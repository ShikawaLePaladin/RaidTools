-- ============================================================
-- RT v4 — OctoFanBridge.lua
--
-- Pont OctoFan (/raid/ sur octofan.vercel.app) <-> RaidTools.
--
-- Import du plan, 3 chemins :
--   1. FICHIER (fiable) : bouton "Fichier addon" du site -> télécharge
--      RT_OctoFanData.lua à poser dans ce dossier -> import auto au login.
--   2. COLLAGE : bouton "RaidTools" du site -> bloc OFP1|... collé dans
--      l'onglet OctoFan (le vanilla peut corrompre les longs collages).
--   3. RELAY RAID : "Envoyer au raid" diffuse le plan aux autres
--      RaidTools du groupe/raid (transport hexa, enveloppe ":").
--
-- Contenu du plan (format OFP, lignes "|" puis records ";") :
--   OFP1|titre|raid|date ; R|role|nom|classe|spé|groupe ;
--   A|boss|poste|joueur|tâche ; T|pack|icône|mob|tank ;
--   X|boss|ligne de stratégie ; END
--
-- Intégration AutoMarkerOW : OF.PushTrash() pousse les packs de trash
-- comme règles de marquage (via AMOW_ImportExternalRules).
--
-- Lua 5.0 strict : gfind, table.getn, pas de # ni match/gmatch.
-- ============================================================

local OF = {}
RT.OctoFan = OF

-- Forward declarations : le boot (PLAYER_LOGIN) appelle IsGuildMode
-- qui est définie PLUS BAS — sans ça la closure capture le global nil
-- (crash "attempt to call global IsGuildMode" au login).
local IsGuildMode

local OFP_PREFIX  = "OFPB"
-- 110 chars de texte = 220 hex + en-tête (~25) < 254 : la limite
-- SendAddonMessage du client 1.12. (220 hexifiait à 440 = tronqué)
local CHUNK_SIZE  = 110
local CHUNK_DELAY = 0.25

local ROLE_FR = { tank = "Tank", heal = "Heal", melee = "Melee", ranged = "Dist" }
local MARK_FR = {
    skull = "Crâne", cross = "Croix", square = "Carré", moon = "Lune",
    diamond = "Diamant", triangle = "Triangle", star = "Étoile", circle = "Rond",
}
local ICON_IDX = {
    star = 1, circle = 2, diamond = 3, triangle = 4,
    moon = 5, square = 6, cross = 7, skull = 8,
}
local RAID_ZONE_EN = {
    mc = "Molten Core", onyxia = "Onyxia's Lair", ony = "Onyxia's Lair",
    bwl = "Blackwing Lair", zg = "Zul'Gurub",
    aq20 = "Ruins of Ahn'Qiraj", aq40 = "Temple of Ahn'Qiraj",
    naxx = "Naxxramas",
}

-- ============================================================
-- Hex transport (le client 1.12 refuse les "|" dans les messages addon)
-- ============================================================

local function HexEnc(s)
    local out = {}
    for i = 1, string.len(s) do
        table.insert(out, string.format("%02x", string.byte(s, i)))
    end
    return table.concat(out)
end

local function HexDec(s)
    local out = {}
    for pair in string.gfind(s .. "0", "(%x%x)") do
        table.insert(out, string.char(tonumber(pair, 16)))
    end
    return table.concat(out)
end

-- ============================================================
-- Parse / serialize OFP
-- ============================================================

local ROLE_OK = { tank = true, heal = true, melee = true, ranged = true }

local function ParseOFP(text)
    if not text then return nil end
    -- Un EditBox 1.12 DOUBLE les "|" au collage ("||") : tout le plan est alors
    -- décalé d'un champ sur deux (rôle="" , nom=rôle...). On rétablit les "|"
    -- seulement si TOUS les pipes sont doublés (un "||" légitime = champ vide,
    -- il reste alors accompagné de "|" simples).
    do
        local noPair = string.gsub(text, "||", "")
        if string.find(text, "||", 1, true) and not string.find(noPair, "|", 1, true) then
            text = string.gsub(text, "||", "|")
        end
    end
    local plan = {
        title = "", raid = "", date = "",
        roster = {}, rosterOrder = {},
        assign = {}, bossOrder = {},
        trash = {}, strats = {},
    }
    local seenBoss, seenPlayer = {}, {}
    local curPack = nil
    local seenHdr = false
    -- records séparés par retour à la ligne OU point-virgule (le collage
    -- vanilla casse les \n ; le site envoie du single-line ";")
    text = string.gsub(text, "[\r\n]", ";")
    for line in string.gfind(text .. ";", "([^;]*);") do
        local t = line
        if t ~= "" and string.sub(t, 1, 1) ~= "#" then
            local parts = {}
            for v in string.gfind(t .. "|", "([^|]*)|") do
                table.insert(parts, v)
            end
            local tag = parts[1] or ""
            if tag == "OFP1" then
                seenHdr = true
                plan.title = parts[2] or ""
                plan.raid = parts[3] or ""
                plan.date = parts[4] or ""
                curPack = nil
            elseif tag == "R" and parts[2] and ROLE_OK[parts[2]] and parts[3] and parts[3] ~= "" then
                local name = parts[3]
                if not seenPlayer[name] then
                    seenPlayer[name] = true
                    table.insert(plan.rosterOrder, name)
                end
                plan.roster[name] = {
                    role = parts[2], class = parts[4] or "",
                    spec = parts[5] or "", group = tonumber(parts[6]) or 0,
                }
            elseif tag == "A" and parts[2] and parts[2] ~= "" and parts[3] and parts[3] ~= ""
                and parts[4] and parts[4] ~= "" then
                local boss, poste, player, task = parts[2], parts[3], parts[4], parts[5] or ""
                if not seenBoss[boss] then
                    seenBoss[boss] = true
                    table.insert(plan.bossOrder, boss)
                    plan.assign[boss] = {}
                end
                local slot = plan.assign[boss][poste]
                if slot and slot.player and slot.player ~= player then
                    slot.player = slot.player .. ", " .. player
                else
                    plan.assign[boss][poste] = { player = player, task = task }
                end
            elseif tag == "T" and parts[2] then
                local packName = parts[2]
                if not curPack or curPack.name ~= packName then
                    curPack = { name = packName, marks = {} }
                    table.insert(plan.trash, curPack)
                end
                if (parts[4] and parts[4] ~= "") or (parts[5] and parts[5] ~= "") then
                    table.insert(curPack.marks, {
                        icon = parts[3] or "", mob = parts[4] or "", tank = parts[5] or "",
                    })
                end
            elseif tag == "X" and parts[2] and parts[2] ~= "" then
                local boss = parts[2]
                plan.strats[boss] = (plan.strats[boss] or "")
                    .. ((plan.strats[boss] and plan.strats[boss] ~= "") and "\n" or "")
                    .. (parts[3] or "")
            elseif tag == "END" then
                curPack = nil
            end
        end
    end
    -- sans en-tête OFP1 ce n'est pas un plan (ex. bloc de schémas OS1 qui
    -- contient aussi des lignes R|... et A|...)
    if not seenHdr then return nil end
    if plan.title == "" and table.getn(plan.bossOrder) == 0 and table.getn(plan.rosterOrder) == 0 then
        return nil
    end
    return plan
end

-- Neutralise les séparateurs dans une valeur saisie en jeu (Boss PUG...)
local function Clean(s)
    return (string.gsub(tostring(s or ""), "[|;\r\n]", ","))
end

local function SerializeOFP(plan)
    local L = {}
    table.insert(L, table.concat({ "OFP1", Clean(plan.title), Clean(plan.raid), Clean(plan.date) }, "|"))
    for _, name in ipairs(plan.rosterOrder or {}) do
        local r = plan.roster and plan.roster[name]
        if r then
            table.insert(L, table.concat({ "R", Clean(r.role ~= "" and r.role or "ranged"), Clean(name),
                Clean(r.class), Clean(r.spec),
                r.group and r.group > 0 and tostring(r.group) or "" }, "|"))
        end
    end
    for _, boss in ipairs(plan.bossOrder or {}) do
        for poste, slot in pairs((plan.assign and plan.assign[boss]) or {}) do
            table.insert(L, table.concat({ "A", Clean(boss), Clean(poste), Clean(slot.player), Clean(slot.task) }, "|"))
        end
    end
    -- Strats (X) : TOUS les boss qui ont un texte (le site exporte les X meme
    -- pour un boss sans assignation, absent de bossOrder).
    local sb, seenS = {}, {}
    for _, boss in ipairs(plan.bossOrder or {}) do table.insert(sb, boss); seenS[boss] = true end
    local extra = {}
    for boss in pairs(plan.strats or {}) do
        if not seenS[boss] then table.insert(extra, boss) end
    end
    table.sort(extra)
    for _, boss in ipairs(extra) do table.insert(sb, boss) end
    for _, boss in ipairs(sb) do
        local strat = plan.strats and plan.strats[boss]
        if strat and strat ~= "" then
            for line in string.gfind(strat .. "\n", "([^\n]*)\n") do
                if line ~= "" then
                    table.insert(L, table.concat({ "X", Clean(boss), Clean(line) }, "|"))
                end
            end
        end
    end
    for _, pack in ipairs(plan.trash or {}) do
        for _, m in ipairs(pack.marks or {}) do
            table.insert(L, table.concat({ "T", Clean(pack.name ~= "" and pack.name or "Pack"),
                Clean(m.icon), Clean(m.mob), Clean(m.tank) }, "|"))
        end
    end
    table.insert(L, "END")
    return table.concat(L, "\n")
