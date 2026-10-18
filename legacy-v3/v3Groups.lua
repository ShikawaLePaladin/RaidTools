-- ============================================================
-- RT v3 - modules/Groups.lua
-- Grille compacte, swap par clic, preset dropdown
-- ============================================================

local GRPLABELS = { "", "[Mixed]", "[Tanks]", "[Heals]", "[DPS]", "[Casters]" }
local GRPCC = {
    WARRIOR="C79C6E", PALADIN="F58CBA", HUNTER="ABD473", ROGUE="FFF569",
    PRIEST="FFFFFF", SHAMAN="0070DE", MAGE="40C7EB", WARLOCK="8787ED", DRUID="FF7D0A",
}
local NUM_PRESETS = 5

local function grpPD()
    local db = RT.Store.DB()
    if not db.v3grppresets then
        db.v3grppresets = { active=1, presets={} }
        for p = 1, NUM_PRESETS do
            local gs = {}
            for g = 1, 8 do gs[g] = { names={}, role=1 } end
            db.v3grppresets.presets[p] = { name="Preset "..p, groups=gs }
        end
    end
    local pd = db.v3grppresets
    for p = 1, NUM_PRESETS do
        if not pd.presets[p] then
            pd.presets[p] = { name="Preset "..p, groups={} }
        end
        for g = 1, 8 do
            local grp = pd.presets[p].groups[g]
            if not grp then
                pd.presets[p].groups[g] = { names={}, role=1 }
            elseif type(grp) == "table" and not grp.names then
                local old = {}
                for s = 1, table.getn(grp) do old[s] = grp[s] end
                pd.presets[p].groups[g] = { names=old, role=1 }
            end
            if not pd.presets[p].groups[g].role then
                pd.presets[p].groups[g].role = 1
            end
        end
    end
    return pd
end

local function grpSlot(pd, p, g, s)
    if not pd.presets[p] then return "" end
    local grp = pd.presets[p].groups[g]
    if not grp or not grp.names then return "" end
    return grp.names[s] or ""
end

local function grpSetSlot(pd, p, g, s, name)
    if not pd.presets[p] then return end
    local grp = pd.presets[p].groups[g]
    if not grp then return end
    if not grp.names then grp.names = {} end
    grp.names[s] = name
end

local function grpNameColor(name)
    if not name or name == "" then return "|cff333333" end
    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    for i = 1, n do
        local pname, _, _, _, cls = GetRaidRosterInfo(i)
        if pname == name then
            local c = cls and GRPCC[string.upper(cls)]
            if c then return "|cff"..c end
        end
    end
    local db = RT.Store.DB()
    local ros = db.roster or {}
    if ros[name] and ros[name].class then
        local c = GRPCC[string.upper(ros[name].class or "")]
        if c then return "|cff"..c end
    end
    return "|cffDDDDDD"
end

