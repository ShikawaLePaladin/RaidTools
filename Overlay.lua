-- ============================================================
-- RT v2 — Overlay.lua
-- Frame flottante "Mon Attrib" — affiche l'attrib personnelle
-- du joueur connecté. Drag, minimise, ferme.
-- Compatible WoW 1.12 / TurtleWoW
-- ============================================================

local OV = {}
RT_Overlay = OV

-- ── Couleurs rôle ──────────────────────────────────────────
local OV_ROLE_COLOR = {
    Tank = "|cffFFAA00",
    Heal = "|cff44FF44",
    DPS  = "|cffFF6666",
}
local OV_CLASS_COLOR = {
    Warrior  = "|cffC79C6E", Paladin  = "|cffF58CBA",
    Hunter   = "|cffABD473", Rogue    = "|cffFFF569",
    Priest   = "|cffFFFFFF", Shaman   = "|cff0070DE",
    Mage     = "|cff69CCF0", Warlock  = "|cff9482C9",
    Druid    = "|cffFF7D0A",
}

-- ── Frame principale ───────────────────────────────────────
local OV_Frame = nil
local OV_Lines = {}
local OV_Minimized = false

local function OV_ColorClass(class, text)
    return (OV_CLASS_COLOR[class] or "|cffCCCCCC") .. (text or "") .. "|r"
end
local function OV_ColorRole(role, text)
    return (OV_ROLE_COLOR[role] or "|cffCCCCCC") .. (text or "") .. "|r"
end

local function OV_SetLine(idx, text)
    if OV_Lines[idx] then
        OV_Lines[idx]:SetText(text or "")
    end
end

-- ── Construire le contenu depuis RT_AA_LAST ─────────────────
local function OV_BuildContent()
    local player = UnitName and UnitName("player") or ""
    if player == "" or player == "Unknown" then return {} end

    local out = RT_AA_LAST
    if not out then
        return { "|cffFF8800Mon Attrib|r", "|cffAAAAAA(aucune attribution calculée)|r" }
    end

    local analysis = out.analysis or {}
    local myData = nil
    for i = 1, table.getn(analysis.all or {}) do
        if analysis.all[i].name == player then
            myData = analysis.all[i]
            break
        end
    end
    if not myData then
        return {
            "|cffFF8800Mon Attrib|r",
            "|cffFFFF00" .. player .. "|r",
            "|cffAAAAAA(non trouvé dans le roster)|r",
        }
    end

    local lines = {}
    local cc = OV_CLASS_COLOR[myData.class] or "|cffCCCCCC"
    table.insert(lines, "|cffFF8800Mon Attrib|r  " .. cc .. player .. "|r")
    table.insert(lines, OV_ColorRole(myData.role, myData.role) ..
                        "  " .. cc .. (myData.class or "?") ..
                        "|r" .. (myData.spec ~= "" and ("  |cff888888" .. (myData.spec or "") .. "|r") or ""))

    -- Groupe
    local function findGroup(name)
        for g = 1, 8 do
            local grp = out.groups and out.groups[g] or {}
            for s = 1, table.getn(grp) do
                if grp[s] == name then return g end
            end
        end
        return nil
    end
    local grp = findGroup(player)
    if grp then
        table.insert(lines, "|cff88CCFF Groupe " .. grp .. "|r")
    end

    -- Tank ?
    local isTank = false
    for ti = 1, table.getn(out.tanks or {}) do
        if out.tanks[ti] == player then
            isTank = true
            local mk = out.tankMarkers and out.tankMarkers[ti] or ""
            local label = "|cffFFAA00 MT" .. ti .. "|r"
            if mk ~= "" then label = label .. "  |cffFFD700[" .. mk .. "]|r" end
            table.insert(lines, label)
        end
    end

    -- Heal tank ?
    for ti = 1, table.getn(out.healTank or {}) do
        if out.healTank[ti] == player then
            local tname = (out.tanks and out.tanks[ti]) or ("MT" .. ti)
            table.insert(lines, "|cff44FF44 Heal Tank: |r|cffFFAA00" .. tname .. "|r")
        end
    end

    -- Heal raid ?
    for i = 1, table.getn(out.healRaid or {}) do
        if out.healRaid[i] == player then
            table.insert(lines, "|cff44FF44 Heal Raid|r")
        end
    end

    -- Note HoT druide
    if out.druidNote and string.find(out.druidNote, player, 1, true) then
        table.insert(lines, "|cffFF7D0A " .. out.druidNote .. "|r")
    end

    -- Buff à donner
    for i = 1, table.getn(out.buffs or {}) do
        local b = out.buffs[i]
        if b.name == player then
            table.insert(lines, "|cff88FF88 Buff: |r" .. b.buff)
        end
    end

    -- Bénédictions Paladin
    if myData.class == "Paladin" then
        local blessNames = { "Might", "Kings", "Wisdom", "Salvation", "Light", "Sanctuary" }
        local palaAssign = out.blessings and out.blessings[player]
        if palaAssign and table.getn(palaAssign) > 0 then
            for bi = 1, table.getn(palaAssign) do
                local b = palaAssign[bi]
                local bname = blessNames[b.blessIdx] or "Benediction"
                table.insert(lines, "|cffF58CBA Béné " .. bname .. "|r → " .. (b.class or "?"))
            end
        end
    end

    -- Consommables
    local conso = out.conso and out.conso[player]
    if conso then
        table.insert(lines, "|cffFFCC44 Conso:|r |cff888888" .. conso .. "|r")
    end

    return lines
