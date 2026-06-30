-- ============================================================
-- RT v3 — Bouton minimap (style addon classique)
-- Clic gauche : ouvrir/fermer le menu v3. Glisser : déplacer.
-- Position sauvegardée dans RT_DB.minimapAngle.
-- Tout est dans un bloc do...end : aucun local au niveau du chunk
-- (limite Lua 5.0 = 200 locals par chunk).
-- ============================================================

do
    local RTMB = CreateFrame("Button", "RT3_MinimapButton", Minimap)
    RTMB:SetWidth(31) RTMB:SetHeight(31)
    RTMB:SetFrameStrata("MEDIUM")
    RTMB:SetFrameLevel(8)
    RTMB:EnableMouse(true)
    RTMB:SetMovable(true)
    RTMB:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    RTMB:RegisterForDrag("LeftButton")

    local icon = RTMB:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    icon:SetWidth(20) icon:SetHeight(20)
    icon:SetPoint("TOPLEFT", RTMB, "TOPLEFT", 6, -6)

    local border = RTMB:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(53) border:SetHeight(53)
    border:SetPoint("TOPLEFT", RTMB, "TOPLEFT", 0, 0)

    RTMB:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Globals (pas de slot local) pour rester sous la limite de 200 locals/chunk
    function RT3MB_Position()
        local angle = (RT_DB and RT_DB.minimapAngle) or 210
        RT3_MinimapButton:ClearAllPoints()
        RT3_MinimapButton:SetPoint("CENTER", Minimap, "CENTER", 80 * cos(angle), 80 * sin(angle))
    end

    function RT3MB_Drag()
        if not math.atan2 then return end
        local mx, my = Minimap:GetCenter()
        local scale  = Minimap:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx = cx / scale
        cy = cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        if angle < 0 then angle = angle + 360 end
        RT_DB = RT_DB or {}
        RT_DB.minimapAngle = angle
        RT3MB_Position()
    end

    RTMB:SetScript("OnClick", function()
        if RT and RT.Modules and RT.Modules.Toggle then
            RT.Modules.Toggle()
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[RT] Menu non chargé.|r")
        end
    end)

    RTMB:SetScript("OnDragStart", function() this:SetScript("OnUpdate", RT3MB_Drag) end)
    RTMB:SetScript("OnDragStop",  function() this:SetScript("OnUpdate", nil) end)

    RTMB:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffFFD700RT — Raid Tool|r")
        GameTooltip:AddLine("Clic gauche : ouvrir le menu", 1, 1, 1)
        GameTooltip:AddLine("Glisser : déplacer le bouton", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    RTMB:SetScript("OnLeave", function() GameTooltip:Hide() end)

    RTMB:RegisterEvent("VARIABLES_LOADED")
    RTMB:RegisterEvent("PLAYER_ENTERING_WORLD")
    RTMB:SetScript("OnEvent", function() RT3MB_Position() end)

    RT3MB_Position()
end
