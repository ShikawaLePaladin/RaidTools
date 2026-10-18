-- ============================================================
-- RT v2 — Dashboard.lua
-- Mode Simple : vue d'ensemble en un seul écran
-- Raid status + Actions + Assignments + Mon Attrib + Tactic
-- ============================================================

RT_Dash = RT_Dash or {}
RT_DISPLAY_MODE = RT_DISPLAY_MODE or "advanced"  -- "simple" | "advanced"

-- ── Toggle Simple / Avancé ─────────────────────────────────
function RT_SetDisplayMode(mode)
    RT_DISPLAY_MODE = mode
    RT_DB = RT_DB or {}
    RT_DB.displayMode = mode
    local btn = getglobal("RT_ModeToggleBtn")
    if mode == "simple" then
        -- Masque les tabs
        if RT_TAB_BUTTONS then
            for _, b in pairs(RT_TAB_BUTTONS) do b:Hide() end
        end
        local tabRow2 = getglobal("RT_TabRow2Frame")
        if tabRow2 then tabRow2:Hide() end
        local sepTabs = getglobal("RT_SepTabs")
        if sepTabs then sepTabs:Hide() end
        local sepTabs2 = getglobal("RT_SepTabs2")
        if sepTabs2 then sepTabs2:Hide() end
        -- Masque tous les panels existants
        if RT_ALL_PANELS then
            for _, p in pairs(RT_ALL_PANELS) do
                if p.Hide then p:Hide() end
            end
        end
        -- Affiche le Dashboard
        local dash = getglobal("RT_Panel_Dashboard")
        if dash then dash:Show() end
        if btn then btn:SetText("|cff88CCFFSimple ▼|r") end
        RT_Dash.Refresh()
    else
        -- Affiche les tabs
        if RT_TAB_BUTTONS then
            for _, b in pairs(RT_TAB_BUTTONS) do b:Show() end
        end
        local tabRow2 = getglobal("RT_TabRow2Frame")
        if tabRow2 then tabRow2:Show() end
        local sepTabs = getglobal("RT_SepTabs")
        if sepTabs then sepTabs:Show() end
        local sepTabs2 = getglobal("RT_SepTabs2")
        if sepTabs2 then sepTabs2:Show() end
        -- Masque le dashboard
        local dash = getglobal("RT_Panel_Dashboard")
        if dash then dash:Hide() end
        if btn then btn:SetText("|cffFFD700Avancé ▼|r") end
        -- Affiche le tab actif
        if RT_ShowTab then RT_ShowTab(RT_CURRENT_TAB or "Roster") end
    end
end

function RT_ToggleDisplayMode()
    if RT_DISPLAY_MODE == "simple" then
        RT_SetDisplayMode("advanced")
    else
        RT_SetDisplayMode("simple")
    end
end

-- ── Couleurs classe ────────────────────────────────────────
local DC = {
    Warrior="|cffC79C6E", Paladin="|cffF58CBA", Hunter="|cffABD473",
    Rogue="|cffFFF569",   Priest="|cffFFFFFF",  Shaman="|cff0070DE",
    Mage="|cff69CCF0",    Warlock="|cff9482C9", Druid="|cffFF7D0A",
}
local function CC(class, s) return (DC[class] or "|cffCCCCCC") .. s .. "|r" end

-- ── Widgets du Dashboard ────────────────────────────────────
local DASH = {}

local function MakeSection(parent, x, y, w, h, titleText, titleColor)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    frame:SetWidth(w)
    frame:SetHeight(h)
    RT_PatchBackdrop(frame)
    frame:SetBackdrop({
        bgFile  = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile= "Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=10,
        insets={left=3,right=3,top=3,bottom=3},
    })
    frame:SetBackdropColor(0.04, 0.02, 0.08, 0.9)
    frame:SetBackdropBorderColor(0.5, 0.35, 0.06, 0.8)
    local lbl = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -5)
    lbl:SetText(titleColor .. titleText .. "|r")
    return frame, lbl
end