end

-- ============================================================
-- Stockage
-- ============================================================

-- Plan stocké corrompu (collage 1.12 avec "|" doublés, ancien parseur) :
-- rôle invalide (roster indexé par "tank"/"heal"...), strats rangées sous la
-- clé "", ou marque de trash dont l'icône n'est pas une marque de raid.
local function PlanIsCorrupt(p)
    if type(p) ~= "table" then return true end
    for _, name in ipairs(p.rosterOrder or {}) do
        local r = p.roster and p.roster[name]
        if type(r) ~= "table" or not ROLE_OK[r.role or ""] then return true end
    end
    if p.strats and p.strats[""] ~= nil then return true end
    for _, pk in ipairs(p.trash or {}) do
        for _, m in ipairs(pk.marks or {}) do
            if m.icon and m.icon ~= "" and not ICON_IDX[m.icon] then return true end
        end
    end
    return false
end

local function PurgeCorruptPlan()
    local db = RT.Store.DB()
    if db.octofan ~= nil and PlanIsCorrupt(db.octofan) then
        db.octofan = nil
        RT.Store.Notify("octofan")
        RT.Print("|cffff6060OctoFan|r: ancien plan local corrompu (collage avec || doublés) purgé — réimporte-le depuis le site (💾 Fichier addon).")
        return true
    end
    return false
end

local RefreshMyWindow
local MaybeAutoSend -- (défini juste en dessous — upvalue, pas de global)

local function ApplyPlan(plan, source)
    local db = RT.Store.DB()
    db.octofan = plan
    RT.Store.Notify("octofan")
    if OF.myOpen and OF.myOpen() then RefreshMyWindow() end
    MaybeAutoSend(source)
end

-- Plan modifié EN JEU (assignations changées par ce joueur) : un plan qui arrive (fichier, collage,
-- relay du chef) ne l'écrase pas en silence ; on demande. La date du plan sert de version.
local pendingPlan = nil
local function PlanBrief(p)
    local d = (p.date and p.date ~= "") and (" du " .. p.date) or ""
    return "« " .. ((p.title and p.title ~= "") and p.title or "sans titre") .. " »" .. d
end

StaticPopupDialogs["RT_OCTOFAN_OVERWRITE"] = {
    text = "%s",
    button1 = "Remplacer",
    button2 = "Garder le mien",
    OnAccept = function()
        local p = pendingPlan
        pendingPlan = nil
        if p then
            ApplyPlan(p.plan, p.source)
            RT.Print("|cff33ccffOctoFan|r: plan remplacé par " .. PlanBrief(p.plan) .. ".")
        end
    end,
    OnCancel = function()
        pendingPlan = nil
        RT.Print("|cff33ccffOctoFan|r: plan reçu ignoré, le tien est conservé.")
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
}

-- Resume lisible des differences entre l'ancien plan et le nouveau (assignations surtout). Retourne les lignes (8 max) et le total.
local function PlanDiff(old, new)
    local L, n = {}, 0
    local function add(t) n = n + 1; if n <= 8 then table.insert(L, t) end end
    if not old or not new then return L, 0 end
    local seen = {}
    for _, boss in ipairs(new.bossOrder or {}) do
        seen[boss] = true
        local a = old.assign and old.assign[boss]
        local b = (new.assign and new.assign[boss]) or {}
        if not a then
            add("+ " .. boss .. " (nouveau boss)")
        else
            for poste, slot in pairs(b) do
                local o = a[poste]
                local np = slot.player or ""
                if not o then
                    add(boss .. " — " .. poste .. " : " .. np .. " (nouveau poste)")
                elseif (o.player or "") ~= np then
                    add(boss .. " — " .. poste .. " : " .. ((o.player or "") ~= "" and o.player or "libre") .. " -> " .. (np ~= "" and np or "libre"))
                end
            end
            for poste in pairs(a) do
                if not b[poste] then add(boss .. " — " .. poste .. " retiré") end
            end
        end
        local sa = old.strats and old.strats[boss] or ""
        local sb = new.strats and new.strats[boss] or ""
        if sa ~= sb then add("stratégie modifiée : " .. boss) end
    end
    for _, boss in ipairs(old.bossOrder or {}) do
        if not seen[boss] then add("- " .. boss .. " (boss retiré)") end
    end
    if (old.title or "") ~= (new.title or "") then
        add("titre : « " .. (old.title or "") .. " » -> « " .. (new.title or "") .. " »")
    end
    if table.getn(old.rosterOrder or {}) ~= table.getn(new.rosterOrder or {}) then
        add("joueurs : " .. table.getn(old.rosterOrder or {}) .. " -> " .. table.getn(new.rosterOrder or {}))
    end
    if n > 8 then table.insert(L, "(+ " .. (n - 8) .. " autres différences)") end
    return L, n
end

-- Faut-il demander avant d'appliquer ce plan ? Toujours si le plan local a ete modifie en jeu ; pour un plan recu du chef,
-- selon le reglage db.octofanUI.confirmRelay (defaut : OUI pour RaidTools complet, NON pour la version Membre).
local function ConfirmWanted(cur, source)
    if cur.localEdit then return true end
    if source == "relay" and not RT.isMember then
        local ui = RT.Store.DB().octofanUI
        return not (ui and ui.confirmRelay == false)
    end
    return false
end

local function StorePlan(plan, source)
    if PlanIsCorrupt(plan) then return false end
    local cur = RT.Store.DB().octofan
    if cur and ConfirmWanted(cur, source) and SerializeOFP(cur) ~= SerializeOFP(plan) then
        pendingPlan = { plan = plan, source = source }
        local from = ({ file = "du fichier addon", paste = "collé", relay = "envoyé par le chef" })[source] or "reçu"
        local lines, n = PlanDiff(cur, plan)
        local txt = "Plan " .. from .. " : " .. PlanBrief(plan)
        if cur.localEdit then txt = txt .. "\n\nTon plan actuel " .. PlanBrief(cur) .. " a été modifié en jeu." end
        if table.getn(lines) > 0 then
            txt = txt .. "\n\nDifférences avec ton plan :\n" .. table.concat(lines, "\n")
        end
        txt = txt .. "\n\nL'appliquer ?"
        StaticPopup_Show("RT_OCTOFAN_OVERWRITE", txt)
        OF.lastRecv = { at = GetTime and GetTime() or 0, ok = false, why = "en attente de confirmation" }
        return false, "pending"
    end
    ApplyPlan(plan, source)
    return true
end

-- Diffusion auto : plan importé (fichier/collage) par le leader EN RAID
-- -> envoyé aux autres RaidTools sans clic. Jamais pour un plan reçu en
-- relay (écho infini sinon). Désactivable (db.octofanUI.autoSend=false).
function MaybeAutoSend(source)
    if source == "relay" then return end
    local db = RT.Store.DB()
    if db.octofanUI and db.octofanUI.autoSend == false then return end
    if (GetNumRaidMembers() or 0) == 0 then return end
    local lead = false
    if IsRaidLeader and (IsRaidLeader() or IsRaidOfficer()) then lead = true end
    if IsPartyLeader and IsPartyLeader() then lead = true end
    if not lead then return end
    local f = CreateFrame("Frame")
    local t = 0
    f:SetScript("OnUpdate", function()
        t = t + arg1
        if t < 3 then return end
        f:SetScript("OnUpdate", nil)
        if (GetNumRaidMembers() or 0) > 0 and OF.SendToRaid then
            OF.SendToRaid()
            RT.Print("|cff33ccffOctoFan|r: diffusion auto du plan au raid.")
        end
    end)
end

local function GetPlan()
    local db = RT.Store.DB()
    return db.octofan
end

-- Le joueur "me" figure-t-il dans "Nom1, Nom2" ? comparaison EXACTE (un find
-- plain faisait matcher "Ana" dans "Banana" / "Bob" dans "Bobby").
local function HasName(list, me)
    if not list or list == "" or not me or me == "" then return false end
    me = string.lower(me)
    for tok in string.gfind(list .. ",", "%s*([^,]-)%s*,") do
        if string.lower(tok) == me then return true end
    end
    return false
end
function OF.HasName(list, me) return HasName(list, me) end

-- ============================================================
-- Relay raid (chunks hexa, enveloppe ":")
-- ============================================================

