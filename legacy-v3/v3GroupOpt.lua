-- ============================================================
-- RT v3 - GroupOpt.lua  (0 local chunk-level — toutes fonctions globales)
--
-- Pools :
--   tanks      → spreads dans groupes mêlée (1 par groupe)
--   melee      → Warrior/Rogue/Paladin Retri/Druid Feral/Shaman Enh
--   hunters    → Hunter (Trueshot Aura buff physique) → groupes mêlée
--   casters    → Mage/Warlock/Shadow Priest/Balance Druid/Ele Shaman
--   shamHeals  → Shaman Heal → autorisés en mêlée pour totems (Windfury)
--   otherHeals → Priest/Druid/Paladin Heal → groupes heal dédiés
--
-- Règles strictes :
--   Max 1 Shaman par groupe (pénalité forte -20)
--   Hunters avec physiques, pas avec casters
--   Paladin Holy préféré dans groupes heal (Devotion Aura)
--   Caster idéal : Shaman + Druid Balance + Shadow Priest + casters
-- ============================================================

function RT3_IsHunter(cls)
    return cls == "HUNTER"
end

function RT3_IsCasterClass(cls, spec)
    if cls == "MAGE" or cls == "WARLOCK" then return true end
    if cls == "PRIEST" and string.find(spec or "", "Shadow") then return true end
    if cls == "DRUID"  and string.find(spec or "", "Balance") then return true end
    if cls == "SHAMAN" and string.find(spec or "", "Ele") then return true end
    return false
end

function RT3_IsMeleeClass(cls, spec)
    if cls == "WARRIOR" or cls == "ROGUE" then return true end
    if cls == "PALADIN" and string.find(spec or "", "Retri") then return true end
    if cls == "DRUID"   and string.find(spec or "", "Feral") then return true end
    if cls == "SHAMAN"  and string.find(spec or "", "Enh") then return true end
    return false
end

-- Retourne true si le groupe contient déjà un joueur de cette classe
local function groupHas(gpList, cls, specPat)
    for i = 1, table.getn(gpList) do
        local p = gpList[i]
        if (p.class or "") == cls then
            if not specPat or string.find(p.spec or "", specPat) then
                return true
            end
        end
    end
    return false
end

-- Score de synergie d'un joueur pour un groupe cible
-- targetRole = "melee" | "caster" | "heal"
function RT3_SynergyScore(player, groupList, targetRole)
    local score = 0
    local cls  = player.class or ""
    local spec = player.spec  or ""
    local role = player.role  or ""

    -- ── Shamans : anchor de buff de groupe ───────────────────────
    if cls == "SHAMAN" then
        if string.find(spec, "Enh") then
            -- Windfury : priorité maximale physique
            if targetRole == "melee"  then score = score + 12 end
        elseif string.find(spec, "Res") then
            -- Windfury pour mêlée, Mana Tide pour heal/casters
            if targetRole == "melee"  then score = score + 9 end
            if targetRole == "caster" then score = score + 10 end
            if targetRole == "heal"   then score = score + 10 end
        else
            -- Ele : Mana Spring excellent pour casters
            if targetRole == "caster" then score = score + 11 end
            if targetRole == "heal"   then score = score + 8 end
            if targetRole == "melee"  then score = score + 5 end
        end
        -- Pénalité forte si déjà un Shaman dans ce groupe
        if groupHas(groupList, "SHAMAN") then score = score - 20 end
    end

    -- ── Paladins ─────────────────────────────────────────────────
    if cls == "PALADIN" then
        if string.find(spec, "Holy") then
            -- Devotion Aura : très utile en heal ou caster (mitigation physique)
            if targetRole == "heal"   then score = score + 9 end
            if targetRole == "caster" then score = score + 6 end
            if targetRole == "melee"  then score = score + 3 end
            if groupHas(groupList, "PALADIN", "Holy") then score = score - 8 end
        elseif string.find(spec, "Retri") then
            if targetRole == "melee"  then score = score + 7 end
            if groupHas(groupList, "PALADIN") then score = score - 5 end
        else
            -- Prot : Aura Dévouement, bien en mêlée
            if targetRole == "melee"  then score = score + 8 end
            if targetRole == "caster" then score = score + 4 end
            if groupHas(groupList, "PALADIN") then score = score - 5 end
        end
    end

    -- ── Warrior : Battle Shout (AP groupe physique) ──────────────
    if cls == "WARRIOR" then
        if targetRole == "melee" then score = score + 4 end
        if groupHas(groupList, "WARRIOR") then score = score - 3 end
    end

    -- ── Druid Feral : Leader of the Pack (crit groupe) ──────────
    if cls == "DRUID" and string.find(spec, "Feral") then
        if targetRole == "melee" then score = score + 5 end
        if groupHas(groupList, "DRUID", "Feral") then score = score - 4 end
    end

    -- ── Hunter : Trueshot Aura (AP physique groupe) ──────────────
    if cls == "HUNTER" then
        if targetRole == "melee" then score = score + 7 end
        if targetRole == "caster" then score = score - 4 end  -- pas utile aux casters
        if groupHas(groupList, "HUNTER") then score = score - 3 end
    end

    -- ── Shadow Priest : Shadow Weaving (dég. ombre +) ──────────
    if cls == "PRIEST" and string.find(spec, "Shadow") then
        if targetRole == "caster" then score = score + 8 end
        if groupHas(groupList, "PRIEST", "Shadow") then score = score - 6 end
    end

    -- ── Druid Balance : bien dans groupe caster ─────────────────
    if cls == "DRUID" and string.find(spec, "Balance") then
        if targetRole == "caster" then score = score + 5 end
    end

    -- ── Tank : 1 seul par groupe mêlée ─────────────────────────
    if role == "Tank" then
        if targetRole == "melee" then score = score + 2 end
        for i = 1, table.getn(groupList) do
            if (groupList[i].role or "") == "Tank" then score = score - 15; break end
        end
    end

    return score
