-- RT v3 - Registry.lua
RT.Modules = RT.Modules or {}

local _mods    = {}
local _byId    = {}
local _shell   = nil
local _current = nil

function RT.Modules.Register(def)
    if not def or not def.id or _byId[def.id] then return end
    table.insert(_mods, def)
    _byId[def.id] = def
end

function RT.Modules.Show(id)
    if not _shell then RT.Modules.BuildShell() end
    for i = 1, table.getn(_mods) do
        local m = _mods[i]
        if m._panel then
            if m.id == id then m._panel:Show() else m._panel:Hide() end
        end
        if m._tab then
            if m.id == id then m._tab:LockHighlight() else m._tab:UnlockHighlight() end
        end
    end
    _current = id
    local mod = _byId[id]
    if mod then
        if not mod._built and mod.build then
            local ok, err = pcall(mod.build, mod._panel)
            if not ok then RT.Print("|cffFF4444[build:" .. id .. "] " .. tostring(err) .. "|r") end
            mod._built = true
        end
        if mod.show then
            local ok, err = pcall(mod.show, mod._panel)
            if not ok then RT.Print("|cffFF4444[show:" .. id .. "] " .. tostring(err) .. "|r") end
        end
    end
end

function RT.Modules.BuildShell()
    if _shell then return _shell end

    local MAX_W    = 676
    local TAB_GAP  = 4
    local TAB_H    = 22
    local ROW_STEP = 28
    local START_X  = 16

    local layout = {}
    local curX   = START_X
    local curRow = 0
    for i = 1, table.getn(_mods) do
        local m = _mods[i]
        local w = m.tabWidth or 72
        if curX + w > MAX_W then
            curRow = curRow + 1
            curX   = START_X
        end
        table.insert(layout, { m = m, tx = curX, ry = curRow })
        curX = curX + w + TAB_GAP
    end
    local numRows   = curRow + 1
    local extraH    = (numRows - 1) * ROW_STEP
    local panelOffY = -44 - extraH - 30

    local f = CreateFrame("Frame", "RT3_MainFrame", UIParent)
    f:SetWidth(720)
    f:SetHeight(470 + extraH)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)
    RT.UI.ApplyBackdrop(f, 0.04, 0.03, 0.07, 0.96)

    local titleFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOP", f, "TOP", 0, -14)
    titleFS:SetText("|cffFFCC44R|r|cffFFAA22A|r|cffFF8800I|r|cffFFAA22D|r  |cffFFCC44T|r|cffFFAA22O|r|cffFF8800O|r|cffFFAA22L|r|cffFFCC44S|r  |cff555555•  |r|cff666666OctoWow Beta|r")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetWidth(24); closeBtn:SetHeight(TAB_H)
    closeBtn:SetText("X")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- ── Panneau Paramètres ───────────────────────────────────────
    local settPanel = CreateFrame("Frame", "RT3_SettPanel", f)
    RT.UI.ApplyBackdrop(settPanel, 0.04, 0.04, 0.08, 0.98)
    settPanel:SetWidth(280) settPanel:SetHeight(220)
    settPanel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -38)
    settPanel:SetFrameStrata("DIALOG")
    settPanel:Hide()

    local stTitle = settPanel:CreateFontString(nil,"OVERLAY","GameFontNormal")
    stTitle:SetPoint("TOPLEFT", settPanel, "TOPLEFT", 10, -8)
    stTitle:SetText("|cffFFD700Parametres|r")

    -- Tooltips
    local stTipLbl = settPanel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    stTipLbl:SetPoint("TOPLEFT", settPanel, "TOPLEFT", 10, -28)
    stTipLbl:SetText("Infobulles :")
    local stTipBtn = RT.UI.Button(settPanel, {
        text="ON", width=48, height=18,
        anchor={"TOPLEFT", settPanel, "TOPLEFT", 90, -28},
    })
    stTipBtn:SetScript("OnClick", function()
        local db = RT.Store.DB()
        db.settings = db.settings or {}
        db.settings.tooltips = not (db.settings.tooltips ~= false)
        if db.settings.tooltips ~= false then
            stTipBtn:SetText("ON")
            local tx = stTipBtn:GetNormalTexture()
            if tx then tx:SetVertexColor(0.2,0.8,0.2) end
        else
            stTipBtn:SetText("OFF")
            local tx = stTipBtn:GetNormalTexture()
            if tx then tx:SetVertexColor(0.8,0.2,0.2) end
        end
    end)
    local stTipTex = stTipBtn:GetNormalTexture()
    if stTipTex then stTipTex:SetVertexColor(0.2,0.8,0.2) end

    -- Langue (placeholder)
    local stLangLbl = settPanel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    stLangLbl:SetPoint("TOPLEFT", settPanel, "TOPLEFT", 10, -52)
    stLangLbl:SetText("Langue :")
    local stLangInfo = settPanel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    stLangInfo:SetPoint("TOPLEFT", settPanel, "TOPLEFT", 90, -52)
    stLangInfo:SetText("|cff888888FR / EN — bientot|r")

    -- Séparateur WhisperBot
    local stWBsep = settPanel:CreateTexture(nil,"BACKGROUND")
    stWBsep:SetPoint("TOPLEFT", settPanel, "TOPLEFT", 8, -68)
    stWBsep:SetPoint("TOPRIGHT", settPanel, "TOPRIGHT", -8, -68)
    stWBsep:SetHeight(1) stWBsep:SetTexture(0.4,0.4,0.6,0.4)
    local stWBLbl = settPanel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    stWBLbl:SetPoint("TOPLEFT", settPanel, "TOPLEFT", 10, -74)
    stWBLbl:SetText("|cff99AAFFMP Auto (WhisperBot)|r")

    local function makeWBField(label, key, y)
        local lbl = settPanel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", settPanel, "TOPLEFT", 10, y)
        lbl:SetText(label)
        local eb = CreateFrame("EditBox", nil, settPanel, "InputBoxTemplate")
        eb:SetPoint("TOPLEFT", settPanel, "TOPLEFT", 80, y+2)
        eb:SetWidth(188) eb:SetHeight(16) eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
        eb:SetScript("OnEnterPressed", function()
            local db = RT.Store.DB()
            db.settings = db.settings or {}
            db.settings[key] = this:GetText()
            this:ClearFocus()
        end)
        -- Charger la valeur stockée
        local db = RT.Store.DB()
        local sv = (db.settings or {})[key]
        if sv then eb:SetText(sv) end
        return eb
    end

    makeWBField("Intro :",   "wp_intro", -90)
    makeWBField("Role :",    "wp_role",  -110)
    makeWBField("Groupe :",  "wp_group", -130)

    local stClose = RT.UI.Button(settPanel, {
        text="Fermer", width=68, height=18,
        anchor={"BOTTOMRIGHT", settPanel, "BOTTOMRIGHT", -6, 6},
    })
    stClose:SetScript("OnClick", function() settPanel:Hide() end)

    -- Bouton gear (⚙) à côté du X
    local gearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    gearBtn:SetWidth(24); gearBtn:SetHeight(TAB_H)
    gearBtn:SetText("S")
    gearBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -38, -10)
    gearBtn:SetScript("OnClick", function()
        if settPanel:IsShown() then settPanel:Hide()
        else settPanel:Show() end
    end)
    if RT_AttachSimpleTooltip then RT_AttachSimpleTooltip(gearBtn, "Parametres de l'addon") end

    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  12, -38)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -38)
    sep:SetHeight(2)
    sep:SetTexture(0.80, 0.62, 0.06, 0.7)

    for i = 1, table.getn(layout) do
        local e  = layout[i]
        local m  = e.m
        local w  = m.tabWidth or 72
        local id = m.id
        local tab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        tab:SetWidth(w); tab:SetHeight(TAB_H)
        tab:SetText(m.title or id)
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", e.tx, -44 - e.ry * ROW_STEP)
        tab:SetScript("OnClick", function() RT.Modules.Show(id) end)
        if m.color then
            local fs = tab:GetFontString()
            if fs then fs:SetTextColor(m.color[1], m.color[2], m.color[3]) end
        end
        -- Infobulle d'onglet (titre + description) pour le grand public
        local mref, tref = m, tab
        tref:SetScript("OnEnter", function()
            GameTooltip:SetOwner(tref, "ANCHOR_BOTTOM")
            GameTooltip:SetText(mref.title or id, 1, 0.82, 0)
            if mref.tip then GameTooltip:AddLine(mref.tip, 0.8, 0.8, 0.8) end
            GameTooltip:Show()
        end)
        tref:SetScript("OnLeave", function() GameTooltip:Hide() end)
        m._tab = tab
        local p = CreateFrame("Frame", "RT3_Panel_" .. id, f)
        p:SetPoint("TOPLEFT",     f, "TOPLEFT",      12, panelOffY)
        p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12,  12)
        RT.UI.ApplyBackdrop(p, 0.02, 0.02, 0.04, 0.85)
        p:Hide()
        m._panel = p
    end

    _shell = f
    f:Hide()
    return f
