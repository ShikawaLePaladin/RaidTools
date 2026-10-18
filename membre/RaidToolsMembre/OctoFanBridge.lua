if RTM_DISABLED then return end
-- ============================================================
-- RT v4 — OctoFanBridge.lua  [VERSION MEMBRE : généré par build.js, ne pas modifier ici]
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
-- Version MEMBRE : tout le bloc officier (fenetre Mon role + editeur d'assignation, overlay strat, mode Guilde/PUG,
-- page d'import, Trash->AutoMarker, envoi au raid) est retire a la fabrication (build.js). Il reste la couche donnees :
-- lecture du plan, relais recu du chef, assignations recues, fichier RT_OctoFanData.lua.
-- ============================================================
IsGuildMode = function() return false end
function OF.GetMode() return "guild" end
function OF.SetMode() end
function OF.IsGuildMode() return false end
function OF.myOpen() return false end
function OF.ResetPlan()
    local db = RT.Store.DB()
    db.octofan = nil
    RT.Store.Notify("octofan")
    RT.Print("plan local effacé.")
end
function OF.ShowMyRole()
    if RTM and RTM.ToggleOverlay then RTM.ToggleOverlay("role") end
end

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
