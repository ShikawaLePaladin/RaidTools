-- ============================================================
-- RT v2 — AutoAssign.lua
-- Moteur d'attribution automatique intelligente
-- Analyse roster → attribue tanks/heals/buffs/groupes/bénédictions
-- Compatible WoW 1.12 / TurtleWoW
-- ============================================================

RT_AA = RT_AA or {}

-- ── Nettoie un message destiné au chat SERVEUR (SendChatMessage) ──
-- Retire les codes couleur/textures/liens et remplace tout | restant,
-- sinon le client renvoie "Invalid escape code in chat message".
function RT_ChatSafe(s)
    s = s or ""
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "") -- ouverture couleur |cAARRGGBB
    s = string.gsub(s, "|r", "")                  -- fermeture couleur
    s = string.gsub(s, "|T.-|t", "")              -- textures |T...|t
    s = string.gsub(s, "|H.-|h", "")              -- début hyperlien
    s = string.gsub(s, "|h", "")                  -- fin hyperlien
    s = string.gsub(s, "||", "|")                 -- normalise les || déjà échappés
    s = string.gsub(s, "|", "/")                  -- tout | restant → / (séparateur sûr)
    return s
end

-- ── Priorité tank par classe/spec (plus haut = meilleur tank) ─
local AA_TANK_SCORE = {
    Warrior  = { Protection=10, Prot=10, Arms=1, Fury=1 },
    Druid    = { Bear=8, ["Feral Tank"]=8, Feral=3, Restoration=0, Resto=0, Balance=0 },
    Paladin  = { Protection=7, Prot=7, Retribution=1, Ret=1, Holy=0 },
}

-- ── Priorité heal tank par classe ─────────────────────────────
local AA_HEAL_TANK = { Paladin=10, Priest=8, Druid=4, Shaman=3 }

-- ── Priorité heal raid par classe ─────────────────────────────
local AA_HEAL_RAID = { Druid=10, Shaman=8, Priest=6, Paladin=2 }

-- ── Bénédiction optimale par classe cible ─────────────────────
-- Index: 1=Might 2=Kings 3=Wisdom 4=Salvation 5=Light 6=Sanctuary
-- Salut (4) réduit la menace de 30% → priorité pour tout le DPS
-- Sagesse (3) régénère le mana → heals et chasseurs
local AA_BLESS_FOR_CLASS = {
    Warrior  = 4,   -- Salut (DPS >> tanks en nb; tanks tiennent sans)
    Rogue    = 4,   -- Salut
    Hunter   = 3,   -- Sagesse (tirs très gourmands en mana)
    Paladin  = 2,   -- Rois
    Priest   = 3,   -- Sagesse
    Druid    = 3,   -- Sagesse
    Shaman   = 3,   -- Sagesse
    Mage     = 4,   -- Salut
    Warlock  = 4,   -- Salut (DoTs génèrent beaucoup de menace)
}

-- ── Noms lisibles des bénédictions ────────────────────────────
local AA_BLESS_NAMES = {
    "Bénéd. de la Puissance",  -- 1 Might
    "Bénéd. des Rois",         -- 2 Kings
    "Bénéd. de Sagesse",       -- 3 Wisdom
    "Bénéd. du Salut",         -- 4 Salvation
    "Bénéd. de Lumière",       -- 5 Light
    "Bénéd. du Sanctuaire",    -- 6 Sanctuary
}
function RT_GetBlessingName(idx)
    return AA_BLESS_NAMES[idx] or ("Bénéd."..tostring(idx or "?"))
end

-- ── Consommables recommandés par rôle ─────────────────────────
local AA_CONSO = {
    Tank  = "Flask of the Titans + Rumsey Rum Black Label + Winterfall Firewater",
    Heal  = "Flask of Distilled Wisdom + Mageblood Potion",
    DPS   = "Flask of Supreme Power (caster) / Elixir of the Mongoose (melee)",
}

