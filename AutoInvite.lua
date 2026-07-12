-- ============================================================
-- RT v2 — AutoInvite.lua
-- LFM builder + auto-invite par mot-clé (inspiré Tactica)
-- Compatible WoW 1.12 / TurtleWoW
-- ============================================================

RT_AI = RT_AI or {}

local AI_ACTIVE    = false
local AI_KEYWORD   = "inv"
local AI_MAX       = 40
local AI_QUEUE     = {}   -- {name, time}
local AI_INVITED   = {}   -- {name = true}
local AI_ROLE_MAP  = {}   -- {name = "Tank"/"Heal"/"DPS"}

-- Réinvitations : joueurs pas encore dans le raid (hors-ligne, groupés...)
local AI_PENDING        = {}   -- { [name] = { tries, grouped, groupedMsgSent } }
local AI_RETRY_INTERVAL = 30   -- secondes entre deux tentatives
local AI_MAX_TRIES      = 10   -- ~5 min de retries avant abandon
local AI_LastRetry      = 0

local function AI_Whisper(target, text)
    local lang = GetDefaultLanguage and GetDefaultLanguage("player") or nil
    pcall(SendChatMessage, "[RT] " .. text, "WHISPER", lang, target)
end

-- Le joueur est-il déjà dans NOTRE groupe/raid ?
function RT_AI.IsGroupedWithUs(name)
    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    for i = 1, n do
        if GetRaidRosterInfo(i) == name then return true end
    end
    local np = GetNumPartyMembers and GetNumPartyMembers() or 0
    for i = 1, np do
        if UnitName("party" .. i) == name then return true end
    end
    return false
end

-- Envoie une invitation et l'enregistre pour retry éventuel
function RT_AI.DoInvite(name)
    AI_PENDING[name] = AI_PENDING[name] or { tries = 0 }
    AI_PENDING[name].tries = AI_PENDING[name].tries + 1
    pcall(InviteUnit or InviteByName, name)
end

-- ── Démarre l'auto-invite ──────────────────────────────────
function RT_AI.Start(keyword, maxPlayers)
    AI_KEYWORD = string.lower(RT_BTrim and RT_BTrim(keyword or "inv") or (keyword or "inv"))
    AI_MAX     = tonumber(maxPlayers) or 40
    AI_ACTIVE  = true
    AI_QUEUE   = {}
    AI_INVITED = {}
    AI_PENDING = {}
    RT_Print("|cff88CCFF[AutoInvite]|r Active. Keyword: |cffFFD700" .. AI_KEYWORD .. "|r — max " .. AI_MAX .. " players.")
    local msg = "[RT] Whisper '" .. AI_KEYWORD .. "' to join the raid! (" .. AI_MAX .. " spots)"
    if RT_DB and RT_DB.ai and RT_DB.ai.lfmChannel then
        pcall(SendChatMessage, msg, RT_DB.ai.lfmChannel)
    end
    RT_AI.UpdateUI()
end

function RT_AI.Stop()
    AI_ACTIVE  = false
    AI_PENDING = {}
    RT_Print("|cff88CCFF[AutoInvite]|r Stopped. " .. table.getn(AI_QUEUE) .. " player(s) invited.")
    RT_AI.UpdateUI()
end

function RT_AI.IsActive() return AI_ACTIVE end

