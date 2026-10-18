if RTM_DISABLED then return end
-- ============================================================
-- RaidTools Membre — RTM_Main.lua
--
-- Point d'entrée : bouton sur la minimap (clic = page Raid, clic droit = menu des overlays, glisser = déplacer),
-- commande /rtm, message de bienvenue.
-- Lua 5.0 strict.
-- ============================================================

RTM = RTM or {}
local M = RTM
local btn, menu

local function Info()
    local db = RT.Store.DB()
    local plan = db.octofan
    local nS = 0
    for _, R in pairs(db.octofanSchemas or {}) do
        for _ in pairs(R.bosses or {}) do nS = nS + 1 end
    end
    if plan then
        RT.Print("Plan : « " .. (plan.title or "?") .. " »" .. ((plan.date and plan.date ~= "") and (" du " .. plan.date) or "") ..
            " — " .. table.getn(plan.rosterOrder or {}) .. " joueurs, " .. table.getn(plan.bossOrder or {}) .. " boss.")
    else
        RT.Print("Aucun plan reçu pour l'instant : le chef de raid l'envoie avec « Envoyer » (RaidTools complet).")
    end
    RT.Print(nS .. " schéma(s) de boss chargé(s). Overlay actuel : " .. M.GetOverlay() .. ".")
end

-- ---------- bouton minimap ----------

local function PlaceButton(angle)
    local db = RT.Store.DB()
    db.rtm = db.rtm or {}
    if not angle then angle = db.rtm.mmAngle or -0.6 end
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 82, math.sin(angle) * 82)
    db.rtm.mmAngle = angle
end

local function BuildMenu()
    if menu then return end
    menu = CreateFrame("Frame", "RTM_Menu", UIParent)
    menu:SetWidth(210)
    menu:SetHeight(122)
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
    menu.items = {}
    local function Item(label, onClick)
        local it = CreateFrame("Button", nil, menu)
        it:SetHeight(24)
        it:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -(8 + table.getn(menu.items) * 26))
        it:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -6, 0)
        local t = it:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        t:SetAllPoints(it)
        t:SetJustifyH("LEFT")
        it:SetFontString(t)
        it:SetText(" " .. label)
        it:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        it:GetHighlightTexture():SetAlpha(0.35)
        it:SetScript("OnClick", function() onClick(); menu:Hide() end)
        table.insert(menu.items, it)
        return it
    end
    menu.raid = Item("Page Raid (schéma, assignations)", function() if RTV and RTV.Toggle then RTV.Toggle() end end)
    menu.recap = Item("Overlay : Récap", function() M.ToggleOverlay("recap") end)
    menu.role = Item("Overlay : Mon rôle", function() M.ToggleOverlay("role") end)
    menu.none = Item("Aucun overlay", function() M.SetOverlay("none") end)
    -- fermer au clic ailleurs
    local closer = CreateFrame("Frame", nil, UIParent)
    closer:SetFrameStrata("DIALOG")
    closer:SetFrameLevel(menu:GetFrameLevel() - 1)
    closer:SetAllPoints(UIParent)
    closer:EnableMouse(true)
    closer:Hide()
    closer:SetScript("OnMouseDown", function() menu:Hide(); this:Hide() end)
    menu:SetScript("OnShow", function()
        local m = M.GetOverlay()
        menu.recap:SetText(" " .. (m == "recap" and "[x] " or "[ ] ") .. "Overlay : Récap")
        menu.role:SetText(" " .. (m == "role" and "[x] " or "[ ] ") .. "Overlay : Mon rôle")
        closer:Show()
    end)
    menu:SetScript("OnHide", function() closer:Hide() end)
end

local function BuildButton()
    if btn or not Minimap then return end
    btn = CreateFrame("Button", "RTM_MMButton", Minimap)
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
    local ring = btn:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetWidth(54)
    ring:SetHeight(54)
    ring:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    btn:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            BuildMenu()
            if menu:IsShown() then menu:Hide() else menu:Show() end
        elseif RTV and RTV.Toggle then
            RTV.Toggle()
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
        GameTooltip:SetText("|cffAA66FFRaidTools|r |cff66CCFFMembre|r", 1, 0.82, 0.27)
        local plan = RT.Store.DB().octofan
        if plan and plan.title and plan.title ~= "" then
            GameTooltip:AddLine("Plan : " .. plan.title, 0.55, 0.8, 1)
        else
            GameTooltip:AddLine("Pas de plan reçu", 0.6, 0.6, 0.6)
        end
        GameTooltip:AddLine("Overlay : " .. M.GetOverlay(), 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cff888888Clic : page Raid · Clic droit : overlays · Glisser : déplacer|r", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PlaceButton()
end

-- apparition tardive de la minimap (pfUI réorganise l'UI) : on attend un peu
local init = CreateFrame("Frame")
init.t = 0
init:SetScript("OnUpdate", function()
    this.t = this.t + arg1
    if this.t < 3 then return end
    this:SetScript("OnUpdate", nil)
    BuildButton()
end)

-- ---------- commande /rtm ----------

local resetArmed = 0
SLASH_RTM1 = "/rtm"
SLASH_RTM2 = "/raidmembre"
SlashCmdList["RTM"] = function(msg)
    msg = string.lower(msg or "")
    msg = string.gsub(msg, "^%s+", "")
    msg = string.gsub(msg, "%s+$", "")
    if msg == "" or msg == "raid" then
        if RTV and RTV.Toggle then RTV.Toggle() end
    elseif msg == "recap" or msg == "récap" then
        M.ToggleOverlay("recap")
    elseif msg == "role" or msg == "rôle" then
        M.ToggleOverlay("role")
    elseif msg == "off" or msg == "none" then
        M.SetOverlay("none")
    elseif msg == "info" then
        Info()
    elseif msg == "reset" then
        local now = GetTime()
        if now - resetArmed < 6 then
            resetArmed = 0
            if RT.OctoFan and RT.OctoFan.ResetPlan then RT.OctoFan.ResetPlan() end
        else
            resetArmed = now
            RT.Print("Retape /rtm reset sous 6 secondes pour effacer ton plan local.")
        end
    else
        RT.Print("Commandes : /rtm (page Raid) · /rtm recap · /rtm role · /rtm off · /rtm info · /rtm reset")
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    RT.Print("version Membre chargée — /rtm ouvre la page Raid, le bouton de la minimap aussi.")
end)