-- ── Groupes par synergie ───────────────────────────────────────
-- Retourne un score de "groupe naturel" pour placer ensemble
local function AA_GroupAffinity(class, spec, role)
    local s = string.lower(spec or "")
    if role == "Tank" then return "tank" end
    if role == "Heal" then return "heal" end
    if class == "Warrior" or class == "Rogue" then return "melee" end
    if class == "Paladin" then
        if string.find(s, "ret") then return "melee" end
        return "heal"
    end
    if class == "Druid" then
        if string.find(s, "feral") or string.find(s, "bear") or string.find(s, "cat") then return "melee" end
        if string.find(s, "balance") or string.find(s, "boom") or string.find(s, "moonkin") then return "caster" end
        return "heal"
    end
    if class == "Shaman" then
        if string.find(s, "enh") then return "melee" end
        if string.find(s, "elem") then return "caster" end
        return "heal"
    end
    if class == "Hunter" then return "ranged" end
    if class == "Mage" or class == "Warlock" then return "caster" end
    if class == "Priest" then
        if string.find(s, "shadow") then return "caster" end
        return "heal"
    end
    return "dps"
end

-- ── Normalisation locale ───────────────────────────────────────
local function AA_NormClass(c)
    if RT_NormalizeClassName then return RT_NormalizeClassName(c or "") end
    return c or ""
end
local function AA_NormRole(r)
    if RT_NormalizeRole then return RT_NormalizeRole(r or "") end
    return r or "DPS"
end
local function AA_Low(s) return string.lower(s or "") end

-- ============================================================
-- RT_AA_Analyze : catégorise le roster
-- Retourne { tanks, healers, melee, casters, ranged, all }
-- ============================================================
function RT_AA_Analyze()
    RT_DB = RT_DB or {}
    local roster = RT_DB.roster or {}
    local result = {
        tanks   = {},   -- {name, class, spec, tankScore}
        healers = {},   -- {name, class, spec, healTankScore, healRaidScore}
        melee   = {},
        casters = {},
        ranged  = {},
        all     = {},
    }

    for name, data in pairs(roster) do
        local class = AA_NormClass(data.class)
        local spec  = data.spec or ""
        local role  = AA_NormRole(data.role)
        local aff   = AA_GroupAffinity(class, spec, role)
        local entry = { name=name, class=class, spec=spec, role=role, aff=aff }
        table.insert(result.all, entry)

        if role == "Tank" then
            local scoreTable = AA_TANK_SCORE[class] or {}
            local score = scoreTable[spec] or scoreTable[AA_NormClass(spec)] or 1
            entry.tankScore = score
            table.insert(result.tanks, entry)
        elseif role == "Heal" then
            entry.healTankScore = AA_HEAL_TANK[class] or 1
            entry.healRaidScore = AA_HEAL_RAID[class] or 1
            table.insert(result.healers, entry)
        elseif aff == "melee" then
            table.insert(result.melee, entry)
        elseif aff == "caster" then
            table.insert(result.casters, entry)
        elseif aff == "ranged" then
            table.insert(result.ranged, entry)
        else
            table.insert(result.casters, entry)
        end
    end

    -- Trie tanks par score décroissant
    table.sort(result.tanks, function(a, b)
        return (a.tankScore or 0) > (b.tankScore or 0)
    end)
    -- Trie healers
    table.sort(result.healers, function(a, b)
        return (a.healTankScore or 0) > (b.healTankScore or 0)
    end)
    table.sort(result.melee,   function(a,b) return a.name < b.name end)
    table.sort(result.casters, function(a,b) return a.name < b.name end)
    table.sort(result.ranged,  function(a,b) return a.name < b.name end)

    return result
end

-- ============================================================
-- RT_AA_AssignTanks : remplit les slots tank + markers auto
-- ============================================================
local RT_AA_MT_MARKERS = { "Skull", "Cross", "Square", "Moon", "Triangle", "Diamond", "Circle", "Star" }