-- ── Construction du Dashboard ───────────────────────────────
function RT_BuildUIDashboard(parent)
    local p = parent
    p:SetWidth(776)
    p:SetHeight(460)

    -- ════════════════════════════════════════════════════════
    -- SECTION 1 : Statut Raid (haut gauche)
    -- ════════════════════════════════════════════════════════
    local raidSec, raidLbl = MakeSection(p, 4, 6, 268, 110, "Statut Raid", "|cff88CCFF")

    local raidCount = raidSec:CreateFontString("RT_Dash_RaidCount", "OVERLAY", "GameFontNormal")
    raidCount:SetPoint("TOPLEFT", raidSec, "TOPLEFT", 6, -22)
    raidCount:SetWidth(256)
    raidCount:SetJustifyH("LEFT")
    raidCount:SetText("|cffAAAAAA(hors raid)|r")
    DASH.raidCount = raidCount

    local raidRoles = raidSec:CreateFontString("RT_Dash_RaidRoles", "OVERLAY", "GameFontNormalSmall")
    raidRoles:SetPoint("TOPLEFT", raidSec, "TOPLEFT", 6, -42)
    raidRoles:SetWidth(256)
    raidRoles:SetJustifyH("LEFT")
    raidRoles:SetText("")
    DASH.raidRoles = raidRoles

    -- Boss sélectionné
    local bossLbl = raidSec:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    bossLbl:SetPoint("TOPLEFT", raidSec, "TOPLEFT", 6, -60)
    bossLbl:SetText("Boss actif:")

    local bossName = raidSec:CreateFontString("RT_Dash_BossName", "OVERLAY", "GameFontNormal")
    bossName:SetPoint("TOPLEFT", raidSec, "TOPLEFT", 6, -76)
    bossName:SetWidth(256)
    bossName:SetJustifyH("LEFT")
    bossName:SetText("|cffAAAAAA(aucun boss sélectionné)|r")
    DASH.bossName = bossName

    -- Sync badge
    local syncBadge = raidSec:CreateFontString("RT_Dash_SyncBadge", "OVERLAY", "GameFontDisableSmall")
    syncBadge:SetPoint("TOPLEFT", raidSec, "TOPLEFT", 6, -96)
    syncBadge:SetText("")
    DASH.syncBadge = syncBadge

    -- ════════════════════════════════════════════════════════
    -- SECTION 2 : Actions Rapides (haut centre)
    -- ════════════════════════════════════════════════════════
    local actSec, actLbl = MakeSection(p, 280, 6, 260, 110, "Actions Rapides", "|cffFFD700")

    local pugBtn2 = CreateFrame("Button", "RT_Dash_PUGBtn", actSec, "UIPanelButtonTemplate")
    pugBtn2:SetPoint("TOPLEFT", actSec, "TOPLEFT", 6, -22)
    pugBtn2:SetWidth(248)
    pugBtn2:SetHeight(26)
    pugBtn2:SetText("|cffFFAA00▶▶ PUG Pack — Tout automatique|r")
    local pugTex = pugBtn2:GetNormalTexture()
    if pugTex then pugTex:SetVertexColor(0.7, 0.4, 0.0) end
    pugBtn2:SetScript("OnClick", function() if RT_AA_PackPUG then RT_AA_PackPUG() end end)

    local guildBtn2 = CreateFrame("Button", "RT_Dash_GuildBtn", actSec, "UIPanelButtonTemplate")
    guildBtn2:SetPoint("TOPLEFT", actSec, "TOPLEFT", 6, -52)
    guildBtn2:SetWidth(248)
    guildBtn2:SetHeight(22)
    guildBtn2:SetText("|cff44FF88Guild Pack — Calculer sans annoncer|r")
    local gTex = guildBtn2:GetNormalTexture()
    if gTex then gTex:SetVertexColor(0.1, 0.6, 0.2) end
    guildBtn2:SetScript("OnClick", function() if RT_AA_PackGuild then RT_AA_PackGuild() end end)

    local pullBtn2 = CreateFrame("Button", nil, actSec, "UIPanelButtonTemplate")
    pullBtn2:SetPoint("TOPLEFT", actSec, "TOPLEFT", 6, -78)
    pullBtn2:SetWidth(120)
    pullBtn2:SetHeight(22)
    pullBtn2:SetText("|cffFFAA00▶ Pull 10s|r")
    pullBtn2:SetScript("OnClick", function() if RT_PT then RT_PT.Start(10, nil, true) end end)

    local cdBtn2 = CreateFrame("Button", nil, actSec, "UIPanelButtonTemplate")
    cdBtn2:SetPoint("LEFT", pullBtn2, "RIGHT", 6, 0)
    cdBtn2:SetWidth(118)
    cdBtn2:SetHeight(22)
    cdBtn2:SetText("|cffAA66FFCooldowns|r")
    cdBtn2:SetScript("OnClick", function() if RT_CD then RT_CD.Toggle() end end)

    -- ════════════════════════════════════════════════════════
    -- SECTION 3 : Aller en Avancé + Import rapide (haut droite)
    -- ════════════════════════════════════════════════════════
    local navSec, navLbl = MakeSection(p, 548, 6, 224, 110, "Navigation", "|cff888888")

    local advBtn = CreateFrame("Button", nil, navSec, "UIPanelButtonTemplate")
    advBtn:SetPoint("TOPLEFT", navSec, "TOPLEFT", 6, -22)
    advBtn:SetWidth(212)
    advBtn:SetHeight(22)
    advBtn:SetText("→ Mode Avancé (tous les onglets)")
    advBtn:SetScript("OnClick", function() RT_SetDisplayMode("advanced") end)

    local rosterBtn2 = CreateFrame("Button", nil, navSec, "UIPanelButtonTemplate")
    rosterBtn2:SetPoint("TOPLEFT", navSec, "TOPLEFT", 6, -48)
    rosterBtn2:SetWidth(212)
    rosterBtn2:SetHeight(20)
    rosterBtn2:SetText("→ Roster")
    rosterBtn2:SetScript("OnClick", function()
        RT_SetDisplayMode("advanced")
        if RT_ShowTab then RT_ShowTab("Roster") end
    end)

    local importBtn2 = CreateFrame("Button", nil, navSec, "UIPanelButtonTemplate")
    importBtn2:SetPoint("TOPLEFT", navSec, "TOPLEFT", 6, -72)
    importBtn2:SetWidth(212)
    importBtn2:SetHeight(20)
    importBtn2:SetText("→ Import Roster / SoftRes")
    importBtn2:SetScript("OnClick", function()
        RT_SetDisplayMode("advanced")
        if RT_ShowTab then RT_ShowTab("Import") end
    end)

    local ovBtn2 = CreateFrame("Button", nil, navSec, "UIPanelButtonTemplate")
    ovBtn2:SetPoint("TOPLEFT", navSec, "TOPLEFT", 6, -96)
    ovBtn2:SetWidth(212)
    ovBtn2:SetHeight(20)
    ovBtn2:SetText("→ Mon Attrib (Overlay)")
    ovBtn2:SetScript("OnClick", function()
        if RT_OverlayToggle then RT_OverlayToggle() end
    end)

    -- ════════════════════════════════════════════════════════
    -- SECTION 4 : Assignments (milieu, pleine largeur)
    -- ════════════════════════════════════════════════════════
    local assignSec, assignLbl = MakeSection(p, 4, 124, 548, 160, "Attributions du Raid", "|cffFFD700")

    -- Sous-titre tanks
    local tankLbl2 = assignSec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tankLbl2:SetPoint("TOPLEFT", assignSec, "TOPLEFT", 6, -22)
    tankLbl2:SetText("|cffFFAA00Tanks & Heals|r")

    -- 4 lignes tank + heal
    for i = 1, 4 do
        local row = assignSec:CreateFontString("RT_Dash_TankRow" .. i, "OVERLAY", "GameFontNormalSmall")
        row:SetPoint("TOPLEFT", assignSec, "TOPLEFT", 6, -22 - i*22)
        row:SetWidth(536)
        row:SetJustifyH("LEFT")
        row:SetText("")
        DASH["tankRow" .. i] = row
    end

    -- Raid healers
    local raidHealLbl = assignSec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    raidHealLbl:SetPoint("TOPLEFT", assignSec, "TOPLEFT", 6, -118)
    raidHealLbl:SetText("|cff44FF44Heal Raid:|r")
    local raidHealText = assignSec:CreateFontString("RT_Dash_RaidHeal", "OVERLAY", "GameFontNormalSmall")
    raidHealText:SetPoint("LEFT", raidHealLbl, "RIGHT", 6, 0)
    raidHealText:SetWidth(430)
    raidHealText:SetJustifyH("LEFT")
    raidHealText:SetText("")
    DASH.raidHeal = raidHealText

    -- Buffs
    local buffLbl2 = assignSec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buffLbl2:SetPoint("TOPLEFT", assignSec, "TOPLEFT", 6, -136)
    buffLbl2:SetText("|cff88FF88Buffs:|r")
    local buffText2 = assignSec:CreateFontString("RT_Dash_Buffs", "OVERLAY", "GameFontNormalSmall")
    buffText2:SetPoint("LEFT", buffLbl2, "RIGHT", 6, 0)
    buffText2:SetWidth(440)
    buffText2:SetJustifyH("LEFT")
    buffText2:SetText("")
    DASH.buffs = buffText2

    -- Bouton Annoncer assignments
    local announceBtn2 = CreateFrame("Button", nil, assignSec, "UIPanelButtonTemplate")
    announceBtn2:SetPoint("BOTTOMRIGHT", assignSec, "BOTTOMRIGHT", -6, 6)
    announceBtn2:SetWidth(110)
    announceBtn2:SetHeight(22)
    announceBtn2:SetText("|cff88FF88Annoncer /Raid|r")
    announceBtn2:SetScript("OnClick", function()
        if RT_AA_LAST then RT_AA_AnnounceAll(RT_AA_LAST) end
    end)

    local whisperBtn2 = CreateFrame("Button", nil, assignSec, "UIPanelButtonTemplate")
    whisperBtn2:SetPoint("RIGHT", announceBtn2, "LEFT", -4, 0)
    whisperBtn2:SetWidth(100)
    whisperBtn2:SetHeight(22)
    whisperBtn2:SetText("Whisper Perso")
    whisperBtn2:SetScript("OnClick", function()
        if RT_AA_LAST then RT_AA_WhisperPersonal(RT_AA_LAST) end
    end)

    -- ════════════════════════════════════════════════════════
    -- SECTION 5 : Mon Attrib personnel (milieu droite)
    -- ════════════════════════════════════════════════════════
    local mySec, myLbl = MakeSection(p, 560, 124, 212, 160, "Mon Attrib", "|cff88CCFF")

    local myText = mySec:CreateFontString("RT_Dash_MyAttrib", "OVERLAY", "GameFontNormalSmall")
    myText:SetPoint("TOPLEFT", mySec, "TOPLEFT", 6, -22)
    myText:SetWidth(200)
    myText:SetHeight(130)
    myText:SetJustifyH("LEFT")
    myText:SetText("|cffAAAAAA(lance PUG Pack\nou Guild Pack)|r")
    DASH.myAttrib = myText

    -- ════════════════════════════════════════════════════════
    -- SECTION 6 : Tactique Boss (bas gauche)
    -- ════════════════════════════════════════════════════════
    local tactSec, tactLbl = MakeSection(p, 4, 292, 548, 158, "Tactique Boss", "|cffFFD700")

    local tactBossName = tactSec:CreateFontString("RT_Dash_TactBoss", "OVERLAY", "GameFontNormal")
    tactBossName:SetPoint("TOPLEFT", tactSec, "TOPLEFT", 6, -22)
    tactBossName:SetWidth(430)
    tactBossName:SetJustifyH("LEFT")
    tactBossName:SetText("|cffAAAAAA(aucun boss sélectionné)|r")
    DASH.tactBossName = tactBossName

    local tactText = tactSec:CreateFontString("RT_Dash_TactText", "OVERLAY", "GameFontNormalSmall")
    tactText:SetPoint("TOPLEFT", tactSec, "TOPLEFT", 6, -42)
    tactText:SetWidth(536)
    tactText:SetHeight(88)
    tactText:SetJustifyH("LEFT")
    tactText:SetText("")
    DASH.tactText = tactText

    local tactPostBtn = CreateFrame("Button", nil, tactSec, "UIPanelButtonTemplate")
    tactPostBtn:SetPoint("BOTTOMLEFT", tactSec, "BOTTOMLEFT", 6, 6)
    tactPostBtn:SetWidth(100)
    tactPostBtn:SetHeight(22)
    tactPostBtn:SetText("|cff88FF88Post /Raid|r")
    tactPostBtn:SetScript("OnClick", function()
        local boss = RT_BOSS_STATE and RT_BOSS_STATE.bossName or ""
        if boss ~= "" and RT_Tactics then RT_Tactics.Post(boss, "RAID") end
    end)

    local tactViewBtn = CreateFrame("Button", nil, tactSec, "UIPanelButtonTemplate")
    tactViewBtn:SetPoint("LEFT", tactPostBtn, "RIGHT", 4, 0)
    tactViewBtn:SetWidth(100)
    tactViewBtn:SetHeight(22)
    tactViewBtn:SetText("→ Toutes Tactics")
    tactViewBtn:SetScript("OnClick", function()
        RT_SetDisplayMode("advanced")
        if RT_ShowTab then RT_ShowTab("Tactics") end
    end)

    -- ════════════════════════════════════════════════════════
    -- SECTION 7 : Status Raid rapide (bas droite)
    -- ════════════════════════════════════════════════════════
    local statSec, statLbl = MakeSection(p, 560, 292, 212, 158, "Raid Live", "|cff88FF88")

    local statText = statSec:CreateFontString("RT_Dash_StatText", "OVERLAY", "GameFontNormalSmall")
    statText:SetPoint("TOPLEFT", statSec, "TOPLEFT", 6, -22)
    statText:SetWidth(200)
    statText:SetHeight(130)
    statText:SetJustifyH("LEFT")
    statText:SetText("")
    DASH.statText = statText

    -- Refresh timer (1.12 : GetTime() plus fiable que elapsed)
    local _dashLast = GetTime()
    p:SetScript("OnUpdate", function()
        if (GetTime() - _dashLast) < 2 then return end
        _dashLast = GetTime()
        RT_Dash.Refresh()
    end)

    -- Refresh initial
    RT_Dash.Refresh()
