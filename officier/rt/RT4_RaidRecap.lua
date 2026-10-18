-- ============================================================
-- RT v5 — RT4_RaidRecap.lua
--
-- RECAP PERSONNEL : discret, semi-transparent, fait pour rester
-- affiche EN COMBAT. Il montre au joueur SON recap, pas celui du raid :
--   - qui je suis : nom (couleur de classe), role du plan, groupe
--   - le boss courant (cible / boss en cours / plan)
--   - MES postes et taches sur ce boss (plan importe ou recu du chef)
--   - mon groupe (cliquable, morts en rouge)
-- Position et affichage memorises. Chargé après RT4_MicroMenu.lua.
-- ============================================================

local MAXROWS = 6
local MAXPOST = 6
local frame, hdrLine, bossLine, postLine, myGrpLbl, footer
local rows = {}

local CLASS_COLORS = {
    WARRIOR  = { 0.78, 0.61, 0.43 }, PRIEST   = { 1.00, 1.00, 1.00 },
    MAGE     = { 0.41, 0.80, 0.94 }, WARLOCK  = { 0.58, 0.51, 0.79 },
    DRUID    = { 1.00, 0.49, 0.04 }, PALADIN  = { 0.96, 0.55, 0.73 },
    ROGUE    = { 1.00, 0.96, 0.41 }, HUNTER   = { 0.67, 0.83, 0.45 },
    SHAMAN   = { 0.00, 0.44, 0.87 },
}
local ROLE_FR = { tank = "Tank", heal = "Heal", melee = "Mêlée", ranged = "Dist" }

local function GetState()
    local db = RT4.GetDB()
    db.recap = db.recap or {}
    return db.recap
end

local function SavePos()
    if not frame then return end
    local l, b = frame:GetLeft(), frame:GetBottom()
    if l and b then
        local st = GetState()
        st.x, st.y = l, b
    end
end

local function EnsureFrame()
    if frame then return end
    frame = CreateFrame("Frame", "RT4_Recap", UIParent)
    frame:SetWidth(252)
    frame:SetHeight(110)
    local st = GetState()
    if st.x and st.y then
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", st.x, st.y)
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -10, 60)
    end
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SavePos() end)
    frame:SetFrameStrata("LOW")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    -- fin et discret : fond a peine la, liseré sombre — lisible en combat
    frame:SetBackdropColor(0.02, 0.02, 0.05, 0.55)
    frame:SetBackdropBorderColor(0.35, 0.28, 0.16, 0.45)

    hdrLine = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdrLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -5)
    hdrLine:SetJustifyH("LEFT")
    hdrLine:SetWidth(220)

    bossLine = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bossLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -22)
    bossLine:SetJustifyH("LEFT")
    bossLine:SetWidth(238)

    postLine = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    postLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -36)
    postLine:SetJustifyH("LEFT")
    postLine:SetWidth(238)

    myGrpLbl = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    myGrpLbl:SetJustifyH("LEFT")

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetWidth(16)
    closeBtn:SetHeight(16)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
        GetState().shown = false
    end)

    for i = 1, MAXROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetHeight(12)
        row:SetPoint("RIGHT", frame, "RIGHT", -7, 0)
        local t = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("TOPLEFT", row, "TOPLEFT", 1, 0)
        t:SetJustifyH("LEFT")
        row.txt = t
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row:GetHighlightTexture():SetAlpha(0.25)
        row:SetScript("OnClick", function()
            if row.punit and TargetUnit then
                TargetUnit(row.punit)          -- unite raidN/partyN : exact
            elseif row.pname and TargetByName then
                TargetByName(row.pname)
            end
        end)
        row:Hide()
        table.insert(rows, row)
    end

    footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer:SetJustifyH("LEFT")
    footer:SetWidth(238)
    frame:Hide()
end

local function SetRow(row, y, txt, cr, cg, cb, name, unit)
    row:Show()
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -y)
    row:SetPoint("RIGHT", frame, "RIGHT", -7, 0)
    row.punit = unit
    row.pname = name
    row.txt:SetText(txt)
    row.txt:SetTextColor(cr or 1, cg or 1, cb or 1)
end

-- groupe + classe du joueur (raid puis groupe)
local function MyInfo(me)
    local nRaid = (GetNumRaidMembers and GetNumRaidMembers()) or 0
    local group, cls = nil, nil
    local mates = {}
    if nRaid > 0 then
        for i = 1, nRaid do
            -- 1.12 : nom, rang, groupe, niveau, classe (localisee), fileName (EN), zone, online, isDead
            local name, _, sg, _, className, fileName, _, online, isDead = GetRaidRosterInfo(i)
            if name == me then group, cls = sg, fileName or className end
            if name and sg then
                table.insert(mates, { name = name, unit = "raid" .. i, sg = sg, cls = fileName or className,
                    online = online, dead = isDead })
            end
        end
        if group then
            local mine = {}
            for _, m in ipairs(mates) do
                if m.sg == group then table.insert(mine, m) end
            end
            mates = mine
        else
            mates = {}
        end
    elseif ((GetNumPartyMembers and GetNumPartyMembers()) or 0) > 0 then
        table.insert(mates, { name = me, unit = "player", online = 1 })
        for i = 1, GetNumPartyMembers() do
            local pn = UnitName("party" .. i)
            if pn then table.insert(mates, { name = pn, unit = "party" .. i, online = 1 }) end
        end
    end
    if not cls and UnitClass then
        local _, c = UnitClass("player")
        cls = c
    end
    return group, cls, mates
