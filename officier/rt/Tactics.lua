-- ============================================================
-- RT v2 - Tactics.lua
-- Boss tactics panel: search, display, raid announce, custom tactics.
-- The built-in strategy database that used to be bundled here came from Tactica by Player-Doite
-- (https://github.com/Player-Doite/tactica), whose license does not allow redistribution without the author's
-- permission. It is therefore NOT included in this release: the panel starts empty and you can add your own
-- tactics (custom tactics are saved in your RT_DB).
-- Compatible WoW 1.12 / TurtleWoW
-- ============================================================

RT_Tactics = RT_Tactics or {}

-- Format : { boss=string, raid=string, lines={string,...} }
RT_TACTICS_DB = {}

-- ── Index de recherche ──────────────────────────────────────
local RT_TACTICS_INDEX = nil

local function Tactics_BuildIndex()
    if RT_TACTICS_INDEX then return end
    RT_TACTICS_INDEX = {}
    for i = 1, table.getn(RT_TACTICS_DB) do
        local t = RT_TACTICS_DB[i]
        local key = string.lower(t.boss)
        RT_TACTICS_INDEX[key] = i
        -- Alias courts
        local short = string.lower(string.gsub(t.boss, " ", ""))
        RT_TACTICS_INDEX[short] = i
    end
end

-- ── Recherche ──────────────────────────────────────────────
function RT_Tactics.Find(query)
    Tactics_BuildIndex()
    if not query or query == "" then return nil end
    local q = string.lower(RT_BTrim and RT_BTrim(query) or query)
    -- Match exact
    if RT_TACTICS_INDEX[q] then
        return RT_TACTICS_DB[RT_TACTICS_INDEX[q]]
    end
    -- Match partiel
    for i = 1, table.getn(RT_TACTICS_DB) do
        if string.find(string.lower(RT_TACTICS_DB[i].boss), q, 1, true)
        or string.find(string.lower(RT_TACTICS_DB[i].raid or ""), q, 1, true) then
            return RT_TACTICS_DB[i]
        end
    end
    -- Customs
    if RT_DB and RT_DB.customTactics then
        for j = 1, table.getn(RT_DB.customTactics) do
            local ct = RT_DB.customTactics[j]
            if string.find(string.lower(ct.boss or ""), q, 1, true) then
                return ct
            end
        end
    end
    return nil
end

function RT_Tactics.FindAll(query)
    local results = {}
    local q = query and string.lower(RT_BTrim and RT_BTrim(query) or query) or ""
    for i = 1, table.getn(RT_TACTICS_DB) do
        local t = RT_TACTICS_DB[i]
        if q == "" or string.find(string.lower(t.boss), q, 1, true)
                   or string.find(string.lower(t.raid or ""), q, 1, true) then
            table.insert(results, t)
        end
    end
    if RT_DB and RT_DB.customTactics then
        for j = 1, table.getn(RT_DB.customTactics) do
            local ct = RT_DB.customTactics[j]
            if q == "" or string.find(string.lower(ct.boss or ""), q, 1, true) then
                table.insert(results, ct)
            end
        end
    end
    return results
end

-- ── Poster une tactique ────────────────────────────────────
function RT_Tactics.Post(bossName, channel)
    local tactic = RT_Tactics.Find(bossName)
    if not tactic then
        RT_Print("|cffFF4444[Tactics] No tactic found for: " .. (bossName or "?") .. "|r")
        return false
    end
    channel = channel or "RAID"
    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    if nRaid == 0 and nParty == 0 then channel = "SAY" end
    if nRaid == 0 and nParty > 0 then channel = "PARTY" end
    local lang = GetDefaultLanguage and GetDefaultLanguage("player") or nil
    for i = 1, table.getn(tactic.lines) do
        pcall(SendChatMessage, tactic.lines[i], channel, lang, nil)
    end
    RT_Print("|cff88FF88[Tactics] Tactic for " .. tactic.boss .. " posted to " .. channel .. ".|r")
    return true
end

-- ── Ajouter une tactique custom ────────────────────────────
function RT_Tactics.AddCustom(bossName, text)
    if not bossName or bossName == "" or not text or text == "" then return false end
    RT_DB = RT_DB or {}
    RT_DB.customTactics = RT_DB.customTactics or {}
    -- Remplace si existant
    for i = 1, table.getn(RT_DB.customTactics) do
        if string.lower(RT_DB.customTactics[i].boss) == string.lower(bossName) then
            RT_DB.customTactics[i] = { boss=bossName, raid="Custom", lines={text}, custom=true }
            RT_Print("|cff88FF88[Tactics] Tactic for " .. bossName .. " updated.|r")
            RT_TACTICS_INDEX = nil
            return true
        end
    end
    table.insert(RT_DB.customTactics, { boss=bossName, raid="Custom", lines={text}, custom=true })
    RT_Print("|cff88FF88[Tactics] Tactic for " .. bossName .. " added.|r")
    RT_TACTICS_INDEX = nil
    return true
end

function RT_Tactics.DeleteCustom(bossName)
    if not RT_DB or not RT_DB.customTactics then return end
    for i = table.getn(RT_DB.customTactics), 1, -1 do
        if string.lower(RT_DB.customTactics[i].boss) == string.lower(bossName or "") then
            table.remove(RT_DB.customTactics, i)
            RT_Print("|cffFFAA00[Tactics] Tactic for " .. bossName .. " removed.|r")
            RT_TACTICS_INDEX = nil
            return
        end
    end
end

-- ── UI Panneau ─────────────────────────────────────────────
local TACT_ROWS     = {}
local TACT_SELECTED = nil

function RT_BuildUITactics(parent)
    local p = parent
    RT_DB = RT_DB or {}
    RT_DB.customTactics = RT_DB.customTactics or {}

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -4)
    title:SetText("|cffFFD700Tactics|r  —  " .. table.getn(RT_TACTICS_DB) .. " bosses + custom tactics")
    title:SetTextColor(1.0, 0.85, 0.0)

    -- Recherche
    local searchLabel = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    searchLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -24)
    searchLabel:SetText("Search:")

    local searchBox = CreateFrame("EditBox", "RT_TacticSearchBox", p, "InputBoxTemplate")
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
    searchBox:SetWidth(200)
    searchBox:SetHeight(22)
    searchBox:SetAutoFocus(false)
    searchBox:SetText("")

    -- Bouton filtrer par raid actif
    local bossBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    bossBtn:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    bossBtn:SetWidth(110)
    bossBtn:SetHeight(22)
    bossBtn:SetText("Current boss")
    bossBtn:SetScript("OnClick", function()
        local bossName = (RT_BOSS_STATE and RT_BOSS_STATE.bossName) or ""
        if bossName ~= "" then
            searchBox:SetText(bossName)
            RT_TacticsRefreshList(bossName)
        else
            RT_Print("|cffFFAA00[Tactics] No boss selected in the Boss tab.|r")
        end
    end)

    -- Zone gauche : liste des boss
    local listScroll = CreateFrame("ScrollFrame", "RT_TacticListScroll", p, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -48)
    listScroll:SetWidth(220)
    listScroll:SetHeight(330)

    local listContent = CreateFrame("Frame", "RT_TacticListContent", listScroll)
    listContent:SetWidth(200)
    listContent:SetHeight(3000)
    listScroll:SetScrollChild(listContent)

    for i = 1, 60 do
        local row = CreateFrame("Button", "RT_TacticRow" .. i, listContent)
        row:SetWidth(198)
        row:SetHeight(16)
        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -(i-1)*17)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetTexture(0.0, 0.0, 0.0, 0.0)
        row._bg = bg

        local txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("LEFT", row, "LEFT", 4, 0)
        txt:SetWidth(190)
        txt:SetJustifyH("LEFT")
        row._txt = txt
        row:Hide()
        TACT_ROWS[i] = row
    end

    -- Zone droite : contenu de la tactique sélectionnée
    local previewBg = p:CreateTexture(nil, "BACKGROUND")
    previewBg:SetPoint("TOPLEFT", p, "TOPLEFT", 234, -48)
    previewBg:SetWidth(488)
    previewBg:SetHeight(280)
    previewBg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    previewBg:SetVertexColor(0.02, 0.02, 0.04, 1.0)

    local previewScroll = CreateFrame("ScrollFrame", "RT_TacticPreviewScroll", p, "UIPanelScrollFrameTemplate")
    previewScroll:SetPoint("TOPLEFT", p, "TOPLEFT", 234, -48)
    previewScroll:SetWidth(486)
    previewScroll:SetHeight(280)

    local previewContent = CreateFrame("Frame", nil, previewScroll)
    previewContent:SetWidth(460)
    previewContent:SetHeight(2000)
    previewScroll:SetScrollChild(previewContent)

    local previewText = previewContent:CreateFontString("RT_TacticPreviewText", "OVERLAY", "GameFontNormalSmall")
    previewText:SetPoint("TOPLEFT", previewContent, "TOPLEFT", 4, -4)
    previewText:SetWidth(450)
    previewText:SetJustifyH("LEFT")
    previewText:SetText("|cff888888Select a boss on the left|r")

    -- Boutons d'action sous la preview
    local postRaidBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    postRaidBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 234, -336)
    postRaidBtn:SetWidth(100)
    postRaidBtn:SetHeight(24)
    postRaidBtn:SetText("|cff88FF88Post /Raid|r")
    local prTex = postRaidBtn:GetNormalTexture()
    if prTex then prTex:SetVertexColor(0.1, 0.6, 0.2) end
    postRaidBtn:SetScript("OnClick", function()
        if TACT_SELECTED then RT_Tactics.Post(TACT_SELECTED, "RAID") end
    end)

    local postPartyBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    postPartyBtn:SetPoint("LEFT", postRaidBtn, "RIGHT", 4, 0)
    postPartyBtn:SetWidth(100)
    postPartyBtn:SetHeight(24)
    postPartyBtn:SetText("Post /Party")
    postPartyBtn:SetScript("OnClick", function()
        if TACT_SELECTED then RT_Tactics.Post(TACT_SELECTED, "PARTY") end
    end)

    local postSayBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    postSayBtn:SetPoint("LEFT", postPartyBtn, "RIGHT", 4, 0)
    postSayBtn:SetWidth(80)
    postSayBtn:SetHeight(24)
    postSayBtn:SetText("Post /Say")
    postSayBtn:SetScript("OnClick", function()
        if TACT_SELECTED then RT_Tactics.Post(TACT_SELECTED, "SAY") end
    end)

    -- Zone custom
    local customSep = p:CreateTexture(nil, "ARTWORK")
    customSep:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -386)
    customSep:SetWidth(718)
    customSep:SetHeight(1)
    customSep:SetTexture(0.5, 0.5, 0.2, 0.5)

    local customTitle = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    customTitle:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -394)
    customTitle:SetText("|cffFFD700Custom Tactic|r")

    local customNameLabel = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    customNameLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -410)
    customNameLabel:SetText("Boss:")

    local customNameEdit = CreateFrame("EditBox", "RT_TacticCustomName", p, "InputBoxTemplate")
    customNameEdit:SetPoint("LEFT", customNameLabel, "RIGHT", 6, 0)
    customNameEdit:SetWidth(160)
    customNameEdit:SetHeight(20)
    customNameEdit:SetAutoFocus(false)
    customNameEdit:SetText("")
    customNameEdit:SetScript("OnEscapePressed", function() customNameEdit:ClearFocus() end)

    local customTextEdit = CreateFrame("EditBox", "RT_TacticCustomText", p, "InputBoxTemplate")
    customTextEdit:SetPoint("LEFT", customNameEdit, "RIGHT", 8, 0)
    customTextEdit:SetWidth(400)
    customTextEdit:SetHeight(20)
    customTextEdit:SetAutoFocus(false)
    customTextEdit:SetText("")
    customTextEdit:SetScript("OnEscapePressed", function() customTextEdit:ClearFocus() end)

    local customSaveBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    customSaveBtn:SetPoint("TOPLEFT", customNameLabel, "BOTTOMLEFT", 0, -6)
    customSaveBtn:SetWidth(90)
    customSaveBtn:SetHeight(22)
    customSaveBtn:SetText("Save")
    customSaveBtn:SetScript("OnClick", function()
        local boss = RT_BTrim and RT_BTrim(customNameEdit:GetText()) or customNameEdit:GetText()
        local text = customTextEdit:GetText()
        if boss ~= "" and text ~= "" then
            RT_Tactics.AddCustom(boss, text)
            RT_TacticsRefreshList("")
            customNameEdit:SetText("")
            customTextEdit:SetText("")
        end
    end)

    local customDelBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    customDelBtn:SetPoint("LEFT", customSaveBtn, "RIGHT", 4, 0)
    customDelBtn:SetWidth(80)
    customDelBtn:SetHeight(22)
    customDelBtn:SetText("Delete")
    customDelBtn:SetScript("OnClick", function()
        if TACT_SELECTED then
            RT_Tactics.DeleteCustom(TACT_SELECTED)
            TACT_SELECTED = nil
            if RT_TacticPreviewText then
                RT_TacticPreviewText:SetText("|cff888888Select a boss|r")
            end
            RT_TacticsRefreshList("")
        end
    end)

    -- Refresh liste initial
    local function onSearch()
        local q = searchBox:GetText()
        RT_TacticsRefreshList(q)
    end
    searchBox:SetScript("OnTextChanged", onSearch)
    searchBox:SetScript("OnEnterPressed", function()
        onSearch()
        searchBox:ClearFocus()
    end)

    RT_TacticsRefreshList("")
