-- ============================================================
-- RT v2 — CooldownTracker.lua
-- Suivi des cooldowns importants de raid (inspiré ExRT)
-- Vanilla 1.12 : tracking manuel + class-based timers
-- Sync via Sync.lua (CD message)
-- ============================================================

RT_CD = RT_CD or {}

-- ── Définition des CDs par classe (vanilla 1.12) ───────────
-- { name, icon_hint, duration_sec, color }
local CD_DEFS = {
    Druid = {
        { id="rebirth",     label="Rebirth",         dur=1800, color="FF7D0A" },
        { id="tranquility", label="Tranquility",      dur=300,  color="FF7D0A" },
        { id="barkskin",    label="Barkskin",         dur=60,   color="FF7D0A" },
    },
    Paladin = {
        { id="divshield",   label="Divine Shield",    dur=300,  color="F58CBA" },
        { id="divinv",      label="Divine Intervention",dur=1800,color="F58CBA" },
        { id="layonh",      label="Lay on Hands",     dur=3600, color="F58CBA" },
        { id="blessp",      label="Blessing of Prot", dur=300,  color="F58CBA" },
    },
    Warrior = {
        { id="shieldwall",  label="Shield Wall",      dur=1800, color="C79C6E" },
        { id="laststand",   label="Last Stand",       dur=600,  color="C79C6E" },
        { id="retaliation", label="Retaliation",      dur=1800, color="C79C6E" },
        { id="recklessness",label="Recklessness",     dur=1800, color="C79C6E" },
    },
    Priest = {
        { id="innervate",   label="Inner Fire",       dur=180,  color="FFFFFF" },
        { id="fearlord",    label="Fear Ward",        dur=30,   color="FFFFFF" },
    },
    Shaman = {
        { id="reincarnation",label="Reincarnation",   dur=3600, color="0070DE" },
    },
    Mage = {
        { id="iceblock",    label="Ice Block",        dur=300,  color="69CCF0" },
        { id="combustion",  label="Combustion",       dur=180,  color="69CCF0" },
    },
    Warlock = {
        { id="soulstone",   label="Soulstone",        dur=1800, color="9482C9" },
        { id="gateway",     label="Healthstone",      dur=900,  color="9482C9" },
    },
}

-- ── État des CDs ────────────────────────────────────────────
-- RT_CD_STATE[playerName][cdId] = { usedAt, duration }
RT_CD_STATE = RT_CD_STATE or {}

-- ── Frame principale ────────────────────────────────────────
local CD_FRAME = nil
local CD_ROWS  = {}

local CLASS_COLOR = {
    Warrior="C79C6E", Paladin="F58CBA", Hunter="ABD473", Rogue="FFF569",
    Priest="FFFFFF",  Shaman="0070DE",  Mage="69CCF0",   Warlock="9482C9",
    Druid="FF7D0A",
}

local function CD_MakeRow(parent, yOff)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(340)
    row:SetHeight(18)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOff)

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", row, "LEFT", 2, 0)
    nameText:SetWidth(90)
    nameText:SetJustifyH("LEFT")

    local cdText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cdText:SetPoint("LEFT", row, "LEFT", 96, 0)
    cdText:SetWidth(240)
    cdText:SetJustifyH("LEFT")

    row.nameText = nameText
    row.cdText   = cdText
    row:Hide()
    return row
end

local function CD_CreateFrame()
    if CD_FRAME then return end

    local f = CreateFrame("Frame", "RT_CDFrame", UIParent)
    f:SetWidth(360)
    f:SetHeight(300)
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -200)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:Hide()

    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left=3, right=3, top=3, bottom=3 },
    })
    f:SetBackdropColor(0.04, 0.02, 0.08, 0.92)
    f:SetBackdropBorderColor(0.5, 0.2, 0.8, 1.0)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -6)
    title:SetText("|cffAA66FFCooldowns Raid|r")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    closeBtn:SetWidth(18)
    closeBtn:SetHeight(18)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Zone de contenu scrollable (max 15 rows visibles)
    for i = 1, 30 do
        CD_ROWS[i] = CD_MakeRow(f, -16 - (i-1)*18)
    end

    -- Timer de refresh (1.12 : GetTime au lieu de elapsed)
    local _cdLast = GetTime()
    f:SetScript("OnUpdate", function()
        if (GetTime() - _cdLast) < 1 then return end
        _cdLast = GetTime()
        RT_CD.Refresh()
    end)

    CD_FRAME = f