local function SplitChunks(text)
    local chunks = {}
    local i = 1
    while i <= string.len(text) do
        table.insert(chunks, string.sub(text, i, i + CHUNK_SIZE - 1))
        i = i + CHUNK_SIZE
    end
    if table.getn(chunks) == 0 then chunks = { "" } end
    return chunks
end

local function ChannelFor()
    if GetNumRaidMembers() > 0 then return "RAID" end
    if GetNumPartyMembers() > 0 then return "PARTY" end
    return nil
end

local incoming = nil
local sendQueue = nil
local sendFrame = nil

-- Les receveurs ignorent tout expediteur qui n'est pas chef/assistant : inutile (et
-- trompeur : "envoi termine") d'emettre si on ne l'est pas.
local function CanBroadcast()
    if (GetNumRaidMembers() or 0) > 0 then
        return (IsRaidLeader and IsRaidLeader()) and true or (IsRaidOfficer and IsRaidOfficer()) and true or false
    end
    return (IsPartyLeader and IsPartyLeader()) and true or false
end

local function StartRelay(texts)
    if type(texts) ~= "table" then texts = { texts } end
    if not CanBroadcast() then
        RT.Print("|cff33ccffOctoFan|r: seul le chef ou un assistant peut envoyer le plan au groupe.")
        return
    end
    local channel = ChannelFor()
    if not channel then
        RT.Print("|cff33ccffOctoFan|r: pas de groupe — les autres joueurs ne peuvent pas recevoir (importe par fichier ou collage).")
        return
    end
    -- payloads filtrés (plan, schémas...)
    local payloads = {}
    for i = 1, table.getn(texts) do
        if type(texts[i]) == "string" and texts[i] ~= "" then
            table.insert(payloads, texts[i])
        end
    end
    if table.getn(payloads) == 0 then return end
    local nPackets = 0
    for i = 1, table.getn(payloads) do nPackets = nPackets + math.ceil(string.len(payloads[i]) / CHUNK_SIZE) end
    RT.Print("|cff33ccffOctoFan|r: envoi de " .. nPackets .. " paquets sur " .. channel .. " (~" .. math.ceil(nPackets * CHUNK_DELAY) ..
        " s) — le destinataire doit être dans le même groupe/raid et te voir chef ou assistant.")
    OF.lastSend = { at = GetTime and GetTime() or 0, packets = nPackets, channel = channel }
    local session = string.sub(tostring(math.random(1000, 9999)) .. UnitName("player"), 1, 8)
    local chunks = SplitChunks(payloads[1])
    sendQueue = { payloads = payloads, pi = 1, id = session,
        chunks = chunks, total = table.getn(chunks), i = 1, channel = channel, sentAll = 0 }
    if not sendFrame then sendFrame = CreateFrame("Frame") end
    sendFrame:SetScript("OnUpdate", function()
        if not sendQueue then
            this:SetScript("OnUpdate", nil)
            return
        end
        this.tick = (this.tick or 0) + arg1
        if this.tick < CHUNK_DELAY then return end
        this.tick = 0
        local q = sendQueue
        if q.i > q.total then
            -- payload suivant (plan PUIS schémas), nouvelle session
            q.pi = q.pi + 1
            if q.pi > table.getn(q.payloads) then
                this:SetScript("OnUpdate", nil)
                RT.Print("|cff33ccffOctoFan|r: envoi terminé — " ..
                    table.getn(q.payloads) .. " bloc(s), " .. q.sentAll .. " paquets.")
                sendQueue = nil
                return
            end
            q.id = string.sub(tostring(math.random(1000, 9999)) .. UnitName("player"), 1, 8)
            q.chunks = SplitChunks(q.payloads[q.pi])
            q.total = table.getn(q.chunks)
            q.i = 1
            return
        end
        SendAddonMessage(OFP_PREFIX, q.id .. ":" .. q.i .. ":" .. q.total .. ":" .. HexEnc(q.chunks[q.i]), q.channel)
        q.i = q.i + 1
        q.sentAll = q.sentAll + 1
    end)
end

-- Seuls le chef/les assistants (RAID) ou le chef de groupe (PARTY) peuvent
-- pousser un plan : sinon n'importe quel membre (ou un inconnu en WHISPER/
-- GUILD) écrase le plan de tout le monde.
local function SenderIsLead(name, dist)
    if not name or name == "" then return false end
    if dist == "RAID" then
        for i = 1, (GetNumRaidMembers() or 0) do
            local rn, rank = GetRaidRosterInfo(i)
            if rn == name then return (rank or 0) >= 1 end
        end
    elseif dist == "PARTY" then
        for i = 1, (GetNumPartyMembers() or 0) do
            if UnitName("party" .. i) == name then
                return UnitIsPartyLeader("party" .. i) and true or false
            end
        end
    end
    return false
end

local MAX_PARTS = 400          -- 400 x 110 car. = 44 Ko max par bloc
local sessions = {}            -- [expéditeur] = { id, total, parts, got }

local relayFrame = CreateFrame("Frame")
relayFrame:RegisterEvent("CHAT_MSG_ADDON")
relayFrame:SetScript("OnEvent", function()
    if event ~= "CHAT_MSG_ADDON" or arg1 ~= OFP_PREFIX then return end
    local msg, dist, sender = arg2, arg3, arg4
    if not msg or not sender or sender == UnitName("player") then return end
    if not SenderIsLead(sender, dist) then return end
    -- NB : string.gfind ne gere PAS l ancre ^ en Lua 5.0 (caractere litteral) -> string.find
    local _, _, id, idx, total, rest = string.find(msg, "^([^:]*):([^:]*):([^:]*):(.*)$")
    if not id or id == "" or not rest then return end
    idx, total = tonumber(idx), tonumber(total)
    if not idx or not total then return end
    if total < 1 or total > MAX_PARTS or idx < 1 or idx > total then return end
    if idx ~= math.floor(idx) or total ~= math.floor(total) then return end
    local s = sessions[sender]
    if not s or s.id ~= id then
        s = { id = id, total = total, parts = {}, got = 0, last = GetTime() }
        sessions[sender] = s
        if total > 3 then
            RT.Print("|cff33ccffOctoFan|r: réception de " .. sender .. " en cours (" .. total .. " paquets)...")
        end
    end
    if total ~= s.total then return end
    s.last = GetTime()
    if not s.parts[idx] then
        s.parts[idx] = HexDec(rest)
        s.got = s.got + 1
    end
    if s.got < s.total then return end
    sessions[sender] = nil
    local full = table.concat(s.parts, "", 1, s.total)
    local from = sender
    if string.sub(full, 1, 4) == "OS1|" then
        -- bloc schémas : à tester AVANT ParseOFP (il contient des lignes R|/A|)
        if RT4 and RT4.ParseSchemas then
            local n = RT4.ParseSchemas(full)
            if n and n > 0 then
                RT.Print("|cff33ccffOctoFan|r: schémas reçus de " .. (from or "?") ..
                    " (" .. n .. " éléments) — page Raid à jour.")
                if RT4.RaidRefresh then RT4.RaidRefresh() end
            end
        end
        return
    end
    local plan = ParseOFP(full)
    local before = RT.Store.DB().octofan          -- l'ancien plan (StorePlan en pose un nouveau)
    local okRelay, whyRelay = nil, nil
    if plan then okRelay, whyRelay = StorePlan(plan, "relay") end
    if okRelay then
        RT.Print("|cff33ccffOctoFan|r: plan reçu de " .. (from or "?") ..
            " — \"" .. (plan.title or "?") .. "\" (" .. table.getn(plan.rosterOrder) ..
            " joueurs, " .. table.getn(plan.bossOrder) .. " boss).")
        local lines, n = PlanDiff(before, plan)
        if before and n > 0 then
            RT.Print("|cff33ccffOctoFan|r: " .. n .. " différence(s) avec ton ancien plan :")
            for i = 1, table.getn(lines) do RT.Print("   " .. lines[i]) end
        elseif before then
            RT.Print("|cff33ccffOctoFan|r: identique à ton plan actuel (rien à changer).")
        end
        OF.lastRecv = { at = GetTime(), from = from, ok = true }
    elseif plan and whyRelay == "pending" then
        RT.Print("|cff33ccffOctoFan|r: plan reçu de " .. (from or "?") .. " — en attente de ta confirmation.")
        OF.lastRecv = { at = GetTime(), from = from, ok = false, why = "en attente de confirmation" }
    elseif not plan then
        RT.Print("|cffff6060OctoFan|r: bloc reçu de " .. (from or "?") .. " illisible (ignoré).")
        OF.lastRecv = { at = GetTime(), from = from, ok = false, why = "illisible" }
    end
end)