end

-- ── Algorithme principal ─────────────────────────────────────────
function RT3_OptimizeGroups()
    local db = RT.Store.Roster()
    local tanks, melee, hunters, casters, shamHeals, otherHeals = {}, {}, {}, {}, {}, {}

    for name, data in pairs(db) do
        local cls  = string.upper(data.class or "")
        local spec = data.spec or ""
        local role = RT_NormalizeRole(data.role or "")
        local p = { name=name, class=cls, spec=spec, role=role }

        if role == "Tank" then
            table.insert(tanks, p)
        elseif role == "Heal" then
            if cls == "SHAMAN" then table.insert(shamHeals, p)
            else                    table.insert(otherHeals, p) end
        elseif cls == "HUNTER" then
            -- Hunter → groupes physiques (Trueshot Aura buff melee)
            table.insert(hunters, p)
        elseif RT3_IsCasterClass(cls, spec) then
            table.insert(casters, p)
        else
            table.insert(melee, p)
        end
    end

    local nTank      = table.getn(tanks)
    local nMelee     = table.getn(melee)
    local nHunt      = table.getn(hunters)
    local nCaster    = table.getn(casters)
    local nShamHeal  = table.getn(shamHeals)
    local nOtherHeal = table.getn(otherHeals)
    if nTank+nMelee+nHunt+nCaster+nShamHeal+nOtherHeal == 0 then return nil end

    -- Tri : anchors de buff en premier (Shaman Enh > Shaman Resto > Paladin > …)
    local function anchorOrder(p)
        local c=p.class or ""; local s=p.spec or ""
        if p.role == "Tank"                             then return 0 end
        if c=="SHAMAN"  and string.find(s,"Enh")       then return 1 end
        if c=="SHAMAN"  and string.find(s,"Res")       then return 2 end
        if c=="SHAMAN"                                  then return 3 end
        if c=="HUNTER"                                  then return 4 end
        if c=="PALADIN"                                 then return 5 end
        if c=="DRUID"   and string.find(s,"Feral")     then return 6 end
        if c=="WARRIOR"                                 then return 7 end
        if c=="PRIEST"  and string.find(s,"Shadow")    then return 8 end
        if c=="DRUID"   and string.find(s,"Balance")   then return 9 end
        return 10
    end

    -- Pool mêlée combiné : tanks + melee + hunters (tous physiques)
    local physPool = {}
    for i=1,nTank  do table.insert(physPool, tanks[i])   end
    for i=1,nMelee do table.insert(physPool, melee[i])   end
    for i=1,nHunt  do table.insert(physPool, hunters[i]) end

    table.sort(physPool,   function(a,b) return anchorOrder(a)<anchorOrder(b) end)
    table.sort(casters,    function(a,b) return anchorOrder(a)<anchorOrder(b) end)
    table.sort(shamHeals,  function(a,b) return anchorOrder(a)<anchorOrder(b) end)
    table.sort(otherHeals, function(a,b) return anchorOrder(a)<anchorOrder(b) end)

    local nPhys    = table.getn(physPool)
    local nPhysG   = (nPhys    > 0) and math.max(1, math.ceil(nPhys    / 5)) or 0
    local nCasterG = (nCaster  > 0) and math.max(1, math.ceil(nCaster  / 5)) or 0

    -- Plafonner à 8 total
    local nonHeal = nPhysG + nCasterG
    if nonHeal > 8 then
        if nCasterG > 1 then nCasterG=nCasterG-1; nonHeal=nonHeal-1 end
        if nonHeal > 8 and nPhysG > 1 then nPhysG=nPhysG-1; nonHeal=nonHeal-1 end
    end
    local nHealG = math.max(0, 8 - nonHeal)

    -- Structure interne
    local gpP={}; local gpN={}
    for g=1,8 do gpP[g]={}; gpN[g]={} end

    local function addP(g,p) table.insert(gpP[g],p); table.insert(gpN[g],p.name) end

    local function assignPool(pool, gS, gE, role, cap)
        if gS>gE or gS>8 then return end
        local maxC=cap or 5
        for i=1,table.getn(pool) do
            local p=pool[i]
            local bestG=gS; local bestScore=-9999
            for g=gS,gE do
                if g>8 then break end
                if table.getn(gpP[g])<maxC then
                    local syn  = RT3_SynergyScore(p, gpP[g], role)
                    local size = -(table.getn(gpP[g]))*3
                    if syn+size>bestScore then bestScore=syn+size; bestG=g end
                end
            end
            if table.getn(gpP[bestG])<maxC then addP(bestG,p)
            else p._ov=true end
        end
    end

    local function fillOverflow(pool, gS, gE)
        for i=1,table.getn(pool) do
            local p=pool[i]
            if p._ov then
                local bestG=nil; local bestFr=0
                for g=gS,gE do
                    local fr=5-table.getn(gpP[g])
                    if fr>bestFr then bestFr=fr; bestG=g end
                end
                if bestG then p._ov=nil; addP(bestG,p) end
            end
        end
    end

    -- ── Phase 1 : PHYSIQUES (tanks spreads 1/groupe, hunters avec mêlée) ──
    local physEnd = nPhysG
    assignPool(physPool, 1, physEnd, "melee", 5)

    -- Shaman Heal dans les slots libres des groupes physiques
    if nShamHeal > 0 then
        assignPool(shamHeals, 1, physEnd, "melee", 5)
    end

    -- ── Phase 2 : CASTERS ──────────────────────────────────────────
    local casterStart = physEnd + 1
    local casterEnd   = physEnd + nCasterG
    if nCasterG > 0 then
        assignPool(casters, casterStart, casterEnd, "caster", 5)
        -- Shaman Heal overflow → casters (Mana Spring/Tide pour casters)
        fillOverflow(shamHeals, casterStart, casterEnd)
    end

    -- ── Phase 3 : HEAL dédiés (Paladin Holy en tête pour Devotion) ──
    local healStart = casterEnd + 1
    local healEnd   = math.min(8, healStart + nHealG - 1)
    if nHealG > 0 then
        assignPool(otherHeals, healStart, healEnd, "heal", 5)
    end

    -- ── Phase 4 : Overflow → slots libres groupes caster/heal uniquement ──
    fillOverflow(otherHeals, casterStart, 8)
    fillOverflow(physPool, 1, 8)
    fillOverflow(casters, 1, 8)

    return gpN
