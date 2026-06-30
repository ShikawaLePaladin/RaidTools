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

-- ── Démarre l'auto-invite ──────────────────────────────────
function RT_AI.Start(keyword, maxPlayers)
    AI_KEYWORD = string.lower(RT_BTrim and RT_BTrim(keyword or "inv") or (keyword or "inv"))
    AI_MAX     = tonumber(maxPlayers) or 40
    AI_ACTIVE  = true
    AI_QUEUE   = {}
    AI_INVITED = {}
    RT_Print("|cff88CCFF[AutoInvite]|r Actif. Mot-clé: |cffFFD700" .. AI_KEYWORD .. "|r — max " .. AI_MAX .. " joueurs.")
    -- Annonce en /say ou /yell selon la préférence
    local nRaid  = GetNumRaidMembers  and GetNumRaidMembers()  or 0
    local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    local msg = "[RT] Tape '" .. AI_KEYWORD .. "' en MP pour rejoindre le raid! (" .. AI_MAX .. " places)"
    if RT_DB and RT_DB.ai and RT_DB.ai.lfmChannel then
        pcall(SendChatMessage, msg, RT_DB.ai.lfmChannel)
    end
    RT_AI.UpdateUI()
end

function RT_AI.Stop()
    AI_ACTIVE = false
    RT_Print("|cff88CCFF[AutoInvite]|r Arrêté. " .. table.getn(AI_QUEUE) .. " joueur(s) invité(s).")
    RT_AI.UpdateUI()
end

function RT_AI.IsActive() return AI_ACTIVE end

-- ── Traitement d'un whisper entrant ───────────────────────
function RT_AI.OnWhisper(sender, message)
    if not AI_ACTIVE then return end
    if not sender or sender == "" then return end

    local msg = string.lower(RT_BTrim and RT_BTrim(message) or message)
    if msg ~= AI_KEYWORD then return end

    -- Déjà invité ?
    if AI_INVITED[sender] then
        local lang = GetDefaultLanguage and GetDefaultLanguage("player") or nil
        pcall(SendChatMessage, "[RT] Tu as déjà été invité(e)!", "WHISPER", lang, sender)
        return
    end

    -- Raid plein ?
    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if nRaid >= AI_MAX then
        local lang = GetDefaultLanguage and GetDefaultLanguage("player") or nil
        pcall(SendChatMessage, "[RT] Désolé, le raid est complet (" .. AI_MAX .. "/" .. AI_MAX .. ")", "WHISPER", lang, sender)
        RT_Print("|cffFFAA00[AI]|r Raid plein, " .. sender .. " refusé.")
        return
    end

    -- Invite
    table.insert(AI_QUEUE, { name=sender, time=GetTime and GetTime() or 0 })
    AI_INVITED[sender] = true
    pcall(InviteUnit, sender)

    local lang = GetDefaultLanguage and GetDefaultLanguage("player") or nil
    pcall(SendChatMessage, "[RT] Invitation envoyée! Bienvenue.", "WHISPER", lang, sender)
    RT_Print("|cff88CCFF[AI]|r " .. sender .. " invité(e) (#" .. table.getn(AI_QUEUE) .. ")")

    RT_AI.UpdateUI()

    -- Ajoute au roster si pas présent
    if RT_DB and RT_DB.roster and not RT_DB.roster[sender] then
        RT_DB.roster[sender] = { role = "DPS", sr = 0 }
        if RT_RosterDisplay then RT_RosterDisplay() end
    end
end

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
    }

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -4)
    title:SetText("|cff88CCFFAuto-Invite|r  —  Invite automatiquement par mot-clé en PM")
    title:SetTextColor(0.3, 0.8, 1.0)

    -- Keyword
    local kwLabel = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    kwLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -26)
    kwLabel:SetText("Mot-clé:")

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
    maxLabel:SetText("Max joueurs:")

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
    startBtn:SetText("Démarrer")
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
    stopBtn:SetText("Arrêter")
    local stTex = stopBtn:GetNormalTexture()
    if stTex then stTex:SetVertexColor(0.8, 0.2, 0.1) end
    stopBtn:SetScript("OnClick", function() RT_AI.Stop() end)

    -- Description LFM
    local lfmLabel = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    lfmLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -52)
    lfmLabel:SetText("Annonce LFM:")

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
    chanLabel:SetText("Canal:")

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
    announceBtn:SetText("Annoncer")
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
    queueTitle:SetText("|cffCCCCCCFile d'invitation|r")

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
        removeBtn:SetText("Retirer")
        local idx = i
        removeBtn:SetScript("OnClick", function()
            if AI_QUEUE[idx] then
                RT_AI.RemoveFromQueue(AI_QUEUE[idx].name)
            end
        end)
    end
end