end

local function Refresh()
    EnsureFrame()
    local me = UnitName("player") or "?"
    local OF = RT.OctoFan
    local plan = RT.Store.DB().octofan
    local boss = OF and OF.CurrentBoss and OF.CurrentBoss() or nil
    local group, cls, mates = MyInfo(me)

    -- ── en-tete : moi, mon role, mon groupe ──
    local col = CLASS_COLORS[cls or ""] or { 1, 0.82, 0.27 }
    local info = {}
    local rinfo = plan and plan.roster and plan.roster[me]
    if rinfo and rinfo.role and ROLE_FR[rinfo.role] then table.insert(info, ROLE_FR[rinfo.role]) end
    if rinfo and rinfo.spec and rinfo.spec ~= "" then table.insert(info, rinfo.spec) end
    if group then table.insert(info, "G" .. group) end
    hdrLine:SetText(string.format("|cff%02x%02x%02x%s|r", math.floor(col[1] * 255), math.floor(col[2] * 255),
        math.floor(col[3] * 255), me) .. (table.getn(info) > 0 and ("  |cff999999" .. table.concat(info, " · ") .. "|r") or ""))

    -- ── boss courant ──
    bossLine:SetText(boss and ("|cffFFCC44" .. boss .. "|r") or "|cff666666aucun boss (cible un boss)|r")

    -- ── MES postes ──
    local lines = {}
    if plan and plan.assign then
        if boss then
            for poste, slot in pairs(plan.assign[boss] or {}) do
                if OF and OF.HasName and OF.HasName(slot.player, me) then
                    table.insert(lines, "|cff66CCFF" .. poste .. "|r" ..
                        ((slot.task and slot.task ~= "") and (" — " .. slot.task) or ""))
                end
            end
        else
            for _, b in ipairs(plan.bossOrder or {}) do
                for poste, slot in pairs(plan.assign[b] or {}) do
                    if OF and OF.HasName and OF.HasName(slot.player, me) then
                        table.insert(lines, "|cffFFCC44" .. b .. "|r : |cff66CCFF" .. poste .. "|r")
                    end
                end
            end
        end
    end
    table.sort(lines)
    local nl = table.getn(lines)
    if nl > MAXPOST then nl = MAXPOST end
    local shown = {}
    for i = 1, nl do shown[i] = lines[i] end
    if nl == 0 then
        if not plan then
            postLine:SetText("|cff666666pas de plan OctoFan|r")
        elseif boss then
            postLine:SetText("|cff888888rien pour toi sur ce boss|r")
        else
            postLine:SetText("|cff888888aucune assignation|r")
        end
        nl = 1
    else
        postLine:SetText(table.concat(shown, "\n"))
    end
    local y = 36 + nl * 12 + 6

    -- ── mon groupe ──
    local nm = table.getn(mates)
    if nm > 0 then
        myGrpLbl:ClearAllPoints()
        myGrpLbl:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -y)
        myGrpLbl:SetText("|cffFFCC44" .. (group and ("Mon groupe (G" .. group .. ")") or "Groupe") .. "|r")
        y = y + 14
        local li = 0
        for _, m in ipairs(mates) do
            if li < MAXROWS then
                li = li + 1
                local c = CLASS_COLORS[m.cls or ""] or { 0.8, 0.8, 0.8 }
                if m.dead then
                    SetRow(rows[li], y, "† " .. m.name, 0.55, 0.35, 0.35, m.name, m.unit)
                elseif not m.online then
                    SetRow(rows[li], y, "× " .. m.name .. " (h-l)", 0.45, 0.45, 0.45, nil, nil)
                else
                    SetRow(rows[li], y, m.name, c[1], c[2], c[3], m.name, m.unit)
                end
                y = y + 12
            end
        end
        for j = li + 1, MAXROWS do rows[j]:Hide() end
    else
        myGrpLbl:SetText("")
        for j = 1, MAXROWS do rows[j]:Hide() end
    end
    footer:SetText("")
    frame:SetHeight(y + 6)
end

function RT4.ToggleRecap()
    EnsureFrame()
    if frame:IsShown() then
        frame:Hide()
        GetState().shown = false
    else
        Refresh()
        frame:Show()
        GetState().shown = true
    end
end

-- Refresh continu tant que le recap est ouvert (1s) — rien ne le cache en combat.
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
    if not frame or not frame:IsVisible() then return end
    this.t = (this.t or 0) + arg1
    if this.t < 1 then return end
    this.t = 0
    Refresh()
end)

-- restaure l'affichage au login si le joueur l'avait laisse ouvert
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    if GetState().shown then
        EnsureFrame()
        Refresh()
        frame:Show()
    end
end)