-- ── Traitement d'un whisper entrant ───────────────────────
function RT_AI.OnWhisper(sender, message)
    if not AI_ACTIVE then return end
    if not sender or sender == "" then return end

    local msg = string.lower(RT_BTrim and RT_BTrim(message) or message)
    -- '+1' = "je suis libre maintenant, réinvite-moi" (joueur qui était groupé)
    if msg ~= AI_KEYWORD and msg ~= "+1" then return end

    -- Déjà invité ?
    if AI_INVITED[sender] then
        if RT_AI.IsGroupedWithUs(sender) then
            AI_Whisper(sender, "You're already in the raid!")
            return
        end
        -- Invité mais toujours pas dans le raid (était groupé / hors-ligne /
        -- a décliné) : on retente.
        if AI_PENDING[sender] then
            AI_PENDING[sender].grouped = nil
            AI_PENDING[sender].groupedMsgSent = nil
        end
        RT_AI.DoInvite(sender)
        AI_Whisper(sender, "Invite sent again!")
        RT_Print("|cff88CCFF[AI]|r " .. sender .. " re-invited.")
        return
    end

    -- Raid plein ?
    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if nRaid >= AI_MAX then
        AI_Whisper(sender, "Sorry, the raid is full (" .. AI_MAX .. "/" .. AI_MAX .. ")")
        RT_Print("|cffFFAA00[AI]|r Raid full, " .. sender .. " declined.")
        return
    end

    -- Invite
    table.insert(AI_QUEUE, { name=sender, time=GetTime and GetTime() or 0 })
    AI_INVITED[sender] = true
    RT_AI.DoInvite(sender)

    AI_Whisper(sender, "Invite sent! Welcome.")
    RT_Print("|cff88CCFF[AI]|r " .. sender .. " invited (#" .. table.getn(AI_QUEUE) .. ")")

    RT_AI.UpdateUI()

    -- Ajoute au roster si pas présent
    if RT_DB and RT_DB.roster and not RT_DB.roster[sender] then
        RT_DB.roster[sender] = { role = "DPS", sr = 0 }
        if RT_RosterDisplay then RT_RosterDisplay() end
    end
end

-- ── Messages système : détecte "déjà groupé" / "introuvable" ──
-- Quand l'invite échoue parce que le joueur est déjà dans un groupe,
-- on le prévient par whisper : il répond '+1' (ou le mot-clé) quand il
-- est libre et on le réinvite.
local AI_SysFrame = CreateFrame("Frame", "RT_AISysFrame")
AI_SysFrame:RegisterEvent("CHAT_MSG_SYSTEM")
AI_SysFrame:SetScript("OnEvent", function()
    if not AI_ACTIVE then return end
    local m = arg1 or ""

    -- EN "X is already in a group." / FR "X est déjà dans un groupe."
    local _, _, who = string.find(m, "^(%S+) is already in a group")
    if not who then _, _, who = string.find(m, "^(%S+) est d.j. dans un groupe") end
    if who and AI_INVITED[who] then
        local p = AI_PENDING[who] or { tries = 0 }
        AI_PENDING[who] = p
        p.grouped = true
        if not p.groupedMsgSent then
            p.groupedMsgSent = true
            AI_Whisper(who, "You're currently in another group. Reply '+1' (or '"
                .. AI_KEYWORD .. "') when you're free and I'll re-invite you.")
            RT_Print("|cffFFAA00[AI]|r " .. who .. " is already grouped — asked to reply '+1' when free.")
        end
        return
    end

    -- EN "Cannot find player 'X'." (hors-ligne) → le retry le rattrapera au login
    local _, _, off = string.find(m, "find player '([^']+)'")
    if off and AI_PENDING[off] then
        AI_PENDING[off].offline = true
    end
end)

-- ── Retry : réinvite toutes les 30 s (rattrape aussi les logins) ──
local AI_RetryFrame = CreateFrame("Frame", "RT_AIRetryFrame")
AI_RetryFrame:SetScript("OnUpdate", function()
    if not AI_ACTIVE then return end
    if not (RT_DB and RT_DB.ai and RT_DB.ai.retry30) then return end
    local now = GetTime and GetTime() or 0
    if (now - AI_LastRetry) < AI_RETRY_INTERVAL then return end
    AI_LastRetry = now
    for name, p in pairs(AI_PENDING) do
        if RT_AI.IsGroupedWithUs(name) then
            AI_PENDING[name] = nil            -- il est arrivé : terminé
        elseif p.grouped then
            -- groupé ailleurs : on ne spamme pas, il doit répondre '+1'
        elseif p.tries >= AI_MAX_TRIES then
            AI_PENDING[name] = nil            -- abandon après ~5 min
            RT_Print("|cff888888[AI] " .. name .. " never joined — giving up.|r")
        else
            RT_AI.DoInvite(name)              -- hors-ligne au moment T → invité au login
        end
    end
end)

-- ── Frame whisper listener ─────────────────────────────────
local AI_ListenFrame = CreateFrame("Frame", "RT_AIListenFrame", UIParent)
AI_ListenFrame:RegisterEvent("CHAT_MSG_WHISPER")
AI_ListenFrame:SetScript("OnEvent", function(self, evName, a1, a2)
    local message = a1 or arg1 or ""
    local sender  = a2 or arg2 or ""
    RT_AI.OnWhisper(sender, message)
end)

