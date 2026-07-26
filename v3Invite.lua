-- ============================================================
-- RT v3 - modules/Invite.lua
-- Auto-Invite : recrutement par mot-clé whisper (RT_AI, AutoInvite.lua)
-- Surface v3 du système v2 existant : ce module ne réimplémente pas
-- la logique, il pilote RT_AI.* et lit son état via des getters.
-- ============================================================

RT3_INVITE_CHANS = { "SAY", "YELL", "GUILD", "WORLD", "LFG" }
RT3_INVITE_CHAN_LABELS = { SAY="Say", YELL="Yell", GUILD="Guild", WORLD="World", LFG="LFG" }

function RT3_InviteChanLabel(c)
    return RT3_INVITE_CHAN_LABELS[c] or c
end

function RT3_InviteResolveChannel(key)
    if key == "WORLD" or key == "LFG" then
        local id = GetChannelName and GetChannelName(key == "WORLD" and "World" or "LookingForGroup")
        if id and id > 0 then return "CHANNEL", id end
        return "SAY", nil
    end
    return key, nil
end

RT.Modules.Register({
    id       = "invite",
    title    = "Invite",
    tip      = "Auto-Invite: players whisper a keyword to get invited automatically. Handles 'already grouped' players (they reply '+1' to be re-invited instantly), offline retry, and a repeating LFM announce.",
    color    = { 0.35, 0.75, 0.95 },
    tabWidth = 76,

    build = function(panel)
        if RT_AI and RT_AI.EnsureDB then RT_AI.EnsureDB() end
        local bd = (RT_DB and RT_DB.ai) or {}

        RT.UI.Label(panel, {
            text   = "|cff59BFF2Auto-Invite|r  —  invite players who whisper a keyword",
            font   = "GameFontNormal",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -10 },
        })

        -- ── Row 1 : keyword / max / start / stop ────────────────
        local kwLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        kwLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -38)
        kwLabel:SetText("Keyword:")

        local kwEB = CreateFrame("EditBox", "RT3_InvKeywordEB", panel, "InputBoxTemplate")
        kwEB:SetPoint("LEFT", kwLabel, "RIGHT", 6, 0)
        kwEB:SetWidth(70) kwEB:SetHeight(20) kwEB:SetAutoFocus(false)
        kwEB:SetText(bd.keyword or "inv")
        kwEB:SetScript("OnEscapePressed", function() kwEB:ClearFocus() end)
        kwEB:SetScript("OnEnterPressed", function() kwEB:ClearFocus() end)
        panel._invKwEB = kwEB

        local maxLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        maxLabel:SetPoint("LEFT", kwEB, "RIGHT", 12, 0)
        maxLabel:SetText("Max:")

        local maxEB = CreateFrame("EditBox", "RT3_InvMaxEB", panel, "InputBoxTemplate")
        maxEB:SetPoint("LEFT", maxLabel, "RIGHT", 6, 0)
        maxEB:SetWidth(36) maxEB:SetHeight(20) maxEB:SetAutoFocus(false)
        maxEB:SetText(tostring(bd.maxPlayers or 40))
        maxEB:SetScript("OnEscapePressed", function() maxEB:ClearFocus() end)
        maxEB:SetScript("OnEnterPressed", function() maxEB:ClearFocus() end)
        panel._invMaxEB = maxEB

        local startBtn = RT.UI.Button(panel, {
            text = "Start", width = 70, height = 22, color = { 0.10, 0.55, 0.15 },
            anchor = { "LEFT", maxEB, "RIGHT", 14, 0 },
            tooltip = "Starts Auto-Invite: whispers the keyword to invite, handles retries and 'already grouped' players.",
            onClick = function()
                if not RT_AI then RT.Print("|cffFF4444RT_AI not loaded.|r") return end
                RT_AI.EnsureDB()
                local kw  = kwEB:GetText() or "inv"
                local max = tonumber(maxEB:GetText()) or 40
                RT_DB.ai.keyword    = kw
                RT_DB.ai.maxPlayers = max
                RT_AI.Start(kw, max)
            end,
        })
        local stopBtn = RT.UI.Button(panel, {
            text = "Stop", width = 60, height = 22, color = { 0.55, 0.15, 0.10 },
            anchor = { "LEFT", startBtn, "RIGHT", 6, 0 },
            onClick = function() if RT_AI then RT_AI.Stop() end end,
        })

        local retryBtn = RT.UI.Button(panel, {
            text = "Retry 30s: OFF", width = 118, height = 22, color = { 0.40, 0.40, 0.40 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -10, -38 },
            tooltip = "When ON: players invited but not yet in the raid (offline, still grouped elsewhere) are automatically re-invited every 30s, and caught the moment they log in.",
        })
        retryBtn:SetScript("OnClick", function()
            RT_AI.EnsureDB()
            RT_DB.ai.retry30 = not RT_DB.ai.retry30
            local tex = retryBtn:GetNormalTexture()
            if RT_DB.ai.retry30 then
                retryBtn:SetText("Retry 30s: ON")
                if tex then tex:SetVertexColor(0.10, 0.55, 0.15) end
                RT.Print("|cff59BFF2[Invite]|r Retry ON: pending players re-invited every 30s. Players grouped elsewhere must reply '+1'.")
            else
                retryBtn:SetText("Retry 30s: OFF")
                if tex then tex:SetVertexColor(0.40, 0.40, 0.40) end
            end
        end)
        panel._invRetryBtn = retryBtn

        -- ── Row 2 : message LFM + canal + annonce manuelle ──────
        local lfmLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        lfmLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -68)
        lfmLabel:SetText("LFM:")

        local lfmEB = CreateFrame("EditBox", "RT3_InvLfmEB", panel, "InputBoxTemplate")
        lfmEB:SetPoint("LEFT", lfmLabel, "RIGHT", 6, 0)
        lfmEB:SetWidth(340) lfmEB:SetHeight(20) lfmEB:SetAutoFocus(false)
        lfmEB:SetText(bd.lfmDesc or "Molten Core")
        lfmEB:SetScript("OnEscapePressed", function() lfmEB:ClearFocus() end)
        lfmEB:SetScript("OnTextChanged", function()
            RT_AI.EnsureDB()
            RT_DB.ai.lfmDesc = lfmEB:GetText() or ""
        end)
        panel._invLfmEB = lfmEB

        local chanBtn = RT.UI.Button(panel, {
            text = "Channel: Say", width = 104, height = 20, color = { 0.30, 0.40, 0.55 },
            anchor = { "LEFT", lfmEB, "RIGHT", 8, 0 },
            tooltip = "LFM broadcast channel: Say / Yell / Guild / World / LFG.",
        })
        chanBtn:SetScript("OnClick", function()
            RT_AI.EnsureDB()
            local cur = RT_DB.ai.lfmChannel or "SAY"
            local idx = 1
            for i = 1, table.getn(RT3_INVITE_CHANS) do
                if RT3_INVITE_CHANS[i] == cur then idx = i break end
            end
            idx = idx + 1
            if idx > table.getn(RT3_INVITE_CHANS) then idx = 1 end
            RT_DB.ai.lfmChannel = RT3_INVITE_CHANS[idx]
            chanBtn:SetText("Channel: " .. RT3_InviteChanLabel(RT_DB.ai.lfmChannel))
        end)
        panel._invChanBtn = chanBtn

        RT.UI.Button(panel, {
            text = "Announce", width = 88, height = 20, color = { 0.20, 0.55, 0.30 },
            anchor = { "LEFT", chanBtn, "RIGHT", 8, 0 },
            tooltip = "Sends the LFM message once, right now.",
            onClick = function()
                RT_AI.EnsureDB()
                local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
                local kw    = kwEB:GetText() or (RT_DB.ai.keyword or "inv")
                local max   = tonumber(maxEB:GetText()) or RT_DB.ai.maxPlayers or 40
                local chanKey, chanId = RT3_InviteResolveChannel(RT_DB.ai.lfmChannel or "SAY")
                local msg = "[LFM] Raid " .. (RT_DB.ai.lfmDesc or "") .. " — " .. nRaid .. "/" .. max
                          .. " — Whisper '" .. kw .. "' to join"
                pcall(SendChatMessage, msg, chanKey, nil, chanId)
            end,
        })

        -- ── Row 3 : spam automatique ─────────────────────────────
        local sep = panel:CreateTexture(nil, "BACKGROUND")
        sep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  6, -94)
        sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -94)
        sep:SetHeight(1) sep:SetTexture(0.3, 0.3, 0.5, 0.6)

        local repLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        repLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -104)
        repLabel:SetText("Repeat every")

        local intervalEB = CreateFrame("EditBox", "RT3_InvIntervalEB", panel, "InputBoxTemplate")
        intervalEB:SetPoint("LEFT", repLabel, "RIGHT", 6, 0)
        intervalEB:SetWidth(40) intervalEB:SetHeight(20) intervalEB:SetAutoFocus(false)
        intervalEB:SetText(tostring(bd.announceInterval or 60))
        intervalEB:SetScript("OnEscapePressed", function() intervalEB:ClearFocus() end)
        intervalEB:SetScript("OnEnterPressed", function()
            RT_AI.EnsureDB()
            local v = tonumber(intervalEB:GetText()) or 60
            if v < 5 then v = 5 end
            RT_DB.ai.announceInterval = v
            intervalEB:SetText(tostring(v))
            intervalEB:ClearFocus()
        end)

        local secLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        secLabel:SetPoint("LEFT", intervalEB, "RIGHT", 4, 0)
        secLabel:SetText("sec")

        local spamBtn = RT.UI.Button(panel, {
            text = "Auto-spam: OFF", width = 118, height = 20, color = { 0.40, 0.40, 0.40 },
            anchor = { "LEFT", secLabel, "RIGHT", 10, 0 },
            tooltip = "Repeats the LFM message automatically at the interval above, while Auto-Invite is active.",
        })
        spamBtn:SetScript("OnClick", function()
            RT_AI.EnsureDB()
            local v = tonumber(intervalEB:GetText()) or 60
            if v < 5 then v = 5 end
            RT_DB.ai.announceInterval = v
            intervalEB:SetText(tostring(v))
            RT_DB.ai.autoAnnounce = not RT_DB.ai.autoAnnounce
            local tex = spamBtn:GetNormalTexture()
            if RT_DB.ai.autoAnnounce then
                spamBtn:SetText("Auto-spam: ON")
                if tex then tex:SetVertexColor(0.10, 0.55, 0.15) end
                RT.Print("|cff59BFF2[Invite]|r Auto-spam ON: LFM repeats every " .. v .. "s.")
            else
                spamBtn:SetText("Auto-spam: OFF")
                if tex then tex:SetVertexColor(0.40, 0.40, 0.40) end
            end
        end)
        panel._invSpamBtn = spamBtn

        -- ── Status + file d'invités ──────────────────────────────
        local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -130)
        status:SetWidth(700) status:SetJustifyH("LEFT")
        status:SetText("|cffAAAAAA Auto-Invite: OFF|r")
        panel._invStatus = status

        local qTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        qTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -150)
        qTitle:SetText("|cffCCCCCCInvited queue|r")

        local scroll, child = RT.UI.ScrollArea(panel, {
            name       = "RT3_InvQueueScroll",
            anchor     = { "TOPLEFT", panel, "TOPLEFT", 8, -168 },
            childWidth = 680,
        })
        scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)

        local list = RT.UI.List(child, {
            rowHeight = 18, gap = 1,
            makeRow = function(l)
                local row = CreateFrame("Frame", nil, l)
                row:SetHeight(18)
                local n = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                n:SetPoint("LEFT", row, "LEFT", 4, 0)
                n:SetWidth(200) n:SetJustifyH("LEFT")
                row._name = n
                local rm = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                rm:SetPoint("LEFT", n, "RIGHT", 8, 0)
                rm:SetWidth(60) rm:SetHeight(16)
                rm:SetText("Remove")
                row._rm = rm
                return row
            end,
            fillRow = function(row, item)
                row._name:SetText("|cffFFFFFF" .. (item.name or "?") .. "|r")
                row._rm:SetScript("OnClick", function()
                    if RT_AI and RT_AI.RemoveFromQueue then RT_AI.RemoveFromQueue(item.name) end
                end)
            end,
        })
        list:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
        list:SetWidth(660)
        panel._invList = list
        panel._invListChild = child

        local function refresh()
            if RT_AI and RT_AI.IsActive and RT_AI.IsActive() then
                local q = RT_AI.GetQueue and RT_AI.GetQueue() or {}
                status:SetText("|cff44FF44Auto-Invite: ON|r  keyword: |cffFFD700"
                    .. (RT_AI.GetKeyword and RT_AI.GetKeyword() or "?") .. "|r  "
                    .. table.getn(q) .. "/" .. (RT_AI.GetMax and RT_AI.GetMax() or "?") .. " invited")
                list:SetItems(q)
            else
                status:SetText("|cffAAAAAA Auto-Invite: OFF|r")
                list:SetItems({})
            end
            child:SetHeight(list:GetHeight() or 1)
        end
        panel._invRefresh = refresh
        if RT_AI and RT_AI.RegisterUIHook then RT_AI.RegisterUIHook(refresh) end
    end,

    show = function(panel)
        if panel._invRefresh then panel._invRefresh() end
        if RT_DB and RT_DB.ai then
            if panel._invChanBtn then panel._invChanBtn:SetText("Channel: " .. RT3_InviteChanLabel(RT_DB.ai.lfmChannel or "SAY")) end
            if panel._invRetryBtn then
                local tex = panel._invRetryBtn:GetNormalTexture()
                if RT_DB.ai.retry30 then
                    panel._invRetryBtn:SetText("Retry 30s: ON")
                    if tex then tex:SetVertexColor(0.10, 0.55, 0.15) end
                else
                    panel._invRetryBtn:SetText("Retry 30s: OFF")
                    if tex then tex:SetVertexColor(0.40, 0.40, 0.40) end
                end
            end
            if panel._invSpamBtn then
                local tex = panel._invSpamBtn:GetNormalTexture()
                if RT_DB.ai.autoAnnounce then
                    panel._invSpamBtn:SetText("Auto-spam: ON")
                    if tex then tex:SetVertexColor(0.10, 0.55, 0.15) end
                else
                    panel._invSpamBtn:SetText("Auto-spam: OFF")
                    if tex then tex:SetVertexColor(0.40, 0.40, 0.40) end
                end
            end
        end
    end,
})