function RT_AA_AssignTanks(analysis, out)
    out = out or {}
    out.tanks      = {}
    out.tankMarkers= {}
    local maxTanks = 4
    local n = math.min(table.getn(analysis.tanks), maxTanks)
    for i = 1, n do
        out.tanks[i]       = analysis.tanks[i].name
        out.tankMarkers[i] = RT_AA_MT_MARKERS[i] or ""
    end
    out.tankCount = math.max(n, 1)
    return out
end

-- ============================================================
-- RT_AA_AssignHeals : 1 healer/tank (Pala prio), reste → raid
-- ============================================================
function RT_AA_AssignHeals(analysis, out)
    out = out or {}
    out.healTank = {}   -- out.healTank[tankSlot] = healerName
    out.healRaid = {}   -- liste healers raid

    local tankCount  = out.tankCount or table.getn(out.tanks or {})
    local healerPool = {}
    for i = 1, table.getn(analysis.healers) do
        table.insert(healerPool, analysis.healers[i])
    end

    -- Trie par priorité tank pour remplir les slots tank d'abord
    table.sort(healerPool, function(a,b) return (a.healTankScore or 0) > (b.healTankScore or 0) end)

    local usedIdx = {}
    -- 1 healer par tank (priorité Paladin)
    for ti = 1, tankCount do
        for hi = 1, table.getn(healerPool) do
            if not usedIdx[hi] then
                out.healTank[ti] = healerPool[hi].name
                usedIdx[hi] = true
                break
            end
        end
    end

    -- Resto → raid (druides puis shamans puis prêtres restants)
    local raidPool = {}
    for hi = 1, table.getn(healerPool) do
        if not usedIdx[hi] then
            table.insert(raidPool, healerPool[hi])
        end
    end
    table.sort(raidPool, function(a,b) return (a.healRaidScore or 0) > (b.healRaidScore or 0) end)
    for i = 1, table.getn(raidPool) do
        table.insert(out.healRaid, raidPool[i].name)
    end

    -- Note HoT pour les druides en raid
    local druidNames = {}
    for i = 1, table.getn(raidPool) do
        if raidPool[i].class == "Druid" then
            table.insert(druidNames, raidPool[i].name)
        end
    end
    if table.getn(druidNames) > 0 and table.getn(out.tanks) > 0 then
        out.druidNote = table.concat(druidNames, "/") .. " : Rejuv + Lifebloom permanent sur " .. (out.tanks[1] or "MT1")
    end

    return out
end