end

-- Résumé textuel des buffs actifs d'un groupe
function RT3_GroupBuffSummary(players)
    if not players then return "" end
    local buffs={}; local seen={}
    for i=1,table.getn(players) do
        local p=players[i]; local c=(p.class or ""); local s=(p.spec or "")
        if c=="SHAMAN" and not seen.sham then
            seen.sham=true
            if string.find(s,"Enh") then
                table.insert(buffs,"|cff22CCFF+Windfury|r")
            elseif string.find(s,"Res") then
                table.insert(buffs,"|cff22CCFF+Windfury+Tide|r")
            else
                table.insert(buffs,"|cff22CCFF+ManaSpring|r")
            end
        end
        if c=="PALADIN" and not seen.pal then
            seen.pal=true; table.insert(buffs,"|cffF58CBA+Devo|r")
        end
        if c=="DRUID" and string.find(s,"Feral") and not seen.feral then
            seen.feral=true; table.insert(buffs,"|cffFF7D0A+LoTP|r")
        end
        if c=="WARRIOR" and not seen.warr then
            seen.warr=true; table.insert(buffs,"|cffC79C6E+BShout|r")
        end
        if c=="HUNTER" and not seen.hunt then
            seen.hunt=true; table.insert(buffs,"|cffABD473+TrueAura|r")
        end
        if c=="PRIEST" and string.find(s,"Shadow") and not seen.spriest then
            seen.spriest=true; table.insert(buffs,"|cffAAAAFF+SWeaving|r")
        end
        if (p.role or "")=="Tank" and not seen.tank then
            seen.tank=true; table.insert(buffs,"|cff4499FF[Tank]|r")
        end
    end
    return table.concat(buffs," ")
end