-- Reception interrompue (paquets perdus) : on le dit au lieu de rester muet.
local stallFrame = CreateFrame("Frame")
stallFrame:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + arg1
    if this.t < 3 then return end
    this.t = 0
    local now = GetTime()
    for who, s in pairs(sessions) do
        if s.last and now - s.last > 20 then
            RT.Print("|cffff6060OctoFan|r: réception de " .. who .. " interrompue (" .. s.got .. "/" .. s.total ..
                " paquets) — demande un nouvel envoi.")
            OF.lastRecv = { at = now, from = who, ok = false, why = "interrompue " .. s.got .. "/" .. s.total }
            sessions[who] = nil
        end
    end
end)

SLASH_RTRELAY1 = "/rtrelay"
SlashCmdList["RTRELAY"] = function()
    local now = GetTime()
    local nr, np = GetNumRaidMembers() or 0, GetNumPartyMembers() or 0
    RT.Print("|cff33ccffOctoFan|r relais : " .. (nr > 0 and ("raid de " .. nr) or (np > 0 and ("groupe de " .. (np + 1)) or "PAS DE GROUPE")) ..
        " — je peux envoyer : " .. (CanBroadcast() and "oui" or "non (chef/assistant requis)"))
    if OF.lastSend then
        RT.Print("   dernier envoi : il y a " .. math.floor(now - OF.lastSend.at) .. " s, " .. OF.lastSend.packets .. " paquets sur " .. OF.lastSend.channel)
    else
        RT.Print("   aucun envoi depuis la connexion.")
    end
    if OF.lastRecv then
        RT.Print("   dernière réception : il y a " .. math.floor(now - OF.lastRecv.at) .. " s de " .. tostring(OF.lastRecv.from or "?") ..
            " — " .. (OF.lastRecv.ok and "appliquée" or ("non appliquée (" .. tostring(OF.lastRecv.why) .. ")")))
    else
        RT.Print("   rien reçu depuis la connexion.")
    end
    local k = 0
    for who, s in pairs(sessions) do k = k + 1; RT.Print("   en cours : " .. who .. " " .. s.got .. "/" .. s.total) end
    if k == 0 then RT.Print("   aucune réception en cours.") end
end

-- ============================================================
-- Boot : fichier RT_OctoFanData.lua (téléchargé du site)
-- ============================================================

local function Sig(s)
    local h = 0
    for i = 1, string.len(s) do
        h = math.mod(h * 31 + string.byte(s, i), 2147483647)
    end
    return string.len(s) .. ":" .. h
end

local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("PLAYER_LOGIN")
bootFrame:SetScript("OnEvent", function()
    PurgeCorruptPlan()
    -- signature du fichier : on ne ré-importe (donc on n'écrase ni les éditions
    -- Boss PUG ni un plan reçu du chef, ni ne ré-émet au raid) que s'il a changé
    local sig = RT_OCTOFAN_IMPORT and RT_OCTOFAN_IMPORT ~= "" and Sig(RT_OCTOFAN_IMPORT) or nil
    local dbu = RT.Store.DB()
    dbu.octofanUI = dbu.octofanUI or {}
    if sig and dbu.octofanUI.fileSig == sig then
        RT_OCTOFAN_IMPORT = nil
    end
    if RT_OCTOFAN_IMPORT and RT_OCTOFAN_IMPORT ~= "" then
        local plan = ParseOFP(RT_OCTOFAN_IMPORT)
        local okFile, whyFile
        if plan then okFile, whyFile = StorePlan(plan, "file") end
        if plan and whyFile == "pending" then
            -- la question est posée : on ne la reposera pas à chaque connexion pour ce fichier
            dbu.octofanUI.fileSig = sig
        elseif okFile then
            dbu.octofanUI.fileSig = sig
            RT.Print("|cff33ccffOctoFan|r: plan chargé depuis le fichier addon — \"" ..
                (plan.title or "?") .. "\" (" .. table.getn(plan.rosterOrder) ..
                " joueurs, " .. table.getn(plan.bossOrder) .. " boss).")
        else
            RT.Print("|cffff6060OctoFan|r: RT_OctoFanData.lua illisible — regénère-le depuis le site (bouton 💾).")
        end
        RT_OCTOFAN_IMPORT = nil
        -- Push trash vers AutoMarkerOW après son init
        local f2 = CreateFrame("Frame")
        local t2 = 0
        f2:SetScript("OnUpdate", function()
            t2 = t2 + arg1
            if t2 < 5 then return end
            f2:SetScript("OnUpdate", nil)
            -- Mode Guilde seulement : en PUG les marks trash du plan ne
            -- s'imposent pas (push manuel via le bouton 🎯 Trash->AM).
            if not IsGuildMode() then return end
            if AMOW_ImportExternalRules and OF.PushTrash then OF.PushTrash(true) end
        end)
    end
end)

-- ============================================================
-- Assignations du boss (comme le site) : lues par tous, modifiables a tout
-- moment par le chef de raid / les assistants (diffusees au raid)
-- ============================================================

local ASSIGN_PREFIX = "OFPA"

local function CleanField(s)
    s = tostring(s or "")
    s = string.gsub(s, "[|;\n\r]", ",")
    return s
end

local function TrimStr(s)
    s = tostring(s or "")
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    return s
end

-- boss courant : boss en cours (module legacy), sinon la cible si c'est un boss du plan
function OF.CurrentBoss()
    local plan = RT.Store.DB().octofan
    if not plan or not plan.assign then return nil end
    if RT_BOSS_STATE and RT_BOSS_STATE.bossName and RT_BOSS_STATE.bossName ~= "" and plan.assign[RT_BOSS_STATE.bossName] then
        return RT_BOSS_STATE.bossName
    end
    local tn = nil
    if UnitExists("target") then tn = UnitName("target") end
    if tn and tn ~= "" then
        local low = string.lower(tn)
        for _, boss in ipairs(plan.bossOrder or {}) do
            local bl = string.lower(boss)
            if bl == low or string.find(bl, low, 1, true) or string.find(low, bl, 1, true) then
                return boss
            end
        end
    end
    return nil
end

-- Qui peut changer une assignation : chef/assistant en raid, chef de groupe en groupe ;
-- seul (hors groupe) : un officier RaidTools (la modification reste locale).
function OF.CanEditAssign()
    if (GetNumRaidMembers() or 0) > 0 then
        if IsRaidLeader and IsRaidLeader() then return true end
        if IsRaidOfficer and IsRaidOfficer() then return true end
        return false
    end
    if (GetNumPartyMembers() or 0) > 0 then
        if IsPartyLeader and IsPartyLeader() then return true end
        return false
    end
    if RT4 and RT4.CanUse and RT4.CanUse("whisperbot") then return true end
    return false
end

-- applique une assignation dans le plan local (poste libre : joueur vide)
local function SetAssign(boss, poste, player, task)
    local plan = GetPlan()
    if not plan or not boss or boss == "" or not poste or poste == "" then return false end
    plan.assign = plan.assign or {}
    plan.bossOrder = plan.bossOrder or {}
    if not plan.assign[boss] then
        plan.assign[boss] = {}
        table.insert(plan.bossOrder, boss)
    end
    local old = plan.assign[boss][poste]
    plan.assign[boss][poste] = { player = player or "", task = task or (old and old.task) or "" }
    RT.Store.Notify("octofan")
    if OF.myOpen and OF.myOpen() then RefreshMyWindow() end
    if RT4 and RT4.RaidRefresh then RT4.RaidRefresh() end
    return true
end

function OF.SendAssign(boss, poste, player, task)
    local ch = nil
    if (GetNumRaidMembers() or 0) > 0 then
        ch = "RAID"
    elseif (GetNumPartyMembers() or 0) > 0 then
        ch = "PARTY"
    end
    if not ch then return end
    SendAddonMessage(ASSIGN_PREFIX, "A|" .. CleanField(boss) .. "|" .. CleanField(poste) .. "|" ..
        CleanField(player) .. "|" .. CleanField(task), ch)
end

-- changement fait par ce joueur : droit verifie, applique, diffuse
function OF.ChangeAssign(boss, poste, player)
    if not OF.CanEditAssign() then
        RT.Print("|cff33ccffOctoFan|r: seuls le chef de raid et les assistants peuvent changer une assignation.")
        return false
    end
    player = TrimStr(player)
    local plan = GetPlan()
    local old = plan and plan.assign and plan.assign[boss] and plan.assign[boss][poste]
    local task = old and old.task or ""
    if SetAssign(boss, poste, player, task) then
        plan.localEdit = true
        OF.SendAssign(boss, poste, player, task)
        RT.Print("|cff33ccffOctoFan|r: " .. boss .. " — " .. poste .. " → " .. (player ~= "" and player or "libre") .. ".")
        return true
    end
    return false
end

