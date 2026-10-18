-- ============================================================
-- RT v4 — RT4_MicroMenu.lua
--
-- Micro menu : un bouton (épée) près de la minimap.
--   - survol  : état du raid (effectif, boss, pull)
--   - clic    : menu compact — Mon rôle, Récap, Pull, /rt,
--               bascule Guilde/PUG, Accueil/réglages
--   - déplaçable autour de la minimap (angle mémorisé)
-- Compatible pfUI (bouton indépendant, textures standard).
-- Lua 5.0 strict. Chargé après RT4_Launcher.lua.
-- ============================================================

local btn, menu

-- ────────────────────────────────────────────────────────────
-- Bouton minimap
-- ────────────────────────────────────────────────────────────

local function PlaceButton(angle)
    if not angle then angle = (RT4.GetDB().mmAngle) or -0.6 end
    local x, y = math.cos(angle), math.sin(angle)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x * 82, y * 82)
    RT4.GetDB().mmAngle = angle
end

local function BuildButton()
    btn = CreateFrame("Button", "RT4_MMButton", Minimap)
    btn:SetFrameStrata("MEDIUM")
    btn:SetWidth(34)
    btn:SetHeight(34)
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    bg:SetVertexColor(0.16, 0.12, 0.28, 1)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Sword_39")
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 5, -5)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -5, 5)

    btn:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            -- clic droit : ouvrir directement le shell (page du mode)
            if RT4.OpenShell then RT4.OpenShell() end
        else
            if RT4.ToggleMenu then RT4.ToggleMenu() end
        end
    end)

    btn:SetScript("OnDragStart", function()
        this:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            PlaceButton(math.atan2(py / scale - my, px / scale - mx))
        end)
    end)
    btn:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)

    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText("|cffAA66FFRaidTools|r", 1, 0.82, 0.27)
        local nRaid = (GetNumRaidMembers and GetNumRaidMembers()) or 0
        local nParty = (GetNumPartyMembers and GetNumPartyMembers()) or 0
        if nRaid > 0 then
            GameTooltip:AddLine("Raid : " .. nRaid .. "/40", 0.8, 0.8, 0.8)
        elseif nParty > 0 then
            GameTooltip:AddLine("Groupe : " .. (nParty + 1) .. "/5", 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine("Solo", 0.6, 0.6, 0.6)
        end
        local boss = RT_BOSS_STATE and RT_BOSS_STATE.bossName or ""
        if boss ~= "" then GameTooltip:AddLine("Boss : " .. boss, 1, 0.82, 0.27) end
        local plan = RT.Store.DB().octofan
        if plan and plan.title and plan.title ~= "" then
            GameTooltip:AddLine("Plan : " .. plan.title, 0.55, 0.8, 1)
        end
        local m = (RT.OctoFan and RT.OctoFan.GetMode and RT.OctoFan.GetMode()) or "pug"
        GameTooltip:AddLine("Mode : " .. (m == "guild" and "🏰 Guilde" or "🌍 PUG"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cff888888Clic : menu · Clic droit : ouvrir · Glisser : déplacer|r", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    PlaceButton()
end

-- ────────────────────────────────────────────────────────────
-- Menu
-- ────────────────────────────────────────────────────────────

local function BuildMenu()
    if menu then return end
    menu = CreateFrame("Frame", "RT4_MMMenu", UIParent)
    menu:SetWidth(190)
    menu:SetHeight(196)
    menu:SetPoint("TOPRIGHT", btn, "TOPLEFT", -6, 0)
    menu:SetFrameStrata("DIALOG")
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    menu:SetBackdropColor(0.04, 0.03, 0.07, 0.96)
    menu:SetBackdropBorderColor(0.55, 0.42, 0.16, 1)
    menu:Hide()

    local items = {}
    local function AddItem(label, onClick, keep)
        local it = CreateFrame("Button", nil, menu)
        it:SetHeight(24)
        it:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -(8 + table.getn(items) * 26))
        it:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -6, 0)
        local t = it:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        t:SetAllPoints(it)
        t:SetJustifyH("LEFT")
        t:SetText(" " .. label)
        it:SetFontString(t)
        it:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        it:GetHighlightTexture():SetAlpha(0.35)
        it:SetScript("OnClick", function()
            onClick()
            if not keep then menu:Hide() end
        end)
        table.insert(items, it)
        return it
    end

    AddItem("👤 Mon rôle", function()
        if RT.OctoFan and RT.OctoFan.ShowMyRole then RT.OctoFan.ShowMyRole() end
    end, true)
    AddItem("📋 Mon récap", function()
        if RT4.ToggleRecap then RT4.ToggleRecap() end
    end, true)
    AddItem("⏱ Pull 10s", function()
        RT4.StartPull(10)
    end)
    AddItem("🛠 Raid Tools (/rt)", function()
        RT4.OpenShell()
    end)
    AddItem("🏰/🌍 Mode : Guilde ⇄ PUG", function()
        local cur = (RT.OctoFan and RT.OctoFan.GetMode and RT.OctoFan.GetMode()) or "pug"
        if RT.OctoFan and RT.OctoFan.SetMode then
            RT.OctoFan.SetMode(cur == "guild" and "pug" or "guild")
        end
        RT.Print("|cffAA66FFRaidTools|r: mode " ..
            (cur == "guild" and "🌍 PUG" or "🏰 Guilde") .. ".")
    end, true)
    AddItem("🏠 Accueil / accès", function()
        -- OpenShell BASCULE : ne l'appeler que si le shell n'est pas deja ouvert
        if not (_G.RT3_MainFrame and _G.RT3_MainFrame:IsShown()) then
            RT4.OpenShell()
        end
        if _G.RT3_MainFrame then
            RT.Modules.Show("home")
        end
    end)

    -- fermer au clic ailleurs
    local closer = CreateFrame("Frame", nil, UIParent)
    closer:SetFrameStrata("DIALOG")
    closer:SetFrameLevel(menu:GetFrameLevel() - 1)
    closer:SetAllPoints(UIParent)
    closer:EnableMouse(true)
    closer:Hide()
    closer:SetScript("OnMouseDown", function()
        menu:Hide()
        this:Hide()
    end)
    menu:SetScript("OnShow", function() closer:Show() end)
    menu:SetScript("OnHide", function() closer:Hide() end)
end

function RT4.ToggleMenu()
    BuildMenu()
    if menu:IsShown() then menu:Hide() else menu:Show() end
end

-- Apparition tardive de la minimap (pfUI réorganise l'UI) : retente
local init = CreateFrame("Frame")
init.t = 0
init:SetScript("OnUpdate", function()
    this.t = this.t + arg1
    if this.t < 3 then return end
    this:SetScript("OnUpdate", nil)
    if Minimap then BuildButton() end
end)
