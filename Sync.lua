-- ============================================================
-- RT v2 — Sync.lua
-- Backbone communication inter-addon via SendAddonMessage
-- Prefix "RTSYNC" — compatible WoW 1.12 / TurtleWoW
-- ============================================================
-- Types de messages :
--   VER   : version broadcast
--   ROLES : sync des rôles roster
--   TIMER : pull timer start/cancel
--   CD    : cooldown utilisé/reset
--   NOTE  : note raid
--   MARK  : markers raid
-- ============================================================

RT_Sync = RT_Sync or {}

local SYNC_PREFIX    = "RTSYNC"
local SYNC_SEP       = "\031"   -- unit separator (safe, non-printable)
local SYNC_VERSION   = "2"
local SYNC_RATE_MIN  = 0.2      -- secondes entre deux envois identiques

local RT_SYNC_LAST_SENT = {}

-- ── Encode / Decode ────────────────────────────────────────
local function Sync_Encode(msgType, ...)
    -- Lua 5.0 : varargs accessibles via `arg`, pas via { ... }
    local parts = { msgType }
    for i = 1, table.getn(arg) do
        table.insert(parts, tostring(arg[i] or ""))
    end
    return table.concat(parts, SYNC_SEP)
end

local function Sync_Decode(raw)
    local parts = {}
    local s = raw or ""
    -- split on SYNC_SEP (char 31)
    local i = 1
    local len = string.len(s)
    local cur = ""
    while i <= len do
        local c = string.sub(s, i, i)
        if c == SYNC_SEP then
            table.insert(parts, cur)
            cur = ""
        else
            cur = cur .. c
        end
        i = i + 1
    end
    table.insert(parts, cur)
    return parts
end

-- ── Envoi ──────────────────────────────────────────────────
function RT_Sync_Send(msgType, ...)
    if not msgType then return end
    local _a = arg   -- capture varargs avant tout appel interne
    local payload = Sync_Encode(msgType, unpack(_a))

    -- Rate-limit pour éviter le spam
    local now = GetTime and GetTime() or 0
    local key = msgType .. "|" .. tostring(_a[1] or "")
    if (now - (RT_SYNC_LAST_SENT[key] or 0)) < SYNC_RATE_MIN then return end
    RT_SYNC_LAST_SENT[key] = now

    local channel = "RAID"
    if GetNumRaidMembers and GetNumRaidMembers() == 0 then
        if GetNumPartyMembers and GetNumPartyMembers() > 0 then
            channel = "PARTY"
        else
            -- Solo : on s'envoie à soi-même pour les tests
            local player = UnitName and UnitName("player") or ""
            if player ~= "" then
                pcall(SendAddonMessage, SYNC_PREFIX, payload, "WHISPER", player)
            end
            return
        end
    end
    pcall(SendAddonMessage, SYNC_PREFIX, payload, channel)
end

-- Envoi ciblé (whisper) à un joueur
function RT_Sync_Whisper(target, msgType, ...)
    if not target or target == "" or not msgType then return end
    local _a = arg
    local payload = Sync_Encode(msgType, unpack(_a))
    pcall(SendAddonMessage, SYNC_PREFIX, payload, "WHISPER", target)
end

-- ── Handlers enregistrés ───────────────────────────────────
local RT_SYNC_HANDLERS = {}

function RT_Sync_Register(msgType, fn)
    RT_SYNC_HANDLERS[msgType] = fn
end

-- ── Reception ──────────────────────────────────────────────
local RT_SyncListenFrame = CreateFrame("Frame", "RT_SyncListenFrame", UIParent)
RT_SyncListenFrame:RegisterEvent("CHAT_MSG_ADDON")
RT_SyncListenFrame:SetScript("OnEvent", function(self, evName, a1, a2, a3, a4)
    local prefix  = a1 or arg1 or ""
    local payload = a2 or arg2 or ""
    local channel = a3 or arg3 or ""
    local sender  = a4 or arg4 or ""

    if prefix ~= SYNC_PREFIX then return end
    if not payload or payload == "" then return end

    local parts   = Sync_Decode(payload)
    local msgType = parts[1] or ""
    if msgType == "" then return end

    local handler = RT_SYNC_HANDLERS[msgType]
    if handler then
        local args = {}
        for i = 2, table.getn(parts) do
            table.insert(args, parts[i])
        end
        -- handler(sender, arg1, arg2, ...)
        handler(sender, unpack(args))
    end
end)