end

-- ── Marquer un CD comme utilisé ─────────────────────────────
function RT_CD.Use(playerName, cdId, broadcast)
    playerName = playerName or (UnitName and UnitName("player") or "")
    if playerName == "" or not cdId then return end

    RT_DB = RT_DB or {}
    RT_DB.cdState = RT_DB.cdState or {}
    RT_DB.cdState[playerName] = RT_DB.cdState[playerName] or {}

    -- Trouve la durée du CD
    local dur = 300
    local class = (RT_DB.roster and RT_DB.roster[playerName] and RT_DB.roster[playerName].class) or ""
    local classCDs = CD_DEFS[class] or {}
    for i = 1, table.getn(classCDs) do
        if classCDs[i].id == cdId then
            dur = classCDs[i].dur
            break
        end
    end

    RT_DB.cdState[playerName][cdId] = {
        usedAt   = GetTime and GetTime() or 0,
        duration = dur,
    }

    if broadcast ~= false and RT_Sync_Send then
        RT_Sync_Send("CD", playerName, cdId, tostring(dur))
    end

    RT_CD.Refresh()
    RT_Print("|cffAA66FF[CD]|r " .. playerName .. " a utilisé " .. cdId)
end

function RT_CD.Reset(playerName, cdId, broadcast)
    if not playerName or not cdId then return end
    RT_DB = RT_DB or {}
    RT_DB.cdState = RT_DB.cdState or {}
    if RT_DB.cdState[playerName] then
        RT_DB.cdState[playerName][cdId] = nil
    end
    if broadcast ~= false and RT_Sync_Send then
        RT_Sync_Send("CD", playerName, cdId, "0")
    end
    RT_CD.Refresh()
end

-- ── Sync reception ─────────────────────────────────────────
if RT_Sync_Register then
    RT_Sync_Register("CD", function(sender, pname, cdId, durStr)
        pname = pname or sender
        cdId  = cdId  or ""
        local dur = tonumber(durStr) or 0
        RT_DB = RT_DB or {}
        RT_DB.cdState = RT_DB.cdState or {}
        RT_DB.cdState[pname] = RT_DB.cdState[pname] or {}
        if dur <= 0 then
            RT_DB.cdState[pname][cdId] = nil
        else
            RT_DB.cdState[pname][cdId] = {
                usedAt   = GetTime and GetTime() or 0,
                duration = dur,
            }
        end
        RT_CD.Refresh()
    end)
end