-- reception : uniquement du chef / d'un assistant du raid (ou chef de groupe)
local assignFrame = CreateFrame("Frame")
assignFrame:RegisterEvent("CHAT_MSG_ADDON")
assignFrame:SetScript("OnEvent", function()
    if event ~= "CHAT_MSG_ADDON" or arg1 ~= ASSIGN_PREFIX then return end
    local msg, dist, sender = arg2, arg3, arg4
    if not msg or not sender or sender == UnitName("player") then return end
    if not SenderIsLead(sender, dist) then return end
    local _, _, boss, poste, player, task = string.find(msg, "^A|([^|]*)|([^|]*)|([^|]*)|(.*)$")
    if not boss or boss == "" or not poste or poste == "" then return end
    if SetAssign(boss, poste, player or "", task or "") then
        RT.Print("|cff33ccffOctoFan|r: " .. sender .. " a changé " .. boss .. " — " .. poste .. " → " ..
            ((player and player ~= "") and player or "libre") .. ".")
    end
end)

-- ============================================================
-- Fenêtre "Mon rôle" : tableau des assignations du boss (comme le site),
-- puis la strat et mes marques de trash. Redimensionnable, taille mémorisée.
-- ============================================================

local myFrame, myText
local BOARD_ROWS = 14
local boardRows = {}
local boardTitle, boardPrev, boardNext
local editFrame, editBox, editLbl

local function BossList(plan)
    local out, seen = {}, {}
    for _, b in ipairs(plan.bossOrder or {}) do
        if not seen[b] then seen[b] = true; table.insert(out, b) end
    end
    for b in pairs(plan.assign or {}) do
        if not seen[b] then seen[b] = true; table.insert(out, b) end
    end
    return out
end

local function ApplyEdit()
    if editFrame and editFrame.boss then
        OF.ChangeAssign(editFrame.boss, editFrame.poste, editBox:GetText())
        editFrame:Hide()
    end
end

local function OpenEditor(boss, poste, who)
    if not editFrame then
        editFrame = CreateFrame("Frame", "RT_OctoFanAssignEdit", UIParent)
        editFrame:SetWidth(300)
        editFrame:SetHeight(112)
        editFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        editFrame:SetFrameStrata("DIALOG")
        editFrame:EnableMouse(true)
        editFrame:SetMovable(true)
        editFrame:RegisterForDrag("LeftButton")
        editFrame:SetScript("OnDragStart", function() editFrame:StartMoving() end)
        editFrame:SetScript("OnDragStop", function() editFrame:StopMovingOrSizing() end)
        editFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        editFrame:SetBackdropColor(0.03, 0.03, 0.07, 0.96)
        editFrame:SetBackdropBorderColor(0.7, 0.55, 0.2, 0.9)
        editLbl = editFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        editLbl:SetPoint("TOPLEFT", editFrame, "TOPLEFT", 10, -10)
        editLbl:SetWidth(280)
        editLbl:SetJustifyH("LEFT")
        local hint = editFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", editFrame, "TOPLEFT", 10, -30)
        hint:SetText("|cff999999Nom du joueur (vide = poste libre)|r")
        editBox = CreateFrame("EditBox", "RT_OctoFanAssignEditBox", editFrame, "InputBoxTemplate")
        editBox:SetWidth(200)
        editBox:SetHeight(20)
        editBox:SetPoint("TOPLEFT", editFrame, "TOPLEFT", 16, -46)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(24)
        editBox:SetScript("OnEnterPressed", function() ApplyEdit() end)
        editBox:SetScript("OnEscapePressed", function() editFrame:Hide() end)
        local ok = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
        ok:SetWidth(90)
        ok:SetHeight(22)
        ok:SetText("Appliquer")
        ok:SetPoint("BOTTOMLEFT", editFrame, "BOTTOMLEFT", 10, 10)
        ok:SetScript("OnClick", function() ApplyEdit() end)
        local free = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
        free:SetWidth(90)
        free:SetHeight(22)
        free:SetText("Libre")
        free:SetPoint("LEFT", ok, "RIGHT", 6, 0)
        free:SetScript("OnClick", function() editBox:SetText(""); ApplyEdit() end)
        local cancel = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
        cancel:SetWidth(90)
        cancel:SetHeight(22)
        cancel:SetText("Annuler")
        cancel:SetPoint("LEFT", free, "RIGHT", 6, 0)
        cancel:SetScript("OnClick", function() editFrame:Hide() end)
        editFrame:Hide()
    end
    editFrame.boss, editFrame.poste = boss, poste
    editLbl:SetText(boss .. " — " .. poste)
    editBox:SetText(who or "")
    editFrame:Show()
    editBox:SetFocus()
end

local function CycleBoss(dir)
    local plan = GetPlan()
    if not plan then return end
    local list = BossList(plan)
    local n = table.getn(list)
    if n == 0 then return end
    local idx = 1
    for i = 1, n do
        if list[i] == OF.boardBoss then idx = i end
    end
    idx = idx + dir
    if idx < 1 then idx = n end
    if idx > n then idx = 1 end
    OF.boardBoss = list[idx]
    RefreshMyWindow()
end