end

-- ── Création de la frame ───────────────────────────────────
function OV.Create()
    if OV_Frame then return end

    local f = CreateFrame("Frame", "RT_OverlayFrame", UIParent)
    OV_Frame = f
    f:SetWidth(280)
    f:SetHeight(160)
    f:SetPoint("CENTER", UIParent, "CENTER", 400, 200)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)

    -- Fond
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true, tileSize = 16, edgeSize = 12,
        insets   = { left=4, right=4, top=4, bottom=4 },
    })
    f:SetBackdropColor(0.04, 0.02, 0.08, 0.95)
    f:SetBackdropBorderColor(0.4, 0.2, 0.8, 1.0)

    -- Barre de titre (drag handle)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -5)
    title:SetText("|cffAA66FF[RT]|r Mon Attrib")

    -- Bouton fermer
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    closeBtn:SetWidth(18)
    closeBtn:SetHeight(18)
    closeBtn:SetScript("OnClick", function() OV.Hide() end)

    -- Bouton minimiser
    local minBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    minBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -4)
    minBtn:SetWidth(18)
    minBtn:SetHeight(14)
    minBtn:SetText("_")
    minBtn:SetScript("OnClick", function() OV.ToggleMinimize() end)

    -- Zone de contenu
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -20)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
    OV.contentFrame = content

    -- Lignes de texte (max 12 lignes)
    for i = 1, 12 do
        local line = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line:SetJustifyH("LEFT")
        if i == 1 then
            line:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -2)
        else
            line:SetPoint("TOPLEFT", OV_Lines[i-1], "BOTTOMLEFT", 0, -1)
        end
        line:SetWidth(268)
        line:SetText("")
        OV_Lines[i] = line
    end

    f:Show()
    RT_DB = RT_DB or {}
    RT_DB.overlay = RT_DB.overlay or {}
    OV.Update()
end

-- ── Mise à jour du contenu ─────────────────────────────────
function OV.Update()
    if not OV_Frame then return end
    local lines = OV_BuildContent()
    for i = 1, 12 do
        OV_Lines[i]:SetText(lines[i] or "")
    end
    -- Ajuste la hauteur dynamiquement
    local count = table.getn(lines)
    local h = math.max(60, 22 + count * 13 + 10)
    OV_Frame:SetHeight(h)
end

function RT_OverlayUpdate()
    OV.Update()
end

function OV.ToggleMinimize()
    OV_Minimized = not OV_Minimized
    if OV_Minimized then
        OV_Frame:SetHeight(24)
        OV.contentFrame:Hide()
    else
        OV.contentFrame:Show()
        OV.Update()
    end
end

function OV.Show()
    if not OV_Frame then OV.Create() else OV_Frame:Show() end
    OV.Update()
end

function OV.Hide()
    if OV_Frame then OV_Frame:Hide() end
end

function OV.Toggle()
    if OV_Frame and OV_Frame:IsShown() then
        OV.Hide()
    else
        OV.Show()
    end
end

-- ── Commande slash ─────────────────────────────────────────
-- /rt overlay  ou  /rt ov
function RT_OverlayToggle()
    OV.Toggle()
end

-- ── Auto-affichage si RT_AA_LAST change ───────────────────
-- Appelé depuis AutoAssign.lua après RT_AA_Apply()
local function OV_OnVarLoaded()
    RT_DB = RT_DB or {}
    RT_DB.overlay = RT_DB.overlay or {}
    if RT_DB.overlay.autoShow then
        OV.Create()
    end
end

local OV_InitFrame = CreateFrame("Frame")
OV_InitFrame:RegisterEvent("VARIABLES_LOADED")
OV_InitFrame:SetScript("OnEvent", function()
    OV_OnVarLoaded()
end)