end

function RT.Modules.Toggle()
    if not _shell then
        local ok, err = pcall(RT.Modules.BuildShell)
        if not ok then RT.Print("|cffFF4444[RT3] Erreur shell: " .. tostring(err) .. "|r"); return end
    end
    if not _shell then RT.Print("|cffFF4444[RT3] Shell nil.|r"); return end
    if _shell:IsShown() then
        _shell:Hide()
    else
        _shell:Show()
        local id = _current or (_mods[1] and _mods[1].id)
        if id then
            local ok, err = pcall(RT.Modules.Show, id)
            if not ok then RT.Print("|cffFF4444[RT3] Erreur show: " .. tostring(err) .. "|r") end
        else
            RT.Print("|cffFFAA00[RT3] Aucun module enregistre.|r")
        end
    end
end

SLASH_RT3_1 = "/rt3"
SlashCmdList["RT3"] = function()
    RT.Modules.Toggle()
end

SLASH_RT3DEBUG_1 = "/rt3debug"
SlashCmdList["RT3DEBUG"] = function()
    RT.Print("--- RT v3 Debug ---")
    RT.Print("Modules: " .. table.getn(_mods) .. "  Shell: " .. tostring(_shell))
    for i = 1, table.getn(_mods) do
        RT.Print("  [" .. i .. "] " .. (_mods[i].id or "?") .. " w=" .. (_mods[i].tabWidth or 72))
    end
end

RT.Events({ "VARIABLES_LOADED" }, function()
    local n = table.getn(_mods)
    RT.Print("|cff44FF88v3 charge|r - /rt v3 pour ouvrir (" .. n .. " modules)")
end)
