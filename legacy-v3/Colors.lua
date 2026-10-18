-- RT - Raid Tool | Colors Module
-- Couleurs et utilitaires visuels
-- ============================================================

-- Couleurs par classe (r/g/b pour SetVertexColor, hex pour color codes)
RT_CLASS_COLORS = {
    ["Warrior"]  = { r=0.78, g=0.61, b=0.43, hex="C79C6E" },
    ["Paladin"]  = { r=0.96, g=0.55, b=0.73, hex="F58CBA" },
    ["Hunter"]   = { r=0.67, g=0.83, b=0.45, hex="ABD473" },
    ["Rogue"]    = { r=1.00, g=0.96, b=0.41, hex="FFF569" },
    ["Priest"]   = { r=1.00, g=1.00, b=1.00, hex="FFFFFF" },
    ["Shaman"]   = { r=0.00, g=0.44, b=0.87, hex="0070DE" },
    ["Mage"]     = { r=0.41, g=0.80, b=0.94, hex="69CCF0" },
    ["Warlock"]  = { r=0.58, g=0.51, b=0.79, hex="9482C9" },
    ["Druid"]    = { r=1.00, g=0.49, b=0.04, hex="FF7D0A" },
}

-- Couleurs de rôles
RT_ROLE_COLORS = {
    ["Tank"]  = { r=0.20, g=0.60, b=1.00, hex="3399FF" },
    ["Heal"]  = { r=0.20, g=1.00, b=0.20, hex="33FF33" },
    ["DPS"]   = { r=1.00, g=0.30, b=0.30, hex="FF4D4D" },
    ["?"]     = { r=0.60, g=0.60, b=0.60, hex="999999" },
}

-- Retourne le nom coloré par classe
function RT_ColorClass(name, class)
    local color = RT_CLASS_COLORS[class]
    if color then
        return "|cff" .. color.hex .. name .. "|r"
    end
    return name
end

-- Retourne le rôle coloré
function RT_ColorRole(role)
    local color = RT_ROLE_COLORS[role] or RT_ROLE_COLORS["?"]
    return "|cff" .. color.hex .. (role or "?") .. "|r"
end

-- Texte orange (titres)
function RT_ColorTitle(text)
    return "|cffFF7D0A" .. text .. "|r"
end

-- Texte vert (succès)
function RT_ColorOK(text)
    return "|cff00FF00" .. text .. "|r"
end

-- Texte rouge (erreur)
function RT_ColorErr(text)
    return "|cffFF3333" .. text .. "|r"
end

-- Texte doré (valeurs)
function RT_ColorGold(text)
    return "|cffFFD700" .. text .. "|r"
end

-- Utilitaires UI
function RT_PadRight(text, width)
    local t = tostring(text or "")
    local pad = width - string.len(t)
    if pad < 1 then return t end
    return t .. string.rep(" ", pad)
end

function RT_AttachSimpleTooltip(frame, text)
    if not frame or not text or text == "" then return end
    frame:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 0.85, 0.2, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end