local function BuildMyWindow()
    if myFrame then return end
    myFrame = CreateFrame("Frame", "RT_OctoFanMyRole", UIParent)
    myFrame:SetResizable(true)
    myFrame:SetMinResize(320, 260)
    myFrame:SetMaxResize(760, 700)
    local db = RT.Store.DB()
    db.octofanUI = db.octofanUI or {}
    if db.octofanUI.myRoleW then myFrame:SetWidth(db.octofanUI.myRoleW) end
    if db.octofanUI.myRoleH then myFrame:SetHeight(db.octofanUI.myRoleH) end
    if not db.octofanUI.myRoleW then myFrame:SetWidth(400) end
    if not db.octofanUI.myRoleH then myFrame:SetHeight(420) end
    myFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    myFrame:SetFrameStrata("HIGH")
    myFrame:EnableMouse(true)
    myFrame:SetMovable(true)
    myFrame:RegisterForDrag("LeftButton")
    myFrame:SetScript("OnDragStart", function() myFrame:StartMoving() end)
    myFrame:SetScript("OnDragStop", function() myFrame:StopMovingOrSizing() end)
    myFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    myFrame:SetBackdropColor(0.02, 0.02, 0.05, 0.75)
    myFrame:SetBackdropBorderColor(0.35, 0.3, 0.15, 0.55)

    local title = myFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", myFrame, "TOPLEFT", 8, -6)
    title:SetText("|cff33ccffOctoFan|r — Assignations")

    local closeBtn = CreateFrame("Button", nil, myFrame, "UIPanelButtonTemplate")
    closeBtn:SetWidth(20)
    closeBtn:SetHeight(16)
    closeBtn:SetText("X")
    closeBtn:SetPoint("TOPRIGHT", myFrame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() myFrame:Hide() end)

    -- barre boss : < nom du boss >
    boardPrev = CreateFrame("Button", nil, myFrame, "UIPanelButtonTemplate")
    boardPrev:SetWidth(22)
    boardPrev:SetHeight(16)
    boardPrev:SetText("<")
    boardPrev:SetPoint("TOPLEFT", myFrame, "TOPLEFT", 8, -24)
    boardPrev:SetScript("OnClick", function() CycleBoss(-1) end)
    boardNext = CreateFrame("Button", nil, myFrame, "UIPanelButtonTemplate")
    boardNext:SetWidth(22)
    boardNext:SetHeight(16)
    boardNext:SetText(">")
    boardNext:SetPoint("LEFT", boardPrev, "RIGHT", 2, 0)
    boardNext:SetScript("OnClick", function() CycleBoss(1) end)
    boardTitle = myFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    boardTitle:SetPoint("LEFT", boardNext, "RIGHT", 8, 0)
    boardTitle:SetJustifyH("LEFT")

    -- lignes du tableau : poste | joueur | tache
    for i = 1, BOARD_ROWS do
        local row = CreateFrame("Button", nil, myFrame)
        row:SetHeight(15)
        row:SetPoint("TOPLEFT", myFrame, "TOPLEFT", 8, -(46 + (i - 1) * 15))
        row:SetPoint("RIGHT", myFrame, "RIGHT", -8, 0)
        row:EnableMouse(true)
        row:RegisterForClicks("LeftButtonUp")
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row:GetHighlightTexture():SetAlpha(0.25)
        row.pFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.pFS:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.pFS:SetWidth(96)
        row.pFS:SetJustifyH("LEFT")
        row.wFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.wFS:SetPoint("LEFT", row, "LEFT", 102, 0)
        row.wFS:SetWidth(130)
        row.wFS:SetJustifyH("LEFT")
        row.tFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.tFS:SetPoint("LEFT", row, "LEFT", 236, 0)
        row.tFS:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        row.tFS:SetJustifyH("LEFT")
        row:SetScript("OnClick", function()
            if not row.boss then return end
            if OF.CanEditAssign() then
                OpenEditor(row.boss, row.poste, row.who)
            elseif row.who and row.who ~= "" and TargetByName then
                local _, _, first = string.find(row.who, "^%s*([^,]+)")
                if first then TargetByName(first) end
            end
        end)
        row:SetScript("OnEnter", function()
            if not row.boss then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            if OF.CanEditAssign() then
                GameTooltip:SetText("Clic : changer le joueur", 1, 0.9, 0.6)
            else
                GameTooltip:SetText("Clic : cibler le joueur", 1, 0.9, 0.6)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:Hide()
        table.insert(boardRows, row)
    end

    myText = RT.UI.TextScroll(myFrame, {
        name = "RT_OctoFanMyRoleText",
        anchor = { "TOPLEFT", myFrame, "TOPLEFT", 8, -(46 + BOARD_ROWS * 15 + 6) },
        width = 322, height = 120, font = "GameFontHighlightSmall",
    })
    myText.scroll:ClearAllPoints()
    myText.scroll:SetPoint("TOPLEFT", myFrame, "TOPLEFT", 8, -(46 + BOARD_ROWS * 15 + 6))
    myText.scroll:SetPoint("BOTTOMRIGHT", myFrame, "BOTTOMRIGHT", -6, 6)
    myFrame:SetScript("OnSizeChanged", function()
        local w = myFrame:GetWidth()
        if myText.fs then myText.fs:SetWidth(w - 24) end
        if myText.child then myText.child:SetHeight((myText.fs and myText.fs:GetHeight() or 1) + 20) end
    end)

    local grip = CreateFrame("Button", nil, myFrame)
    grip:SetWidth(16)
    grip:SetHeight(16)
    grip:SetPoint("BOTTOMRIGHT", myFrame, "BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() myFrame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        myFrame:StopMovingOrSizing()
        local d2 = RT.Store.DB()
        d2.octofanUI = d2.octofanUI or {}
        d2.octofanUI.myRoleW = myFrame:GetWidth()
        d2.octofanUI.myRoleH = myFrame:GetHeight()
    end)

    myFrame:Hide()
end

-- ordre d'affichage des postes : Tank, Heal, puis le reste ; numerote dans chaque famille
local function PosteRank(p)
    local low = string.lower(p)
    local r = 5
    if string.find(low, "tank", 1, true) then r = 1
    elseif string.find(low, "heal", 1, true) or string.find(low, "soin", 1, true) then r = 2
    elseif string.find(low, "cac", 1, true) or string.find(low, "melee", 1, true) then r = 3
    elseif string.find(low, "dist", 1, true) or string.find(low, "range", 1, true) then r = 4 end
    return r
end

function RefreshMyWindow()
    BuildMyWindow()
    local plan = GetPlan()
    if not plan then
        for i = 1, BOARD_ROWS do boardRows[i]:Hide() end
        boardTitle:SetText("")
        myText.scroll:ClearAllPoints()
        myText.scroll:SetPoint("TOPLEFT", myFrame, "TOPLEFT", 8, -28)
        myText.scroll:SetPoint("BOTTOMRIGHT", myFrame, "BOTTOMRIGHT", -6, 6)
        myText:SetText("|cff888888Aucun plan OctoFan importé.|r")
        return
    end
    local me = UnitName("player")
    local bosses = BossList(plan)
    local boss = OF.boardBoss
    if not boss or not plan.assign or not plan.assign[boss] then
        boss = OF.CurrentBoss() or bosses[1]
        OF.boardBoss = boss
    end
    local canEdit = OF.CanEditAssign()
    boardTitle:SetText((boss and ("|cffFFCC44" .. boss .. "|r") or "|cff888888aucun boss|r") ..
        (canEdit and "  |cff66CC66(clic = changer)|r" or ""))

    -- tableau : tous les postes du boss, comme le site
    local postes = {}
    for poste in pairs((boss and plan.assign and plan.assign[boss]) or {}) do
        table.insert(postes, poste)
    end
    table.sort(postes, function(a, b)
        local ra, rb = PosteRank(a), PosteRank(b)
        if ra ~= rb then return ra < rb end
        return a < b
    end)
    local n = table.getn(postes)
    for i = 1, BOARD_ROWS do
        local row = boardRows[i]
        local poste = postes[i]
        if poste then
            local slot = plan.assign[boss][poste]
            local who = slot and slot.player or ""
            row.boss, row.poste, row.who = boss, poste, who
            row:Show()
            row.pFS:SetText("|cffFFD700" .. poste .. "|r")
            local mine = HasName(who, me)
            if who == "" then
                row.wFS:SetText("|cff666666— libre —|r")
            elseif mine then
                row.wFS:SetText("|cff66FF66" .. who .. "|r")
            else
                row.wFS:SetText(who)
            end
            row.tFS:SetText("|cff999999" .. ((slot and slot.task and slot.task ~= "") and slot.task or "") .. "|r")
        else
            row.boss = nil
            row:Hide()
        end
    end
    local shownRows = n
    if shownRows > BOARD_ROWS then shownRows = BOARD_ROWS end
    myText.scroll:ClearAllPoints()
    myText.scroll:SetPoint("TOPLEFT", myFrame, "TOPLEFT", 8, -(46 + shownRows * 15 + 8))
    myText.scroll:SetPoint("BOTTOMRIGHT", myFrame, "BOTTOMRIGHT", -6, 6)

    -- dessous : strat du boss + mes marques de trash + mon role
    local L = {}
    if n > BOARD_ROWS then
        table.insert(L, "|cff888888(+" .. (n - BOARD_ROWS) .. " postes non affichés : agrandis la fenêtre ou change de boss)|r")
    end
    local strat = boss and plan.strats and plan.strats[boss]
    if strat and strat ~= "" then
        table.insert(L, "|cff66CCFFStrat :|r")
        for line in string.gfind(strat .. "\n", "([^\n]*)\n") do
            if line ~= "" then table.insert(L, "  |cffBBBBBB" .. line .. "|r") end
        end
    end
    local tCount = 0
    local tl = {}
    for _, pack in ipairs(plan.trash or {}) do
        for _, m in ipairs(pack.marks or {}) do
            if m.tank and string.lower(m.tank) == string.lower(me) then
                tCount = tCount + 1
                table.insert(tl, "  [" .. (MARK_FR[m.icon] or m.icon or "?") .. "] " ..
                    (m.mob ~= "" and m.mob or "mob") .. "  —  " .. (pack.name or ""))
            end
        end
    end
    if tCount > 0 then
        table.insert(L, "")
        table.insert(L, "|cff66CCFFMarques de trash (moi tank) :|r")
        for _, x in ipairs(tl) do table.insert(L, x) end
    end
    local myInfo = plan.roster and plan.roster[me]
    if myInfo then
        table.insert(L, "")
        table.insert(L, "|cff88FF88" .. (ROLE_FR[myInfo.role] or myInfo.role or "?") ..
            (myInfo.group and myInfo.group > 0 and (" · Groupe " .. myInfo.group) or "") ..
            ((myInfo.spec and myInfo.spec ~= "") and (" · " .. myInfo.spec) or "") .. "|r")
    end
    if table.getn(L) == 0 then table.insert(L, "|cff888888Pas de strat pour ce boss.|r") end
    myText:SetText(table.concat(L, "\n"))
end

-- le tableau suit la cible quand la fenetre est ouverte (nouveau boss cible -> son tableau)
local followFrame = CreateFrame("Frame")
followFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
followFrame:SetScript("OnEvent", function()
    if event ~= "PLAYER_TARGET_CHANGED" then return end
    if not (OF.myOpen and OF.myOpen()) then return end
    local cb = OF.CurrentBoss()
    if cb and cb ~= OF.boardBoss then
        OF.boardBoss = cb
        RefreshMyWindow()
    end
end)

-- ============================================================
-- Push trash vers AutoMarkerOW (si installé)
-- ============================================================

function OF.PushTrash(quiet)
    local plan = GetPlan()
    if not plan or table.getn(plan.trash or {}) == 0 then
        if not quiet then RT.Print("|cff33ccffOctoFan|r: aucun pack de trash dans le plan.") end
        return 0
    end
    if not AMOW_ImportExternalRules then
        if not quiet then RT.Print("|cff33ccffOctoFan|r: AutoMarkerOW n'est pas installé — push annulé.") end
        return 0
    end
    local rules, count = {}, 0
    for _, pack in ipairs(plan.trash or {}) do
        for _, m in ipairs(pack.marks or {}) do
            if m.mob and m.mob ~= "" then
                local idx = ICON_IDX[m.icon]
                if idx then
                    rules[m.mob] = idx
                    count = count + 1
                end
            end
        end
    end
    if count == 0 then
        if not quiet then RT.Print("|cff33ccffOctoFan|r: aucune règle valide dans le plan.") end
        return 0
    end
    local zones = RAID_ZONE_EN[plan.raid or ""] or GetRealZoneText()
    local applied = AMOW_ImportExternalRules(
        "octofan-" .. (plan.raid or "plan"),
        "OctoFan: " .. (plan.title or "Raid"),
        zones, rules)
    if not quiet then
        local ztxt = type(zones) == "table" and table.concat(zones, ", ") or tostring(zones)
        RT.Print("|cff33ccffOctoFan|r: " .. applied .. " règle(s) de trash poussée(s) vers AutoMarkerOW (zone: " .. ztxt .. ").")
    end
    return applied
end

-- ============================================================
-- Mode Guild / PUG
-- ============================================================

local function GetMode()
    local db = RT.Store.DB()
    db.octofanUI = db.octofanUI or {}
    return db.octofanUI.mode or "pug"  -- défaut : PUG (le plus courant)
end

local function SetMode(mode)
    local db = RT.Store.DB()
    db.octofanUI = db.octofanUI or {}
    db.octofanUI.mode = mode
    RT.Store.Notify("octofan_mode")
end

function IsGuildMode()
    return GetMode() == "guild"
end

-- Retourne le titre contextuel selon le mode
local function ModeTitle()
    if IsGuildMode() then
        return "|cff33ccffOctoFan|r — |cffFFCC44Guilde|r"
    else
        return "|cff33ccffOctoFan|r — |cffFFCC44PUG|r"
    end
end

-- API publique (Dashboard v3, micro menu v4, slash, tests)
function OF.GetMode() return GetMode() end
function OF.SetMode(m)
    if m == "guild" or m == "pug" then SetMode(m) end
end
function OF.IsGuildMode() return IsGuildMode() end
function OF.ResetPlan()
    local db = RT.Store.DB()
    db.octofan = nil
    RT.Store.Notify("octofan")
    if OF.myOpen and OF.myOpen() then RefreshMyWindow() end
    RT.Print("|cff33ccffOctoFan|r: plan local effacé.")
end
function OF.myOpen() return myFrame and myFrame:IsVisible() end
function OF.ShowMyRole()
    OF.boardBoss = OF.CurrentBoss() or OF.boardBoss
    RefreshMyWindow()
    if myFrame then
        if myFrame:IsVisible() then myFrame:Hide() else myFrame:Show() end
    end
end
function OF.SendToRaid()
    local plan = GetPlan()
    local texts = {}
    if plan then
        table.insert(texts, SerializeOFP(plan))
    end
    local db = RT.Store.DB()
    if db.octofanSchemasRaw and db.octofanSchemasRaw ~= "" then
        table.insert(texts, db.octofanSchemasRaw)
    end
    if table.getn(texts) == 0 then
        RT.Print("|cff33ccffOctoFan|r: rien à envoyer (aucun plan, aucun schéma).")
        return
    end
    StartRelay(texts)
    RT.Print("|cff33ccffOctoFan|r: envoi — plan" ..
        (db.octofanSchemasRaw and db.octofanSchemasRaw ~= "" and " + schémas" or "") .. "...")
end

-- ============================================================
-- Overlay : strat du boss + ton poste (compact, toujours visible)
-- ============================================================

local ovFrame, ovText

local function BuildOverlay()
    if ovFrame then return end
    ovFrame = CreateFrame("Frame", "RT_OctoFanOverlay", UIParent)
    ovFrame:SetWidth(280)
    ovFrame:SetHeight(120)
    ovFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 12, -480)
    ovFrame:SetFrameStrata("MEDIUM")
    ovFrame:EnableMouse(true)
    ovFrame:SetMovable(true)
    ovFrame:RegisterForDrag("LeftButton")
    ovFrame:SetScript("OnDragStart", function() ovFrame:StartMoving() end)
    ovFrame:SetScript("OnDragStop", function() ovFrame:StopMovingOrSizing() end)
    ovFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    ovFrame:SetBackdropColor(0.03, 0.03, 0.06, 0.92)
    ovFrame:SetBackdropBorderColor(0.25, 0.2, 0.1, 1)

    local title = ovFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", ovFrame, "TOPLEFT", 6, -4)
    title:SetText("|cff33ccffOctoFan|r")

    local closeBtn = CreateFrame("Button", nil, ovFrame, "UIPanelButtonTemplate")
    closeBtn:SetWidth(16)
    closeBtn:SetHeight(14)
    closeBtn:SetText("X")
    closeBtn:SetPoint("TOPRIGHT", ovFrame, "TOPRIGHT", -3, -3)
    closeBtn:SetScript("OnClick", function() ovFrame:Hide() end)

    ovText = RT.UI.TextScroll(ovFrame, {
        name = "RT_OctoFanOverlayText",
        anchor = { "TOPLEFT", ovFrame, "TOPLEFT", 6, -18 },
        width = 266, height = 94, font = "GameFontHighlightSmall",
    })
    ovText.scroll:ClearAllPoints()
    ovText.scroll:SetPoint("TOPLEFT", ovFrame, "TOPLEFT", 6, -18)
    ovText.scroll:SetPoint("BOTTOMRIGHT", ovFrame, "BOTTOMRIGHT", -4, 4)
    ovFrame:Hide()