-- ─────────────────────────────────────────────────────────────
RT.Modules.Register({
    id       = "groups",
    title    = "Groups",
    tip      = "The 8 groups. Click to swap 2 players, 'Import Raid' captures the in-game setup, 'Apply' reorganizes it in-game.",
    color    = { 0.90, 0.70, 0.20 },
    tabWidth = 74,

    build = function(panel)
        panel._sel = nil   -- { g, s } slot sélectionné pour swap

        -- Layout grille
        local COL_X  = { 4, 350 }
        local COL_W  = 342
        local HDR_H  = 14
        local SLT_H  = 12
        local GRP_H  = HDR_H + 5 * SLT_H   -- 74px
        local ROW_H  = GRP_H + 4            -- 78px
        local START_Y = -54

        local gHdrs   = {}   -- gHdrs[g] = FontString role
        local gSlots  = {}   -- gSlots[g][s] = frame
        local gSelHL  = {}   -- gSelHL[g][s] = texture overlay selection

        -- ── Dropdown preset ──────────────────────────────────────
        local dd = CreateFrame("Frame","RT3_GP_DD",panel)
        dd:SetWidth(136)
        dd:SetHeight(NUM_PRESETS * 22 + 4)
        RT.UI.ApplyBackdrop(dd, 0.08, 0.06, 0.14, 0.98)
        dd:Hide()
        dd:SetFrameStrata("TOOLTIP")
        panel._dd = dd

        local ddBtns = {}
        for p = 1, NUM_PRESETS do
            local dbtn = CreateFrame("Button","RT3_GPDD"..p,dd,"UIPanelButtonTemplate")
            dbtn:SetPoint("TOPLEFT", dd, "TOPLEFT", 2, -2-(p-1)*22)
            dbtn:SetWidth(132) dbtn:SetHeight(20)
            dbtn:SetText("Preset "..p)
            local pi = p
            dbtn:SetScript("OnClick", function()
                grpPD().active = pi
                dd:Hide()
                if panel._grpRefresh then panel._grpRefresh() end
            end)
            ddBtns[p] = dbtn
        end

        -- ── Barre preset + actions ────────────────────────────────
        local prevBtn = CreateFrame("Button","RT3_GPPrev",panel,"UIPanelButtonTemplate")
        prevBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -10)
        prevBtn:SetWidth(22) prevBtn:SetHeight(22)
        prevBtn:SetText("<")
        prevBtn:SetScript("OnClick", function()
            dd:Hide()
            local pd = grpPD()
            pd.active = math.mod(pd.active - 2 + NUM_PRESETS, NUM_PRESETS) + 1
            if panel._grpRefresh then panel._grpRefresh() end
        end)

        local presBtn = CreateFrame("Button","RT3_GPPreset",panel,"UIPanelButtonTemplate")
        presBtn:SetPoint("LEFT", prevBtn, "RIGHT", 2, 0)
        presBtn:SetWidth(110) presBtn:SetHeight(22)
        presBtn:SetText("Preset 1")
        presBtn:SetScript("OnClick", function()
            if dd:IsShown() then
                dd:Hide()
            else
                -- Mettre à jour les labels dropdown
                local pd = grpPD()
                for p = 1, NUM_PRESETS do
                    local nm = (pd.presets[p] and pd.presets[p].name) or ("Preset "..p)
                    if p == pd.active then
                        ddBtns[p]:SetText("|cffFFD700"..nm.."|r")
                    else
                        ddBtns[p]:SetText(nm)
                    end
                end
                dd:ClearAllPoints()
                dd:SetPoint("TOPLEFT", presBtn, "BOTTOMLEFT", 0, -2)
                dd:Show()
            end
        end)

        local nextBtn = CreateFrame("Button","RT3_GPNext",panel,"UIPanelButtonTemplate")
        nextBtn:SetPoint("LEFT", presBtn, "RIGHT", 2, 0)
        nextBtn:SetWidth(22) nextBtn:SetHeight(22)
        nextBtn:SetText(">")
        nextBtn:SetScript("OnClick", function()
            dd:Hide()
            local pd = grpPD()
            pd.active = math.mod(pd.active, NUM_PRESETS) + 1
            if panel._grpRefresh then panel._grpRefresh() end
        end)

        -- Action buttons
        RT.UI.Button(panel, {
            text="Import Raid", width=96, height=22, color={0.25,0.35,0.10},
            anchor={"TOPLEFT", panel, "TOPLEFT", 170, -10},
            onClick=function()
                dd:Hide()
                local pd = grpPD()
                local ap = pd.active or 1
                local n  = GetNumRaidMembers and GetNumRaidMembers() or 0
                if n == 0 then RT.Print("|cffFFAA00Pas dans un raid.|r") return end
                local counts = {}
                for g = 1, 8 do
                    pd.presets[ap].groups[g] = {
                        names={},
                        role=(pd.presets[ap].groups[g] and pd.presets[ap].groups[g].role) or 1
                    }
                    counts[g] = 0
                end
                for i = 1, n do
                    local pname, _, sg = GetRaidRosterInfo(i)
                    if pname and sg then
                        local gi = tonumber(sg) or 1
                        if gi >= 1 and gi <= 8 then
                            counts[gi] = counts[gi] + 1
                            if counts[gi] <= 5 then
                                pd.presets[ap].groups[gi].names[counts[gi]] = pname
                            end
                        end
                    end
                end
                panel._sel = nil
                if panel._grpRefresh then panel._grpRefresh() end
                RT.Print("|cff44FF88"..n.." players imported.|r")
            end,
        })
        RT.UI.Button(panel, {
            text="Invite", width=68, height=22, color={0.15,0.45,0.75},
            anchor={"TOPLEFT", panel, "TOPLEFT", 272, -10},
            onClick=function()
                dd:Hide()
                local pd  = grpPD()
                local ap  = pd.active or 1
                local me  = UnitName("player") or ""
                local cnt = 0
                if pd.presets[ap] then
                    for g = 1, 8 do
                        local grp = pd.presets[ap].groups[g]
                        local nms = (grp and grp.names) or {}
                        for s = 1, 5 do
                            local nm = nms[s] or ""
                            if nm ~= "" and nm ~= me then
                                InviteByName(nm)
                                cnt = cnt + 1
                            end
                        end
                    end
                end
                RT.Print("|cff44FF88"..cnt.." invitation(s).|r")
            end,
        })
        RT.UI.Button(panel, {
            text="Apply", width=80, height=22, color={0.20,0.45,0.20},
            anchor={"TOPLEFT", panel, "TOPLEFT", 346, -10},
            tooltip="Reorganizes the REAL in-game raid groups to match this setup (raid leader/assistant required).",
            onClick=function()
                dd:Hide()
                local n = GetNumRaidMembers and GetNumRaidMembers() or 0
                if n == 0 then RT.Print("|cffFFAA00Pas dans un raid.|r") return end
                local canManage = true
                if IsRaidLeader and IsRaidOfficer then
                    canManage = IsRaidLeader() or IsRaidOfficer()
                end
                if not canManage then
                    RT.Print("|cffFFAA00You must be raid leader or assistant.|r") return
                end
                local pd = grpPD(); local ap = pd.active or 1
                if not pd.presets[ap] then return end
                -- want[nom] = groupe cible
                local want = {}
                for g = 1, 8 do
                    local grp = pd.presets[ap].groups[g]
                    local nms = (grp and grp.names) or {}
                    for s = 1, 5 do
                        if nms[s] and nms[s] ~= "" then want[nms[s]] = g end
                    end
                end
                -- modèle local de l'état actuel du raid
                local idxName, idxGroup, groupCount = {}, {}, {}
                for g = 1, 8 do groupCount[g] = 0 end
                for i = 1, n do
                    local nm, _, sg = GetRaidRosterInfo(i)
                    idxName[i]  = nm
                    idxGroup[i] = tonumber(sg) or 1
                    groupCount[idxGroup[i]] = groupCount[idxGroup[i]] + 1
                end
                -- passes successives : place les joueurs (swap si groupe plein)
                local moves, changed, guard = 0, true, 0
                while changed and guard < 100 do
                    changed = false
                    guard = guard + 1
                    for i = 1, n do
                        local nm = idxName[i]
                        local tg = nm and want[nm]
                        if tg and tg ~= idxGroup[i] then
                            if groupCount[tg] < 5 then
                                groupCount[idxGroup[i]] = groupCount[idxGroup[i]] - 1
                                groupCount[tg] = groupCount[tg] + 1
                                idxGroup[i] = tg
                                SetRaidSubgroup(i, tg)
                                moves = moves + 1
                                changed = true
                            else
                                local j = nil
                                for k = 1, n do
                                    if idxGroup[k] == tg then
                                        local wk = idxName[k] and want[idxName[k]]
                                        if wk ~= tg then j = k; break end
                                    end
                                end
                                if j then
                                    local gi, gj = idxGroup[i], idxGroup[j]
                                    SwapRaidSubgroup(i, j)
                                    idxGroup[i] = gj
                                    idxGroup[j] = gi
                                    moves = moves + 1
                                    changed = true
                                end
                            end
                        end
                    end
                end
                RT.Print("|cff44FF88"..moves.." move(s) applied to the raid.|r")
            end,
        })
        RT.UI.Button(panel, {
            text="Clear", width=52, height=22, color={0.55,0.15,0.10},
            anchor={"TOPLEFT", panel, "TOPLEFT", 432, -10},
            onClick=function()
                dd:Hide()
                local pd = grpPD()
                local ap = pd.active or 1
                if pd.presets[ap] then
                    for g = 1, 8 do
                        if pd.presets[ap].groups[g] then
                            pd.presets[ap].groups[g].names = {}
                        end
                    end
                end
                panel._sel = nil
                if panel._grpRefresh then panel._grpRefresh() end
            end,
        })

        -- ── Optimiseur de composition basé sur les synergies de buffs ─
        local optSummary = nil  -- FontString pour afficher les buffs par groupe
        RT.UI.Button(panel, {
            text="Optimize", width=88, height=22, color={0.60,0.30,0.80},
            anchor={"TOPLEFT", panel, "TOPLEFT", 490, -10},
            tooltip="Automatically distributes roster players across the 8 groups, maximizing buff synergies (Windfury, Mana Tide, auras…).",
            onClick=function()
                dd:Hide()
                if not RT3_OptimizeGroups then
                    RT.Print("|cffFF4444v3GroupOpt not loaded.|r") return
                end
                local result = RT3_OptimizeGroups()
                if not result then
                    RT.Print("|cffFFAA00Roster vide — importe ou scanne le raid d'abord.|r") return
                end
                -- Écrire dans le preset actif
                local pd = grpPD()
                local ap = pd.active or 1
                pd.presets[ap] = pd.presets[ap] or { name="Preset "..ap, groups={} }
                for g = 1, 8 do
                    pd.presets[ap].groups[g] = pd.presets[ap].groups[g] or { names={}, role=1 }
                    pd.presets[ap].groups[g].names = {}
                    local gnames = result[g] or {}
                    for s = 1, table.getn(gnames) do
                        pd.presets[ap].groups[g].names[s] = gnames[s]
                    end
                end
                panel._sel = nil
                if panel._grpRefresh then panel._grpRefresh() end
                -- Résumé buffs
                if optSummary then
                    local db  = RT.Store.Roster()
                    local lines = {}
                    for g = 1, 8 do
                        local gnames = result[g] or {}
                        if table.getn(gnames) > 0 then
                            local players = {}
                            for s = 1, table.getn(gnames) do
                                local nm = gnames[s]
                                local d  = db[nm] or {}
                                table.insert(players, {
                                    name  = nm,
                                    class = string.upper(d.class or ""),
                                    spec  = d.spec or "",
                                    role  = RT_NormalizeRole(d.role or ""),
                                })
                            end
                            local bufftxt = RT3_GroupBuffSummary and RT3_GroupBuffSummary(players) or ""
                            table.insert(lines, "|cff888888G"..g.."|r " .. bufftxt)
                        end
                    end
                    optSummary:SetText(table.concat(lines, "  "))
                end
                RT.Print("|cffAA66FF[Optimize] Groups computed and applied to preset "..ap..".|r")
            end,
        })

        -- Ligne de résumé des buffs actifs (sous les boutons)
        optSummary = panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        optSummary:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -34)
        optSummary:SetWidth(680) optSummary:SetJustifyH("LEFT")
        optSummary:SetText("")

        local saveBtn = CreateFrame("Button","RT3_GPSave",panel,"UIPanelButtonTemplate")
        saveBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -10)
        saveBtn:SetWidth(100) saveBtn:SetHeight(22)
        saveBtn:SetText("Save")
        saveBtn:SetScript("OnClick", function()
            dd:Hide()
            RT.Print("|cff44FF88Preset "..grpPD().active.." saved.|r")
        end)

        -- Séparateur (décalé sous la ligne de résumé buffs)
        local sep = panel:CreateTexture(nil,"BACKGROUND")
        sep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  6, -50)
        sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -50)
        sep:SetHeight(1) sep:SetTexture(0.4,0.4,0.6,0.4)

        -- ── Popup classe/spec pour joueur inconnu du roster ─────────
        local classPopup = CreateFrame("Frame", "RT3_GP_ClassPop", UIParent)
        RT.UI.ApplyBackdrop(classPopup, 0.06, 0.04, 0.12, 0.97)
        classPopup:SetFrameStrata("DIALOG")
        classPopup:SetWidth(220) classPopup:SetHeight(160)
        classPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
        classPopup:Hide()
        classPopup._name = nil
        local cpTitle = classPopup:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        cpTitle:SetPoint("TOPLEFT", classPopup, "TOPLEFT", 8, -6)
        cpTitle:SetWidth(204) cpTitle:SetJustifyH("LEFT")
        -- 9 boutons classe, 3 par ligne
        local CLASS_LIST = {"Warrior","Paladin","Druid","Priest","Shaman","Rogue","Mage","Warlock","Hunter"}
        local cpBtns = {}
        for ci = 1, table.getn(CLASS_LIST) do
            local cls = CLASS_LIST[ci]
            local cb = CreateFrame("Button", nil, classPopup, "UIPanelButtonTemplate")
            local col = math.mod(ci-1, 3)
            local row2 = math.floor((ci-1) / 3)
            cb:SetWidth(68) cb:SetHeight(17)
            cb:SetPoint("TOPLEFT", classPopup, "TOPLEFT", 6 + col*72, -22 - row2*20)
            cb:SetText(cls)
            local clsName = cls
            cb:SetScript("OnClick", function()
                if not classPopup._name then return end
                local nm = classPopup._name
                local db = RT.Store.Roster()
                db[nm] = db[nm] or {}
                db[nm].class = clsName
                -- Afficher sélecteur spec
                cpTitle:SetText("|cffFFD700" .. nm .. "|r  →  Spec:")
                for i = 1, table.getn(cpBtns) do cpBtns[i]:Hide() end
                local specList = (RT3_SPEC_LISTS and RT3_SPEC_LISTS[string.upper(clsName)]) or {}
                local specBtns = {}
                for si = 1, table.getn(specList) do
                    local sp = specList[si]
                    local sb = CreateFrame("Button", nil, classPopup, "UIPanelButtonTemplate")
                    sb:SetWidth(68) sb:SetHeight(17)
                    local sc2 = math.mod(si-1, 3)
                    local sr2 = math.floor((si-1) / 3)
                    sb:SetPoint("TOPLEFT", classPopup, "TOPLEFT", 6 + sc2*72, -42 - sr2*20)
                    sb:SetText(sp)
                    local spName = sp
                    sb:SetScript("OnClick", function()
                        db[nm].spec = spName
                        RT.Store.Notify("roster")
                        for i = 1, table.getn(specBtns) do specBtns[i]:Hide() end
                        classPopup:Hide()
                        if panel._grpRefresh then panel._grpRefresh() end
                    end)
                    sb:Show()
                    specBtns[si] = sb
                end
                -- Bouton Skip
                local skipH = table.getn(specList) > 0 and (math.floor((table.getn(specList)-1)/3)+1)*20 or 20
                local skipB = CreateFrame("Button", nil, classPopup, "UIPanelButtonTemplate")
                skipB:SetWidth(68) skipB:SetHeight(17)
                skipB:SetPoint("TOPLEFT", classPopup, "TOPLEFT", 6, -42 - skipH)
                skipB:SetText("Skip")
                skipB:SetScript("OnClick", function()
                    RT.Store.Notify("roster")
                    for i = 1, table.getn(specBtns) do specBtns[i]:Hide() end
                    skipB:Hide()
                    classPopup:Hide()
                    if panel._grpRefresh then panel._grpRefresh() end
                end)
                classPopup:SetHeight(42 + skipH + 36)
            end)
            cpBtns[ci] = cb
        end
        -- Bouton Annuler
        local cpCancel = CreateFrame("Button", nil, classPopup, "UIPanelButtonTemplate")
        cpCancel:SetWidth(68) cpCancel:SetHeight(17)
        cpCancel:SetPoint("BOTTOMRIGHT", classPopup, "BOTTOMRIGHT", -6, 6)
        cpCancel:SetText("Cancel")
        cpCancel:SetScript("OnClick", function() classPopup:Hide() end)

        local function showClassPopup(name)
            classPopup._name = name
            cpTitle:SetText("|cffFFD700" .. name .. "|r  —  Choose class:")
            for ci = 1, table.getn(cpBtns) do
                local cls = CLASS_LIST[ci]
                local col = math.mod(ci-1, 3)
                local row2 = math.floor((ci-1) / 3)
                cpBtns[ci]:SetWidth(68) cpBtns[ci]:SetHeight(17)
                cpBtns[ci]:ClearAllPoints()
                cpBtns[ci]:SetPoint("TOPLEFT", classPopup, "TOPLEFT", 6 + col*72, -22 - row2*20)
                cpBtns[ci]:Show()
            end
            classPopup:SetHeight(22 + 3*20 + 30)
            classPopup:Show()
        end

        -- EditBox partagé (inline, parented panel)
        local eb = CreateFrame("EditBox","RT3_GPEdit",panel,"InputBoxTemplate")
        eb:SetHeight(SLT_H) eb:SetAutoFocus(false) eb:Hide()
        local ebRef = nil
        eb:SetScript("OnEnterPressed", function()
            if ebRef then
                local entered = eb:GetText() or ""
                local pd = grpPD()
                grpSetSlot(pd, ebRef[1], ebRef[2], ebRef[3], entered)
                -- Proposer classe/spec si joueur inconnu du roster
                if entered ~= "" then
                    local db = RT.Store.Roster()
                    if not db[entered] then
                        db[entered] = { class="?", spec="", role="DPS", sr=0 }
                        showClassPopup(entered)
                    end
                end
                ebRef = nil
            end
            eb:Hide()
            if panel._grpRefresh then panel._grpRefresh() end
        end)
        eb:SetScript("OnEscapePressed", function()
            ebRef = nil; eb:Hide()
        end)

        -- ── Grille 8 groupes ─────────────────────────────────────
        for g = 1, 8 do
            local col = math.mod(g-1, 2) + 1
            local row = math.floor((g-1) / 2)
            local bx  = COL_X[col]
            local by  = START_Y - row * ROW_H

            local box = CreateFrame("Frame","RT3_GB"..g,panel)
            box:SetPoint("TOPLEFT", panel, "TOPLEFT", bx, by)
            box:SetWidth(COL_W) box:SetHeight(GRP_H)
            local boxBg = box:CreateTexture(nil,"BACKGROUND")
            boxBg:SetAllPoints(); boxBg:SetTexture(0.05,0.03,0.08,0.95)

            -- En-tête compact
            local hdr = CreateFrame("Frame", nil, box)
            hdr:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
            hdr:SetWidth(COL_W) hdr:SetHeight(HDR_H)
            local hdrBg = hdr:CreateTexture(nil,"BACKGROUND")
            hdrBg:SetAllPoints(); hdrBg:SetTexture(0.13,0.10,0.20,1.0)

            local gNumFS = hdr:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            gNumFS:SetPoint("LEFT", hdr, "LEFT", 4, 0)
            gNumFS:SetText("|cffFFD700G"..g.."|r")

            -- Rôle (clic = cycle)
            local roleBtn = CreateFrame("Button", nil, hdr)
            roleBtn:SetPoint("LEFT", hdr, "LEFT", 26, 0)
            roleBtn:SetWidth(COL_W-30) roleBtn:SetHeight(HDR_H)
            roleBtn:EnableMouse(true)
            local roleFS = roleBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            roleFS:SetAllPoints(); roleFS:SetJustifyH("LEFT")
            roleFS:SetText("")
            local gi = g
            roleBtn:SetScript("OnClick", function()
                dd:Hide()
                local pd = grpPD(); local ap = pd.active or 1
                if pd.presets[ap] and pd.presets[ap].groups[gi] then
                    local cur = pd.presets[ap].groups[gi].role or 1
                    pd.presets[ap].groups[gi].role = math.mod(cur, table.getn(GRPLABELS)) + 1
                    if panel._grpRefresh then panel._grpRefresh() end
                end
            end)
            gHdrs[g] = roleFS

            -- 5 slots joueur
            gSlots[g]  = {}
            gSelHL[g]  = {}
            for s = 1, 5 do
                local sy = -HDR_H - (s-1) * SLT_H
                local sf = CreateFrame("Frame", nil, box)
                sf:SetPoint("TOPLEFT",  box, "TOPLEFT",  2, sy)
                sf:SetPoint("TOPRIGHT", box, "TOPRIGHT", -2, sy)
                sf:SetHeight(SLT_H)

                local sbg = sf:CreateTexture(nil,"BACKGROUND")
                sbg:SetAllPoints()
                if math.mod(s,2)==0 then sbg:SetTexture(0.16,0.07,0.07,0.9)
                else                      sbg:SetTexture(0.10,0.04,0.04,0.9) end

                -- Overlay sélection (or semi-transparent)
                local selHL = sf:CreateTexture(nil,"ARTWORK")
                selHL:SetAllPoints(); selHL:SetTexture(0.85,0.75,0.0,0.4); selHL:Hide()
                gSelHL[g][s] = selHL

                local nameFS = sf:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                nameFS:SetPoint("LEFT", sf, "LEFT", 4, 0)
                nameFS:SetWidth(COL_W - 10)
                nameFS:SetJustifyH("LEFT")
                nameFS:SetText("|cff333333—|r")
                sf._nFS = nameFS

                local clickF = CreateFrame("Button", nil, sf)
                clickF:SetAllPoints()
                local gi2, si = g, s
                clickF:SetScript("OnClick", function()
                    dd:Hide()
                    local pd  = grpPD(); local ap = pd.active or 1
                    local nm  = grpSlot(pd, ap, gi2, si)

                    if panel._sel then
                        local sg, ss = panel._sel.g, panel._sel.s
                        if sg == gi2 and ss == si then
                            -- Désélection
                            panel._sel = nil
                        else
                            -- Swap / déplacement
                            local selNm = grpSlot(pd, ap, sg, ss)
                            grpSetSlot(pd, ap, gi2, si, selNm)
                            grpSetSlot(pd, ap, sg,  ss, nm)
                            panel._sel = nil
                        end
                        if panel._grpRefresh then panel._grpRefresh() end
                    else
                        if nm ~= "" then
                            -- Sélection pour swap futur
                            panel._sel = { g=gi2, s=si }
                            -- Montrer overlay
                            for gg = 1, 8 do
                                for ss2 = 1, 5 do
                                    if gSelHL[gg] and gSelHL[gg][ss2] then
                                        gSelHL[gg][ss2]:Hide()
                                    end
                                end
                            end
                            selHL:Show()
                            nameFS:SetText("|cffFFD700"..nm.."|r")
                        else
                            -- Slot vide : ouvrir EditBox
                            eb:ClearAllPoints()
                            eb:SetPoint("TOPLEFT", sf, "TOPLEFT", 3, 0)
                            eb:SetWidth(COL_W - 10)
                            ebRef = { ap, gi2, si }
                            eb:SetText(""); eb:Show(); eb:SetFocus()
                        end
                    end
                end)

                -- Clic droit = supprimer le joueur
                clickF:SetScript("OnMouseUp", function(_, btn)
                    if btn ~= "RightButton" then return end
                    dd:Hide()
                    local pd  = grpPD(); local ap = pd.active or 1
                    grpSetSlot(pd, ap, gi2, si, "")
                    if panel._sel and panel._sel.g==gi2 and panel._sel.s==si then
                        panel._sel = nil
                    end
                    if panel._grpRefresh then panel._grpRefresh() end
                end)

                gSlots[g][s] = sf
            end
        end

        -- ── Refresh ───────────────────────────────────────────────
        local function refresh()
            local pd = grpPD(); local ap = pd.active or 1
            local nm = (pd.presets[ap] and pd.presets[ap].name) or ("Preset "..ap)
            presBtn:SetText("|cffFFD700"..nm.."|r")

            -- Réinitialiser overlays si rien de sélectionné
            if not panel._sel then
                for g = 1, 8 do
                    for s = 1, 5 do
                        if gSelHL[g] and gSelHL[g][s] then gSelHL[g][s]:Hide() end
                    end
                end
            end

            for g = 1, 8 do
                -- Rôle header
                local rfs = gHdrs[g]
                if rfs then
                    local grp = pd.presets[ap] and pd.presets[ap].groups[g]
                    local ri  = (grp and grp.role) or 1
                    rfs:SetText("|cffAAAAAA"..(GRPLABELS[ri] or "").."|r")
                end
                -- Slots
                for s = 1, 5 do
                    local sf = gSlots[g] and gSlots[g][s]
                    if sf and sf._nFS then
                        local isSel = panel._sel and (panel._sel.g==g) and (panel._sel.s==s)
                        if not isSel then
                            local name = grpSlot(pd, ap, g, s)
                            if name and name ~= "" then
                                -- Spec + rôle depuis le roster
                                local ros  = RT.Store.Roster()
                                local d    = ros[name] or {}
                                local spec = d.spec or ""
                                local role = RT_NormalizeRole(d.role or "")
                                local roleTag, roleCol
                                if     role == "Tank"   then roleTag="T" roleCol="|cff4499FF"
                                elseif role == "Heal"   then roleTag="H" roleCol="|cff44FF88"
                                elseif role == "Melee"  then roleTag="M" roleCol="|cffFF8800"
                                elseif role == "Ranged" then roleTag="R" roleCol="|cff22CCFF"
                                else                         roleTag="D" roleCol="|cffFF4444" end
                                local specPart = spec ~= "" and ("|cff888888 "..spec.."|r") or ""
                                local tag = " "..roleCol.."["..roleTag.."]|r"
                                sf._nFS:SetText(grpNameColor(name)..name.."|r"..specPart..tag)
                            else
                                sf._nFS:SetText("|cff333333—|r")
                            end
                        end
                    end
                end
            end
        end
        panel._grpRefresh = refresh

        -- Refresh automatique quand Assign pousse une attribution
        RT.Store.Subscribe("groups", function()
            if panel:IsShown() and panel._grpRefresh then panel._grpRefresh() end
        end)
    end,

    show = function(panel)
        if panel._grpRefresh then panel._grpRefresh() end
    end,
})