-- ── Refresh display ────────────────────────────────────────
function RT_CD.Refresh()
    if not CD_FRAME or not CD_FRAME:IsShown() then return end

    local now = GetTime and GetTime() or 0
    RT_DB = RT_DB or {}
    local roster  = RT_DB.roster  or {}
    local cdState = RT_DB.cdState or {}

    local entries = {}

    -- Collecte tous les CDs de tous les joueurs du roster
    for name, data in pairs(roster) do
        local class    = data.class or ""
        local classCDs = CD_DEFS[class]
        if classCDs then
            for _, cdDef in pairs(classCDs) do
                local state = cdState[name] and cdState[name][cdDef.id]
                local remaining = 0
                local isOnCD = false
                if state and state.usedAt then
                    remaining = math.max(0, state.duration - (now - state.usedAt))
                    isOnCD = remaining > 0
                end
                table.insert(entries, {
                    name      = name,
                    class     = class,
                    cdId      = cdDef.id,
                    cdLabel   = cdDef.label,
                    dur       = cdDef.dur,
                    remaining = remaining,
                    isOnCD    = isOnCD,
                    color     = cdDef.color or "CCCCCC",
                    classColor= CLASS_COLOR[class] or "CCCCCC",
                })
            end
        end
    end

    -- Trie : dispo (remaining=0) d'abord, puis par remaining croissant
    table.sort(entries, function(a, b)
        if a.isOnCD ~= b.isOnCD then return (a.isOnCD and 1 or 0) < (b.isOnCD and 1 or 0) end
        return a.remaining < b.remaining
    end)

    -- Affiche dans les rows
    local maxRows = math.min(table.getn(entries), 30)
    for i = 1, 30 do
        if i <= maxRows then
            local e = entries[i]
            CD_ROWS[i].nameText:SetText("|cff" .. e.classColor .. e.name .. "|r")
            local cdStr
            if e.isOnCD then
                local m = math.floor(e.remaining / 60)
                local s = math.mod(math.floor(e.remaining), 60)
                if m > 0 then
                    cdStr = "|cffFF4444" .. e.cdLabel .. "|r |cff888888" .. m .. "m" .. s .. "s|r"
                else
                    cdStr = "|cffFF8800" .. e.cdLabel .. "|r |cff888888" .. s .. "s|r"
                end
            else
                cdStr = "|cff44FF44" .. e.cdLabel .. "|r |cff44FF44✓ dispo|r"
            end
            CD_ROWS[i].cdText:SetText(cdStr)

            -- Bouton "Utilisé" sur clic de la row
            if not CD_ROWS[i]._btn then
                local btn = CreateFrame("Button", nil, CD_ROWS[i])
                btn:SetAllPoints(CD_ROWS[i])
                btn:SetScript("OnClick", function()
                    local entry = entries[i]
                    if entry then
                        if entry.isOnCD then
                            RT_CD.Reset(entry.name, entry.cdId, true)
                        else
                            RT_CD.Use(entry.name, entry.cdId, true)
                        end
                    end
                end)
                btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                CD_ROWS[i]._btn = btn
            end
            CD_ROWS[i]:Show()
        else
            CD_ROWS[i]:Hide()
        end
    end

    -- Ajuste hauteur
    local h = math.max(50, 22 + maxRows * 18 + 10)
    CD_FRAME:SetHeight(h)
end

-- ── Afficher/masquer ────────────────────────────────────────
function RT_CD.Show()
    if not CD_FRAME then CD_CreateFrame() end
    CD_FRAME:Show()
    RT_CD.Refresh()
end

function RT_CD.Hide()
    if CD_FRAME then CD_FRAME:Hide() end
end

function RT_CD.Toggle()
    if CD_FRAME and CD_FRAME:IsShown() then RT_CD.Hide()
    else RT_CD.Show() end
end