end

local function RefreshOverlay()
    BuildOverlay()
    local plan = GetPlan()
    if not plan or table.getn(plan.bossOrder or {}) == 0 then
        ovFrame:Hide()
        return
    end
    -- Boss en cours : cible hostile OU dernier boss assigné
    local bossName = nil
    if UnitExists("target") and not UnitIsPlayer("target") then
        local tgt = UnitName("target")
        -- matcher avec un boss du plan
        for _, b in ipairs(plan.bossOrder or {}) do
            if string.find(string.lower(b), string.lower(tgt or ""), 1, true)
                or string.lower(b) == string.lower(tgt or "") then
                bossName = b
                break
            end
        end
        -- si pas trouvé exactement, essai partiel
        if not bossName then
            for _, b in ipairs(plan.bossOrder or {}) do
                if string.find(string.lower(tgt or ""), string.lower(string.sub(b, 1, 6)), 1, true) then
                    bossName = b
                    break
                end
            end
        end
    end
    if not bossName then bossName = plan.bossOrder[1] end -- fallback : premier boss

    local me = UnitName("player")
    local L = {}
    table.insert(L, "|cffFFD700" .. bossName .. "|r")
    table.insert(L, "")

    -- Mes assignations pour ce boss
    local postes = (plan.assign or {})[bossName] or {}
    local hasAssign = false
    for poste, slot in pairs(postes) do
        local names = slot.player or ""
        if HasName(names, me) then
            hasAssign = true
            table.insert(L, "|cff66CCFF" .. poste .. "|r" ..
                (slot.task ~= "" and ("  " .. slot.task) or ""))
        end
    end
    if not hasAssign then table.insert(L, "|cff888888Pas d'assignation sur ce boss|r") end
    table.insert(L, "")

    -- Strat (importée du site, X lines)
    local strat = plan.strats and plan.strats[bossName]
    if strat and strat ~= "" then
        table.insert(L, "|cff999999" .. strat .. "|r")
    end

    -- Trash marks pour les packs (mode guilde : mes tanks)
    if IsGuildMode() then
        local trashLines = {}
        for _, pack in ipairs(plan.trash or {}) do
            for _, m in ipairs(pack.marks or {}) do
                if m.tank and string.lower(m.tank) == string.lower(me) then
                    table.insert(trashLines, "[" .. (MARK_FR[m.icon] or "?") .. "] " .. (m.mob or "?"))
                end
            end
        end
        if table.getn(trashLines) > 0 then
            table.insert(L, "")
            table.insert(L, "|cff66CCFFTrash (mes marks) :|r")
            for _, tl in ipairs(trashLines) do table.insert(L, tl) end
        end
    end

    ovText:SetText(table.concat(L, "\n"))
end

-- Slash /rt strat : ouvre l'overlay
function OctoFan_ShowOverlay()
    RefreshOverlay()
    if ovFrame then
        if ovFrame:IsVisible() then ovFrame:Hide() else ovFrame:Show() end
    end
end

-- Auto-refresh de l'overlay toutes les 2s quand visible (target change)
local ovTicker = CreateFrame("Frame")
ovTicker:SetScript("OnUpdate", function()
    if not ovFrame or not ovFrame:IsVisible() then return end
    this.tick = (this.tick or 0) + arg1
    if this.tick < 2 then return end
    this.tick = 0
    RefreshOverlay()
end)

-- ============================================================
-- Onglet OctoFan (shell v3)
-- ============================================================

local statusText, importBox

local function PlanSummaryText()
    local plan = GetPlan()
    if not plan then
        return "|cff888888Aucun plan importé.|r\n\n1. Sur |cff33ccffoctofan.vercel.app/raid|r : ouvre ton plan,\n   bouton |cffFFCC44💾 Fichier addon|r -> pose le fichier téléchargé\n   dans le dossier |cff33ccffInterface\\AddOns\\rt\\|r -> relog.\n   (ou bouton |cffFFCC44📋 RaidTools|r -> colle dans la zone ci-dessus)\n3. \"Envoyer au raid\" diffuse aux autres RaidTools du groupe.\n4. \"Mon rôle\" affiche tes assignations en permanence."
    end
    local L = {}
    table.insert(L, "|cffFFD700" .. (plan.title or "Raid") .. "|r  " ..
        (plan.raid ~= "" and ("· " .. plan.raid) or "") ..
        (plan.date ~= "" and (" · " .. plan.date) or ""))
    table.insert(L, "Joueurs : " .. table.getn(plan.rosterOrder or {}) ..
        "  |  Boss : " .. table.getn(plan.bossOrder or {}) ..
        "  |  Packs trash : " .. table.getn(plan.trash or {}) ..
        "  |  Mode : " .. (IsGuildMode() and "🏰 Guilde" or "🌍 PUG"))
    table.insert(L, "")
    for _, boss in ipairs(plan.bossOrder or {}) do
        local cnt = 0
        for _ in pairs(plan.assign[boss] or {}) do cnt = cnt + 1 end
        table.insert(L, "  · " .. boss .. " (" .. cnt .. " postes)")
    end
    return table.concat(L, "\n")