-- ── Announce LFM en boucle ─────────────────────────────────
local AI_AnnounceInterval = 60
local AI_LastAnnounce     = 0
local AI_AnnounceFrame    = CreateFrame("Frame")
AI_AnnounceFrame:SetScript("OnUpdate", function()
    if not AI_ACTIVE then return end
    if not (RT_DB and RT_DB.ai and RT_DB.ai.autoAnnounce) then return end
    local now = GetTime and GetTime() or 0
    if (now - AI_LastAnnounce) < AI_AnnounceInterval then return end
    AI_LastAnnounce = now
    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    local channel = (RT_DB.ai and RT_DB.ai.lfmChannel) or "SAY"
    local msg = "[LFM] Raid " .. (RT_DB.ai and RT_DB.ai.lfmDesc or "")
              .. " — " .. nRaid .. "/" .. AI_MAX
              .. " — MP '" .. AI_KEYWORD .. "' pour rejoindre"
    pcall(SendChatMessage, msg, channel)
end)

-- ── Kick de la queue ────────────────────────────────────────
function RT_AI.RemoveFromQueue(name)
    for i = table.getn(AI_QUEUE), 1, -1 do
        if AI_QUEUE[i].name == name then
            table.remove(AI_QUEUE, i)
            AI_INVITED[name] = nil
            break
        end
    end
    RT_AI.UpdateUI()
end

-- ── Mise à jour UI ─────────────────────────────────────────
function RT_AI.UpdateUI()
    local statusLabel = getglobal("RT_AIStatusLabel")
    if not statusLabel then return end
    if AI_ACTIVE then
        statusLabel:SetText("|cff44FF44AutoInvite: ON|r  mot-clé: |cffFFD700" .. AI_KEYWORD
            .. "|r  " .. table.getn(AI_QUEUE) .. " invité(s)")
    else
        statusLabel:SetText("|cffAAAAAA AutoInvite: OFF|r")
    end
    -- Refresh la liste
    local listFrame = getglobal("RT_AIQueueContent")
    if not listFrame then return end
    for i = 1, 30 do
        local row = getglobal("RT_AIRow" .. i)
        if row then
            if i <= table.getn(AI_QUEUE) then
                local e = AI_QUEUE[i]
                local nameLbl = getglobal("RT_AIRowName" .. i)
                if nameLbl then nameLbl:SetText("|cffFFFFFF" .. e.name .. "|r") end
                row:Show()
            else
                row:Hide()
            end
        end
    end
end