-- ── Version broadcast ──────────────────────────────────────
RT_SYNC_MEMBERS = RT_SYNC_MEMBERS or {}  -- {name = version}

RT_Sync_Register("VER", function(sender, ver)
    RT_SYNC_MEMBERS[sender] = ver or "?"
end)

function RT_Sync_BroadcastVersion()
    RT_Sync_Send("VER", SYNC_VERSION)
end

-- ── Sync Rôles ─────────────────────────────────────────────
-- Encode le roster en mini-format compact : "Name:Class:Role|Name:Class:Role|..."
function RT_Sync_SendRoles()
    RT_DB = RT_DB or {}
    local roster = RT_DB.roster or {}
    local parts = {}
    for name, data in pairs(roster) do
        local c = (data.class or ""):sub(1,3)
        local r = (data.role  or "D"):sub(1,1)
        table.insert(parts, name .. ":" .. c .. ":" .. r)
    end
    if table.getn(parts) == 0 then return end
    -- Envoie par chunks de 200 chars
    local chunk = ""
    for i = 1, table.getn(parts) do
        local seg = parts[i]
        if string.len(chunk) + string.len(seg) + 1 > 200 then
            RT_Sync_Send("ROLES", chunk)
            chunk = seg
        else
            chunk = chunk == "" and seg or (chunk .. "|" .. seg)
        end
    end
    if chunk ~= "" then RT_Sync_Send("ROLES", chunk) end
end

RT_Sync_Register("ROLES", function(sender, encoded)
    if not encoded or encoded == "" then return end
    RT_DB = RT_DB or {}
    RT_DB.roster = RT_DB.roster or {}
    -- Décode "Name:Cls:Role|..."
    local i = 1
    local len = string.len(encoded)
    local seg = ""
    while i <= len + 1 do
        local c = i <= len and string.sub(encoded, i, i) or "|"
        if c == "|" then
            if seg ~= "" then
                -- parse Name:Cls:Role
                local p = {}
                local si = 1
                local slen = string.len(seg)
                local cur = ""
                while si <= slen + 1 do
                    local sc = si <= slen and string.sub(seg, si, si) or ":"
                    if sc == ":" then
                        table.insert(p, cur)
                        cur = ""
                    else
                        cur = cur .. sc
                    end
                    si = si + 1
                end
                local pname = p[1] or ""
                local pcls  = p[2] or ""
                local prole = p[3] or "D"
                if pname ~= "" then
                    local existing = RT_DB.roster[pname] or {}
                    if pcls  ~= "" and (not existing.class or existing.class == "") then
                        existing.class = pcls
                    end
                    local roleMap = { T="Tank", H="Heal", D="DPS" }
                    if not existing.role or existing.role == "" then
                        existing.role = roleMap[prole] or "DPS"
                    end
                    RT_DB.roster[pname] = existing
                end
            end
            seg = ""
        else
            seg = seg .. c
        end
        i = i + 1
    end
    if RT_RosterDisplay then RT_RosterDisplay() end
end)

-- ── Sync Note raid ─────────────────────────────────────────
function RT_Sync_SendNote(noteText)
    if not noteText or noteText == "" then return end
    RT_Sync_Send("NOTE", noteText)
end

RT_Sync_Register("NOTE", function(sender, note)
    if not note or note == "" then return end
    RT_DB = RT_DB or {}
    RT_DB.sharedNotes = RT_DB.sharedNotes or {}
    RT_DB.sharedNotes[sender] = note
    RT_Print("|cff88CCFF[Sync]|r Note de " .. sender .. " reçue.")
    local nb = getglobal("RT_NotesContent")
    if nb then
        local cur = nb:GetText() or ""
        if not string.find(cur, note, 1, true) then
            nb:SetText(cur ~= "" and (cur .. "\n-- " .. sender .. " --\n" .. note) or note)
        end
    end
end)

-- ── Init on VARIABLES_LOADED ───────────────────────────────
local RT_SyncInitFrame = CreateFrame("Frame")
RT_SyncInitFrame:RegisterEvent("VARIABLES_LOADED")
RT_SyncInitFrame:SetScript("OnEvent", function()
    -- broadcast version après 3s pour laisser les autres charger
    if RT_Sync_BroadcastVersion then
        local _tStart = GetTime()
        RT_SyncInitFrame:SetScript("OnUpdate", function()
            if (GetTime() - _tStart) < 3 then return end
            RT_SyncInitFrame:SetScript("OnUpdate", nil)
            pcall(RT_Sync_BroadcastVersion)
        end)
    end
end)