end

-- ── Refresh du Dashboard ────────────────────────────────────
function RT_Dash.Refresh()
    if not DASH.raidCount then return end

    RT_DB = RT_DB or {}

    -- 1. Statut raid
    local nRaid  = GetNumRaidMembers  and GetNumRaidMembers()  or 0
    local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    if nRaid > 0 then
        DASH.raidCount:SetText("|cff88FF88" .. nRaid .. "/40 joueurs en raid|r")
    elseif nParty > 0 then
        DASH.raidCount:SetText("|cff88FF88" .. (nParty+1) .. " joueurs en groupe|r")
    else
        local nb = 0
        for _ in pairs(RT_DB.roster or {}) do nb = nb + 1 end
        if nb > 0 then
            DASH.raidCount:SetText("|cffFFAA00" .. nb .. " joueurs dans le roster|r")
        else
            DASH.raidCount:SetText("|cffAAAAAA(hors raid, roster vide)|r")
        end
    end

    -- Compte rôles
    local tanks, heals, dps = 0, 0, 0
    for _, data in pairs(RT_DB.roster or {}) do
        local r = data.role or "DPS"
        if r == "Tank" then tanks = tanks + 1
        elseif r == "Heal" then heals = heals + 1
        else dps = dps + 1 end
    end
    if tanks + heals + dps > 0 then
        DASH.raidRoles:SetText(
            "|cffFFAA00Tank: " .. tanks .. "|r  " ..
            "|cff44FF44Heal: " .. heals .. "|r  " ..
            "|cffFF6666DPS: "  .. dps   .. "|r")
    else
        DASH.raidRoles:SetText("")
    end

    -- Sync badge
    local nSync = 0
    if RT_SYNC_MEMBERS then
        for _ in pairs(RT_SYNC_MEMBERS) do nSync = nSync + 1 end
    end
    if nSync > 0 then
        DASH.syncBadge:SetText("|cff88CCFF" .. nSync .. " joueur(s) avec RT v2|r")
    else
        DASH.syncBadge:SetText("")
    end

    -- 2. Boss actif
    local boss = (RT_BOSS_STATE and RT_BOSS_STATE.bossName) or ""
    if boss ~= "" then
        DASH.bossName:SetText("|cffFFD700" .. boss .. "|r")
    else
        DASH.bossName:SetText("|cffAAAAAA(aucun boss sélectionné)|r")
    end

    -- 3. Assignments
    local out = RT_AA_LAST
    local markerNames = { "Skull","Cross","Square","Moon","Triangle","Diamond","Circle","Star" }
    for i = 1, 4 do
        local row = DASH["tankRow" .. i]
        if row then
            if out and out.tanks and out.tanks[i] and out.tanks[i] ~= "" then
                local tname = out.tanks[i]
                local mk    = out.tankMarkers and out.tankMarkers[i] or ""
                local heal  = out.healTank and out.healTank[i] or ""
                local mkStr = mk ~= "" and ("|cffFFD700[" .. mk .. "]|r ") or ""
                local tRoster = RT_DB.roster and RT_DB.roster[tname] or {}
                local tClass  = tRoster.class or ""
                row:SetText(
                    mkStr ..
                    "|cffFFAA00MT" .. i .. ":|r " .. CC(tClass, tname) ..
                    (heal ~= "" and ("  |cff44FF44←|r " .. heal) or ""))
            else
                row:SetText("")
            end
        end
    end

    if DASH.raidHeal then
        if out and out.healRaid and table.getn(out.healRaid) > 0 then
            DASH.raidHeal:SetText(table.concat(out.healRaid, "  "))
        else
            DASH.raidHeal:SetText("|cffAAAAAA(lancer PUG Pack)|r")
        end
    end

    if DASH.buffs then
        if out and out.buffs and table.getn(out.buffs) > 0 then
            local bparts = {}
            for i = 1, math.min(table.getn(out.buffs), 4) do
                local b = out.buffs[i]
                table.insert(bparts, b.name .. ": " .. b.buff)
            end
            DASH.buffs:SetText(table.concat(bparts, "   "))
        else
            DASH.buffs:SetText("|cffAAAAAA(lancer PUG Pack)|r")
        end
    end

    -- 4. Mon Attrib
    if DASH.myAttrib then
        local player = UnitName and UnitName("player") or ""
        if out and player ~= "" then
            local lines = {}
            -- Trouver dans roster
            local myData = RT_DB.roster and RT_DB.roster[player]
            if myData then
                table.insert(lines, CC(myData.class or "", player))
                table.insert(lines, "|cff888888" .. (myData.class or "?") .. " " .. (myData.spec or "") .. " " .. (myData.role or "") .. "|r")
            end
            -- Groupe
            local function findGrp(name)
                for g = 1, 8 do
                    local grp = out.groups and out.groups[g] or {}
                    for s = 1, table.getn(grp) do
                        if grp[s] == name then return g end
                    end
                end
            end
            local grp = findGrp(player)
            if grp then table.insert(lines, "Groupe |cff88CCFF" .. grp .. "|r") end
            -- Tank heal
            for ti = 1, table.getn(out.healTank or {}) do
                if out.healTank[ti] == player then
                    table.insert(lines, "|cff44FF44Heal MT" .. ti .. ": |r" .. (out.tanks[ti] or "?"))
                end
            end
            -- Raid heal
            for _, rh in pairs(out.healRaid or {}) do
                if rh == player then table.insert(lines, "|cff44FF44Heal Raid|r") end
            end
            -- Buff
            for _, b in pairs(out.buffs or {}) do
                if b.name == player then
                    table.insert(lines, "|cff88FF88Buff: |r" .. b.buff)
                end
            end
            DASH.myAttrib:SetText(table.getn(lines) > 0 and table.concat(lines, "\n") or "|cffAAAAAA(non trouvé dans l'attribution)|r")
        else
            DASH.myAttrib:SetText("|cffAAAAAA(lancer PUG Pack\nou Guild Pack)|r")
        end
    end

    -- 5. Tactique boss
    if DASH.tactBossName and DASH.tactText then
        if boss ~= "" and RT_Tactics then
            local tact = RT_Tactics.Find(boss)
            if tact then
                DASH.tactBossName:SetText("|cffFFD700" .. tact.boss .. "|r  |cff888888" .. (tact.raid or "") .. "|r")
                local preview = {}
                for i = 1, math.min(table.getn(tact.lines), 4) do
                    table.insert(preview, tact.lines[i])
                end
                DASH.tactText:SetText(table.concat(preview, "\n"))
            else
                DASH.tactBossName:SetText("|cffFFD700" .. boss .. "|r  |cff888888(pas de tactic enregistrée)|r")
                DASH.tactText:SetText("|cffAAAAAA Ajoute une tactique custom dans l'onglet Tactics.|r")
            end
        else
            DASH.tactBossName:SetText("|cffAAAAAA(sélectionne un boss dans l'onglet Boss)|r")
            DASH.tactText:SetText("")
        end
    end

    -- 6. Live raid info
    if DASH.statText then
        local liveLines = {}
        if nRaid > 0 then
            table.insert(liveLines, "|cff88FF88" .. nRaid .. " joueurs en raid|r")
            -- Vérifie les présences live
            local nOnline = 0
            for i = 1, nRaid do
                local rname, _, sg, _, _, rclass = GetRaidRosterInfo(i)
                if rname then
                    nOnline = nOnline + 1
                end
            end
            table.insert(liveLines, "En ligne: |cff88FF88" .. nOnline .. "|r")
        elseif nParty > 0 then
            table.insert(liveLines, "|cff88FF88" .. (nParty+1) .. " en groupe|r")
        else
            table.insert(liveLines, "|cffAAAAAA(hors groupe)|r")
        end
        -- Boss status
        if boss ~= "" then
            table.insert(liveLines, "Boss: |cffFFD700" .. boss .. "|r")
        end
        -- Kills récents
        RT_DB.attendance = RT_DB.attendance or {}
        local killCount = 0
        for _ in pairs(RT_DB.attendance) do killCount = killCount + 1 end
        if killCount > 0 then
            table.insert(liveLines, killCount .. " boss enregistré(s)")
        end
        DASH.statText:SetText(table.concat(liveLines, "\n"))
    end
end

-- ── Init : restaurer le mode sauvegardé ────────────────────
-- (1.12 : OnUpdate reçoit elapsed comme 1er argument, pas self)
local RT_DashInitFrame = CreateFrame("Frame")
RT_DashInitFrame:RegisterEvent("VARIABLES_LOADED")
RT_DashInitFrame:SetScript("OnEvent", function()
    RT_DB = RT_DB or {}
    RT_DISPLAY_MODE = RT_DB.displayMode or "advanced"
    local _tStart = GetTime()
    RT_DashInitFrame:SetScript("OnUpdate", function()
        if (GetTime() - _tStart) < 1 then return end
        RT_DashInitFrame:SetScript("OnUpdate", nil)
        if RT_UI_BUILT and RT_DISPLAY_MODE then
            RT_SetDisplayMode(RT_DISPLAY_MODE)
        end
    end)
end)