-- ============================================================
-- RT_AA_AssignGroups : 8 groupes par synergie
-- Groupes 1-2 : Tanks + tank healers
-- Groupes 3-4 : Melee DPS (+ Enh Shaman Windfury)
-- Groupes 5-6 : Ranged/Caster DPS
-- Groupes 7-8 : Healers raid
-- ============================================================
function RT_AA_AssignGroups(analysis, out)
    out = out or {}
    local groups = {}
    for g = 1, 8 do groups[g] = {} end

    local function addToGroup(g, name)
        if table.getn(groups[g]) < 5 then
            table.insert(groups[g], name)
            return true
        end
        return false
    end

    local function addToFirstFreeGroup(startG, endG, name)
        for g = startG, endG do
            if addToGroup(g, name) then return g end
        end
        return nil
    end

    -- Groupe 1-2 : tanks
    for i = 1, table.getn(analysis.tanks) do
        addToFirstFreeGroup(1, 2, analysis.tanks[i].name)
    end
    -- Tank healers dans groupes 1-2 avec leur tank
    for ti = 1, table.getn(out.healTank or {}) do
        if out.healTank[ti] and out.healTank[ti] ~= "" then
            addToFirstFreeGroup(1, 2, out.healTank[ti])
        end
    end

    -- Sépare Enh Shaman pour groupe melee (Windfury)
    local enhShaman, otherMelee = {}, {}
    for i = 1, table.getn(analysis.melee) do
        local e = analysis.melee[i]
        if e.class == "Shaman" and string.find(AA_Low(e.spec), "enh") then
            table.insert(enhShaman, e)
        else
            table.insert(otherMelee, e)
        end
    end

    -- Groupe 3-4 : melee (avec Enh Shaman en slot 1 si possible)
    for i = 1, table.getn(enhShaman) do
        addToFirstFreeGroup(3, 4, enhShaman[i].name)
    end
    for i = 1, table.getn(otherMelee) do
        addToFirstFreeGroup(3, 4, otherMelee[i].name)
    end

    -- Sépare Ele Shaman / Moonkin pour boost casters
    local boostCaster, otherCaster = {}, {}
    for i = 1, table.getn(analysis.casters) do
        local e = analysis.casters[i]
        if (e.class == "Shaman" and string.find(AA_Low(e.spec), "elem")) or
           (e.class == "Druid"  and (string.find(AA_Low(e.spec), "balance") or string.find(AA_Low(e.spec), "boom"))) then
            table.insert(boostCaster, e)
        else
            table.insert(otherCaster, e)
        end
    end

    -- Groupe 5-6 : casters/ranged (boost en slot 1)
    for i = 1, table.getn(boostCaster) do
        addToFirstFreeGroup(5, 6, boostCaster[i].name)
    end
    for i = 1, table.getn(otherCaster) do
        addToFirstFreeGroup(5, 6, otherCaster[i].name)
    end
    for i = 1, table.getn(analysis.ranged) do
        addToFirstFreeGroup(5, 6, analysis.ranged[i].name)
    end

    -- Groupe 7-8 : raid healers
    for i = 1, table.getn(out.healRaid or {}) do
        addToFirstFreeGroup(7, 8, out.healRaid[i])
    end

    out.groups = groups
    return out
end