end

if RT.Modules and RT.Modules.Register then
RT.Modules.Register({
    id = "octofan",
    title = "OctoFan",
    tabWidth = 78,
    build = function(panel)
        -- ===== Mode Guild / PUG =====
        local modeLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        modeLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
        modeLbl:SetText("|cffFFCC44Mode :|r")

        local btnGuild = RT.UI.Button(panel, {
            text = "🏰 Guilde", width = 110, height = 22,
            anchor = { "TOPLEFT", modeLbl, "TOPRIGHT", 8, -2 },
            onClick = function()
                SetMode("guild")
                RT.Print("|cff33ccffOctoFan|r: mode Guilde — priorité aux assignations officielles et aux strats du site.")
                if panel._status then panel._status:SetText(PlanSummaryText()) end
            end,
        })
        local btnPug = RT.UI.Button(panel, {
            text = "🌍 PUG", width = 110, height = 22,
            anchor = { "TOPLEFT", btnGuild, "TOPRIGHT", 8, 0 },
            onClick = function()
                SetMode("pug")
                RT.Print("|cff33ccffOctoFan|r: mode PUG — priorité au WhisperBot et à l'import rapide.")
                if panel._status then panel._status:SetText(PlanSummaryText()) end
            end,
        })

        -- indicateur visuel du mode actif
        local modeActive = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        modeActive:SetPoint("TOPLEFT", btnPug, "TOPRIGHT", 12, -4)
        panel._modeActive = modeActive

        -- ===== Import =====
        local impLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        impLbl:SetPoint("TOPLEFT", modeLbl, "BOTTOMLEFT", 0, -10)
        impLbl:SetText("|cffFFCC44Import du plan (bouton 💾 Fichier addon = fiable, ou collage) :|r")

        -- Zone de collage : EditBox multi-lignes dans un cadre qui clippe,
        -- clic n'importe où -> focus -> CTRL+V.
        local impScroll = CreateFrame("ScrollFrame", "RT3_OctoFanImportScroll", panel)
        impScroll:SetWidth(676)
        impScroll:SetHeight(110)
        impScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -30)
        impScroll:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        impScroll:SetBackdropColor(0, 0, 0, 0.45)
        impScroll:SetBackdropBorderColor(0.35, 0.3, 0.15, 1)
        importBox = CreateFrame("EditBox", "RT3_OctoFanImportBox", impScroll)
        importBox:SetMultiLine(true)
        importBox:SetAutoFocus(false)
        importBox:SetFontObject(GameFontHighlightSmall)
        importBox:SetWidth(656)
        importBox:SetHeight(100)
        importBox:SetPoint("TOPLEFT", impScroll, "TOPLEFT", 8, -6)
        importBox:SetTextInsets(8, 8, 6, 6)
        importBox:EnableMouse(true)
        importBox:SetText("Clique ici, puis CTRL+V le bloc OFP1... du site.")
        importBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
        importBox:SetScript("OnEditFocusGained", function()
            if this._helper then this:SetText(""); this._helper = nil end
        end)
        importBox._helper = true
        impScroll:SetScrollChild(importBox)
        panel._importBox = importBox -- le bouton Importer lit ce champ
        impScroll:EnableMouse(true)
        impScroll:SetScript("OnMouseDown", function() importBox:SetFocus() end)

        local btnImport = RT.UI.Button(panel, {
            text = "Importer", width = 110, height = 22,
            anchor = { "TOPLEFT", panel, "TOPLEFT", 8, -148 },
            onClick = function()
                local txt = panel._importBox and panel._importBox:GetText()
                if not txt or string.gsub(txt, "%s", "") == "" or string.find(txt, "CTRL%+V le bloc") then
                    RT.Print("|cff33ccffOctoFan|r: colle le texte du plan dans la zone d'import.")
                    return
                end
                local plan = ParseOFP(txt)
                local okPaste, whyPaste
                if plan then okPaste, whyPaste = StorePlan(plan, "paste") end
                if plan and whyPaste == "pending" then
                    statusText:SetText("|cffFFCC44Plan en attente : confirme le remplacement dans la fenêtre.|r")
                elseif okPaste then
                    statusText:SetText(PlanSummaryText())
                    RT.Print("|cff33ccffOctoFan|r: plan importé — \"" .. (plan.title or "?") .. "\".")
                else
                    local preview = string.sub(txt or "", 1, 60)
                    RT.Print("|cffff6060OctoFan|r: texte non reconnu (" ..
                        string.len(txt or "") .. " car.) début : |r" .. preview)
                    statusText:SetText("|cffff6060Import échoué — " ..
                        string.len(txt or "") .. " caractères reçus, début :\n" .. preview ..
                        "\n\nVérifie que le bloc commence par OFP1| (regénère avec le bouton 💾 du site).")
                end
            end,
        })

        local btnRelay = RT.UI.Button(panel, {
            text = "Envoyer au raid", width = 140, height = 22,
            anchor = { "TOPLEFT", btnImport, "TOPRIGHT", 8, 0 },
            onClick = function()
                local plan = GetPlan()
                if not plan then
                    RT.Print("|cff33ccffOctoFan|r: aucun plan importé à transmettre.")
                    return
                end
                StartRelay(SerializeOFP(plan))
            end,
        })

        local btnMy = RT.UI.Button(panel, {
            text = "Mon rôle", width = 110, height = 22,
            anchor = { "TOPLEFT", btnRelay, "TOPRIGHT", 8, 0 },
            onClick = function()
                RefreshMyWindow()
                if myFrame then
                    if myFrame:IsVisible() then myFrame:Hide() else myFrame:Show() end
                end
            end,
        })

        local btnAMOW = RT.UI.Button(panel, {
            text = "🎯 Trash->AM", width = 110, height = 22,
            anchor = { "TOPLEFT", btnMy, "TOPRIGHT", 8, 0 },
            onClick = function() OF.PushTrash(false) end,
        })

        local btnOverlay = RT.UI.Button(panel, {
            text = "📋 Strat", width = 110, height = 22,
            anchor = { "TOPLEFT", btnAMOW, "TOPRIGHT", 8, 0 },
            onClick = function() OctoFan_ShowOverlay() end,
        })

        local btnErase
        btnErase = RT.UI.Button(panel, {
            text = "Reset", width = 60, height = 22,
            anchor = { "TOPLEFT", btnOverlay, "TOPRIGHT", 8, 0 },
            tooltip = "Efface le plan local (2 clics). Ne touche ni aux schémas ni au mode.",
            onClick = function()
                if not btnErase._armed then
                    btnErase._armed = GetTime() + 4
                    btnErase:SetText("Sûr ?")
                    return
                end
                if GetTime() > btnErase._armed then
                    btnErase._armed = GetTime() + 4
                    return
                end
                btnErase._armed = nil
                btnErase:SetText("Reset")
                OF.ResetPlan()
                statusText:SetText(PlanSummaryText())
            end,
        })

        statusText = RT.UI.TextScroll(panel, {
            name = "RT3_OctoFanStatus",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 8, -178 },
            width = 690, height = 210, font = "GameFontHighlightSmall",
        })
        statusText.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)
        panel._status = statusText
    end,
    show = function(panel)
        if panel._status then panel._status:SetText(PlanSummaryText()) end
        if panel._modeActive then
            local m = GetMode()
            panel._modeActive:SetText(m == "guild" and "|cffFFCC44🏰 GUILDE|r" or "|cff88FF88🌍 PUG|r")
        end
    end,
})
else
    RT.Print("|cffff6060OctoFan|r: RT.Modules indisponible — l'onglet OctoFan n'est pas enregistré.")
end

-- === AUDIT_3 exposure (copy only) ===
OF._Parse = ParseOFP
OF._Serialize = SerializeOFP
OF._HexEnc = HexEnc
OF._HexDec = HexDec
OF._StartRelay = StartRelay
OF._StorePlan = StorePlan
OF._PlanIsCorrupt = PlanIsCorrupt
OF._GetPlan = GetPlan
OF._RefreshMyWindow = RefreshMyWindow
OF._relayFrame = relayFrame
OF._SplitChunks = SplitChunks
OF._MaybeAutoSend = MaybeAutoSend