end

-- ── Refresh la liste ────────────────────────────────────────
function RT_TacticsRefreshList(query)
    local results = RT_Tactics.FindAll(query or "")
    local raidColors = {
        ["Molten Core"]           = "FF8800",
        ["Blackwing Lair"]        = "CC4444",
        ["Zul'Gurub"]             = "44FFAA",
        ["Ruins of Ahn'Qiraj"]   = "FFDD44",
        ["Temple of Ahn'Qiraj"]  = "FF6600",
        ["Naxxramas"]             = "AA66FF",
        ["Onyxia's Lair"]        = "66CCFF",
        ["World Boss"]            = "FF4488",
        ["Custom"]                = "FFFFFF",
    }
    local maxR = math.min(table.getn(results), 60)
    for i = 1, 60 do
        local row = getglobal("RT_TacticRow" .. i)
        if not row then break end
        if i <= maxR then
            local t = results[i]
            local color = raidColors[t.raid] or "CCCCCC"
            row._txt:SetText("|cff" .. color .. t.boss .. "|r")
            local boss = t.boss
            row:SetScript("OnClick", function()
                TACT_SELECTED = boss
                -- Highlight
                for j = 1, 60 do
                    local r2 = getglobal("RT_TacticRow" .. j)
                    if r2 and r2._bg then r2._bg:SetTexture(0,0,0,0) end
                end
                if row._bg then row._bg:SetTexture(0.2, 0.1, 0.5, 0.5) end
                -- Affiche dans la preview
                local tactic = RT_Tactics.Find(boss)
                local pt = getglobal("RT_TacticPreviewText")
                if pt and tactic then
                    local txt = "|cffFFD700" .. tactic.boss .. "|r  |cff888888(" .. (tactic.raid or "") .. ")|r\n\n"
                    for li = 1, table.getn(tactic.lines) do
                        txt = txt .. tactic.lines[li] .. "\n"
                    end
                    pt:SetText(txt)
                end
            end)
            row:Show()
        else
            row:Hide()
        end
    end
end