-- ============================================================
-- RT_AA_AssignBuffs : qui buffe qui (avec répartition de groupes)
-- ============================================================
function RT_AA_AssignBuffs(analysis, out)
    out = out or {}
    out.buffs = {}

    local priests, druids, mages, warlocks, warriors = {}, {}, {}, {}, {}
    for i = 1, table.getn(analysis.all) do
        local e = analysis.all[i]
        if e.class == "Priest" then
            table.insert(priests, e.name)
        elseif e.class == "Druid" and (e.role=="Heal" or string.find(AA_Low(e.spec or ""),"resto")) then
            table.insert(druids, e.name)
        elseif e.class == "Mage" then
            table.insert(mages, e.name)
        elseif e.class == "Warlock" then
            table.insert(warlocks, e.name)
        elseif e.class == "Warrior" and (e.role=="Tank" or string.find(AA_Low(e.spec or ""),"prot")) then
            table.insert(warriors, e.name)
        end
    end

    -- Répartit un buff entre N fournisseurs → chacun couvre une tranche de groupes
    local function splitAdd(providers, buffName)
        local n = table.getn(providers)
        if n == 0 then return end
        local total = 8
        local perP  = math.floor(total / n)
        local extra = math.mod(total, n)
        local gs = 1
        for i = 1, n do
            local ge = gs + perP - 1
            if i <= extra then ge = ge + 1 end
            local scope
            if n == 1 then scope = "Raid entier"
            else scope = "Grp " .. gs .. "-" .. ge end
            table.insert(out.buffs, { name=providers[i], buff=buffName, scope=scope })
            gs = ge + 1
        end
    end

    splitAdd(priests,  "Prière de Forteresse")
    splitAdd(priests,  "Esprit Divin")
    splitAdd(druids,   "Don des Fauves")
    splitAdd(mages,    "Brillance Arcanique")
    -- (Cri de Guerre retiré : buff de classe trivial, allège l'annonce)

    -- Pierre d'Âme : chaque démoniste en pose une sur un soigneur (rez de combat)
    if table.getn(warlocks) > 0 then
        local ssTargets = {}
        for ti = 1, table.getn(out.healTank or {}) do
            local h = out.healTank[ti]
            if h and h ~= "" then table.insert(ssTargets, h) end
        end
        for i = 1, table.getn(out.healRaid or {}) do
            table.insert(ssTargets, out.healRaid[i])
        end
        for i = 1, table.getn(warlocks) do
            local tgt = ssTargets[i] or ssTargets[1] or "soigneur principal"
            table.insert(out.buffs, { name=warlocks[i], buff="Pierre d'Âme", scope="sur "..tgt })
        end
    end

    -- ── Malédictions (section séparée) ────────────────────────
    -- 1 seul slot de malédiction par cible → chaque démoniste maintient
    -- UNE malédiction différente, jamais simultanées sur le boss.
    out.curses = {}
    local WLOCK_CURSES = {
        { curse="Maléd. des Éléments", why="+10% Feu/Givre (mages)" },
        { curse="Maléd. de l'Ombre",  why="+10% Ombre/Arcane (shadow, démos)" },
        { curse="Maléd. de Témérité", why="-640 armure (DPS physique)" },
    }
    for i = 1, table.getn(warlocks) do
        local c = WLOCK_CURSES[i] or { curse="Maléd. d'Agonie", why="DoT" }
        table.insert(out.curses, { name=warlocks[i], curse=c.curse, why=c.why })
    end

    return out
end

-- ============================================================
-- RT_AA_AssignBlessings : Paladins → bénédictions par classe
-- ============================================================
function RT_AA_AssignBlessings(analysis, out)
    out = out or {}
    out.blessings = {}

    local paladins = {}
    for i = 1, table.getn(analysis.all) do
        if analysis.all[i].class == "Paladin" then
            table.insert(paladins, analysis.all[i].name)
        end
    end
    if table.getn(paladins) == 0 then return out end

    -- Collecte toutes les classes présentes
    local classes = {}
    local classSet = {}
    for i = 1, table.getn(analysis.all) do
        local c = analysis.all[i].class
        if c and c ~= "" and not classSet[c] then
            classSet[c] = true
            table.insert(classes, c)
        end
    end
    table.sort(classes)

    -- Distribue une classe par paladin (round-robin)
    local pIdx = 1
    for ci = 1, table.getn(classes) do
        local cls   = classes[ci]
        local bIdx  = AA_BLESS_FOR_CLASS[cls] or 2
        local pala  = paladins[pIdx]
        local existing = out.blessings[pala] or {}
        table.insert(existing, { class=cls, blessIdx=bIdx })
        out.blessings[pala] = existing
        pIdx = pIdx + 1
        if pIdx > table.getn(paladins) then pIdx = 1 end
    end

    return out
end

-- ============================================================
-- RT_AA_AssignConso : consommables recommandés par joueur
-- ============================================================
function RT_AA_AssignConsoList(analysis, out)
    out = out or {}
    out.conso = {}
    for i = 1, table.getn(analysis.all) do
        local e = analysis.all[i]
        out.conso[e.name] = AA_CONSO[e.role] or AA_CONSO["DPS"]
    end
    return out
end

-- ============================================================
-- RT_AA_Run : exécute tout le pipeline d'attribution
-- Retourne un objet "assignment" complet
-- ============================================================
function RT_AA_Run()
    local analysis = RT_AA_Analyze()
    local out = {}

    RT_AA_AssignTanks(analysis, out)
    RT_AA_AssignHeals(analysis, out)
    RT_AA_AssignGroups(analysis, out)
    RT_AA_AssignBuffs(analysis, out)
    RT_AA_AssignBlessings(analysis, out)
    RT_AA_AssignConsoList(analysis, out)

    out.analysis = analysis
    RT_AA_LAST = out
    return out
end

-- ============================================================
-- RT_AA_Apply : applique l'assignment dans RT_DB / RT_BOSS_STATE
-- ============================================================
function RT_AA_Apply(out)
    out = out or RT_AA_LAST
    if not out then
        RT_Print("|cffFF4444[AA] Aucune attribution. Lance d'abord RT_AA_Run().|r")
        return
    end

    RT_DB = RT_DB or {}
    RT_DB.groupPlanner = RT_DB.groupPlanner or { plan={ groups={} } }

    -- Groupes
    if out.groups then
        RT_DB.groupPlanner.plan.groups = out.groups
    end

    -- Boss state (tanks + heals)
    if RT_BOSS_STATE then
        RT_BOSS_STATE.tanks      = {}
        RT_BOSS_STATE.tank_marks = {}
        RT_BOSS_STATE.tank_count = out.tankCount or 1
        for i = 1, table.getn(out.tanks or {}) do
            RT_BOSS_STATE.tanks[i]      = out.tanks[i] or ""
            RT_BOSS_STATE.tank_marks[i] = out.tankMarkers[i] or ""
        end
        local healKeys = { "h_tank1","h_tank2","h_tank3","h_tank4" }
        for ti = 1, 4 do
            RT_BOSS_STATE[healKeys[ti]] = { out.healTank[ti] or "" }
        end
        RT_BOSS_STATE.h_raid   = {}
        for i = 1, math.min(table.getn(out.healRaid or {}), 3) do
            RT_BOSS_STATE.h_raid[i] = out.healRaid[i]
        end
        -- Note druide HoT si présente
        if out.druidNote and out.druidNote ~= "" then
            local cur = RT_BOSS_STATE.note or ""
            if not string.find(cur, "Rejuv", 1, true) then
                RT_BOSS_STATE.note = cur ~= "" and (cur .. "\n" .. out.druidNote) or out.druidNote
            end
        end
        if RT_BOSS_STATE.h_counts then
            for ti = 1, 4 do RT_BOSS_STATE.h_counts[healKeys[ti]] = 1 end
            RT_BOSS_STATE.h_counts.h_raid = math.max(table.getn(out.healRaid or {}), 1)
        end
    end

    -- Bénédictions
    if out.blessings then
        RT_DB.blessings = RT_DB.blessings or {}
        RT_DB.blessings.palaAssign = out.blessings
    end

    -- Actualise l'UI si disponible
    if RT_BossRefreshSlots then RT_BossRefreshSlots() end
    if RT_GroupDisplay then RT_GroupDisplay() end
    if RT_RosterDisplay then RT_RosterDisplay() end
end

-- ============================================================
-- RT_AA_AnnounceAll : annonce tout au raid (throttlé)
-- ============================================================
function RT_AA_AnnounceAll(out)
    out = out or RT_AA_LAST
    if not out then RT_Print("|cffFF4444[AA] Pas d'attribution à annoncer.|r"); return end

    local function send(msg)
        msg = RT_ChatSafe(msg)
        if msg == "" then return end
        local nRaid  = GetNumRaidMembers  and GetNumRaidMembers()  or 0
        local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
        if nRaid > 0 then
            SendChatMessage(msg, "RAID")
        elseif nParty > 0 then
            SendChatMessage(msg, "PARTY")
        else
            -- hors groupe (test solo) : affichage local pour ne pas spammer /say
            DEFAULT_CHAT_FRAME:AddMessage("|cff88CCFF[RT annonce]|r " .. msg)
        end
    end

    -- Tanks + markers
    if table.getn(out.tanks or {}) > 0 then
        local parts = {}
        for i = 1, table.getn(out.tanks) do
            local mk = out.tankMarkers[i]
            local label = "MT" .. i
            if mk and mk ~= "" then label = "[" .. mk .. "] " .. label end
            table.insert(parts, label .. ": " .. out.tanks[i])
        end
        send("[RT] Tanks: " .. table.concat(parts, "  |  "))
    end

    -- Heals tank
    local healParts = {}
    for ti = 1, table.getn(out.healTank or {}) do
        if out.healTank[ti] and out.healTank[ti] ~= "" then
            table.insert(healParts, "MT" .. ti .. "<-" .. out.healTank[ti])
        end
    end
    if table.getn(healParts) > 0 then
        send("[RT] Soins Tank: " .. table.concat(healParts, "  "))
    end

    -- Heals raid
    if table.getn(out.healRaid or {}) > 0 then
        send("[RT] Soins Raid: " .. table.concat(out.healRaid, ", "))
    end

    -- Buffs : 1 ligne par type (noms anglais), prêtres fusionnés sur 1 ligne
    if table.getn(out.buffs or {}) > 0 then
        local byBuff, order = {}, {}
        for i = 1, table.getn(out.buffs) do
            local b = out.buffs[i]
            if not byBuff[b.buff] then byBuff[b.buff] = {}; table.insert(order, b.buff) end
            table.insert(byBuff[b.buff], b)
        end

        -- Construit la liste de segments "Grp X-Y=Nom" ou "Nom" pour un type
        local function buildParts(entries)
            local parts = {}
            if table.getn(entries) == 1 then
                table.insert(parts, entries[1].name)
            else
                for j = 1, table.getn(entries) do
                    local e = entries[j]
                    if e.scope == "Raid entier" then
                        table.insert(parts, e.name)
                    else
                        table.insert(parts, e.scope .. "=" .. e.name)
                    end
                end
            end
            return parts
        end

        -- Détecte si deux listes de buff ont les mêmes fournisseurs (prêtres Fort+DS)
        local function sameProviders(ea, eb)
            if table.getn(ea) ~= table.getn(eb) then return false end
            for j = 1, table.getn(ea) do
                if ea[j].name ~= eb[j].name then return false end
            end
            return true
        end

        -- Cherche les clés Fort et DS parmi les buffs
        local fortKey, dsKey = nil, nil
        for _, k in ipairs(order) do
            if string.find(k, "Forteresse") then fortKey = k end
            if string.find(k, "Esprit")     then dsKey   = k end
        end
        local priestMerged = fortKey and dsKey and sameProviders(byBuff[fortKey], byBuff[dsKey])

        local sent = {}
        for i = 1, table.getn(order) do
            local k = order[i]
            if sent[k] then -- skip
            elseif (k == fortKey or k == dsKey) and priestMerged then
                if k == fortKey then
                    -- Fusion Fort+DS sur une ligne
                    local parts = buildParts(byBuff[fortKey])
                    send("[RT] PW:Fort+D.Spirit: " .. table.concat(parts, " | "))
                    sent[fortKey] = true; sent[dsKey] = true
                end
            elseif string.find(k, "Pierre") then
                local parts = {}
                for j = 1, table.getn(byBuff[k]) do
                    local e = byBuff[k][j]
                    local tgt = string.gsub(e.scope or "", "^sur ", "")
                    table.insert(parts, e.name .. ">" .. tgt)
                end
                send("[RT] Soulstone: " .. table.concat(parts, " | "))
            elseif string.find(k, "Fauves") then
                send("[RT] MotW: " .. table.concat(buildParts(byBuff[k]), " | "))
            elseif string.find(k, "Brillance") then
                send("[RT] Arc.Brill: " .. table.concat(buildParts(byBuff[k]), " | "))
            else
                send("[RT] Buff: " .. table.concat(buildParts(byBuff[k]), " | "))
            end
        end
    end

    -- Malédictions (démonistes) — abréviations anglaises
    if table.getn(out.curses or {}) > 0 then
        local cparts = {}
        for i = 1, table.getn(out.curses) do
            local c = out.curses[i]
            local cs
            if string.find(c.curse, "ment") or string.find(c.curse, "lem") then cs = "CoE"
            elseif string.find(c.curse, "Ombre") then cs = "CoS"
            else cs = "CoR"
            end
            table.insert(cparts, cs .. "=" .. c.name)
        end
        send("[RT] Curses: " .. table.concat(cparts, " | "))
    end

    -- Note druide
    if out.druidNote and out.druidNote ~= "" then
        send("[RT] " .. out.druidNote)
    end

    -- (Bénédictions : désactivées pour l'instant)

    RT_Print("|cff88FF88[AA] Annonces envoyées.|r")
end

-- ============================================================
-- RT_AA_WhisperPersonal : envoie l'attrib perso à chaque joueur
-- ============================================================
function RT_AA_WhisperPersonal(out)
    out = out or RT_AA_LAST
    if not out then return end

    local function wsend(target, text)
        if not target or target == "" then return end
        local lang = GetDefaultLanguage and GetDefaultLanguage("player") or nil
        pcall(SendChatMessage, RT_ChatSafe("[RT] " .. text), "WHISPER", lang, target)
    end

    -- MP perso : UNIQUEMENT les tâches actionnables (pas de classe/spec/
    -- rôle/groupe, inutiles au joueur). On ne whisper que ceux qui ont
    -- une consigne réelle.
    for i = 1, table.getn(out.analysis.all) do
        local e = out.analysis.all[i]
        local tasks = {}

        for ti = 1, table.getn(out.healTank or {}) do
            if out.healTank[ti] == e.name then
                table.insert(tasks, "Soins MT" .. ti .. " (" .. (out.tanks[ti] or "?") .. ")")
            end
        end
        for i2 = 1, table.getn(out.healRaid or {}) do
            if out.healRaid[i2] == e.name then
                local t = "Soins Raid"
                if out.druidNote and string.find(out.druidNote, e.name, 1, true) then
                    t = t .. " + HoTs sur " .. (out.tanks[1] or "MT1")
                end
                table.insert(tasks, t)
            end
        end
        for bi = 1, table.getn(out.buffs or {}) do
            if out.buffs[bi].name == e.name then
                table.insert(tasks, out.buffs[bi].buff)
            end
        end
        for ci = 1, table.getn(out.curses or {}) do
            if out.curses[ci].name == e.name then
                table.insert(tasks, "Maléd: " .. out.curses[ci].curse)
            end
        end

        if table.getn(tasks) > 0 then
            wsend(e.name, table.concat(tasks, "  —  "))
        end
    end

    RT_Print("|cff88FF88[AA] Attribs personnelles envoyées en MP.|r")
end

-- ============================================================
-- RT_AA_PackPUG : pipeline complet en 1 appel (mode PUG)
-- ============================================================
function RT_AA_PackPUG()
    local n = 0
    if RT_DB and RT_DB.roster then
        for _ in pairs(RT_DB.roster) do n = n + 1 end
    end
    if n == 0 then
        RT_Print("|cffFF4444[PUG Pack] Roster vide — importe d'abord le roster.|r")
        return
    end

    RT_Print("|cff88CCFF[PUG Pack]|r Calcul des attributions pour " .. n .. " joueurs...")
    local out = RT_AA_Run()
    RT_AA_Apply(out)
    RT_AA_AnnounceAll(out)
    RT_AA_WhisperPersonal(out)

    -- Mise à jour overlay si visible
    if RT_OverlayUpdate then RT_OverlayUpdate() end
    RT_Print("|cff88FF88[PUG Pack] Terminé. Tout a été attribué et annoncé.|r")
end

-- ============================================================
-- RT_AA_PackGuild : calcule sans annoncer (mode Guild)
-- ============================================================
function RT_AA_PackGuild()
    local n = 0
    if RT_DB and RT_DB.roster then
        for _ in pairs(RT_DB.roster) do n = n + 1 end
    end
    if n == 0 then
        RT_Print("|cffFF4444[Guild Pack] Roster vide.|r")
        return
    end
    local out = RT_AA_Run()
    RT_AA_Apply(out)
    if RT_OverlayUpdate then RT_OverlayUpdate() end
    RT_Print("|cff88FF88[Guild Pack] Attributions calculées. Vérifie et ajuste avant d'annoncer.|r")
end