-- ── Construire le panneau "CDs" dans l'UI principale ───────
-- Appelé depuis rt.lua lors de la création des panels
function RT_BuildUICooldowns(parent)
    local p = RT_CreatePanel and RT_CreatePanel("RT_Panel_CDs") or parent

    local titleLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -4)
    titleLabel:SetText("|cffAA66FFCooldowns Raid|r  —  Clic sur un CD pour le marquer utilisé/dispo")
    titleLabel:SetTextColor(0.7, 0.4, 1.0)

    local openBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    openBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -4)
    openBtn:SetWidth(130)
    openBtn:SetHeight(22)
    openBtn:SetText("Fenêtre CDs")
    openBtn:SetScript("OnClick", function() RT_CD.Toggle() end)

    -- Mini-liste intégrée dans le panneau (non-interactive, refresh)
    local cdInlineScroll = CreateFrame("ScrollFrame", "RT_CDInlineScroll", p, "UIPanelScrollFrameTemplate")
    cdInlineScroll:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -30)
    cdInlineScroll:SetWidth(700)
    cdInlineScroll:SetHeight(380)

    local cdInlineContent = CreateFrame("Frame", nil, cdInlineScroll)
    cdInlineContent:SetWidth(680)
    cdInlineContent:SetHeight(1200)
    cdInlineScroll:SetScrollChild(cdInlineContent)

    local CD_INLINE_ROWS = {}
    for i = 1, 40 do
        local row = CreateFrame("Frame", nil, cdInlineContent)
        row:SetWidth(680)
        row:SetHeight(18)
        row:SetPoint("TOPLEFT", cdInlineContent, "TOPLEFT", 2, -(i-1)*18)

        local rName = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rName:SetPoint("LEFT", row, "LEFT", 2, 0)
        rName:SetWidth(100)
        rName:SetJustifyH("LEFT")

        local rCD = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rCD:SetPoint("LEFT", row, "LEFT", 106, 0)
        rCD:SetWidth(580)
        rCD:SetJustifyH("LEFT")

        -- Bouton "Utilisé"
        local markBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        markBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        markBtn:SetWidth(60)
        markBtn:SetHeight(16)
        markBtn:SetText("Utilisé")
        markBtn:Hide()

        row.rName  = rName
        row.rCD    = rCD
        row.markBtn= markBtn
        row:Hide()
        CD_INLINE_ROWS[i] = row
    end

    -- Refresh toutes les secondes (1.12 : GetTime au lieu de elapsed)
    local _panelLast = GetTime()
    p:SetScript("OnUpdate", function()
        if (GetTime() - _panelLast) < 1 then return end
        _panelLast = GetTime()
        -- Rebuilt entries
        local now = GetTime and GetTime() or 0
        RT_DB = RT_DB or {}
        local roster  = RT_DB.roster  or {}
        local cdState = RT_DB.cdState or {}
        local entries = {}
        for name, data in pairs(roster) do
            local class = data.class or ""
            local cds   = CD_DEFS[class]
            if cds then
                for _, cdDef in pairs(cds) do
                    local state = cdState[name] and cdState[name][cdDef.id]
                    local rem = 0
                    local onCD = false
                    if state and state.usedAt then
                        rem  = math.max(0, state.duration - (now - state.usedAt))
                        onCD = rem > 0
                    end
                    table.insert(entries, {
                        name=name, class=class, cdId=cdDef.id, cdLabel=cdDef.label,
                        dur=cdDef.dur, remaining=rem, isOnCD=onCD,
                        classColor=CLASS_COLOR[class] or "CCCCCC"
                    })
                end
            end
        end
        table.sort(entries, function(a,b)
            if a.isOnCD ~= b.isOnCD then return (a.isOnCD and 1 or 0) < (b.isOnCD and 1 or 0) end
            return a.remaining < b.remaining
        end)
        local maxR = math.min(table.getn(entries), 40)
        for i = 1, 40 do
            if i <= maxR then
                local e = entries[i]
                CD_INLINE_ROWS[i].rName:SetText("|cff" .. e.classColor .. e.name .. "|r")
                local cdStr
                if e.isOnCD then
                    local m = math.floor(e.remaining/60)
                    local s = math.mod(math.floor(e.remaining),60)
                    cdStr = "|cffFF4444" .. e.cdLabel .. "|r  "
                        .. (m>0 and (m.."m") or "") .. s .. "s"
                else
                    cdStr = "|cff44FF44" .. e.cdLabel .. "  ✓|r"
                end
                CD_INLINE_ROWS[i].rCD:SetText(cdStr)
                -- Configure le bouton
                local entry = entries[i]
                CD_INLINE_ROWS[i].markBtn:SetText(entry.isOnCD and "Reset" or "Utilisé")
                CD_INLINE_ROWS[i].markBtn:SetScript("OnClick", function()
                    if entry.isOnCD then RT_CD.Reset(entry.name, entry.cdId, true)
                    else RT_CD.Use(entry.name, entry.cdId, true) end
                end)
                CD_INLINE_ROWS[i].markBtn:Show()
                CD_INLINE_ROWS[i]:Show()
            else
                CD_INLINE_ROWS[i]:Hide()
            end
        end
    end)
end