-- ── Construit l'UI dans le panneau AutoInvite ──────────────
function RT_BuildUIAutoInvite(parent)
    local p = RT_CreatePanel and RT_CreatePanel("RT_Panel_Invite") or parent

    RT_DB = RT_DB or {}
    RT_DB.ai = RT_DB.ai or {
        keyword      = "inv",
        maxPlayers   = 40,
        lfmDesc      = "Molten Core",
        lfmChannel   = "SAY",
        autoAnnounce = false,
        retry30      = false,
    }

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -4)
    title:SetText("|cff88CCFFAuto-Invite|r  —  invites automatically on whisper keyword")
    title:SetTextColor(0.3, 0.8, 1.0)

    -- Keyword
    local kwLabel = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    kwLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -26)
    kwLabel:SetText("Keyword:")

    local kwEdit = CreateFrame("EditBox", "RT_AIKeywordEdit", p, "InputBoxTemplate")
    kwEdit:SetPoint("LEFT", kwLabel, "RIGHT", 6, 0)
    kwEdit:SetWidth(80)
    kwEdit:SetHeight(20)
    kwEdit:SetAutoFocus(false)
    kwEdit:SetText(RT_DB.ai.keyword or "inv")
    kwEdit:SetScript("OnEscapePressed", function() kwEdit:ClearFocus() end)
    kwEdit:SetScript("OnEnterPressed", function()
        RT_DB.ai.keyword = RT_BTrim and RT_BTrim(kwEdit:GetText()) or kwEdit:GetText()
        kwEdit:ClearFocus()
    end)

    -- Max players
    local maxLabel = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    maxLabel:SetPoint("LEFT", kwEdit, "RIGHT", 12, 0)
    maxLabel:SetText("Max players:")

    local maxEdit = CreateFrame("EditBox", "RT_AIMaxEdit", p, "InputBoxTemplate")
    maxEdit:SetPoint("LEFT", maxLabel, "RIGHT", 6, 0)
    maxEdit:SetWidth(42)
    maxEdit:SetHeight(20)
    maxEdit:SetAutoFocus(false)
    maxEdit:SetText(tostring(RT_DB.ai.maxPlayers or 40))
    maxEdit:SetScript("OnEscapePressed", function() maxEdit:ClearFocus() end)
    maxEdit:SetScript("OnEnterPressed", function()
        RT_DB.ai.maxPlayers = tonumber(maxEdit:GetText()) or 40
        maxEdit:ClearFocus()
    end)

    -- Boutons Start / Stop
    local startBtn = CreateFrame("Button", "RT_AIStartBtn", p, "UIPanelButtonTemplate")
    startBtn:SetPoint("LEFT", maxEdit, "RIGHT", 12, 0)
    startBtn:SetWidth(80)
    startBtn:SetHeight(22)
    startBtn:SetText("Start")
    local sTex = startBtn:GetNormalTexture()
    if sTex then sTex:SetVertexColor(0.1, 0.7, 0.2) end
    startBtn:SetScript("OnClick", function()
        local kw  = RT_BTrim and RT_BTrim(kwEdit:GetText()) or kwEdit:GetText()
        local max = tonumber(maxEdit:GetText()) or 40
        RT_DB.ai.keyword    = kw
        RT_DB.ai.maxPlayers = max
        AI_KEYWORD = string.lower(kw)
        AI_MAX     = max
        RT_AI.Start(kw, max)
    end)

    local stopBtn = CreateFrame("Button", "RT_AIStopBtn", p, "UIPanelButtonTemplate")
    stopBtn:SetPoint("LEFT", startBtn, "RIGHT", 6, 0)
    stopBtn:SetWidth(72)
    stopBtn:SetHeight(22)
    stopBtn:SetText("Stop")
    local stTex = stopBtn:GetNormalTexture()
    if stTex then stTex:SetVertexColor(0.8, 0.2, 0.1) end
    stopBtn:SetScript("OnClick", function() RT_AI.Stop() end)

    -- Toggle : réinvitation automatique toutes les 30 s
    local retryBtn = CreateFrame("Button", "RT_AIRetryBtn", p, "UIPanelButtonTemplate")
    retryBtn:SetPoint("LEFT", stopBtn, "RIGHT", 10, 0)
    retryBtn:SetWidth(110)
    retryBtn:SetHeight(22)
    local function retryPaint()
        local tex = retryBtn:GetNormalTexture()
        if RT_DB.ai.retry30 then
            retryBtn:SetText("Retry 30s: ON")
            if tex then tex:SetVertexColor(0.1, 0.6, 0.2) end
        else
            retryBtn:SetText("Retry 30s: OFF")
            if tex then tex:SetVertexColor(0.4, 0.4, 0.4) end
        end
    end
    retryBtn:SetScript("OnClick", function()
        RT_DB.ai.retry30 = not RT_DB.ai.retry30
        retryPaint()
        if RT_DB.ai.retry30 then
            RT_Print("|cff88CCFF[AI]|r Retry ON: pending players are re-invited every 30s (also catches players logging in). Players grouped elsewhere get a whisper and must reply '+1'.")
        end
    end)
    retryPaint()

    -- Description LFM
    local lfmLabel = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    lfmLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -52)
    lfmLabel:SetText("LFM message:")

    local lfmEdit = CreateFrame("EditBox", "RT_AILFMEdit", p, "InputBoxTemplate")
    lfmEdit:SetPoint("LEFT", lfmLabel, "RIGHT", 6, 0)
    lfmEdit:SetWidth(260)
    lfmEdit:SetHeight(20)
    lfmEdit:SetAutoFocus(false)
    lfmEdit:SetText(RT_DB.ai.lfmDesc or "Molten Core")
    lfmEdit:SetScript("OnEscapePressed", function() lfmEdit:ClearFocus() end)
    lfmEdit:SetScript("OnEnterPressed", function()
        RT_DB.ai.lfmDesc = lfmEdit:GetText()
        lfmEdit:ClearFocus()
    end)

    -- Channel LFM
    local chanLabel = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    chanLabel:SetPoint("LEFT", lfmEdit, "RIGHT", 8, 0)
    chanLabel:SetText("Channel:")

    local chanEdit = CreateFrame("EditBox", "RT_AIChanEdit", p, "InputBoxTemplate")
    chanEdit:SetPoint("LEFT", chanLabel, "RIGHT", 6, 0)
    chanEdit:SetWidth(60)
    chanEdit:SetHeight(20)
    chanEdit:SetAutoFocus(false)
    chanEdit:SetText(RT_DB.ai.lfmChannel or "SAY")
    chanEdit:SetScript("OnEscapePressed", function() chanEdit:ClearFocus() end)
    chanEdit:SetScript("OnEnterPressed", function()
        RT_DB.ai.lfmChannel = string.upper(RT_BTrim and RT_BTrim(chanEdit:GetText()) or chanEdit:GetText())
        chanEdit:ClearFocus()
    end)

    -- Bouton annoncer manuellement
    local announceBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    announceBtn:SetPoint("LEFT", chanEdit, "RIGHT", 8, 0)
    announceBtn:SetWidth(80)
    announceBtn:SetHeight(20)
    announceBtn:SetText("Announce")
    announceBtn:SetScript("OnClick", function()
        local desc    = lfmEdit:GetText()
        local channel = string.upper(RT_BTrim and RT_BTrim(chanEdit:GetText()) or chanEdit:GetText())
        local nRaid   = GetNumRaidMembers and GetNumRaidMembers() or 0
        local kw      = RT_BTrim and RT_BTrim(kwEdit:GetText()) or kwEdit:GetText()
        local msg = "[LFM] Raid " .. desc .. " — " .. nRaid .. "/" .. (tonumber(maxEdit:GetText()) or 40)
                  .. " — MP '" .. kw .. "' pour rejoindre"
        pcall(SendChatMessage, msg, channel)
    end)

    -- Status
    local statusLabel = p:CreateFontString("RT_AIStatusLabel", "OVERLAY", "GameFontHighlightSmall")
    statusLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -78)
    statusLabel:SetWidth(720)
    statusLabel:SetJustifyH("LEFT")
    statusLabel:SetText("|cffAAAAAA AutoInvite: OFF|r")

    -- Liste des invités
    local queueTitle = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    queueTitle:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -96)
    queueTitle:SetText("|cffCCCCCCInvite queue|r")

    local queueScroll = CreateFrame("ScrollFrame", "RT_AIQueueScroll", p, "UIPanelScrollFrameTemplate")
    queueScroll:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -112)
    queueScroll:SetWidth(700)
    queueScroll:SetHeight(280)

    local queueContent = CreateFrame("Frame", "RT_AIQueueContent", queueScroll)
    queueContent:SetWidth(680)
    queueContent:SetHeight(900)
    queueScroll:SetScrollChild(queueContent)

    for i = 1, 30 do
        local row = CreateFrame("Frame", "RT_AIRow" .. i, queueContent)
        row:SetWidth(680)
        row:SetHeight(18)
        row:SetPoint("TOPLEFT", queueContent, "TOPLEFT", 0, -(i-1)*18)
        row:Hide()

        local num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        num:SetPoint("LEFT", row, "LEFT", 2, 0)
        num:SetWidth(24)
        num:SetText(i .. ".")
        num:SetTextColor(0.6, 0.6, 0.6)

        local nameLbl = row:CreateFontString("RT_AIRowName" .. i, "OVERLAY", "GameFontNormalSmall")
        nameLbl:SetPoint("LEFT", num, "RIGHT", 2, 0)
        nameLbl:SetWidth(160)
        nameLbl:SetJustifyH("LEFT")

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetPoint("LEFT", nameLbl, "RIGHT", 4, 0)
        removeBtn:SetWidth(60)
        removeBtn:SetHeight(16)
        removeBtn:SetText("Remove")
        local idx = i
        removeBtn:SetScript("OnClick", function()
            if AI_QUEUE[idx] then
                RT_AI.RemoveFromQueue(AI_QUEUE[idx].name)
            end
        end)
    end
end
