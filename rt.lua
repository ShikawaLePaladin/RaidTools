-- RT - Raid Tool
-- Version : 1.0-turtle  |  TurtleWoW vanilla 1.12
-- Dépendances (chargées avant ce fichier via rt.toc) :
--   Colors.lua   → RT_CLASS_COLORS, RT_ROLE_COLORS, RT_Color*, RT_PadRight, RT_AttachSimpleTooltip
--   Config.lua   → RT_SPEC_ROLE, RT_BUFFS_LIST, RT_VANILLA_RAIDS, RT_DEFAULT_RAID_BOSSES
--   BossPresets.lua → RT_BOSS_PRESETS
-- ============================================================

-- ============================================================
-- Données persistantes (initialisées après VARIABLES_LOADED)
-- ============================================================
RT_DB = RT_DB or {}

-- État interne du panel Boss
RT_BOSS_STATE = {
        raidIdx  = 1,
        bossName = "",
        tanks    = {"","","",""},
        tank_marks = {"","","",""},
        tank_count = 3,
        h_tank1  = {"",""},
        h_tank2  = {"",""},
        h_tank3  = {"",""},
        h_tank4  = {"",""},
        h_raid   = {"","",""},
        h_melee  = {""},
        h_caster = {""},
        h_counts = {
            h_tank1 = 2, h_tank2 = 2, h_tank3 = 2, h_tank4 = 2,
            h_raid = 3, h_melee = 1, h_caster = 1
        },
        note     = "",
}

RT_BOSS_HEAL_DEFAULTS = {
    h_tank1 = 2, h_tank2 = 2, h_tank3 = 2, h_tank4 = 2,
    h_raid = 3, h_melee = 1, h_caster = 1
}
RT_BOSS_HEAL_LIMITS   = {
    h_tank1 = 4, h_tank2 = 4, h_tank3 = 4, h_tank4 = 4,
    h_raid = 6, h_melee = 3, h_caster = 3
}

-- Références boutons de slots (rempli par RT_BuildUI)
RT_BOSS_SLOT_BTNS = {}
-- Callback du picker joueur
RT_PICKER_CALLBACK = nil
-- Filtre rôle du roster
RT_ROSTER_ROLE_FILTER = "All"
-- Joueur sélectionné dans l'éditeur de rôle du roster
RT_ROSTER_SELECTED_PLAYER = ""
RT_GROUP_SLOT_BTNS = {}
RT_GROUP_SLOT_CTX = nil
RT_GROUP_DRAG_SOURCE = nil   -- {g, s, name} quand un joueur est selectionne pour deplacement
RT_GROUP_SLOT_AC_CACHE = {}
RT_GROUP_SLOT_AC_SELECTED_IDX = 0
RT_GROUP_INVITE_INTERVAL = 2
RT_GROUP_INVITE_BURST = 5
RT_GROUP_INVITE_TIMER = 0
RT_GROUP_INVITE_CLOCK = 0
RT_GROUP_INVITE_CURSOR = 0
RT_GROUP_INVITE_ATTEMPTED = {}
-- Markers disponibles pour les tanks (clic droit sur un slot tank)
RT_TANK_MARKERS = { "", "Skull", "Cross", "Square", "Moon", "Triangle", "Diamond", "Circle", "Star" }
-- Noms texte pour OctoWow/TurtleWoW ({rt1} ne fonctionne pas)
RT_TANK_MARKER_RAID_ICON = {
    ["Star"]     = "[Star]",
    ["Circle"]   = "[Circle]",
    ["Diamond"]  = "[Diamond]",
    ["Triangle"] = "[Triangle]",
    ["Moon"]     = "[Moon]",
    ["Square"]   = "[Square]",
    ["Cross"]    = "[Cross]",
    ["Skull"]    = "[Skull]",
}
RT_BOSS_MARKER_SLOT_IDX = nil
RT_MARKER_ANNOUNCE_LAST_TIME = 0
RT_MARKER_ANNOUNCE_LAST_SIG = ""

local function RT_BossMarkerAnnounceSig()
    if not RT_BOSS_STATE then return "" end
    return (RT_BOSS_STATE.bossName or "")
        .. "|" .. (RT_BOSS_STATE.tanks and RT_BOSS_STATE.tanks[1] or "")
        .. "|" .. (RT_BOSS_STATE.tank_marks and RT_BOSS_STATE.tank_marks[1] or "")
        .. "|" .. (RT_BOSS_STATE.tanks and RT_BOSS_STATE.tanks[2] or "")
        .. "|" .. (RT_BOSS_STATE.tank_marks and RT_BOSS_STATE.tank_marks[2] or "")
        .. "|" .. (RT_BOSS_STATE.tanks and RT_BOSS_STATE.tanks[3] or "")
        .. "|" .. (RT_BOSS_STATE.tank_marks and RT_BOSS_STATE.tank_marks[3] or "")
        .. "|" .. (RT_BOSS_STATE.tanks and RT_BOSS_STATE.tanks[4] or "")
        .. "|" .. (RT_BOSS_STATE.tank_marks and RT_BOSS_STATE.tank_marks[4] or "")
end

local function RT_BossMaybeAnnounceTankMarks(changed)
    -- Auto-announce markers désactivé — utilise le bouton "Tanks" manuellement
end

function RT_NormalizeRole(role)
    local t = string.gsub(role or "", "^%s+", "")
    t = string.gsub(t, "%s+$", "")
    t = string.lower(t)
    if t == "tank" or t == "mt" then return "Tank" end
    if t == "heal" or t == "healer" or t == "soin" then return "Heal" end
    if t == "melee" or t == "cac" or t == "melée" or t == "mêlée" then return "Melee" end
    if t == "ranged" or t == "range" or t == "rdps" or t == "distance" then return "Ranged" end
    if t == "dps" then return "DPS" end
    return "DPS"
end

-- Onglets disponibles
RT_TABS = { "Roster", "Boss", "Groups", "Buffs", "Loot", "Import", "Notes", "Check", "Timer", "Invite", "Attend" }
RT_CURRENT_TAB = "Import"

RT_GROUP_MELEE_CLASSES = {
    Warrior = true,
    Rogue = true,
    Paladin = true,
    Shaman = true,
    Druid = true,
}
RT_GROUP_MELEE_SPECS = {
    Fury = true,
    Arms = true,
    Combat = true,
    Assassination = true,
    Swords = true,
    Enhancement = true,
    Retribution = true,
    Feral = true,
}
RT_GROUP_MELEE_SUPPORT_CLASSES = {
    Shaman = true,
    Paladin = true,
}

-- ============================================================
-- BossSheet v2 — logique Raid > Boss > Slots
-- ============================================================

local function RT_BTrim(s)
    local t = string.gsub(s or "", "^%s+", "")
    t = string.gsub(t, "%s+$", "")
    return t
end

local function RT_BossGetRaid()
    local idx = (RT_BOSS_STATE and RT_BOSS_STATE.raidIdx) or 1
    return RT_VANILLA_RAIDS[idx]
end

local function RT_BossRaidKey()
    local r = RT_BossGetRaid()
    return r and r.key or "CUSTOM"
end

local function RT_BossEnsure()
    RT_DB.bosses   = RT_DB.bosses   or {}
    RT_DB.sessions = RT_DB.sessions or {}
    local k = RT_BossRaidKey()
    if not RT_DB.bosses[k] then RT_DB.bosses[k] = {} end
end

local function RT_BossSetStatus2(text, isErr)
    local s = getglobal("RT_BossStatus2")
    if not s then return end
    s:SetText(isErr and RT_ColorErr(text) or RT_ColorOK(text))
end

local function RT_BossEnsureHealState(state)
    if not state then return end
    state.tanks      = state.tanks      or {"", "", "", ""}
    state.tank_marks = state.tank_marks or {"", "", "", ""}
    state.tank_count = state.tank_count or 3
    if state.tank_count < 1 then state.tank_count = 1 end
    if state.tank_count > 4 then state.tank_count = 4 end

    state.h_tank1  = state.h_tank1  or {}
    state.h_tank2  = state.h_tank2  or {}
    state.h_tank3  = state.h_tank3  or {}
    state.h_tank4  = state.h_tank4  or {}
    state.h_raid   = state.h_raid   or {}
    state.h_melee  = state.h_melee  or {}
    state.h_caster = state.h_caster or {}
    state.h_counts = state.h_counts or {}
    for k, def in pairs(RT_BOSS_HEAL_DEFAULTS) do
        local limit = RT_BOSS_HEAL_LIMITS[k] or def
        local c = state.h_counts[k] or def
        if c < 1 then c = 1 end
        if c > limit then c = limit end
        state.h_counts[k] = c
    end
end

function RT_BossChangeTankSlots(delta)
    if not RT_BOSS_STATE then return end
    RT_BossEnsureHealState(RT_BOSS_STATE)
    local nextV = (RT_BOSS_STATE.tank_count or 3) + (delta or 0)
    if nextV < 1 then nextV = 1 end
    if nextV > 4 then nextV = 4 end
    local prev = RT_BOSS_STATE.tank_count or 3
    if nextV < prev then
        for i = nextV + 1, prev do
            RT_BOSS_STATE.tanks[i] = ""
            RT_BOSS_STATE.tank_marks[i] = ""
            local hk = "h_tank" .. i
            if RT_BOSS_STATE[hk] then
                for j = 1, table.getn(RT_BOSS_STATE[hk]) do RT_BOSS_STATE[hk][j] = "" end
            end
        end
    end
    RT_BOSS_STATE.tank_count = nextV
    RT_BossRefreshSlots()
end

function RT_BossChangeHealSlots(slotKey, delta)
    if not RT_BOSS_STATE then return end
    RT_BossEnsureHealState(RT_BOSS_STATE)
    local limit = RT_BOSS_HEAL_LIMITS[slotKey] or 1
    local cur   = RT_BOSS_STATE.h_counts[slotKey] or 1
    local nextV = cur + (delta or 0)
    if nextV < 1 then nextV = 1 end
    if nextV > limit then nextV = limit end

    if nextV < cur then
        for i = nextV + 1, cur do
            if RT_BOSS_STATE[slotKey] then RT_BOSS_STATE[slotKey][i] = "" end
        end
    end
    RT_BOSS_STATE.h_counts[slotKey] = nextV
    RT_BossRefreshSlots()
end

-- Rafraîchit les labels de tous les boutons de slots
function RT_BossRefreshSlots()
    if not RT_BOSS_STATE then return end
    local state = RT_BOSS_STATE
    RT_BossEnsureHealState(state)

    local tankMap = {
        {"tank_1", 1}, {"tank_2", 2}, {"tank_3", 3}, {"tank_4", 4},
    }
    for eIdx = 1, table.getn(tankMap) do
        local e = tankMap[eIdx]
        local key, idx = e[1], e[2]
        local btn  = RT_BOSS_SLOT_BTNS[key]
        local xBtn = RT_BOSS_SLOT_BTNS[key .. "_x"]
        local lbl  = getglobal("RT_BossTankLbl" .. idx)
        if btn then
            if idx <= (state.tank_count or 3) then
                local val = (state.tanks and state.tanks[idx]) or ""
                local marker = (state.tank_marks and state.tank_marks[idx]) or ""
                if val ~= "" then
                    btn:SetText(marker ~= "" and ("[" .. marker .. "] " .. val) or val)
                    local fs = btn:GetFontString()
                    if fs then fs:SetTextColor(0.7, 1, 0.7) end
                else
                    btn:SetText(marker ~= "" and ("[" .. marker .. "] ---") or "---")
                    local fs = btn:GetFontString()
                    if fs then fs:SetTextColor(0.55, 0.55, 0.55) end
                end
                btn:Show()
                if xBtn then xBtn:Show() end
                -- Mettre à jour le label/bouton marker
                if lbl then
                    lbl:Show()
                    if lbl.GetFontString then
                        local lfs = lbl:GetFontString()
                        if lfs then
                            if marker ~= "" then
                                lfs:SetTextColor(1.0, 0.82, 0.0)
                            else
                                lfs:SetTextColor(0.6, 0.6, 0.6)
                            end
                        end
                    end
                end
            else
                btn:Hide()
                if xBtn then xBtn:Hide() end
                if lbl then lbl:Hide() end
            end
        end
    end

    local tankCountLbl = getglobal("RT_BossTankCount")
    if tankCountLbl then tankCountLbl:SetText("(" .. (state.tank_count or 3) .. ")") end

    local healRowsEnabled = {
        h_tank1 = true,
        h_tank2 = true,
        h_tank3 = (state.tank_count or 3) >= 3,
        h_tank4 = (state.tank_count or 3) >= 4,
        h_raid  = true,
        h_melee = true,
        h_caster= true,
    }
    local healKeys = { "h_tank1", "h_tank2", "h_tank3", "h_tank4", "h_raid", "h_melee", "h_caster" }

    for keyIdx = 1, table.getn(healKeys) do
        local slotKey = healKeys[keyIdx]
        local rowOn = healRowsEnabled[slotKey]
        local rowLbl = getglobal("RT_BossLbl_" .. slotKey)
        local minusBtn = RT_BOSS_SLOT_BTNS[slotKey .. "_minus"]
        local plusBtn = RT_BOSS_SLOT_BTNS[slotKey .. "_plus"]
        local countLbl = getglobal("RT_BossCount_" .. slotKey)

        if rowLbl then if rowOn then rowLbl:Show() else rowLbl:Hide() end end
        if minusBtn then if rowOn then minusBtn:Show() else minusBtn:Hide() end end
        if plusBtn then if rowOn then plusBtn:Show() else plusBtn:Hide() end end
        if countLbl then if rowOn then countLbl:Show() else countLbl:Hide() end end

        if not rowOn then
            local arr = state[slotKey] or {}
            for i = 1, table.getn(arr) do arr[i] = "" end
        end

        local maxN = RT_BOSS_HEAL_LIMITS[slotKey] or 1
        local cnt  = state.h_counts[slotKey] or 1
        local arr  = state[slotKey] or {}
        for i = 1, maxN do
            local btn = RT_BOSS_SLOT_BTNS[slotKey .. "_" .. i]
            local xBtn = RT_BOSS_SLOT_BTNS[slotKey .. "_" .. i .. "_x"]
            if btn then
                if rowOn and i <= cnt then
                    local val = arr[i] or ""
                    if val ~= "" then
                        btn:SetText(val)
                        local fs = btn:GetFontString()
                        if fs then fs:SetTextColor(0.7, 1, 0.7) end
                    else
                        btn:SetText("---")
                        local fs = btn:GetFontString()
                        if fs then fs:SetTextColor(0.55, 0.55, 0.55) end
                    end
                    btn:Show()
                    if xBtn then xBtn:Show() end
                else
                    btn:Hide()
                    if xBtn then xBtn:Hide() end
                end
            end
        end
        if countLbl then countLbl:SetText("(" .. cnt .. ")") end
    end

    local noteEdit = getglobal("RT_BossNoteEdit2")
    if noteEdit then noteEdit:SetText(state.note or "") end
end

function RT_BossCycleTankMarker(slotIdx)
    if not RT_BOSS_STATE then return end
    RT_BOSS_STATE.tank_marks = RT_BOSS_STATE.tank_marks or {"","","",""}
    local cur = RT_BOSS_STATE.tank_marks[slotIdx] or ""
    local pos = 1
    for markIdx = 1, table.getn(RT_TANK_MARKERS) do
        local mark = RT_TANK_MARKERS[markIdx]
        if mark == cur then pos = markIdx; break end
    end
    local nextPos = pos + 1
    if nextPos > table.getn(RT_TANK_MARKERS) then nextPos = 1 end
    RT_BOSS_STATE.tank_marks[slotIdx] = RT_TANK_MARKERS[nextPos]
    RT_BossRefreshSlots()
    RT_BossMaybeAnnounceTankMarks(cur ~= RT_BOSS_STATE.tank_marks[slotIdx])
end

function RT_BossSetTankMarker(marker)
    if not RT_BOSS_STATE then return end
    if not RT_BOSS_MARKER_SLOT_IDX then return end
    RT_BOSS_STATE.tank_marks = RT_BOSS_STATE.tank_marks or {"", "", "", ""}
    local old = RT_BOSS_STATE.tank_marks[RT_BOSS_MARKER_SLOT_IDX] or ""
    RT_BOSS_STATE.tank_marks[RT_BOSS_MARKER_SLOT_IDX] = marker or ""
    RT_BossRefreshSlots()
    RT_BossMaybeAnnounceTankMarks(old ~= (marker or ""))
    local popup = getglobal("RT_TankMarkerPopup")
    if popup then popup:Hide() end
end

-- Force un popup au premier plan, au-dessus du menu principal
local function RT_PopupBringToFront(popup)
    if not popup then return end
    popup:SetFrameStrata("TOOLTIP")
    if popup.SetToplevel then popup:SetToplevel(true) end
    local base = 20
    if RT_MainFrame and RT_MainFrame.GetFrameLevel then
        base = RT_MainFrame:GetFrameLevel() + 30
    end
    popup:SetFrameLevel(base)
    popup:Show()
    popup:Raise()
end

function RT_BossOpenMarkerPicker(slotIdx)
    RT_BOSS_MARKER_SLOT_IDX = slotIdx
    local popup = getglobal("RT_TankMarkerPopup")
    if not popup then
        RT_BossCycleTankMarker(slotIdx)
        return
    end
    local title = getglobal("RT_TankMarkerPopupTitle")
    if title then title:SetText("Marker Tank " .. slotIdx) end
    RT_PopupBringToFront(popup)
end

-- Rafraîchit le bouton Raid
local function RT_BossRefreshRaidBtn()
    local btn = getglobal("RT_BossRaidBtn")
    if not btn then return end
    local r = RT_BossGetRaid()
    btn:SetText(r and r.name or "-- Raid --")
end

-- Rafraîchit le bouton Boss
local function RT_BossRefreshBossBtn()
    local btn = getglobal("RT_BossBossBtn")
    if not btn then return end
    local boss = RT_BOSS_STATE and RT_BOSS_STATE.bossName or ""
    btn:SetText(boss ~= "" and boss or "-- Boss --")
end

-- Charge la fiche sauvegardée dans RT_BOSS_STATE
function RT_BossLoadFromUI()
    if not RT_BOSS_STATE then return end
    local boss = RT_BOSS_STATE.bossName
    if not boss or boss == "" then
        RT_BossSetStatus2("Selectionnez un boss.", true)
        return
    end
    RT_BossEnsure()
    local data = RT_DB.bosses[RT_BossRaidKey()][boss]
    if not data then
        RT_BossSetStatus2("Aucune fiche pour " .. boss, true)
        return
    end
    local function safeList(t, n)
        local out = {}
        for i = 1, n do out[i] = (t and t[i]) or "" end
        return out
    end
    local function inferCount(arr, key)
        local limit = RT_BOSS_HEAL_LIMITS[key] or 1
        local def   = RT_BOSS_HEAL_DEFAULTS[key] or 1
        local maxSeen = 0
        for i = limit, 1, -1 do
            if arr and arr[i] and arr[i] ~= "" then
                maxSeen = i
                break
            end
        end
        if data.h_counts and data.h_counts[key] then
            maxSeen = data.h_counts[key]
        elseif maxSeen == 0 then
            maxSeen = def
        end
        if maxSeen < 1 then maxSeen = 1 end
        if maxSeen > limit then maxSeen = limit end
        return maxSeen
    end
    RT_BOSS_STATE.tanks    = safeList(data.tanks,    4)
    RT_BOSS_STATE.tank_marks = safeList(data.tank_marks, 4)
    RT_BOSS_STATE.tank_count = data.tank_count or 3
    RT_BOSS_STATE.h_tank1  = safeList(data.h_tank1,  RT_BOSS_HEAL_LIMITS.h_tank1)
    RT_BOSS_STATE.h_tank2  = safeList(data.h_tank2,  RT_BOSS_HEAL_LIMITS.h_tank2)
    RT_BOSS_STATE.h_tank3  = safeList(data.h_tank3,  RT_BOSS_HEAL_LIMITS.h_tank3)
    RT_BOSS_STATE.h_tank4  = safeList(data.h_tank4,  RT_BOSS_HEAL_LIMITS.h_tank4)
    RT_BOSS_STATE.h_raid   = safeList(data.h_raid,   RT_BOSS_HEAL_LIMITS.h_raid)
    RT_BOSS_STATE.h_melee  = safeList(data.h_melee,  RT_BOSS_HEAL_LIMITS.h_melee)
    RT_BOSS_STATE.h_caster = safeList(data.h_caster, RT_BOSS_HEAL_LIMITS.h_caster)
    RT_BOSS_STATE.h_counts = {
        h_tank1 = inferCount(RT_BOSS_STATE.h_tank1, "h_tank1"),
        h_tank2 = inferCount(RT_BOSS_STATE.h_tank2, "h_tank2"),
        h_tank3 = inferCount(RT_BOSS_STATE.h_tank3, "h_tank3"),
        h_tank4 = inferCount(RT_BOSS_STATE.h_tank4, "h_tank4"),
        h_raid  = inferCount(RT_BOSS_STATE.h_raid,  "h_raid"),
        h_melee = inferCount(RT_BOSS_STATE.h_melee, "h_melee"),
        h_caster= inferCount(RT_BOSS_STATE.h_caster,"h_caster"),
    }
    RT_BOSS_STATE.note     = data.note or ""
    RT_BossRefreshSlots()
    RT_BossSetStatus2(RT_Text("boss_loaded", {boss=boss}), false)
end

-- Sauvegarde RT_BOSS_STATE dans RT_DB
function RT_BossGetStratKey()
    local raidKey  = RT_BossRaidKey() or "?"
    local bossName = RT_BOSS_STATE and RT_BOSS_STATE.bossName or ""
    if bossName == "" then return nil end
    return raidKey .. " - " .. bossName
end

-- Charge la note depuis stratNotes si disponible, sinon depuis boss.note
local function RT_BossSyncNoteFromStrat()
    local stratKey = RT_BossGetStratKey()
    if not stratKey then return end
    RT_DB.stratNotes = RT_DB.stratNotes or {}
    local stratNote = RT_DB.stratNotes[stratKey]
    local syncLbl = getglobal("RT_BossStratSyncLbl")
    if stratNote and stratNote ~= "" then
        RT_BOSS_STATE.note = stratNote
        local noteEdit = getglobal("RT_BossNoteEdit2")
        if noteEdit then noteEdit:SetText(stratNote) end
        if syncLbl then syncLbl:SetText("|cff44FF88✓ Notes|r") end
    elseif RT_BOSS_STATE.note and RT_BOSS_STATE.note ~= "" then
        -- Sync inverse : note du boss → stratNotes
        RT_DB.stratNotes[stratKey] = RT_BOSS_STATE.note
        if syncLbl then syncLbl:SetText("|cffFFAA00~ syncé|r") end
    else
        if syncLbl then syncLbl:SetText("|cff666666pas de strat|r") end
    end
end

function RT_BossSaveFromUI()
    if not RT_BOSS_STATE then return end
    local boss = RT_BOSS_STATE.bossName
    if not boss or boss == "" then
        RT_BossSetStatus2(RT_Text("boss_select_first"), true)
        return
    end
    local noteEdit = getglobal("RT_BossNoteEdit2")
    if noteEdit then RT_BOSS_STATE.note = noteEdit:GetText() or "" end
    RT_BossEnsure()
    RT_DB.bosses[RT_BossRaidKey()][boss] = {
        tanks    = RT_BOSS_STATE.tanks,
        tank_marks = RT_BOSS_STATE.tank_marks,
        tank_count = RT_BOSS_STATE.tank_count,
        h_tank1  = RT_BOSS_STATE.h_tank1,
        h_tank2  = RT_BOSS_STATE.h_tank2,
        h_tank3  = RT_BOSS_STATE.h_tank3,
        h_tank4  = RT_BOSS_STATE.h_tank4,
        h_raid   = RT_BOSS_STATE.h_raid,
        h_melee  = RT_BOSS_STATE.h_melee,
        h_caster = RT_BOSS_STATE.h_caster,
        h_counts = RT_BOSS_STATE.h_counts,
        note     = RT_BOSS_STATE.note,
    }
    -- Sync vers stratNotes (source unique)
    local stratKey = RT_BossGetStratKey()
    if stratKey then
        RT_DB.stratNotes = RT_DB.stratNotes or {}
        RT_DB.stratNotes[stratKey] = RT_BOSS_STATE.note
        local syncLbl = getglobal("RT_BossStratSyncLbl")
        if syncLbl then
            if RT_BOSS_STATE.note ~= "" then
                syncLbl:SetText("|cff44FF88✓ Notes|r")
            else
                syncLbl:SetText("|cff666666pas de strat|r")
            end
        end
    end
    RT_BossSetStatus2(RT_Text("boss_saved_status", {boss=boss}), false)
    RT_BossDisplay(boss)
end

-- Markers par défaut selon la position MT (MT1=Skull, MT2=Cross, MT3=Square, MT4=Moon)
RT_BOSS_DEFAULT_MT_MARKERS = { "Skull", "Cross", "Square", "Moon" }

-- Import depuis le roster avec priorités heal complètes :
--   Paladin  → 1 par tank (prio tank)
--   Pretre   → tank si place dispo, sinon raid
--   Druid    → raid heal (+ note HoT sur tank)
--   Shaman   → raid heal
--   Markers auto → MT1=Skull, MT2=Cross, MT3=Square, MT4=Moon
function RT_BossImportFromRoster()
    if not RT_BOSS_STATE then
        RT_BossSetStatus2("Selectionne un boss d'abord.", true)
        return
    end
    RT_DB = RT_DB or {}
    local roster = RT_DB.roster or {}

    local tanks      = {}
    local palHeals   = {}
    local priestHeals= {}
    local druidHeals = {}
    local shamanHeals= {}
    local otherHeals = {}

    for name, data in pairs(roster) do
        local role  = RT_NormalizeRole(data.role or "")
        local class = (RT_NormalizeClassName and RT_NormalizeClassName(data.class or "")) or (data.class or "")
        if role == "Tank" then
            table.insert(tanks, name)
        elseif role == "Heal" then
            if     class == "Paladin" then table.insert(palHeals,    name)
            elseif class == "Priest"  then table.insert(priestHeals, name)
            elseif class == "Druid"   then table.insert(druidHeals,  name)
            elseif class == "Shaman"  then table.insert(shamanHeals, name)
            else                           table.insert(otherHeals,  name)
            end
        end
    end

    table.sort(tanks)
    table.sort(palHeals)
    table.sort(priestHeals)
    table.sort(druidHeals)
    table.sort(shamanHeals)

    local nTanks = math.min(table.getn(tanks), 4)
    RT_BOSS_STATE.tanks      = {"","","",""}
    RT_BOSS_STATE.tank_marks = {"","","",""}
    RT_BOSS_STATE.tank_count = math.max(nTanks, 1)

    -- Place les tanks + markers automatiques MT1=Skull, MT2=Cross...
    for i = 1, nTanks do
        RT_BOSS_STATE.tanks[i]      = tanks[i]
        RT_BOSS_STATE.tank_marks[i] = RT_BOSS_DEFAULT_MT_MARKERS[i] or ""
    end

    -- Prépare les slots heal (1 healer par tank)
    local healKeys = {"h_tank1","h_tank2","h_tank3","h_tank4"}
    for ti = 1, 4 do RT_BOSS_STATE[healKeys[ti]] = {""} end

    -- 1. Paladin → 1 par tank (prio MT1 → MT2...)
    local palIdx = 1
    for ti = 1, nTanks do
        if palIdx <= table.getn(palHeals) then
            RT_BOSS_STATE[healKeys[ti]][1] = palHeals[palIdx]
            palIdx = palIdx + 1
        end
    end

    -- 2. Prêtres → complètent les tanks sans healer, puis passent en raid
    local raidHealPool = {}
    local priIdx = 1
    for ti = 1, nTanks do
        if RT_BOSS_STATE[healKeys[ti]][1] == "" then
            if priIdx <= table.getn(priestHeals) then
                RT_BOSS_STATE[healKeys[ti]][1] = priestHeals[priIdx]
                priIdx = priIdx + 1
            end
        end
    end
    -- Prêtres restants → raid
    while priIdx <= table.getn(priestHeals) do
        table.insert(raidHealPool, priestHeals[priIdx])
        priIdx = priIdx + 1
    end

    -- 3. Druides → raid heal
    for i = 1, table.getn(druidHeals) do
        table.insert(raidHealPool, druidHeals[i])
    end

    -- 4. Shamans → raid heal
    for i = 1, table.getn(shamanHeals) do
        table.insert(raidHealPool, shamanHeals[i])
    end

    -- 5. Paladins excédentaires → raid
    while palIdx <= table.getn(palHeals) do
        table.insert(raidHealPool, palHeals[palIdx])
        palIdx = palIdx + 1
    end

    -- Remplit h_raid
    RT_BOSS_STATE.h_raid = {"","",""}
    for i = 1, math.min(table.getn(raidHealPool), 3) do
        RT_BOSS_STATE.h_raid[i] = raidHealPool[i]
    end

    RT_BOSS_STATE.h_melee  = {"","","",""}
    RT_BOSS_STATE.h_caster = {"","","",""}

    -- Met à jour les compteurs heal (1 par tank, X raid)
    RT_BOSS_STATE.h_counts = RT_BOSS_STATE.h_counts or {}
    for ti = 1, 4 do RT_BOSS_STATE.h_counts[healKeys[ti]] = 1 end
    RT_BOSS_STATE.h_counts["h_raid"]   = math.max(table.getn(raidHealPool), 1)
    RT_BOSS_STATE.h_counts["h_melee"]  = 1
    RT_BOSS_STATE.h_counts["h_caster"] = 1

    -- Note automatique pour les druides heal : HoT sur le tank principal
    local druidNote = ""
    if table.getn(druidHeals) > 0 and nTanks > 0 then
        local mt1 = tanks[1] or "MT1"
        local druidNames = table.concat(druidHeals, "/")
        druidNote = "Druides (" .. druidNames .. "): Rejuv + Lifebloom sur " .. mt1 .. " en permanence."
    end

    -- Ajoute la note druide à la note du boss (sans écraser)
    if druidNote ~= "" then
        local existing = RT_BOSS_STATE.note or ""
        if string.find(existing, "Druide", 1, true) then
            -- note druide déjà présente, on ne réécrit pas
        elseif existing ~= "" then
            RT_BOSS_STATE.note = existing .. "\n" .. druidNote
        else
            RT_BOSS_STATE.note = druidNote
        end
    end

    local nH = table.getn(palHeals) + table.getn(priestHeals) + table.getn(druidHeals) + table.getn(shamanHeals)
    RT_BossSetStatus2("Import OK : " .. nTanks .. "T " .. nH .. "H — markers auto assignes.", false)
    RT_BossRefreshSlots()
    RT_BossDisplay()
end

-- Efface tous les slots
function RT_BossClearUI()
    if not RT_BOSS_STATE then return end
    RT_BOSS_STATE.tanks    = {"","","",""}
    RT_BOSS_STATE.tank_marks = {"","","",""}
    RT_BOSS_STATE.tank_count = 3
    RT_BOSS_STATE.h_tank1  = {"",""}
    RT_BOSS_STATE.h_tank2  = {"",""}
    RT_BOSS_STATE.h_tank3  = {"",""}
    RT_BOSS_STATE.h_tank4  = {"",""}
    RT_BOSS_STATE.h_raid   = {"","",""}
    RT_BOSS_STATE.h_melee  = {""}
    RT_BOSS_STATE.h_caster = {""}
    RT_BOSS_STATE.h_counts = {
        h_tank1 = 2, h_tank2 = 2, h_tank3 = 2, h_tank4 = 2,
        h_raid = 3, h_melee = 1, h_caster = 1
    }
    RT_BOSS_STATE.note     = ""
    RT_BossRefreshSlots()
    RT_BossSetStatus2(RT_Text("boss_slots_cleared"), false)
end

-- Applique un preset BossPresets.lua à RT_BOSS_STATE sans écraser les slots joueurs
function RT_BossApplyPreset(bossName)
    if not RT_BOSS_PRESETS then return end
    local preset = RT_BOSS_PRESETS[bossName]
    if not preset then return end

    local function safeMarks(t)
        local out = {}
        for i = 1, 4 do out[i] = (t and t[i]) or "" end
        return out
    end
    local function emptyCapped(limit)
        local out = {}
        for i = 1, limit do out[i] = "" end
        return out
    end

    RT_BOSS_STATE.tank_count  = preset.tank_count or 3
    RT_BOSS_STATE.tank_marks  = safeMarks(preset.tank_marks)
    RT_BOSS_STATE.tanks       = {"","","",""}

    local lim = RT_BOSS_HEAL_LIMITS
    RT_BOSS_STATE.h_tank1  = emptyCapped(lim.h_tank1)
    RT_BOSS_STATE.h_tank2  = emptyCapped(lim.h_tank2)
    RT_BOSS_STATE.h_tank3  = emptyCapped(lim.h_tank3)
    RT_BOSS_STATE.h_tank4  = emptyCapped(lim.h_tank4)
    RT_BOSS_STATE.h_raid   = emptyCapped(lim.h_raid)
    RT_BOSS_STATE.h_melee  = emptyCapped(lim.h_melee)
    RT_BOSS_STATE.h_caster = emptyCapped(lim.h_caster)

    if preset.h_counts then
        RT_BOSS_STATE.h_counts = {
            h_tank1 = preset.h_counts.h_tank1 or RT_BOSS_HEAL_DEFAULTS.h_tank1,
            h_tank2 = preset.h_counts.h_tank2 or RT_BOSS_HEAL_DEFAULTS.h_tank2,
            h_tank3 = preset.h_counts.h_tank3 or RT_BOSS_HEAL_DEFAULTS.h_tank3,
            h_tank4 = preset.h_counts.h_tank4 or RT_BOSS_HEAL_DEFAULTS.h_tank4,
            h_raid  = preset.h_counts.h_raid  or RT_BOSS_HEAL_DEFAULTS.h_raid,
            h_melee = preset.h_counts.h_melee or RT_BOSS_HEAL_DEFAULTS.h_melee,
            h_caster= preset.h_counts.h_caster or RT_BOSS_HEAL_DEFAULTS.h_caster,
        }
    else
        RT_BOSS_STATE.h_counts = {
            h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1
        }
    end

    RT_BOSS_STATE.note = preset.note or ""
    -- Afficher la note dans l'éditeur
    local noteEdit = getglobal("RT_BossNoteEdit2")
    if noteEdit then noteEdit:SetText(RT_BOSS_STATE.note) end

    RT_BossRefreshSlots()
end

-- Sélection d'un raid
function RT_BossSelectRaid(idx)
    RT_BOSS_STATE.raidIdx  = idx
    RT_BOSS_STATE.bossName = ""
    RT_BossClearUI()
    RT_BossEnsureHealState(RT_BOSS_STATE)
    RT_BossRefreshRaidBtn()
    RT_BossRefreshBossBtn()
    RT_BossDisplay()
    local syncLbl = getglobal("RT_BossStratSyncLbl")
    if syncLbl then syncLbl:SetText("|cff444444sélectionne un boss|r") end
    local p = getglobal("RT_RaidPickerPopup")
    if p then p:Hide() end
end

-- Sélection d'un boss
function RT_BossSelectBoss(bossName)
    RT_BOSS_STATE.bossName = bossName
    RT_BossClearUI()
    RT_BossEnsureHealState(RT_BOSS_STATE)
    RT_BossRefreshBossBtn()
    -- Auto-charger si fiche existante
    RT_BossEnsure()
    if RT_DB.bosses[RT_BossRaidKey()][bossName] then
        RT_BossLoadFromUI()
    elseif RT_BOSS_PRESETS and RT_BOSS_PRESETS[bossName] then
        RT_BossApplyPreset(bossName)
        RT_BossSetStatus2("[Preset] " .. bossName, false)
    else
        RT_BossSetStatus2(RT_Text("boss_new", {boss=bossName}), false)
    end
    -- Sync la note depuis stratNotes (priorité sur boss.note et preset.note)
    RT_BossSyncNoteFromStrat()
    RT_BossDisplay()
    local p = getglobal("RT_BossPickerPopup")
    if p then p:Hide() end
    -- Pas d'auto-announce au changement de boss (manuel seulement via boutons)
end

-- Ajoute un boss custom au raid courant et le sélectionne
function RT_BossAddCustom()
    local edit = getglobal("RT_BossCustomEdit")
    if not edit then return end
    local name = RT_BTrim(edit:GetText() or "")
    if name == "" then return end
    local raid = RT_BossGetRaid()
    if not raid then return end
    local found = false
    local bosses = raid.bosses or {}
    for bIdx = 1, table.getn(bosses) do
        local b = bosses[bIdx]
        if b == name then found = true; break end
    end
    if not found then table.insert(raid.bosses, name) end
    edit:SetText("")
    local p = getglobal("RT_BossAddPopup")
    if p then p:Hide() end
    RT_BossSelectBoss(name)
end

local function RT_BossIsDefault(raidKey, bossName)
    local raidDefaults = RT_DEFAULT_RAID_BOSSES and RT_DEFAULT_RAID_BOSSES[raidKey]
    if not raidDefaults then return false end
    return raidDefaults[bossName] and true or false
end

function RT_BossRemoveCustom()
    if not RT_BOSS_STATE then return end
    local bossName = RT_BOSS_STATE.bossName or ""
    if bossName == "" then
        RT_BossSetStatus2(RT_Text("boss_select_del"), true)
        return
    end

    local raid = RT_BossGetRaid()
    local raidKey = RT_BossRaidKey()
    if not raid then return end

    if RT_BossIsDefault(raidKey, bossName) then
        RT_BossSetStatus2(RT_Text("boss_native_nodelete"), true)
        return
    end

    local removed = false
    for i = table.getn(raid.bosses or {}), 1, -1 do
        if raid.bosses[i] == bossName then
            table.remove(raid.bosses, i)
            removed = true
            break
        end
    end

    RT_BossEnsure()
    if RT_DB.bosses[raidKey] then
        RT_DB.bosses[raidKey][bossName] = nil
    end

    if removed then
        RT_BOSS_STATE.bossName = ""
        RT_BossClearUI()
        RT_BossRefreshBossBtn()
        RT_BossSetStatus2(RT_Text("boss_custom_deleted", {boss=bossName}), false)
        RT_BossDisplay()
    else
        RT_BossSetStatus2(RT_Text("boss_not_found"), true)
    end
end

-- Ouvre le picker joueur pour un slot spécifique
function RT_BossOpenSlotPicker(slotKey, slotIdx, roleFilter)
    RT_PICKER_CALLBACK = function(playerName)
        local s = RT_BOSS_STATE
        if slotKey == "tanks"    then s.tanks[slotIdx]    = playerName
        elseif slotKey == "h_tank1"  then s.h_tank1[slotIdx]  = playerName
        elseif slotKey == "h_tank2"  then s.h_tank2[slotIdx]  = playerName
        elseif slotKey == "h_tank3"  then s.h_tank3[slotIdx]  = playerName
        elseif slotKey == "h_tank4"  then s.h_tank4[slotIdx]  = playerName
        elseif slotKey == "h_raid"   then s.h_raid[slotIdx]   = playerName
        elseif slotKey == "h_melee"  then s.h_melee[slotIdx]  = playerName
        elseif slotKey == "h_caster" then s.h_caster[slotIdx] = playerName
        end
        RT_BossRefreshSlots()
    end
    RT_OpenPlayerPicker(roleFilter or "All")
end

-- Vide un slot
function RT_BossClearSlot(slotKey, slotIdx)
    local s = RT_BOSS_STATE
    if slotKey == "tanks"    then s.tanks[slotIdx]    = ""
    elseif slotKey == "h_tank1"  then s.h_tank1[slotIdx]  = ""
    elseif slotKey == "h_tank2"  then s.h_tank2[slotIdx]  = ""
    elseif slotKey == "h_tank3"  then s.h_tank3[slotIdx]  = ""
    elseif slotKey == "h_tank4"  then s.h_tank4[slotIdx]  = ""
    elseif slotKey == "h_raid"   then s.h_raid[slotIdx]   = ""
    elseif slotKey == "h_melee"  then s.h_melee[slotIdx]  = ""
    elseif slotKey == "h_caster" then s.h_caster[slotIdx] = ""
    end
    RT_BossRefreshSlots()
end

-- Sauvegarde la configuration courante comme session nommée
function RT_BossSaveSession()
    local edit = getglobal("RT_BossSessionEdit")
    if not edit then return end
    local sessName = RT_BTrim(edit:GetText() or "")
    if sessName == "" then
        RT_BossSetStatus2(RT_Text("session_enter_name"), true)
        return
    end
    RT_BossSaveFromUI()
    local raid = RT_BossGetRaid()
    RT_DB.sessions[sessName] = {
        raidKey  = RT_BossRaidKey(),
        raidName = raid and raid.name or "",
        bossName = RT_BOSS_STATE.bossName,
        tanks    = RT_BOSS_STATE.tanks,
        tank_marks = RT_BOSS_STATE.tank_marks,
        tank_count = RT_BOSS_STATE.tank_count,
        h_tank1  = RT_BOSS_STATE.h_tank1,
        h_tank2  = RT_BOSS_STATE.h_tank2,
        h_tank3  = RT_BOSS_STATE.h_tank3,
        h_tank4  = RT_BOSS_STATE.h_tank4,
        h_raid   = RT_BOSS_STATE.h_raid,
        h_melee  = RT_BOSS_STATE.h_melee,
        h_caster = RT_BOSS_STATE.h_caster,
        h_counts = RT_BOSS_STATE.h_counts,
        note     = RT_BOSS_STATE.note,
    }
    RT_BossSetStatus2(RT_Text("session_saved_status", {sess=sessName}), false)
end

-- Charge une session nommée
function RT_BossLoadSession()
    local edit = getglobal("RT_BossSessionEdit")
    if not edit then return end
    local sessName = RT_BTrim(edit:GetText() or "")
    if sessName == "" then
        RT_BossSetStatus2(RT_Text("session_enter_name"), true)
        return
    end
    local sess = RT_DB.sessions and RT_DB.sessions[sessName]
    if not sess then
        RT_BossSetStatus2(RT_Text("session_not_found", {sess=sessName}), true)
        return
    end
    -- Trouver le raidIdx
    local raidIdx = 1
    for rIdx = 1, table.getn(RT_VANILLA_RAIDS) do
        local r = RT_VANILLA_RAIDS[rIdx]
        if r.key == sess.raidKey then raidIdx = rIdx; break end
    end
    local function safe(t, n)
        local out = {}
        for i = 1, n do out[i] = (t and t[i]) or "" end
        return out
    end
    RT_BOSS_STATE = {
        raidIdx  = raidIdx,
        bossName = sess.bossName or "",
        tanks    = safe(sess.tanks,    4),
        tank_marks = safe(sess.tank_marks, 4),
        tank_count = sess.tank_count or 3,
        h_tank1  = safe(sess.h_tank1,  RT_BOSS_HEAL_LIMITS.h_tank1),
        h_tank2  = safe(sess.h_tank2,  RT_BOSS_HEAL_LIMITS.h_tank2),
        h_tank3  = safe(sess.h_tank3,  RT_BOSS_HEAL_LIMITS.h_tank3),
        h_tank4  = safe(sess.h_tank4,  RT_BOSS_HEAL_LIMITS.h_tank4),
        h_raid   = safe(sess.h_raid,   RT_BOSS_HEAL_LIMITS.h_raid),
        h_melee  = safe(sess.h_melee,  RT_BOSS_HEAL_LIMITS.h_melee),
        h_caster = safe(sess.h_caster, RT_BOSS_HEAL_LIMITS.h_caster),
        h_counts = sess.h_counts or {
            h_tank1 = 2, h_tank2 = 2, h_tank3 = 2, h_tank4 = 2,
            h_raid = 3, h_melee = 1, h_caster = 1
        },
        note     = sess.note or "",
    }
    RT_BossRefreshRaidBtn()
    RT_BossRefreshBossBtn()
    RT_BossEnsureHealState(RT_BOSS_STATE)
    RT_BossRefreshSlots()
    RT_BossDisplay()
    RT_BossSetStatus2(RT_Text("session_loaded", {sess=sessName}), false)
end

-- Affiche les fiches du raid courant dans le log
function RT_BossDisplay(focusBoss)
    local frame = getglobal("RT_BossLog2")
    if not frame then return end
    RT_BossEnsure()
    frame:Clear()

    local function addBossLogLine(text)
        local line = RT_BTrim(text or "")
        if line == "" then
            frame:AddMessage(" ")
            return
        end
        local maxLen = 112
        while string.len(line) > maxLen do
            local cut = maxLen
            while cut > 40 and string.sub(line, cut, cut) ~= " " do
                cut = cut - 1
            end
            if cut <= 40 then cut = maxLen end
            frame:AddMessage(string.sub(line, 1, cut))
            line = RT_BTrim(string.sub(line, cut + 1))
        end
        if line ~= "" then
            frame:AddMessage(line)
        end
    end

    local raid    = RT_BossGetRaid()
    local raidKey = RT_BossRaidKey()
    addBossLogLine(RT_ColorTitle("=== " .. (raid and raid.name or raidKey) .. " — Fiches ==="))
    addBossLogLine(" ")
    local bossDB = RT_DB.bosses[raidKey] or {}
    local list   = {}
    for boss, data in pairs(bossDB) do
        table.insert(list, { name = boss, data = data })
    end
    if table.getn(list) == 0 then
        addBossLogLine("|cff888888Aucune fiche enregistree pour ce raid.|r")
        addBossLogLine("|cff888888Selectionne Raid > Boss > assigne > Sauver.|r")
        return
    end
    table.sort(list, function(a, b)
        if focusBoss and a.name == focusBoss and b.name ~= focusBoss then return true end
        if focusBoss and b.name == focusBoss and a.name ~= focusBoss then return false end
        return a.name < b.name
    end)
    for eIdx = 1, table.getn(list) do
        local entry = list[eIdx]
        local d = entry.data or {}
        local title = RT_ColorTitle(entry.name)
        if focusBoss and entry.name == focusBoss then
            title = "|cffFFD200> |r" .. title
        end
        addBossLogLine(title)
        -- Tanks
        local tParts = {}
        local tanks = d.tanks or {}
        for tIdx = 1, table.getn(tanks) do
            local t = tanks[tIdx]
            if t ~= "" then
                local cl = RT_DB.roster and RT_DB.roster[t] and RT_DB.roster[t].class or "?"
                local marker = (d.tank_marks and d.tank_marks[tIdx]) or ""
                local text = RT_ColorClass(t, cl)
                if marker ~= "" then
                    text = "|cffFFD200[" .. marker .. "]|r " .. text
                end
                table.insert(tParts, text)
            end
        end
        if table.getn(tParts) > 0 then
            addBossLogLine("  " .. RT_ColorRole("Tank") .. " " .. table.concat(tParts, " | "))
        end
        -- Heals
        local hParts = {}
        local h_tank1 = d.h_tank1 or {}
        for hIdx1 = 1, table.getn(h_tank1) do
            local h = h_tank1[hIdx1]
            if h~="" then table.insert(hParts, "|cff88FFAAHealT1|r:"..h) end
        end
        local h_tank2 = d.h_tank2 or {}
        for hIdx2 = 1, table.getn(h_tank2) do
            local h = h_tank2[hIdx2]
            if h~="" then table.insert(hParts, "|cff88FFAAHealT2|r:"..h) end
        end
        local h_tank3 = d.h_tank3 or {}
        for hIdx3 = 1, table.getn(h_tank3) do
            local h = h_tank3[hIdx3]
            if h~="" then table.insert(hParts, "|cff88FFAAHealT3|r:"..h) end
        end
        local h_tank4 = d.h_tank4 or {}
        for hIdx4 = 1, table.getn(h_tank4) do
            local h = h_tank4[hIdx4]
            if h~="" then table.insert(hParts, "|cff88FFAAHealT4|r:"..h) end
        end
        local h_raid = d.h_raid or {}
        for hIdxRaid = 1, table.getn(h_raid) do
            local h = h_raid[hIdxRaid]
            if h~="" then table.insert(hParts, "|cff88FFAAHealR|r:"..h) end
        end
        local h_melee = d.h_melee or {}
        for hIdxMelee = 1, table.getn(h_melee) do
            local h = h_melee[hIdxMelee]
            if h~="" then table.insert(hParts, "|cff88FFAAHealM|r:"..h) end
        end
        local h_caster = d.h_caster or {}
        for hIdxCaster = 1, table.getn(h_caster) do
            local h = h_caster[hIdxCaster]
            if h~="" then table.insert(hParts, "|cff88FFAAHealC|r:"..h) end
        end
        if table.getn(hParts) > 0 then
            addBossLogLine("  " .. table.concat(hParts, "  "))
        end
        if d.note and d.note ~= "" then
            addBossLogLine("  |cffCCCCCC" .. d.note .. "|r")
        end
        addBossLogLine(" ")
    end
end

local RT_AnnouncementLang
local RT_RefreshLocalizedStaticUI
local RT_RLQuickEnsureSettings  -- forward declaration, défini plus bas

local function RT_UpdateBossOptionsUI()
    local langBtn = getglobal("RT_BossLangBtn")
    local autoBtn = getglobal("RT_BossAutoBtn")
    if langBtn then
        local prefix = "Lang"
        if RT_Text then
            prefix = RT_Text("ui_lang_prefix")
        end
        local langStr = prefix .. ":" .. string.upper(RT_AnnouncementLang())
        langBtn:SetText(langStr)
        langBtn:Show()
        -- Mettre à jour aussi le bouton du popup logo
        local popupLang = getglobal("RT_PopupLangBtn")
        if popupLang then popupLang:SetText(langStr) end
    end
    if autoBtn then
        RT_DB = RT_DB or {}
        RT_DB.settings = RT_DB.settings or {}
        local auto = RT_DB.settings.raidAutoAnnounce and "ON" or "OFF"
        autoBtn:SetText("Auto:" .. auto)
    end
end

function RT_CycleAnnouncementLang()
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    local cur = RT_AnnouncementLang()
    local nextLang = "fr"
    if cur == "fr" then nextLang = "en"
    else nextLang = "fr" end
    RT_DB.settings.announceLang = nextLang
    if RT_RefreshLocalizedStaticUI then RT_RefreshLocalizedStaticUI() end
    RT_UpdateBossOptionsUI()
    if RT_CURRENT_TAB == "Buffs" and RT_BuffDisplay then RT_BuffDisplay() end
    if RT_CURRENT_TAB == "Boss" and RT_BossDisplay then RT_BossDisplay() end
    if RT_Text then
        RT_Print(RT_Text("ui_lang_changed", { lang = string.upper(nextLang) }))
    else
        RT_Print("Langue annonces: " .. RT_ColorGold(nextLang))
    end
end

function RT_ToggleBossAutoAnnounce()
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    RT_DB.settings.raidAutoAnnounce = not not (not RT_DB.settings.raidAutoAnnounce)
    RT_DB.settings.raidAutoAnnounce = not RT_DB.settings.raidAutoAnnounce
    RT_UpdateBossOptionsUI()
    RT_Print("Annonce boss auto: " .. RT_ColorGold(RT_DB.settings.raidAutoAnnounce and "ON" or "OFF"))
end

local RT_BossResolveContext  -- forward-declare (défini plus bas)

local function RT_BossMaybeAutoAnnounce()
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    if not RT_DB.settings.raidAutoAnnounce then return end

    local ctx = RT_BossResolveContext()
    if ctx.kind ~= "boss" or not ctx.bossName or not ctx.bossData then return end

    -- Ne jamais auto-annoncer la fiche "Trash Mob"
    local trashLabel = RT_Text and RT_Text("trash_mob") or "Trash Mob"
    if ctx.bossName == trashLabel or string.lower(ctx.bossName) == "trash mob" then return end

    local now = GetTime and GetTime() or 0
    if RT_AUTO_LAST_BOSS == ctx.bossName and (now - (RT_AUTO_LAST_TIME or 0)) < 8 then
        return
    end

    RT_AUTO_LAST_BOSS = ctx.bossName
    RT_AUTO_LAST_TIME = now
    RT_RLQuickEnsureSettings()
    if RT_DB.settings.rlQuickAuto and RT_RLQuickPack then
        RT_RLQuickPack(true)
    else
        RT_RaidAnnounceCommand("all")
    end
end

local function RT_NameKey(name)
    local n = RT_BTrim(name or "")
    n = string.gsub(n, "%-.*$", "")
    return string.lower(n)
end

local function RT_BossFindByNameInRaid(raidKey, bossName)
    local clean = RT_NameKey(bossName)
    if clean == "" then return nil, nil end
    local raidDB = RT_DB and RT_DB.bosses and RT_DB.bosses[raidKey]
    if not raidDB then return nil, nil end

    for savedBoss, data in pairs(raidDB) do
        if RT_NameKey(savedBoss) == clean then
            return savedBoss, data
        end
    end

    for savedBoss, data in pairs(raidDB) do
        local key = RT_NameKey(savedBoss)
        if string.find(key, clean, 1, true) or string.find(clean, key, 1, true) then
            return savedBoss, data
        end
    end

    return nil, nil
end

RT_BossResolveContext = function()
    RT_BossEnsure()

    local context = {
        kind = "none",
        targetName = "",
        raidKey = RT_BossRaidKey(),
        bossName = nil,
        bossData = nil,
        source = "",
    }

    if UnitExists and UnitExists("target") then
        local targetName = UnitName("target") or ""
        context.targetName = targetName

        if UnitIsPlayer and UnitIsPlayer("target") then
            context.kind = "player"
        elseif UnitCanAttack and UnitCanAttack("player", "target") then
            context.kind = "boss"
            local byTarget, byTargetData = RT_BossFindByNameInRaid(context.raidKey, targetName)
            if byTarget then
                context.bossName = byTarget
                context.bossData = byTargetData
                context.source = "target"
                return context
            end

            for raidIdx2 = 1, table.getn(RT_VANILLA_RAIDS or {}) do
                local raid = (RT_VANILLA_RAIDS or {})[raidIdx2]
                local bossName, bossData = RT_BossFindByNameInRaid(raid.key, targetName)
                if bossName then
                    context.raidKey = raid.key
                    context.bossName = bossName
                    context.bossData = bossData
                    context.source = "target"
                    return context
                end
            end
            -- Cible ennemie inconnue = trash, on ne remonte pas la fiche UI sélectionnée
            return context
        else
            context.kind = "other"
        end
    end

    local selected = RT_BOSS_STATE and RT_BOSS_STATE.bossName or ""
    if selected ~= "" then
        if RT_BOSS_STATE and RT_BOSS_STATE.bossName == selected then
            context.bossName = selected
            context.bossData = {
                tanks = RT_BOSS_STATE.tanks,
                tank_marks = RT_BOSS_STATE.tank_marks,
                tank_count = RT_BOSS_STATE.tank_count,
                h_tank1 = RT_BOSS_STATE.h_tank1,
                h_tank2 = RT_BOSS_STATE.h_tank2,
                h_tank3 = RT_BOSS_STATE.h_tank3,
                h_tank4 = RT_BOSS_STATE.h_tank4,
                h_raid = RT_BOSS_STATE.h_raid,
                h_melee = RT_BOSS_STATE.h_melee,
                h_caster = RT_BOSS_STATE.h_caster,
                h_counts = RT_BOSS_STATE.h_counts,
                note = RT_BOSS_STATE.note,
            }
            context.source = "ui"
            return context
        end
        if RT_DB.bosses[context.raidKey] and RT_DB.bosses[context.raidKey][selected] then
            context.bossName = selected
            context.bossData = RT_DB.bosses[context.raidKey][selected]
            context.source = "selected"
            return context
        end
    end

    for savedBoss, data in pairs(RT_DB.bosses[context.raidKey] or {}) do
        context.bossName = savedBoss
        context.bossData = data
        context.source = "saved"
        return context
    end

    return context
end

local function RT_BossCollectAssignments(bossData)
    local perPlayer = {}
    local order = {}

    local function add(playerName, label)
        local name = RT_BTrim(playerName or "")
        if name == "" then return end

        local key = RT_NameKey(name)
        if not perPlayer[key] then
            perPlayer[key] = { name = name, labels = {} }
            table.insert(order, key)
        end
        table.insert(perPlayer[key].labels, label)
    end

    local tankCount = (bossData and bossData.tank_count) or 4
    if tankCount < 1 then tankCount = 1 end
    if tankCount > 4 then tankCount = 4 end
    for i = 1, tankCount do
        local tank = bossData and bossData.tanks and bossData.tanks[i] or ""
        local mark = bossData and bossData.tank_marks and bossData.tank_marks[i] or ""
        local tankLabel = "Tank " .. i
        if mark and mark ~= "" then tankLabel = tankLabel .. " [" .. mark .. "]" end
        add(tank, tankLabel)
    end

    local healSlots = {
        { key = "h_tank1", label = "Heal Tank1" },
        { key = "h_tank2", label = "Heal Tank2" },
        { key = "h_tank3", label = "Heal Tank3" },
        { key = "h_tank4", label = "Heal Tank4" },
        { key = "h_raid",  label = "Heal Raid" },
        { key = "h_melee", label = "Heal Melee" },
        { key = "h_caster",label = "Heal Caster" },
    }

    for sIdx = 1, table.getn(healSlots) do
        local slot = healSlots[sIdx]
        local arr = bossData and bossData[slot.key] or nil
        if arr then
            for i = 1, table.getn(arr) do
                add(arr[i], slot.label)
            end
        end
    end

    return perPlayer, order
end

local function RT_BossBuildPlayerAttribution(playerName, bossName, bossData)
    local perPlayer = RT_BossCollectAssignments(bossData)
    local mine = perPlayer[RT_NameKey(playerName or "")]
    if not mine or table.getn(mine.labels or {}) == 0 then
        return RT_Text("attrib_none", {
            player = playerName or "?",
            boss = bossName or "?",
        })
    end
    return RT_Text("attrib_line", {
        player = mine.name,
        boss = bossName,
        jobs = table.concat(mine.labels, " + "),
    })
end

local RT_BuffScanTip = nil
-- (RT_Text déjà déclaré plus haut comme forward-declare)
local RT_AUTO_LAST_BOSS = ""
local RT_AUTO_LAST_TIME = 0

local function RT_BuffGetTooltipName(unit, idx)
    if not unit or unit == "" then return "" end
    if not idx then return "" end

    if not RT_BuffScanTip and CreateFrame then
        RT_BuffScanTip = CreateFrame("GameTooltip", "RT_BuffScanTip", UIParent, "GameTooltipTemplate")
        if RT_BuffScanTip and RT_BuffScanTip.SetOwner then
            RT_BuffScanTip:SetOwner(UIParent, "ANCHOR_NONE")
        end
    end
    if not RT_BuffScanTip then return "" end

    RT_BuffScanTip:ClearLines()
    if RT_BuffScanTip.SetUnitBuff then
        RT_BuffScanTip:SetUnitBuff(unit, idx)
    else
        return ""
    end

    local left = getglobal("RT_BuffScanTipTextLeft1")
    return (left and left.GetText and left:GetText()) or ""
end

local RT_IMPORTANT_BUFF_GROUPS = {
    { label = "Fortitude", names = {
        "power word: fortitude", "prayer of fortitude",
        "mot de pouvoir : robustesse", "priere de robustesse"
    } },
    { label = "Intellect", names = {
        "arcane intellect", "arcane brilliance",
        "intelligence des arcanes", "brillance des arcanes"
    } },
    { label = "Mark", names = {
        "mark of the wild", "gift of the wild",
        "marque du fauve", "don du fauve"
    } },
}

local RT_WARLOCK_CURSE_SPECS = {
    elements = { "affliction", "affli", "drain", "ua", "unstable" },
    shadow   = { "destruction", "destro", "ruin", "shadow", "ombre", "smruin" },
    reck     = { "demonology", "demo", "demono", "sacrifice", "tank" },
}

local function RT_BuffActiveGroupList()
    local groups = {}
    local planGroups = RT_DB and RT_DB.groupPlanner and RT_DB.groupPlanner.plan and RT_DB.groupPlanner.plan.groups
    if planGroups then
        for groupIdx = 1, 8 do
            local group = planGroups[groupIdx] or {}
            for slotIdx = 1, 5 do
                if RT_BTrim(group[slotIdx] or "") ~= "" then
                    table.insert(groups, groupIdx)
                    break
                end
            end
        end
    end
    if table.getn(groups) == 0 then
        local groupCount = math.ceil((RT_CountPlayers() or 0) / 5)
        if groupCount < 1 then groupCount = 1 end
        if groupCount > 8 then groupCount = 8 end
        for groupIdx = 1, groupCount do
            table.insert(groups, groupIdx)
        end
    end
    return groups
end

local function RT_BuffFormatGroups(groups)
    if not groups or table.getn(groups) == 0 then return RT_Text("none") end
    local parts = {}
    for idx = 1, table.getn(groups) do
        table.insert(parts, "G" .. groups[idx])
    end
    return table.concat(parts, ", ")
end

local RT_NormalizeClassName

local function RT_BuffListClassPlayers(className)
    local roster = RT_DB and RT_DB.roster or {}
    local out = {}
    local seen = {}

    for name, data in pairs(roster) do
        if RT_NormalizeClassName((data and data.class) or "") == className then
            local k = string.lower(name or "")
            if k ~= "" and not seen[k] then
                seen[k] = true
                table.insert(out, name)
            end
        end
    end

    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if nRaid > 0 then
        for i = 1, nRaid do
            local name, _, _, _, _, class = GetRaidRosterInfo(i)
            local cls = RT_NormalizeClassName(class or "")
            if name and cls == className then
                local k = string.lower(name)
                if not seen[k] then
                    seen[k] = true
                    table.insert(out, name)
                end
            end
        end
    else
        local me = UnitName and UnitName("player") or nil
        if me and UnitClass then
            local c1, c2 = UnitClass("player")
            local cls = RT_NormalizeClassName(c2 or c1 or "")
            if cls == className then
                local k = string.lower(me)
                if not seen[k] then
                    seen[k] = true
                    table.insert(out, me)
                end
            end
        end
        local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
        for i = 1, nParty do
            local u = "party" .. i
            local name = UnitName and UnitName(u) or nil
            local cls = ""
            if UnitClass then
                local c1, c2 = UnitClass(u)
                cls = RT_NormalizeClassName(c2 or c1 or "")
            end
            if name and cls == className then
                local k = string.lower(name)
                if not seen[k] then
                    seen[k] = true
                    table.insert(out, name)
                end
            end
        end
    end

    table.sort(out)
    return out
end

local function RT_BuffBuildGroupAssignments(className)
    local names = RT_BuffListClassPlayers(className)
    local activeGroups = RT_BuffActiveGroupList()
    local assignments = {}

    local nameCount = table.getn(names)
    local groupCount = table.getn(activeGroups)
    if nameCount == 0 or groupCount == 0 then return assignments end

    if nameCount >= groupCount then
        for idx = 1, nameCount do
            assignments[idx] = { name = names[idx], groups = {} }
            if idx <= groupCount then
                table.insert(assignments[idx].groups, activeGroups[idx])
            end
        end
        return assignments
    end

    for idx = 1, nameCount do
        local startIdx = math.floor((idx - 1) * groupCount / nameCount) + 1
        local endIdx = math.floor(idx * groupCount / nameCount)
        if endIdx < startIdx then endIdx = startIdx end
        assignments[idx] = { name = names[idx], groups = {} }
        for groupPos = startIdx, endIdx do
            table.insert(assignments[idx].groups, activeGroups[groupPos])
        end
    end
    return assignments
end

local function RT_BuffDetectWarlockCurse(spec)
    local lowerSpec = string.lower(RT_BTrim(spec or ""))
    local order = { "elements", "shadow", "reck" }
    for orderIdx = 1, table.getn(order) do
        local key = order[orderIdx]
        local patterns = RT_WARLOCK_CURSE_SPECS[key] or {}
        for patIdx = 1, table.getn(patterns) do
            if string.find(lowerSpec, patterns[patIdx], 1, true) then
                return key
            end
        end
    end
    return nil
end

local function RT_BuffCurseText(key)
    if key == "elements" then return RT_Text("curse_elements") end
    if key == "shadow" then return RT_Text("curse_shadow") end
    if key == "reck" then return RT_Text("curse_reck") end
    return RT_Text("curse_flex")
end

local function RT_BuffEnsureCurseSettings()
    RT_DB = RT_DB or {}
    RT_DB.buffs = RT_DB.buffs or {}
    if RT_DB.buffs.curseAuto == nil then RT_DB.buffs.curseAuto = true end
    RT_DB.buffs.manualCurses = RT_DB.buffs.manualCurses or {}
    RT_DB.buffs.manualPick = RT_DB.buffs.manualPick or { demo = "", male = "" }
end

local function RT_BuffListWarlocks()
    return RT_BuffListClassPlayers("Warlock")
end

function RT_BuffToggleCurseMode()
    RT_BuffEnsureCurseSettings()
    RT_DB.buffs.curseAuto = not RT_DB.buffs.curseAuto
    local b = getglobal("RT_BuffCurseModeBtn")
    if b then
        if RT_DB.buffs.curseAuto then b:SetText(RT_Text("buff_curse_mode_auto"))
        else b:SetText(RT_Text("buff_curse_mode_man")) end
    end
    RT_BuffDisplay()
end

function RT_BuffSetManualCurse(kind)
    RT_BuffEnsureCurseSettings()
    local locks = RT_BuffListWarlocks()
    if table.getn(locks) == 0 then
        RT_Print(RT_ColorErr(RT_Text("buff_none_warlock")))
        return
    end

    local key = (kind == "demo") and "demo" or "male"
    local cur = RT_DB.buffs.manualPick[key] or ""
    local idx = 0
    for i = 1, table.getn(locks) do
        if locks[i] == cur then idx = i break end
    end
    idx = idx + 1
    if idx > table.getn(locks) then idx = 1 end
    local selected = locks[idx]
    RT_DB.buffs.manualPick[key] = selected

    if key == "demo" then
        RT_DB.buffs.manualCurses[selected] = "reck"
        RT_Print(RT_ColorOK(RT_Text("buff_demo_set", {name = selected})))
    else
        RT_DB.buffs.manualCurses[selected] = "elements"
        RT_Print(RT_ColorOK(RT_Text("buff_male_set", {name = selected})))
    end
    RT_BuffDisplay()
end

local function RT_BuffBuildWarlockAssignments()
    local roster = RT_DB and RT_DB.roster or {}
    local locks = {}
    local assigned = {}
    local output = {}
    local core = { "elements", "shadow", "reck" }

    RT_BuffEnsureCurseSettings()

    local warlockNames = RT_BuffListWarlocks()
    for i = 1, table.getn(warlockNames) do
        local name = warlockNames[i]
        local data = roster[name] or {}
        table.insert(locks, {
            name = name,
            spec = data.spec or "",
            preferred = RT_BuffDetectWarlockCurse(data.spec),
        })
    end

    table.sort(locks, function(a, b)
        local ap = a.preferred and 0 or 1
        local bp = b.preferred and 0 or 1
        if ap ~= bp then return ap < bp end
        return string.lower(a.name) < string.lower(b.name)
    end)

    for lockIdx = 1, table.getn(locks) do
        local row = locks[lockIdx]
        if row.preferred and not assigned[row.preferred] then
            assigned[row.preferred] = row.name
            table.insert(output, { name = row.name, spec = row.spec, curse = row.preferred })
        end
    end

    for coreIdx = 1, table.getn(core) do
        local curseKey = core[coreIdx]
        if not assigned[curseKey] then
            for lockIdx = 1, table.getn(locks) do
                local row = locks[lockIdx]
                local used = false
                for outIdx = 1, table.getn(output) do
                    if output[outIdx].name == row.name then
                        used = true
                        break
                    end
                end
                if not used then
                    assigned[curseKey] = row.name
                    table.insert(output, { name = row.name, spec = row.spec, curse = curseKey })
                    break
                end
            end
        end
    end

    for lockIdx = 1, table.getn(locks) do
        local row = locks[lockIdx]
        local used = false
        for outIdx = 1, table.getn(output) do
            if output[outIdx].name == row.name then
                used = true
                break
            end
        end
        if not used then
            table.insert(output, { name = row.name, spec = row.spec, curse = "flex" })
        end
    end

    -- Mode manuel: override par joueur
    if not RT_DB.buffs.curseAuto then
        for outIdx = 1, table.getn(output) do
            local nm = output[outIdx].name
            local forced = RT_DB.buffs.manualCurses[nm]
            if forced and forced ~= "" then
                output[outIdx].curse = forced
            end
        end
    end

    return output
end

local function RT_BuffCurseCycle(current, dir)
    local order = { "elements", "shadow", "reck", "flex" }
    local idx = 1
    for i = 1, table.getn(order) do
        if order[i] == current then idx = i break end
    end
    idx = idx + (dir or 1)
    if idx < 1 then idx = table.getn(order) end
    if idx > table.getn(order) then idx = 1 end
    return order[idx]
end

local function RT_BuffRefreshWarlockControlUI()
    RT_BuffEnsureCurseSettings()
    local lbl = getglobal("RT_BuffWarlockPickLbl")
    local locks = RT_BuffListWarlocks()
    if not lbl then return end
    if table.getn(locks) == 0 then
        lbl:SetText("|cff888888" .. RT_Text("buff_none_warlock") .. "|r")
        return
    end

    local sel = RT_DB.buffs.manualPick.target or ""
    local found = false
    for i = 1, table.getn(locks) do
        if locks[i] == sel then found = true break end
    end
    if not found then
        sel = locks[1]
        RT_DB.buffs.manualPick.target = sel
    end

    local curse = RT_DB.buffs.manualCurses[sel] or "flex"
    lbl:SetText(RT_ColorClass(sel, "Warlock") .. " |cffFFFFFF=>|r " .. RT_ColorGold(RT_BuffCurseText(curse)))
end

function RT_BuffCycleWarlockTarget(step)
    RT_BuffEnsureCurseSettings()
    local locks = RT_BuffListWarlocks()
    if table.getn(locks) == 0 then
        RT_BuffRefreshWarlockControlUI()
        return
    end
    local cur = RT_DB.buffs.manualPick.target or ""
    local idx = 1
    for i = 1, table.getn(locks) do
        if locks[i] == cur then idx = i break end
    end
    idx = idx + (step or 1)
    if idx < 1 then idx = table.getn(locks) end
    if idx > table.getn(locks) then idx = 1 end
    RT_DB.buffs.manualPick.target = locks[idx]
    RT_BuffRefreshWarlockControlUI()
end

function RT_BuffCycleWarlockCurse(step)
    RT_BuffEnsureCurseSettings()
    local locks = RT_BuffListWarlocks()
    if table.getn(locks) == 0 then
        RT_BuffRefreshWarlockControlUI()
        return
    end
    local target = RT_DB.buffs.manualPick.target or locks[1]
    local valid = false
    for i = 1, table.getn(locks) do
        if locks[i] == target then valid = true break end
    end
    if not valid then target = locks[1] end

    local cur = RT_DB.buffs.manualCurses[target] or "flex"
    RT_DB.buffs.manualPick.target = target
    RT_DB.buffs.manualCurses[target] = RT_BuffCurseCycle(cur, step or 1)
    RT_BuffRefreshWarlockControlUI()
    RT_BuffDisplay()
end

local function RT_UnitHasAnyBuff(unit, buffNames)
    if not UnitExists or not UnitExists(unit) then return false end
    for i = 1, 32 do
        local texture = UnitBuff and UnitBuff(unit, i)
        if not texture then break end
        local bname = string.lower(RT_BuffGetTooltipName(unit, i) or "")
        if bname ~= "" then
            for bIdx = 1, table.getn(buffNames) do
                local expected = buffNames[bIdx]
                if string.find(bname, expected, 1, true) then return true end
            end
        end
    end
    return false
end

local function RT_FindRaidUnitByPlayerName(playerName)
    local targetKey = RT_NameKey(playerName)
    if targetKey == "" then return nil end

    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    for i = 1, n do
        local unit = "raid" .. i
        if RT_NameKey(UnitName(unit) or "") == targetKey then
            return unit
        end
    end

    if RT_NameKey(UnitName("player") or "") == targetKey then
        return "player"
    end
    return nil
end

-- Vérifie si les joueurs des groupes assignés ont le buff de la classe donnée
-- Retourne: "ok", "missing", "partial", "?" (inconnu)
local function RT_BuffCheckGroupStatus(className, groupList)
    if not GetNumRaidMembers or GetNumRaidMembers() == 0 then return "?" end
    if not groupList or table.getn(groupList) == 0 then return "?" end

    local classToLabel = { Priest="Fortitude", Mage="Intellect", Druid="Mark" }
    local targetLabel = classToLabel[className]
    if not targetLabel then return "?" end

    local buffNames = nil
    for bgIdx = 1, table.getn(RT_IMPORTANT_BUFF_GROUPS) do
        local bg = RT_IMPORTANT_BUFF_GROUPS[bgIdx]
        if bg.label == targetLabel then buffNames = bg.names; break end
    end
    if not buffNames then return "?" end

    local planGroups = RT_DB and RT_DB.groupPlanner and RT_DB.groupPlanner.plan and RT_DB.groupPlanner.plan.groups
    if not planGroups then return "?" end

    local checked = 0
    local buffed  = 0
    for glIdx = 1, table.getn(groupList) do
        local g = groupList[glIdx]
        local grp = planGroups[g] or {}
        for slot = 1, 5 do
            local pName = RT_BTrim(grp[slot] or "")
            if pName ~= "" then
                local unit = RT_FindRaidUnitByPlayerName(pName)
                if unit and UnitExists and UnitExists(unit) then
                    checked = checked + 1
                    if RT_UnitHasAnyBuff(unit, buffNames) then
                        buffed = buffed + 1
                    end
                end
            end
        end
    end

    if checked == 0 then return "?" end
    if buffed == checked then return "ok" end
    if buffed == 0 then return "missing" end
    return "partial"
end

local function RT_BuffAppendAssignmentLines(lines)
    local classes = {
        { key = "Priest", label = RT_Text("class_priests") },
        { key = "Mage", label = RT_Text("class_mages") },
        { key = "Druid", label = RT_Text("class_druids") },
    }

    for classIdx = 1, table.getn(classes) do
        local classInfo = classes[classIdx]
        local assignments = RT_BuffBuildGroupAssignments(classInfo.key)
        if table.getn(assignments) > 0 then
            local parts = {}
            for rowIdx = 1, table.getn(assignments) do
                local row = assignments[rowIdx]
                table.insert(parts, row.name .. "->" .. RT_BuffFormatGroups(row.groups))
            end
            table.insert(lines, "[RT] " .. classInfo.label .. ": " .. table.concat(parts, " | "))
        end
    end

    local warlocks = RT_BuffBuildWarlockAssignments()
    if table.getn(warlocks) > 0 then
        local parts = {}
        for rowIdx = 1, table.getn(warlocks) do
            local row = warlocks[rowIdx]
            table.insert(parts, row.name .. "->" .. RT_BuffCurseText(row.curse))
        end
        table.insert(lines, "[RT] " .. RT_Text("class_warlocks") .. ": " .. table.concat(parts, " | "))
    end
end

local function RT_LocalizedBuffLabel(label)
    if label == "Fortitude" then return RT_Text("buff_fort") end
    if label == "Intellect" then return RT_Text("buff_int") end
    if label == "Mark" then return RT_Text("buff_mark") end
    return label
end

local function RT_BossCollectMissingImportantBuffs(bossData)
    local perPlayer, order = RT_BossCollectAssignments(bossData)
    local lines = {}

    for oIdx = 1, table.getn(order) do
        local key = order[oIdx]
        local row = perPlayer[key]
        if row and row.name and row.name ~= "" then
            local unit = RT_FindRaidUnitByPlayerName(row.name)
            if unit and (not UnitIsDeadOrGhost or not UnitIsDeadOrGhost(unit)) then
                local missing = {}
                local buffGroups = RT_IMPORTANT_BUFF_GROUPS or {}
                for bgIdx = 1, table.getn(buffGroups) do
                    local group = buffGroups[bgIdx]
                    if not RT_UnitHasAnyBuff(unit, group.names) then
                        table.insert(missing, RT_LocalizedBuffLabel(group.label))
                    end
                end
                if table.getn(missing) > 0 then
                    table.insert(lines, RT_Text("missing_line", {
                        player = row.name,
                        buffs = table.concat(missing, ", "),
                    }))
                end
            end
        end
    end
    return lines
end

local RT_I18N = {
    fr = {
        raid_header = "[RT] Boss {boss} - attributions",
        tanks = "Tanks",
        none = "aucun",
        heals_tank = "Heals Tank{index}",
        heals_raid = "Heals Raid",
        heals_melee = "Heals Melee",
        heals_caster = "Heals Caster",
        note = "Note",
        missing_buffs = "Buffs importants manquants:",
        buffs_ok = "Buffs importants: OK (joueurs assignes)",
        missing_line = "{player} manque: {buffs}",
        no_boss = "Aucune fiche boss a annoncer. Cible un boss ou charge une fiche.",
        no_boss_attrib = "Aucun boss trouve. Cible un boss ou selectionne une fiche Boss.",
        attrib_none = "Aucune attribution pour {player} sur {boss}.",
        attrib_line = "Attrib {player} sur {boss}: {jobs}",
        context = "Contexte: {kind}{target} | boss: {boss}{source}",
        kind_boss = "boss",
        kind_player = "joueur",
        kind_other = "autre",
        target = " | cible: {target}",
        source = " ({source})",
        sent = "Annonce raid envoyee pour {boss}.",
        buff_fort = "Robustesse",
        buff_int = "Intelligence",
        buff_mark = "Marque",
        class_priests = "Pretres",
        class_mages = "Mages",
        class_druids = "Druides",
        class_warlocks = "Demonistes",
        curse_elements = "Male des elements",
        curse_shadow = "Male de l'ombre",
        curse_reck = "Male de temerite",
        curse_flex = "Male flexible",
        buff_header     = "=== Rotation Buffs ({total} joueurs) ===",
        buff_none_roster= "Roster vide — importe d'abord un CSV.",
        buff_none_class = "Aucun {label} dans le raid.",
        buff_groups_arrow= "→  groupes {groups}",
        buff_summary_lbl = "Resume:",
        buff_curse_badge_auto = "Mode Maledictions: AUTO",
        buff_curse_badge_man  = "Mode Maledictions: MANUEL",
        buff_warlock_cols = "Nom               Talent               Malediction",
        trash_mob       = "Trash Mob",
        ui_lang_prefix  = "Lang",
        ui_lang_changed = "Langue interface/annonces: |cffFFD700{lang}|r",
        ui_boss_sheet_title = "☠ Feuille de Boss",
        ui_buffs_title = "✦ Rotation Buffs — Pretre / Mage / Druide / Demoniste",
        -- Boss status
        boss_select_first    = "Sélectionnez un boss.",
        boss_no_sheet        = "Aucune fiche pour {boss}",
        boss_loaded          = "Chargé: {boss}",
        boss_saved_status    = "Sauvegardé: {boss}",
        boss_saved_print     = "BossSheet: {boss} sauvegardé.",
        boss_slots_cleared   = "Slots effacés.",
        boss_new             = "Nouveau boss: {boss}",
        boss_select_del      = "Sélectionnez un boss à supprimer.",
        boss_native_nodelete = "Boss natif: suppression interdite.",
        boss_custom_deleted  = "Boss custom supprimé: {boss}",
        boss_not_found       = "Boss introuvable dans la liste du raid.",
        -- Session
        session_enter_name   = "Entrez un nom de session.",
        session_saved_status = "Session sauvée: {sess}",
        session_saved_print  = "Session sauvée: {sess}",
        session_not_found    = "Session introuvable: {sess}",
        session_loaded       = "Session chargée: {sess}",
        -- Picker/popup
        picker_select_tank   = "Sélectionner Tank",
        picker_select_heal   = "Sélectionner Heal",
        picker_select_player = "Sélectionner joueur",
        picker_cancel        = "Annuler",
        picker_close         = "Fermer",
        picker_select_raid   = "Sélectionner raid",
        picker_select_boss   = "Sélectionner boss",
        boss_custom_name_lbl = "Nom du boss custom :",
        marker_none          = "Aucun",
        -- Boss panel buttons
        btn_save             = "Sauver",
        btn_clear_slots      = "Vider slots",
        btn_save_sess        = "Sauver sess.",
        btn_load_sess        = "Charger sess.",
        btn_announce_label   = "Annoncer:",
        -- Roster / Groups panel
        roster_header        = "⚔ Composition du raid",
        groups_title         = "⚡ Pré-groupement raid (optimisation câc / caster)",
        groups_hint          = "1) Actualiser Raid 2) Adapter Groupes 3) Inviter 4) placement auto",
        btn_gen_auto         = "Générer auto",
        btn_adapter_groupes  = "Adapter Groupes",
        btn_refresh_raid     = "Actualiser Raid",
        raid_refreshed       = "Raid actualisé : {n} joueur(s) chargé(s).",
        raid_refresh_empty   = "Aucun raid actif détecté.",
        notes_loaded         = "◈ {key}",
        notes_new_key        = "◈ {key} (nouveau)",
        btn_invite_plan      = "Inviter plan",
        btn_apply_groups     = "Appliquer groupes",
        group_label          = "Groupe {n}",
        slot_group_lbl       = "Slot Groupe",
        btn_clear_slot       = "Vider",
        player_lbl           = "Joueur:",
        pick_player_btn      = "Choisir joueur",
        role_current_none    = "Role actuel: -",
        role_current         = "Role actuel: {role}",
        -- Group status messages
        need_leader_invite   = "Tu dois être leader/assistant pour inviter.",
        no_planned_players   = "Aucun joueur planifié à inviter.",
        invs_sent            = "Invitations envoyées: {n}",
        plan_generated       = "Pré-groupement généré.",
        no_plan              = "Aucun pré-groupement.",
        need_rl              = "Tu dois être RL ou assistant.",
        no_raid              = "Aucun raid actif.",
        groups_moved         = "Groupes: {moved} déplacés, {ok} déjà OK, {missing} absents",
        groups_moved_inv     = "Groupes: {moved} déplacés, {ok} déjà OK, {missing} absents, {invalid} invalides",
        inv_auto_on          = "Invitations auto activées.",
        inv_auto_off         = "Invitations auto désactivées.",
        skip_after_tour      = "(après tour complet)",
        -- Import panel
        whisper_keyword_lbl  = "Mot-cle:",
        btn_apply            = "Appliquer",
        btn_import           = "Importer",
        btn_clear            = "Effacer",
        import_title         = "▼ Import CSV (SoftRes + formats alternatifs) — colle les données ci-dessous :",
        import_db_empty      = "Base de données vide. Colle un CSV puis clique Importer.",
        import_db_stats      = "DB actuelle :  {players} joueurs  |  {loots} loots  |  {raids} date(s) de raid",
        import_err_empty     = "Erreur : zone de texte vide.",
        import_analyzing     = "Analyse en cours...",
        import_err           = "Erreur : {msg}",
        import_ok_groups_csv = "groupes CSV appliqués",
        -- WhisperBot
        whisper_kw_empty     = "Mot-cle whisper vide.",
        whisper_kw_set       = "Mot-cle whisper défini sur: {kw}",
        whisper_no_custom    = "Aucune commande whisper perso.",
        whisper_custom_list_msg = "Commandes whisper perso: {list}",
        whisper_raid_disabled   = "Commande raid désactivée. Contacte un officier.",
        whisper_lua_err      = "[WhisperBot] Erreur Lua: {msg}",
        -- Window / misc
        window_closed        = "Fenêtre RT fermée.",
        window_opened        = "Fenêtre RT ouverte.",
        loaded_msg           = "|cff00AAFF✦ OctoWow Edition|r chargé — |cffFFFFFF/rt|r pour ouvrir | |cffFFFFFF/rt help|r pour les commandes.",
        -- Notes de stratégie (Angry Assignments style)
        notes_tab_title      = "★ Notes de stratégie",
        notes_boss_lbl       = "Titre / Boss :",
        notes_save           = "Sauvegarder",
        notes_delete         = "Supprimer",
        notes_broadcast      = "Broadcast",
        notes_saved          = "Note sauvegardée : [{key}]",
        notes_deleted        = "Note supprimée : [{key}]",
        notes_broadcast_done = "{n} ligne(s) envoyée(s) en /{ch}.",
        notes_broadcast_empty= "Note vide — rien à envoyer.",
        notes_no_key         = "Saisis un titre de note.",
        notes_pick_btn       = "◄► Parcourir",
        notes_hint           = "Strat par boss. Broadcast envoie ligne par ligne en /raid.",
        notes_list_empty     = "(aucune note sauvegardée)",
        notes_browse_title   = "Notes",
        notes_strat_lbl      = "Strats Boss :",
        notes_strat_new_strat= "+ Strat",
        notes_tpl_lbl        = "Templates :",
        notes_tpl_pull       = "Pull",
        notes_tpl_positions  = "Placements",
        notes_tpl_cds        = "CDs",
        notes_template_loaded= "Template chargé : {name}",
        notes_channel_lbl    = "Canal Notes : /{ch}",
        notes_addon_lbl      = "Suivi boss :",
        notes_addon_dbm      = "DBM",
        notes_addon_bigwigs  = "BigWigs",
        notes_addon_none     = "Manuel",
        notes_addon_detect   = "Detecter",
        notes_addon_mode_set = "Suivi boss: {mode}",
        notes_addon_status_detected = "[{src}] Boss detecte: {boss}",
        notes_addon_status_none = "Aucun boss detecte via {src}.",
        notes_addon_tip_none = "Saisie manuelle du boss.",
        notes_addon_tip_dbm = "Utiliser DBM pour detecter le boss en combat.",
        notes_addon_tip_bigwigs = "Utiliser BigWigs pour detecter le boss en combat.",
        notes_addon_tip_detect = "Lancer une detection immediate du boss.",
        rl_panel_title       = "⚡ RL Speedrun",
        rl_pack_btn          = "PACK RL",
        rl_auto_on           = "Auto Pack: ON",
        rl_auto_off          = "Auto Pack: OFF",
        rl_btn_attrib        = "Attrib",
        rl_btn_raid_all      = "Raid All",
        rl_btn_note          = "Note Boss",
        rl_btn_strat         = "Strat Note",
        rl_btn_bless         = "Bless",
        rl_btn_check         = "Check",
        rl_btn_cds           = "CDs",
        rl_pack_done         = "Pack RL envoyé pour: {boss}",
        rl_no_strat_note     = "Aucune note strat pour: {boss}",
        rl_strat_sent        = "Note strat envoyée pour: {boss}",
        rl_cds_title         = "Raid Cooldowns RL",
        rl_cds_refresh       = "Refresh",
        rl_cds_call          = "Call Raid",
        rl_cds_size_plus     = "Taille +",
        rl_cds_size_minus    = "Taille -",
        rl_cds_drag_hint     = "Drag pour déplacer",
        rl_cds_called        = "Cooldowns annoncés en /{ch}",
        -- Raid Check
        check_tab_title      = "✔ Raid Check & Cooldowns",
        check_scan_btn       = "Scanner les buffs",
        check_clear          = "Effacer",
        check_no_raid        = "Aucun raid/groupe actif.",
        check_result_hdr     = "=== Raid Check ({n} joueurs) ===",
        check_col_hdr        = "Joueur                       Flask  Nourrit.  Arme",
        check_no_flask       = "Sans Flask :",
        check_no_food        = "Sans nourriture :",
        check_all_ok         = "Tout le monde est bien consommé ✓",
        -- Cooldowns de raid
        cd_title             = "⚡ Cooldowns de raid (depuis le roster)",
        cd_rebirth           = "Battle Rez / Rebirth",
        cd_innervate         = "Innervate",
        cd_bloodlust         = "Bloodlust / Héroïsme",
        cd_ankh              = "Résurrection Ancêtre",
        cd_lay_on_hands      = "Imposition des Mains",
        cd_divine_int        = "Intervention Divine",
        cd_soulstone         = "Pierre d'Âme",
        cd_misdirection      = "Détournement",
        cd_none              = " (aucun)",
        cd_refresh           = "Actualiser CDs",
        -- Bénédictions Paladin (PallyPower-lite)
        bless_title          = "✦ Bénédictions Paladin",
        bless_no_pala        = "Aucun Paladin détecté (raid/groupe/roster).",
        bless_broadcast      = "Broadcast",
        bless_broadcast_done = "Bénédictions envoyées en /{ch}.",
        bless_nothing_to_send= "Aucune bénédiction assignée à diffuser.",
        bless_refresh        = "Actualiser",
        bless_channel_lbl    = "Canal Bénédictions : /{ch}",
        bless_sync_pp        = "Sync PP",
        bless_read_pp        = "Lire PP",
        bless_sync_pp_missing= "PallyPower non détecté (sync impossible).",
        bless_sync_pp_fail   = "Sync PallyPower: échec ({msg})",
        bless_class_col      = "Classe",
        bless_pala_col       = "Paladin",
        bless_type_col       = "Bénédiction",
        bless_none           = "—",
        bless_kings          = "Rois",
        bless_might          = "Puissance",
        bless_wisdom         = "Sagesse",
        bless_salvation      = "Salut",
        bless_sanctuary      = "Sanctuaire",
        bless_light          = "Lumière",
        bless_map_title      = "Paladin => buffs",
        bless_map_empty      = "Aucune bénédiction assignée.",
        buff_curse_mode_auto = "Curses: AUTO",
        buff_curse_mode_man  = "Curses: MAN",
        buff_set_demo        = "Set Demo",
        buff_set_male        = "Set Malé",
        buff_demo_set        = "Demo: {name}",
        buff_male_set        = "Malé: {name}",
        buff_none_warlock    = "Aucun démoniste trouvé.",
        buff_players_lbl     = "Joueurs buffeurs:",
        loot_search_ph       = "Recherche joueur/classe/item",
        loot_search_btn      = "Chercher",
        loot_search_clear    = "Reset",
        import_paste_hint    = "Colle ton CSV ici (Ctrl+V). Support SoftRes + format alternatif.",
        demo_loaded          = "Preset démo chargé (roster/loot/notes/bénédictions).",
        demo_cleared         = "Preset démo vidé.",
    },
    en = {
        raid_header = "[RT] Boss {boss} - assignments",
        tanks = "Tanks",
        none = "none",
        heals_tank = "Heals Tank{index}",
        heals_raid = "Heals Raid",
        heals_melee = "Heals Melee",
        heals_caster = "Heals Caster",
        note = "Note",
        missing_buffs = "Important missing buffs:",
        buffs_ok = "Important buffs: OK (assigned players)",
        missing_line = "{player} missing: {buffs}",
        no_boss = "No boss sheet to announce. Target a boss or load a sheet.",
        no_boss_attrib = "No boss found. Target a boss or select a Boss sheet.",
        attrib_none = "No assignment for {player} on {boss}.",
        attrib_line = "Assignment for {player} on {boss}: {jobs}",
        context = "Context: {kind}{target} | boss: {boss}{source}",
        kind_boss = "boss",
        kind_player = "player",
        kind_other = "other",
        target = " | target: {target}",
        source = " ({source})",
        sent = "Raid announcement sent for {boss}.",
        buff_fort = "Fortitude",
        buff_int = "Intellect",
        buff_mark = "Mark",
        class_priests = "Priests",
        class_mages = "Mages",
        class_druids = "Druids",
        class_warlocks = "Warlocks",
        curse_elements = "Curse of Elements",
        curse_shadow = "Curse of Shadow",
        curse_reck = "Curse of Recklessness",
        curse_flex = "Flexible curse",
        buff_header     = "=== Buff Rotation ({total} players) ===",
        buff_none_roster= "Roster empty — import a CSV first.",
        buff_none_class = "No {label} in raid.",
        buff_groups_arrow= "→  groups {groups}",
        buff_summary_lbl = "Summary:",
        buff_curse_badge_auto = "Curse Mode: AUTO",
        buff_curse_badge_man  = "Curse Mode: MANUAL",
        buff_warlock_cols = "Name              Talent               Curse",
        trash_mob       = "Trash Mob",
        ui_lang_prefix  = "Lang",
        ui_lang_changed = "UI/announcement language: |cffFFD700{lang}|r",
        ui_boss_sheet_title = "☠ Boss Sheet",
        ui_buffs_title = "✦ Buff Rotation — Priest / Mage / Druid / Warlock",
        -- Boss status
        boss_select_first    = "Select a boss first.",
        boss_no_sheet        = "No sheet for {boss}",
        boss_loaded          = "Loaded: {boss}",
        boss_saved_status    = "Saved: {boss}",
        boss_saved_print     = "BossSheet: {boss} saved.",
        boss_slots_cleared   = "Slots cleared.",
        boss_new             = "New boss: {boss}",
        boss_select_del      = "Select a boss to delete.",
        boss_native_nodelete = "Native boss: cannot be deleted.",
        boss_custom_deleted  = "Custom boss deleted: {boss}",
        boss_not_found       = "Boss not found in raid list.",
        -- Session
        session_enter_name   = "Enter a session name.",
        session_saved_status = "Session saved: {sess}",
        session_saved_print  = "Session saved: {sess}",
        session_not_found    = "Session not found: {sess}",
        session_loaded       = "Session loaded: {sess}",
        -- Picker/popup
        picker_select_tank   = "Select Tank",
        picker_select_heal   = "Select Heal",
        picker_select_player = "Select player",
        picker_cancel        = "Cancel",
        picker_close         = "Close",
        picker_select_raid   = "Select raid",
        picker_select_boss   = "Select boss",
        boss_custom_name_lbl = "Custom boss name:",
        marker_none          = "None",
        -- Boss panel buttons
        btn_save             = "Save",
        btn_clear_slots      = "Clear slots",
        btn_save_sess        = "Save sess.",
        btn_load_sess        = "Load sess.",
        btn_announce_label   = "Announce:",
        -- Roster / Groups panel
        roster_header        = "⚔ Raid roster",
        groups_title         = "⚡ Raid pre-grouping (melee / caster optimization)",
        groups_hint          = "1) Refresh Raid 2) Adapt Groups 3) Invite 4) auto-placement",
        btn_gen_auto         = "Auto generate",
        btn_adapter_groupes  = "Adapt Groups",
        btn_refresh_raid     = "Refresh Raid",
        raid_refreshed       = "Raid refreshed: {n} player(s) loaded.",
        raid_refresh_empty   = "No active raid detected.",
        notes_loaded         = "◈ {key}",
        notes_new_key        = "◈ {key} (new)",
        btn_invite_plan      = "Invite plan",
        btn_apply_groups     = "Apply groups",
        group_label          = "Group {n}",
        slot_group_lbl       = "Group Slot",
        btn_clear_slot       = "Clear",
        player_lbl           = "Player:",
        pick_player_btn      = "Pick player",
        role_current_none    = "Current role: -",
        role_current         = "Current role: {role}",
        -- Group status messages
        need_leader_invite   = "You must be leader/assistant to invite.",
        no_planned_players   = "No players planned to invite.",
        invs_sent            = "Invitations sent: {n}",
        plan_generated       = "Pre-grouping generated.",
        no_plan              = "No pre-grouping.",
        need_rl              = "You must be RL or assistant.",
        no_raid              = "No active raid.",
        groups_moved         = "Groups: {moved} moved, {ok} already OK, {missing} absent",
        groups_moved_inv     = "Groups: {moved} moved, {ok} already OK, {missing} absent, {invalid} invalid",
        inv_auto_on          = "Auto invitations enabled.",
        inv_auto_off         = "Auto invitations disabled.",
        skip_after_tour      = "(after full cycle)",
        -- Import panel
        whisper_keyword_lbl  = "Keyword:",
        btn_apply            = "Apply",
        btn_import           = "Import",
        btn_clear            = "Clear",
        import_title         = "▼ Import CSV (SoftRes + alternate formats) — paste data below:",
        import_db_empty      = "Empty database. Paste a CSV then click Import.",
        import_db_stats      = "Current DB:  {players} players  |  {loots} loots  |  {raids} raid date(s)",
        import_err_empty     = "Error: text area is empty.",
        import_analyzing     = "Analyzing...",
        import_err           = "Error: {msg}",
        import_ok_groups_csv = "CSV groups applied",
        -- WhisperBot
        whisper_kw_empty     = "Whisper keyword empty.",
        whisper_kw_set       = "Whisper keyword set to: {kw}",
        whisper_no_custom    = "No custom whisper commands.",
        whisper_custom_list_msg = "Custom whisper commands: {list}",
        whisper_raid_disabled   = "Raid command disabled. Contact an officer.",
        whisper_lua_err      = "[WhisperBot] Lua error: {msg}",
        -- Window / misc
        window_closed        = "RT window closed.",
        window_opened        = "RT window opened.",
        loaded_msg           = "|cff00AAFF✦ OctoWow Edition|r loaded — |cffFFFFFF/rt|r to open | |cffFFFFFF/rt help|r for commands.",
        -- Strategy Notes (Angry Assignments style)
        notes_tab_title      = "★ Strategy Notes",
        notes_boss_lbl       = "Title / Boss:",
        notes_save           = "Save",
        notes_delete         = "Delete",
        notes_broadcast      = "Broadcast",
        notes_saved          = "Note saved: [{key}]",
        notes_deleted        = "Note deleted: [{key}]",
        notes_broadcast_done = "{n} line(s) sent to /{ch}.",
        notes_broadcast_empty= "Empty note — nothing to send.",
        notes_no_key         = "Enter a note title.",
        notes_pick_btn       = "◄► Browse",
        notes_hint           = "Strat per boss. Broadcast sends line by line to /raid.",
        notes_list_empty     = "(no saved notes)",
        notes_browse_title   = "Notes",
        notes_strat_lbl      = "Boss Strats:",
        notes_strat_new_strat= "+ Strat",
        notes_tpl_lbl        = "Templates:",
        notes_tpl_pull       = "Pull",
        notes_tpl_positions  = "Positions",
        notes_tpl_cds        = "CDs",
        notes_template_loaded= "Template loaded: {name}",
        notes_channel_lbl    = "Notes channel: /{ch}",
        notes_addon_lbl      = "Boss tracker:",
        notes_addon_dbm      = "DBM",
        notes_addon_bigwigs  = "BigWigs",
        notes_addon_none     = "Manual",
        notes_addon_detect   = "Detect",
        notes_addon_mode_set = "Boss tracker: {mode}",
        notes_addon_status_detected = "[{src}] Detected boss: {boss}",
        notes_addon_status_none = "No boss detected via {src}.",
        notes_addon_tip_none = "Manual boss entry.",
        notes_addon_tip_dbm = "Use DBM to detect current boss in combat.",
        notes_addon_tip_bigwigs = "Use BigWigs to detect current boss in combat.",
        notes_addon_tip_detect = "Run an immediate boss detection.",
        rl_panel_title       = "⚡ RL Speedrun",
        rl_pack_btn          = "RL PACK",
        rl_auto_on           = "Auto Pack: ON",
        rl_auto_off          = "Auto Pack: OFF",
        rl_btn_attrib        = "Attrib",
        rl_btn_raid_all      = "Raid All",
        rl_btn_note          = "Boss Note",
        rl_btn_strat         = "Strat Note",
        rl_btn_bless         = "Bless",
        rl_btn_check         = "Check",
        rl_btn_cds           = "CDs",
        rl_pack_done         = "RL Pack sent for: {boss}",
        rl_no_strat_note     = "No strategy note for: {boss}",
        rl_strat_sent        = "Strategy note sent for: {boss}",
        rl_cds_title         = "Raid Cooldowns RL",
        rl_cds_refresh       = "Refresh",
        rl_cds_call          = "Call Raid",
        rl_cds_size_plus     = "Size +",
        rl_cds_size_minus    = "Size -",
        rl_cds_drag_hint     = "Drag to move",
        rl_cds_called        = "Cooldowns announced in /{ch}",
        -- Raid Check
        check_tab_title      = "✔ Raid Check & Cooldowns",
        check_scan_btn       = "Scan buffs",
        check_clear          = "Clear",
        check_no_raid        = "No active raid/group.",
        check_result_hdr     = "=== Raid Check ({n} players) ===",
        check_col_hdr        = "Player                       Flask  Fed       Weapon",
        check_no_flask       = "Missing Flask:",
        check_no_food        = "Missing food:",
        check_all_ok         = "Everyone has consumables ✓",
        -- Raid Cooldowns
        cd_title             = "⚡ Raid Cooldowns (from roster)",
        cd_rebirth           = "Battle Rez / Rebirth",
        cd_innervate         = "Innervate",
        cd_bloodlust         = "Bloodlust / Heroism",
        cd_ankh              = "Ancestral Spirit",
        cd_lay_on_hands      = "Lay on Hands",
        cd_divine_int        = "Divine Intervention",
        cd_soulstone         = "Soulstone",
        cd_misdirection      = "Misdirection",
        cd_none              = " (none)",
        cd_refresh           = "Refresh CDs",
        -- Paladin Blessings (PallyPower-lite)
        bless_title          = "✦ Paladin Blessings",
        bless_no_pala        = "No Paladin detected (raid/party/roster).",
        bless_broadcast      = "Broadcast",
        bless_broadcast_done = "Blessings broadcast to /{ch}.",
        bless_nothing_to_send= "No blessing assignment to broadcast.",
        bless_refresh        = "Refresh",
        bless_channel_lbl    = "Blessings channel: /{ch}",
        bless_sync_pp        = "Sync PP",
        bless_read_pp        = "Read PP",
        bless_sync_pp_missing= "PallyPower not detected (sync unavailable).",
        bless_sync_pp_fail   = "PallyPower sync failed: {msg}",
        bless_class_col      = "Class",
        bless_pala_col       = "Paladin",
        bless_type_col       = "Blessing",
        bless_none           = "—",
        bless_kings          = "Kings",
        bless_might          = "Might",
        bless_wisdom         = "Wisdom",
        bless_salvation      = "Salvation",
        bless_sanctuary      = "Sanctuary",
        bless_light          = "Light",
        bless_map_title      = "Paladin => buffs",
        bless_map_empty      = "No blessing assigned.",
        buff_curse_mode_auto = "Curses: AUTO",
        buff_curse_mode_man  = "Curses: MAN",
        buff_set_demo        = "Set Demo",
        buff_set_male        = "Set Malé",
        buff_demo_set        = "Demo: {name}",
        buff_male_set        = "Malé: {name}",
        buff_none_warlock    = "No warlock found.",
        buff_players_lbl     = "Buff players:",
        loot_search_ph       = "Search player/class/item",
        loot_search_btn      = "Search",
        loot_search_clear    = "Reset",
        import_paste_hint    = "Paste your CSV here (Ctrl+V). SoftRes + alternate format supported.",
        demo_loaded          = "Demo preset loaded (roster/loot/notes/blessings).",
        demo_cleared         = "Demo preset cleared.",
    }
}

local function RT_FormatVars(text, vars)
    local out = text or ""
    out = string.gsub(out, "{([%w_]+)}", function(key)
        local val = vars and vars[key]
        if val == nil then return "{" .. key .. "}" end
        return tostring(val)
    end)
    return out
end

RT_AnnouncementLang = function()
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    local lang = string.lower(RT_DB.settings.announceLang or "fr")
    if lang ~= "fr" and lang ~= "en" and lang ~= "both" then
        lang = "fr"
        RT_DB.settings.announceLang = lang
    end
    return lang
end

RT_Text = function(key, vars)
    local lang = RT_AnnouncementLang()
    local fr = RT_I18N.fr[key] or key
    local en = RT_I18N.en[key] or fr
    if lang == "en" then return RT_FormatVars(en, vars) end
    if lang == "both" then
        return RT_FormatVars(fr, vars) .. " / " .. RT_FormatVars(en, vars)
    end
    return RT_FormatVars(fr, vars)
end

RT_RefreshLocalizedStaticUI = function()
    local bossTitle = getglobal("RT_BossPanelTitle")
    if bossTitle and RT_Text then
        bossTitle:SetText(RT_Text("ui_boss_sheet_title"))
    end
    local buffsTitle = getglobal("RT_BuffsPanelTitle")
    if buffsTitle and RT_Text then
        buffsTitle:SetText(RT_Text("ui_buffs_title"))
    end

    local notesTitle = getglobal("RT_NotesPanelTitle")
    if notesTitle and RT_Text then notesTitle:SetText(RT_Text("notes_tab_title")) end

    local notesBrowseBtn = getglobal("RT_NotesBrowseBtn")
    if notesBrowseBtn and RT_Text then notesBrowseBtn:SetText(RT_Text("notes_pick_btn")) end
    local notesSaveBtn = getglobal("RT_NotesSaveBtn")
    if notesSaveBtn and RT_Text then notesSaveBtn:SetText(RT_Text("notes_save")) end
    local notesDeleteBtn = getglobal("RT_NotesDeleteBtn")
    if notesDeleteBtn and RT_Text then notesDeleteBtn:SetText(RT_Text("notes_delete")) end
    local notesBroadcastBtn = getglobal("RT_NotesBroadcastBtn")
    if notesBroadcastBtn and RT_Text then notesBroadcastBtn:SetText(RT_Text("notes_broadcast")) end
    local notesTplLbl = getglobal("RT_NotesTplLbl")
    if notesTplLbl and RT_Text then notesTplLbl:SetText(RT_Text("notes_tpl_lbl")) end
    local notesTplPullBtn = getglobal("RT_NotesTplPullBtn")
    if notesTplPullBtn and RT_Text then notesTplPullBtn:SetText(RT_Text("notes_tpl_pull")) end
    local notesTplPosBtn = getglobal("RT_NotesTplPosBtn")
    if notesTplPosBtn and RT_Text then notesTplPosBtn:SetText(RT_Text("notes_tpl_positions")) end
    local notesTplCdsBtn = getglobal("RT_NotesTplCdsBtn")
    if notesTplCdsBtn and RT_Text then notesTplCdsBtn:SetText(RT_Text("notes_tpl_cds")) end
    local notesBrowseTitle = getglobal("RT_NotesBrowseTitle")
    if notesBrowseTitle and RT_Text then notesBrowseTitle:SetText(RT_Text("notes_browse_title")) end
    local notesBrowseClose = getglobal("RT_NotesBrowseCloseBtn")
    if notesBrowseClose and RT_Text then notesBrowseClose:SetText(RT_Text("picker_close")) end

    local checkTitle = getglobal("RT_CheckPanelTitle")
    if checkTitle and RT_Text then checkTitle:SetText(RT_Text("check_tab_title")) end
    local checkScanBtn = getglobal("RT_CheckScanBtn")
    if checkScanBtn and RT_Text then checkScanBtn:SetText(RT_Text("check_scan_btn")) end
    local checkClearBtn = getglobal("RT_CheckClearBtn")
    if checkClearBtn and RT_Text then checkClearBtn:SetText(RT_Text("check_clear")) end

    local lootSearchBtn = getglobal("RT_LootSearchBtn")
    if lootSearchBtn and RT_Text then lootSearchBtn:SetText(RT_Text("loot_search_btn")) end
    local lootSearchResetBtn = getglobal("RT_LootSearchResetBtn")
    if lootSearchResetBtn and RT_Text then lootSearchResetBtn:SetText(RT_Text("loot_search_clear")) end
    local lootSearchEdit = getglobal("RT_LootSearchEdit")
    if lootSearchEdit and RT_Text then
        local cur = RT_BTrim(lootSearchEdit:GetText() or "")
        if cur == "" then lootSearchEdit:SetText(RT_Text("loot_search_ph")) end
    end

    local importPasteHint = getglobal("RT_ImportPasteHint")
    if importPasteHint and RT_Text then importPasteHint:SetText("|cff88CCFF" .. RT_Text("import_paste_hint") .. "|r") end

    local cdTitle = getglobal("RT_CDPanelTitle")
    if cdTitle and RT_Text then cdTitle:SetText(RT_Text("cd_title")) end
    local cdRefreshBtn = getglobal("RT_CDRefreshBtn")
    if cdRefreshBtn and RT_Text then cdRefreshBtn:SetText(RT_Text("cd_refresh")) end

    local blessTitle = getglobal("RT_BlessingsPanelTitle")
    if blessTitle and RT_Text then blessTitle:SetText(RT_Text("bless_title")) end
    local blessRefreshBtn = getglobal("RT_BlessRefreshBtn")
    if blessRefreshBtn and RT_Text then blessRefreshBtn:SetText(RT_Text("bless_refresh")) end
    local blessBroadcastBtn = getglobal("RT_BlessBroadcastBtn")
    if blessBroadcastBtn and RT_Text then blessBroadcastBtn:SetText(RT_Text("bless_broadcast")) end
    local blessSyncPPBtn = getglobal("RT_BlessSyncPPBtn")
    if blessSyncPPBtn and RT_Text then blessSyncPPBtn:SetText(RT_Text("bless_sync_pp")) end

    local blessClassCol = getglobal("RT_BlessColClass")
    if blessClassCol and RT_Text then blessClassCol:SetText(RT_Text("bless_class_col")) end
    local blessPalaCol = getglobal("RT_BlessColPala")
    if blessPalaCol and RT_Text then blessPalaCol:SetText(RT_Text("bless_pala_col")) end
    local blessTypeCol = getglobal("RT_BlessColType")
    if blessTypeCol and RT_Text then blessTypeCol:SetText(RT_Text("bless_type_col")) end

    local curseModeBtn = getglobal("RT_BuffCurseModeBtn")
    if curseModeBtn and RT_Text then
        RT_BuffEnsureCurseSettings()
        if RT_DB.buffs.curseAuto then curseModeBtn:SetText(RT_Text("buff_curse_mode_auto"))
        else curseModeBtn:SetText(RT_Text("buff_curse_mode_man")) end
    end
    local curseDemoBtn = getglobal("RT_BuffSetDemoBtn")
    if curseDemoBtn and RT_Text then curseDemoBtn:SetText(RT_Text("buff_set_demo")) end
    local curseMaleBtn = getglobal("RT_BuffSetMaleBtn")
    if curseMaleBtn and RT_Text then curseMaleBtn:SetText(RT_Text("buff_set_male")) end

    local rlTitle = getglobal("RT_RLQuickTitle")
    if rlTitle and RT_Text then rlTitle:SetText(RT_Text("rl_panel_title")) end
    local rlPackBtn = getglobal("RT_RLQuickPackBtn")
    if rlPackBtn and RT_Text then rlPackBtn:SetText(RT_Text("rl_pack_btn")) end
    local rlAttribBtn = getglobal("RT_RLQuickAttribBtn")
    if rlAttribBtn and RT_Text then rlAttribBtn:SetText(RT_Text("rl_btn_attrib")) end
    local rlRaidAllBtn = getglobal("RT_RLQuickRaidAllBtn")
    if rlRaidAllBtn and RT_Text then rlRaidAllBtn:SetText(RT_Text("rl_btn_raid_all")) end
    local rlNoteBtn = getglobal("RT_RLQuickNoteBtn")
    if rlNoteBtn and RT_Text then rlNoteBtn:SetText(RT_Text("rl_btn_note")) end
    local rlStratBtn = getglobal("RT_RLQuickStratBtn")
    if rlStratBtn and RT_Text then rlStratBtn:SetText(RT_Text("rl_btn_strat")) end
    local rlBlessBtn = getglobal("RT_RLQuickBlessBtn")
    if rlBlessBtn and RT_Text then rlBlessBtn:SetText(RT_Text("rl_btn_bless")) end
    local rlCheckBtn = getglobal("RT_RLQuickCheckBtn")
    if rlCheckBtn and RT_Text then rlCheckBtn:SetText(RT_Text("rl_btn_check")) end
    local rlCDsBtn = getglobal("RT_RLQuickCDsBtn")
    if rlCDsBtn and RT_Text then rlCDsBtn:SetText(RT_Text("rl_btn_cds")) end
    local rlAutoBtn = getglobal("RT_RLQuickAutoBtn")
    if rlAutoBtn and RT_Text then
        RT_RLQuickEnsureSettings()
        if RT_DB.settings.rlQuickAuto then rlAutoBtn:SetText(RT_Text("rl_auto_on"))
        else rlAutoBtn:SetText(RT_Text("rl_auto_off")) end
    end

    local rlCDTitle = getglobal("RT_RLCDTitle")
    if rlCDTitle and RT_Text then rlCDTitle:SetText(RT_Text("rl_cds_title")) end
    local rlCDRefreshBtn = getglobal("RT_RLCDRefreshBtn")
    if rlCDRefreshBtn and RT_Text then rlCDRefreshBtn:SetText(RT_Text("rl_cds_refresh")) end
    local rlCDCallBtn = getglobal("RT_RLCDCallBtn")
    if rlCDCallBtn and RT_Text then rlCDCallBtn:SetText(RT_Text("rl_cds_call")) end
    local rlCDDrag = getglobal("RT_RLCDDragHint")
    if rlCDDrag and RT_Text then rlCDDrag:SetText(RT_Text("rl_cds_drag_hint")) end

    if RT_BuffCycleWarlockTarget then RT_BuffCycleWarlockTarget(0) end

    if RT_UpdateAnnounceChannelLabels then RT_UpdateAnnounceChannelLabels() end
end

local function RT_WrapChatLine(text, maxLen)
    local msg = RT_BTrim(text or "")
    local limit = maxLen or 220
    local lines = {}
    while string.len(msg) > limit do
        local cut = limit
        while cut > 40 and string.sub(msg, cut, cut) ~= " " do
            cut = cut - 1
        end
        if cut <= 40 then cut = limit end
        table.insert(lines, RT_BTrim(string.sub(msg, 1, cut)))
        msg = RT_BTrim(string.sub(msg, cut + 1))
    end
    if msg ~= "" then table.insert(lines, msg) end
    return lines
end

local function RT_SendRaidAnnounce(text)
    local msg = RT_BTrim(text or "")
    if msg == "" then return end
    local chan = "SAY"
    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    if nRaid > 0 then
        chan = "RAID"
    elseif nParty > 0 then
        chan = "PARTY"
    end
    local wrapped = RT_WrapChatLine(msg, 220)
    for i = 1, table.getn(wrapped) do
        local safe = string.gsub(wrapped[i], "|", "||")
        SendChatMessage(safe, chan)
    end
end

local function RT_BossAppendTankLines(lines, bossData)
    local tanks = {}
    local tankCount = (bossData and bossData.tank_count) or 4
    if tankCount < 1 then tankCount = 1 end
    if tankCount > 4 then tankCount = 4 end
    for i = 1, tankCount do
        local t = bossData and bossData.tanks and bossData.tanks[i] or ""
        if t and t ~= "" then
            local mark = bossData and bossData.tank_marks and bossData.tank_marks[i] or ""
            local prefix = "T" .. i
            if mark and mark ~= "" then
                local icon = RT_TANK_MARKER_RAID_ICON and RT_TANK_MARKER_RAID_ICON[mark]
                if icon and icon ~= "" then
                    prefix = prefix .. icon
                else
                    prefix = prefix .. "[" .. mark .. "]"
                end
            end
            table.insert(tanks, prefix .. ":" .. t)
        end
    end
    if table.getn(tanks) > 0 then
        table.insert(lines, "[RT] " .. RT_Text("tanks") .. ": " .. table.concat(tanks, " | "))
    else
        table.insert(lines, "[RT] " .. RT_Text("tanks") .. ": " .. RT_Text("none"))
    end
end

local function RT_BossAppendTankMarkerOnlyLines(lines, bossData)
    local out = {}
    local tankCount = (bossData and bossData.tank_count) or 4
    if tankCount < 1 then tankCount = 1 end
    if tankCount > 4 then tankCount = 4 end

    for i = 1, tankCount do
        local t = bossData and bossData.tanks and bossData.tanks[i] or ""
        if t and t ~= "" then
            local mark = bossData and bossData.tank_marks and bossData.tank_marks[i] or ""
            local label = t
            if mark and mark ~= "" then
                local icon = RT_TANK_MARKER_RAID_ICON and RT_TANK_MARKER_RAID_ICON[mark]
                if icon and icon ~= "" then
                    label = icon .. " " .. t
                else
                    label = "[" .. mark .. "] " .. t
                end
            end
            table.insert(out, label)
        end
    end

    if table.getn(out) > 0 then
        table.insert(lines, "[RT] Tanks: " .. table.concat(out, " | "))
    else
        table.insert(lines, "[RT] " .. RT_Text("tanks") .. ": " .. RT_Text("none"))
    end
end

local function RT_BossAppendHealLines(lines, bossData)
    local function pushHeals(key, label)
        local arr = bossData and bossData[key] or nil
        local vals = {}
        if arr then
            for i = 1, table.getn(arr) do
                if arr[i] and arr[i] ~= "" then table.insert(vals, arr[i]) end
            end
        end
        if table.getn(vals) > 0 then
            table.insert(lines, "[RT] " .. label .. ": " .. table.concat(vals, ", "))
        end
    end

    pushHeals("h_tank1", RT_Text("heals_tank", { index = 1 }))
    pushHeals("h_tank2", RT_Text("heals_tank", { index = 2 }))
    pushHeals("h_tank3", RT_Text("heals_tank", { index = 3 }))
    pushHeals("h_tank4", RT_Text("heals_tank", { index = 4 }))
    pushHeals("h_raid", RT_Text("heals_raid"))
    pushHeals("h_melee", RT_Text("heals_melee"))
    pushHeals("h_caster", RT_Text("heals_caster"))
end

local function RT_BossAppendNoteLines(lines, bossData)
    local note = RT_BTrim(bossData and bossData.note or "")
    if note ~= "" then
        table.insert(lines, "[RT] " .. RT_Text("note") .. ": " .. note)
    end
end

local function RT_BossAppendBuffLines(lines, bossData)
    RT_BuffAppendAssignmentLines(lines)
end

local function RT_BossBuildRaidAnnounceLines(bossName, bossData, mode)
    local lines = {}
    local section = RT_BTrim(mode or "all")
    if section == "" then section = "all" end
    -- Pas de header séparé : [RT] sera ajouté par RT_SendRaidAnnounce sur chaque ligne

    if section == "all" or section == "tanks" then
        RT_BossAppendTankLines(lines, bossData)
    end
    if section == "tankmarks" then
        RT_BossAppendTankMarkerOnlyLines(lines, bossData)
    end
    if section == "all" or section == "heals" then
        RT_BossAppendHealLines(lines, bossData)
    end
    if section == "all" or section == "note" then
        RT_BossAppendNoteLines(lines, bossData)
    end
    if section == "all" or section == "buffs" then
        RT_BossAppendBuffLines(lines, bossData)
    end

    return lines
end

function RT_AttribCommand()
    local ctx = RT_BossResolveContext()
    local playerName = UnitName("player") or "Joueur"

    if not ctx.bossName or not ctx.bossData then
        RT_Print(RT_ColorErr(RT_Text("no_boss_attrib")))
        return
    end

    local contextLabel = RT_Text("kind_other")
    if ctx.kind == "boss" then contextLabel = RT_Text("kind_boss") end
    if ctx.kind == "player" then contextLabel = RT_Text("kind_player") end

    RT_Print(RT_Text("context", {
        kind = contextLabel,
        target = ctx.targetName ~= "" and RT_Text("target", { target = ctx.targetName }) or "",
        boss = ctx.bossName,
        source = ctx.source ~= "" and RT_Text("source", { source = ctx.source }) or "",
    }))
    RT_Print(RT_BossBuildPlayerAttribution(playerName, ctx.bossName, ctx.bossData))
end

function RT_RaidAnnounceCommand(mode)
    local ctx = RT_BossResolveContext()
    if not ctx.bossName or not ctx.bossData then
        RT_Print(RT_ColorErr(RT_Text("no_boss")))
        return
    end

    local section = string.lower(RT_BTrim(mode or "all"))
    if section == "" then section = "all" end
    if section ~= "all" and section ~= "tanks" and section ~= "tankmarks" and section ~= "heals" and section ~= "buffs" and section ~= "note" then
        RT_Print(RT_ColorErr("Usage: /rt raid [all|tanks|tankmarks|heals|buffs|note]"))
        return
    end

    local lines = RT_BossBuildRaidAnnounceLines(ctx.bossName, ctx.bossData, section)
    for i = 1, table.getn(lines) do
        RT_SendRaidAnnounce(lines[i])
    end
    RT_Print(RT_Text("sent", { boss = RT_ColorGold(ctx.bossName) }))
end

-- Ouvre/rafraîchit le picker joueur
function RT_OpenPlayerPicker(roleFilter)
    local roster = RT_DB.roster or {}
    local players = {}
    local rf = roleFilter or "All"
    if rf ~= "All" then rf = RT_NormalizeRole(rf) end

    local function RT_IsLikelyPlayerName(name)
        local n = RT_BTrim(name or "")
        if n == "" then return false end
        if string.len(n) > 16 then return false end
        if string.find(n, " ", 1, true) then return false end
        if string.find(n, '"', 1, true) then return false end
        return true
    end

    for name, data in pairs(roster) do
        if RT_IsLikelyPlayerName(name) then
            local role = RT_NormalizeRole(data.role)
            if rf == "All" or role == rf then
                table.insert(players, { name=name, class=data.class or "?", spec=data.spec or "?", role=role })
            end
        end
    end
    table.sort(players, function(a, b)
        local order = { Tank=1, Heal=2, DPS=3 }
        local ra = order[a.role] or 4
        local rb = order[b.role] or 4
        if ra ~= rb then return ra < rb end
        return a.name < b.name
    end)
    for i = 1, 20 do
        local btn = RT_BOSS_SLOT_BTNS["_picker_"..i]
        if btn then
            local p = players[i]
            if p then
                local pname = p.name
                local cl    = p.class
                local specTxt = p.spec or "?"
                if string.len(specTxt) > 18 then
                    specTxt = string.sub(specTxt, 1, 18) .. "..."
                end
                btn:SetText(RT_ColorClass(pname, cl) .. " |cffAAAAAA" .. specTxt .. "|r")
                btn:SetScript("OnClick", function()
                    if RT_PICKER_CALLBACK then RT_PICKER_CALLBACK(pname) end
                    local pp = getglobal("RT_PlayerPickerPopup")
                    if pp then pp:Hide() end
                end)
                btn:Show()
            else
                btn:SetText("")
                btn:SetScript("OnClick", nil)
                btn:Hide()
            end
        end
    end
    local titleLbl = getglobal("RT_PickerTitle")
    if titleLbl then
        if rf == "Tank" then titleLbl:SetText(RT_Text("picker_select_tank"))
        elseif rf == "Heal" then titleLbl:SetText(RT_Text("picker_select_heal"))
        else titleLbl:SetText(RT_Text("picker_select_player")) end
    end
    local nb   = math.min(table.getn(players), 20)
    local popup = getglobal("RT_PlayerPickerPopup")
    if popup then
        popup:SetHeight(46 + nb * 22)
        RT_PopupBringToFront(popup)
    end
end

-- Met à jour le texte des widgets de l'éditeur de rôle du roster
function RT_RosterRefreshRoleEditor()
    local pickBtn = getglobal("RT_RosterPickPlayerBtn")
    local roleLbl = getglobal("RT_RosterPickRoleLbl")
    local status  = getglobal("RT_RosterRoleEditStatus")
    local name = RT_ROSTER_SELECTED_PLAYER or ""
    local roster = RT_DB.roster or {}

    if pickBtn then
        if name ~= "" and roster[name] then
            local class = roster[name].class or "?"
            pickBtn:SetText(RT_ColorClass(name, class))
        else
            pickBtn:SetText(RT_Text("pick_player_btn"))
        end
    end

    if roleLbl then
        if name ~= "" and roster[name] then
            roleLbl:SetText(RT_Text("role_current", {role=RT_ColorRole(RT_NormalizeRole(roster[name].role))}))
        else
            roleLbl:SetText(RT_Text("role_current_none"))
        end
    end

    if status and name == "" then
        status:SetText("")
    end

    local specEdit = getglobal("RT_RosterSpecEdit")
    if specEdit then
        if name ~= "" and roster[name] then
            specEdit:SetText(roster[name].spec or "")
        else
            specEdit:SetText("")
        end
    end
end

-- Ouvre le picker pour choisir le joueur à modifier
function RT_RosterPickPlayer()
    RT_PICKER_CALLBACK = function(playerName)
        RT_ROSTER_SELECTED_PLAYER = playerName or ""
        RT_RosterRefreshRoleEditor()
    end
    RT_OpenPlayerPicker("All")
end

-- Change le rôle d'un joueur sélectionné
function RT_RosterSetSelectedRole(newRole)
    local name = RT_ROSTER_SELECTED_PLAYER or ""
    local status = getglobal("RT_RosterRoleEditStatus")
    local roster = RT_DB.roster or {}

    if name == "" or not roster[name] then
        if status then status:SetText(RT_ColorErr("Select a player first.")) end
        return
    end

    if newRole ~= "Tank" and newRole ~= "Heal" and newRole ~= "DPS" then
        if status then status:SetText(RT_ColorErr("Role invalide.")) end
        return
    end

    roster[name].role = newRole
    if status then status:SetText(RT_ColorOK(name .. " -> " .. newRole)) end
    RT_RosterRefreshRoleEditor()
    RT_RosterDisplay()
end

-- Change la spé d'un joueur sélectionné et met à jour le rôle si reconnu
function RT_RosterSetSelectedSpec(newSpec)
    local name   = RT_ROSTER_SELECTED_PLAYER or ""
    local status = getglobal("RT_RosterRoleEditStatus")
    local roster = RT_DB.roster or {}

    if name == "" or not roster[name] then
        if status then status:SetText(RT_ColorErr("Sélectionne un joueur d'abord.")) end
        return
    end

    newSpec = newSpec or ""
    roster[name].spec = newSpec

    -- Auto-déduire le rôle si la spé est reconnue
    local class       = roster[name].class or ""
    local deducedRole = RT_GetRole(class, newSpec)
    if deducedRole and deducedRole ~= "DPS" then
        -- RT_GetRole retourne "DPS" par défaut même si inconnu, on garde l'ancien rôle dans ce cas
        roster[name].role = deducedRole
    elseif deducedRole == "DPS" then
        roster[name].role = "DPS"
    end

    if status then
        local roleInfo = "|cffAAAAAA(rôle: " .. RT_ColorRole(roster[name].role) .. "|cffAAAAAA)|r"
        status:SetText(RT_ColorOK(name .. " → " .. (newSpec ~= "" and newSpec or "?")) .. "  " .. roleInfo)
    end

    RT_RosterRefreshRoleEditor()
    RT_RosterDisplay()
end

-- ============================================================
-- Fonctions utilitaires
-- ============================================================

-- Affiche un message dans le chat principal
function RT_Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("[|cffFF7D0ART|r] " .. (msg or ""))
end

-- Retourne le rôle déduit de la classe + spé
function RT_GetRole(class, spec)
    if RT_SPEC_ROLE[class] and RT_SPEC_ROLE[class][spec] then
        return RT_SPEC_ROLE[class][spec]
    end
    return "DPS"
end

-- Compte les joueurs par rôle dans le roster
function RT_CountRoles()
    local counts = { Tank = 0, Heal = 0, DPS = 0 }
    for _, player in pairs(RT_DB.roster or {}) do
        local role = RT_NormalizeRole(player.role)
        counts[role] = (counts[role] or 0) + 1
    end
    return counts
end

-- Compte le total de joueurs dans le roster
function RT_CountPlayers()
    local n = 0
    for _ in pairs(RT_DB.roster or {}) do n = n + 1 end
    return n
end

-- Réinitialise toutes les données
function RT_ResetDB()
    RT_DB.roster   = {}
    RT_DB.bosses   = {}
    RT_DB.loot     = {}
    RT_DB.sr       = {}
    RT_DB.presence = {}
    RT_DB.buffs    = {}
    RT_DB.debuffs  = {}
    local status = getglobal("RT_ImportStatus")
    local stats  = getglobal("RT_ImportStats")
    if status then status:SetText(RT_ColorErr("Database reset.")) end
    if stats   then stats:SetText("") end
    RT_Print(RT_ColorErr("Database reset."))
end

-- Réinitialise uniquement le roster (conserve BossSheet et le reste)
function RT_ResetRosterOnly()
    RT_DB.roster = {}
    RT_ROSTER_SELECTED_PLAYER = ""

    local status = getglobal("RT_ImportStatus")
    if status then status:SetText(RT_ColorErr("Roster reset (Boss data kept).")) end

    RT_UpdateImportStats()
    RT_RosterDisplay()
    RT_Print(RT_ColorErr("Roster reset (Boss data kept)."))
end

-- ============================================================
-- Gestion des onglets
-- ============================================================

-- Couleurs des onglets (inactif) par tab — OctoWow Edition
local RT_TAB_COLORS = {
    Roster = {0.20, 0.65, 1.00},   -- cyan-bleu électrique
    Boss   = {1.00, 0.28, 0.28},   -- rouge vif
    Groups = {0.20, 0.95, 0.50},   -- vert néon
    Buffs  = {1.00, 0.90, 0.10},   -- or vif
    Loot   = {1.00, 0.55, 0.05},   -- orange vif
    Import = {0.78, 0.32, 1.00},   -- violet électrique
    Notes  = {0.10, 0.88, 1.00},   -- cyan brillant
    Check  = {0.30, 1.00, 0.65},   -- vert menthe néon
}

local function RT_CloseBossSubmenus()
    local popups = {
        "RT_RaidPickerPopup",
        "RT_BossPickerPopup",
        "RT_PlayerPickerPopup",
        "RT_BossAddPopup",
        "RT_TankMarkerPopup",
        "RT_NotesBrowsePopup",
    }
    for i = 1, table.getn(popups) do
        local p = getglobal(popups[i])
        if p and p.Hide then p:Hide() end
    end
end

function RT_ShowTab(tabName)
    -- En mode Simple, on bascule en mode Avancé puis on affiche l'onglet
    if RT_DISPLAY_MODE == "simple" and tabName ~= "Dashboard" then
        RT_SetDisplayMode("advanced")
    end
    RT_CURRENT_TAB = tabName
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    RT_DB.settings.ui = RT_DB.settings.ui or {}
    RT_DB.settings.ui.lastTab = tabName

    if tabName ~= "Boss" then
        RT_CloseBossSubmenus()
    end

    local rlQuick = getglobal("RT_RLQuickPanel")
    if rlQuick then
        -- Le panel RL est géré par RT_RLTogglePersist, pas par le tab actif
        -- On ne le cache jamais automatiquement
        if tabName == "Boss" then
            -- Afficher un indicateur visuel que le tab Boss est actif
        end
    end

    -- Cacher tous les panels + re-colorer les onglets
    for tabIdx = 1, table.getn(RT_TABS) do
        local name = RT_TABS[tabIdx]
        local panel = getglobal("RT_Panel_" .. name)
        if panel then panel:Hide() end
        -- Mettre à jour la couleur du bouton onglet
        if RT_TAB_BUTTONS and RT_TAB_BUTTONS[name] then
            local btn = RT_TAB_BUTTONS[name]
            if name == tabName then
                -- Onglet actif : fond doré brillant, texte blanc
                btn:GetFontString():SetTextColor(1.0, 1.0, 1.0)
                if btn.SetNormalTextColor then btn:SetNormalTextColor(1.0, 1.0, 1.0) end
                local c = RT_TAB_COLORS[name]
                if c then
                    btn:GetFontString():SetTextColor(c[1] * 1.4 > 1 and 1 or c[1] * 1.4,
                                                    c[2] * 1.4 > 1 and 1 or c[2] * 1.4,
                                                    c[3] * 1.4 > 1 and 1 or c[3] * 1.4)
                end
                btn:LockHighlight()
            else
                -- Onglet inactif : texte de la couleur du tab
                local c = RT_TAB_COLORS[name] or {0.7, 0.7, 0.7}
                btn:GetFontString():SetTextColor(c[1] * 0.75, c[2] * 0.75, c[3] * 0.75)
                btn:UnlockHighlight()
            end
        end
    end

    -- Afficher le panel actif
    local active = getglobal("RT_Panel_" .. tabName)
    if active then active:Show() end

    -- Rafraîchir le contenu si nécessaire
    if tabName == "Roster" then
        RT_RosterDisplay()
    elseif tabName == "Boss" then
        RT_BossDisplay()
        RT_UpdateBossOptionsUI()
        RT_RLQuickEnsureSettings()
        local autoBtn = getglobal("RT_RLQuickAutoBtn")
        if autoBtn then
            if RT_DB.settings.rlQuickAuto then autoBtn:SetText(RT_Text("rl_auto_on"))
            else autoBtn:SetText(RT_Text("rl_auto_off")) end
        end
        if RT_UpdateAnnounceChannelLabels then RT_UpdateAnnounceChannelLabels() end
    elseif tabName == "Groups" then
        RT_GroupDisplay()
    elseif tabName == "Loot" then
        RT_LootDisplay("all")
    elseif tabName == "Buffs" then
        local r = getglobal("RT_BuffRotFrame")
        local b = getglobal("RT_BuffBlessFrame")
        if r then r:Show() end
        if b then b:Hide() end
        RT_BuffDisplay()
        if RT_UpdateAnnounceChannelLabels then RT_UpdateAnnounceChannelLabels() end
    elseif tabName == "Import" then
        RT_UpdateImportStats()
    elseif tabName == "Notes" then
        -- Rafraîchir le popup si ouvert
        local nbp = getglobal("RT_NotesBrowsePopup")
        if nbp and nbp:IsShown() then RT_NotesBrowsePopupRefresh() end
        if RT_UpdateAnnounceChannelLabels then RT_UpdateAnnounceChannelLabels() end
    elseif tabName == "Check" then
        RT_CheckRefreshConfigUI()
        RT_CooldownDisplay()
    end
end

local function RT_SaveMainFramePosition()
    if not RT_MainFrame then return end
    local point, _, relativePoint, xOfs, yOfs = RT_MainFrame:GetPoint()
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    RT_DB.settings.ui = RT_DB.settings.ui or {}
    RT_DB.settings.ui.point = point or "CENTER"
    RT_DB.settings.ui.relativePoint = relativePoint or "CENTER"
    RT_DB.settings.ui.x = xOfs or 0
    RT_DB.settings.ui.y = yOfs or 0
end

local function RT_ApplySavedMainFramePosition()
    if not RT_MainFrame then return end
    local ui = RT_DB and RT_DB.settings and RT_DB.settings.ui
    if not ui then return end
    local point = ui.point or "CENTER"
    local relativePoint = ui.relativePoint or "CENTER"
    local x = ui.x or 0
    local y = ui.y or 0
    RT_MainFrame:ClearAllPoints()
    RT_MainFrame:SetPoint(point, UIParent, relativePoint, x, y)
end

-- ============================================================
-- Construction UI (Lua only, compatible Vanilla 1.12)
-- ============================================================

-- ============================================================
-- Constantes pour Raid Check, Cooldowns, Bénédictions
-- ============================================================

-- Patterns de texture indiquant un buff Flask (UnitBuff renvoie la texture en 1.12)
local RT_FLASK_TEX = {
    "Alchemy_Flask",   -- INV_Alchemy_Flask01, 02, 03…
    "Inv_Flask",
    "Flask_",
    "Alchemist_Stone", -- Philosopher's Stone
}

-- Patterns de texture pour les buffs de nourriture / "Well Fed"
local RT_FOOD_TEX = {
    "INV_Misc_Food",    -- Well Fed depuis la plupart des aliments
    "INV_Drink_",
    "Spell_Holy_SealOf", -- certains buffs food custom
    "Consumable_",
    "INV_Potion_",      -- elixirs/potions comme alternative
}

-- Bosses Vanilla/TurtleWoW (pour le sélecteur de strat dans l'onglet Notes)
local RT_BOSS_LIST = {
    { raid = "Molten Core",         color = {1.0, 0.4, 0.1}, bosses = {
        "Lucifron", "Magmadar", "Gehennas", "Garr",
        "Baron Geddon", "Shazzrah", "Sulfuron Harbinger",
        "Golemagg", "Majordomo Executus", "Ragnaros",
    }},
    { raid = "Onyxia's Lair",       color = {0.8, 0.1, 0.1}, bosses = {
        "Onyxia",
    }},
    { raid = "Blackwing Lair",      color = {0.6, 0.3, 0.1}, bosses = {
        "Razorgore", "Vaelastrasz", "Broodlord Lashlayer",
        "Firemaw", "Ebonroc", "Flamegor",
        "Chromaggus", "Nefarian",
    }},
    { raid = "Zul'Gurub",           color = {0.2, 0.8, 0.3}, bosses = {
        "Jeklik", "Venoxis", "Marli", "Mandokir",
        "Gahzranka", "Thekal", "Arlokk", "Jindo", "Hakkar",
    }},
    { raid = "Ruins of Ahn'Qiraj",  color = {0.9, 0.8, 0.4}, bosses = {
        "Kurinnaxx", "Rajaxx", "Moam",
        "Buru", "Ayamiss", "Ossirian",
    }},
    { raid = "Temple of Ahn'Qiraj", color = {0.7, 0.65, 0.2}, bosses = {
        "Skeram", "Bug Trio", "Sartura", "Fankriss",
        "Viscidus", "Huhuran", "Twin Emperors", "Ouro", "C'Thun",
    }},
    { raid = "Naxxramas",           color = {0.5, 0.5, 0.8}, bosses = {
        "Anub'Rekhan", "Faerlina", "Maexxna",
        "Noth", "Heigan", "Loatheb",
        "Razuvious", "Gothik", "Four Horsemen",
        "Patchwerk", "Grobbulus", "Gluth", "Thaddius",
        "Sapphiron", "Kel'Thuzad",
    }},
    { raid = "World Bosses",        color = {0.4, 0.7, 1.0}, bosses = {
        "Azuregos", "Lord Kazzak",
        "Taerar", "Emeriss", "Lethon", "Ysondre",
    }},
}

-- Patterns de texture pour enchantements d'arme temporaires
local RT_WEAPON_TEX = {
    "Temp_EnchantWeapon",
    "WizardOil",
    "ManaOil",
    "Windfury",
    "Flametongue",
    "Poison",           -- rogues weapon
    "Consecration",
}

-- Cooldowns importants de raid, par classe (clé i18n + classe anglaise)
local RT_RAID_CDS = {
    { key = "cd_rebirth",      class = "Druid"   },
    { key = "cd_innervate",    class = "Druid"   },
    { key = "cd_bloodlust",    class = "Shaman"  },
    { key = "cd_ankh",         class = "Shaman"  },
    { key = "cd_lay_on_hands", class = "Paladin" },
    { key = "cd_divine_int",   class = "Paladin" },
    { key = "cd_soulstone",    class = "Warlock" },
    { key = "cd_misdirection", class = "Hunter"  },
}

-- ============================================================
-- Config Check : quels buffs / CDs afficher et annoncer
-- ============================================================

local function RT_CheckBuffConfig()
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    local cfg = RT_DB.settings.checkBuffs or {}
    return {
        flask  = cfg.flask  ~= false,
        food   = cfg.food   ~= false,
        weapon = cfg.weapon ~= false,
    }
end

local function RT_CheckCDConfig()
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    local cfg = RT_DB.settings.checkCDs or {}
    local out = {}
    for i = 1, table.getn(RT_RAID_CDS) do
        local k = RT_RAID_CDS[i].key
        out[k] = cfg[k] ~= false
    end
    return out
end

function RT_CheckRefreshConfigUI()
    local cfg   = RT_CheckBuffConfig()
    local cdcfg = RT_CheckCDConfig()
    local function applyToggle(name, active)
        local btn = getglobal(name)
        if not btn then return end
        local tex = btn:GetNormalTexture()
        if tex then
            if active then tex:SetVertexColor(0.25, 0.90, 0.35)
            else           tex:SetVertexColor(0.45, 0.45, 0.45) end
        end
        local fs = btn:GetFontString()
        if fs then
            if active then fs:SetTextColor(1.0, 1.0, 1.0)
            else           fs:SetTextColor(0.5, 0.5, 0.5) end
        end
    end
    applyToggle("RT_CheckToggleFlask",  cfg.flask)
    applyToggle("RT_CheckToggleFood",   cfg.food)
    applyToggle("RT_CheckToggleWeapon", cfg.weapon)
    for i = 1, table.getn(RT_RAID_CDS) do
        local k = RT_RAID_CDS[i].key
        applyToggle("RT_CDToggle_" .. k, cdcfg[k])
    end
end

local function RT_CheckToggleBuff(key)
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    RT_DB.settings.checkBuffs = RT_DB.settings.checkBuffs or {}
    local cfg = RT_DB.settings.checkBuffs
    cfg[key] = not (cfg[key] ~= false)
    RT_CheckRefreshConfigUI()
end

local function RT_CheckToggleCD(key)
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    RT_DB.settings.checkCDs = RT_DB.settings.checkCDs or {}
    local cfg = RT_DB.settings.checkCDs
    cfg[key] = not (cfg[key] ~= false)
    RT_CheckRefreshConfigUI()
    RT_CooldownDisplay()
    if RT_RLCooldownRefresh then RT_RLCooldownRefresh() end
end

-- Classes supportées pour les bénédictions (ordre affiché)
-- { nomAnglais, {r,g,b} }
local RT_BLESS_CLASSES = {
    { "Warrior",  {0.78, 0.61, 0.43} },
    { "Paladin",  {0.96, 0.55, 0.73} },
    { "Hunter",   {0.67, 0.83, 0.45} },
    { "Rogue",    {1.00, 0.96, 0.41} },
    { "Priest",   {1.00, 1.00, 1.00} },
    { "Shaman",   {0.00, 0.44, 0.87} },
    { "Mage",     {0.25, 0.78, 0.92} },
    { "Warlock",  {0.53, 0.53, 0.93} },
    { "Druid",    {1.00, 0.49, 0.04} },
}

-- Index des types de bénédictions (1 = aucune)
local RT_BLESS_TYPES_FR = { "—", "Rois",      "Puissance", "Sagesse", "Salut",     "Sanctuaire", "Lumière" }
local RT_BLESS_TYPES_EN = { "—", "Kings",     "Might",     "Wisdom",  "Salvation", "Sanctuary",  "Light"  }

local RT_CLASS_ALIASES = {
    warrior = "Warrior", guerrier = "Warrior", war = "Warrior",
    paladin = "Paladin", pala = "Paladin", pal = "Paladin",
    hunter = "Hunter", chasseur = "Hunter", hunt = "Hunter",
    rogue = "Rogue", voleur = "Rogue", rog = "Rogue",
    priest = "Priest", pretre = "Priest", pretre = "Priest", pri = "Priest",
    shaman = "Shaman", chamane = "Shaman", sham = "Shaman",
    mage = "Mage",
    warlock = "Warlock", demono = "Warlock", demo = "Warlock", lock = "Warlock",
    druid = "Druid", druide = "Druid", drood = "Druid",
    -- class tokens souvent vus en CSV / API
    wrr = "Warrior", pal = "Paladin", hun = "Hunter", rog = "Rogue", pri = "Priest",
    shm = "Shaman", mag = "Mage", wrk = "Warlock", drd = "Druid",
}

RT_NormalizeClassName = function(class)
    local raw = RT_BTrim(class or "")
    if raw == "" then return "" end

    local low = string.lower(raw)
    local direct = RT_CLASS_ALIASES[low]
    if direct then return direct end

    -- variantes avec espaces/traits d'union
    local compact = string.gsub(low, "[^%a]", "")
    local mapped = RT_CLASS_ALIASES[compact]
    if mapped then return mapped end

    -- déjà au bon format (Warrior, Paladin...)
    local cap = string.upper(string.sub(low, 1, 1)) .. string.sub(low, 2)
    if RT_CLASS_COLORS[cap] then return cap end

    return raw
end

local function RT_GetBlessingName(idx)
    local types = (RT_AnnouncementLang() == "fr") and RT_BLESS_TYPES_FR or RT_BLESS_TYPES_EN
    return types[idx] or "—"
end

-- Vérifie si une unité a un buff dont la texture correspond à l'un des patterns
local function RT_UnitHasBuffPattern(unit, patterns)
    for i = 1, 32 do
        local tex = UnitBuff(unit, i)
        if not tex then break end
        local texLow = string.lower(tex)
        for pi = 1, table.getn(patterns) do
            if string.find(texLow, string.lower(patterns[pi])) then
                return true
            end
        end
    end
    return false
end

-- Découpe un texte en lignes (compatible Lua 5.0 / WoW 1.12)
local function RT_SplitLines(text)
    local lines = {}
    local pos = 1
    local len = string.len(text)
    while pos <= len do
        local s = string.find(text, "\n", pos, true)
        if s then
            local line = string.sub(text, pos, s - 1)
            table.insert(lines, line)
            pos = s + 1
        else
            local line = string.sub(text, pos)
            if string.len(line) > 0 then table.insert(lines, line) end
            break
        end
    end
    return lines
end

-- Choisit automatiquement le meilleur canal d'annonce disponible
local function RT_GetBestAnnounceChannel()
    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if nRaid > 0 then return "RAID", "raid" end

    local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    if nParty > 0 then return "PARTY", "party" end

    return "SAY", "say"
end

local function RT_NotesTemplateText(kind)
    local fr = (RT_AnnouncementLang() ~= "en")
    if kind == "pull" then
        if fr then
            return "=== PULL ===\nTank: [Main Tank]\nAssist: [Off Tank]\nHeal focus: [T1/T2/T3]\n\nCall: Pull dans 5...4...3...2...1"
        end
        return "=== PULL ===\nTank: [Main Tank]\nAssist: [Off Tank]\nHeal focus: [T1/T2/T3]\n\nCall: Pull in 5...4...3...2...1"
    end
    if kind == "positions" then
        if fr then
            return "=== PLACEMENTS ===\nTank: Boss au marqueur [Skull]\nMelee: Derriere boss\nCaster/Heals: Stack [Moon]\n\nPriorite: Eviter front + spread sur debuff"
        end
        return "=== POSITIONS ===\nTank: Boss on marker [Skull]\nMelee: Behind boss\nCaster/Heals: Stack [Moon]\n\nPriority: Avoid frontal + spread on debuff"
    end
    if fr then
        return "=== ROTATION CDs ===\nPhase 1: [CD raid 1]\nPhase 2: [CD raid 2]\nPhase execute: [CD raid 3]\n\nBattle rez: [Druid 1] puis [Druid 2]"
    end
    return "=== CD ROTATION ===\nPhase 1: [Raid CD 1]\nPhase 2: [Raid CD 2]\nExecute phase: [Raid CD 3]\n\nBattle rez: [Druid 1] then [Druid 2]"
end

function RT_NotesInsertTemplate(kind)
    local edit = getglobal("RT_NotesTextEdit")
    local status = getglobal("RT_NotesStatus")
    if not edit then return end

    local template = RT_NotesTemplateText(kind)
    edit:SetText(template)

    local keyName = "notes_tpl_pull"
    if kind == "positions" then keyName = "notes_tpl_positions" end
    if kind == "cds" then keyName = "notes_tpl_cds" end

    if status then
        status:SetText(RT_ColorGold(RT_Text("notes_template_loaded", {name = RT_Text(keyName)})))
    end
end

function RT_UpdateAnnounceChannelLabels()
    local _, ch = RT_GetBestAnnounceChannel()

    local notesLbl = getglobal("RT_NotesChannelLbl")
    if notesLbl then
        notesLbl:SetText("|cff88CCFF" .. RT_Text("notes_channel_lbl", {ch = ch}) .. "|r")
    end

    local blessLbl = getglobal("RT_BlessChannelLbl")
    if blessLbl then
        blessLbl:SetText("|cff99EE99" .. RT_Text("bless_channel_lbl", {ch = ch}) .. "|r")
    end

    local rlChanLbl = getglobal("RT_RLQuickChannelLbl")
    if rlChanLbl then
        rlChanLbl:SetText("|cff88CCFF/" .. ch .. "|r")
    end
end

RT_RLQuickEnsureSettings = function()
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    if RT_DB.settings.rlQuickAuto == nil then RT_DB.settings.rlQuickAuto = false end
    if RT_DB.settings.rlEnabled   == nil then RT_DB.settings.rlEnabled   = false end
    RT_DB.settings.rlCDFrame = RT_DB.settings.rlCDFrame or { w = 280, h = 200 }
end

-- forward declaration: utilisée par le panel RL avant sa définition complète
local RT_BuildClassMap

local function RT_RLCooldownLines()
    local classMap = RT_BuildClassMap()
    local cdcfg    = RT_CheckCDConfig()
    local lines    = {}
    for i = 1, table.getn(RT_RAID_CDS) do
        local cd = RT_RAID_CDS[i]
        if cdcfg[cd.key] then
            local players = classMap[cd.class]
            if players and table.getn(players) > 0 then
                table.insert(lines, RT_Text(cd.key) .. ": " .. table.concat(players, ", "))
            end
        end
    end
    return lines
end

function RT_RLCooldownRefresh()
    if RT_RLUpdateRoleSummary then RT_RLUpdateRoleSummary() end
    local log = getglobal("RT_RLCDLog")
    if not log then return end
    log:Clear()
    log:AddMessage(RT_ColorGold(RT_Text("rl_cds_title")))
    log:AddMessage(" ")
    local lines = RT_RLCooldownLines()
    if table.getn(lines) == 0 then
        log:AddMessage("|cff888888" .. RT_Text("cd_none") .. "|r")
        return
    end
    for i = 1, table.getn(lines) do
        log:AddMessage(lines[i])
    end
end

function RT_RLCooldownCallRaid()
    local lines = RT_RLCooldownLines()
    local _, ch = RT_GetBestAnnounceChannel()
    if table.getn(lines) == 0 then return end
    RT_SendRaidAnnounce("[RT] " .. RT_Text("rl_cds_title"))
    for i = 1, table.getn(lines) do
        RT_SendRaidAnnounce(lines[i])
    end
    RT_Print(RT_ColorOK(RT_Text("rl_cds_called", {ch = ch})))
end

function RT_RLCooldownToggle()
    local f = getglobal("RT_RLCDFrame")
    if not f then return end
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        RT_RLCooldownRefresh()
    end
end

function RT_RLCooldownResize(step)
    local f = getglobal("RT_RLCDFrame")
    if not f then return end
    RT_RLQuickEnsureSettings()
    local w = f:GetWidth() + (step or 0)
    local h = f:GetHeight() + (step or 0)
    if w < 220 then w = 220 end
    if w > 420 then w = 420 end
    if h < 150 then h = 150 end
    if h > 360 then h = 360 end
    f:SetWidth(w)
    f:SetHeight(h)
    RT_DB.settings.rlCDFrame.w = w
    RT_DB.settings.rlCDFrame.h = h

    local log = getglobal("RT_RLCDLog")
    if log then
        log:SetWidth(w - 12)
        log:SetHeight(h - 58)
    end
end

function RT_FindStratNoteForBoss(bossName)
    RT_DB = RT_DB or {}
    RT_DB.stratNotes = RT_DB.stratNotes or {}
    local key = RT_BTrim(bossName or "")
    if key == "" then return nil end

    if RT_DB.stratNotes[key] and RT_BTrim(RT_DB.stratNotes[key]) ~= "" then
        return key, RT_DB.stratNotes[key]
    end

    local low = string.lower(key)
    for k, v in pairs(RT_DB.stratNotes) do
        if string.lower(RT_BTrim(k or "")) == low and RT_BTrim(v or "") ~= "" then
            return k, v
        end
    end
    -- Recherche partielle : "Lucifron" trouve "MC - Lucifron"
    for k, v in pairs(RT_DB.stratNotes) do
        local kLow = string.lower(RT_BTrim(k or ""))
        if string.find(kLow, low, 1, true) and RT_BTrim(v or "") ~= "" then
            return k, v
        end
    end
    return nil
end

function RT_AnnounceCurrentBossStratNote(silent)
    local ctx = RT_BossResolveContext()
    if not ctx or not ctx.bossName then return false end

    local foundKey, text = RT_FindStratNoteForBoss(ctx.bossName)
    if not foundKey or RT_BTrim(text or "") == "" then
        if not silent then
            RT_Print(RT_ColorErr(RT_Text("rl_no_strat_note", { boss = ctx.bossName })))
        end
        return false
    end

    RT_SendRaidAnnounce("[RT] " .. foundKey)
    local lines = RT_SplitLines(text)
    for i = 1, table.getn(lines) do
        local line = RT_BTrim(lines[i])
        if line ~= "" then RT_SendRaidAnnounce(line) end
    end

    if not silent then
        RT_Print(RT_ColorOK(RT_Text("rl_strat_sent", { boss = ctx.bossName })))
    end
    return true
end

function RT_RLQuickPack(isAuto)
    local ctx = RT_BossResolveContext()
    if not ctx or not ctx.bossName or not ctx.bossData then
        RT_Print(RT_ColorErr(RT_Text("no_boss")))
        return
    end

    RT_RaidAnnounceCommand("all")
    RT_AnnounceCurrentBossStratNote(true)
    RT_BlessingsAnnounce()

    if not isAuto then
        RT_Print(RT_ColorOK(RT_Text("rl_pack_done", { boss = ctx.bossName })))
    end
end

function RT_RLQuickToggleAuto()
    RT_RLQuickEnsureSettings()
    RT_DB.settings.rlQuickAuto = not RT_DB.settings.rlQuickAuto
    local b = getglobal("RT_RLQuickAutoBtn")
    if b then
        if RT_DB.settings.rlQuickAuto then b:SetText(RT_Text("rl_auto_on"))
        else b:SetText(RT_Text("rl_auto_off")) end
    end
    RT_Print("RL Quick Auto: " .. RT_ColorGold(RT_DB.settings.rlQuickAuto and "ON" or "OFF"))
end

-- Activer/désactiver le panel RL Speedrun (persiste indépendamment du menu RT)
function RT_RLTogglePersist()
    RT_RLQuickEnsureSettings()
    RT_DB.settings.rlEnabled = not RT_DB.settings.rlEnabled
    local rl = getglobal("RT_RLQuickPanel")
    if rl then
        if RT_DB.settings.rlEnabled then
            rl:Show()
            if RT_RLUpdateRoleSummary then RT_RLUpdateRoleSummary() end
        else rl:Hide() end
        rl:SetFrameStrata("DIALOG")
        if rl.Raise then rl:Raise() end
    end
    -- Mettre à jour le bouton header
    local hdrBtn = getglobal("RT_RLHeaderToggle")
    if hdrBtn then
        if RT_DB.settings.rlEnabled then hdrBtn:SetText("RL: ON")
        else hdrBtn:SetText("RL: OFF") end
    end
    RT_Print("RL Speedrun: " .. RT_ColorGold(RT_DB.settings.rlEnabled and "ON" or "OFF"))
end

function RT_RLSetPersist(enabled)
    RT_RLQuickEnsureSettings()
    RT_DB.settings.rlEnabled = (enabled == true)
    local rl = getglobal("RT_RLQuickPanel")
    if rl then
        if RT_DB.settings.rlEnabled then
            rl:Show()
            rl:SetFrameStrata("DIALOG")
            if rl.Raise then rl:Raise() end
        else
            rl:Hide()
        end
    end
    local hdrBtn = getglobal("RT_RLHeaderToggle")
    if hdrBtn then
        if RT_DB.settings.rlEnabled then hdrBtn:SetText("RL: ON")
        else hdrBtn:SetText("RL: OFF") end
    end
end

-- ============================================================
-- Système de modes (Guild / PUG / RL Leadeur)
-- ============================================================

function RT_GetMode()
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    return RT_DB.settings.mode or "guild"
end

function RT_SetMode(mode)
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    RT_DB.settings.mode = mode or "guild"

    local modes = { guild = "RT_ModeBtnGuild", pug = "RT_ModeBtnPUG", rl = "RT_ModeBtnRL" }
    for m, btnName in pairs(modes) do
        local b = getglobal(btnName)
        if b then
            if m == mode then
                b:LockHighlight()
                local fs = b:GetFontString()
                if fs then fs:SetTextColor(1.0, 1.0, 1.0) end
            else
                b:UnlockHighlight()
                local fs = b:GetFontString()
                if fs then fs:SetTextColor(0.55, 0.55, 0.55) end
            end
        end
    end

    -- Comportement selon mode
    if mode == "rl" then
        RT_RLSetPersist(true)
    end

    local modeNames = { guild = "|cff88FFAA[Guild]|r", pug = "|cffFFAA00[PUG]|r", rl = "|cffFF6666[RL]|r" }
    RT_Print("Mode: " .. (modeNames[mode] or mode))
end

function RT_ModeIsPUG()
    return RT_GetMode() == "pug"
end

function RT_ModeIsRL()
    return RT_GetMode() == "rl"
end

function RT_RLResetPanelPosition()
    local rl = getglobal("RT_RLQuickPanel")
    if not rl then return end
    rl:ClearAllPoints()
    rl:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -120, -120)
    rl:SetFrameStrata("DIALOG")
    if rl.Raise then rl:Raise() end
end

function RT_RLUpdateRoleSummary()
    local lbl = getglobal("RT_RLRoleSummary")
    if not lbl then return end
    local counts = RT_CountRoles()
    local total  = RT_CountPlayers()
    if total == 0 then
        lbl:SetText("|cff666666Roster vide|r")
        return
    end
    lbl:SetText(
        "|cffFF6666T:" .. counts.Tank .. "|r  "
        .. "|cff88FF88H:" .. counts.Heal .. "|r  "
        .. "|cffFFDD44D:" .. counts.DPS  .. "|r  "
        .. "|cff888888(" .. total .. " total)|r"
    )
end

local function RT_PPGetAssignments()
    return getglobal("PallyPower_Assignments")
        or getglobal("PP_Assignments")
        or (getglobal("PallyPower") and getglobal("PallyPower").db and getglobal("PallyPower").db.assignments)
end

local function RT_PPGetClassBuckets(ppAssign, className, classIdx)
    local buckets = {}
    buckets[1] = ppAssign[className]
    buckets[2] = ppAssign[string.upper(className)]
    buckets[3] = ppAssign[classIdx]
    return buckets
end

local function RT_PPExtractAssignment(ppData)
    if type(ppData) ~= "table" then return "", "" end
    local paladin = ppData.paladin or ppData.player or ppData.name or ppData[1] or ""
    local blessing = ppData.blessing or ppData.buff or ppData.spell or ppData[2] or ""
    return RT_BTrim(paladin), blessing
end

local function RT_PPBlessingToIdx(value)
    if value == nil then return nil end
    if type(value) == "number" then
        local idx = math.floor(value)
        if idx >= 1 and idx <= table.getn(RT_BLESS_TYPES_FR) then return idx end
    end
    local s = string.lower(RT_BTrim(tostring(value)))
    if s == "" then return nil end

    local byName = {
        [string.lower(RT_Text("bless_none"))] = 1,
        ["-"] = 1,
        ["none"] = 1,
        ["kings"] = 2, [string.lower(RT_Text("bless_kings"))] = 2,
        ["might"] = 3, [string.lower(RT_Text("bless_might"))] = 3,
        ["wisdom"] = 4, [string.lower(RT_Text("bless_wisdom"))] = 4,
        ["salvation"] = 5, [string.lower(RT_Text("bless_salvation"))] = 5,
        ["sanctuary"] = 6, [string.lower(RT_Text("bless_sanctuary"))] = 6,
        ["light"] = 7, [string.lower(RT_Text("bless_light"))] = 7,
    }
    return byName[s]
end

-- Synche un joueur 10min vers PallyPower (assignment individuel par nom de joueur)
local function RT_BlessSyncPalaRowToPP(palaName, assign)
    if not palaName or palaName == "" then return end
    if not assign then return end
    local playerName = RT_BTrim(assign.player10min or "")
    if playerName == "" then return end
    local blessName = RT_GetBlessingName(assign.blessIdx or 1)
    if not blessName or blessName == "—" or blessName == "" then return end
    pcall(function()
        local ppAssign = RT_PPGetAssignments()
        if type(ppAssign) ~= "table" then return end
        -- Entrée par nom de joueur (bénédiction individuelle 10min dans PP)
        local entry = ppAssign[playerName]
        if type(entry) ~= "table" then
            entry = {}
            ppAssign[playerName] = entry
        end
        entry.paladin  = palaName
        entry.player   = palaName
        entry.name     = palaName
        entry.blessing = blessName
        entry.buff     = blessName
        entry.spell    = blessName
        entry[1]       = palaName
        entry[2]       = blessName
        local pp = getglobal("PallyPower")
        if pp then
            if pp.Refresh then pcall(function() pp:Refresh() end) end
            if pp.Update  then pcall(function() pp:Update()  end) end
        end
        if PallyPower_Update then pcall(PallyPower_Update) end
    end)
end

-- Auto-assign des bénédictions basé sur les specs des Paladins du roster
-- Règle clé : Prot Pala → Salut (peut cancel sur soi/tanks, reçoit Lumière/Sanctuaire)
function RT_BlessingsAutoAssign()
    RT_DB = RT_DB or {}
    RT_DB.blessings = RT_DB.blessings or {}
    RT_DB.blessings.classAssign = RT_DB.blessings.classAssign or {}

    local roster = RT_DB.roster or {}
    local status = getglobal("RT_BlessStatus")

    -- 1) Collecter les Paladins et leurs specs
    local paladins = {}
    for name, data in pairs(roster) do
        if RT_NormalizeClassName(data.class or "") == "Paladin" then
            local spec = string.lower(RT_BTrim(data.spec or ""))
            local stype = "holy"
            if string.find(spec, "prot") then stype = "prot"
            elseif string.find(spec, "ret")  then stype = "ret"  end
            table.insert(paladins, {name=name, stype=stype})
        end
    end
    table.sort(paladins, function(a, b)
        local ord = {prot=1, ret=2, holy=3}
        local oa = ord[a.stype] or 3
        local ob = ord[b.stype] or 3
        if oa ~= ob then return oa < ob end
        return a.name < b.name
    end)

    local n = table.getn(paladins)
    if n == 0 then
        if status then status:SetText(RT_ColorErr("Aucun Paladin dans le roster")) end
        return
    end

    -- Index bénédictions : 1=— 2=Kings 3=Might 4=Wisdom 5=Salvation 6=Sanctuary 7=Light
    local KINGS = 2; local MIGHT = 3; local WISDOM = 4
    local SALUT = 5; local LIGHT = 7

    -- 2) Attribution des béné selon spec et nombre de paladins
    -- Priorité d'attribution : Prot→Salut, Ret→Puissance, Holy→Sagesse/Lumière
    local blessQueue = {MIGHT, WISDOM, SALUT, KINGS, LIGHT}
    -- On remplace selon spec
    local specPrefer = {prot=SALUT, ret=MIGHT, holy=WISDOM}

    local assigned = {}  -- blessIdx par paladin index
    local usedBless = {}
    for i = 1, n do
        local pref = specPrefer[paladins[i].stype] or MIGHT
        if not usedBless[pref] then
            assigned[i] = pref
            usedBless[pref] = true
        else
            -- Chercher la prochaine béné libre
            for _, bi in pairs(blessQueue) do
                if not usedBless[bi] then
                    assigned[i] = bi
                    usedBless[bi] = true
                    break
                end
            end
        end
        if not assigned[i] then assigned[i] = MIGHT end
    end

    -- 3) Attribution des classes par béné
    -- Salut → tout le monde (Prot peut cancel sur soi/tanks)
    -- Puissance → melee (Warrior, Rogue, Hunter, Pala)
    -- Sagesse → casters/healers (Priest, Mage, Warlock, Druid, Shaman, Pala)
    -- Kings → tout le monde
    -- Lumière → Tanks en priorité (soin passif)
    local classForBless = {
        [SALUT]  = {"Warrior","Rogue","Paladin","Hunter","Priest","Mage","Warlock","Druid","Shaman"},
        [MIGHT]  = {"Warrior","Rogue","Paladin","Hunter","Druid","Shaman"},
        [WISDOM] = {"Priest","Mage","Warlock","Druid","Shaman","Paladin"},
        [KINGS]  = {"Warrior","Paladin","Hunter","Rogue","Priest","Shaman","Mage","Warlock","Druid"},
        [LIGHT]  = {"Warrior","Paladin","Druid"},
    }

    -- Reset les assignations
    RT_DB.blessings.classAssign = {}
    local ca = RT_DB.blessings.classAssign

    -- Pour chaque classe, choisir la béné la plus utile parmi les paladins disponibles
    -- Priorité : Kings > Salut > Puissance > Sagesse
    local classPriority = {
        ["Warrior"]  = {MIGHT,  SALUT, KINGS, WISDOM},
        ["Rogue"]    = {MIGHT,  SALUT, KINGS, WISDOM},
        ["Hunter"]   = {MIGHT,  SALUT, KINGS, WISDOM},
        ["Paladin"]  = {SALUT,  KINGS, MIGHT, WISDOM},
        ["Priest"]   = {WISDOM, KINGS, SALUT, LIGHT},
        ["Mage"]     = {WISDOM, KINGS, SALUT, LIGHT},
        ["Warlock"]  = {WISDOM, KINGS, SALUT, LIGHT},
        ["Druid"]    = {WISDOM, KINGS, SALUT, MIGHT},
        ["Shaman"]   = {WISDOM, KINGS, SALUT, MIGHT},
    }

    -- Construire la map blessIdx → paladin
    local blessToPala = {}
    for i = 1, n do
        if assigned[i] then
            blessToPala[assigned[i]] = paladins[i].name
        end
    end

    for classIdx = 1, table.getn(RT_BLESS_CLASSES) do
        local className = RT_BLESS_CLASSES[classIdx][1]
        local prio = classPriority[className] or {MIGHT, WISDOM, KINGS}
        local chosenBless = nil
        local chosenPala  = nil
        for _, bi in pairs(prio) do
            if blessToPala[bi] then
                chosenBless = bi
                chosenPala  = blessToPala[bi]
                break
            end
        end
        if not chosenPala then
            -- Fallback : premier pala disponible
            chosenPala  = paladins[1].name
            chosenBless = assigned[1] or MIGHT
        end
        ca[className] = {pala = chosenPala, blessIdx = chosenBless}
    end

    RT_BlessingsDisplay()
    local msg = "Auto-assign OK — " .. n .. " paladin(s)"
    if status then status:SetText(RT_ColorOK(msg)) end

    -- Note sur le Prot Pala
    if blessToPala[SALUT] then
        local protName = blessToPala[SALUT]
        RT_Print("|cffFFD700[RT]|r Béné auto : |cffFF7777" .. protName
            .. "|r → Salut (peut cancel sur tanks et recevoir Lumière/Sanctuaire)")
    end
end

function RT_BlessingsSyncToPallyPower()
    local status = getglobal("RT_BlessStatus")
    local ok, err = pcall(function()
        RT_DB = RT_DB or {}
        RT_DB.blessings = RT_DB.blessings or {}
        RT_DB.blessings.classAssign = RT_DB.blessings.classAssign or {}

        local ppAssign = RT_PPGetAssignments()
        if type(ppAssign) ~= "table" then
            error("missing")
        end

        local pp = getglobal("PallyPower")
        for classIdx = 1, table.getn(RT_BLESS_CLASSES) do
            local className = RT_BLESS_CLASSES[classIdx][1]
            local assign = RT_DB.blessings.classAssign[className] or {}
            local bless = RT_GetBlessingName(assign.blessIdx or 1)

            local buckets = RT_PPGetClassBuckets(ppAssign, className, classIdx)
            local used = nil
            for i = 1, table.getn(buckets) do
                if type(buckets[i]) == "table" then
                    used = buckets[i]
                    break
                end
            end
            if not used then
                used = {}
                ppAssign[className] = used
            end
            used.paladin = assign.pala or ""
            used.player = assign.pala or ""
            used.blessing = bless or ""
            used.buff = bless or ""
            used.spell = bless or ""
            used[1] = assign.pala or ""
            used[2] = bless or ""
        end

        -- Sync aussi les joueurs 10min depuis palaAssign
        RT_DB.blessings.palaAssign = RT_DB.blessings.palaAssign or {}
        RT_BlessPalaRows = RT_BlessPalaRows or {}
        for ri = 1, 8 do
            local palaName = RT_BlessPalaRows[ri]
            if palaName then
                local pa = RT_DB.blessings.palaAssign[palaName] or {}
                local playerName = RT_BTrim(pa.player10min or "")
                if playerName ~= "" then
                    local blessName2 = RT_GetBlessingName(pa.blessIdx or 1)
                    if blessName2 and blessName2 ~= "—" and blessName2 ~= "" then
                        local entry = ppAssign[playerName]
                        if type(entry) ~= "table" then entry = {}; ppAssign[playerName] = entry end
                        entry.paladin  = palaName
                        entry.player   = palaName
                        entry.name     = palaName
                        entry.blessing = blessName2
                        entry.buff     = blessName2
                        entry.spell    = blessName2
                        entry[1]       = palaName
                        entry[2]       = blessName2
                    end
                end
            end
        end

        -- Déclencher la mise à jour PP (plusieurs signatures possibles)
        if pp then
            if pp.Refresh then pcall(function() pp:Refresh() end) end
            if pp.Update  then pcall(function() pp:Update()  end) end
        end
        if PallyPower_Update then pcall(PallyPower_Update) end
    end)

    if ok then
        RT_BlessingsDisplay()
        if status then status:SetText(RT_ColorOK(RT_Text("bless_sync_pp_ok"))) end
        RT_Print(RT_ColorOK(RT_Text("bless_sync_pp_ok")))
    else
        if tostring(err) == "missing" then
            if status then status:SetText(RT_ColorErr(RT_Text("bless_sync_pp_missing"))) end
            RT_Print(RT_ColorErr(RT_Text("bless_sync_pp_missing")))
        else
            if status then status:SetText(RT_ColorErr(RT_Text("bless_sync_pp_fail", {msg=tostring(err)}))) end
            RT_Print(RT_ColorErr(RT_Text("bless_sync_pp_fail", {msg=tostring(err)})))
        end
    end
end

-- Lire les assignations depuis PallyPower et les importer dans RT
function RT_BlessingsReadFromPallyPower()
    local status = getglobal("RT_BlessStatus")
    local ok, err = pcall(function()
        RT_DB = RT_DB or {}
        RT_DB.blessings = RT_DB.blessings or {}
        RT_DB.blessings.classAssign = RT_DB.blessings.classAssign or {}

        local ppAssign = RT_PPGetAssignments()
        if type(ppAssign) ~= "table" then error("missing") end

        for classIdx = 1, table.getn(RT_BLESS_CLASSES) do
            local className = RT_BLESS_CLASSES[classIdx][1]
            local ppData = nil
            local buckets = RT_PPGetClassBuckets(ppAssign, className, classIdx)
            for i = 1, table.getn(buckets) do
                if type(buckets[i]) == "table" then
                    ppData = buckets[i]
                    break
                end
            end

            if ppData then
                local assign = RT_DB.blessings.classAssign[className] or {}
                local paladin, blessing = RT_PPExtractAssignment(ppData)
                if paladin ~= "" then
                    assign.pala = paladin
                end
                local idx = RT_PPBlessingToIdx(blessing)
                if idx then
                    assign.blessIdx = idx
                end
                RT_DB.blessings.classAssign[className] = assign
            end
        end
    end)

    if ok then
        RT_BlessingsDisplay()
        if status then status:SetText(RT_ColorOK(RT_Text("bless_sync_pp_ok") .. " ← PP")) end
    else
        if tostring(err) == "missing" then
            if status then status:SetText(RT_ColorErr(RT_Text("bless_sync_pp_missing"))) end
        else
            if status then status:SetText(RT_ColorErr(RT_Text("bless_sync_pp_fail", {msg=tostring(err)}))) end
        end
    end
end

-- Retourne la liste des Paladins présents dans le roster (ou raid en direct)
local function RT_GetPaladinsInRaid()
    local palas = {}
    local seen  = {}

    -- Live raid en priorité
    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if nRaid > 0 then
        for i = 1, nRaid do
            local name, rank, sg, level, race, class = GetRaidRosterInfo(i)
            local unitClass = nil
            if UnitClass then
                local c1, c2 = UnitClass("raid" .. i)
                unitClass = RT_NormalizeClassName(c2 or c1 or "")
            end
            local cls = RT_NormalizeClassName(unitClass or class or "")
            if name and cls == "Paladin" and not seen[name] then
                seen[name] = true
                table.insert(palas, name)
            end
        end
    else
        local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
        local pName = UnitName and UnitName("player") or nil
        local pCls = ""
        if UnitClass then
            local c1, c2 = UnitClass("player")
            pCls = RT_NormalizeClassName(c2 or c1 or "")
        end
        if pName and pCls == "Paladin" and not seen[pName] then
            seen[pName] = true
            table.insert(palas, pName)
        end
        for i = 1, nParty do
            local u = "party" .. i
            local name = UnitName and UnitName(u) or nil
            local cls = ""
            if UnitClass then
                local cc1, cc2 = UnitClass(u)
                cls = RT_NormalizeClassName(cc2 or cc1 or "")
            end
            if name and cls == "Paladin" and not seen[name] then
                seen[name] = true
                table.insert(palas, name)
            end
        end
    end

    -- Compléter depuis le roster importé
    for _, player in pairs(RT_DB and RT_DB.roster or {}) do
        local cls = RT_NormalizeClassName(player.class or "")
        local nm  = player.name  or ""
        if cls == "Paladin" and nm ~= "" and not seen[nm] then
            seen[nm] = true
            table.insert(palas, nm)
        end
    end
    return palas
end

-- Retourne tous les joueurs présents dans le raid/groupe (pour ciblage 10min)
local function RT_GetAllRaidPlayers()
    local players = {}
    local seen = {}
    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if nRaid > 0 then
        for i = 1, nRaid do
            local name = GetRaidRosterInfo(i)
            if name and not seen[name] then
                seen[name] = true
                table.insert(players, name)
            end
        end
    else
        local pName = UnitName and UnitName("player") or nil
        if pName and not seen[pName] then
            seen[pName] = true
            table.insert(players, pName)
        end
        local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
        for i = 1, nParty do
            local name = UnitName and UnitName("party"..i) or nil
            if name and not seen[name] then
                seen[name] = true
                table.insert(players, name)
            end
        end
    end
    -- Compléter depuis le roster importé
    if RT_DB and RT_DB.roster then
        for nm, _ in pairs(RT_DB.roster) do
            if nm ~= "" and not seen[nm] then
                seen[nm] = true
                table.insert(players, nm)
            end
        end
    end
    table.sort(players)
    return players
end

-- Construit un map classe → liste de joueurs (roster + raid live)
RT_BuildClassMap = function()
    local map = {}

    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if nRaid > 0 then
        for i = 1, nRaid do
            local name, rank, sg, level, race, class = GetRaidRosterInfo(i)
            local cls = RT_NormalizeClassName(class or "")
            if name and cls ~= "" then
                map[cls] = map[cls] or {}
                table.insert(map[cls], name)
            end
        end
    else
        local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
        local pName = UnitName and UnitName("player") or nil
        local pCls = ""
        if UnitClass then
            local c1, c2 = UnitClass("player")
            pCls = RT_NormalizeClassName(c2 or c1 or "")
        end
        if pName and pCls ~= "" then
            map[pCls] = map[pCls] or {}
            table.insert(map[pCls], pName)
        end
        for i = 1, nParty do
            local u = "party" .. i
            local name = UnitName and UnitName(u) or nil
            local cls = ""
            if UnitClass then
                local cc1, cc2 = UnitClass(u)
                cls = RT_NormalizeClassName(cc2 or cc1 or "")
            end
            if name and cls ~= "" then
                map[cls] = map[cls] or {}
                table.insert(map[cls], name)
            end
        end

        for _, player in pairs(RT_DB and RT_DB.roster or {}) do
            local cls = RT_NormalizeClassName(player.class or "")
            local nm  = player.name  or ""
            if cls ~= "" and nm ~= "" then
                map[cls] = map[cls] or {}
                table.insert(map[cls], nm)
            end
        end
    end
    return map
end

-- Compat SetBackdrop : vanilla 1.12 a SetBackdrop natif, Classic 1.14+ requiert BackdropTemplateMixin
function RT_PatchBackdrop(frame)
    if not frame then return end
    if not frame.SetBackdrop then
        if BackdropTemplateMixin then
            Mixin(frame, BackdropTemplateMixin)
        end
    end
end

local RT_UI_BUILT = nil

RT_ALL_PANELS = RT_ALL_PANELS or {}

local function RT_CreatePanel(panelName)
    local panel = CreateFrame("Frame", panelName, RT_MainFrame)
    panel:SetWidth(730)
    panel:SetHeight(452)
    panel:SetPoint("TOP", RT_MainFrame, "TOP", 0, -92)
    RT_ALL_PANELS[panelName] = panel
    -- Fond subtil de panel
    RT_PatchBackdrop(panel)
    panel:SetBackdrop({
        bgFile  = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.03, 0.02, 0.06, 0.88)
    panel:SetBackdropBorderColor(0.55, 0.42, 0.04, 0.55)
    panel:Hide()
    return panel
end

function RT_BuildUI()
    if RT_UI_BUILT then return end
    if not RT_MainFrame then return end

    RT_MainFrame:SetWidth(760)
    RT_MainFrame:SetHeight(562)
    RT_MainFrame:ClearAllPoints()
    RT_MainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    RT_MainFrame:SetFrameStrata("DIALOG")
    RT_MainFrame:SetToplevel(true)
    RT_MainFrame:SetClampedToScreen(true)
    RT_MainFrame:SetMovable(true)
    RT_MainFrame:EnableMouse(true)
    RT_MainFrame:RegisterForDrag("LeftButton")
    RT_MainFrame:SetScript("OnDragStart", function() RT_MainFrame:StartMoving() end)
    RT_MainFrame:SetScript("OnDragStop", function()
        RT_MainFrame:StopMovingOrSizing()
        RT_SaveMainFramePosition()
    end)
    RT_PatchBackdrop(RT_MainFrame)
    RT_MainFrame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 28,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    RT_MainFrame:SetBackdropColor(0.03, 0.02, 0.06, 1.0)
    RT_MainFrame:SetBackdropBorderColor(0.72, 0.55, 0.08, 1.0)

    -- Bande de fond header (noir-violet profond)
    local headerBg = RT_MainFrame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetPoint("TOPLEFT",  RT_MainFrame, "TOPLEFT",  8, -8)
    headerBg:SetPoint("TOPRIGHT", RT_MainFrame, "TOPRIGHT", -8, -8)
    headerBg:SetHeight(30)
    headerBg:SetTexture(0.05, 0.04, 0.10, 1.0)

    -- Liseré or sous le header (séparateur unique)
    local headerLine = RT_MainFrame:CreateTexture(nil, "ARTWORK")
    headerLine:SetPoint("TOPLEFT",  RT_MainFrame, "TOPLEFT",  8, -38)
    headerLine:SetPoint("TOPRIGHT", RT_MainFrame, "TOPRIGHT", -8, -38)
    headerLine:SetHeight(2)
    headerLine:SetTexture(0.90, 0.72, 0.05, 1.0)

    -- ── Logo [RT] — bouton cliquable qui ouvre le mini-menu ──
    local logoBtn = CreateFrame("Button", "RT_LogoBtn", RT_MainFrame)
    logoBtn:SetPoint("TOPLEFT", RT_MainFrame, "TOPLEFT", 10, -9)
    logoBtn:SetWidth(30)
    logoBtn:SetHeight(26)
    logoBtn:EnableMouse(true)

    local logoBorder = logoBtn:CreateTexture(nil, "BACKGROUND")
    logoBorder:SetAllPoints(logoBtn)
    logoBorder:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    logoBorder:SetVertexColor(0.85, 0.65, 0.06, 1.0)

    local logoFill = logoBtn:CreateTexture(nil, "BORDER")
    logoFill:SetPoint("TOPLEFT",     logoBtn, "TOPLEFT",     2,  -2)
    logoFill:SetPoint("BOTTOMRIGHT", logoBtn, "BOTTOMRIGHT", -2,  2)
    logoFill:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    logoFill:SetVertexColor(0.04, 0.03, 0.09, 1.0)

    local logoHL = logoBtn:CreateTexture(nil, "HIGHLIGHT")
    logoHL:SetAllPoints(logoBtn)
    logoHL:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    logoHL:SetVertexColor(0.95, 0.75, 0.1, 0.35)

    local logoText = logoBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    logoText:SetAllPoints(logoBtn)
    logoText:SetJustifyH("CENTER")
    logoText:SetText("|cffFFD700RT|r")

    RT_AttachSimpleTooltip(logoBtn, "Cliquer pour ouvrir le menu Raid Tool (Mode, RL, Langue)")

    -- ── Mini-menu [RT] — popup flottant ───────────────────────
    local rtMenu = CreateFrame("Frame", "RT_LogoMenu", UIParent)
    rtMenu:SetWidth(346)
    rtMenu:SetHeight(40)
    rtMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    rtMenu:SetFrameLevel(100)
    rtMenu:Hide()
    RT_PatchBackdrop(rtMenu)
    rtMenu:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3},
    })
    rtMenu:SetBackdropColor(0.04, 0.03, 0.08, 0.97)
    rtMenu:SetBackdropBorderColor(0.90, 0.72, 0.05, 1.0)
    rtMenu:EnableMouse(true)

    -- Positionner sous le logo (mis à jour à chaque ouverture)
    local function RT_OpenLogoMenu()
        local x, y = logoBtn:GetCenter()
        rtMenu:ClearAllPoints()
        rtMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x - 6, y - 4)
        rtMenu:Show()
    end

    logoBtn:SetScript("OnClick", function()
        if rtMenu:IsShown() then
            rtMenu:Hide()
        else
            RT_OpenLogoMenu()
        end
    end)

    -- Fermer quand la souris quitte le menu (1.12 : pas de self dans OnUpdate)
    rtMenu:SetScript("OnLeave", function()
        -- Petit délai pour éviter de fermer pendant qu'on survole un bouton enfant
        -- On utilise juste le toggle du logoBtn pour ouvrir/fermer
    end)

    -- Contenu du mini-menu : Mode + RL + Lang
    local menuModeLabel = rtMenu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    menuModeLabel:SetPoint("TOPLEFT", rtMenu, "TOPLEFT", 8, -14)
    menuModeLabel:SetText("|cff888888Mode :|r")

    local function makeMenuBtn(name, label, w, tooltipTxt, onClick, r, g, b)
        local btn = CreateFrame("Button", name, rtMenu, "UIPanelButtonTemplate")
        btn:SetWidth(w)
        btn:SetHeight(22)
        btn:SetText(label)
        local fs = btn:GetFontString()
        if fs and r then fs:SetTextColor(r, g, b) end
        btn:SetScript("OnClick", function()
            onClick()
            rtMenu:Hide()
        end)
        RT_AttachSimpleTooltip(btn, tooltipTxt)
        return btn
    end

    local menuGuild = makeMenuBtn("RT_ModeBtnGuild", "Guild", 52,
        "Mode Guild : contrôle total (défaut)",
        function() RT_SetMode("guild") end, 0.4, 1.0, 0.5)
    menuGuild:SetPoint("TOPLEFT", rtMenu, "TOPLEFT", 50, -9)

    local menuPUG = makeMenuBtn("RT_ModeBtnPUG", "PUG", 46,
        "Mode PUG : annonces auto boss/groupes",
        function() RT_SetMode("pug") end, 1.0, 0.7, 0.1)
    menuPUG:SetPoint("LEFT", menuGuild, "RIGHT", 4, 0)

    local menuRL = makeMenuBtn("RT_ModeBtnRL", "RL", 36,
        "Mode Raid Leader : RL panel auto-visible",
        function() RT_SetMode("rl") end, 1.0, 0.4, 0.4)
    menuRL:SetPoint("LEFT", menuPUG, "RIGHT", 4, 0)

    -- Séparateur vertical
    local menuSep = rtMenu:CreateTexture(nil, "ARTWORK")
    menuSep:SetPoint("LEFT", menuRL, "RIGHT", 6, 0)
    menuSep:SetWidth(1)
    menuSep:SetHeight(28)
    menuSep:SetTexture(0.5, 0.4, 0.1, 0.6)

    -- [RL: OFF]
    local menuRLOff = CreateFrame("Button", "RT_RLHeaderToggle", rtMenu, "UIPanelButtonTemplate")
    menuRLOff:SetPoint("LEFT", menuSep, "RIGHT", 6, 0)
    menuRLOff:SetWidth(64)
    menuRLOff:SetHeight(22)
    menuRLOff:SetText("RL: OFF")
    local rlTex = menuRLOff:GetNormalTexture()
    if rlTex then rlTex:SetVertexColor(0.90, 0.72, 0.05) end
    menuRLOff:SetScript("OnClick", function()
        RT_RLTogglePersist()
        rtMenu:Hide()
    end)
    RT_AttachSimpleTooltip(menuRLOff, "Toggle persistent RL panel.")

    -- [Lang:FR]
    local menuLang = CreateFrame("Button", "RT_PopupLangBtn", rtMenu, "UIPanelButtonTemplate")
    menuLang:SetPoint("LEFT", menuRLOff, "RIGHT", 4, 0)
    menuLang:SetWidth(66)
    menuLang:SetHeight(22)
    menuLang:SetText("Lang:FR")
    local langTex = menuLang:GetNormalTexture()
    if langTex then langTex:SetVertexColor(0.90, 0.72, 0.05) end
    menuLang:SetScript("OnClick", function()
        RT_CycleAnnouncementLang()
        -- Ne ferme pas le menu pour pouvoir rechanger
    end)
    RT_AttachSimpleTooltip(menuLang, "Changer la langue des annonces (FR/EN)")

    -- ── Header : titre centré + [Avancé▼] + [X] ──────────────
    local title = RT_MainFrame:CreateFontString("RT_Title", "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", RT_MainFrame, "TOP", 0, -18)
    title:SetText("|cffAA66FFRaid Tool|r |cffFFD700v2|r")
    title:SetTextColor(1.0, 1.0, 1.0)

    -- Fallback si Dashboard.lua n'a pas chargé
    if not RT_ToggleDisplayMode then
        RT_DISPLAY_MODE = "advanced"
        RT_ToggleDisplayMode = function() end
        RT_SetDisplayMode = RT_SetDisplayMode or function() end
    end

    -- [Avancé▼ / Simple▼] — toggle Dashboard
    local modeToggleBtn = CreateFrame("Button", "RT_ModeToggleBtn", RT_MainFrame, "UIPanelButtonTemplate")
    modeToggleBtn:SetPoint("TOPRIGHT", RT_MainFrame, "TOPRIGHT", -100, -12)
    modeToggleBtn:SetWidth(86)
    modeToggleBtn:SetHeight(20)
    modeToggleBtn:SetText("|cffFFD700Avancé ▼|r")
    RT_AttachSimpleTooltip(modeToggleBtn, "Basculer Dashboard (Simple) / Onglets (Avancé).")
    modeToggleBtn:SetScript("OnClick", function() RT_ToggleDisplayMode() end)

    local closeBtn = CreateFrame("Button", "RT_CloseBtn", RT_MainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", RT_MainFrame, "TOPRIGHT", -2, -2)

    -- Zone de drag sur toute la bande titre
    local dragZone = CreateFrame("Frame", "RT_DragZone", RT_MainFrame)
    dragZone:SetPoint("TOPLEFT",  RT_MainFrame, "TOPLEFT",  46, -8)
    dragZone:SetPoint("TOPRIGHT", RT_MainFrame, "TOPRIGHT", -190, -8)
    dragZone:SetHeight(28)
    dragZone:EnableMouse(true)
    dragZone:RegisterForDrag("LeftButton")
    dragZone:SetScript("OnDragStart", function() RT_MainFrame:StartMoving() end)
    dragZone:SetScript("OnDragStop", function()
        RT_MainFrame:StopMovingOrSizing()
        RT_SaveMainFramePosition()
    end)

    -- sepTitle supprimé (causait une double ligne sous le header)

    -- Bandes de fond des onglets (2 rangées, sous le header à y=-40)
    local tabBg = RT_MainFrame:CreateTexture(nil, "BACKGROUND")
    tabBg:SetPoint("TOPLEFT",  RT_MainFrame, "TOPLEFT",  8, -40)
    tabBg:SetPoint("TOPRIGHT", RT_MainFrame, "TOPRIGHT", -8, -40)
    tabBg:SetHeight(50)
    tabBg:SetTexture(0.05, 0.04, 0.10, 1.0)

    -- Séparateur entre les 2 rangées de tabs
    local tabMidLine = RT_MainFrame:CreateTexture(nil, "ARTWORK")
    tabMidLine:SetPoint("TOPLEFT",  RT_MainFrame, "TOPLEFT",  8, -62)
    tabMidLine:SetPoint("TOPRIGHT", RT_MainFrame, "TOPRIGHT", -8, -62)
    tabMidLine:SetHeight(1)
    tabMidLine:SetTexture(0.30, 0.22, 0.02, 0.5)

    RT_TAB_BUTTONS = {}

    -- Rangée 1 (y=-48) : Roster Boss Groups Buffs Loot Import
    local row1Defs = {
        {"Roster",  "Roster",  70},
        {"Boss",    "Boss",    58},
        {"Groups",  "Groups",  66},
        {"Buffs",   "Buffs",   58},
        {"Loot",    "Loot",    54},
        {"Import",  "Import",  66},
    }
    -- Rangée 2 (y=-70) : Strats Check Timer Invite Présences
    local row2Defs = {
        {"Notes",   "Strats",   60},
        {"Check",   "Check/CDs",80},
        {"Timer",   "Timer",    54},
        {"Invite",  "Invite",   54},
        {"Attend",  "Présences",72},
    }

    local function makeTab(name, text, width, yRow)
        local b = CreateFrame("Button", "RT_Tab_" .. name, RT_MainFrame, "UIPanelButtonTemplate")
        b:SetWidth(width)
        b:SetHeight(20)
        b:SetText(text)
        RT_TAB_BUTTONS[name] = b
        local n = name
        b:SetScript("OnClick", function() RT_ShowTab(n) end)
        return b
    end

    local row1X = 15
    for di = 1, table.getn(row1Defs) do
        local d = row1Defs[di]
        local b = makeTab(d[1], d[2], d[3])
        b:SetPoint("TOPLEFT", RT_MainFrame, "TOPLEFT", row1X, -41)
        row1X = row1X + d[3] + 4
    end

    -- Cadre invisible pour row2 (pour pouvoir le masquer en mode Simple)
    local tabRow2Frame = CreateFrame("Frame", "RT_TabRow2Frame", RT_MainFrame)
    tabRow2Frame:SetPoint("TOPLEFT", RT_MainFrame, "TOPLEFT", 8, -62)
    tabRow2Frame:SetWidth(744)
    tabRow2Frame:SetHeight(22)

    local row2X = 15
    for di = 1, table.getn(row2Defs) do
        local d = row2Defs[di]
        local b = makeTab(d[1], d[2], d[3])
        b:SetPoint("TOPLEFT", RT_MainFrame, "TOPLEFT", row2X, -63)
        row2X = row2X + d[3] + 4
    end

    local sepTabs = RT_MainFrame:CreateTexture("RT_SepTabs", "ARTWORK")
    sepTabs:SetPoint("TOP", RT_MainFrame, "TOP", 0, -87)
    sepTabs:SetWidth(730)
    sepTabs:SetHeight(2)
    sepTabs:SetTexture(0.80, 0.62, 0.06, 0.8)

    local sepTabs2 = RT_MainFrame:CreateTexture("RT_SepTabs2", "ARTWORK")
    sepTabs2:SetPoint("TOP", RT_MainFrame, "TOP", 0, -89)
    sepTabs2:SetWidth(730)
    sepTabs2:SetHeight(2)
    sepTabs2:SetTexture(0.90, 0.72, 0.05, 0.3)

    -- Panel Dashboard (mode Simple)
    local dashPanel = CreateFrame("Frame", "RT_Panel_Dashboard", RT_MainFrame)
    dashPanel:SetWidth(776)
    dashPanel:SetHeight(460)
    dashPanel:SetPoint("TOP", RT_MainFrame, "TOP", 0, -92)
    RT_PatchBackdrop(dashPanel)
    dashPanel:SetBackdrop({
        bgFile  = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile= "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true, tileSize=16, edgeSize=22,
        insets={left=6,right=6,top=6,bottom=6},
    })
    dashPanel:SetBackdropColor(0.02, 0.01, 0.05, 0.92)
    dashPanel:SetBackdropBorderColor(0.72, 0.55, 0.08, 0.8)
    dashPanel:Hide()
    RT_ALL_PANELS["RT_Panel_Dashboard"] = dashPanel
    if RT_BuildUIDashboard then RT_BuildUIDashboard(dashPanel) end

    -- Panel Roster
    local rosterPanel = RT_CreatePanel("RT_Panel_Roster")
    local rosterHeader = rosterPanel:CreateFontString("RT_RosterHeader", "OVERLAY", "GameFontNormal")
    rosterHeader:SetPoint("TOPLEFT", rosterPanel, "TOPLEFT", 6, -4)
    rosterHeader:SetText(RT_Text("roster_header"))
    rosterHeader:SetTextColor(0.45, 0.75, 1.0)

    local rosterCount = rosterPanel:CreateFontString("RT_RosterCount", "OVERLAY", "GameFontDisable")
    rosterCount:SetPoint("TOPRIGHT", rosterPanel, "TOPRIGHT", -6, -4)
    rosterCount:SetText("")

    local rosterScroll = CreateFrame("ScrollFrame", "RT_RosterScrollFrame", rosterPanel, "UIPanelScrollFrameTemplate")
    rosterScroll:SetPoint("TOPLEFT", rosterPanel, "TOPLEFT", 6, -22)
    rosterScroll:SetWidth(718)
    rosterScroll:SetHeight(420)

    local rosterText = CreateFrame("EditBox", "RT_RosterText", rosterScroll)
    rosterText:SetMultiLine(true)
    rosterText:SetAutoFocus(false)
    rosterText:SetFontObject(GameFontHighlightSmall)
    rosterText:SetWidth(690)
    rosterText:SetHeight(1200)
    rosterText:SetText("")
    rosterText:EnableMouse(false)
    rosterText:SetScript("OnEscapePressed", function() rosterText:ClearFocus() end)
    rosterText:SetScript("OnTextChanged", function()
        RT_RosterScrollFrame:UpdateScrollChildRect()
    end)
    rosterScroll:SetScrollChild(rosterText)

    -- Panel Groups
    local groupsPanel = RT_CreatePanel("RT_Panel_Groups")
    local groupsTitle = groupsPanel:CreateFontString("RT_GroupsTitle", "OVERLAY", "GameFontNormal")
    groupsTitle:SetPoint("TOPLEFT", groupsPanel, "TOPLEFT", 6, -4)
    groupsTitle:SetText(RT_Text("groups_title"))
    groupsTitle:SetTextColor(0.4, 0.95, 0.4)

    local groupsHint = groupsPanel:CreateFontString("RT_GroupsHint", "OVERLAY", "GameFontDisable")
    groupsHint:SetPoint("TOPLEFT", groupsPanel, "TOPLEFT", 6, -20)
    groupsHint:SetText(RT_Text("groups_hint"))

    local gRefresh = CreateFrame("Button", "RT_GroupsRefreshBtn", groupsPanel, "UIPanelButtonTemplate")
    gRefresh:SetPoint("TOPLEFT", groupsPanel, "TOPLEFT", 6, -38)
    gRefresh:SetWidth(120)
    gRefresh:SetHeight(22)
    gRefresh:SetText(RT_Text("btn_refresh_raid"))
    gRefresh:SetScript("OnClick", function() RT_GroupRefreshFromRaid() end)
    local gRefreshTex = gRefresh:GetNormalTexture()
    if gRefreshTex then gRefreshTex:SetVertexColor(0.45, 0.8, 1.0) end

    local gGen = CreateFrame("Button", "RT_GroupsGenerateBtn", groupsPanel, "UIPanelButtonTemplate")
    gGen:SetPoint("LEFT", gRefresh, "RIGHT", 4, 0)
    gGen:SetWidth(120)
    gGen:SetHeight(22)
    gGen:SetText(RT_Text("btn_adapter_groupes"))
    gGen:SetScript("OnClick", function() RT_GroupGenerateAutoPlan() end)
    local gGenTex = gGen:GetNormalTexture()
    if gGenTex then gGenTex:SetVertexColor(0.6, 0.9, 0.5) end

    local gInvite = CreateFrame("Button", "RT_GroupsInviteBtn", groupsPanel, "UIPanelButtonTemplate")
    gInvite:SetPoint("LEFT", gGen, "RIGHT", 4, 0)
    gInvite:SetWidth(95)
    gInvite:SetHeight(22)
    gInvite:SetText(RT_Text("btn_invite_plan"))
    gInvite:SetScript("OnClick", function() RT_GroupInvitePlan() end)

    local gApply = CreateFrame("Button", "RT_GroupsApplyBtn", groupsPanel, "UIPanelButtonTemplate")
    gApply:SetPoint("LEFT", gInvite, "RIGHT", 4, 0)
    gApply:SetWidth(120)
    gApply:SetHeight(22)
    gApply:SetText(RT_Text("btn_apply_groups"))
    gApply:SetScript("OnClick", function() RT_GroupApplyNow(false) end)

    local gAuto = CreateFrame("Button", "RT_GroupsAutoBtn", groupsPanel, "UIPanelButtonTemplate")
    gAuto:SetPoint("LEFT", gApply, "RIGHT", 4, 0)
    gAuto:SetWidth(82)
    gAuto:SetHeight(22)
    gAuto:SetText("Auto: ON")
    gAuto:SetScript("OnClick", function() RT_GroupToggleAutoApply() end)

    local groupsStatus = groupsPanel:CreateFontString("RT_GroupsStatus", "OVERLAY", "GameFontHighlightSmall")
    groupsStatus:SetPoint("TOPLEFT", groupsPanel, "TOPLEFT", 6, -62)
    groupsStatus:SetText("")
    groupsStatus:SetTextColor(0.8, 0.8, 0.8)

    local groupsCount = groupsPanel:CreateFontString("RT_GroupsCount", "OVERLAY", "GameFontDisable")
    groupsCount:SetPoint("TOPRIGHT", groupsPanel, "TOPRIGHT", -8, -20)
    groupsCount:SetText("")

    local groupsSep = groupsPanel:CreateTexture(nil, "ARTWORK")
    groupsSep:SetPoint("TOPLEFT", groupsPanel, "TOPLEFT", 6, -78)
    groupsSep:SetWidth(718)
    groupsSep:SetHeight(1)
    groupsSep:SetTexture(1, 1, 1, 0.15)

    local function makeGroupBox(groupIdx, x, y)
        local title = groupsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", groupsPanel, "TOPLEFT", x, y)
        title:SetText(RT_Text("group_label", {n=groupIdx}))
        title:SetTextColor(1, 0.82, 0)

        -- Label de rôle du groupe (mis à jour par RT_GroupDisplay)
        local roleTag = groupsPanel:CreateFontString("RT_GroupRoleTag" .. groupIdx, "OVERLAY", "GameFontHighlightSmall")
        roleTag:SetPoint("LEFT", title, "RIGHT", 6, 0)
        roleTag:SetText("")

        local top = y - 14
        for slotIdx = 1, 5 do
            local key = groupIdx .. "_" .. slotIdx
            local b = CreateFrame("Button", nil, groupsPanel, "UIPanelButtonTemplate")
            b:SetPoint("TOPLEFT", groupsPanel, "TOPLEFT", x, top - (slotIdx - 1) * 15)
            b:SetWidth(330)
            b:SetHeight(14)
            b:SetText("Empty")
            local g, s = groupIdx, slotIdx
            b:SetScript("OnClick", function()
                RT_GroupEnsureDB()
                local grps  = RT_DB.groupPlanner.plan.groups or {}
                local name  = (grps[g] or {})[s] or ""
                local drag  = RT_GROUP_DRAG_SOURCE

                if drag then
                    -- Mode deplacement actif
                    if drag.g == g and drag.s == s then
                        -- Meme slot : annule la selection
                        RT_GroupCancelDrag()
                    else
                        -- Autre slot : deplace/echange
                        RT_GroupMoveSlot(drag.g, drag.s, g, s)
                    end
                else
                    if name ~= "" then
                        -- Joueur present : entrer en mode deplacement
                        RT_GROUP_DRAG_SOURCE = {g=g, s=s, name=name}
                        RT_GroupDisplay()
                    else
                        -- Slot vide : ouvrir editeur
                        RT_GroupOpenSlotEditor(g, s)
                    end
                end
            end)
            RT_GROUP_SLOT_BTNS[key] = b
        end
    end

    makeGroupBox(1,  8, -82)
    makeGroupBox(2, 370, -82)
    makeGroupBox(3,  8, -170)
    makeGroupBox(4, 370, -170)
    makeGroupBox(5,  8, -258)
    makeGroupBox(6, 370, -258)
    makeGroupBox(7,  8, -346)
    makeGroupBox(8, 370, -346)

    local slotPopup = CreateFrame("Frame", "RT_GroupSlotPopup", groupsPanel)
    slotPopup:SetWidth(280)
    slotPopup:SetHeight(230)
    slotPopup:SetPoint("CENTER", groupsPanel, "CENTER", 0, 0)
    slotPopup:SetFrameStrata("TOOLTIP")
    RT_PatchBackdrop(slotPopup)
    slotPopup:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets = { left=4, right=4, top=4, bottom=4 },
    })
    slotPopup:Hide()

    local spTitle = slotPopup:CreateFontString("RT_GroupSlotPopupTitle", "OVERLAY", "GameFontNormal")
    spTitle:SetPoint("TOPLEFT", slotPopup, "TOPLEFT", 8, -8)
    spTitle:SetText(RT_Text("slot_group_lbl"))
    spTitle:SetTextColor(1, 0.82, 0)

    local spEdit = CreateFrame("EditBox", "RT_GroupSlotEdit", slotPopup, "InputBoxTemplate")
    spEdit:SetPoint("TOPLEFT", slotPopup, "TOPLEFT", 8, -28)
    spEdit:SetWidth(180)
    spEdit:SetHeight(20)
    spEdit:SetAutoFocus(false)
    spEdit:SetScript("OnTextChanged", function() RT_GroupSlotEditorRefresh() end)
    spEdit:SetScript("OnEnterPressed", function() RT_GroupSlotEditorConfirm() end)
    spEdit:SetScript("OnEscapePressed", function() RT_GroupCloseSlotEditor() end)

    local spClear = CreateFrame("Button", nil, slotPopup, "UIPanelButtonTemplate")
    spClear:SetPoint("LEFT", spEdit, "RIGHT", 6, 0)
    spClear:SetWidth(78)
    spClear:SetHeight(20)
    spClear:SetText(RT_Text("btn_clear_slot"))
    spClear:SetScript("OnClick", function() RT_GroupSlotEditorClear() end)

    for i = 1, 8 do
        local pb = CreateFrame("Button", "RT_GroupSlotPick" .. i, slotPopup, "UIPanelButtonTemplate")
        pb:SetPoint("TOPLEFT", slotPopup, "TOPLEFT", 8, -54 - (i - 1) * 18)
        pb:SetWidth(264)
        pb:SetHeight(16)
        pb:SetText("")
        pb:Hide()
    end

    local spOk = CreateFrame("Button", nil, slotPopup, "UIPanelButtonTemplate")
    spOk:SetPoint("BOTTOMRIGHT", slotPopup, "BOTTOMRIGHT", -70, 8)
    spOk:SetWidth(60)
    spOk:SetHeight(20)
    spOk:SetText("OK")
    spOk:SetScript("OnClick", function() RT_GroupSlotEditorConfirm() end)

    local spCancel = CreateFrame("Button", nil, slotPopup, "UIPanelButtonTemplate")
    spCancel:SetPoint("LEFT", spOk, "RIGHT", 4, 0)
    spCancel:SetWidth(60)
    spCancel:SetHeight(20)
    spCancel:SetText(RT_Text("picker_close"))
    spCancel:SetScript("OnClick", function() RT_GroupCloseSlotEditor() end)

    -- ── Panel Boss v2 ─────────────────────────────────────────
    local bossPanel = RT_CreatePanel("RT_Panel_Boss")
    local bossTitle = bossPanel:CreateFontString("RT_BossPanelTitle", "OVERLAY", "GameFontNormal")
    bossTitle:SetPoint("TOPLEFT", bossPanel, "TOPLEFT", 6, -4)
    bossTitle:SetText(RT_Text("ui_boss_sheet_title"))
    bossTitle:SetTextColor(1.0, 0.45, 0.2)

    -- Fonds subtils pour mieux séparer les zones d'action
    local bossTopBlock = bossPanel:CreateTexture(nil, "BACKGROUND")
    bossTopBlock:SetPoint("TOPLEFT", bossPanel, "TOPLEFT", 6, -30)
    bossTopBlock:SetWidth(718)
    bossTopBlock:SetHeight(220)
    bossTopBlock:SetTexture(0.12, 0.05, 0.04, 0.20)

    local bossBottomBlock = bossPanel:CreateTexture(nil, "BACKGROUND")
    bossBottomBlock:SetPoint("TOPLEFT", bossPanel, "TOPLEFT", 6, -286)
    bossBottomBlock:SetWidth(718)
    bossBottomBlock:SetHeight(158)
    bossBottomBlock:SetTexture(0.04, 0.08, 0.10, 0.18)

    -- Helpers locaux pour créer des éléments réutilisables -----
    local function bLabel(parent, text, x, y, name)
        local lbl = parent:CreateFontString(name, "OVERLAY", "GameFontDisable")
        lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        lbl:SetText(text)
        return lbl
    end
    local function bSep(parent, y)
        local s = parent:CreateTexture(nil, "ARTWORK")
        s:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y)
        s:SetWidth(718)
        s:SetHeight(1)
        s:SetTexture(1,1,1,0.15)
    end
    -- Crée un bouton de slot (player picker) et l'enregistre
    local function bSlot(parent, key, slotKey, slotIdx, role, x, y, w)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        btn:SetWidth(w or 100)
        btn:SetHeight(20)
        btn:SetText("---")
        local fs = btn:GetFontString()
        if fs then fs:SetTextColor(0.55, 0.55, 0.55) end
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local sk, si, rf = slotKey, slotIdx, role
        btn:SetScript("OnClick", function()
            if sk == "tanks" and arg1 == "RightButton" then
                RT_BossOpenMarkerPicker(si)
                return
            end
            RT_BossOpenSlotPicker(sk, si, rf)
        end)
        RT_BOSS_SLOT_BTNS[key] = btn
        -- Bouton X pour vider
        local xBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        xBtn:SetPoint("LEFT", btn, "RIGHT", 2, 0)
        xBtn:SetWidth(18)
        xBtn:SetHeight(20)
        xBtn:SetText("x")
        local sk2, si2 = slotKey, slotIdx
        xBtn:SetScript("OnClick", function() RT_BossClearSlot(sk2, si2) end)
        RT_BOSS_SLOT_BTNS[key .. "_x"] = xBtn
        return btn
    end

    -- Ligne 1 : Raid / Boss / boutons principaux ---------------
    local raidBtn = CreateFrame("Button", "RT_BossRaidBtn", bossPanel, "UIPanelButtonTemplate")
    raidBtn:SetPoint("TOPLEFT", bossPanel, "TOPLEFT", 6, -4)
    raidBtn:SetWidth(140)
    raidBtn:SetHeight(22)
    raidBtn:SetText("-- Raid --")
    raidBtn:SetScript("OnClick", function()
        local p = getglobal("RT_RaidPickerPopup")
        if p then
            if p:IsShown() then p:Hide() else RT_PopupBringToFront(p) end
        end
    end)

    local bossSelBtn = CreateFrame("Button", "RT_BossBossBtn", bossPanel, "UIPanelButtonTemplate")
    bossSelBtn:SetPoint("LEFT", raidBtn, "RIGHT", 2, 0)
    bossSelBtn:SetWidth(140)
    bossSelBtn:SetHeight(22)
    bossSelBtn:SetText("-- Boss --")
    bossSelBtn:SetScript("OnClick", function()
        local p = getglobal("RT_BossPickerPopup")
        if p then
            -- Peuple le picker avec les boss du raid courant
            local raid = nil
            for rIdx2 = 1, table.getn(RT_VANILLA_RAIDS) do
                if rIdx2 == RT_BOSS_STATE.raidIdx then raid = RT_VANILLA_RAIDS[rIdx2]; break end
            end
            local buttons = RT_BOSS_SLOT_BTNS["_bossbtns_"] or {}
            -- Bouton 1 : toujours Trash Mob
            local b1 = buttons[1]
            if b1 then
                b1:SetText("|cffAAAAAA[" .. RT_Text("trash_mob") .. "]|r")
                b1:SetScript("OnClick", function() RT_BossSelectBoss(RT_Text("trash_mob")); end)
                b1:Show()
            end
            -- Boutons 2-20 : vrais boss du raid (décalés de 1)
            local visibleCount = 1  -- Trash Mob toujours visible
            for i = 2, 20 do
                local b = buttons[i]
                if b then
                    local bossName = raid and raid.bosses and raid.bosses[i - 1]
                    if bossName then
                        b:SetText(bossName)
                        local bn = bossName
                        b:SetScript("OnClick", function()
                            RT_BossSelectBoss(bn)
                        end)
                        b:Show()
                        visibleCount = visibleCount + 1
                    else
                        b:Hide()
                    end
                end
            end
            -- Ajuste la hauteur du popup selon le nombre de boss visibles
            local popupH = 24 + visibleCount * 20
            if popupH < 44 then popupH = 44 end
            p:SetHeight(popupH)
            if p:IsShown() then p:Hide() else RT_PopupBringToFront(p) end
        end
    end)

    local bossSaveBtn2 = CreateFrame("Button", nil, bossPanel, "UIPanelButtonTemplate")
    bossSaveBtn2:SetPoint("LEFT", bossSelBtn, "RIGHT", 2, 0)
    bossSaveBtn2:SetWidth(56)
    bossSaveBtn2:SetHeight(22)
    bossSaveBtn2:SetText(RT_Text("btn_save"))
    bossSaveBtn2:SetScript("OnClick", function() RT_BossSaveFromUI() end)

    local bossClearBtn2 = CreateFrame("Button", nil, bossPanel, "UIPanelButtonTemplate")
    bossClearBtn2:SetPoint("LEFT", bossSaveBtn2, "RIGHT", 2, 0)
    bossClearBtn2:SetWidth(66)
    bossClearBtn2:SetHeight(22)
    bossClearBtn2:SetText(RT_Text("btn_clear_slots"))
    bossClearBtn2:SetScript("OnClick", function() RT_BossClearUI() end)

    local bossAddBtn = CreateFrame("Button", nil, bossPanel, "UIPanelButtonTemplate")
    bossAddBtn:SetPoint("LEFT", bossClearBtn2, "RIGHT", 2, 0)
    bossAddBtn:SetWidth(60)
    bossAddBtn:SetHeight(22)
    bossAddBtn:SetText("+Custom")
    bossAddBtn:SetScript("OnClick", function()
        local p = getglobal("RT_BossAddPopup")
        if p then
            if p:IsShown() then p:Hide() else RT_PopupBringToFront(p) end
        end
    end)

    local bossDelBtn = CreateFrame("Button", nil, bossPanel, "UIPanelButtonTemplate")
    bossDelBtn:SetPoint("LEFT", bossAddBtn, "RIGHT", 2, 0)
    bossDelBtn:SetWidth(60)
    bossDelBtn:SetHeight(22)
    bossDelBtn:SetText("-Custom")
    bossDelBtn:SetScript("OnClick", function() RT_BossRemoveCustom() end)

    -- RT_BossLangBtn : fantôme caché (pour RT_UpdateBossOptionsUI qui l'utilise)
    local bossLangBtn = CreateFrame("Button", "RT_BossLangBtn", RT_MainFrame, "UIPanelButtonTemplate")
    bossLangBtn:SetPoint("TOPLEFT", RT_MainFrame, "TOPLEFT", -200, -200)
    bossLangBtn:SetWidth(62)
    bossLangBtn:SetHeight(22)
    bossLangBtn:SetText("Lang:FR")
    bossLangBtn:SetScript("OnClick", function() RT_CycleAnnouncementLang() end)
    bossLangBtn:Hide()

    local bossAutoBtn = CreateFrame("Button", "RT_BossAutoBtn", bossPanel, "UIPanelButtonTemplate")
    bossAutoBtn:SetPoint("LEFT", bossDelBtn, "RIGHT", 2, 0)
    bossAutoBtn:SetWidth(66)
    bossAutoBtn:SetHeight(22)
    bossAutoBtn:SetText("Auto:OFF")
    bossAutoBtn:SetScript("OnClick", function() RT_ToggleBossAutoAnnounce() end)

    local bossImportRaidBtn = CreateFrame("Button", "RT_BossImportRaidBtn", bossPanel, "UIPanelButtonTemplate")
    bossImportRaidBtn:SetPoint("LEFT", bossAutoBtn, "RIGHT", 6, 0)
    bossImportRaidBtn:SetWidth(90)
    bossImportRaidBtn:SetHeight(22)
    bossImportRaidBtn:SetText("Import Raid")
    local bImpTex = bossImportRaidBtn:GetNormalTexture()
    if bImpTex then bImpTex:SetVertexColor(0.4, 1.0, 0.6) end
    bossImportRaidBtn:SetScript("OnClick", function() RT_BossImportFromRoster() end)

    bSep(bossPanel, -30)

    -- Ligne 2 : Tanks -------------------------------------------
    -- Labels tanks = boutons cliquables pour ouvrir le marker picker
    local function bTankMarkerBtn(idx, x)
        local btn = CreateFrame("Button", "RT_BossTankLbl" .. idx, bossPanel, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", bossPanel, "TOPLEFT", x, -36)
        btn:SetWidth(40)
        btn:SetHeight(20)
        btn:SetText("Tnk " .. idx .. ":")
        local fs = btn:GetFontString()
        if fs then fs:SetTextColor(0.6, 0.6, 0.6) end
        local si = idx
        btn:SetScript("OnClick", function() RT_BossOpenMarkerPicker(si) end)
        return btn
    end
    -- Layout: [Marker(40)] [Slot(80)] [X(18)] gaps=2  x4 → tMinus at 584
    bTankMarkerBtn(1, 6)
    bSlot(bossPanel, "tank_1", "tanks", 1, "Tank", 48, -36, 80)
    bTankMarkerBtn(2, 150)
    bSlot(bossPanel, "tank_2", "tanks", 2, "Tank", 192, -36, 80)
    bTankMarkerBtn(3, 294)
    bSlot(bossPanel, "tank_3", "tanks", 3, "Tank", 336, -36, 80)
    bTankMarkerBtn(4, 438)
    bSlot(bossPanel, "tank_4", "tanks", 4, "Tank", 480, -36, 80)

    local tMinus = CreateFrame("Button", nil, bossPanel, "UIPanelButtonTemplate")
    tMinus:SetPoint("TOPLEFT", bossPanel, "TOPLEFT", 584, -36)
    tMinus:SetWidth(16)
    tMinus:SetHeight(18)
    tMinus:SetText("-")
    tMinus:SetScript("OnClick", function() RT_BossChangeTankSlots(-1) end)

    local tPlus = CreateFrame("Button", nil, bossPanel, "UIPanelButtonTemplate")
    tPlus:SetPoint("LEFT", tMinus, "RIGHT", 2, 0)
    tPlus:SetWidth(16)
    tPlus:SetHeight(18)
    tPlus:SetText("+")
    tPlus:SetScript("OnClick", function() RT_BossChangeTankSlots(1) end)

    local tCountLbl = bossPanel:CreateFontString("RT_BossTankCount", "OVERLAY", "GameFontDisable")
    tCountLbl:SetPoint("LEFT", tPlus, "RIGHT", 4, 0)
    tCountLbl:SetText("(3)")

    bSep(bossPanel, -62)

    -- Lignes 3-6 : Heal slots -----------------------------------
    local function bHealRow(label, slotKey, y)
        bLabel(bossPanel, label, 6, y, "RT_BossLbl_" .. slotKey)

        local minusBtn = CreateFrame("Button", nil, bossPanel, "UIPanelButtonTemplate")
        minusBtn:SetPoint("TOPLEFT", bossPanel, "TOPLEFT", 58, y + 2)
        minusBtn:SetWidth(16)
        minusBtn:SetHeight(18)
        minusBtn:SetText("-")
        local sk1 = slotKey
        minusBtn:SetScript("OnClick", function() RT_BossChangeHealSlots(sk1, -1) end)

        local plusBtn = CreateFrame("Button", nil, bossPanel, "UIPanelButtonTemplate")
        plusBtn:SetPoint("LEFT", minusBtn, "RIGHT", 2, 0)
        plusBtn:SetWidth(16)
        plusBtn:SetHeight(18)
        plusBtn:SetText("+")
        local sk2 = slotKey
        plusBtn:SetScript("OnClick", function() RT_BossChangeHealSlots(sk2, 1) end)

        local countLbl = bossPanel:CreateFontString("RT_BossCount_" .. slotKey, "OVERLAY", "GameFontDisable")
        countLbl:SetPoint("LEFT", plusBtn, "RIGHT", 4, 0)
        countLbl:SetText("(0)")

        local startX = 112
        local spacing = 80
        local slotW = 60
        local maxN = RT_BOSS_HEAL_LIMITS[slotKey] or 1
        for i = 1, maxN do
            local key = slotKey .. "_" .. i
            bSlot(bossPanel, key, slotKey, i, "Heal", startX + (i - 1) * spacing, y + 2, slotW)
        end
    end

    bHealRow("H.Tank1:", "h_tank1", -70)
    bHealRow("H.Tank2:", "h_tank2", -92)
    bHealRow("H.Tank3:", "h_tank3", -114)
    bHealRow("H.Tank4:", "h_tank4", -136)
    bHealRow("H.Raid:",  "h_raid",  -158)
    bHealRow("H.Melee:", "h_melee", -180)
    bHealRow("H.Caster:","h_caster",-202)

    bSep(bossPanel, -220)

    -- Ligne 7 : Note (= strat Notes synchro) -------------------
    bLabel(bossPanel, "Strat:", 6, -228)
    local bossNoteEdit2 = CreateFrame("EditBox", "RT_BossNoteEdit2", bossPanel, "InputBoxTemplate")
    bossNoteEdit2:SetPoint("TOPLEFT", bossPanel, "TOPLEFT", 50, -226)
    bossNoteEdit2:SetWidth(520)
    bossNoteEdit2:SetHeight(20)
    bossNoteEdit2:SetAutoFocus(false)
    bossNoteEdit2:SetMaxLetters(2000)

    -- Bouton "Editer strat" → ouvre Notes tab avec la strat du boss
    local bossEditStratBtn = CreateFrame("Button", "RT_BossEditStratBtn", bossPanel, "UIPanelButtonTemplate")
    bossEditStratBtn:SetPoint("LEFT", bossNoteEdit2, "RIGHT", 4, 0)
    bossEditStratBtn:SetWidth(70)
    bossEditStratBtn:SetHeight(20)
    bossEditStratBtn:SetText("Notes →")
    local besTex = bossEditStratBtn:GetNormalTexture()
    if besTex then besTex:SetVertexColor(0.3, 0.9, 1.0) end
    bossEditStratBtn:SetScript("OnClick", function()
        local stratKey = RT_BossGetStratKey and RT_BossGetStratKey()
        if stratKey then
            RT_ShowTab("Notes")
            RT_NotesLoadKey(stratKey)
        end
    end)

    -- Indicateur de sync
    local bossStratSyncLbl = bossPanel:CreateFontString("RT_BossStratSyncLbl", "OVERLAY", "GameFontDisableSmall")
    bossStratSyncLbl:SetPoint("LEFT", bossEditStratBtn, "RIGHT", 4, 0)
    bossStratSyncLbl:SetWidth(60)
    bossStratSyncLbl:SetText("|cff444444sélectionne un boss|r")

    bSep(bossPanel, -252)

    -- Ligne 8 : Session ----------------------------------------
    bLabel(bossPanel, "Session:", 6, -260)
    local sessEdit = CreateFrame("EditBox", "RT_BossSessionEdit", bossPanel, "InputBoxTemplate")
    sessEdit:SetPoint("TOPLEFT", bossPanel, "TOPLEFT", 60, -258)
    sessEdit:SetWidth(160)
    sessEdit:SetHeight(20)
    sessEdit:SetAutoFocus(false)

    local sessSaveBtn = CreateFrame("Button", nil, bossPanel, "UIPanelButtonTemplate")
    sessSaveBtn:SetPoint("TOPLEFT", bossPanel, "TOPLEFT", 226, -260)
    sessSaveBtn:SetWidth(90)
    sessSaveBtn:SetHeight(22)
    sessSaveBtn:SetText(RT_Text("btn_save_sess"))
    sessSaveBtn:SetScript("OnClick", function() RT_BossSaveSession() end)

    local sessLoadBtn = CreateFrame("Button", nil, bossPanel, "UIPanelButtonTemplate")
    sessLoadBtn:SetPoint("LEFT", sessSaveBtn, "RIGHT", 4, 0)
    sessLoadBtn:SetWidth(90)
    sessLoadBtn:SetHeight(22)
    sessLoadBtn:SetText(RT_Text("btn_load_sess"))
    sessLoadBtn:SetScript("OnClick", function() RT_BossLoadSession() end)

    local bossStatus2 = bossPanel:CreateFontString("RT_BossStatus2", "OVERLAY", "GameFontHighlightSmall")
    bossStatus2:SetPoint("LEFT", sessLoadBtn, "RIGHT", 10, 0)
    bossStatus2:SetText("")
    bossStatus2:SetTextColor(0.8, 0.8, 0.8)

    bSep(bossPanel, -286)

    -- Ligne 9 : Boutons d'annonces raid ------------------------
    local annLabel = bossPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    annLabel:SetPoint("TOPLEFT", bossPanel, "TOPLEFT", 6, -296)
    annLabel:SetText(RT_Text("btn_announce_label"))
    annLabel:SetTextColor(0.7, 0.7, 0.7)

    local function mkAnnBtn(label, xOff, mode, func)
        local b = CreateFrame("Button", nil, bossPanel, "UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT", bossPanel, "TOPLEFT", xOff, -294)
        b:SetWidth(80)
        b:SetHeight(20)
        b:SetText(label)
        if func then
            b:SetScript("OnClick", func)
        else
            local m = mode
            b:SetScript("OnClick", function() RT_RaidAnnounceCommand(m) end)
        end
        return b
    end

    local annAll   = mkAnnBtn("Tout",       68,  "all")
    local annTankM = mkAnnBtn("Tanks+M",    152, "tankmarks")
    local annHeals = mkAnnBtn("Soins",      236, "heals")
    local annBuffs = mkAnnBtn("Buffs",      320, "buffs")
    local annNote  = mkAnnBtn("Note",       404, "note")
    local annStrat = mkAnnBtn("Strat",      488, nil, function() RT_AnnounceCurrentBossStratNote(false) end)
    local annMine  = mkAnnBtn("Mon Attrib", 572, nil, function() RT_AttribCommand() end)

    local function RT_SetBtnTextColor(btn, r, g, b)
        if not btn then return end
        local fs = btn:GetFontString()
        if fs then fs:SetTextColor(r, g, b) end
    end
    RT_SetBtnTextColor(annAll,   1.0, 0.78, 0.18)
    RT_SetBtnTextColor(annTankM, 0.60, 0.85, 1.00)
    RT_SetBtnTextColor(annHeals, 0.50, 1.00, 0.50)
    RT_SetBtnTextColor(annBuffs, 1.00, 0.90, 0.35)
    RT_SetBtnTextColor(annNote,  0.95, 0.70, 0.35)
    RT_SetBtnTextColor(annStrat, 0.40, 1.00, 0.90)
    RT_SetBtnTextColor(annMine,  1.00, 0.85, 0.45)

    bSep(bossPanel, -320)

    -- Ligne 10 : Log des fiches --------------------------------
    local bossLog2 = CreateFrame("ScrollingMessageFrame", "RT_BossLog2", bossPanel)
    bossLog2:SetPoint("TOPLEFT", bossPanel, "TOPLEFT", 6, -324)
    bossLog2:SetWidth(718)
    bossLog2:SetHeight(120)
    bossLog2:SetFontObject(GameFontHighlightSmall)
    bossLog2:SetJustifyH("LEFT")
    bossLog2:SetFading(false)
    bossLog2:SetMaxLines(180)
    RT_PatchBackdrop(bossLog2)
    bossLog2:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    bossLog2:SetBackdropColor(0.02, 0.02, 0.04, 0.65)
    bossLog2:SetBackdropBorderColor(0.35, 0.45, 0.55, 0.70)

    -- Mini panel RL Speedrun (one-click actions) — parent UIParent pour rester visible méme menu fermé
    local rlQuick = CreateFrame("Frame", "RT_RLQuickPanel", UIParent)
    rlQuick:SetWidth(156)
    rlQuick:SetHeight(212)
    rlQuick:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -120, -120)
    rlQuick:SetFrameStrata("DIALOG")
    rlQuick:SetToplevel(true)
    rlQuick:SetClampedToScreen(true)
    rlQuick:SetMovable(true)
    rlQuick:EnableMouse(true)
    rlQuick:RegisterForDrag("LeftButton")
    rlQuick:SetScript("OnDragStart", function() rlQuick:StartMoving() end)
    rlQuick:SetScript("OnDragStop", function() rlQuick:StopMovingOrSizing() end)
    RT_PatchBackdrop(rlQuick)
    rlQuick:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    rlQuick:SetBackdropColor(0.03, 0.04, 0.08, 0.90)
    rlQuick:SetBackdropBorderColor(0.45, 0.55, 0.75, 0.80)
    rlQuick:Hide()

    local rlTitle = rlQuick:CreateFontString("RT_RLQuickTitle", "OVERLAY", "GameFontNormal")
    rlTitle:SetPoint("TOPLEFT", rlQuick, "TOPLEFT", 6, -6)
    rlTitle:SetText(RT_Text("rl_panel_title"))
    rlTitle:SetTextColor(0.60, 0.85, 1.00)

    local rlAutoBtn = CreateFrame("Button", "RT_RLQuickAutoBtn", rlQuick, "UIPanelButtonTemplate")
    rlAutoBtn:SetPoint("TOPLEFT", rlQuick, "TOPLEFT", 6, -24)
    rlAutoBtn:SetWidth(100)
    rlAutoBtn:SetHeight(18)
    rlAutoBtn:SetText(RT_Text("rl_auto_off"))
    rlAutoBtn:SetScript("OnClick", function() RT_RLQuickToggleAuto() end)

    local rlChanLbl = rlQuick:CreateFontString("RT_RLQuickChannelLbl", "OVERLAY", "GameFontHighlightSmall")
    rlChanLbl:SetPoint("LEFT", rlAutoBtn, "RIGHT", 6, 0)
    rlChanLbl:SetWidth(38)
    rlChanLbl:SetJustifyH("LEFT")
    rlChanLbl:SetText("")

    local rlPackBtn = CreateFrame("Button", "RT_RLQuickPackBtn", rlQuick, "UIPanelButtonTemplate")
    rlPackBtn:SetPoint("TOPLEFT", rlQuick, "TOPLEFT", 6, -46)
    rlPackBtn:SetWidth(144)
    rlPackBtn:SetHeight(20)
    rlPackBtn:SetText(RT_Text("rl_pack_btn"))
    rlPackBtn:SetScript("OnClick", function() RT_RLQuickPack(false) end)

    local function mkRLBtn(name, textKey, x, y, cb)
        local b = CreateFrame("Button", name, rlQuick, "UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT", rlQuick, "TOPLEFT", x, y)
        b:SetWidth(70)
        b:SetHeight(18)
        b:SetText(RT_Text(textKey))
        b:SetScript("OnClick", cb)
        return b
    end

    -- Résumé rôles roster
    local rlRoleSummary = rlQuick:CreateFontString("RT_RLRoleSummary", "OVERLAY", "GameFontHighlightSmall")
    rlRoleSummary:SetPoint("TOPLEFT", rlQuick, "TOPLEFT", 6, -70)
    rlRoleSummary:SetWidth(144)
    rlRoleSummary:SetJustifyH("LEFT")
    rlRoleSummary:SetText("|cff888888Roster: --/--/--|r")

    mkRLBtn("RT_RLQuickAttribBtn", "rl_btn_attrib", 6,  -92, function() RT_AttribCommand() end)
    mkRLBtn("RT_RLQuickRaidAllBtn", "rl_btn_raid_all", 80, -92, function() RT_RaidAnnounceCommand("all") end)
    mkRLBtn("RT_RLQuickNoteBtn",   "rl_btn_note",   6, -114, function() RT_RaidAnnounceCommand("note") end)
    mkRLBtn("RT_RLQuickStratBtn",  "rl_btn_strat",  80,-114, function() RT_AnnounceCurrentBossStratNote(false) end)
    mkRLBtn("RT_RLQuickBlessBtn",  "rl_btn_bless",  6, -136, function() RT_BlessingsAnnounce() end)
    mkRLBtn("RT_RLQuickCheckBtn",  "rl_btn_check",  80,-136, function() RT_CheckScanRaid() RT_ShowTab("Check") end)
    mkRLBtn("RT_RLQuickCDsBtn",    "rl_btn_cds",    6, -158, function() RT_RLCooldownToggle() end)

    local rlHelp = rlQuick:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    rlHelp:SetPoint("BOTTOMLEFT", rlQuick, "BOTTOMLEFT", 6, 6)
    rlHelp:SetText("L-Drag")
    rlHelp:SetTextColor(0.6, 0.6, 0.6)

    -- RL Cooldowns frame (movable + resizable) — parent UIParent pour persistance
    RT_RLQuickEnsureSettings()
    local rlCD = CreateFrame("Frame", "RT_RLCDFrame", UIParent)
    rlCD:SetWidth(RT_DB.settings.rlCDFrame.w or 280)
    rlCD:SetHeight(RT_DB.settings.rlCDFrame.h or 200)
    rlCD:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -300, -120)
    rlCD:SetFrameStrata("HIGH")
    rlCD:SetMovable(true)
    rlCD:EnableMouse(true)
    rlCD:RegisterForDrag("LeftButton")
    rlCD:SetScript("OnDragStart", function() rlCD:StartMoving() end)
    rlCD:SetScript("OnDragStop", function() rlCD:StopMovingOrSizing() end)
    RT_PatchBackdrop(rlCD)
    rlCD:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    rlCD:SetBackdropColor(0.02, 0.03, 0.06, 0.92)
    rlCD:SetBackdropBorderColor(0.4, 0.55, 0.8, 0.8)
    rlCD:Hide()

    local rlCDTitle = rlCD:CreateFontString("RT_RLCDTitle", "OVERLAY", "GameFontNormal")
    rlCDTitle:SetPoint("TOPLEFT", rlCD, "TOPLEFT", 6, -6)
    rlCDTitle:SetText(RT_Text("rl_cds_title"))
    rlCDTitle:SetTextColor(0.6, 0.85, 1.0)

    local rlCDRefresh = CreateFrame("Button", "RT_RLCDRefreshBtn", rlCD, "UIPanelButtonTemplate")
    rlCDRefresh:SetPoint("TOPLEFT", rlCD, "TOPLEFT", 6, -24)
    rlCDRefresh:SetWidth(64)
    rlCDRefresh:SetHeight(18)
    rlCDRefresh:SetText(RT_Text("rl_cds_refresh"))
    rlCDRefresh:SetScript("OnClick", function() RT_RLCooldownRefresh() end)

    local rlCDCall = CreateFrame("Button", "RT_RLCDCallBtn", rlCD, "UIPanelButtonTemplate")
    rlCDCall:SetPoint("LEFT", rlCDRefresh, "RIGHT", 4, 0)
    rlCDCall:SetWidth(74)
    rlCDCall:SetHeight(18)
    rlCDCall:SetText(RT_Text("rl_cds_call"))
    rlCDCall:SetScript("OnClick", function() RT_RLCooldownCallRaid() end)

    local rlCDMinus = CreateFrame("Button", "RT_RLCDMinusBtn", rlCD, "UIPanelButtonTemplate")
    rlCDMinus:SetPoint("LEFT", rlCDCall, "RIGHT", 6, 0)
    rlCDMinus:SetWidth(24)
    rlCDMinus:SetHeight(18)
    rlCDMinus:SetText("-")
    rlCDMinus:SetScript("OnClick", function() RT_RLCooldownResize(-20) end)

    local rlCDPlus = CreateFrame("Button", "RT_RLCDPlusBtn", rlCD, "UIPanelButtonTemplate")
    rlCDPlus:SetPoint("LEFT", rlCDMinus, "RIGHT", 2, 0)
    rlCDPlus:SetWidth(24)
    rlCDPlus:SetHeight(18)
    rlCDPlus:SetText("+")
    rlCDPlus:SetScript("OnClick", function() RT_RLCooldownResize(20) end)

    local rlCDClose = CreateFrame("Button", "RT_RLCDCloseBtn", rlCD, "UIPanelButtonTemplate")
    rlCDClose:SetPoint("LEFT", rlCDPlus, "RIGHT", 4, 0)
    rlCDClose:SetWidth(22)
    rlCDClose:SetHeight(18)
    rlCDClose:SetText("x")
    rlCDClose:SetScript("OnClick", function() rlCD:Hide() end)

    local rlCDDrag = rlCD:CreateFontString("RT_RLCDDragHint", "OVERLAY", "GameFontDisableSmall")
    rlCDDrag:SetPoint("TOPRIGHT", rlCD, "TOPRIGHT", -6, -7)
    rlCDDrag:SetText(RT_Text("rl_cds_drag_hint"))

    local rlCDLog = CreateFrame("ScrollingMessageFrame", "RT_RLCDLog", rlCD)
    rlCDLog:SetPoint("TOPLEFT", rlCD, "TOPLEFT", 6, -46)
    rlCDLog:SetWidth((RT_DB.settings.rlCDFrame.w or 280) - 12)
    rlCDLog:SetHeight((RT_DB.settings.rlCDFrame.h or 200) - 58)
    rlCDLog:SetFontObject(GameFontHighlightSmall)
    rlCDLog:SetJustifyH("LEFT")
    rlCDLog:SetFading(false)
    rlCDLog:SetMaxLines(200)

    -- Panel Buffs
    local buffsPanel = RT_CreatePanel("RT_Panel_Buffs")
    local buffsTitle = buffsPanel:CreateFontString("RT_BuffsPanelTitle", "OVERLAY", "GameFontNormal")
    buffsTitle:SetPoint("TOPLEFT", buffsPanel, "TOPLEFT", 6, -4)
    buffsTitle:SetText(RT_Text("ui_buffs_title"))
    buffsTitle:SetTextColor(1.0, 0.9, 0.2)

    -- Sous-onglets Rotation / Bénédictions
    local buffTabRotBtn = CreateFrame("Button", "RT_BuffTabRotBtn", buffsPanel, "UIPanelButtonTemplate")
    buffTabRotBtn:SetPoint("TOPLEFT", buffsPanel, "TOPLEFT", 200, -2)
    buffTabRotBtn:SetWidth(120)
    buffTabRotBtn:SetHeight(20)
    buffTabRotBtn:SetText("◈ Rotation")
    buffTabRotBtn:SetScript("OnClick", function()
        local r = getglobal("RT_BuffRotFrame")
        local b = getglobal("RT_BuffBlessFrame")
        if r then r:Show() end
        if b then b:Hide() end
        RT_BuffDisplay()
    end)

    local buffTabBlessBtn = CreateFrame("Button", "RT_BuffTabBlessBtn", buffsPanel, "UIPanelButtonTemplate")
    buffTabBlessBtn:SetPoint("LEFT", buffTabRotBtn, "RIGHT", 4, 0)
    buffTabBlessBtn:SetWidth(130)
    buffTabBlessBtn:SetHeight(20)
    buffTabBlessBtn:SetText("◈ Bénédictions")
    buffTabBlessBtn:SetScript("OnClick", function()
        local r = getglobal("RT_BuffRotFrame")
        local b = getglobal("RT_BuffBlessFrame")
        if r then r:Hide() end
        if b then b:Show() end
        RT_BlessingsDisplay()
    end)

    -- Bouton toggle HUD Buffs/CDs flottant
    local buffHUDBtn = CreateFrame("Button", "RT_BuffHUDToggleBtn", buffsPanel, "UIPanelButtonTemplate")
    buffHUDBtn:SetPoint("TOPRIGHT", buffsPanel, "TOPRIGHT", -6, -2)
    buffHUDBtn:SetWidth(110)
    buffHUDBtn:SetHeight(20)
    local bhs = RT_DB and RT_DB.settings and RT_DB.settings.buffHUD
    buffHUDBtn:SetText(bhs and bhs.enabled and "⬛ HUD: ON" or "⬜ HUD: OFF")
    buffHUDBtn:SetScript("OnClick", function() RT_BuffHUDToggle() end)

    -- Sous-frame Rotation (visible par défaut)
    local buffRotFrame = CreateFrame("Frame", "RT_BuffRotFrame", buffsPanel)
    buffRotFrame:SetPoint("TOPLEFT", buffsPanel, "TOPLEFT", 0, -24)
    buffRotFrame:SetWidth(730)
    buffRotFrame:SetHeight(426)
    buffRotFrame:Show()

    local curseModeBtn = CreateFrame("Button", "RT_BuffCurseModeBtn", buffRotFrame, "UIPanelButtonTemplate")
    curseModeBtn:SetPoint("TOPRIGHT", buffRotFrame, "TOPRIGHT", -6, -2)
    curseModeBtn:SetWidth(92)
    curseModeBtn:SetHeight(20)
    curseModeBtn:SetText(RT_Text("buff_curse_mode_auto"))
    curseModeBtn:SetScript("OnClick", function() RT_BuffToggleCurseMode() end)

    local curseDemoBtn = CreateFrame("Button", "RT_BuffSetDemoBtn", buffRotFrame, "UIPanelButtonTemplate")
    curseDemoBtn:SetPoint("RIGHT", curseModeBtn, "LEFT", -4, 0)
    curseDemoBtn:SetWidth(80)
    curseDemoBtn:SetHeight(20)
    curseDemoBtn:SetText(RT_Text("buff_set_demo"))
    curseDemoBtn:SetScript("OnClick", function() RT_BuffSetManualCurse("demo") end)

    local curseMaleBtn = CreateFrame("Button", "RT_BuffSetMaleBtn", buffRotFrame, "UIPanelButtonTemplate")
    curseMaleBtn:SetPoint("RIGHT", curseDemoBtn, "LEFT", -4, 0)
    curseMaleBtn:SetWidth(80)
    curseMaleBtn:SetHeight(20)
    curseMaleBtn:SetText(RT_Text("buff_set_male"))
    curseMaleBtn:SetScript("OnClick", function() RT_BuffSetManualCurse("male") end)

    local warlockPickLbl = buffRotFrame:CreateFontString("RT_BuffWarlockPickLbl", "OVERLAY", "GameFontHighlightSmall")
    warlockPickLbl:SetPoint("TOPLEFT", buffRotFrame, "TOPLEFT", 6, -24)
    warlockPickLbl:SetWidth(300)
    warlockPickLbl:SetJustifyH("LEFT")
    warlockPickLbl:SetText("")

    local warlockPrevBtn = CreateFrame("Button", "RT_BuffWarlockPrevBtn", buffRotFrame, "UIPanelButtonTemplate")
    warlockPrevBtn:SetPoint("LEFT", warlockPickLbl, "RIGHT", 6, 0)
    warlockPrevBtn:SetWidth(20)
    warlockPrevBtn:SetHeight(18)
    warlockPrevBtn:SetText("<")
    warlockPrevBtn:SetScript("OnClick", function() RT_BuffCycleWarlockTarget(-1) end)

    local warlockNextBtn = CreateFrame("Button", "RT_BuffWarlockNextBtn", buffRotFrame, "UIPanelButtonTemplate")
    warlockNextBtn:SetPoint("LEFT", warlockPrevBtn, "RIGHT", 2, 0)
    warlockNextBtn:SetWidth(20)
    warlockNextBtn:SetHeight(18)
    warlockNextBtn:SetText(">")
    warlockNextBtn:SetScript("OnClick", function() RT_BuffCycleWarlockTarget(1) end)

    local cursePrevBtn = CreateFrame("Button", "RT_BuffCursePrevBtn", buffRotFrame, "UIPanelButtonTemplate")
    cursePrevBtn:SetPoint("LEFT", warlockNextBtn, "RIGHT", 8, 0)
    cursePrevBtn:SetWidth(20)
    cursePrevBtn:SetHeight(18)
    cursePrevBtn:SetText("<")
    cursePrevBtn:SetScript("OnClick", function() RT_BuffCycleWarlockCurse(-1) end)

    local curseNextBtn = CreateFrame("Button", "RT_BuffCurseNextBtn", buffRotFrame, "UIPanelButtonTemplate")
    curseNextBtn:SetPoint("LEFT", cursePrevBtn, "RIGHT", 2, 0)
    curseNextBtn:SetWidth(20)
    curseNextBtn:SetHeight(18)
    curseNextBtn:SetText(">")
    curseNextBtn:SetScript("OnClick", function() RT_BuffCycleWarlockCurse(1) end)

    local buffLog = CreateFrame("ScrollingMessageFrame", "RT_BuffLog", buffRotFrame)
    buffLog:SetPoint("TOPLEFT", buffRotFrame, "TOPLEFT", 6, -46)
    buffLog:SetWidth(718)
    buffLog:SetHeight(374)
    buffLog:SetFontObject(GameFontNormalSmall)
    buffLog:SetJustifyH("LEFT")
    buffLog:SetFading(false)
    buffLog:SetMaxLines(500)
    RT_PatchBackdrop(buffLog)
    buffLog:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    buffLog:SetBackdropColor(0.01, 0.01, 0.03, 0.72)
    buffLog:SetBackdropBorderColor(0.45, 0.55, 0.72, 0.75)
    buffLog:EnableMouseWheel(1)
    buffLog:SetScript("OnMouseWheel", function()
        local delta = arg1 or 0
        if delta > 0 then
            buffLog:ScrollUp()
        elseif delta < 0 then
            buffLog:ScrollDown()
        end
    end)

    -- Sous-frame Bénédictions (cachée par défaut)
    local buffBlessFrame = CreateFrame("Frame", "RT_BuffBlessFrame", buffsPanel)
    buffBlessFrame:SetPoint("TOPLEFT", buffsPanel, "TOPLEFT", 0, -24)
    buffBlessFrame:SetWidth(730)
    buffBlessFrame:SetHeight(426)
    buffBlessFrame:Hide()

    RT_BuildUIBlessings(buffBlessFrame)

    -- Panel Loot
    local lootPanel = RT_CreatePanel("RT_Panel_Loot")
    local lootTitle = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lootTitle:SetPoint("TOPLEFT", lootPanel, "TOPLEFT", 6, -4)
    lootTitle:SetText("◈ Historique de Loot & Points SR+")
    lootTitle:SetTextColor(1.0, 0.72, 0.15)

    local lootBtnAll = CreateFrame("Button", "RT_LootFilter_All", lootPanel, "UIPanelButtonTemplate")
    lootBtnAll:SetPoint("TOPRIGHT", lootPanel, "TOPRIGHT", -6, -22)
    lootBtnAll:SetWidth(70)
    lootBtnAll:SetHeight(20)
    lootBtnAll:SetText("Tous")
    lootBtnAll:SetScript("OnClick", function() RT_LootDisplay("all") end)

    local lootBtnSR = CreateFrame("Button", "RT_LootFilter_SR", lootPanel, "UIPanelButtonTemplate")
    lootBtnSR:SetPoint("RIGHT", lootBtnAll, "LEFT", -4, 0)
    lootBtnSR:SetWidth(70)
    lootBtnSR:SetHeight(20)
    lootBtnSR:SetText("SR+ Top")
    lootBtnSR:SetScript("OnClick", function() RT_LootDisplay("sr") end)

    local lootSearchEdit = CreateFrame("EditBox", "RT_LootSearchEdit", lootPanel, "InputBoxTemplate")
    lootSearchEdit:SetPoint("TOPLEFT", lootPanel, "TOPLEFT", 6, -24)
    lootSearchEdit:SetWidth(220)
    lootSearchEdit:SetHeight(18)
    lootSearchEdit:SetAutoFocus(false)
    lootSearchEdit:SetText(RT_Text("loot_search_ph"))
    lootSearchEdit:SetScript("OnEditFocusGained", function()
        if lootSearchEdit:GetText() == RT_Text("loot_search_ph") then lootSearchEdit:SetText("") end
    end)
    lootSearchEdit:SetScript("OnEnterPressed", function()
        RT_LootDisplay("all")
        lootSearchEdit:ClearFocus()
    end)

    local lootSearchBtn = CreateFrame("Button", "RT_LootSearchBtn", lootPanel, "UIPanelButtonTemplate")
    lootSearchBtn:SetPoint("LEFT", lootSearchEdit, "RIGHT", 4, 0)
    lootSearchBtn:SetWidth(64)
    lootSearchBtn:SetHeight(20)
    lootSearchBtn:SetText(RT_Text("loot_search_btn"))
    lootSearchBtn:SetScript("OnClick", function() RT_LootDisplay("all") end)

    local lootSearchReset = CreateFrame("Button", "RT_LootSearchResetBtn", lootPanel, "UIPanelButtonTemplate")
    lootSearchReset:SetPoint("LEFT", lootSearchBtn, "RIGHT", 4, 0)
    lootSearchReset:SetWidth(52)
    lootSearchReset:SetHeight(20)
    lootSearchReset:SetText(RT_Text("loot_search_clear"))
    lootSearchReset:SetScript("OnClick", function()
        lootSearchEdit:SetText("")
        RT_LootDisplay("all")
    end)

    local lootLog = CreateFrame("ScrollingMessageFrame", "RT_LootLog", lootPanel)
    lootLog:SetPoint("TOPLEFT", lootPanel, "TOPLEFT", 6, -50)
    lootLog:SetWidth(718)
    lootLog:SetHeight(392)
    lootLog:SetFontObject(GameFontHighlightSmall)
    lootLog:SetJustifyH("LEFT")
    lootLog:SetFading(false)
    lootLog:SetMaxLines(400)

    -- Panel Import
    local importPanel = RT_CreatePanel("RT_Panel_Import")

    -- ── Titre ────────────────────────────────────────────────
    local importTitle = importPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importTitle:SetPoint("TOPLEFT", importPanel, "TOPLEFT", 6, -4)
    importTitle:SetText("|cffAA66FFImport|r  —  Colle chaque export dans sa colonne puis clique Importer")
    importTitle:SetTextColor(0.85, 0.55, 1.0)

    -- ═══════════════════════════════════════════════════════
    -- COLONNE GAUCHE — Roster / RaidRes (noms + classe + rôle)
    -- ═══════════════════════════════════════════════════════
    local rosterColW = 348

    local rosterColLabel = importPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rosterColLabel:SetPoint("TOPLEFT", importPanel, "TOPLEFT", 6, -20)
    rosterColLabel:SetText("|cff88FF88Roster / RaidRes|r")

    local rosterColHelp = importPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    rosterColHelp:SetPoint("TOPLEFT", importPanel, "TOPLEFT", 6, -33)
    rosterColHelp:SetText("CSV SoftRes Attendees  ou  Name,Class,Spec,Role  ou  JSON roster")

    local rosterScroll2 = CreateFrame("ScrollFrame", "RT_ImportRosterScrollFrame", importPanel, "UIPanelScrollFrameTemplate")
    rosterScroll2:SetPoint("TOPLEFT", importPanel, "TOPLEFT", 6, -46)
    rosterScroll2:SetWidth(rosterColW)
    rosterScroll2:SetHeight(240)
    RT_PatchBackdrop(rosterScroll2)
    rosterScroll2:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    rosterScroll2:SetBackdropColor(0.02, 0.04, 0.02, 1.0)
    rosterScroll2:SetBackdropBorderColor(0.2, 0.7, 0.3, 0.7)

    local rosterEdit2 = CreateFrame("EditBox", "RT_ImportRosterEditBox", rosterScroll2)
    rosterEdit2:SetMultiLine(true)
    rosterEdit2:SetAutoFocus(false)
    rosterEdit2:SetFontObject(GameFontHighlightSmall)
    rosterEdit2:SetWidth(rosterColW - 26)
    rosterEdit2:SetHeight(4000)
    rosterEdit2:SetMaxLetters(999999)
    rosterEdit2:SetText("")
    rosterEdit2:SetScript("OnEscapePressed", function() rosterEdit2:ClearFocus() end)
    rosterEdit2:SetScript("OnTextChanged", function()
        RT_ImportRosterScrollFrame:UpdateScrollChildRect()
    end)
    rosterScroll2:SetScrollChild(rosterEdit2)
    rosterScroll2:EnableMouse(true)
    rosterScroll2:SetScript("OnMouseDown", function() rosterEdit2:SetFocus() end)

    -- Boutons roster
    local rosterImportBtn = CreateFrame("Button", "RT_ImportRosterBtn", importPanel, "UIPanelButtonTemplate")
    rosterImportBtn:SetPoint("TOPLEFT", rosterScroll2, "BOTTOMLEFT", 0, -5)
    rosterImportBtn:SetWidth(110)
    rosterImportBtn:SetHeight(22)
    rosterImportBtn:SetText("Importer Roster")
    local rITex = rosterImportBtn:GetNormalTexture()
    if rITex then rITex:SetVertexColor(0.2, 0.7, 0.3) end
    rosterImportBtn:SetScript("OnClick", function() RT_ImportRoster_Process() end)

    local rosterClearBtn = CreateFrame("Button", nil, importPanel, "UIPanelButtonTemplate")
    rosterClearBtn:SetPoint("LEFT", rosterImportBtn, "RIGHT", 4, 0)
    rosterClearBtn:SetWidth(58)
    rosterClearBtn:SetHeight(22)
    rosterClearBtn:SetText("Clear")
    rosterClearBtn:SetScript("OnClick", function()
        rosterEdit2:SetText("")
        local st = getglobal("RT_ImportRosterStatus")
        if st then st:SetText("") end
    end)

    local rosterResetBtn = CreateFrame("Button", nil, importPanel, "UIPanelButtonTemplate")
    rosterResetBtn:SetPoint("LEFT", rosterClearBtn, "RIGHT", 4, 0)
    rosterResetBtn:SetWidth(80)
    rosterResetBtn:SetHeight(22)
    rosterResetBtn:SetText("Reset Roster")
    rosterResetBtn:SetScript("OnClick", function() RT_ResetRosterOnly() end)

    local rosterStatus = importPanel:CreateFontString("RT_ImportRosterStatus", "OVERLAY", "GameFontHighlightSmall")
    rosterStatus:SetPoint("TOPLEFT", rosterImportBtn, "BOTTOMLEFT", 0, -4)
    rosterStatus:SetWidth(rosterColW)
    rosterStatus:SetJustifyH("LEFT")
    rosterStatus:SetText("")

    -- ═══════════════════════════════════════════════════════
    -- COLONNE DROITE — SoftRes (loots réservés)
    -- ═══════════════════════════════════════════════════════
    local srColX    = 6 + rosterColW + 12
    local srColW    = 718 - rosterColW - 12

    local srColLabel = importPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    srColLabel:SetPoint("TOPLEFT", importPanel, "TOPLEFT", srColX, -20)
    srColLabel:SetText("|cffFFAA44SoftRes (Loots réservés)|r")

    local srColHelp = importPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    srColHelp:SetPoint("TOPLEFT", importPanel, "TOPLEFT", srColX, -33)
    srColHelp:SetText("CSV SoftRes export  :  ID,Item,Boss,Attendee,Class,Spec,SR+,Date...")

    local srScroll = CreateFrame("ScrollFrame", "RT_ImportSRScrollFrame", importPanel, "UIPanelScrollFrameTemplate")
    srScroll:SetPoint("TOPLEFT", importPanel, "TOPLEFT", srColX, -46)
    srScroll:SetWidth(srColW)
    srScroll:SetHeight(240)
    RT_PatchBackdrop(srScroll)
    srScroll:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    srScroll:SetBackdropColor(0.04, 0.02, 0.02, 1.0)
    srScroll:SetBackdropBorderColor(0.8, 0.5, 0.1, 0.7)

    local srEdit = CreateFrame("EditBox", "RT_ImportSREditBox", srScroll)
    srEdit:SetMultiLine(true)
    srEdit:SetAutoFocus(false)
    srEdit:SetFontObject(GameFontHighlightSmall)
    srEdit:SetWidth(srColW - 26)
    srEdit:SetHeight(4000)
    srEdit:SetMaxLetters(999999)
    srEdit:SetText("")
    srEdit:SetScript("OnEscapePressed", function() srEdit:ClearFocus() end)
    srEdit:SetScript("OnTextChanged", function()
        RT_ImportSRScrollFrame:UpdateScrollChildRect()
    end)
    srScroll:SetScrollChild(srEdit)
    srScroll:EnableMouse(true)
    srScroll:SetScript("OnMouseDown", function() srEdit:SetFocus() end)

    -- Boutons SoftRes
    local srImportBtn = CreateFrame("Button", "RT_ImportSRBtn", importPanel, "UIPanelButtonTemplate")
    srImportBtn:SetPoint("TOPLEFT", srScroll, "BOTTOMLEFT", 0, -5)
    srImportBtn:SetWidth(110)
    srImportBtn:SetHeight(22)
    srImportBtn:SetText("Importer SoftRes")
    local srITex = srImportBtn:GetNormalTexture()
    if srITex then srITex:SetVertexColor(0.8, 0.45, 0.1) end
    srImportBtn:SetScript("OnClick", function() RT_ImportSoftRes_Process() end)

    local srClearBtn = CreateFrame("Button", nil, importPanel, "UIPanelButtonTemplate")
    srClearBtn:SetPoint("LEFT", srImportBtn, "RIGHT", 4, 0)
    srClearBtn:SetWidth(58)
    srClearBtn:SetHeight(22)
    srClearBtn:SetText("Clear")
    srClearBtn:SetScript("OnClick", function()
        srEdit:SetText("")
        local st = getglobal("RT_ImportSRStatus")
        if st then st:SetText("") end
    end)

    local srResetBtn = CreateFrame("Button", nil, importPanel, "UIPanelButtonTemplate")
    srResetBtn:SetPoint("LEFT", srClearBtn, "RIGHT", 4, 0)
    srResetBtn:SetWidth(80)
    srResetBtn:SetHeight(22)
    srResetBtn:SetText("Reset Loots")
    srResetBtn:SetScript("OnClick", function()
        RT_DB = RT_DB or {}
        RT_DB.loot = {}
        RT_DB.sr   = {}
        RT_UpdateImportStats()
        RT_Print("|cff88FF88[Import] Loots/SoftRes réinitialisés.|r")
    end)

    local srResetAllBtn = CreateFrame("Button", nil, importPanel, "UIPanelButtonTemplate")
    srResetAllBtn:SetPoint("LEFT", srResetBtn, "RIGHT", 4, 0)
    srResetAllBtn:SetWidth(72)
    srResetAllBtn:SetHeight(22)
    srResetAllBtn:SetText("Reset DB")
    srResetAllBtn:SetScript("OnClick", function() RT_ResetDB() end)

    local srStatus = importPanel:CreateFontString("RT_ImportSRStatus", "OVERLAY", "GameFontHighlightSmall")
    srStatus:SetPoint("TOPLEFT", srImportBtn, "BOTTOMLEFT", 0, -4)
    srStatus:SetWidth(srColW)
    srStatus:SetJustifyH("LEFT")
    srStatus:SetText("")

    -- ── Stats globales (pleine largeur, sous les deux colonnes) ──
    -- Compatibilité : RT_ImportEditBox pointé vers la boîte SoftRes
    -- pour ne pas casser RT_LootImport_Process() existant
    local importEditCompat = srEdit   -- alias
    -- expose sous l'ancien nom global aussi
    local function RT_GetImportEditBoxCompat()
        return srEdit
    end

    local importStats = importPanel:CreateFontString("RT_ImportStats", "OVERLAY", "GameFontDisable")
    importStats:SetPoint("TOPLEFT", importPanel, "TOPLEFT", 6, -300)
    importStats:SetWidth(718)
    importStats:SetJustifyH("LEFT")
    importStats:SetText("")

    local importEventLabel = importPanel:CreateFontString("RT_ImportEventLabel", "OVERLAY", "GameFontDisable")
    importEventLabel:SetPoint("TOPLEFT", importStats, "BOTTOMLEFT", 0, -2)
    importEventLabel:SetWidth(718)
    importEventLabel:SetJustifyH("LEFT")
    importEventLabel:SetText("")

    -- Compatibilité avec RT_ImportStatus (anciens appels)
    local importStatus = importPanel:CreateFontString("RT_ImportStatus", "OVERLAY", "GameFontHighlightSmall")
    importStatus:SetPoint("TOPLEFT", importEventLabel, "BOTTOMLEFT", 0, -2)
    importStatus:SetWidth(718)
    importStatus:SetJustifyH("LEFT")
    importStatus:SetText("")

    -- (WhisperBot déplacé dans le panel Invite)

    RT_BuildUIRosterRoleEditor()

    RT_BuildUIPopups(RT_MainFrame)

    -- Extract Notes UI to separate function
    RT_BuildUINotes(RT_MainFrame)

    -- Extract Check UI to separate function
    local checkPanel = RT_CreatePanel("RT_Panel_Check")
    local checkTitle = checkPanel:CreateFontString("RT_CheckPanelTitle", "OVERLAY", "GameFontNormal")
    checkTitle:SetPoint("TOPLEFT", checkPanel, "TOPLEFT", 6, -4)
    checkTitle:SetText(RT_Text("check_tab_title"))
    checkTitle:SetTextColor(0.4, 1.0, 0.6)
    RT_BuildUICheck(checkPanel)

    -- Pull Timer panel
    local timerPanel = RT_CreatePanel("RT_Panel_Timer")
    local timerTitle = timerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timerTitle:SetPoint("TOPLEFT", timerPanel, "TOPLEFT", 6, -4)
    timerTitle:SetText("|cffFFAA00Pull Timer|r  —  Compte à rebours visible par tout le raid")
    timerTitle:SetTextColor(1.0, 0.65, 0.0)

    local ptSecLabel = timerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ptSecLabel:SetPoint("TOPLEFT", timerPanel, "TOPLEFT", 6, -30)
    ptSecLabel:SetText("Secondes :")

    local ptInput = CreateFrame("EditBox", "RT_PullTimerInput", timerPanel, "InputBoxTemplate")
    ptInput:SetPoint("LEFT", ptSecLabel, "RIGHT", 8, 0)
    ptInput:SetWidth(48)
    ptInput:SetHeight(22)
    ptInput:SetAutoFocus(false)
    ptInput:SetText("10")
    ptInput:SetScript("OnEscapePressed", function() ptInput:ClearFocus() end)

    local ptStartBtn = CreateFrame("Button", nil, timerPanel, "UIPanelButtonTemplate")
    ptStartBtn:SetPoint("LEFT", ptInput, "RIGHT", 8, 0)
    ptStartBtn:SetWidth(110)
    ptStartBtn:SetHeight(24)
    ptStartBtn:SetText("|cffFFAA00▶ Lancer Timer|r")
    local ptSTex = ptStartBtn:GetNormalTexture()
    if ptSTex then ptSTex:SetVertexColor(0.8, 0.5, 0.0) end
    ptStartBtn:SetScript("OnClick", function()
        if RT_PT_StartFromUI then RT_PT_StartFromUI() end
    end)

    local ptCancelBtn = CreateFrame("Button", nil, timerPanel, "UIPanelButtonTemplate")
    ptCancelBtn:SetPoint("LEFT", ptStartBtn, "RIGHT", 6, 0)
    ptCancelBtn:SetWidth(80)
    ptCancelBtn:SetHeight(24)
    ptCancelBtn:SetText("Annuler")
    ptCancelBtn:SetScript("OnClick", function()
        if RT_PT then RT_PT.Cancel(true) end
    end)

    local ptHelp = timerPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    ptHelp:SetPoint("TOPLEFT", timerPanel, "TOPLEFT", 6, -62)
    ptHelp:SetWidth(720)
    ptHelp:SetText("Le timer est broadcasté à tous les joueurs du raid ayant RT v2. "
        .. "Le compte à rebours apparaît en grand au centre de l'écran.\n"
        .. "Slash: /rt timer <N>  /rt timer cancel")

    -- Presets rapides
    local ptPresetLabel = timerPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    ptPresetLabel:SetPoint("TOPLEFT", timerPanel, "TOPLEFT", 6, -96)
    ptPresetLabel:SetText("Presets rapides :")

    local presets = { 5, 10, 15, 20, 30 }
    local lastPresetBtn = ptPresetLabel
    for _, sec in pairs(presets) do
        local pb = CreateFrame("Button", nil, timerPanel, "UIPanelButtonTemplate")
        pb:SetPoint("LEFT", lastPresetBtn, "RIGHT", 6, 0)
        pb:SetWidth(46)
        pb:SetHeight(22)
        pb:SetText(tostring(sec) .. "s")
        local s = sec
        pb:SetScript("OnClick", function()
            ptInput:SetText(tostring(s))
            if RT_PT then RT_PT.Start(s, nil, true) end
        end)
        lastPresetBtn = pb
    end

    -- Auto-Invite panel + WhisperBot (fusionnés dans Invite)
    if RT_BuildUIAutoInvite then
        local invPanel = RT_CreatePanel("RT_Panel_Invite")
        RT_BuildUIAutoInvite(invPanel)

        -- Séparateur WhisperBot
        local wbSep = invPanel:CreateTexture(nil, "ARTWORK")
        wbSep:SetPoint("TOPLEFT", invPanel, "TOPLEFT", 6, -240)
        wbSep:SetWidth(718)
        wbSep:SetHeight(1)
        wbSep:SetTexture(0.5, 0.35, 0.1, 0.6)

        local wbTitle = invPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        wbTitle:SetPoint("TOPLEFT", invPanel, "TOPLEFT", 6, -248)
        wbTitle:SetText("WhisperBot")
        wbTitle:SetTextColor(1, 0.82, 0)

        local wbHint = invPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        wbHint:SetPoint("LEFT", wbTitle, "RIGHT", 10, 0)
        wbHint:SetText("Répond automatiquement aux MPs contenant le mot-clé avec la liste de SoftRes du joueur")

        local wbToggle = CreateFrame("Button", "RT_WhisperToggleBtn", invPanel, "UIPanelButtonTemplate")
        wbToggle:SetPoint("TOPLEFT", invPanel, "TOPLEFT", 6, -266)
        wbToggle:SetWidth(110)
        wbToggle:SetHeight(20)
        wbToggle:SetText("Whisper: ON")
        wbToggle:SetScript("OnClick", function() RT_WhisperToggleFromUI() end)

        local wbKwLbl = invPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        wbKwLbl:SetPoint("LEFT", wbToggle, "RIGHT", 12, 0)
        wbKwLbl:SetText(RT_Text("whisper_keyword_lbl"))

        local wbKwEdit = CreateFrame("EditBox", "RT_WhisperKeywordEdit", invPanel, "InputBoxTemplate")
        wbKwEdit:SetPoint("LEFT", wbKwLbl, "RIGHT", 6, 0)
        wbKwEdit:SetWidth(90)
        wbKwEdit:SetHeight(18)
        wbKwEdit:SetAutoFocus(false)
        wbKwEdit:SetText("attrib")
        wbKwEdit:SetScript("OnEnterPressed", function()
            RT_WhisperApplyKeywordFromUI()
            wbKwEdit:ClearFocus()
        end)
        wbKwEdit:SetScript("OnEscapePressed", function()
            RT_UpdateWhisperUI()
            wbKwEdit:ClearFocus()
        end)

        local wbApply = CreateFrame("Button", "RT_WhisperApplyBtn", invPanel, "UIPanelButtonTemplate")
        wbApply:SetPoint("LEFT", wbKwEdit, "RIGHT", 6, 0)
        wbApply:SetWidth(80)
        wbApply:SetHeight(20)
        wbApply:SetText(RT_Text("btn_apply"))
        wbApply:SetScript("OnClick", function() RT_WhisperApplyKeywordFromUI() end)

        local wbStatus = invPanel:CreateFontString("RT_WhisperStatus", "OVERLAY", "GameFontHighlightSmall")
        wbStatus:SetPoint("TOPLEFT", invPanel, "TOPLEFT", 6, -288)
        wbStatus:SetWidth(718)
        wbStatus:SetJustifyH("LEFT")
        wbStatus:SetText("")
    end

    -- Attendance panel
    if RT_BuildUIAttendance then
        local attendPanel = RT_CreatePanel("RT_Panel_Attend")
        RT_BuildUIAttendance(attendPanel)
    end

    RT_UI_BUILT = true
    if RT_RefreshLocalizedStaticUI then RT_RefreshLocalizedStaticUI() end
    RT_ApplySavedMainFramePosition()
end

-- ============================================================
-- Extracted UI builders (reduce local variables in RT_BuildUI)
-- ============================================================

function RT_BuildUIPopups(RT_MainFrame)
    if not RT_MainFrame then return end

    -- ── Popup : liste des raids ────────────────────────────────
    local raidPopup = CreateFrame("Frame", "RT_RaidPickerPopup", RT_MainFrame)
    raidPopup:SetWidth(220)
    raidPopup:SetHeight(230)
    raidPopup:SetPoint("TOPLEFT", RT_MainFrame, "TOPLEFT", 22, -100)
    raidPopup:SetFrameStrata("TOOLTIP")
    RT_PatchBackdrop(raidPopup)
    raidPopup:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets = { left=4, right=4, top=4, bottom=4 },
    })
    raidPopup:Hide()
    local raidPopTitle = raidPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidPopTitle:SetPoint("TOPLEFT", raidPopup, "TOPLEFT", 8, -6)
    raidPopTitle:SetText(RT_Text("picker_select_raid"))
    raidPopTitle:SetTextColor(1, 0.82, 0)
    for raidIdx3 = 1, table.getn(RT_VANILLA_RAIDS) do
        local raid = RT_VANILLA_RAIDS[raidIdx3]
        local rb = CreateFrame("Button", nil, raidPopup, "UIPanelButtonTemplate")
        rb:SetPoint("TOPLEFT", raidPopup, "TOPLEFT", 6, -20 - (raidIdx3-1)*22)
        rb:SetWidth(206)
        rb:SetHeight(20)
        rb:SetText(raid.name)
        local ri = raidIdx3
        rb:SetScript("OnClick", function() RT_BossSelectRaid(ri) end)
    end
    raidPopup:SetHeight(28 + table.getn(RT_VANILLA_RAIDS) * 22)

    -- ── Popup : liste des boss ────────────────────────────────
    local bossPopup = CreateFrame("Frame", "RT_BossPickerPopup", RT_MainFrame)
    bossPopup:SetWidth(300)
    bossPopup:SetHeight(200)
    bossPopup:SetPoint("TOPLEFT", RT_MainFrame, "TOPLEFT", 230, -100)
    bossPopup:SetFrameStrata("TOOLTIP")
    RT_PatchBackdrop(bossPopup)
    bossPopup:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets = { left=4, right=4, top=4, bottom=4 },
    })
    bossPopup:Hide()
    local bossPopTitle = bossPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bossPopTitle:SetPoint("TOPLEFT", bossPopup, "TOPLEFT", 8, -6)
    bossPopTitle:SetText(RT_Text("picker_select_boss"))
    bossPopTitle:SetTextColor(1, 0.82, 0)
    local bossPopBtns = {}
    RT_BOSS_SLOT_BTNS["_bossbtns_"] = bossPopBtns
    for i = 1, 20 do
        local bb = CreateFrame("Button", nil, bossPopup, "UIPanelButtonTemplate")
        bb:SetPoint("TOPLEFT", bossPopup, "TOPLEFT", 6, -20 - (i-1)*20)
        bb:SetWidth(286)
        bb:SetHeight(18)
        bb:SetText("")
        bb:Hide()
        bossPopBtns[i] = bb
    end

    -- ── Popup : picker joueur ─────────────────────────────────
    local pickerPopup = CreateFrame("Frame", "RT_PlayerPickerPopup", RT_MainFrame)
    pickerPopup:SetWidth(230)
    pickerPopup:SetHeight(200)
    pickerPopup:SetPoint("CENTER", RT_MainFrame, "CENTER", 0, 0)
    pickerPopup:SetFrameStrata("TOOLTIP")
    RT_PatchBackdrop(pickerPopup)
    pickerPopup:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets = { left=4, right=4, top=4, bottom=4 },
    })
    pickerPopup:Hide()
    local pickerTitle = pickerPopup:CreateFontString("RT_PickerTitle", "OVERLAY", "GameFontNormal")
    pickerTitle:SetPoint("TOPLEFT", pickerPopup, "TOPLEFT", 8, -6)
    pickerTitle:SetText(RT_Text("picker_select_player"))
    pickerTitle:SetTextColor(1, 0.82, 0)
    for i = 1, 20 do
        local pb = CreateFrame("Button", nil, pickerPopup, "UIPanelButtonTemplate")
        pb:SetPoint("TOPLEFT", pickerPopup, "TOPLEFT", 6, -20 - (i-1)*20)
        pb:SetWidth(216)
        pb:SetHeight(18)
        pb:SetText("")
        pb:Hide()
        RT_BOSS_SLOT_BTNS["_picker_"..i] = pb
    end
    local pickerClose = CreateFrame("Button", nil, pickerPopup, "UIPanelButtonTemplate")
    pickerClose:SetPoint("BOTTOMRIGHT", pickerPopup, "BOTTOMRIGHT", -4, 4)
    pickerClose:SetWidth(60)
    pickerClose:SetHeight(18)
    pickerClose:SetText(RT_Text("picker_cancel"))
    pickerClose:SetScript("OnClick", function() pickerPopup:Hide() end)

    -- ── Popup : ajouter boss custom ───────────────────────────
    local addBossPopup = CreateFrame("Frame", "RT_BossAddPopup", RT_MainFrame)
    addBossPopup:SetWidth(260)
    addBossPopup:SetHeight(70)
    addBossPopup:SetPoint("CENTER", RT_MainFrame, "CENTER", 0, 80)
    addBossPopup:SetFrameStrata("TOOLTIP")
    RT_PatchBackdrop(addBossPopup)
    addBossPopup:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets = { left=4, right=4, top=4, bottom=4 },
    })
    addBossPopup:Hide()
    local addBossLbl = addBossPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addBossLbl:SetPoint("TOPLEFT", addBossPopup, "TOPLEFT", 8, -8)
    addBossLbl:SetText(RT_Text("boss_custom_name_lbl"))
    addBossLbl:SetTextColor(1, 0.82, 0)
    local addBossEdit = CreateFrame("EditBox", "RT_BossCustomEdit", addBossPopup, "InputBoxTemplate")
    addBossEdit:SetPoint("TOPLEFT", addBossPopup, "TOPLEFT", 8, -26)
    addBossEdit:SetWidth(160)
    addBossEdit:SetHeight(20)
    addBossEdit:SetAutoFocus(false)
    local addBossOk = CreateFrame("Button", nil, addBossPopup, "UIPanelButtonTemplate")
    addBossOk:SetPoint("LEFT", addBossEdit, "RIGHT", 6, 0)
    addBossOk:SetWidth(60)
    addBossOk:SetHeight(20)
    addBossOk:SetText("OK")
    addBossOk:SetScript("OnClick", function() RT_BossAddCustom() end)

    -- ── Popup : marker tank ──────────────────────────────────
    local markerPopup = CreateFrame("Frame", "RT_TankMarkerPopup", RT_MainFrame)
    markerPopup:SetWidth(180)
    markerPopup:SetHeight(220)
    markerPopup:SetPoint("CENTER", RT_MainFrame, "CENTER", 230, 10)
    markerPopup:SetFrameStrata("TOOLTIP")
    RT_PatchBackdrop(markerPopup)
    markerPopup:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets = { left=4, right=4, top=4, bottom=4 },
    })
    markerPopup:Hide()

    local markerTitle = markerPopup:CreateFontString("RT_TankMarkerPopupTitle", "OVERLAY", "GameFontNormal")
    markerTitle:SetPoint("TOPLEFT", markerPopup, "TOPLEFT", 8, -6)
    markerTitle:SetText("Marker Tank")
    markerTitle:SetTextColor(1, 0.82, 0)

    for markIdx = 1, table.getn(RT_TANK_MARKERS) do
        local mark = RT_TANK_MARKERS[markIdx]
        local mb = CreateFrame("Button", nil, markerPopup, "UIPanelButtonTemplate")
        mb:SetPoint("TOPLEFT", markerPopup, "TOPLEFT", 8, -20 - (markIdx - 1) * 20)
        mb:SetWidth(164)
        mb:SetHeight(18)
        if mark == "" then
            mb:SetText(RT_Text("marker_none"))
        else
            mb:SetText(mark)
        end
        local m = mark
        mb:SetScript("OnClick", function() RT_BossSetTankMarker(m) end)
    end

    local markerClose = CreateFrame("Button", nil, markerPopup, "UIPanelButtonTemplate")
    markerClose:SetPoint("BOTTOMRIGHT", markerPopup, "BOTTOMRIGHT", -6, 6)
    markerClose:SetWidth(60)
    markerClose:SetHeight(18)
    markerClose:SetText(RT_Text("picker_close"))
    markerClose:SetScript("OnClick", function() markerPopup:Hide() end)
end

function RT_BuildUIRosterRoleEditor()
    local rosterPanel2 = getglobal("RT_Panel_Roster")
    if not rosterPanel2 then return end

    local filterY = -4
    local filterBtns = { {"All","Tous"}, {"Tank","Tank"}, {"Heal","Heal"}, {"DPS","DPS"} }
    local fBtnX = 185
    for fbIdx = 1, table.getn(filterBtns) do
        local fb = filterBtns[fbIdx]
        local fKey, fLabel = fb[1], fb[2]
        local fBtn = CreateFrame("Button", "RT_RFilter_"..fKey, rosterPanel2, "UIPanelButtonTemplate")
        fBtn:SetPoint("TOPLEFT", rosterPanel2, "TOPLEFT", fBtnX, filterY)
        fBtn:SetWidth(52)
        fBtn:SetHeight(18)
        fBtn:SetText(fLabel)
        local fk = fKey
        fBtn:SetScript("OnClick", function()
            RT_ROSTER_ROLE_FILTER = fk
            RT_RosterDisplay()
        end)
        fBtnX = fBtnX + 56
    end

    -- Éditeur de rôle : sélection joueur + changement Tank/Heal/DPS
    local pickLbl = rosterPanel2:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    pickLbl:SetPoint("TOPLEFT", rosterPanel2, "TOPLEFT", 6, -23)
    pickLbl:SetText(RT_Text("player_lbl"))

    local pickBtn = CreateFrame("Button", "RT_RosterPickPlayerBtn", rosterPanel2, "UIPanelButtonTemplate")
    pickBtn:SetPoint("LEFT", pickLbl, "RIGHT", 6, 0)
    pickBtn:SetWidth(150)
    pickBtn:SetHeight(18)
    pickBtn:SetText(RT_Text("pick_player_btn"))
    pickBtn:SetScript("OnClick", function() RT_RosterPickPlayer() end)

    local roleLbl = rosterPanel2:CreateFontString("RT_RosterPickRoleLbl", "OVERLAY", "GameFontDisable")
    roleLbl:SetPoint("LEFT", pickBtn, "RIGHT", 10, 0)
    roleLbl:SetText(RT_Text("role_current_none"))

    local setTankBtn = CreateFrame("Button", "RT_RosterSetTankBtn", rosterPanel2, "UIPanelButtonTemplate")
    setTankBtn:SetPoint("TOPLEFT", rosterPanel2, "TOPLEFT", 430, -23)
    setTankBtn:SetWidth(48)
    setTankBtn:SetHeight(18)
    setTankBtn:SetText("Tank")
    setTankBtn:SetScript("OnClick", function() RT_RosterSetSelectedRole("Tank") end)

    local setHealBtn = CreateFrame("Button", "RT_RosterSetHealBtn", rosterPanel2, "UIPanelButtonTemplate")
    setHealBtn:SetPoint("LEFT", setTankBtn, "RIGHT", 4, 0)
    setHealBtn:SetWidth(48)
    setHealBtn:SetHeight(18)
    setHealBtn:SetText("Heal")
    setHealBtn:SetScript("OnClick", function() RT_RosterSetSelectedRole("Heal") end)

    local setDpsBtn = CreateFrame("Button", "RT_RosterSetDpsBtn", rosterPanel2, "UIPanelButtonTemplate")
    setDpsBtn:SetPoint("LEFT", setHealBtn, "RIGHT", 4, 0)
    setDpsBtn:SetWidth(48)
    setDpsBtn:SetHeight(18)
    setDpsBtn:SetText("DPS")
    setDpsBtn:SetScript("OnClick", function() RT_RosterSetSelectedRole("DPS") end)

    local roleStatus = rosterPanel2:CreateFontString("RT_RosterRoleEditStatus", "OVERLAY", "GameFontHighlightSmall")
    roleStatus:SetPoint("TOPLEFT", rosterPanel2, "TOPLEFT", 500, -26)
    roleStatus:SetWidth(230)
    roleStatus:SetText("")

    -- Ligne spé : label + EditBox + bouton Appliquer
    local specLbl = rosterPanel2:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    specLbl:SetPoint("TOPLEFT", rosterPanel2, "TOPLEFT", 6, -43)
    specLbl:SetText("Spé:")

    local specEdit = CreateFrame("EditBox", "RT_RosterSpecEdit", rosterPanel2, "InputBoxTemplate")
    specEdit:SetPoint("TOPLEFT", rosterPanel2, "TOPLEFT", 38, -40)
    specEdit:SetWidth(160)
    specEdit:SetHeight(16)
    specEdit:SetAutoFocus(false)
    specEdit:SetMaxLetters(30)
    specEdit:SetScript("OnEscapePressed", function() specEdit:ClearFocus() end)
    specEdit:SetScript("OnEnterPressed", function()
        RT_RosterSetSelectedSpec(specEdit:GetText())
        specEdit:ClearFocus()
    end)

    local specApplyBtn = CreateFrame("Button", "RT_RosterSpecApplyBtn", rosterPanel2, "UIPanelButtonTemplate")
    specApplyBtn:SetPoint("LEFT", specEdit, "RIGHT", 4, 0)
    specApplyBtn:SetWidth(80)
    specApplyBtn:SetHeight(16)
    specApplyBtn:SetText("Appliquer")
    specApplyBtn:SetScript("OnClick", function()
        RT_RosterSetSelectedSpec(RT_RosterSpecEdit:GetText())
    end)

    local specHint = rosterPanel2:CreateFontString("RT_RosterSpecHint", "OVERLAY", "GameFontDisable")
    specHint:SetPoint("LEFT", specApplyBtn, "RIGHT", 8, 0)
    specHint:SetWidth(250)
    specHint:SetText("|cff888888(Entrée ou Appliquer — met à jour le rôle automatiquement)|r")

    -- Déplacer la zone roster pour laisser de la place aux filtres + éditeur spé
    local rScroll = getglobal("RT_RosterScrollFrame")
    if rScroll then
        rScroll:ClearAllPoints()
        rScroll:SetPoint("TOPLEFT", rosterPanel2, "TOPLEFT", 6, -60)
        rScroll:SetWidth(718)
        rScroll:SetHeight(348)
        rScroll:Show()
    end

    RT_RosterRefreshRoleEditor()
end

function RT_BuildUIBlessings(buffBlessFrame)
    if not buffBlessFrame then return end

    local blessHeader = buffBlessFrame:CreateFontString("RT_BlessingsPanelTitle", "OVERLAY", "GameFontNormal")
    blessHeader:SetPoint("TOPLEFT", buffBlessFrame, "TOPLEFT", 6, -6)
    blessHeader:SetText(RT_Text("bless_title"))
    blessHeader:SetTextColor(1.0, 0.84, 0.25)

    local blessHint = buffBlessFrame:CreateFontString("RT_BlessingsHint", "OVERLAY", "GameFontDisableSmall")
    blessHint:SetPoint("TOPLEFT", buffBlessFrame, "TOPLEFT", 120, -8)
    blessHint:SetWidth(280)
    blessHint:SetJustifyH("LEFT")
    blessHint:SetText("Left Click: Next  |  Right Click: Previous")

    local blessRefreshBtn = CreateFrame("Button", "RT_BlessRefreshBtn", buffBlessFrame, "UIPanelButtonTemplate")
    blessRefreshBtn:SetPoint("TOPLEFT", buffBlessFrame, "TOPLEFT", 6, -26)
    blessRefreshBtn:SetWidth(100)
    blessRefreshBtn:SetHeight(20)
    blessRefreshBtn:SetText(RT_Text("bless_refresh"))
    blessRefreshBtn:SetScript("OnClick", function() RT_BlessingsDisplay() end)

    local blessBroadcastBtn = CreateFrame("Button", "RT_BlessBroadcastBtn", buffBlessFrame, "UIPanelButtonTemplate")
    blessBroadcastBtn:SetPoint("LEFT", blessRefreshBtn, "RIGHT", 6, 0)
    blessBroadcastBtn:SetWidth(155)
    blessBroadcastBtn:SetHeight(20)
    blessBroadcastBtn:SetText(RT_Text("bless_broadcast"))
    blessBroadcastBtn:SetScript("OnClick", function() RT_BlessingsAnnounce() end)
    local blessBroadcastTex = blessBroadcastBtn:GetNormalTexture()
    if blessBroadcastTex then blessBroadcastTex:SetVertexColor(0.7, 0.9, 0.5) end

    local blessSyncPPBtn = CreateFrame("Button", "RT_BlessSyncPPBtn", buffBlessFrame, "UIPanelButtonTemplate")
    blessSyncPPBtn:SetPoint("LEFT", blessBroadcastBtn, "RIGHT", 6, 0)
    blessSyncPPBtn:SetWidth(78)
    blessSyncPPBtn:SetHeight(20)
    blessSyncPPBtn:SetText(RT_Text("bless_sync_pp"))
    blessSyncPPBtn:SetScript("OnClick", function() RT_BlessingsSyncToPallyPower() end)

    local blessReadPPBtn = CreateFrame("Button", "RT_BlessReadPPBtn", buffBlessFrame, "UIPanelButtonTemplate")
    blessReadPPBtn:SetPoint("LEFT", blessSyncPPBtn, "RIGHT", 4, 0)
    blessReadPPBtn:SetWidth(78)
    blessReadPPBtn:SetHeight(20)
    blessReadPPBtn:SetText(RT_Text("bless_read_pp"))
    blessReadPPBtn:SetScript("OnClick", function() RT_BlessingsReadFromPallyPower() end)

    local blessChannelLbl = buffBlessFrame:CreateFontString("RT_BlessChannelLbl", "OVERLAY", "GameFontHighlightSmall")
    blessChannelLbl:SetPoint("LEFT", blessReadPPBtn, "RIGHT", 8, 0)
    blessChannelLbl:SetWidth(160)
    blessChannelLbl:SetJustifyH("LEFT")
    blessChannelLbl:SetText("")

    local blessAutoBtn = CreateFrame("Button", "RT_BlessAutoBtn", buffBlessFrame, "UIPanelButtonTemplate")
    blessAutoBtn:SetPoint("LEFT", blessReadPPBtn, "RIGHT", 8, 0)
    blessAutoBtn:SetWidth(105)
    blessAutoBtn:SetHeight(20)
    blessAutoBtn:SetText("Auto-Assign")
    local blessAutoTex = blessAutoBtn:GetNormalTexture()
    if blessAutoTex then blessAutoTex:SetVertexColor(1.0, 0.82, 0.0) end
    blessAutoBtn:SetScript("OnClick", function() RT_BlessingsAutoAssign() end)

    local blessStatus = buffBlessFrame:CreateFontString("RT_BlessStatus", "OVERLAY", "GameFontHighlightSmall")
    blessStatus:SetPoint("TOPLEFT", buffBlessFrame, "TOPLEFT", 6, -50)
    blessStatus:SetWidth(350)
    blessStatus:SetJustifyH("LEFT")
    blessStatus:SetText("")

    -- === Assignments Card (interactive class grid + paladin summary) ===
    local blessAssignCard = CreateFrame("Frame", "RT_BlessAssignCard", buffBlessFrame)
    blessAssignCard:SetPoint("TOPLEFT", buffBlessFrame, "TOPLEFT", 6, -68)
    blessAssignCard:SetWidth(713)
    blessAssignCard:SetHeight(352)
    RT_PatchBackdrop(blessAssignCard)
    blessAssignCard:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    blessAssignCard:SetBackdropColor(0.015, 0.02, 0.035, 0.82)
    blessAssignCard:SetBackdropBorderColor(0.36, 0.38, 0.50, 0.70)

    local blessAssignTitle = blessAssignCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    blessAssignTitle:SetPoint("TOPLEFT", blessAssignCard, "TOPLEFT", 8, -8)
    blessAssignTitle:SetText("Assignments")
    blessAssignTitle:SetTextColor(0.90, 0.82, 0.26)

    local blessAssignSub = blessAssignCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    blessAssignSub:SetPoint("TOPRIGHT", blessAssignCard, "TOPRIGHT", -8, -8)
    blessAssignSub:SetText("< Paladin >  < Blessing >")

    local blessHeadLine = blessAssignCard:CreateTexture(nil, "ARTWORK")
    blessHeadLine:SetPoint("TOPLEFT", blessAssignCard, "TOPLEFT", 8, -20)
    blessHeadLine:SetWidth(697)
    blessHeadLine:SetHeight(1)
    blessHeadLine:SetTexture(0.55, 0.46, 0.18, 0.55)

    -- Column headers
    local blessColPalaH = blessAssignCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    blessColPalaH:SetPoint("TOPLEFT", blessAssignCard, "TOPLEFT", 10, -28)
    blessColPalaH:SetText("Paladin")
    blessColPalaH:SetTextColor(0.55, 0.55, 0.60)

    local blessColBlessH = blessAssignCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    blessColBlessH:SetPoint("TOPLEFT", blessAssignCard, "TOPLEFT", 148, -28)
    blessColBlessH:SetText("Benediction")
    blessColBlessH:SetTextColor(0.55, 0.55, 0.60)

    local blessColPlayerH = blessAssignCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    blessColPlayerH:SetPoint("TOPLEFT", blessAssignCard, "TOPLEFT", 360, -28)
    blessColPlayerH:SetText("Joueur 10 min")
    blessColPlayerH:SetTextColor(0.55, 0.55, 0.60)

    -- Per-paladin interactive rows (up to 8)
    local blessMaxRows = 8
    local blessRowStartY = -42
    local blessRowH = 20

    for ri = 1, blessMaxRows do
        local riY = blessRowStartY - (ri - 1) * blessRowH
        local ri_cap = ri

        local rowFrame = CreateFrame("Frame", "RT_BlessRow_Frame_"..ri, blessAssignCard)
        rowFrame:SetPoint("TOPLEFT", blessAssignCard, "TOPLEFT", 8, riY)
        rowFrame:SetWidth(697)
        rowFrame:SetHeight(blessRowH)

        local palLbl = rowFrame:CreateFontString("RT_BlessRow_Lbl_"..ri, "OVERLAY", "GameFontHighlightSmall")
        palLbl:SetPoint("LEFT", rowFrame, "LEFT", 2, 0)
        palLbl:SetWidth(120)
        palLbl:SetJustifyH("LEFT")
        palLbl:SetText("—")
        palLbl:SetTextColor(0.96, 0.55, 0.73)

        local blessPrevBtn = CreateFrame("Button", "RT_BlessRow_BlessPrev_"..ri, rowFrame, "UIPanelButtonTemplate")
        blessPrevBtn:SetPoint("LEFT", rowFrame, "LEFT", 130, 0)
        blessPrevBtn:SetWidth(18)
        blessPrevBtn:SetHeight(16)
        blessPrevBtn:SetText("<")
        blessPrevBtn:SetScript("OnClick", function() RT_BlessCyclePalaBlessing(ri_cap, -1) end)

        local blessRowBtn = CreateFrame("Button", "RT_BlessRow_Bless_"..ri, rowFrame, "UIPanelButtonTemplate")
        blessRowBtn:SetPoint("LEFT", blessPrevBtn, "RIGHT", 2, 0)
        blessRowBtn:SetWidth(165)
        blessRowBtn:SetHeight(16)
        blessRowBtn:SetText("—")
        blessRowBtn:SetScript("OnClick", function() RT_BlessCyclePalaBlessing(ri_cap, 1) end)

        local blessNextBtn = CreateFrame("Button", "RT_BlessRow_BlessNext_"..ri, rowFrame, "UIPanelButtonTemplate")
        blessNextBtn:SetPoint("LEFT", blessRowBtn, "RIGHT", 2, 0)
        blessNextBtn:SetWidth(18)
        blessNextBtn:SetHeight(16)
        blessNextBtn:SetText(">")
        blessNextBtn:SetScript("OnClick", function() RT_BlessCyclePalaBlessing(ri_cap, 1) end)

        local playerPrevBtn = CreateFrame("Button", "RT_BlessRow_PlayerPrev_"..ri, rowFrame, "UIPanelButtonTemplate")
        playerPrevBtn:SetPoint("LEFT", blessNextBtn, "RIGHT", 10, 0)
        playerPrevBtn:SetWidth(18)
        playerPrevBtn:SetHeight(16)
        playerPrevBtn:SetText("<")
        playerPrevBtn:SetScript("OnClick", function() RT_BlessCyclePalaPlayer(ri_cap, -1) end)

        local playerRowBtn = CreateFrame("Button", "RT_BlessRow_Player_"..ri, rowFrame, "UIPanelButtonTemplate")
        playerRowBtn:SetPoint("LEFT", playerPrevBtn, "RIGHT", 2, 0)
        playerRowBtn:SetWidth(155)
        playerRowBtn:SetHeight(16)
        playerRowBtn:SetText("—")
        playerRowBtn:SetScript("OnClick", function() RT_BlessCyclePalaPlayer(ri_cap, 1) end)

        local playerNextBtn = CreateFrame("Button", "RT_BlessRow_PlayerNext_"..ri, rowFrame, "UIPanelButtonTemplate")
        playerNextBtn:SetPoint("LEFT", playerRowBtn, "RIGHT", 2, 0)
        playerNextBtn:SetWidth(18)
        playerNextBtn:SetHeight(16)
        playerNextBtn:SetText(">")
        playerNextBtn:SetScript("OnClick", function() RT_BlessCyclePalaPlayer(ri_cap, 1) end)
    end

    -- Separator before summary
    local blessMidLine = blessAssignCard:CreateTexture(nil, "ARTWORK")
    blessMidLine:SetPoint("TOPLEFT", blessAssignCard, "TOPLEFT", 8, -210)
    blessMidLine:SetWidth(697)
    blessMidLine:SetHeight(1)
    blessMidLine:SetTexture(0.36, 0.38, 0.50, 0.55)

    -- Summary label
    local blessAssignOnlyLabel = blessAssignCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    blessAssignOnlyLabel:SetPoint("TOPLEFT", blessAssignCard, "TOPLEFT", 10, -216)
    blessAssignOnlyLabel:SetText("Paladin -> Blessings")
    blessAssignOnlyLabel:SetTextColor(0.62, 0.66, 0.76)

    -- Scrollable paladin summary
    local blessAssignScroll = CreateFrame("ScrollFrame", "RT_BlessPallyOnlyScroll", blessAssignCard, "UIPanelScrollFrameTemplate")
    blessAssignScroll:SetPoint("TOPLEFT", blessAssignCard, "TOPLEFT", 8, -232)
    blessAssignScroll:SetWidth(680)
    blessAssignScroll:SetHeight(114)
    RT_PatchBackdrop(blessAssignScroll)
    blessAssignScroll:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    blessAssignScroll:SetBackdropColor(0.03, 0.05, 0.08, 0.55)
    blessAssignScroll:SetBackdropBorderColor(0.24, 0.34, 0.52, 0.60)

    local blessAssignContent = CreateFrame("Frame", "RT_BlessPallyOnlyContent", blessAssignScroll)
    blessAssignContent:SetWidth(660)
    blessAssignContent:SetHeight(160)
    blessAssignScroll:SetScrollChild(blessAssignContent)

    local blessAssignText = blessAssignContent:CreateFontString("RT_BlessPallyOnlyText", "OVERLAY", "GameFontHighlightSmall")
    blessAssignText:SetPoint("TOPLEFT", blessAssignContent, "TOPLEFT", 4, -4)
    blessAssignText:SetWidth(650)
    blessAssignText:SetJustifyH("LEFT")
    blessAssignText:SetJustifyV("TOP")
    blessAssignText:SetText("")

end

function RT_BuildUINotes(RT_MainFrame)
    if not RT_MainFrame then return end

    -- Panel Notes (Angry Assignments style)
    local notesPanel = RT_CreatePanel("RT_Panel_Notes")
    local notesTitle = notesPanel:CreateFontString("RT_NotesPanelTitle", "OVERLAY", "GameFontNormal")
    notesTitle:SetPoint("TOPLEFT", notesPanel, "TOPLEFT", 6, -4)
    notesTitle:SetText("Strats  —  éditeur de notes + tactiques vanilla")
    notesTitle:SetTextColor(0.5, 0.9, 1.0)

    local notesHint = notesPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    notesHint:SetPoint("TOPLEFT", notesPanel, "TOPLEFT", 6, -18)
    notesHint:SetText(RT_Text("notes_hint"))

    -- Ligne 1 : label + EditBox titre/boss + boutons Parcourir
    local notesKeyLbl = notesPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    notesKeyLbl:SetPoint("TOPLEFT", notesPanel, "TOPLEFT", 6, -34)
    notesKeyLbl:SetText(RT_Text("notes_boss_lbl"))
    notesKeyLbl:SetTextColor(0.8, 0.8, 0.8)

    local notesKeyEdit = CreateFrame("EditBox", "RT_NotesKeyEdit", notesPanel, "InputBoxTemplate")
    notesKeyEdit:SetPoint("TOPLEFT", notesPanel, "TOPLEFT", 108, -32)
    notesKeyEdit:SetWidth(160)
    notesKeyEdit:SetHeight(18)
    notesKeyEdit:SetAutoFocus(false)
    notesKeyEdit:SetText("")
    notesKeyEdit:SetScript("OnEnterPressed", function() notesKeyEdit:ClearFocus() end)
    notesKeyEdit:SetScript("OnEscapePressed", function() notesKeyEdit:ClearFocus() end)

    local notesBrowseBtn = CreateFrame("Button", "RT_NotesBrowseBtn", notesPanel, "UIPanelButtonTemplate")
    notesBrowseBtn:SetPoint("LEFT", notesKeyEdit, "RIGHT", 6, 0)
    notesBrowseBtn:SetWidth(100)
    notesBrowseBtn:SetHeight(20)
    notesBrowseBtn:SetText(RT_Text("notes_pick_btn"))
    notesBrowseBtn:SetScript("OnClick", function() RT_NotesBrowse() end)

    local notesSaveBtn = CreateFrame("Button", "RT_NotesSaveBtn", notesPanel, "UIPanelButtonTemplate")
    notesSaveBtn:SetPoint("LEFT", notesBrowseBtn, "RIGHT", 6, 0)
    notesSaveBtn:SetWidth(100)
    notesSaveBtn:SetHeight(20)
    notesSaveBtn:SetText(RT_Text("notes_save"))
    notesSaveBtn:SetScript("OnClick", function() RT_NotesSave() end)

    local notesDeleteBtn = CreateFrame("Button", "RT_NotesDeleteBtn", notesPanel, "UIPanelButtonTemplate")
    notesDeleteBtn:SetPoint("LEFT", notesSaveBtn, "RIGHT", 4, 0)
    notesDeleteBtn:SetWidth(80)
    notesDeleteBtn:SetHeight(20)
    notesDeleteBtn:SetText(RT_Text("notes_delete"))
    notesDeleteBtn:SetScript("OnClick", function() RT_NotesDelete() end)

    local notesDefaultBtn = CreateFrame("Button", "RT_NotesDefaultBtn", notesPanel, "UIPanelButtonTemplate")
    notesDefaultBtn:SetPoint("LEFT", notesDeleteBtn, "RIGHT", 4, 0)
    notesDefaultBtn:SetWidth(120)
    notesDefaultBtn:SetHeight(20)
    notesDefaultBtn:SetText("Strats par défaut")
    local ndTex = notesDefaultBtn:GetNormalTexture()
    if ndTex then ndTex:SetVertexColor(0.4, 0.9, 0.4) end
    notesDefaultBtn:SetScript("OnClick", function()
        RT_LoadDefaultStrats()
        local nbp = getglobal("RT_NotesBrowsePopup")
        if nbp and nbp:IsShown() then RT_NotesBrowsePopupRefresh() end
        RT_Print("|cff44FF88Strats vanilla chargées.|r")
    end)

    local notesBroadcastBtn = CreateFrame("Button", "RT_NotesBroadcastBtn", notesPanel, "UIPanelButtonTemplate")
    notesBroadcastBtn:SetPoint("LEFT", notesDefaultBtn, "RIGHT", 4, 0)
    notesBroadcastBtn:SetWidth(130)
    notesBroadcastBtn:SetHeight(20)
    notesBroadcastBtn:SetText(RT_Text("notes_broadcast"))
    notesBroadcastBtn:SetScript("OnClick", function() RT_NotesBroadcast() end)
    local notesBroadcastTex = notesBroadcastBtn:GetNormalTexture()
    if notesBroadcastTex then notesBroadcastTex:SetVertexColor(0.5, 0.85, 1.0) end

    local notesTplLbl = notesPanel:CreateFontString("RT_NotesTplLbl", "OVERLAY", "GameFontDisable")
    notesTplLbl:SetPoint("TOPLEFT", notesPanel, "TOPLEFT", 6, -56)
    notesTplLbl:SetText(RT_Text("notes_tpl_lbl"))

    local notesTplPullBtn = CreateFrame("Button", "RT_NotesTplPullBtn", notesPanel, "UIPanelButtonTemplate")
    notesTplPullBtn:SetPoint("LEFT", notesTplLbl, "RIGHT", 6, 0)
    notesTplPullBtn:SetWidth(70)
    notesTplPullBtn:SetHeight(18)
    notesTplPullBtn:SetText(RT_Text("notes_tpl_pull"))
    notesTplPullBtn:SetScript("OnClick", function() RT_NotesInsertTemplate("pull") end)

    local notesTplPosBtn = CreateFrame("Button", "RT_NotesTplPosBtn", notesPanel, "UIPanelButtonTemplate")
    notesTplPosBtn:SetPoint("LEFT", notesTplPullBtn, "RIGHT", 4, 0)
    notesTplPosBtn:SetWidth(90)
    notesTplPosBtn:SetHeight(18)
    notesTplPosBtn:SetText(RT_Text("notes_tpl_positions"))
    notesTplPosBtn:SetScript("OnClick", function() RT_NotesInsertTemplate("positions") end)

    local notesTplCdsBtn = CreateFrame("Button", "RT_NotesTplCdsBtn", notesPanel, "UIPanelButtonTemplate")
    notesTplCdsBtn:SetPoint("LEFT", notesTplPosBtn, "RIGHT", 4, 0)
    notesTplCdsBtn:SetWidth(70)
    notesTplCdsBtn:SetHeight(18)
    notesTplCdsBtn:SetText(RT_Text("notes_tpl_cds"))
    notesTplCdsBtn:SetScript("OnClick", function() RT_NotesInsertTemplate("cds") end)

    local notesChannelLbl = notesPanel:CreateFontString("RT_NotesChannelLbl", "OVERLAY", "GameFontHighlightSmall")
    notesChannelLbl:SetPoint("TOPRIGHT", notesPanel, "TOPRIGHT", -8, -56)
    notesChannelLbl:SetWidth(190)
    notesChannelLbl:SetJustifyH("RIGHT")
    notesChannelLbl:SetText("")

    -- Statut de la note en cours d'édition
    local notesStatus = notesPanel:CreateFontString("RT_NotesStatus", "OVERLAY", "GameFontHighlightSmall")
    notesStatus:SetPoint("TOPLEFT", notesPanel, "TOPLEFT", 6, -68)
    notesStatus:SetWidth(490)
    notesStatus:SetJustifyH("LEFT")
    notesStatus:SetText("|cff888888— aucune note sélectionnée —|r")

    -- Fond visuel derrière la zone de texte (frame séparé pour ne pas casser la scrollbar template)
    local notesScrollBg = CreateFrame("Frame", nil, notesPanel)
    notesScrollBg:SetPoint("TOPLEFT", notesPanel, "TOPLEFT", 4, -82)
    notesScrollBg:SetWidth(503)
    notesScrollBg:SetHeight(324)
    RT_PatchBackdrop(notesScrollBg)
    notesScrollBg:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    notesScrollBg:SetBackdropColor(0.02, 0.04, 0.06, 0.78)
    notesScrollBg:SetBackdropBorderColor(0.35, 0.52, 0.68, 0.65)

    -- Zone de texte multilignes (réduite pour laisser la place au sélecteur de boss)
    local notesScroll = CreateFrame("ScrollFrame", "RT_NotesScrollFrame", notesPanel, "UIPanelScrollFrameTemplate")
    notesScroll:SetPoint("TOPLEFT", notesPanel, "TOPLEFT", 6, -84)
    notesScroll:SetWidth(493)
    notesScroll:SetHeight(320)

    local notesEdit = CreateFrame("EditBox", "RT_NotesTextEdit", notesScroll)
    notesEdit:SetMultiLine(true)
    notesEdit:SetAutoFocus(false)
    notesEdit:SetFontObject(GameFontHighlightSmall)
    notesEdit:SetWidth(475)
    notesEdit:SetHeight(4000)
    notesEdit:SetText("")
    notesEdit:SetScript("OnEscapePressed", function() notesEdit:ClearFocus() end)
    notesEdit:SetScript("OnTextChanged", function()
        RT_NotesScrollFrame:UpdateScrollChildRect()
    end)
    notesScroll:SetScrollChild(notesEdit)
    notesScroll:EnableMouse(true)
    notesScroll:SetScript("OnMouseDown", function() notesEdit:SetFocus() end)

    -- Sélecteur de strat boss (colonne droite, aligné avec le scroll et le fond de texte)
    local bossPickFrame = CreateFrame("Frame", "RT_NotesBossPickFrame", notesPanel)
    bossPickFrame:SetPoint("TOPLEFT",    notesPanel, "TOPLEFT",  510, -84)
    bossPickFrame:SetPoint("BOTTOMRIGHT",notesPanel, "BOTTOMRIGHT", -6, 22)
    RT_PatchBackdrop(bossPickFrame)
    bossPickFrame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    bossPickFrame:SetBackdropColor(0.04, 0.04, 0.06, 0.80)
    bossPickFrame:SetBackdropBorderColor(0.4, 0.6, 0.9, 0.5)

    local bossPickLbl = bossPickFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bossPickLbl:SetPoint("TOPLEFT", bossPickFrame, "TOPLEFT", 12, -6)
    bossPickLbl:SetText(RT_Text("notes_strat_lbl"))
    bossPickLbl:SetTextColor(0.5, 0.9, 1.0)

    -- Sélecteur d'addon de suivi (DBM / BigWigs / Manuel)
    local addonLbl = bossPickFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    addonLbl:SetPoint("TOPLEFT", bossPickFrame, "TOPLEFT", 12, -20)
    addonLbl:SetText(RT_Text("notes_addon_lbl"))
    addonLbl:SetTextColor(0.7, 0.7, 0.7)

    local function makeAddonBtn(name, label, xOff, mode)
        local btn = CreateFrame("Button", name, bossPickFrame, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", bossPickFrame, "TOPLEFT", xOff, -36)
        btn:SetWidth(60)
        btn:SetHeight(18)
        btn:SetText(label)
        btn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        local m = mode
        btn:SetScript("OnClick", function() RT_NotesAddonSetMode(m) end)
        return btn
    end
    local btnNone = makeAddonBtn("RT_NotesAddonBtnNone", RT_Text("notes_addon_none"), 6,   "none")
    btnNone:SetWidth(50)
    local btnDBM  = makeAddonBtn("RT_NotesAddonBtnDBM",  RT_Text("notes_addon_dbm"),  60,  "dbm")
    btnDBM:SetWidth(44)
    local btnBW   = makeAddonBtn("RT_NotesAddonBtnBW",   RT_Text("notes_addon_bigwigs"), 108, "bigwigs")
    btnBW:SetWidth(54)

    RT_AttachSimpleTooltip(btnNone, RT_Text("notes_addon_tip_none"))
    RT_AttachSimpleTooltip(btnDBM, RT_Text("notes_addon_tip_dbm"))
    RT_AttachSimpleTooltip(btnBW, RT_Text("notes_addon_tip_bigwigs"))

    local detectBtn = CreateFrame("Button", "RT_NotesAddonDetectBtn", bossPickFrame, "UIPanelButtonTemplate")
    detectBtn:SetPoint("TOPLEFT", bossPickFrame, "TOPLEFT", 166, -36)
    detectBtn:SetWidth(46)
    detectBtn:SetHeight(18)
    detectBtn:SetText(RT_Text("notes_addon_detect"))
    detectBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    detectBtn:SetScript("OnClick", function() RT_NotesDetectCurrentBoss() end)
    RT_AttachSimpleTooltip(detectBtn, RT_Text("notes_addon_tip_detect"))

    local bossPickScroll = CreateFrame("ScrollFrame", "RT_NotesBossPickScroll", bossPickFrame, "UIPanelScrollFrameTemplate")
    bossPickScroll:SetPoint("TOPLEFT",    bossPickFrame, "TOPLEFT",    4,  -58)
    bossPickScroll:SetPoint("BOTTOMRIGHT",bossPickFrame, "BOTTOMRIGHT", -22, 4)
    local bossPickContent = CreateFrame("Frame", "RT_NotesBossPickContent", bossPickScroll)
    bossPickContent:SetWidth(180)
    bossPickContent:SetHeight(800)
    bossPickScroll:SetScrollChild(bossPickContent)

    -- Remplir le contenu du sélecteur de boss
    local bossY = -2
    for raidIdx = 1, table.getn(RT_BOSS_LIST) do
        local raid = RT_BOSS_LIST[raidIdx]
        -- En-tête de raid
        local raidHdr = bossPickContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        raidHdr:SetPoint("TOPLEFT", bossPickContent, "TOPLEFT", 4, bossY)
        raidHdr:SetText(raid.raid)
        raidHdr:SetTextColor(raid.color[1], raid.color[2], raid.color[3])
        bossY = bossY - 14
        -- Boutons boss
        for bossIdx = 1, table.getn(raid.bosses) do
            local bossName = raid.bosses[bossIdx]
            local bBtn = CreateFrame("Button", "RT_BossStratBtn_" .. raidIdx .. "_" .. bossIdx,
                bossPickContent, "UIPanelButtonTemplate")
            bBtn:SetPoint("TOPLEFT", bossPickContent, "TOPLEFT", 2, bossY)
            bBtn:SetWidth(176)
            bBtn:SetHeight(16)
            bBtn:SetText(bossName)
            bBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            local bn = bossName
            bBtn:SetScript("OnClick", function()
                RT_NotesLoadKey(bn)
                -- Si pas encore de strat pour ce boss, pré-remplir la clé
                local ke = getglobal("RT_NotesKeyEdit")
                if ke then ke:SetText(bn) end
            end)
            bossY = bossY - 17
        end
        bossY = bossY - 4  -- espace entre raids
    end
    bossPickContent:SetHeight(math.abs(bossY) + 10)
    RT_NotesBossPickScroll:UpdateScrollChildRect()

    -- Popup liste des notes sauvegardées
    local notesBrowsePopup = CreateFrame("Frame", "RT_NotesBrowsePopup", RT_MainFrame)
    notesBrowsePopup:SetWidth(220)
    notesBrowsePopup:SetHeight(230)
    notesBrowsePopup:SetPoint("TOPLEFT", RT_MainFrame, "TOPLEFT", 120, -110)
    notesBrowsePopup:SetFrameStrata("TOOLTIP")
    RT_PatchBackdrop(notesBrowsePopup)
    notesBrowsePopup:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets = { left=4, right=4, top=4, bottom=4 },
    })
    notesBrowsePopup:Hide()
    notesBrowsePopup:SetScript("OnShow", function() RT_NotesBrowsePopupRefresh() end)
    local notesBrowseTitle = notesBrowsePopup:CreateFontString("RT_NotesBrowseTitle", "OVERLAY", "GameFontNormal")
    notesBrowseTitle:SetPoint("TOPLEFT", notesBrowsePopup, "TOPLEFT", 8, -6)
    notesBrowseTitle:SetText(RT_Text("notes_browse_title"))
    notesBrowseTitle:SetTextColor(0.5, 0.9, 1.0)
    local notesBrowseClose = CreateFrame("Button", "RT_NotesBrowseCloseBtn", notesBrowsePopup, "UIPanelButtonTemplate")
    notesBrowseClose:SetPoint("BOTTOMRIGHT", notesBrowsePopup, "BOTTOMRIGHT", -6, 6)
    notesBrowseClose:SetWidth(60)
    notesBrowseClose:SetHeight(18)
    notesBrowseClose:SetText(RT_Text("picker_close"))
    notesBrowseClose:SetScript("OnClick", function() notesBrowsePopup:Hide() end)
    -- Scroll pour les entrées de la liste
    local notesBrowseScroll = CreateFrame("ScrollFrame", "RT_NotesBrowseScroll", notesBrowsePopup, "UIPanelScrollFrameTemplate")
    notesBrowseScroll:SetPoint("TOPLEFT",     notesBrowsePopup, "TOPLEFT",     6,  -22)
    notesBrowseScroll:SetPoint("BOTTOMRIGHT", notesBrowsePopup, "BOTTOMRIGHT", -26, 30)
    local notesBrowseContent = CreateFrame("Frame", "RT_NotesBrowseContent", notesBrowseScroll)
    notesBrowseContent:SetWidth(190)
    notesBrowseContent:SetHeight(400)
    notesBrowseScroll:SetScrollChild(notesBrowseContent)
end

function RT_BuildUICheck(checkPanel)
    if not checkPanel then return end

    -- === Gauche : Scan buffs ===
    local checkScanBtn = CreateFrame("Button", "RT_CheckScanBtn", checkPanel, "UIPanelButtonTemplate")
    checkScanBtn:SetPoint("TOPLEFT", checkPanel, "TOPLEFT", 6, -24)
    checkScanBtn:SetWidth(120)
    checkScanBtn:SetHeight(22)
    checkScanBtn:SetText(RT_Text("check_scan_btn"))
    checkScanBtn:SetScript("OnClick", function() RT_CheckScanRaid() end)
    local checkScanTex = checkScanBtn:GetNormalTexture()
    if checkScanTex then checkScanTex:SetVertexColor(0.4, 1.0, 0.6) end

    local checkClearBtn = CreateFrame("Button", "RT_CheckClearBtn", checkPanel, "UIPanelButtonTemplate")
    checkClearBtn:SetPoint("LEFT", checkScanBtn, "RIGHT", 3, 0)
    checkClearBtn:SetWidth(60)
    checkClearBtn:SetHeight(22)
    checkClearBtn:SetText(RT_Text("check_clear"))
    checkClearBtn:SetScript("OnClick", function()
        local log = getglobal("RT_CheckLog")
        if log then log:Clear() end
    end)

    local checkAnnBtn = CreateFrame("Button", "RT_CheckAnnounceBtn", checkPanel, "UIPanelButtonTemplate")
    checkAnnBtn:SetPoint("LEFT", checkClearBtn, "RIGHT", 3, 0)
    checkAnnBtn:SetWidth(138)
    checkAnnBtn:SetHeight(22)
    checkAnnBtn:SetText("Annoncer manquants")
    checkAnnBtn:SetScript("OnClick", function() RT_CheckAnnounceMissing() end)
    local checkAnnTex = checkAnnBtn:GetNormalTexture()
    if checkAnnTex then checkAnnTex:SetVertexColor(1.0, 0.75, 0.2) end

    -- Config buffs : quels types scanner / annoncer
    local buffCfgLbl = checkPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buffCfgLbl:SetPoint("TOPLEFT", checkPanel, "TOPLEFT", 6, -52)
    buffCfgLbl:SetText("|cffFFD700Annoncer :|r")

    local function makeBuffToggle(name, label, anchorX)
        local b = CreateFrame("Button", name, checkPanel, "UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT", checkPanel, "TOPLEFT", anchorX, -50)
        b:SetWidth(82)
        b:SetHeight(18)
        b:SetText(label)
        return b
    end

    local bFlask  = makeBuffToggle("RT_CheckToggleFlask",  "Flasque",   82)
    local bFood   = makeBuffToggle("RT_CheckToggleFood",   "Nourriture",168)
    local bWeapon = makeBuffToggle("RT_CheckToggleWeapon", "Arme",      254)
    bFlask:SetScript("OnClick",  function() RT_CheckToggleBuff("flask") end)
    bFood:SetScript("OnClick",   function() RT_CheckToggleBuff("food") end)
    bWeapon:SetScript("OnClick", function() RT_CheckToggleBuff("weapon") end)

    -- Log des scans (décalé pour laisser la place aux toggles)
    local checkLog = CreateFrame("ScrollingMessageFrame", "RT_CheckLog", checkPanel)
    checkLog:SetPoint("TOPLEFT", checkPanel, "TOPLEFT", 6, -74)
    checkLog:SetWidth(358)
    checkLog:SetHeight(366)
    checkLog:SetFontObject(GameFontNormalSmall)
    checkLog:SetJustifyH("LEFT")
    checkLog:SetFading(false)
    checkLog:SetMaxLines(300)
    RT_PatchBackdrop(checkLog)
    checkLog:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    checkLog:SetBackdropColor(0.01, 0.02, 0.03, 0.72)
    checkLog:SetBackdropBorderColor(0.40, 0.65, 0.50, 0.70)

    -- === Droite : Cooldowns ===
    local cdSep = checkPanel:CreateTexture(nil, "ARTWORK")
    cdSep:SetPoint("TOPLEFT", checkPanel, "TOPLEFT", 370, -10)
    cdSep:SetWidth(1)
    cdSep:SetHeight(430)
    cdSep:SetTexture(0.5, 0.5, 0.5, 0.3)

    local cdTitle = checkPanel:CreateFontString("RT_CDPanelTitle", "OVERLAY", "GameFontNormal")
    cdTitle:SetPoint("TOPLEFT", checkPanel, "TOPLEFT", 378, -4)
    cdTitle:SetText(RT_Text("cd_title"))
    cdTitle:SetTextColor(1.0, 0.85, 0.1)

    local cdRefreshBtn = CreateFrame("Button", "RT_CDRefreshBtn", checkPanel, "UIPanelButtonTemplate")
    cdRefreshBtn:SetPoint("TOPLEFT", checkPanel, "TOPLEFT", 378, -24)
    cdRefreshBtn:SetWidth(110)
    cdRefreshBtn:SetHeight(22)
    cdRefreshBtn:SetText(RT_Text("cd_refresh"))
    cdRefreshBtn:SetScript("OnClick", function() RT_CooldownDisplay() end)

    -- Config CDs : 2 rangées de toggles (4 par rangée)
    local cdCfgLbl = checkPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cdCfgLbl:SetPoint("TOPLEFT", checkPanel, "TOPLEFT", 378, -52)
    cdCfgLbl:SetText("|cffFFD700Afficher :|r")

    local cdShortLabels = {
        { key = "cd_rebirth",      label = "B.Rez"    },
        { key = "cd_innervate",    label = "Innervate" },
        { key = "cd_bloodlust",    label = "Bloodlust" },
        { key = "cd_ankh",         label = "Ankh"      },
        { key = "cd_lay_on_hands", label = "LoH"       },
        { key = "cd_divine_int",   label = "Div.Int"   },
        { key = "cd_soulstone",    label = "Soulstone" },
        { key = "cd_misdirection", label = "Misdir."   },
    }
    local cdToggleW = 82
    local cdToggleH = 18
    for idx = 1, table.getn(cdShortLabels) do
        local entry = cdShortLabels[idx]
        local col   = math.mod(idx - 1, 4)
        local row   = math.floor((idx - 1) / 4)
        local xOff  = 378 + col * (cdToggleW + 2)
        local yOff  = -50 - row * (cdToggleH + 2)
        local btn = CreateFrame("Button", "RT_CDToggle_" .. entry.key, checkPanel, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", checkPanel, "TOPLEFT", xOff, yOff)
        btn:SetWidth(cdToggleW)
        btn:SetHeight(cdToggleH)
        btn:SetText(entry.label)
        local k = entry.key
        btn:SetScript("OnClick", function() RT_CheckToggleCD(k) end)
    end

    -- Log des CDs (décalé sous les 2 rangées de toggles)
    local cdLog = CreateFrame("ScrollingMessageFrame", "RT_CooldownLog", checkPanel)
    cdLog:SetPoint("TOPLEFT", checkPanel, "TOPLEFT", 378, -94)
    cdLog:SetWidth(344)
    cdLog:SetHeight(346)
    cdLog:SetFontObject(GameFontNormalSmall)
    cdLog:SetJustifyH("LEFT")
    cdLog:SetFading(false)
    cdLog:SetMaxLines(200)
    RT_PatchBackdrop(cdLog)
    cdLog:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    cdLog:SetBackdropColor(0.02, 0.02, 0.04, 0.72)
    cdLog:SetBackdropBorderColor(0.65, 0.55, 0.30, 0.70)
end

-- ============================================================
-- Panel Roster — affichage
-- ============================================================

function RT_RosterDisplay()
    local scroll = getglobal("RT_RosterScrollFrame")
    local text   = getglobal("RT_RosterText")
    if not scroll or not text then return end

    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", RT_Panel_Roster, "TOPLEFT", 6, -60)
    scroll:SetWidth(718)
    scroll:SetHeight(348)
    scroll:Show()

    RT_RosterRefreshRoleEditor()

    local out = {}
    local function add(line)
        table.insert(out, line or "")
    end

    local roster = RT_DB.roster or {}
    local total  = RT_CountPlayers()

    if total == 0 then
        add(RT_ColorTitle("Roster vide")
            .. " — utilise l'onglet |cffFFFFFFImport CSV|r pour charger les donnees.")
        local lootCount = 0
        for _ in pairs(RT_DB.loot or {}) do lootCount = lootCount + 1 end
        if lootCount > 0 then
            add("|cffAAAAAAJoueurs detectes dans loot: " .. lootCount
                .. " (reimporte CSV pour reconstruire roster).|r")
        end
        text:SetText(table.concat(out, "\n"))
        RT_RosterScrollFrame:UpdateScrollChildRect()
        RT_RosterScrollFrame:SetVerticalScroll(0)
        return
    end

    local counts = RT_CountRoles()

    -- Mettre à jour le compteur en haut à droite du panel
    local countLbl = getglobal("RT_RosterCount")
    if countLbl then
        countLbl:SetText(
            "|cffFF6666T:" .. counts.Tank .. "|r  "
            .. "|cff88FF88H:" .. counts.Heal .. "|r  "
            .. "|cffFFDD44D:" .. counts.DPS .. "|r  "
            .. "|cff888888/" .. total .. "|r"
        )
    end

    -- En-tête résumé
    local header = RT_ColorTitle("=== Roster (" .. total .. " joueurs) ===")
        .. "   " .. RT_ColorRole("Tank") .. " " .. RT_ColorGold(counts.Tank)
        .. "   " .. RT_ColorRole("Heal") .. " " .. RT_ColorGold(counts.Heal)
        .. "   " .. RT_ColorRole("DPS")  .. " " .. RT_ColorGold(counts.DPS)
    add(header)
    add(" ")

    -- Construire la liste triée : Tank → Heal → DPS, puis par nom
    local sorted = {}
    for name, data in pairs(roster) do
        local role = RT_NormalizeRole(data.role)
        if RT_ROSTER_ROLE_FILTER == "All" or role == RT_ROSTER_ROLE_FILTER then
            table.insert(sorted, { name = name, data = data })
        end
    end
    if table.getn(sorted) == 0 and total > 0 then
        if RT_ROSTER_ROLE_FILTER ~= "All" then
            add("|cffAAAAAAFiltre " .. RT_ROSTER_ROLE_FILTER .. " vide, affichage de tous les joueurs.|r")
            add(" ")
        end
        RT_ROSTER_ROLE_FILTER = "All"
        for name, data in pairs(roster) do
            table.insert(sorted, { name = name, data = data })
        end
    end
    table.sort(sorted, function(a, b)
        local order = { Tank = 1, Heal = 2, DPS = 3 }
        local ra = order[RT_NormalizeRole(a.data.role)] or 4
        local rb = order[RT_NormalizeRole(b.data.role)] or 4
        if ra ~= rb then return ra < rb end
        return a.name < b.name
    end)

    local prevRole = nil
    for sIdx = 1, table.getn(sorted) do
        local entry = sorted[sIdx]
        local p    = entry.data
        local role = RT_NormalizeRole(p.role)

        -- Séparateur de section par rôle
        if role ~= prevRole then
            if prevRole then add(" ") end
            add("|cff888888-- " .. role .. "s -----|r")
            prevRole = role
        end

        local marker = (entry.name == RT_ROSTER_SELECTED_PLAYER) and "|cffFFD200*|r " or "  "
        local line = marker .. RT_ColorRole(role)
            .. "  " .. RT_ColorClass(entry.name, p.class)
            .. "  |cffAAAAAA" .. (p.spec  or "?") .. "|r"
            .. "  SR+: " .. RT_ColorGold(tostring(p.sr or 0))
        add(line)
    end

    text:SetText(table.concat(out, "\n"))
    RT_RosterScrollFrame:UpdateScrollChildRect()
    RT_RosterScrollFrame:SetVerticalScroll(0)

    -- Mettre à jour le compteur dans le header du panel
    local countLabel = getglobal("RT_RosterCount")
    if countLabel then
        countLabel:SetText(RT_ColorGold(total .. " players"))
    end
end

-- ============================================================
-- Panel Groups — pré-groupement et placement auto raid
-- ============================================================

function RT_GroupEnsureDB()
    RT_DB.groupPlanner = RT_DB.groupPlanner or {}
    RT_DB.groupPlanner.autoApply = (RT_DB.groupPlanner.autoApply ~= false)
    RT_DB.groupPlanner.plan = RT_DB.groupPlanner.plan or { groups = {} }
    RT_DB.groupPlanner.plan.groups = RT_DB.groupPlanner.plan.groups or {}
end

local function RT_GroupTrim(s)
    local t = string.gsub(s or "", "^%s+", "")
    t = string.gsub(t, "%s+$", "")
    return t
end

local function RT_GroupLowerName(name)
    return string.lower(RT_GroupTrim(name or ""))
end

local function RT_GroupResolveRosterName(name)
    local n = RT_GroupTrim(name or "")
    if n == "" then return "" end
    local roster = RT_DB.roster or {}
    if roster[n] then return n end
    local low = RT_GroupLowerName(n)
    for rn, _ in pairs(roster) do
        if RT_GroupLowerName(rn) == low then
            return rn
        end
    end
    return n
end

local function RT_GroupEnsurePlanLayout()
    RT_GroupEnsureDB()
    local groups = RT_DB.groupPlanner.plan.groups or {}
    for g = 1, 8 do
        local src = groups[g] or {}
        local dst = {}
        local k = 1
        for i = 1, table.getn(src) do
            if src[i] and src[i] ~= "" then
                if k <= 5 then
                    dst[k] = src[i]
                    k = k + 1
                end
            end
        end
        for i = k, 5 do dst[i] = "" end
        groups[g] = dst
    end
    RT_DB.groupPlanner.plan.groups = groups
end

local function RT_GroupFindPlayerSlot(name)
    RT_GroupEnsurePlanLayout()
    local low = RT_GroupLowerName(name)
    local groups = RT_DB.groupPlanner.plan.groups or {}
    for g = 1, 8 do
        for s = 1, 5 do
            if RT_GroupLowerName(groups[g][s] or "") == low then
                return g, s
            end
        end
    end
    return nil, nil
end

local function RT_GroupSetSlot(groupIdx, slotIdx, playerName)
    RT_GroupEnsurePlanLayout()
    if not groupIdx or groupIdx < 1 or groupIdx > 8 then
        return false, "Groupe invalide."
    end
    if not slotIdx or slotIdx < 1 or slotIdx > 5 then
        return false, "Slot invalide."
    end

    local groups = RT_DB.groupPlanner.plan.groups or {}
    local name = RT_GroupResolveRosterName(playerName or "")
    if name == "" then
        groups[groupIdx][slotIdx] = ""
        RT_DB.groupPlanner.plan.generatedAt = date("%d/%m %H:%M")
        return true, "Slot vidé."
    end

    local oldG, oldS = RT_GroupFindPlayerSlot(name)
    if oldG and oldS then
        groups[oldG][oldS] = ""
    end
    groups[groupIdx][slotIdx] = name
    RT_DB.groupPlanner.plan.generatedAt = date("%d/%m %H:%M")
    return true, name .. " -> G" .. groupIdx .. " S" .. slotIdx
end

function RT_GroupCloseSlotEditor()
    local popup = getglobal("RT_GroupSlotPopup")
    if popup then popup:Hide() end
    RT_GROUP_SLOT_CTX = nil
    RT_GROUP_SLOT_AC_CACHE = {}
    RT_GROUP_SLOT_AC_SELECTED_IDX = 0
end

local function RT_GroupSlotEditorRenderSelection()
    local roster = RT_DB.roster or {}
    for i = 1, 8 do
        local b = getglobal("RT_GroupSlotPick" .. i)
        local name = RT_GROUP_SLOT_AC_CACHE[i]
        if b and name then
            local p = roster[name]
            local txt = RT_ColorClass(name, p and p.class or "?")
            if i == RT_GROUP_SLOT_AC_SELECTED_IDX then
                b:SetText("|cffFFD200>|r " .. txt)
            else
                b:SetText("  " .. txt)
            end
        end
    end
end

function RT_GroupSlotEditorSelect(playerName)
    local edit = getglobal("RT_GroupSlotEdit")
    if not edit then return end
    edit:SetText(RT_GroupResolveRosterName(playerName))
end

function RT_GroupSlotEditorMoveSelection(delta)
    if not RT_GROUP_SLOT_AC_CACHE or not RT_GROUP_SLOT_AC_CACHE[1] then return end
    local n = table.getn(RT_GROUP_SLOT_AC_CACHE)
    if n <= 0 then return end
    local idx = RT_GROUP_SLOT_AC_SELECTED_IDX or 1
    if idx < 1 then idx = 1 end
    idx = idx + (delta or 0)
    if idx < 1 then idx = n end
    if idx > n then idx = 1 end
    RT_GROUP_SLOT_AC_SELECTED_IDX = idx
    RT_GroupSlotEditorRenderSelection()
end

function RT_GroupSlotEditorRefresh()
    local edit = getglobal("RT_GroupSlotEdit")
    if not edit then return end

    local query = RT_GroupLowerName(edit:GetText() or "")
    local roster = RT_DB.roster or {}
    local list = {}
    for name, _ in pairs(roster) do
        local low = RT_GroupLowerName(name)
        if query == "" or string.find(low, query, 1, true) then
            table.insert(list, name)
        end
    end
    table.sort(list)

    RT_GROUP_SLOT_AC_CACHE = {}
    RT_GROUP_SLOT_AC_SELECTED_IDX = 0
    local shown = 0
    for i = 1, 8 do
        local b = getglobal("RT_GroupSlotPick" .. i)
        local name = list[i]
        if b then
            if name then
                shown = shown + 1
                RT_GROUP_SLOT_AC_CACHE[i] = name
                local p = roster[name]
                b:SetText("  " .. RT_ColorClass(name, p and p.class or "?"))
                local pick = name
                b:SetScript("OnClick", function() RT_GroupSlotEditorSelect(pick) end)
                b:Show()
            else
                b:SetText("")
                b:SetScript("OnClick", nil)
                b:Hide()
            end
        end
    end
    if shown > 0 then
        RT_GROUP_SLOT_AC_SELECTED_IDX = 1
        RT_GroupSlotEditorRenderSelection()
    end
end

function RT_GroupSlotEditorConfirm()
    if not RT_GROUP_SLOT_CTX then return end
    local edit = getglobal("RT_GroupSlotEdit")
    local status = getglobal("RT_GroupsStatus")
    if not edit then return end

    local raw = RT_GroupTrim(edit:GetText() or "")
    local name = RT_GroupResolveRosterName(raw)
    if raw == "" then
        local idx = RT_GROUP_SLOT_AC_SELECTED_IDX or 0
        if idx > 0 and RT_GROUP_SLOT_AC_CACHE[idx] then
            name = RT_GroupResolveRosterName(RT_GROUP_SLOT_AC_CACHE[idx])
            edit:SetText(name)
        end
    elseif name == raw and not (RT_DB.roster and RT_DB.roster[name]) then
        local idx2 = RT_GROUP_SLOT_AC_SELECTED_IDX or 0
        if idx2 > 0 and RT_GROUP_SLOT_AC_CACHE[idx2] then
            name = RT_GroupResolveRosterName(RT_GROUP_SLOT_AC_CACHE[idx2])
            edit:SetText(name)
        end
    end

    local ok, msg = RT_GroupSetSlot(RT_GROUP_SLOT_CTX.groupIdx, RT_GROUP_SLOT_CTX.slotIdx, name)
    if status then
        if ok then status:SetText(RT_ColorOK(msg)) else status:SetText(RT_ColorErr(msg)) end
    end
    RT_GroupCloseSlotEditor()
    RT_GroupDisplay()
end

function RT_GroupSlotEditorClear()
    if not RT_GROUP_SLOT_CTX then return end
    local status = getglobal("RT_GroupsStatus")
    local ok, msg = RT_GroupSetSlot(RT_GROUP_SLOT_CTX.groupIdx, RT_GROUP_SLOT_CTX.slotIdx, "")
    if status then
        if ok then status:SetText(RT_ColorOK(msg)) else status:SetText(RT_ColorErr(msg)) end
    end
    RT_GroupCloseSlotEditor()
    RT_GroupDisplay()
end

function RT_GroupOpenSlotEditor(groupIdx, slotIdx)
    RT_GroupEnsurePlanLayout()
    local popup = getglobal("RT_GroupSlotPopup")
    local title = getglobal("RT_GroupSlotPopupTitle")
    local edit = getglobal("RT_GroupSlotEdit")
    if not popup or not edit then return end

    RT_GROUP_SLOT_CTX = { groupIdx = groupIdx, slotIdx = slotIdx }
    local groups = RT_DB.groupPlanner.plan.groups or {}
    local current = (groups[groupIdx] and groups[groupIdx][slotIdx]) or ""

    if title then title:SetText("G" .. groupIdx .. " - Slot " .. slotIdx) end
    edit:SetText(current or "")
    RT_PopupBringToFront(popup)
    edit:SetFocus()
    RT_GroupSlotEditorRefresh()
end

local function RT_GroupRemoveFromAll(name)
    RT_GroupEnsureDB()
    RT_GroupEnsurePlanLayout()
    local groups = RT_DB.groupPlanner.plan.groups or {}
    local low = RT_GroupLowerName(name)
    local oldGroup = nil

    for g = 1, 8 do
        local arr = groups[g] or {}
        for i = 1, 5 do
            if RT_GroupLowerName(arr[i] or "") == low then
                arr[i] = ""
                oldGroup = g
            end
        end
        groups[g] = arr
    end
    return oldGroup
end

function RT_GroupSetPlayerGroup(name, groupIdx)
    RT_GroupEnsureDB()
    RT_GroupEnsurePlanLayout()
    local n = RT_GroupResolveRosterName(name)
    if n == "" then
        return false, "Nom joueur vide."
    end
    if not groupIdx or groupIdx < 1 or groupIdx > 8 then
        return false, "Groupe invalide (1-8)."
    end

    local groups = RT_DB.groupPlanner.plan.groups or {}
    RT_GroupRemoveFromAll(n)

    local freeSlot = nil
    for s = 1, 5 do
        if not groups[groupIdx][s] or groups[groupIdx][s] == "" then
            freeSlot = s
            break
        end
    end
    if not freeSlot then
        return false, "G" .. groupIdx .. " est plein (5)."
    end

    groups[groupIdx][freeSlot] = n
    RT_DB.groupPlanner.plan.generatedAt = date("%d/%m %H:%M")
    return true, n .. " -> G" .. groupIdx
end

function RT_GroupRemovePlayer(name)
    local n = RT_GroupResolveRosterName(name)
    if n == "" then return false, "Nom joueur vide." end
    local oldGroup = RT_GroupRemoveFromAll(n)
    if oldGroup then
        RT_DB.groupPlanner.plan.generatedAt = date("%d/%m %H:%M")
        return true, n .. " retiré de G" .. oldGroup
    end
    return false, n .. " n'est pas dans le plan."
end

local function RT_GroupIsMelee(data)
    if not data then return false end
    local class = data.class or ""
    local spec = data.spec or ""
    local role = RT_NormalizeRole(data.role)

    if role == "Tank" then return true end
    if RT_GROUP_MELEE_SPECS[spec] then return true end
    if role == "DPS" and RT_GROUP_MELEE_CLASSES[class] then return true end
    return false
end

local function RT_GroupCanManageRaid()
    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    if n == 0 then return false end
    local me = UnitName("player")
    if not me then return false end

    for i = 1, n do
        local name, rank = GetRaidRosterInfo(i)
        if name == me then
            return (rank and rank > 0)
        end
    end
    return false
end

local function RT_GroupCanInvite()
    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if nRaid > 0 then
        return RT_GroupCanManageRaid()
    end
    if UnitIsPartyLeader and UnitIsPartyLeader("player") then return true end
    local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    if nParty == 0 then return true end
    return false
end

local function RT_GroupAutoConvertToRaidIfNeeded()
    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if nRaid > 0 then return end
    local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    if nParty <= 0 then return end
    if not (UnitIsPartyLeader and UnitIsPartyLeader("player")) then return end
    if ConvertToRaid then
        pcall(ConvertToRaid)
    end
end

local function RT_GroupUpdateInviteTickLabel()
    local lbl = getglobal("RT_GroupsInviteTick")
    if not lbl then return end
    if not RT_DB or not RT_DB.groupPlanner or not RT_DB.groupPlanner.autoInvite then
        lbl:SetText("InvAuto: OFF")
        return
    end
    local left = (RT_GROUP_INVITE_INTERVAL or 8) - (RT_GROUP_INVITE_TIMER or 0)
    if left < 0 then left = 0 end
    lbl:SetText("Next invite: " .. math.ceil(left) .. "s")
end

local function RT_GroupBuildAlreadyGroupedMap()
    local map = {}
    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if nRaid > 0 then
        for i = 1, nRaid do
            local name = GetRaidRosterInfo(i)
            if name and name ~= "" then map[RT_GroupLowerName(name)] = true end
        end
        return map
    end

    local me = UnitName("player")
    if me and me ~= "" then map[RT_GroupLowerName(me)] = true end
    local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    for i = 1, nParty do
        local name = UnitName("party" .. i)
        if name and name ~= "" then map[RT_GroupLowerName(name)] = true end
    end
    return map
end

local function RT_GroupInvitePlanned(maxInvites, silent)
    RT_GroupEnsurePlanLayout()
    RT_GroupAutoConvertToRaidIfNeeded()
    if not RT_GroupCanInvite() then
        if not silent then
            local status = getglobal("RT_GroupsStatus")
            if status then status:SetText(RT_ColorErr(RT_Text("need_leader_invite"))) end
        end
        return 0
    end

    local grouped = RT_GroupBuildAlreadyGroupedMap()
    local groups = RT_DB.groupPlanner.plan and RT_DB.groupPlanner.plan.groups or {}
    local order = {}
    for g = 1, 8 do
        local arr = groups[g] or {}
        for i = 1, 5 do
            local name = arr[i]
            if name and name ~= "" then
                table.insert(order, name)
            end
        end
    end
    local total = table.getn(order)
    if total == 0 then
        if not silent then
            local status = getglobal("RT_GroupsStatus")
            if status then status:SetText(RT_ColorErr(RT_Text("no_planned_players"))) end
        end
        return 0
    end

    local invited = 0
    local skipped = nil
    local attempts = 0
    local maxInv = maxInvites or total
    if maxInv < 1 then maxInv = 1 end

    while attempts < total and invited < maxInv do
        RT_GROUP_INVITE_CURSOR = (RT_GROUP_INVITE_CURSOR or 0) + 1
        if RT_GROUP_INVITE_CURSOR > total then RT_GROUP_INVITE_CURSOR = 1 end

        local name = order[RT_GROUP_INVITE_CURSOR]
        local low = RT_GroupLowerName(name)
        if not grouped[low] then
            if not RT_GROUP_INVITE_ATTEMPTED[low] then
                InviteByName(name)
                RT_GROUP_INVITE_ATTEMPTED[low] = true
                invited = invited + 1
            else
                if not skipped then skipped = name end
            end
        end
        attempts = attempts + 1
    end

    local pending = 0
    for i = 1, total do
        local low = RT_GroupLowerName(order[i])
        if not grouped[low] and not RT_GROUP_INVITE_ATTEMPTED[low] then
            pending = pending + 1
        end
    end
    if pending == 0 then
        RT_GROUP_INVITE_ATTEMPTED = {}
    end

    if invited == 0 and skipped then
        local status = getglobal("RT_GroupsStatus")
        if status then status:SetText("|cffffcc00Skip|r " .. skipped .. " (" .. RT_Text("skip_after_tour") .. ")") end
        return 0
    end

    if not silent then
        local status = getglobal("RT_GroupsStatus")
        if status then status:SetText(RT_ColorOK(RT_Text("invs_sent", {n=invited}))) end
    end
    return invited
end

local function RT_GroupPlanAsMap()
    RT_GroupEnsureDB()
    RT_GroupEnsurePlanLayout()
    local map = {}
    local groups = RT_DB.groupPlanner.plan.groups or {}
    for g = 1, 8 do
        local arr = groups[g] or {}
        for i = 1, 5 do
            local nm = arr[i]
            if nm and nm ~= "" then
                map[RT_GroupLowerName(nm)] = g
            end
        end
    end
    return map
end

function RT_GroupRefreshFromRaid()
    RT_DB = RT_DB or {}
    local status = getglobal("RT_GroupsStatus")

    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if nRaid == 0 then
        local msg = RT_Text("raid_refresh_empty")
        if status then status:SetText(RT_ColorErr(msg)) end
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF7777[RT]|r " .. msg)
        return
    end

    RT_GroupEnsureDB()

    -- Relit les groupes réels depuis le jeu, sans toucher au roster
    local newGroups = {}
    for g = 1, 8 do newGroups[g] = {} end
    local slotCount = {}
    for g = 1, 8 do slotCount[g] = 0 end

    local count = 0
    for i = 1, nRaid do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if name and subgroup and subgroup >= 1 and subgroup <= 8 then
            slotCount[subgroup] = slotCount[subgroup] + 1
            if slotCount[subgroup] <= 5 then
                newGroups[subgroup][slotCount[subgroup]] = name
            end
            count = count + 1
        end
    end

    RT_DB.groupPlanner.plan.groups = newGroups

    local msg = RT_Text("raid_refreshed", {n=count})
    if status then status:SetText(RT_ColorOK(msg)) end
    DEFAULT_CHAT_FRAME:AddMessage("|cff88FF88[RT]|r " .. msg)
    RT_GroupDisplay()
end

function RT_GroupGenerateAutoPlan()
    RT_GroupEnsureDB()
    local roster = RT_DB.roster or {}

    -- Buckets TurtleWoW meta — AUCUN heal dans les groupes DPS/Tank
    -- Les groupes sont construits UNIQUEMENT par synergie de bonus de groupe
    local tanks     = {}   -- role Tank -> Groupe 1
    local enhShaman = {}   -- Enhancement Shaman -> Slot 1 groupe melee (Windfury)
    local meleeDPS  = {}   -- Warriors, Rogues, Ret Paladin, Feral Druid, Survival Hunter
    local hunters   = {}   -- Hunters ranged -> Groupe 4
    local eleShaman = {}   -- Elemental Shaman -> slot 1 groupe caster
    local moonkin   = {}   -- Balance Druid (Moonkin Aura +5% crit sort) -> groupe caster
    local casterDPS = {}   -- Mages, Warlocks, Shadow Priests, autres casters
    local healers   = {}   -- TOUS les healers -> Groupes 7-8 uniquement

    local function low(s) return string.lower(RT_BTrim(s or "")) end
    local function isSpec(spec, pat)
        return string.find(low(spec), pat, 1, true) ~= nil
    end

    for name, data in pairs(roster) do
        local class = RT_NormalizeClassName(data.class or "")
        local spec  = low(data.spec or "")
        local role  = RT_NormalizeRole(data.role)

        if role == "Tank" then
            table.insert(tanks, name)

        elseif role == "Heal" then
            -- TOUS les healers → groupes 7-8 sans exception
            table.insert(healers, name)

        elseif class == "Shaman" and (isSpec(spec, "enh") or isSpec(spec, "enhancement")) then
            -- Enhancement Shaman -> Windfury Totem (AP + attaques supplementaires pour melee du groupe)
            table.insert(enhShaman, name)

        elseif class == "Shaman" and (isSpec(spec, "elem") or isSpec(spec, "elemental")) then
            -- Elemental Shaman -> Wrath of Air / Flametongue / Mana Spring pour casters
            table.insert(eleShaman, name)

        elseif class == "Druid" and (isSpec(spec, "balance") or isSpec(spec, "boom") or isSpec(spec, "moonkin") or isSpec(spec, "boomkin")) then
            -- Moonkin/Balance Druid -> Moonkin Aura +5% crit sort pour le groupe
            table.insert(moonkin, name)

        elseif class == "Hunter" and (isSpec(spec, "surv") or isSpec(spec, "survival")) then
            -- Survival Hunter qui joue au corps a corps -> groupe melee
            table.insert(meleeDPS, name)

        elseif class == "Hunter" then
            table.insert(hunters, name)

        elseif class == "Priest" and (isSpec(spec, "shadow") or isSpec(spec, "ombre")) then
            -- Shadow Priest -> Vampiric Embrace (soigne groupe par degats shadow) + Misery (hit sorts)
            table.insert(casterDPS, name)

        elseif RT_GroupIsMelee(data) then
            table.insert(meleeDPS, name)

        else
            -- Mages, Warlocks, et autres casters
            table.insert(casterDPS, name)
        end
    end

    table.sort(tanks)
    table.sort(enhShaman)
    table.sort(meleeDPS)
    table.sort(hunters)
    table.sort(eleShaman)
    table.sort(moonkin)
    table.sort(casterDPS)
    table.sort(healers)

    local groups = {}
    for g = 1, 8 do
        groups[g] = {"", "", "", "", ""}
    end

    -- Ajoute name dans le premier slot libre du groupe g
    local function addToGroup(g, name)
        if g < 1 or g > 8 then return false end
        if not name or name == "" then return false end
        for s = 1, 5 do
            if groups[g][s] == "" then
                groups[g][s] = name
                return true
            end
        end
        return false
    end

    -- Remplit les groupes [gStart..gEnd] en remplissant le premier avant de passer au suivant
    local function addPacked(list, gStart, gEnd)
        local g = gStart
        for i = 1, table.getn(list) do
            local name = list[i]
            local placed = false
            local tries = 0
            while tries <= (gEnd - gStart) do
                if addToGroup(g, name) then placed = true break end
                g = g + 1
                if g > gEnd then g = gStart end
                tries = tries + 1
            end
            if not placed then
                -- Debordement : essayer dans tous les groupes
                for gg = 1, 8 do
                    if addToGroup(gg, name) then break end
                end
            end
        end
    end

    -- === Repartition TurtleWoW — groupes purs par synergie ===
    -- Groupe 1 : Tanks uniquement
    addPacked(tanks, 1, 1)

    -- Groupe 2 : Enh Shaman (slot 1 = Windfury pour tout le groupe) + melee DPS
    addPacked(enhShaman, 2, 2)
    addPacked(meleeDPS,  2, 3)

    -- Groupe 4 : Hunters ranged
    addPacked(hunters, 4, 4)

    -- Groupe 5 : Ele Shaman slot 1 + Moonkin slot 2 + Casters (Shadow Priest en priorite)
    addPacked(eleShaman, 5, 5)
    addPacked(moonkin,   5, 5)
    addPacked(casterDPS, 5, 6)

    -- Groupes 7-8 : TOUS les healers (aucun healer ailleurs)
    addPacked(healers, 7, 8)

    -- Debordements (raid > 30 ou groupes deja pleins)
    local function fillOverflow(list, gStart, gEnd)
        for i = 1, table.getn(list) do
            local name = list[i]
            local placed = false
            for g = 1, 8 do
                if placed then break end
                for s = 1, 5 do
                    if groups[g][s] == name then placed = true break end
                end
            end
            if not placed then
                addPacked({name}, gStart, gEnd)
            end
        end
    end
    fillOverflow(meleeDPS,  3, 4)
    fillOverflow(hunters,   3, 6)
    fillOverflow(casterDPS, 5, 6)
    fillOverflow(healers,   6, 8)

    RT_DB.groupPlanner.plan = {
        generatedAt = date("%d/%m %H:%M"),
        groups = groups,
    }
    RT_GroupDisplay()
    -- Actualiser les Buffs si l'onglet Buffs est visible
    if RT_CURRENT_TAB == "Buffs" and RT_BuffDisplay then RT_BuffDisplay() end
    local totalPlanned = 0
    local plannedGroups = RT_DB.groupPlanner.plan.groups or {}
    for g = 1, 8 do
        local arr = plannedGroups[g] or {}
        for s = 1, 5 do
            if arr[s] and arr[s] ~= "" then totalPlanned = totalPlanned + 1 end
        end
    end
    local status = getglobal("RT_GroupsStatus")
    local msg = RT_Text("plan_generated") .. " |cff888888(" .. totalPlanned .. " joueurs répartis)|r"
    if status then status:SetText(RT_ColorOK(msg)) end
    DEFAULT_CHAT_FRAME:AddMessage("|cff88FF88[RT]|r " .. RT_Text("plan_generated") .. " — " .. totalPlanned .. " joueurs")
    -- Pas d'auto-announce groupes (manuel seulement)
end

function RT_GroupInvitePlan()
    RT_GroupInvitePlanned(nil, false)
end

function RT_GroupApplyNow(silent)
    RT_GroupEnsureDB()
    local planMap = RT_GroupPlanAsMap()
    local hasPlan = false
    for _ in pairs(planMap) do hasPlan = true break end
    if not hasPlan then
        if not silent then
            local status = getglobal("RT_GroupsStatus")
            if status then status:SetText(RT_ColorErr(RT_Text("no_plan"))) end
        end
        return
    end

    if not RT_GroupCanManageRaid() then
        if not silent then
            local status = getglobal("RT_GroupsStatus")
            if status then status:SetText(RT_ColorErr(RT_Text("need_rl"))) end
        end
        return
    end

    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    if n == 0 then
        if not silent then
            local status = getglobal("RT_GroupsStatus")
            if status then status:SetText(RT_ColorErr(RT_Text("no_raid"))) end
        end
        return
    end

    local moved = 0
    local alreadyOk = 0
    local invalid = 0
    local seen = {}
    for i = 1, n do
        local name, rank, subgroup = GetRaidRosterInfo(i)
        if name and subgroup then
            seen[RT_GroupLowerName(name)] = true
            local target = planMap[RT_GroupLowerName(name)]
            local cur = tonumber(subgroup) or subgroup
            local targetNum = tonumber(target)
            if targetNum then
                if targetNum < 1 or targetNum > 8 then
                    invalid = invalid + 1
                elseif targetNum ~= cur then
                    SetRaidSubgroup(i, targetNum)
                    moved = moved + 1
                else
                    alreadyOk = alreadyOk + 1
                end
            end
        end
    end

    local missing = 0
    for lowName, target in pairs(planMap) do
        local targetNum = tonumber(target)
        if not targetNum or targetNum < 1 or targetNum > 8 then
            invalid = invalid + 1
        elseif not seen[lowName] then
            missing = missing + 1
        end
    end

    if not silent then
        local status = getglobal("RT_GroupsStatus")
        if status then
            local msg
            if invalid > 0 then
                msg = RT_Text("groups_moved_inv", {moved=moved, ok=alreadyOk, missing=missing, invalid=invalid})
            else
                msg = RT_Text("groups_moved", {moved=moved, ok=alreadyOk, missing=missing})
            end
            status:SetText(RT_ColorOK(msg))
        end
    end
end

function RT_GroupToggleAutoApply()
    RT_GroupEnsureDB()
    RT_DB.groupPlanner.autoApply = not RT_DB.groupPlanner.autoApply
    local b = getglobal("RT_GroupsAutoBtn")
    if b then
        if RT_DB.groupPlanner.autoApply then
            b:SetText("Auto: ON")
        else
            b:SetText("Auto: OFF")
        end
    end
end

function RT_GroupToggleAutoInvite()
    RT_GroupEnsureDB()
    RT_DB.groupPlanner.autoInvite = not RT_DB.groupPlanner.autoInvite
    if RT_DB.groupPlanner.autoInvite then
        RT_GROUP_INVITE_TIMER = 0
        RT_GROUP_INVITE_ATTEMPTED = {}
        RT_GroupInvitePlanned(RT_GROUP_INVITE_BURST or 5, true)
    end
    RT_GroupUpdateInviteTickLabel()
    local status = getglobal("RT_GroupsStatus")
    if status then
        if RT_DB.groupPlanner.autoInvite then
        status:SetText(RT_ColorOK(RT_Text("inv_auto_on")))
    else
        status:SetText(RT_ColorErr(RT_Text("inv_auto_off")))
    end
    end
end

-- Deplace ou echange un joueur entre deux slots de groupes
function RT_GroupMoveSlot(fromG, fromS, toG, toS)
    RT_GroupEnsureDB()
    local groups = RT_DB.groupPlanner.plan.groups
    if not groups then return end
    groups[fromG] = groups[fromG] or {"","","","",""}
    groups[toG]   = groups[toG]   or {"","","","",""}
    local fromName = groups[fromG][fromS] or ""
    local toName   = groups[toG][toS]     or ""
    groups[fromG][fromS] = toName
    groups[toG][toS]     = fromName
    RT_GROUP_DRAG_SOURCE = nil
    RT_GroupDisplay()
end

-- Annule la selection de drag en cours
function RT_GroupCancelDrag()
    RT_GROUP_DRAG_SOURCE = nil
    RT_GroupDisplay()
end

function RT_GroupDisplay()
    RT_GroupEnsurePlanLayout()

    local autoBtn = getglobal("RT_GroupsAutoBtn")
    if autoBtn then
        if RT_DB.groupPlanner.autoApply then
            autoBtn:SetText("Auto: ON")
        else
            autoBtn:SetText("Auto: OFF")
        end
    end

    RT_GroupUpdateInviteTickLabel()

    local groups = RT_DB.groupPlanner.plan.groups or {}
    local roster = RT_DB.roster or {}
    local assigned = 0

    -- Etiquettes de rôle par groupe
    local roleTagColors = {
        Tank   = {1.0, 0.4, 0.4},
        Heal   = {0.4, 1.0, 0.6},
        DPS    = {1.0, 0.9, 0.3},
        Mixte  = {0.7, 0.7, 1.0},
        Vide   = {0.4, 0.4, 0.4},
    }
    for g = 1, 8 do
        local arr = groups[g] or {}
        local nTank, nHeal, nDPS = 0, 0, 0
        for s = 1, 5 do
            local name = arr[s] or ""
            if name ~= "" then
                local p = roster[name]
                local role = p and RT_NormalizeRole(p.role) or "DPS"
                if role == "Tank" then nTank = nTank + 1
                elseif role == "Heal" then nHeal = nHeal + 1
                else nDPS = nDPS + 1 end
            end
        end
        local lbl = getglobal("RT_GroupRoleTag" .. g)
        if lbl then
            local roleKey, labelTxt
            if nTank + nHeal + nDPS == 0 then
                roleKey = "Vide"; labelTxt = ""
            elseif nHeal > 0 and nTank == 0 and nDPS == 0 then
                roleKey = "Heal"; labelTxt = "|cff55FF88[Heals]|r"
            elseif nTank > 0 and nHeal == 0 then
                roleKey = "Tank"; labelTxt = "|cffFF6666[Tanks]|r"
            elseif nDPS > 0 and nHeal == 0 and nTank == 0 then
                roleKey = "DPS"; labelTxt = "|cffFFDD44[DPS]|r"
            else
                roleKey = "Mixte"; labelTxt = "|cffAAAAAA[Mixte]|r"
            end
            lbl:SetText(labelTxt)
        end
    end

    local dragSrc = RT_GROUP_DRAG_SOURCE
    for g = 1, 8 do
        local arr = groups[g] or {}
        for s = 1, 5 do
            local key = g .. "_" .. s
            local btn = RT_GROUP_SLOT_BTNS[key]
            if btn then
                local name = arr[s] or ""
                local tex  = btn:GetNormalTexture()
                -- Highlight du slot selectionne (drag source)
                local isDragSrc = dragSrc and dragSrc.g == g and dragSrc.s == s
                if name ~= "" then
                    assigned = assigned + 1
                    local p = roster[name]
                    if p and p.class then
                        btn:SetText(RT_ColorClass(name, p.class))
                    else
                        btn:SetText("|cffBBBBBB" .. name .. "|r")
                    end
                    if tex then
                        if isDragSrc then
                            tex:SetVertexColor(1.0, 0.85, 0.0)   -- or selectionne
                        else
                            tex:SetVertexColor(1, 1, 1)
                        end
                    end
                else
                    -- Slot vide : cible potentielle si drag en cours
                    if dragSrc then
                        btn:SetText("|cff44FF44[ deposer ici ]|r")
                        if tex then tex:SetVertexColor(0.3, 0.8, 0.3) end
                    else
                        btn:SetText("|cff666666Empty|r")
                        if tex then tex:SetVertexColor(1, 1, 1) end
                    end
                end
            end
        end
    end

    local count = getglobal("RT_GroupsCount")
    if count then
        count:SetText("Slots: " .. assigned .. "/40")
    end

    -- Hint de deplacement actif
    local status = getglobal("RT_GroupsStatus")
    if status and RT_GROUP_DRAG_SOURCE then
        status:SetText("|cffFFD700Deplacement: |r|cffFFFFFF"
            .. (RT_GROUP_DRAG_SOURCE.name or "?")
            .. "|r  |cff888888→ clique un slot  |  reclic = annuler|r")
    end
end

function RT_GroupOnUpdate(elapsed)
    if not RT_DB or not RT_DB.groupPlanner then return end
    RT_GROUP_INVITE_CLOCK = (RT_GROUP_INVITE_CLOCK or 0) + (elapsed or 0)
    if not RT_DB.groupPlanner.autoInvite then
        RT_GroupUpdateInviteTickLabel()
        return
    end
    RT_GROUP_INVITE_TIMER = (RT_GROUP_INVITE_TIMER or 0) + (elapsed or 0)
    RT_GroupUpdateInviteTickLabel()
    if RT_GROUP_INVITE_TIMER < (RT_GROUP_INVITE_INTERVAL or 8) then return end
    RT_GROUP_INVITE_TIMER = 0
    RT_GroupInvitePlanned(RT_GROUP_INVITE_BURST or 5, true)
    RT_GroupUpdateInviteTickLabel()
end

function RT_GroupOnRaidRosterUpdate()
    RT_GroupEnsureDB()
    if RT_DB.groupPlanner.autoApply then
        RT_GroupApplyNow(true)
    end
end

-- ============================================================
-- Panel Loot — affichage
-- ============================================================

function RT_LootDisplay(filter)
    local frame = getglobal("RT_LootLog")
    if not frame then return end
    frame:Clear()

    local loot   = RT_DB.loot   or {}
    local roster = RT_DB.roster or {}
    local search = ""
    local searchEdit = getglobal("RT_LootSearchEdit")
    if searchEdit then
        search = RT_BTrim(searchEdit:GetText() or "")
        if search == RT_Text("loot_search_ph") then search = "" end
        search = string.lower(search)
    end

    -- Compter les joueurs avec loot
    local count = 0
    for _ in pairs(loot) do count = count + 1 end

    if count == 0 then
        frame:AddMessage(RT_ColorTitle("Historique vide")
            .. " — utilise l'onglet |cffFFFFFFImport CSV|r.")
        return
    end

    -- Construire une liste triée
    local players = {}
    for name, items in pairs(loot) do
        local class = RT_NormalizeClassName((roster[name] and roster[name].class) or "")
        local classLow = string.lower(class or "")
        local nameLow = string.lower(name or "")
        local matchedItems = {}

        if search == "" or string.find(nameLow, search, 1, true) or string.find(classLow, search, 1, true) then
            matchedItems = items
        else
            for itemIdx = 1, table.getn(items) do
                local it = items[itemIdx]
                local itName = string.lower(it.itemName or "")
                local boss = string.lower(it.boss or "")
                if string.find(itName, search, 1, true) or string.find(boss, search, 1, true) then
                    table.insert(matchedItems, it)
                end
            end
        end

        if table.getn(matchedItems) > 0 then
            table.insert(players, { name = name, items = matchedItems })
        end
    end

    if table.getn(players) == 0 then
        frame:AddMessage(RT_ColorErr("Aucun résultat."))
        return
    end

    -- Tri selon le filtre
    if filter == "sr" then
        -- Trier par SR+ décroissant
        table.sort(players, function(a, b)
            local sa = (roster[a.name] and roster[a.name].sr) or 0
            local sb = (roster[b.name] and roster[b.name].sr) or 0
            if sa ~= sb then return sa > sb end
            return a.name < b.name
        end)
        frame:AddMessage(RT_ColorTitle("=== Loot by SR+ descending ==="))
    else
        table.sort(players, function(a, b) return a.name < b.name end)
        frame:AddMessage(RT_ColorTitle("=== Historique de Loot ==="))
    end
    frame:AddMessage(" ")

    for pIdx = 1, table.getn(players) do
        local entry = players[pIdx]
        local p     = roster[entry.name]
        local class = p and p.class or "?"
        local sr    = p and p.sr    or 0

        frame:AddMessage(RT_ColorClass(entry.name, class)
            .. "  |cffAAAAAA" .. (p and p.spec or "?") .. "|r"
            .. "  SR+: " .. RT_ColorGold(tostring(sr))
            .. "  |cff888888(" .. table.getn(entry.items) .. " item(s))|r")

        for itemIdx = 1, table.getn(entry.items) do
            local item = entry.items[itemIdx]
            frame:AddMessage("   |cffFFD700" .. (item.itemName or "?") .. "|r"
                .. "  |cff888888← " .. (item.boss or "?")
                .. "  [" .. (item.date or "?") .. "]|r"
                .. "  SR dépensé: |cffFFD700" .. (item.sr or 0) .. "|r")
        end
    end
end

-- ============================================================
-- Panel Buffs — affichage de la rotation
-- ============================================================

function RT_BuffDisplay()
    local frame = getglobal("RT_BuffLog")
    if not frame then return end
    frame:Clear()

    local total = RT_CountPlayers()
    if total == 0 then
        frame:AddMessage(RT_ColorTitle(RT_Text("buff_none_roster")))
        return
    end

    RT_BuffEnsureCurseSettings()

    local curseMode = RT_DB.buffs and RT_DB.buffs.curseAuto
        and "|cff88DD88[Auto]|r" or "|cffFFCC66[Manuel]|r"
    frame:AddMessage(RT_ColorTitle(RT_Text("buff_header", {total=total})) .. "  " .. curseMode)

    local cntP = table.getn(RT_BuffListClassPlayers("Priest"))
    local cntM = table.getn(RT_BuffListClassPlayers("Mage"))
    local cntD = table.getn(RT_BuffListClassPlayers("Druid"))
    local cntW = table.getn(RT_BuffListClassPlayers("Warlock"))
    frame:AddMessage(
        RT_ColorClass("Prêtres", "Priest") .. "=" .. RT_ColorGold(cntP)
        .. "  " .. RT_ColorClass("Mages", "Mage") .. "=" .. RT_ColorGold(cntM)
        .. "  " .. RT_ColorClass("Druides", "Druid") .. "=" .. RT_ColorGold(cntD)
        .. "  " .. RT_ColorClass("Démonistes", "Warlock") .. "=" .. RT_ColorGold(cntW))
    frame:AddMessage("|cff334455──────────────────────────────────────────────|r")

    local CHECK_OK   = "|cff00FF00[OK]|r"
    local CHECK_MISS = "|cffFF3333[NO]|r"
    local CHECK_PART = "|cffFFAA00[~]|r"
    local CHECK_UNK  = "|cff888888[?]|r"

    local classes = {
        { key = "Priest", label = "PRÊTRES" },
        { key = "Mage",   label = "MAGES"   },
        { key = "Druid",  label = "DRUIDES"  },
    }

    for classIdx = 1, table.getn(classes) do
        local ci = classes[classIdx]
        local assignments = RT_BuffBuildGroupAssignments(ci.key)
        if table.getn(assignments) == 0 then
            frame:AddMessage(RT_ColorClass(ci.label, ci.key) .. " |cff666666— aucun joueur|r")
        else
            local buffNames = {}
            for ai = 1, table.getn(assignments) do
                table.insert(buffNames, assignments[ai].name)
            end
            frame:AddMessage(RT_ColorClass(ci.label, ci.key)
                .. " |cff888888(" .. table.concat(buffNames, " / ") .. ")|r")
            for rowIdx = 1, table.getn(assignments) do
                local row = assignments[rowIdx]
                local status = RT_BuffCheckGroupStatus(ci.key, row.groups)
                local icon = CHECK_UNK
                if     status == "ok"      then icon = CHECK_OK
                elseif status == "missing" then icon = CHECK_MISS
                elseif status == "partial" then icon = CHECK_PART end
                frame:AddMessage("  " .. icon .. " " .. RT_PadRight(row.name, 22)
                    .. " |cff888888→|r G" .. RT_BuffFormatGroups(row.groups))
            end
        end
    end

    frame:AddMessage("|cff334455──────────────────────────────────────────────|r")

    local warlocks = RT_BuffBuildWarlockAssignments()
    if table.getn(warlocks) == 0 then
        frame:AddMessage(RT_ColorClass("DÉMONISTES", "Warlock") .. " |cff666666— aucun joueur|r")
    else
        frame:AddMessage(RT_ColorClass("DÉMONISTES", "Warlock")
            .. " |cff888888(Joueur / Spec / Malédiction)|r")
        for rowIdx = 1, table.getn(warlocks) do
            local row = warlocks[rowIdx]
            local wSpec = row.spec ~= "" and row.spec or "?"
            frame:AddMessage("  "
                .. RT_ColorClass(RT_PadRight(row.name, 18), "Warlock")
                .. " |cff888888" .. RT_PadRight(wSpec, 18) .. "|r"
                .. " |cff888888→|r " .. RT_ColorGold(RT_BuffCurseText(row.curse)))
        end
    end

    RT_BuffRefreshWarlockControlUI()
end

-- ============================================================
-- Panel Import — mise à jour des statistiques
-- ============================================================

function RT_UpdateImportStats()
    local stats = getglobal("RT_ImportStats")
    if not stats then return end

    local nbPlayers = RT_CountPlayers()
    local nbLoot    = 0
    for _, items in pairs(RT_DB.loot or {}) do
        nbLoot = nbLoot + table.getn(items)
    end
    local nbRaids = 0
    for _ in pairs(RT_DB.presence or {}) do nbRaids = nbRaids + 1 end

    if nbPlayers == 0 then
        stats:SetText("|cff888888" .. RT_Text("import_db_empty") .. "|r")
    else
        local counts = RT_CountRoles()
        local roleLine = "|cffFF6666T:" .. counts.Tank .. "|r  |cff88FF88H:" .. counts.Heal .. "|r  |cffFFDD44D:" .. counts.DPS .. "|r"
        stats:SetText(RT_Text("import_db_stats", {players=RT_ColorGold(nbPlayers), loots=RT_ColorGold(nbLoot), raids=RT_ColorGold(nbRaids)})
            .. "   " .. roleLine)
    end

    -- Afficher le dernier événement importé
    local eventLbl = getglobal("RT_ImportEventLabel")
    if eventLbl then
        local su = RT_DB.signUps
        if su and (su.title or su.date) then
            local txt = "|cffFFAA00Evénement :|r "
            if su.title and su.title ~= "" then txt = txt .. "|cffFFFFFF" .. su.title .. "|r" end
            if su.date  and su.date  ~= "" then txt = txt .. " |cff888888(" .. su.date .. ")|r" end
            eventLbl:SetText(txt)
        else
            eventLbl:SetText("|cff444444Aucun import effectué.|r")
        end
    end

    if RT_UpdateWhisperUI then RT_UpdateWhisperUI() end
end

-- ============================================================
-- Import CSV SoftRes (modules/LootImport.lua intégré)
-- ============================================================

-- Découpe une ligne CSV en tenant compte des guillemets
local function RT_LI_ParseCSVLine(line)
    local fields   = {}
    local field    = ""
    local inQuotes = false
    local i        = 1
    local len      = string.len(line)
    while i <= len do
        local c = string.sub(line, i, i)
        if c == '"' then
            if inQuotes and string.sub(line, i + 1, i + 1) == '"' then
                field = field .. '"'
                i = i + 2
            else
                inQuotes = not inQuotes
                i = i + 1
            end
        elseif c == "," and not inQuotes then
            table.insert(fields, field)
            field = ""
            i = i + 1
        elseif c == "\r" then
            i = i + 1
        else
            field = field .. c
            i = i + 1
        end
    end
    table.insert(fields, field)
    return fields
end

-- Découpe un texte en lignes (séparateur \n, tolère \r\n)
local function RT_LI_SplitLines(text)
    local lines = {}
    local start = 1
    local len   = string.len(text)
    while start <= len do
        local pos = string.find(text, "\n", start, true)
        if pos then
            local line = string.sub(text, start, pos - 1)
            line = string.gsub(line, "\r", "")
            if string.len(line) > 0 then
                table.insert(lines, line)
            end
            start = pos + 1
        else
            local line = string.sub(text, start)
            line = string.gsub(line, "\r", "")
            if string.len(line) > 0 then
                table.insert(lines, line)
            end
            break
        end
    end
    return lines
end

local function RT_LI_NormalizeHeaderKey(key)
    local k = string.lower(RT_BTrim(key or ""))
    k = string.gsub(k, "[%s_%-%(%)]", "")
    k = string.gsub(k, "%+", "plus")
    return k
end

local function RT_LI_GetField(fields, headerMap, k1, k2, k3, k4)
    local idx = nil
    if k1 and headerMap[k1] then idx = headerMap[k1]
    elseif k2 and headerMap[k2] then idx = headerMap[k2]
    elseif k3 and headerMap[k3] then idx = headerMap[k3]
    elseif k4 and headerMap[k4] then idx = headerMap[k4]
    end
    if idx and fields[idx] then
        return RT_BTrim(fields[idx])
    end
    return ""
end

local function RT_LI_FindRaidIdxByBossName(bossName)
    local key = RT_NameKey and RT_NameKey(bossName) or string.lower(RT_BTrim(bossName or ""))
    if key == "" then return nil end

    for raidIdx = 1, table.getn(RT_VANILLA_RAIDS) do
        local raid = RT_VANILLA_RAIDS[raidIdx]
        local bosses = raid and raid.bosses or {}
        for bIdx = 1, table.getn(bosses) do
            local b = bosses[bIdx]
            if (RT_NameKey and RT_NameKey(b) or string.lower(RT_BTrim(b or ""))) == key then
                return raidIdx, b
            end
        end
    end

    return nil, nil
end

local function RT_LI_FindRaidIdxByRaidName(raidName)
    local key = string.lower(RT_BTrim(raidName or ""))
    if key == "" then return nil end
    for raidIdx = 1, table.getn(RT_VANILLA_RAIDS) do
        local raid = RT_VANILLA_RAIDS[raidIdx]
        local raidKey = string.lower(raid.key or "")
        local raidLabel = string.lower(raid.name or "")
        if key == raidKey or key == raidLabel then
            return raidIdx
        end
        if string.find(raidLabel, key, 1, true) or string.find(key, raidLabel, 1, true) then
            return raidIdx
        end
    end
    return nil
end

local function RT_LI_FindExistingBossName(raid, bossName)
    local bosses = raid and raid.bosses or {}
    local key = RT_NameKey and RT_NameKey(bossName) or string.lower(RT_BTrim(bossName or ""))
    if key == "" then return nil end
    for bIdx = 1, table.getn(bosses) do
        local b = bosses[bIdx]
        local bKey = RT_NameKey and RT_NameKey(b) or string.lower(RT_BTrim(b or ""))
        if bKey == key then
            return b
        end
    end
    return nil
end

local function RT_LI_EnsureBossSheet(raidKey, bossName)
    RT_DB.bosses = RT_DB.bosses or {}
    RT_DB.bosses[raidKey] = RT_DB.bosses[raidKey] or {}
    if RT_DB.bosses[raidKey][bossName] then return end
    RT_DB.bosses[raidKey][bossName] = {
        tanks = {"", "", "", ""},
        tank_marks = {"", "", "", ""},
        tank_count = 3,
        h_tank1 = {"", ""},
        h_tank2 = {"", ""},
        h_tank3 = {"", ""},
        h_tank4 = {"", ""},
        h_raid = {"", "", ""},
        h_melee = {""},
        h_caster = {""},
        h_counts = { h_tank1 = 2, h_tank2 = 2, h_tank3 = 2, h_tank4 = 2, h_raid = 3, h_melee = 1, h_caster = 1 },
        note = "",
    }
end

local function RT_LI_ResolveRosterNameInsensitive(name)
    local n = RT_BTrim(name or "")
    if n == "" then return "" end
    local low = string.lower(n)
    for rn, _ in pairs(RT_DB.roster or {}) do
        if string.lower(rn) == low then
            return rn
        end
    end
    return n
end

-- Parse le CSV et alimente RT_DB.
-- Formats supportés:
-- 1) SoftRes: ID,Item,Boss,Attendee,Class,Specialization,Comment,Date,Date(GMT),SR+
-- 2) Alt:     Item,ItemId,From,Name,Class,Spec,Note,Plus,Date
function RT_ImportCSV(text)
    if not text or string.len(RT_BTrim(text)) == 0 then
        return false, "La zone de texte est vide."
    end

    local lines = RT_LI_SplitLines(text)
    if table.getn(lines) < 2 then
        return false, "Le CSV doit contenir un header et au moins une ligne de données."
    end

    local headerFields = RT_LI_ParseCSVLine(lines[1])
    local headerMap = {}
    for hIdx = 1, table.getn(headerFields) do
        local hKey = RT_LI_NormalizeHeaderKey(headerFields[hIdx])
        if hKey ~= "" then
            headerMap[hKey] = hIdx
        end
    end

    local isSoftRes = (headerMap.attendee and headerMap.item and (headerMap.id or headerMap.itemid)) and true or false
    local isAlt = (headerMap.name and headerMap.item and headerMap.from and (headerMap.itemid or headerMap.id)) and true or false
    if not isSoftRes and not isAlt then
        return false, "Header non reconnu. Formats supportés: SoftRes (Attendee/ID/SR+) et Alt (Name/ItemId/From/Plus)."
    end

    RT_DB.roster   = RT_DB.roster   or {}
    RT_DB.loot     = RT_DB.loot     or {}
    RT_DB.sr       = RT_DB.sr       or {}
    RT_DB.presence = RT_DB.presence or {}

    local hasGroupColumn = (headerMap.group or headerMap.raidgroup or headerMap.groupe or headerMap.grp) and true or false
    local groupBuckets = {}
    local groupSeen = {}
    local raidCountByIdx = {}
    local topRaidIdx = nil
    local topRaidCount = 0
    for g = 1, 8 do
        groupBuckets[g] = {}
        groupSeen[g] = {}
    end
    local hasImportedGroups = false

    local newPlayers = 0
    local newItems   = 0
    local newDates   = 0

    for i = 2, table.getn(lines) do
        local fields = RT_LI_ParseCSVLine(lines[i])

        if table.getn(fields) >= 4 then
            local itemId   = RT_LI_GetField(fields, headerMap, "id", "itemid")
            local itemName = RT_LI_GetField(fields, headerMap, "item")
            local boss     = RT_LI_GetField(fields, headerMap, "boss", "from", "encounter")
            local player   = RT_LI_GetField(fields, headerMap, "attendee", "name", "player", "roster")
            local class    = RT_NormalizeClassName(RT_LI_GetField(fields, headerMap, "class"))
            local spec     = RT_LI_GetField(fields, headerMap, "specialization", "spec", "talent")
            local groupRaw = RT_LI_GetField(fields, headerMap, "group", "raidgroup", "groupe", "grp")
            local raidRaw  = RT_LI_GetField(fields, headerMap, "raid", "instance", "zone")
            local date     = RT_LI_GetField(fields, headerMap, "datelocal", "date", "dategmt")
            local sr       = tonumber(RT_LI_GetField(fields, headerMap, "srplus", "plus", "sr")) or 0
            local dateKey  = string.sub(date, 1, 10)

            local raidIdxDetected, canonicalBoss = RT_LI_FindRaidIdxByBossName(boss)
            if not raidIdxDetected then
                raidIdxDetected = RT_LI_FindRaidIdxByRaidName(raidRaw)
            end
            if raidIdxDetected and raidIdxDetected >= 1 and raidIdxDetected <= table.getn(RT_VANILLA_RAIDS) then
                local raid = RT_VANILLA_RAIDS[raidIdxDetected]
                if raid then
                    local bossToUse = canonicalBoss or RT_LI_FindExistingBossName(raid, boss) or boss
                    boss = bossToUse
                    if bossToUse and bossToUse ~= "" then
                        if not RT_LI_FindExistingBossName(raid, bossToUse) then
                            table.insert(raid.bosses, bossToUse)
                        end
                        RT_LI_EnsureBossSheet(raid.key, bossToUse)
                    end
                    raidCountByIdx[raidIdxDetected] = (raidCountByIdx[raidIdxDetected] or 0) + 1
                    if raidCountByIdx[raidIdxDetected] > topRaidCount then
                        topRaidCount = raidCountByIdx[raidIdxDetected]
                        topRaidIdx = raidIdxDetected
                    end
                end
            end

            if string.len(player) > 0 then
                player = RT_LI_ResolveRosterNameInsensitive(player)
                -- Roster
                if not RT_DB.roster[player] then
                    RT_DB.roster[player] = {
                        class = class,
                        spec  = spec,
                        role  = RT_GetRole(class, spec),
                        sr    = sr,
                    }
                    newPlayers = newPlayers + 1
                else
                    if sr > (RT_DB.roster[player].sr or 0) then
                        RT_DB.roster[player].sr = sr
                    end
                    if (not RT_DB.roster[player].class or RT_DB.roster[player].class == "") and class ~= "" then
                        RT_DB.roster[player].class = class
                    end
                    if (not RT_DB.roster[player].spec or RT_DB.roster[player].spec == "") and spec ~= "" then
                        RT_DB.roster[player].spec  = spec
                    end
                    if not RT_DB.roster[player].role or RT_DB.roster[player].role == "" then
                        RT_DB.roster[player].role  = RT_GetRole(class, spec)
                    end
                end

                if hasGroupColumn and groupRaw ~= "" then
                    local digits = string.gsub(groupRaw, "[^0-9]", "")
                    local gNum = tonumber(digits)
                    if gNum and gNum >= 1 and gNum <= 8 then
                        local lowName = string.lower(player)
                        if not groupSeen[gNum][lowName] and table.getn(groupBuckets[gNum]) < 5 then
                            table.insert(groupBuckets[gNum], player)
                            groupSeen[gNum][lowName] = true
                            hasImportedGroups = true
                        end
                    end
                end

                -- Présence
                if string.len(dateKey) >= 8 then
                    if not RT_DB.presence[dateKey] then
                        RT_DB.presence[dateKey] = {}
                        newDates = newDates + 1
                    end
                    RT_DB.presence[dateKey][player] = true
                end

                -- Loot
                local id = tonumber(itemId) or 0
                if id > 0 and string.len(itemName) > 0 and string.lower(itemName) ~= "nothing" then
                    if not RT_DB.loot[player] then RT_DB.loot[player] = {} end
                    local isDuplicate = false
                    local existingLoot = RT_DB.loot[player] or {}
                    for lIdx = 1, table.getn(existingLoot) do
                        local existing = existingLoot[lIdx]
                        if existing.itemId == id and existing.boss == boss and existing.date == date then
                            isDuplicate = true
                            break
                        end
                    end
                    if not isDuplicate then
                        table.insert(RT_DB.loot[player], {
                            itemId   = id,
                            itemName = itemName,
                            boss     = boss,
                            date     = date,
                            sr       = sr,
                        })
                        newItems = newItems + 1
                    end
                    -- SR+
                    if not RT_DB.sr[player] then
                        RT_DB.sr[player] = { points = sr, lastUpdated = date }
                    elseif sr > (RT_DB.sr[player].points or 0) then
                        RT_DB.sr[player].points      = sr
                        RT_DB.sr[player].lastUpdated = date
                    end
                end
            end
        end
    end

    if hasImportedGroups then
        RT_GroupEnsureDB()
        local groups = RT_DB.groupPlanner.plan.groups or {}
        for g = 1, 8 do
            groups[g] = {"", "", "", "", ""}
            local src = groupBuckets[g] or {}
            for s = 1, table.getn(src) do
                groups[g][s] = src[s]
            end
        end
        RT_DB.groupPlanner.plan.groups = groups
        RT_DB.groupPlanner.plan.generatedAt = date("%d/%m %H:%M")
    end

    if topRaidIdx then
        RT_BOSS_STATE = RT_BOSS_STATE or {}
        RT_BOSS_STATE.raidIdx = topRaidIdx
    end

    return true, newPlayers, newItems, newDates, hasImportedGroups
end

-- ── Import Roster uniquement (colonne gauche) ─────────────────
-- Formats acceptés :
--   1. CSV SoftRes Attendees  : Attendee,Class,Spec,Role,...
--   2. CSV simple             : Name,Class,Spec,Role
--   3. Liste brute            : Playername (classe déduite si connue)
function RT_ImportRosterOnly(text)
    if not text or RT_BTrim(text) == "" then
        return false, "Zone vide — colle le CSV Attendees ou liste de joueurs."
    end
    RT_DB = RT_DB or {}
    RT_DB.roster = RT_DB.roster or {}
    local lines = RT_LI_SplitLines(text)
    if table.getn(lines) < 1 then
        return false, "Aucune ligne trouvée."
    end
    local newP = 0
    -- Détecte si la première ligne est un header CSV
    local firstLow = string.lower(RT_BTrim(lines[1] or ""))
    local hasHeader = string.find(firstLow, "attendee", 1, true)
                   or string.find(firstLow, "name", 1, true)
                   or string.find(firstLow, "class", 1, true)
                   or string.find(firstLow, "joueur", 1, true)
    local startLine = hasHeader and 2 or 1
    local headerMap = {}
    if hasHeader then
        local hfields = RT_LI_ParseCSVLine(lines[1])
        for hi = 1, table.getn(hfields) do
            local hk = RT_LI_NormalizeHeaderKey(hfields[hi])
            if hk ~= "" then headerMap[hk] = hi end
        end
    end
    for li = startLine, table.getn(lines) do
        local fields = RT_LI_ParseCSVLine(lines[li])
        if table.getn(fields) >= 1 then
            local name, class, spec, role
            if hasHeader and (headerMap.attendee or headerMap.name) then
                name  = RT_LI_GetField(fields, headerMap, "attendee", "name", "player")
                class = RT_NormalizeClassName(RT_LI_GetField(fields, headerMap, "class", "classe") or "")
                spec  = RT_LI_GetField(fields, headerMap, "specialization", "spec", "talent") or ""
                role  = RT_LI_GetField(fields, headerMap, "role") or ""
            else
                name  = RT_BTrim(fields[1] or "")
                class = RT_NormalizeClassName(RT_BTrim(fields[2] or ""))
                spec  = RT_BTrim(fields[3] or "")
                role  = RT_BTrim(fields[4] or "")
            end
            name = RT_BTrim(name or "")
            if name ~= "" and string.len(name) <= 24 then
                local existing = RT_DB.roster[name] or {}
                if class and class ~= "" then existing.class = class end
                if spec  and spec  ~= "" then existing.spec  = spec  end
                if role  and role  ~= "" then
                    local nr = RT_NormalizeRole and RT_NormalizeRole(role) or role
                    if nr ~= "" then existing.role = nr end
                end
                if not existing.role or existing.role == "" then
                    existing.role = RT_GuessRole and RT_GuessRole(existing.class or "", existing.spec or "") or "DPS"
                end
                existing.sr = existing.sr or 0
                if not RT_DB.roster[name] then newP = newP + 1 end
                RT_DB.roster[name] = existing
            end
        end
    end
    if RT3_AutofixRoster then RT3_AutofixRoster() end
    if RT_RosterDisplay then RT_RosterDisplay() end
    if RT_RLUpdateRoleSummary then RT_RLUpdateRoleSummary() end
    RT_UpdateImportStats()
    return true, newP
end

-- Bouton Roster (colonne gauche du panel Import)
function RT_ImportRoster_Process()
    local editBox = getglobal("RT_ImportRosterEditBox")
    local status  = getglobal("RT_ImportRosterStatus")
    if not editBox then return end
    local text = editBox:GetText()
    -- Tente JSON d'abord
    if string.sub(RT_BTrim(text), 1, 1) == "{" or string.sub(RT_BTrim(text), 1, 1) == "[" then
        local ok, msg = RT_ImportSoftResJSON(text)
        if status then
            status:SetText(ok and ("|cff44FF88" .. (msg or "OK") .. "|r")
                              or  ("|cffFF4444Erreur JSON: " .. (msg or "?") .. "|r"))
        end
        if ok then editBox:SetText("") end
        return
    end
    -- Sinon CSV roster
    local ok, n = RT_ImportRosterOnly(text)
    if status then
        if ok then
            status:SetText("|cff44FF88" .. n .. " joueur(s) importé(s) dans le Roster.|r")
            editBox:SetText("")
        else
            status:SetText("|cffFF4444" .. (n or "Erreur inconnue") .. "|r")
        end
    end
end

-- Bouton SoftRes (colonne droite du panel Import)
function RT_ImportSoftRes_Process()
    local editBox = getglobal("RT_ImportSREditBox")
    local status  = getglobal("RT_ImportSRStatus")
    if not editBox then return end
    local text = editBox:GetText()
    if not text or text == "" then
        if status then status:SetText("|cffFF4444Zone vide.|r") end
        return
    end
    if status then status:SetText("|cffFFFF00Analyse en cours...|r") end
    local ok, a, b, c = RT_ImportCSV(text)
    if not ok then
        if status then status:SetText("|cffFF4444" .. (a or "Erreur") .. "|r") end
        return
    end
    if status then
        status:SetText("|cff44FF88Import OK — " .. a .. " joueur(s) " .. b .. " item(s) " .. c .. " date(s)|r")
    end
    RT_UpdateImportStats()
    editBox:SetText("")
    if RT_GroupGenerateAutoPlan then RT_GroupGenerateAutoPlan() end
end

-- Appelé par le bouton "Importer" dans l'UI (ancienne méthode, maintenu pour compat)
function RT_LootImport_Process()
    local editBox = getglobal("RT_ImportEditBox")
    local status  = getglobal("RT_ImportStatus")

    if not editBox or not status then return end

    local text = editBox:GetText()
    if not text or string.len(text) == 0 then
        status:SetText(RT_ColorErr(RT_Text("import_err_empty")))
        return
    end

    status:SetText("|cffFFFF00" .. RT_Text("import_analyzing") .. "|r")

    local ok, a, b, c, groupsImported = RT_ImportCSV(text)
    if not ok then
        status:SetText(RT_ColorErr(RT_Text("import_err", {msg=a or "inconnue"})))
        RT_Print(RT_ColorErr(RT_Text("import_err", {msg=a or "inconnue"})))
        return
    end

    local resultMsg = RT_ColorOK("Import OK !")
        .. "  " .. RT_ColorGold(a) .. " nouveau(x) joueur(s)"
        .. "  |  " .. RT_ColorGold(b) .. " item(s) ajouté(s)"
        .. "  |  " .. RT_ColorGold(c) .. " date(s) de raid"
    if groupsImported then
        resultMsg = resultMsg .. "  |  " .. RT_ColorGold(RT_Text("import_ok_groups_csv"))
    end
    status:SetText(resultMsg)

    RT_Print("Import done — "
        .. RT_ColorGold(a) .. " player(s), "
        .. RT_ColorGold(b) .. " item(s), "
        .. RT_ColorGold(c) .. " date(s)."
        .. (groupsImported and " " .. RT_Text("import_ok_groups_csv") .. "." or ""))

    RT_UpdateImportStats()

    -- Auto-générer seulement s'il n'y a pas déjà des groupes importés depuis le CSV.
    if not groupsImported then
        RT_GroupGenerateAutoPlan()
    else
        RT_GroupDisplay()
    end

    -- Compat strict : navigation auto après import réussi
    local compatStrict = RT_DB and RT_DB.settings and RT_DB.settings.compatStrict
    if compatStrict then
        -- Si un boss/raid a été détecté, afficher Boss ; sinon afficher Roster
        local bossDetected = RT_BOSS_STATE and RT_BOSS_STATE.raidIdx and RT_BOSS_STATE.raidIdx > 0
        if bossDetected then
            RT_ShowTab("Boss")
        else
            RT_ShowTab("Roster")
        end
        return
    end

    if RT_CURRENT_TAB == "Roster" then
        RT_RosterDisplay()
    elseif RT_CURRENT_TAB == "Loot" then
        RT_LootDisplay("all")
    elseif RT_CURRENT_TAB == "Buffs" then
        RT_BuffDisplay()
    elseif RT_CURRENT_TAB == "Groups" then
        RT_GroupDisplay()
    end
end

-- Résumé rapide dans le chat
function RT_ImportSummary()
    local counts = RT_CountRoles()
    local total  = RT_CountPlayers()
    RT_Print(RT_ColorTitle("=== Roster summary ==="))
    RT_Print("Total: " .. RT_ColorGold(total) .. " players")
    RT_Print(RT_ColorRole("Tank") .. " : " .. RT_ColorGold(counts.Tank)
        .. "   " .. RT_ColorRole("Heal") .. " : " .. RT_ColorGold(counts.Heal)
        .. "   " .. RT_ColorRole("DPS")  .. " : " .. RT_ColorGold(counts.DPS))
    local classes = {}
    for name, data in pairs(RT_DB.roster or {}) do
        classes[data.class] = (classes[data.class] or 0) + 1
    end
    local classList = {}
    for class, nb in pairs(classes) do
        table.insert(classList, { class = class, nb = nb })
    end
    table.sort(classList, function(a, b) return a.class < b.class end)
    for clIdx = 1, table.getn(classList) do
        local entry = classList[clIdx]
        RT_Print("  " .. RT_ColorClass(entry.class, entry.class)
            .. " : " .. RT_ColorGold(entry.nb))
    end
end

-- ============================================================
-- WhisperBot — réponses automatiques aux MPs
-- ============================================================

local function RT_WhisperEnsureSettings()
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    if RT_DB.settings.whisperBot == nil then RT_DB.settings.whisperBot = true end
    if not RT_DB.settings.whisperKeyword or RT_DB.settings.whisperKeyword == "" then
        RT_DB.settings.whisperKeyword = "attrib"
    end
    if not RT_DB.settings.leaderName or RT_DB.settings.leaderName == "" then
        RT_DB.settings.leaderName = UnitName("player")
    end
    if RT_DB.settings.whisperRaid == nil then RT_DB.settings.whisperRaid = true end
    if not RT_DB.settings.whisperRaidMessage or RT_DB.settings.whisperRaidMessage == "" then
        RT_DB.settings.whisperRaidMessage = "Raid actif. Contact: {leader}. Commandes: {keyword}, sr, {keyword} loot, {keyword} buff, {keyword} raid."
    end
    RT_DB.settings.whisperMessages = RT_DB.settings.whisperMessages or {}
    if not RT_DB.settings.whisperMessages.help or RT_DB.settings.whisperMessages.help == "" then
        RT_DB.settings.whisperMessages.help = "Commandes: {keyword}, {keyword} sr, sr, {keyword} loot, {keyword} buff, {keyword} boss, {keyword} bless, {keyword} raid"
    end
    if not RT_DB.settings.whisperMessages.unknown or RT_DB.settings.whisperMessages.unknown == "" then
        RT_DB.settings.whisperMessages.unknown = "Commande inconnue. Essaie: {keyword}, sr, loot, buff, boss, bless, raid, help"
    end
    if not RT_DB.settings.whisperMessages.noroster or RT_DB.settings.whisperMessages.noroster == "" then
        RT_DB.settings.whisperMessages.noroster = "Tu n'es pas dans le roster importe."
    end
    if not RT_DB.settings.whisperMessages.noloot or RT_DB.settings.whisperMessages.noloot == "" then
        RT_DB.settings.whisperMessages.noloot = "Aucun loot enregistre pour toi."
    end
    if not RT_DB.settings.whisperMessages.nobuff or RT_DB.settings.whisperMessages.nobuff == "" then
        RT_DB.settings.whisperMessages.nobuff = "Tu n'as pas de buff de masse assign."
    end
    if not RT_DB.settings.whisperMessages.attrib or RT_DB.settings.whisperMessages.attrib == "" then
        RT_DB.settings.whisperMessages.attrib = "{player} - Classe: {class}, Role: {role}, Spe: {spec}, SR+: {sr}"
    end
    if not RT_DB.settings.whisperMessages.sr or RT_DB.settings.whisperMessages.sr == "" then
        RT_DB.settings.whisperMessages.sr = "Ton SR+ : {sr}"
    end
    if not RT_DB.settings.whisperMessages.loot or RT_DB.settings.whisperMessages.loot == "" then
        RT_DB.settings.whisperMessages.loot = "Dernier loot: {item} ({boss})"
    end
    if not RT_DB.settings.whisperMessages.buff or RT_DB.settings.whisperMessages.buff == "" then
        RT_DB.settings.whisperMessages.buff = "Tu es buffeur ({class}) — voir l'onglet Buffs."
    end
    if not RT_DB.settings.whisperMessages.boss or RT_DB.settings.whisperMessages.boss == "" then
        RT_DB.settings.whisperMessages.boss = "Boss actuel: {boss}"
    end
    if not RT_DB.settings.whisperMessages.bless or RT_DB.settings.whisperMessages.bless == "" then
        RT_DB.settings.whisperMessages.bless = "{player} ({class}): Bénédiction — {bless} par {pala}"
    end
    RT_DB.settings.whisperCustom = RT_DB.settings.whisperCustom or {}
end

local function RT_WhisperTrim(s)
    local t = string.gsub(s or "", "^%s+", "")
    t = string.gsub(t, "%s+$", "")
    return t
end

local function RT_WhisperLower(s)
    return string.lower(RT_WhisperTrim(s or ""))
end

local function RT_WhisperSenderKey(sender)
    local name = RT_WhisperTrim(sender or "")
    local dash = string.find(name, "%-", 1, true)
    if dash then
        name = string.sub(name, 1, dash - 1)
    end
    return name
end

local function RT_WhisperReply(target, text)
    if not target or target == "" or not text or text == "" then return end
    local safeText = string.gsub(text, "|", "||")
    local lang = GetDefaultLanguage and GetDefaultLanguage("player") or nil
    local ok, err = pcall(SendChatMessage, "[RT] " .. safeText, "WHISPER", lang, target)
    if not ok then
        pcall(SendChatMessage, "[RT] " .. safeText, "WHISPER", nil, target)
    end
end

local RT_WHISPER_LAST_REPLY = {}

local function RT_WhisperShouldReply(target, messageKey)
    local now = GetTime and GetTime() or 0
    local key = (target or "") .. "|" .. (messageKey or "")
    local prev = RT_WHISPER_LAST_REPLY[key] or 0
    if prev > 0 and (now - prev) < 1.5 then
        return false
    end
    RT_WHISPER_LAST_REPLY[key] = now
    return true
end

local function RT_WhisperFormat(text, vars)
    local out = text or ""
    local repl = vars or {}
    out = string.gsub(out, "{([%w_]+)}", function(key)
        local val = repl[key]
        if val == nil then return "{" .. key .. "}" end
        return tostring(val)
    end)
    return out
end

local function RT_WhisperFindPlayerKey(tbl, name)
    if not tbl or not name or name == "" then return nil end
    if tbl[name] then return name end

    local low = RT_WhisperLower(name)
    for k in pairs(tbl) do
        if RT_WhisperLower(k) == low then
            return k
        end
    end
    return nil
end

local RT_WhisperKeyword
local RT_WhisperStatusText

local function RT_WhisperNormalizeMessage(message)
    local msg = RT_WhisperLower(message)
    msg = string.gsub(msg, "^[!%./%?]+", "")
    msg = RT_WhisperTrim(msg)
    if string.sub(msg, 1, 3) == "rt " then
        msg = RT_WhisperTrim(string.sub(msg, 4))
    elseif msg == "rt" then
        msg = "help"
    end
    return msg
end

local function RT_WhisperResolveAtom(word)
    local value = RT_WhisperTrim(word or "")
    if value == "" then return nil end
    if value == "help" or value == "aide" or value == "commandes" or value == "commands" then
        return "help"
    end
    if value == "attrib" or value == "attribution" or value == "infos" or value == "info" then
        return "attrib"
    end
    if value == "sr" or value == "loot" or value == "buff" or value == "raid"
        or value == "boss" or value == "bless" or value == "benediction" then
        return value
    end
    return nil
end

local function RT_WhisperResolveCommand(msg, keyword)
    local raw = RT_WhisperTrim(msg or "")
    if raw == "" then return nil end

    local direct = RT_WhisperResolveAtom(raw)
    if direct then return direct end
    if raw == keyword then return "attrib" end

    local sp = string.find(raw, " ")
    if not sp then return nil end

    local head = RT_WhisperTrim(string.sub(raw, 1, sp - 1))
    local tail = RT_WhisperTrim(string.sub(raw, sp + 1))
    if tail == "" then
        if head == keyword or head == "attrib" or head == "attribution" then
            return "attrib"
        end
        return nil
    end

    if head ~= keyword and head ~= "attrib" and head ~= "attribution" then
        return nil
    end

    local sub = RT_WhisperResolveAtom(tail)
    if not sub then return "unknown-keyword" end
    if sub == "sr" or sub == "attrib" then return "attrib" end
    return sub
end

local function RT_WhisperIsExplicitTarget(msg, keyword)
    local raw = RT_WhisperTrim(msg or "")
    if raw == "" then return false end
    if raw == "rt" or string.sub(raw, 1, 3) == "rt " then return true end
    if RT_WhisperResolveCommand(raw, keyword) then return true end
    if string.sub(raw, 1, string.len(keyword) + 1) == (keyword .. " ") then return true end
    if string.sub(raw, 1, 7) == "attrib " then return true end
    return false
end

local function RT_WhisperResolveCustom(raw, keyword)
    RT_WhisperEnsureSettings()
    local custom = RT_DB.settings.whisperCustom or {}
    local keysToTry = {}
    local function addKey(k)
        k = RT_WhisperLower(k)
        if k ~= "" then table.insert(keysToTry, k) end
    end

    addKey(raw)

    local prefix = keyword .. " "
    if string.sub(raw, 1, string.len(prefix)) == prefix then
        addKey(string.sub(raw, string.len(prefix) + 1))
    end

    if string.sub(raw, 1, 7) == "attrib " then
        addKey(string.sub(raw, 8))
    end

    for keyIdx = 1, table.getn(keysToTry) do
        local key = keysToTry[keyIdx]
        if custom[key] and custom[key] ~= "" then
            return key, custom[key]
        end
    end
    return nil, nil
end

local function RT_WhisperBuildVars(senderName, rosterKey, lootKey)
    RT_WhisperEnsureSettings()
    local p = rosterKey and RT_DB.roster[rosterKey] or nil
    local srKey = RT_WhisperFindPlayerKey(RT_DB.sr, senderName)
    if not srKey and rosterKey then srKey = RT_WhisperFindPlayerKey(RT_DB.sr, rosterKey) end
    local srData = srKey and RT_DB.sr[srKey] or nil
    local items = lootKey and RT_DB.loot[lootKey] or nil
    local last = nil
    if items and table.getn(items) > 0 then
        last = items[table.getn(items)]
    end
    local srValue = 0
    if p and p.sr then srValue = p.sr end
    if srData and (srData.points or 0) > srValue then srValue = srData.points or 0 end
    return {
        player = rosterKey or senderName or "?",
        sender = senderName or "?",
        keyword = RT_WhisperKeyword(),
        leader = RT_DB.settings.leaderName or UnitName("player") or "?",
        class = p and (p.class or "?") or "?",
        role = p and (p.role or "?") or "?",
        spec = p and (p.spec or "?") or "?",
        sr = srValue,
        item = last and (last.itemName or "?") or "?",
        boss = last and (last.boss or "?") or "?",
    }, p, last
end

local function RT_WhisperMessage(key)
    RT_WhisperEnsureSettings()
    return RT_DB.settings.whisperMessages and RT_DB.settings.whisperMessages[key] or ""
end

local function RT_WhisperSetMessage(key, text)
    RT_WhisperEnsureSettings()
    RT_DB.settings.whisperMessages[key] = text
end

local function RT_WhisperCustomCount()
    RT_WhisperEnsureSettings()
    local n = 0
    for _ in pairs(RT_DB.settings.whisperCustom or {}) do n = n + 1 end
    return n
end

local function RT_WhisperPrintCustomList()
    RT_WhisperEnsureSettings()
    local custom = RT_DB.settings.whisperCustom or {}
    local names = {}
    for k in pairs(custom) do table.insert(names, k) end
    table.sort(names)
    if table.getn(names) == 0 then
        RT_Print(RT_Text("whisper_no_custom"))
        return
    end
    RT_Print(RT_Text("whisper_custom_list_msg", {list=table.concat(names, ", ")}))
end

RT_WhisperKeyword = function()
    RT_WhisperEnsureSettings()
    local settings = RT_DB and RT_DB.settings or nil
    local keyword = settings and settings.whisperKeyword or "attrib"
    keyword = string.lower(RT_WhisperTrim(keyword))
    if keyword == "" then keyword = "attrib" end
    return keyword
end

RT_WhisperStatusText = function()
    RT_WhisperEnsureSettings()
    local enabled = RT_DB.settings.whisperBot and "ON" or "OFF"
    return "WhisperBot: " .. enabled .. " | keyword: " .. RT_WhisperKeyword()
end

function RT_UpdateWhisperUI()
    local toggle = getglobal("RT_WhisperToggleBtn")
    if not toggle then return end

    RT_WhisperEnsureSettings()

    if RT_DB.settings.whisperBot then
        toggle:SetText("Whisper: ON")
    else
        toggle:SetText("Whisper: OFF")
    end

    local edit = getglobal("RT_WhisperKeywordEdit")
    if edit then
        local focused = GetCurrentKeyBoardFocus and (GetCurrentKeyBoardFocus() == edit)
        if not focused then
            edit:SetText(RT_WhisperKeyword())
        end
    end

    local status = getglobal("RT_WhisperStatus")
    if status then
        local raidState = RT_DB.settings.whisperRaid and "raid ON" or "raid OFF"
        status:SetText(RT_WhisperStatusText() .. " | " .. raidState .. " | perso: " .. RT_WhisperCustomCount())
    end
end

function RT_WhisperToggleFromUI()
    RT_WhisperEnsureSettings()
    RT_DB.settings.whisperBot = not RT_DB.settings.whisperBot
    RT_UpdateWhisperUI()
    RT_Print(RT_WhisperStatusText())
end

function RT_WhisperApplyKeywordFromUI()
    RT_WhisperEnsureSettings()
    local edit = getglobal("RT_WhisperKeywordEdit")
    if not edit then return end

    local keyword = RT_WhisperTrim(edit:GetText() or "")
    if keyword == "" then
        RT_Print(RT_ColorErr(RT_Text("whisper_kw_empty")))
        edit:SetText(RT_WhisperKeyword())
        return
    end

    RT_DB.settings.whisperKeyword = keyword
    RT_UpdateWhisperUI()
    RT_Print(RT_Text("whisper_kw_set", {kw=RT_ColorGold(string.lower(keyword))}))
end

-- Envoie une réponse whisper seulement si le texte n'est pas vide et que le throttle le permet
local function RT_WhisperSend(target, text, throttleKey)
    if not text or text == "" then
        RT_Print("[WhisperBot] ERREUR: message vide pour cle='" .. tostring(throttleKey) .. "' -> verifie /rt whisper msg " .. tostring(throttleKey))
        return
    end
    if RT_WhisperShouldReply(target, throttleKey) then
        RT_WhisperReply(target, text)
    end
end

local function RT_HandleWhisperInner(message, sender)
    RT_WhisperEnsureSettings()
    if not RT_DB.settings or not RT_DB.settings.whisperBot then return end

    local msg = RT_WhisperNormalizeMessage(message)
    local senderName = RT_WhisperSenderKey(sender)
    local keyword = RT_WhisperKeyword()
    local isExplicit = RT_WhisperIsExplicitTarget(msg, keyword)
    local command = RT_WhisperResolveCommand(msg, keyword)
    local rosterKey = RT_WhisperFindPlayerKey(RT_DB.roster or {}, senderName)
    local lootKey = RT_WhisperFindPlayerKey(RT_DB.loot or {}, senderName)
    local vars, p, last = RT_WhisperBuildVars(senderName, rosterKey, lootKey)
    local customKey, customReply = RT_WhisperResolveCustom(msg, keyword)

    -- Ignorer si pas explicitement adressé au bot et pas de commande perso
    if not isExplicit and not customKey then return end

    -- Notification RL : affiche dans le chat qui a demandé quoi
    RT_Print("|cff88CCFF[WB]|r " .. tostring(senderName) .. " -> " .. tostring(command or msg))

    -- "help" / "aide" / "commandes"
    if command == "help" then
        RT_WhisperSend(senderName, RT_WhisperFormat(RT_WhisperMessage("help"), vars), "help")
        return
    end

    -- "raid" → info raid
    if command == "raid" then
        if RT_DB.settings.whisperRaid then
            local raidMsg = RT_DB.settings.whisperRaidMessage or ""
            RT_WhisperSend(senderName, RT_WhisperFormat(raidMsg, vars), "raid")
        else
            RT_WhisperSend(senderName, RT_Text("whisper_raid_disabled"), "raid-off")
        end
        return
    end

    -- Commandes personnalisées (priorité sur les built-in sauf attrib/sr/loot/buff)
    if customKey and customReply then
        vars.custom = customKey
        RT_WhisperSend(senderName, RT_WhisperFormat(customReply, vars), "custom:" .. customKey)
        return
    end

    -- Mot-clé inconnu après le keyword
    if command == "unknown-keyword" then
        RT_WhisperSend(senderName, RT_WhisperFormat(RT_WhisperMessage("unknown"), vars), "unknown")
        return
    end

    -- "attrib" / "attrib sr" → attribution complète (classe, rôle, spé, SR)
    if command == "attrib" then
        local known = p or (vars.sr and vars.sr > 0)
        if known then
            local reply = RT_WhisperFormat(RT_WhisperMessage("attrib"), vars)
            RT_WhisperSend(senderName, reply, "attrib")
        else
            local noroster = RT_WhisperFormat(RT_WhisperMessage("noroster"), vars)
            RT_WhisperSend(senderName, noroster, "noroster")
            -- Envoie quand même les commandes disponibles
            RT_WhisperSend(senderName, RT_WhisperFormat(RT_WhisperMessage("help"), vars), "noroster-help")
        end
        return
    end

    -- "sr" → score SR uniquement
    if command == "sr" then
        local known = p or (vars.sr and vars.sr > 0)
        if known then
            RT_WhisperSend(senderName, RT_WhisperFormat(RT_WhisperMessage("sr"), vars), "sr")
        else
            RT_WhisperSend(senderName, RT_WhisperFormat(RT_WhisperMessage("noroster"), vars), "noroster")
        end
        return
    end

    -- "attrib loot" / "loot" → dernier item reçu
    if command == "loot" then
        if last then
            RT_WhisperSend(senderName, RT_WhisperFormat(RT_WhisperMessage("loot"), vars), "loot")
        else
            RT_WhisperSend(senderName, RT_WhisperFormat(RT_WhisperMessage("noloot"), vars), "noloot")
        end
        return
    end

    -- "attrib buff" / "buff" → buff de masse
    if command == "buff" then
        if p and RT_BUFFS_LIST and RT_BUFFS_LIST[p.class] then
            RT_WhisperSend(senderName, RT_WhisperFormat(RT_WhisperMessage("buff"), vars), "buff")
        else
            RT_WhisperSend(senderName, RT_WhisperFormat(RT_WhisperMessage("nobuff"), vars), "nobuff")
        end
        return
    end

    -- "boss" → note strat du boss actuel
    if command == "boss" then
        RT_DB = RT_DB or {}
        local bossKey, bossText = RT_FindCurrentBossStratNote and RT_FindCurrentBossStratNote() or nil, nil
        if bossKey then
            local bossVars = {}
            for k, v in pairs(vars) do bossVars[k] = v end
            bossVars.boss = bossKey
            RT_WhisperSend(senderName, RT_WhisperFormat(RT_WhisperMessage("boss"), bossVars), "boss")
            -- Envoyer aussi la note strat ligne par ligne si courte
            local note = RT_DB.stratNotes and RT_DB.stratNotes[bossKey] or ""
            if note ~= "" then
                local lines = RT_SplitLines(note)
                for li = 1, math.min(table.getn(lines), 6) do
                    local l = RT_BTrim(lines[li])
                    if l ~= "" then RT_WhisperReply(senderName, l) end
                end
            end
        else
            RT_WhisperSend(senderName, RT_WhisperFormat(RT_WhisperMessage("boss"), vars), "boss")
        end
        return
    end

    -- "bless" → bénédiction assignée à la classe du joueur
    if command == "bless" or command == "benediction" then
        RT_DB = RT_DB or {}
        RT_DB.blessings = RT_DB.blessings or {}
        RT_DB.blessings.classAssign = RT_DB.blessings.classAssign or {}
        local playerClass = p and RT_NormalizeClassName(p.class or "") or ""
        local blessAssign = RT_DB.blessings.classAssign[playerClass] or {}
        local palaName = blessAssign.pala or "?"
        local blessName = RT_GetBlessingName(blessAssign.blessIdx or 1)
        local blessVars = {}
        for k, v in pairs(vars) do blessVars[k] = v end
        blessVars.bless = blessName
        blessVars.pala  = palaName
        RT_WhisperSend(senderName, RT_WhisperFormat(RT_WhisperMessage("bless"), blessVars), "bless")
        return
    end
end

function RT_HandleWhisper(message, sender)
    local ok, err = pcall(RT_HandleWhisperInner, message, sender)
    if not ok then
        RT_Print(RT_Text("whisper_lua_err", {msg=tostring(err)}))
    end
end

-- ============================================================
-- Événements
-- ============================================================

local RT_CoreFrame = CreateFrame("Frame", "RT_CoreFrame", UIParent)
RT_CoreFrame:RegisterEvent("VARIABLES_LOADED")
RT_CoreFrame:RegisterEvent("RAID_ROSTER_UPDATE")
RT_CoreFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
RT_CoreFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

-- ============================================================
-- WhisperBot listener — compatible WoW 1.12 ET TurtleWoW
-- WoW 1.12  : args en globales (arg1, arg2)
-- TurtleWoW : args en paramètres (a1, a2)
-- On lit les deux pour couvrir les deux cas.
-- ============================================================

local function RT_WBSend(target, text)
    if not target or target == "" or not text or text == "" then return end
    -- Sanitize : échappe les pipes pour éviter "Invalid escape code"
    local safe = string.gsub(tostring(text), "|", "||")
    local lang = GetDefaultLanguage and GetDefaultLanguage("player") or nil
    local ok = pcall(SendChatMessage, "[RT] " .. safe, "WHISPER", lang, target)
    if not ok then pcall(SendChatMessage, "[RT] " .. safe, "WHISPER", nil, target) end
end

local function RT_WBFindRosterKey(name)
    local low = string.lower(name or "")
    -- Retire le suffixe realm (ex: "Joueur-Realm" -> "Joueur")
    local dash = string.find(low, "%-", 1, true)
    if dash then low = string.sub(low, 1, dash - 1) end
    for k in pairs(RT_DB.roster or {}) do
        if string.lower(k) == low then return k end
    end
    return nil
end

local function RT_WBGetBossName()
    if RT_BOSS_STATE and RT_BOSS_STATE.bossName and RT_BOSS_STATE.bossName ~= "" then
        return RT_BOSS_STATE.bossName
    end
    return nil
end

local function RT_WBGetBlessForClass(className)
    if not className or className == "" then return nil, nil end
    RT_DB.blessings = RT_DB.blessings or {}
    RT_DB.blessings.classAssign = RT_DB.blessings.classAssign or {}
    local norm = RT_NormalizeClassName and RT_NormalizeClassName(className) or className
    local assign = RT_DB.blessings.classAssign[norm] or {}
    local pala  = assign.pala or nil
    local bless = RT_GetBlessingName and RT_GetBlessingName(assign.blessIdx or 1) or "Benediction"
    return pala, bless
end

local RT_WhisperListenFrame = CreateFrame("Frame", "RT_WhisperListenFrame", UIParent)
RT_WhisperListenFrame:RegisterEvent("CHAT_MSG_WHISPER")
RT_WhisperListenFrame:SetScript("OnEvent", function(self, evName, a1, a2)
    -- Supporte WoW 1.12 (globales) ET TurtleWoW (paramètres)
    local message = a1 or arg1 or ""
    local sender  = a2 or arg2 or ""

    if not RT_DB or not RT_DB.settings then return end
    if not RT_DB.settings.whisperBot then return end
    if message == "" or sender == "" then return end

    -- Normalise : minuscules + trim
    local msg = string.lower(message)
    msg = string.gsub(msg, "^%s+", "")
    msg = string.gsub(msg, "%s+$", "")

    -- Commandes reconnues : attrib, sr, loot, buff, boss, bless, raid, help
    -- Déclencheur requis : "attrib" seul OU "attrib <cmd>"
    local cmd = nil
    if msg == "attrib" then
        cmd = "attrib"
    elseif msg == "sr" then
        cmd = "sr"
    elseif msg == "loot" then
        cmd = "loot"
    elseif msg == "buff" then
        cmd = "buff"
    elseif msg == "boss" then
        cmd = "boss"
    elseif msg == "bless" or msg == "benediction" or msg == "benee" then
        cmd = "bless"
    elseif msg == "raid" then
        cmd = "raid"
    elseif msg == "help" or msg == "aide" or msg == "?" then
        cmd = "help"
    elseif string.sub(msg, 1, 7) == "attrib " then
        local sub = string.gsub(string.sub(msg, 8), "^%s+", "")
        if sub == "sr"   then cmd = "sr"
        elseif sub == "loot"  then cmd = "loot"
        elseif sub == "buff"  then cmd = "buff"
        elseif sub == "boss"  then cmd = "boss"
        elseif sub == "bless" or sub == "benediction" or sub == "benee" then cmd = "bless"
        elseif sub == "raid"  then cmd = "raid"
        elseif sub == "help"  then cmd = "help"
        else cmd = "attrib" end
    end

    if not cmd then return end

    -- Notification RL
    RT_Print("|cff88CCFF[WB]|r " .. sender .. " -> " .. cmd)

    -- Trouve le joueur dans le roster
    local rkey = RT_WBFindRosterKey(sender)
    local p    = rkey and RT_DB.roster[rkey] or nil

    -- ── HELP ──────────────────────────────────────────────────
    if cmd == "help" then
        RT_WBSend(sender, "Commandes: attrib, sr, loot, buff, boss, bless, raid")
        return
    end

    -- ── RAID ──────────────────────────────────────────────────
    if cmd == "raid" then
        local title = RT_DB.signUps and RT_DB.signUps.title or "Raid"
        local date  = RT_DB.signUps and RT_DB.signUps.date  or ""
        local total = RT_CountPlayers and RT_CountPlayers() or 0
        local info  = title
        if date ~= "" then info = info .. " (" .. date .. ")" end
        if total > 0  then info = info .. " - " .. total .. " joueurs" end
        RT_WBSend(sender, info)
        return
    end

    -- ── ATTRIB ────────────────────────────────────────────────
    if cmd == "attrib" then
        if p then
            local sr = p.sr and tostring(p.sr) or "0"
            RT_WBSend(sender, sender .. " - " .. (p.class or "?") .. " " .. (p.spec or "?") .. " (" .. (p.role or "?") .. ") SR+" .. sr)
        else
            RT_WBSend(sender, "Tu n'es pas dans le roster. Contacte le RL.")
            RT_WBSend(sender, "Commandes disponibles: attrib, sr, loot, buff, boss, bless, raid")
        end
        return
    end

    -- ── SR ────────────────────────────────────────────────────
    if cmd == "sr" then
        if p then
            local sr = p.sr and tostring(p.sr) or "0"
            RT_WBSend(sender, "Ton SR+ : " .. sr)
        else
            RT_WBSend(sender, "Tu n'es pas dans le roster.")
        end
        return
    end

    -- ── LOOT ──────────────────────────────────────────────────
    if cmd == "loot" then
        local lootKey = RT_WBFindRosterKey(sender)
        local items = lootKey and RT_DB.loot and RT_DB.loot[lootKey] or nil
        if items and table.getn(items) > 0 then
            local last = items[table.getn(items)]
            RT_WBSend(sender, "Dernier loot: " .. (last.itemName or "?") .. " (" .. (last.boss or "?") .. ")")
        else
            RT_WBSend(sender, "Aucun loot enregistre pour toi.")
        end
        return
    end

    -- ── BUFF ──────────────────────────────────────────────────
    if cmd == "buff" then
        if p and p.class then
            local buffList = RT_BUFFS_LIST and RT_BUFFS_LIST[p.class] or nil
            if buffList and table.getn(buffList) > 0 then
                RT_WBSend(sender, "Tu es buffeur " .. p.class .. " - " .. table.concat(buffList, ", "))
            else
                RT_WBSend(sender, "Pas de buff de masse assigne pour " .. (p.class or "?") .. ".")
            end
        else
            RT_WBSend(sender, "Tu n'es pas dans le roster.")
        end
        return
    end

    -- ── BOSS ──────────────────────────────────────────────────
    if cmd == "boss" then
        local bossName = RT_WBGetBossName()
        if bossName then
            RT_WBSend(sender, "Boss actuel: " .. bossName)
            -- Envoie les premières lignes de la strat si disponible
            local stratKey = RT_BossGetStratKey and RT_BossGetStratKey() or nil
            local strat = stratKey and RT_DB.stratNotes and RT_DB.stratNotes[stratKey] or nil
            if strat and strat ~= "" then
                -- Envoie ligne par ligne (max 4 lignes)
                local linesSent = 0
                local i = 1
                while i <= string.len(strat) and linesSent < 4 do
                    local nl = string.find(strat, "\n", i, true)
                    local line
                    if nl then
                        line = string.sub(strat, i, nl - 1)
                        i = nl + 1
                    else
                        line = string.sub(strat, i)
                        i = string.len(strat) + 1
                    end
                    line = string.gsub(line, "^%s+", "")
                    line = string.gsub(line, "%s+$", "")
                    if line ~= "" then
                        RT_WBSend(sender, line)
                        linesSent = linesSent + 1
                    end
                end
            end
        else
            RT_WBSend(sender, "Aucun boss selectionne.")
        end
        return
    end

    -- ── BLESS ─────────────────────────────────────────────────
    if cmd == "bless" then
        if p and p.class then
            local pala, bless = RT_WBGetBlessForClass(p.class)
            if pala then
                RT_WBSend(sender, "Ta benee: " .. bless .. " par " .. pala)
            else
                RT_WBSend(sender, "Pas de benediction assignee pour " .. (p.class or "?") .. ".")
            end
        else
            RT_WBSend(sender, "Tu n'es pas dans le roster.")
        end
        return
    end
end)

local function RT_BuildUISafe()
    local ok, err = pcall(RT_BuildUI)
    if not ok then
        RT_Print("UI Error (BuildUI): " .. tostring(err))
        return false
    end
    return true
end

RT_CoreFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4, arg5)
    -- VARIABLES_LOADED : SavedVariables disponibles, on initialise
    if event == "VARIABLES_LOADED" then
        RT_DB = RT_DB or {}
        if not RT_DB.roster   then RT_DB.roster   = {} end
        if not RT_DB.bosses   then RT_DB.bosses   = {} end
        if not RT_DB.loot     then RT_DB.loot     = {} end
        if not RT_DB.sr       then RT_DB.sr       = {} end
        if not RT_DB.presence then RT_DB.presence = {} end
        if not RT_DB.buffs    then RT_DB.buffs    = {} end
        if not RT_DB.debuffs  then RT_DB.debuffs  = {} end
        if not RT_DB.settings then
            RT_DB.settings = {
                whisperBot     = true,
                whisperKeyword = "attrib",
                leaderName     = UnitName("player"),
            }
        end
        if not RT_DB.settings.announceLang or RT_DB.settings.announceLang == "" then
            RT_DB.settings.announceLang = "fr"
        end
        if RT_DB.settings.raidAutoAnnounce == nil then
            RT_DB.settings.raidAutoAnnounce = false
        end
        if RT_DB.settings.compatStrict == nil then
            RT_DB.settings.compatStrict = true
        end
        RT_DB.settings.ui = RT_DB.settings.ui or {}
        if not RT_DB.settings.ui.lastTab or RT_DB.settings.ui.lastTab == "" then
            RT_DB.settings.ui.lastTab = "Import"
        end
        RT_CURRENT_TAB = RT_DB.settings.ui.lastTab
        RT_WhisperEnsureSettings()
        if not RT_DB.sessions then RT_DB.sessions = {} end
        if not RT_DB.groupPlanner then
            RT_DB.groupPlanner = {
                autoApply = true,
                autoInvite = false,
                plan = { groups = {} },
            }
        end
        if RT_DB.groupPlanner.autoApply == nil then RT_DB.groupPlanner.autoApply = true end
        if RT_DB.groupPlanner.autoInvite == nil then RT_DB.groupPlanner.autoInvite = false end
        if not RT_DB.groupPlanner.plan then RT_DB.groupPlanner.plan = { groups = {} } end
        if not RT_DB.groupPlanner.plan.groups then RT_DB.groupPlanner.plan.groups = {} end
        -- Charger les strats par défaut si aucune strat existante
        if not RT_DB.stratNotes or not next(RT_DB.stratNotes) then
            if RT_LoadDefaultStrats then RT_LoadDefaultStrats() end
        end
        if not RT_DB.settings.mode then RT_DB.settings.mode = "guild" end
        if not RT_BuildUISafe() then return end
        RT_UpdateWhisperUI()
        RT_UpdateBossOptionsUI()
        RT_ShowTab(RT_CURRENT_TAB)
        -- Restaurer l'état du panel RL au chargement
        RT_RLQuickEnsureSettings()
        local rlPanel = getglobal("RT_RLQuickPanel")
        if rlPanel then
            if RT_DB.settings.rlEnabled then rlPanel:Show() else rlPanel:Hide() end
        end
        local hdrBtn = getglobal("RT_RLHeaderToggle")
        if hdrBtn then
            if RT_DB.settings.rlEnabled then hdrBtn:SetText("RL: ON") else hdrBtn:SetText("RL: OFF") end
        end
        -- Restaurer le mode de suivi boss (DBM/BigWigs) dans Notes
        RT_DB.settings.notesBossAddon = RT_DB.settings.notesBossAddon or "none"
        RT_NotesAddonSetMode(RT_DB.settings.notesBossAddon)
        -- Créer le HUD Buffs/CDs flottant (positionné via SavedVariables)
        if RT_BuffHUDCreate then RT_BuffHUDCreate() end
        -- Restaurer l'état visuel des boutons de mode
        RT_SetMode(RT_DB.settings.mode or "guild")
        RT_Print(RT_Text("loaded_msg"))

    -- RAID_ROSTER_UPDATE : placement auto selon pré-groupement
    elseif event == "RAID_ROSTER_UPDATE" then
        RT_GroupOnRaidRosterUpdate()

    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Auto-announce désactivé sur changement de cible (manuel seulement via bouton)

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entrée en combat : tenter de détecter le boss actif depuis DBM/BigWigs
        local mode = RT_DB and RT_DB.settings and RT_DB.settings.notesBossAddon or "none"
        if mode ~= "none" then
            RT_NotesDetectCurrentBoss()
        end
    end
end)

RT_BUFF_HUD_LAST_BOSS     = nil
RT_BUFF_HUD_DETECT_TIMER  = 0

local _coreLast = 0
RT_CoreFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    local elapsed = now - _coreLast
    _coreLast = now
    if RT_GroupOnUpdate then
        RT_GroupOnUpdate(elapsed)
    end
    -- Auto-détection boss DBM/BigWigs pour les notes de strat
    RT_BUFF_HUD_DETECT_TIMER = RT_BUFF_HUD_DETECT_TIMER + elapsed
    if RT_BUFF_HUD_DETECT_TIMER >= 8 then
        RT_BUFF_HUD_DETECT_TIMER = 0
        local mode = RT_DB and RT_DB.settings and RT_DB.settings.notesBossAddon or "none"
        if mode ~= "none" and GetNumRaidMembers and GetNumRaidMembers() > 0 then
            local bossName = RT_NotesDetectCurrentBoss and RT_NotesDetectCurrentBoss()
            if bossName and bossName ~= "" and bossName ~= RT_BUFF_HUD_LAST_BOSS then
                RT_BUFF_HUD_LAST_BOSS = bossName
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cff88FF88[RT]|r Note strat chargée : |cffFFD700" .. bossName .. "|r")
            end
        end
    end
end)

-- ============================================================
-- Commandes Slash
-- ============================================================

local function RT_ApplyDemoPreset(clearOnly)
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    RT_DB.roster = RT_DB.roster or {}
    RT_DB.loot = RT_DB.loot or {}
    RT_DB.sr = RT_DB.sr or {}
    RT_DB.stratNotes = RT_DB.stratNotes or {}
    RT_DB.buffs = RT_DB.buffs or {}
    RT_DB.blessings = RT_DB.blessings or {}
    RT_DB.blessings.classAssign = RT_DB.blessings.classAssign or {}

    if clearOnly then
        RT_DB.roster = {}
        RT_DB.loot = {}
        RT_DB.sr = {}
        RT_DB.stratNotes = {}
        RT_DB.blessings.classAssign = {}
        RT_DB.buffs.manualPick = { demo = "", male = "" }
        RT_Print(RT_ColorOK(RT_Text("demo_cleared")))
    else
        RT_DB.roster = {
            ["Aldor"] = { class = "Paladin", spec = "Holy", role = "Heal", sr = 12 },
            ["Morth"] = { class = "Warlock", spec = "Destruction", role = "DPS", sr = 10 },
            ["Vexx"] = { class = "Warlock", spec = "Affliction", role = "DPS", sr = 8 },
            ["Lyrena"] = { class = "Priest", spec = "Holy", role = "Heal", sr = 11 },
            ["Irielle"] = { class = "Druid", spec = "Restoration", role = "Heal", sr = 9 },
            ["Tharos"] = { class = "Warrior", spec = "Protection", role = "Tank", sr = 7 },
            ["Brakka"] = { class = "Warrior", spec = "Protection", role = "Tank", sr = 6 },
            ["Kaelun"] = { class = "Mage", spec = "Arcane", role = "DPS", sr = 13 },
            ["Rivah"] = { class = "Hunter", spec = "Marksmanship", role = "DPS", sr = 5 },
            ["Slynn"] = { class = "Rogue", spec = "Combat", role = "DPS", sr = 4 },
        }

        RT_DB.loot = {
            ["Kaelun"] = {
                { itemName = "Nathrezim Mindblade", boss = "Prince Malchezaar", date = "2026-04-23", sr = 12 },
            },
            ["Aldor"] = {
                { itemName = "Girdle of the Prowler", boss = "Moroes", date = "2026-04-23", sr = 8 },
            },
            ["Morth"] = {
                { itemName = "Malchazeen", boss = "Prince Malchezaar", date = "2026-04-23", sr = 10 },
            },
        }

        RT_DB.stratNotes = RT_DB.stratNotes or {}
        RT_DB.stratNotes["Attumen the Huntsman"] = "Pull propre. Tanks swap sur debuff. Heals assignes Tank1/Tank2."
        RT_DB.stratNotes["Prince Malchezaar"] = "P1/P2 spread. Infernal = move instant. P3 BL + CD def tanks."

        RT_DB.blessings.classAssign = {
            Warrior = { pala = "Aldor", blessIdx = 1 },
            Rogue = { pala = "Aldor", blessIdx = 2 },
            Hunter = { pala = "Aldor", blessIdx = 4 },
            Mage = { pala = "Aldor", blessIdx = 3 },
            Warlock = { pala = "Aldor", blessIdx = 3 },
            Priest = { pala = "Aldor", blessIdx = 3 },
            Druid = { pala = "Aldor", blessIdx = 3 },
            Paladin = { pala = "Aldor", blessIdx = 6 },
        }

        RT_DB.buffs.manualPick = { demo = "Vexx", male = "Morth" }
        RT_Print(RT_ColorOK(RT_Text("demo_loaded")))
    end

    if getglobal("RT_RosterText") then RT_RosterDisplay() end
    if getglobal("RT_BuffLog") then RT_BuffDisplay() end
    if getglobal("RT_LootLog") then RT_LootDisplay("all") end
    if getglobal("RT_BlessStatus") then RT_BlessingsDisplay() end
    if getglobal("RT_ImportStats") then RT_UpdateImportStats() end
end

local function RT_EnsureUIReady()
    if not RT_MainFrame then
        RT_Print("UI Error: RT_MainFrame not found. Check rt.xml then /reload.")
        return false
    end
    return RT_BuildUISafe()
end

SLASH_RT_RAIDTOOL1 = "/rt"
SLASH_RT_RAIDTOOL2 = "/raidtool"
SLASH_RTATTRIB1 = "/attrib"
SLASH_RTATTRIB2 = "/attribution"
SlashCmdList["RTATTRIB"] = function()
    RT_AttribCommand()
end

SlashCmdList["RT_RAIDTOOL"] = function(msg)
    local raw = msg or ""
    local cmd = string.lower(raw)

    if cmd == "" or cmd == "open" or cmd == "v3" or cmd == "menu" then
        -- /rt ouvre le menu v3 par défaut (Raid Command Center)
        if RT and RT.Modules and RT.Modules.Toggle then
            RT.Modules.Toggle()
        else
            RT_Print("|cffFF4444[RT] Menu v3 non chargé.|r")
        end

    elseif cmd == "v2" or cmd == "old" then
        if not RT_EnsureUIReady() then return end
        local wasShown = RT_MainFrame:IsShown()
        if wasShown then
            RT_MainFrame:Hide()
            RT_Print(RT_Text("window_closed"))
        else
            RT_MainFrame:SetParent(UIParent)
            RT_MainFrame:SetFrameStrata("DIALOG")
            RT_MainFrame:SetToplevel(true)
            RT_MainFrame:Show()
            RT_MainFrame:Raise()
            if not RT_MainFrame:IsShown() then
                RT_MainFrame:ClearAllPoints()
                RT_MainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                RT_MainFrame:Show()
            end
            RT_ShowTab(RT_CURRENT_TAB)
            RT_Print(RT_Text("window_opened"))
        end

    elseif cmd == "roster" then
        if not RT_EnsureUIReady() then return end
        RT_MainFrame:Show()
        RT_ShowTab("Roster")

    elseif cmd == "boss" then
        if not RT_EnsureUIReady() then return end
        RT_MainFrame:Show()
        RT_ShowTab("Boss")

    elseif cmd == "buffs" then
        if not RT_EnsureUIReady() then return end
        RT_MainFrame:Show()
        RT_ShowTab("Buffs")

    elseif cmd == "groups" or cmd == "groupes" then
        if not RT_EnsureUIReady() then return end
        RT_MainFrame:Show()
        RT_ShowTab("Groups")

    -- ── v2 commandes ────────────────────────────────────────
    elseif cmd == "overlay" or cmd == "ov" then
        if RT_OverlayToggle then RT_OverlayToggle()
        else RT_Print("|cffFF4444Overlay non chargé.|r") end

    elseif cmd == "pack" or cmd == "pack pug" or cmd == "pug" then
        if RT_AA_PackPUG then RT_AA_PackPUG()
        else RT_Print("|cffFF4444AutoAssign non chargé.|r") end

    elseif cmd == "pack guild" or cmd == "guild" then
        if RT_AA_PackGuild then RT_AA_PackGuild()
        else RT_Print("|cffFF4444AutoAssign non chargé.|r") end

    elseif cmd == "assign" or cmd == "aa" then
        if RT_AA_Run and RT_AA_Apply then
            local out = RT_AA_Run()
            RT_AA_Apply(out)
            RT_Print("|cff88FF88[AA] Attribution calculée. Utilise /rt pack pour annoncer.|r")
        end

    elseif cmd == "whisper" or cmd == "wh" then
        if RT_AA_LAST then RT_AA_WhisperPersonal(RT_AA_LAST)
        else RT_Print("|cffFF8800[AA] Lance d'abord /rt pack ou /rt assign.|r") end

    -- ── Pull Timer ───────────────────────────────────────────
    elseif string.sub(cmd, 1, 5) == "timer" then
        local arg = RT_BTrim(string.sub(raw, 7))
        if RT_PT_SlashCmd then RT_PT_SlashCmd(arg)
        else RT_Print("|cffFF4444PullTimer non chargé.|r") end

    -- ── Cooldowns ────────────────────────────────────────────
    elseif cmd == "cd" or cmd == "cds" or cmd == "cooldowns" then
        if RT_CD and RT_CD.Toggle then RT_CD.Toggle()
        else RT_Print("|cffFF4444CooldownTracker non chargé.|r") end
        if not RT_EnsureUIReady() then return end
        RT_MainFrame:Show()
        RT_ShowTab("Check")

    -- ── Auto-Invite ──────────────────────────────────────────
    elseif string.sub(cmd, 1, 6) == "invite" then
        local arg = RT_BTrim(string.sub(raw, 8))
        if arg == "stop" or arg == "off" then
            if RT_AI then RT_AI.Stop() end
        elseif arg ~= "" then
            if RT_AI then RT_AI.Start(arg) end
        else
            if not RT_EnsureUIReady() then return end
            RT_MainFrame:Show()
            RT_ShowTab("Invite")
        end

    -- ── Tactics ──────────────────────────────────────────────
    elseif string.sub(cmd, 1, 6) == "tactic" or string.sub(cmd, 1, 2) == "tt" then
        local bossArg = RT_BTrim(string.sub(raw, string.sub(cmd,1,2)=="tt" and 4 or 8))
        if bossArg == "" then
            if not RT_EnsureUIReady() then return end
            RT_MainFrame:Show()
            RT_ShowTab("Notes")
        else
            if RT_Tactics then RT_Tactics.Post(bossArg, "RAID") end
        end

    -- ── Attendance ───────────────────────────────────────────
    elseif cmd == "kill" or cmd == "attend" or string.sub(cmd,1,4) == "kill" then
        local bossArg = RT_BTrim(string.sub(raw, 6))
        if bossArg == "" then
            bossArg = RT_BOSS_STATE and RT_BOSS_STATE.bossName or ""
        end
        if bossArg ~= "" and RT_Attend then
            RT_Attend.RecordKill(bossArg)
        else
            if not RT_EnsureUIReady() then return end
            RT_MainFrame:Show()
            RT_ShowTab("Attend")
        end

    -- ── Sync ─────────────────────────────────────────────────
    elseif cmd == "sync" or cmd == "sync roles" then
        if RT_Sync_SendRoles then RT_Sync_SendRoles()
            RT_Print("|cff88CCFF[Sync] Rôles envoyés au raid.|r")
        end

    -- ── RL ───────────────────────────────────────────────────
    elseif cmd == "rl" or cmd == "rl panel" then
        if not RT_EnsureUIReady() then return end
        RT_RLTogglePersist()

    elseif cmd == "rl on" then
        if not RT_EnsureUIReady() then return end
        RT_RLSetPersist(true)
        RT_Print("RL Speedrun: " .. RT_ColorGold("ON"))

    elseif cmd == "rl off" then
        if not RT_EnsureUIReady() then return end
        RT_RLSetPersist(false)
        RT_Print("RL Speedrun: " .. RT_ColorGold("OFF"))

    elseif cmd == "rl reset" then
        if not RT_EnsureUIReady() then return end
        RT_RLResetPanelPosition()
        RT_RLSetPersist(true)
        RT_Print("RL panel reset.")

    elseif cmd == "group apply" then
        RT_GroupApplyNow(false)

    elseif cmd == "raid" then
        RT_RaidAnnounceCommand("all")

    elseif cmd == "raid all" then
        RT_RaidAnnounceCommand("all")

    elseif cmd == "raid auto on" then
        RT_DB = RT_DB or {}
        RT_DB.settings = RT_DB.settings or {}
        RT_DB.settings.raidAutoAnnounce = true
        RT_UpdateBossOptionsUI()
        RT_Print("Annonce boss auto: " .. RT_ColorGold("ON"))

    elseif cmd == "raid auto off" then
        RT_DB = RT_DB or {}
        RT_DB.settings = RT_DB.settings or {}
        RT_DB.settings.raidAutoAnnounce = false
        RT_UpdateBossOptionsUI()
        RT_Print("Annonce boss auto: " .. RT_ColorGold("OFF"))

    elseif cmd == "raid tanks" then
        RT_RaidAnnounceCommand("tanks")

    elseif cmd == "raid tankmarks" then
        RT_RaidAnnounceCommand("tankmarks")

    elseif cmd == "raid heals" then
        RT_RaidAnnounceCommand("heals")

    elseif cmd == "raid buffs" then
        RT_RaidAnnounceCommand("buffs")

    elseif cmd == "raid note" then
        RT_RaidAnnounceCommand("note")

    elseif cmd == "attrib" then
        RT_AttribCommand()

    elseif cmd == "lang fr" or cmd == "lang en" or cmd == "lang both" then
        RT_DB = RT_DB or {}
        RT_DB.settings = RT_DB.settings or {}
        RT_DB.settings.announceLang = string.sub(cmd, 6)
        RT_Print("Langue annonces: " .. RT_ColorGold(RT_DB.settings.announceLang))

    elseif cmd == "compat" or cmd == "compat status" then
        RT_DB = RT_DB or {}
        RT_DB.settings = RT_DB.settings or {}
        local state = (RT_DB.settings.compatStrict ~= false) and "ON" or "OFF"
        RT_Print("Compat stricte Turtle: " .. RT_ColorGold(state))

    elseif cmd == "compat on" then
        RT_DB = RT_DB or {}
        RT_DB.settings = RT_DB.settings or {}
        RT_DB.settings.compatStrict = true
        RT_Print("Compat stricte Turtle: " .. RT_ColorGold("ON"))

    elseif cmd == "compat off" then
        RT_DB = RT_DB or {}
        RT_DB.settings = RT_DB.settings or {}
        RT_DB.settings.compatStrict = false
        RT_Print("Compat stricte Turtle: " .. RT_ColorGold("OFF"))

    elseif cmd == "group gen" then
        RT_GroupGenerateAutoPlan()

    elseif cmd == "group invite" then
        RT_GroupInvitePlan()

    elseif cmd == "group autoinvite on" then
        RT_GroupEnsureDB()
        RT_DB.groupPlanner.autoInvite = true
        RT_GroupDisplay()
        RT_Print(RT_ColorOK("Auto invitations enabled."))

    elseif cmd == "group autoinvite off" then
        RT_GroupEnsureDB()
        RT_DB.groupPlanner.autoInvite = false
        RT_GroupDisplay()
        RT_Print(RT_ColorErr("Auto invitations disabled."))

    elseif string.find(cmd, "^group set ") then
        local args = string.sub(cmd, 11)
        local sp = string.find(args, " ")
        if not sp then
            RT_Print("Usage: /rt group set Player 3")
        else
            local name = RT_GroupTrim(string.sub(args, 1, sp - 1))
            local grp = tonumber(RT_GroupTrim(string.sub(args, sp + 1)))
            local ok, msg = RT_GroupSetPlayerGroup(name, grp)
            if ok then
                RT_Print(RT_ColorOK(msg))
                RT_GroupDisplay()
            else
                RT_Print(RT_ColorErr(msg))
            end
        end

    elseif string.find(cmd, "^group del ") then
        local name = RT_GroupTrim(string.sub(cmd, 11))
        local ok, msg = RT_GroupRemovePlayer(name)
        if ok then
            RT_Print(RT_ColorOK(msg))
            RT_GroupDisplay()
        else
            RT_Print(RT_ColorErr(msg))
        end

    elseif cmd == "loot" then
        if not RT_EnsureUIReady() then return end
        RT_MainFrame:Show()
        RT_ShowTab("Loot")

    elseif cmd == "import" then
        if not RT_EnsureUIReady() then return end
        RT_MainFrame:Show()
        RT_ShowTab("Import")

    elseif cmd == "demo" then
        RT_ApplyDemoPreset(false)
        if RT_EnsureUIReady() then
            RT_MainFrame:Show()
            RT_ShowTab("Import")
        end

    elseif cmd == "demo clear" then
        RT_ApplyDemoPreset(true)
        if RT_EnsureUIReady() then
            RT_MainFrame:Show()
            RT_ShowTab("Import")
        end

    elseif cmd == "ui reset" then
        RT_DB = RT_DB or {}
        RT_DB.settings = RT_DB.settings or {}
        RT_DB.settings.ui = RT_DB.settings.ui or {}
        RT_DB.settings.ui.point = "CENTER"
        RT_DB.settings.ui.relativePoint = "CENTER"
        RT_DB.settings.ui.x = 0
        RT_DB.settings.ui.y = 0
        RT_DB.settings.ui.lastTab = "Import"
        RT_CURRENT_TAB = "Import"
        if RT_EnsureUIReady() then
            RT_MainFrame:ClearAllPoints()
            RT_MainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            RT_MainFrame:Show()
            RT_ShowTab("Import")
            RT_MainFrame:Raise()
        end
        RT_Print("UI RT reset (position + tab).")

    elseif cmd == "reset" then
        RT_ResetDB()

    elseif cmd == "whisper on" then
        RT_WhisperEnsureSettings()
        RT_DB.settings.whisperBot = true
        RT_UpdateWhisperUI()
        RT_Print("WhisperBot " .. RT_ColorOK("enabled") .. ".")

    elseif cmd == "whisper off" then
        RT_WhisperEnsureSettings()
        RT_DB.settings.whisperBot = false
        RT_UpdateWhisperUI()
        RT_Print("WhisperBot " .. RT_ColorErr("disabled") .. ".")

    elseif cmd == "whisper" or cmd == "whisper status" then
        RT_WhisperEnsureSettings()
        RT_Print(RT_WhisperStatusText() .. " | raid: " .. (RT_DB.settings.whisperRaid and "ON" or "OFF")
            .. " | custom commands: " .. RT_WhisperCustomCount())

    elseif cmd == "whisper raid on" then
        RT_WhisperEnsureSettings()
        RT_DB.settings.whisperRaid = true
        RT_UpdateWhisperUI()
        RT_Print("Whisper raid command " .. RT_ColorOK("enabled") .. ".")

    elseif cmd == "whisper raid off" then
        RT_WhisperEnsureSettings()
        RT_DB.settings.whisperRaid = false
        RT_UpdateWhisperUI()
        RT_Print("Whisper raid command " .. RT_ColorErr("disabled") .. ".")

    elseif string.find(cmd, "^whisper raidmsg ") then
        RT_WhisperEnsureSettings()
        local text = RT_WhisperTrim(string.sub(raw, 17))
        if text == "" then
            RT_Print(RT_ColorErr("Usage: /rt whisper raidmsg Ton message"))
        else
            RT_DB.settings.whisperRaidMessage = text
            RT_UpdateWhisperUI()
            RT_Print("Whisper raid message updated.")
        end

    elseif string.find(cmd, "^whisper keyword ") then
        RT_WhisperEnsureSettings()
        local keyword = string.sub(raw, 17)
        keyword = RT_WhisperTrim(keyword)
        if keyword == "" then
            RT_Print(RT_ColorErr("Usage: /rt whisper keyword attrib"))
        else
            RT_DB.settings.whisperKeyword = keyword
            RT_UpdateWhisperUI()
            RT_Print(RT_Text("whisper_kw_set", {kw=RT_ColorGold(string.lower(keyword))}))
        end

    elseif cmd == "whisper custom list" then
        RT_WhisperPrintCustomList()

    elseif string.find(cmd, "^whisper test") then
        -- Simule un whisper entrant depuis le joueur actuel (pour tester sans autre perso)
        local testMsg = RT_WhisperTrim(string.sub(raw, 14))
        if testMsg == "" then testMsg = "attrib" end
        local selfName = UnitName("player") or "TestJoueur"
        RT_Print("Simulation whisper de " .. RT_ColorGold(selfName) .. ": '" .. testMsg .. "'")
        RT_HandleWhisper(testMsg, selfName)

    elseif cmd == "whisper debug" then
        -- Affiche l'etat interne du whisperbot pour diagnostiquer
        RT_WhisperEnsureSettings()
        local s = RT_DB.settings
        RT_Print("=== WhisperBot Debug ===")
        RT_Print("Bot: " .. (s.whisperBot and RT_ColorOK("ON") or RT_ColorErr("OFF"))
            .. " | Keyword: " .. RT_ColorGold(RT_WhisperKeyword())
            .. " | Raid: " .. (s.whisperRaid and RT_ColorOK("ON") or RT_ColorErr("OFF")))
        local rosterCount = 0
        for _ in pairs(RT_DB.roster or {}) do rosterCount = rosterCount + 1 end
        local srCount = 0
        for _ in pairs(RT_DB.sr or {}) do srCount = srCount + 1 end
        RT_Print("Roster: " .. rosterCount .. " players | SR table: " .. srCount .. " entries")
        RT_Print("Messages: attrib='" .. (s.whisperMessages and s.whisperMessages.attrib or "?") .. "'")
        RT_Print("Messages: sr='" .. (s.whisperMessages and s.whisperMessages.sr or "?") .. "'")
        RT_Print("Messages: loot='" .. (s.whisperMessages and s.whisperMessages.loot or "?") .. "'")
        RT_Print("Messages: buff='" .. (s.whisperMessages and s.whisperMessages.buff or "?") .. "'")
        RT_Print("RaidMsg: '" .. (s.whisperRaidMessage or "?") .. "'")
        RT_Print("Custom commands: " .. RT_WhisperCustomCount())

    elseif string.find(cmd, "^whisper custom del ") then
        RT_WhisperEnsureSettings()
        local trigger = RT_WhisperLower(string.sub(raw, 20))
        if trigger == "" then
            RT_Print(RT_ColorErr("Usage: /rt whisper custom del trigger"))
        elseif RT_DB.settings.whisperCustom[trigger] then
            RT_DB.settings.whisperCustom[trigger] = nil
            RT_UpdateWhisperUI()
            RT_Print("Custom whisper command deleted: " .. RT_ColorGold(trigger))
        else
            RT_Print(RT_ColorErr("Custom command not found: " .. trigger))
        end

    elseif string.find(cmd, "^whisper custom add ") then
        RT_WhisperEnsureSettings()
        local payload = RT_WhisperTrim(string.sub(raw, 20))
        local sp = string.find(payload, " ")
        if not sp then
            RT_Print(RT_ColorErr("Usage: /rt whisper custom add trigger Message"))
        else
            local trigger = RT_WhisperLower(string.sub(payload, 1, sp - 1))
            local text = RT_WhisperTrim(string.sub(payload, sp + 1))
            if trigger == "" or text == "" then
                RT_Print(RT_ColorErr("Usage: /rt whisper custom add trigger Message"))
            else
                RT_DB.settings.whisperCustom[trigger] = text
                RT_UpdateWhisperUI()
                RT_Print("Custom whisper command added: " .. RT_ColorGold(trigger))
            end
        end

    elseif string.find(cmd, "^whisper msg ") then
        RT_WhisperEnsureSettings()
        local payload = RT_WhisperTrim(string.sub(raw, 13))
        local sp = string.find(payload, " ")
        if not sp then
            RT_Print(RT_ColorErr("Usage: /rt whisper msg help Ton message"))
        else
            local key = RT_WhisperLower(string.sub(payload, 1, sp - 1))
            local text = RT_WhisperTrim(string.sub(payload, sp + 1))
            local allowed = {
                help = true, unknown = true, noroster = true,
                noloot = true, nobuff = true, attrib = true,
                sr = true, loot = true, buff = true,
            }
            if not allowed[key] then
                RT_Print(RT_ColorErr("Invalid key. Use: help, unknown, noroster, noloot, nobuff, attrib, sr, loot, buff"))
            elseif text == "" then
                RT_Print(RT_ColorErr("Usage: /rt whisper msg " .. key .. " Ton message"))
            else
                RT_WhisperSetMessage(key, text)
                RT_UpdateWhisperUI()
                RT_Print("Whisper message updated: " .. RT_ColorGold(key))
            end
        end

    elseif cmd == "stats" then
        local nb = RT_CountPlayers()
        local counts = RT_CountRoles()
        local nbLoot = 0
        for _, items in pairs(RT_DB.loot or {}) do nbLoot = nbLoot + table.getn(items) end
        RT_Print("Roster : " .. RT_ColorGold(nb) .. " players"
            .. "  (" .. RT_ColorRole("Tank") .. " " .. counts.Tank
            .. "  " .. RT_ColorRole("Heal") .. " " .. counts.Heal
            .. "  " .. RT_ColorRole("DPS")  .. " " .. counts.DPS .. ")"
            .. "  |  Loots : " .. RT_ColorGold(nbLoot))

    elseif cmd == "help" then
        RT_Print("|cffFFD700═══ RT v2 — Raid Tool Ultimate ═══|r")
        RT_Print("|cffFFAA00── Mode PUG (tout automatique) ──|r")
        RT_Print("/rt pack        — |cffFFAA00PUG Pack|r : calcule + annonce TOUT automatiquement")
        RT_Print("/rt pack guild  — |cff44FF88Guild Pack|r : calcule sans annoncer (pour review)")
        RT_Print("/rt assign      — Calcule les attributions (sans annoncer)")
        RT_Print("/rt whisper     — Envoie les attribs perso en MP à chaque joueur")
        RT_Print("/rt overlay     — Affiche/masque la frame 'Mon Attrib'")
        RT_Print("|cff888888── Navigation ──|r")
        RT_Print("/rt             — open / close")
        RT_Print("/attrib         — show your assignment for the current boss")
        RT_Print("/rt lang fr|en  — UI and announcement language")
        RT_Print("/rt compat on|off — enable/disable strict Turtle compat")
        RT_Print("/rt compat      — show compat status")
        RT_Print("/rt roster      — Roster tab")
        RT_Print("/rt boss        — Boss tab")
        RT_Print("/rt buffs       — Buffs tab")
        RT_Print("/rt groups      — Groups tab")
        RT_Print("/rt rl          — toggle RL panel")
        RT_Print("/rt rl on|off   — force RL panel state")
        RT_Print("/rt rl reset    — move RL panel to default position")
        RT_Print("/rt raid        — announce all boss info in raid")
        RT_Print("/rt raid tanks  — announce tanks only")
        RT_Print("/rt raid tankmarks — announce tanks + markers only")
        RT_Print("/rt raid heals  — announce heals only")
        RT_Print("/rt raid buffs  — announce missing buffs only")
        RT_Print("/rt raid note   — announce boss note only")
        RT_Print("/rt raid auto on|off — auto-announce when targeting a known boss")
        RT_Print("/rt loot        — Loot/SR+ tab")
        RT_Print("/rt import      — Import CSV tab")
        RT_Print("/rt demo        — load demo preset data")
        RT_Print("/rt demo clear  — clear demo preset data")
        RT_Print("/rt ui reset    — re-center window and reset tab")
        RT_Print("/rt group gen   — generate auto pre-grouping")
        RT_Print("/rt group invite — invite players from plan")
        RT_Print("/rt group autoinvite on|off — enable/disable auto invite")
        RT_Print("/rt group apply — apply groups in raid")
        RT_Print("/rt group set Player 3 — manually assign a player to a group")
        RT_Print("/rt group del Player — remove a player from the plan")
        RT_Print("/rt stats       — quick summary in chat")
        RT_Print("/rt whisper     — WhisperBot status")
        RT_Print("/rt whisper on  — enable WhisperBot")
        RT_Print("/rt whisper off — disable WhisperBot")
        RT_Print("/rt whisper raid on|off — enable/disable raid command")
        RT_Print("/rt whisper raidmsg MESSAGE — set raid message")
        RT_Print("/rt whisper keyword WORD — change attrib keyword")
        RT_Print("/rt whisper msg KEY MESSAGE — edit a whisper message")
        RT_Print("/rt whisper custom add TRIGGER MESSAGE — add custom command")
        RT_Print("/rt whisper custom del TRIGGER — remove custom command")
        RT_Print("/rt whisper custom list — list custom commands")
        RT_Print("/rt whisper test [command] — simulate a whisper (test)")
        RT_Print("/rt whisper debug — show WhisperBot internal state")
        RT_Print("/rt reset       — clear all data")

    else
        RT_Print("Unknown command. Type |cffFFFFFF/rt help|r.")
    end
end

-- ============================================================
-- Notes de stratégie (Angry Assignments style)
-- ============================================================

function RT_NotesSave()
    local keyEdit  = getglobal("RT_NotesKeyEdit")
    local textEdit = getglobal("RT_NotesTextEdit")
    local status   = getglobal("RT_NotesStatus")
    if not keyEdit or not textEdit then return end

    local key  = RT_BTrim(keyEdit:GetText() or "")
    local text = textEdit:GetText() or ""

    if key == "" then
        if status then status:SetText(RT_ColorErr(RT_Text("notes_no_key"))) end
        return
    end

    RT_DB           = RT_DB or {}
    RT_DB.stratNotes = RT_DB.stratNotes or {}
    RT_DB.stratNotes[key] = text

    -- Sync vers Boss tab si la clé correspond au boss actuellement sélectionné
    local bossStratKey = RT_BossGetStratKey and RT_BossGetStratKey()
    if bossStratKey and bossStratKey == key and RT_BOSS_STATE then
        RT_BOSS_STATE.note = text
        local noteEdit = getglobal("RT_BossNoteEdit2")
        if noteEdit then noteEdit:SetText(text) end
    end
    -- Sync vers RT_DB.bosses si la clé est au format "RAID - Boss"
    -- et que cette fiche est sauvegardée
    local _, _, raidKey, bossName = string.find(key, "^(.-)%s%-%s(.+)$")
    if raidKey and bossName then
        RT_DB.bosses = RT_DB.bosses or {}
        RT_DB.bosses[raidKey] = RT_DB.bosses[raidKey] or {}
        local bossData = RT_DB.bosses[raidKey][bossName]
        if bossData then
            bossData.note = text
        end
    end

    if status then status:SetText(RT_ColorGold(RT_Text("notes_saved", {key=key}))) end
end

function RT_NotesDelete()
    local keyEdit = getglobal("RT_NotesKeyEdit")
    local status  = getglobal("RT_NotesStatus")
    if not keyEdit then return end

    local key = RT_BTrim(keyEdit:GetText() or "")
    if key == "" then
        if status then status:SetText(RT_ColorErr(RT_Text("notes_no_key"))) end
        return
    end

    RT_DB           = RT_DB or {}
    RT_DB.stratNotes = RT_DB.stratNotes or {}

    if RT_DB.stratNotes[key] then
        RT_DB.stratNotes[key] = nil
        local textEdit = getglobal("RT_NotesTextEdit")
        if textEdit then textEdit:SetText("") end
        keyEdit:SetText("")
        if status then status:SetText(RT_ColorErr(RT_Text("notes_deleted", {key=key}))) end
    else
        if status then status:SetText(RT_ColorErr(RT_Text("notes_no_key"))) end
    end
end

function RT_NotesBroadcast()
    local keyEdit  = getglobal("RT_NotesKeyEdit")
    local textEdit = getglobal("RT_NotesTextEdit")
    local status   = getglobal("RT_NotesStatus")
    if not keyEdit or not textEdit then return end

    local text = textEdit:GetText() or ""
    if text == "" then
        if status then status:SetText(RT_ColorErr(RT_Text("notes_broadcast_empty"))) end
        return
    end

    local channel, channelShort = RT_GetBestAnnounceChannel()

    local key = RT_BTrim(keyEdit:GetText() or "")
    if key ~= "" then
        SendChatMessage("[RT] === " .. key .. " ===", channel)
    end

    local lines = RT_SplitLines(text)
    for li = 1, table.getn(lines) do
        local line = RT_BTrim(lines[li])
        if line ~= "" then
            SendChatMessage(line, channel)
        end
    end

    local n = table.getn(lines)
    if status then status:SetText(RT_ColorGold(RT_Text("notes_broadcast_done", {n=n, ch=channelShort}))) end
end

function RT_LoadDefaultStrats()
    RT_DB = RT_DB or {}
    RT_DB.stratNotes = RT_DB.stratNotes or {}
    local s = RT_DB.stratNotes

    -- ===== MOLTEN CORE =====
    s["MC - Lucifron"]    = "2 tanks. Interrompre Maledict sur les healers. Tuer les adds en premier (CC: chaînes). Pala: dépurifier."
    s["MC - Magmadar"]    = "1 tank principal. Fear Ward sur les tanks. Hunter: Tranq Shot pour enlever Frenzy. Rester groupés."
    s["MC - Géhénnas"]    = "3 tanks (1 boss, 2 adds). Tuer d'abord les gardes. Purger Hex des Raiders. Pas de feu sous les pieds."
    s["MC - Garr"]        = "8 adds à gérer (1 tank par add). Warlock Banish 2 adds. Kill les adds puis le boss. Warlock: Curse of Doom."
    s["MC - Baron Geddon"] = "1 tank. Bomb = sortir du groupe IMMÉDIATEMENT. Inferno: rester spread. Pas de sort quand Living Bomb."
    s["MC - Shazzrah"]    = "Tank swap (téléporte aléatoire). Mêlée reste proche. Dispell Arcane Explosion. Spread casters."
    s["MC - Sulfuron"]    = "4 adds healers à focus en prio. CC ou interrupts sur heals. 1 tank boss, 4 tanks adds. Focus adds 1 à 1."
    s["MC - Golemagg"]    = "2 chiens flanquants. DPS boss uniquement. Healers préparés pour dégâts Magma Splash sur le tank."
    s["MC - Majordomo"]   = "8 adds (4 élites + 4 mages). Sheep/CC les mages. Tuer les élites d'abord. Boss ne meurt pas."
    s["MC - Ragnaros"]    = "2 tanks. Wrath of Ragnaros = spread. Adds à 50% et 25%: offtank + kill vite. Sons of Flame: prio stop."

    -- ===== ONYXIA =====
    s["ONY - Onyxia"]     = "P1 (sol): tank dos au raid, DPS côté. P2 (vol): spread raid, pas sous Onyxia, Whelps = AoE. P3: tank fond salle, healers prêts Deep Breath."

    -- ===== BLACKWING LAIR =====
    s["BWL - Razorgore"]   = "Phase protect: Warrior prend l'oeuf, DPS def les adds, tanks gérent les adds. P2: kill boss. Healers focus tanks."
    s["BWL - Vaélastrasz"] = "Tank rotation obligatoire (debuff stack). DPS burst max. Plus de mana = sacrifice. BL dès le début."
    s["BWL - Broodlord"]   = "3 Suppression Rooms à clearer avant. Tank: dos au mur. Blastwave = danger mêlée. Adds: CC/kill priorité."
    s["BWL - Firemaw"]     = "Static Cling = jump pour enlever. Flame Buffet stack = rotation tanks. Wing Buffet = spread."
    s["BWL - Ebonroc"]     = "Tank swap sur Shadow of Ebonroc (debuff). Healers: ne pas être à portée des tanks débuffés."
    s["BWL - Flamegor"]    = "Frenzy = Tranq Shot Hunter impératif. Tank: dos au mur. Conflagration = move."
    s["BWL - Chromaggus"]  = "5 breaths: connaître les 2 de la semaine. Feral Rage = tank swap. Brood Affliction: dispell selon couleur."
    s["BWL - Nefarian"]    = "P1: adds par couleur, 42 total. P2: class calls (Warrior: berserker, Mage: wand, etc.). P3: Corrupted Healers = off-tank."

    -- ===== ZUL'GURUB =====
    s["ZG - High Priest Venoxis"] = "Snake phase: dispell Poison Volley. Human phase: interrupt Shadow Word Pain et Hex. 1 tank suffit."
    s["ZG - High Priestess Jeklik"] = "P1 (chauve-souris): AoE adds. P2 (troll): tanks bombe sonique, spread bomb sur le sol."
    s["ZG - High Priest Thekal"]  = "Tuer les 2 adds EN MÊME TEMPS puis le boss. Si 1 add meurt seul il se rez. Rapide et synchronisé."
    s["ZG - High Priestess Arlokk"] = "Panthers adds = AoE. Boss disparaît. Mark = cibler rapidement. Tank boss dos à la fosse."
    s["ZG - Jin'do le Fléau"]    = "Brisez les chaînes des âmes emprisonnées sur l'autel. Adds fantômes = ignore, cible les âmes."
    s["ZG - Hakkar"]              = "Venin de sang: utiliser les mobs envenimés pour soigner. Chaque prêtre boss doit être tué avant Hakkar."

    -- ===== AQ20 =====
    s["AQ20 - Kurinnaxx"]    = "Sable = sort rapidement de la zone. Tank: contre-rotation. Heal lourd tank. DPS burst."
    s["AQ20 - Général Rajaxx"] = "8 vagues puis boss. Orientalus: protégez-le. Thunderclap = spread mêlée. Tank chaque capitaine."
    s["AQ20 - Moam"]         = "Drain mana = healers en danger. Warlock/Druid: mana shield. 30 sec: stone phase, AoE adds."
    s["AQ20 - Buru l'Écraseur"] = "Courez vers les oeufs pour les exploser sur Buru. Debuff stack = phase finale burst."
    s["AQ20 - Ayamiss l'Incubateur"] = "P1: adds sur joueurs piqués = kill vite. P2 (sol): tank normal, DPS burn."
    s["AQ20 - Ossiriann"]    = "1 min 30 de DPS avant wipe. Heal lourd. Warrior: Berserker Rage pour Break Fear."

    -- ===== AQ40 =====
    s["AQ40 - Skeram"]       = "3 images à tuer simultanément. Tank chaque image. AoE mind control = spread."
    s["AQ40 - Bugs (Sartura)"] = "Trash de bugs: 1 main mob + adds rapides. Sartura: rotation tanks, whirlwind = mêlée recule."
    s["AQ40 - Fankriss"]     = "Ne pas tuer les worms (Spawn of Fankriss). Aléatoire téléport = heal raid. Tank face au mur."
    s["AQ40 - Viscidus"]     = "Froid requis (Frost Bolt, Ice Trap). Shatter à ~5 stacks Cold. Mêlée frappe vite pour shatter."
    s["AQ40 - Princesse Huhuran"] = "Frenzy = Tranq Shot x4 Hunters. Stack nature resist. Wyvern Sting: sleep adds. P2: BL."
    s["AQ40 - Jumeaux Qiraji"] = "2 tanks 1 chacun. Couleurs: attaque opposée (rouge=DPS vert, vert=DPS rouge). Orb = prendre si bonne couleur."
    s["AQ40 - C'thun"]       = "P1: Eyebeam = sortir du faisceau. P2: ventre = tunnel, DPS tentacules d'abord. BL à la fin."

    -- ===== NAXXRAMAS =====
    s["NAXX - Anub'Rekhan"]  = "Locust Swarm = courir à travers Anub. Adds: off-tank les Crypt Guards. Sand rain = move."
    s["NAXX - Grand Widow Faerlina"] = "Worshippers adds = sacrifice pour enlever Rage. Ne pas AoE les adds. Tank swap."
    s["NAXX - Maexxna"]      = "Web Spray = stun 8s, bourrez les heals avant. Cocoon = libérez les joueurs. Frenzy à 30%."
    s["NAXX - Noth le Dépouilleur"] = "Téléport: tanks swap. Adds squelettes à chaque téléport: kill vite. Curse = dispell."
    s["NAXX - Heigan le Dansant"] = "LA DANSE. Phase danse: 4 zones (1=safe, 2-4=mort). Apprenez la danse. Phase DPS: brûlez."
    s["NAXX - Loatheb"]      = "Spores = DPS vite dessus (crit buff). Heals UNIQUEMENT quand window ouverte. Prepot."
    s["NAXX - Razuvious"]    = "Prêtres: MC les Understudies pour tanker. DPS burn understudies entre MC. Raid: heal."
    s["NAXX - Gothik"]       = "2 équipes: vivant et mort. Synchroniser les kills des 2 côtés. BL à la transition."
    s["NAXX - Quatre Cavaliers"] = "Rotation tanks: 2 marks = swap IMMÉDIAT avec autre tank. Healers assignés. BL."
    s["NAXX - Patchwerk"]    = "Haste à maintenir. 3 tanks, heal lourd sur Hasted Tank. DPS race. BL d'entrée."
    s["NAXX - Grobbulus"]    = "Injection: courir déposer le cloud sur les bords, retourner vite. Adds: off-tank."
    s["NAXX - Gluth"]        = "Decimate à 30%: heal raid. Chained Zombie: kite les adds, tank les maintient."
    s["NAXX - Thaddius"]     = "Charge polaire: vert = droite, rouge = gauche. INSTANTANÉ. Erreur = wipe."
    s["NAXX - Sapphiron"]    = "Ice Block: cachons-nous derrière les blocs de glace. Chill: spread. P2: BL."
    s["NAXX - Kel'Thuzad"]   = "P1: adds + boss fantôme. P2: boss vrai, MC random. P3 (Guardians): kill vite. BL P3."

    RT_NotesBrowsePopupRefresh()
end

function RT_NotesBrowse()
    local popup = getglobal("RT_NotesBrowsePopup")
    if not popup then return end
    if popup:IsShown() then
        popup:Hide()
    else
        popup:Show()
    end
end

function RT_NotesBrowsePopupRefresh()
    local content = getglobal("RT_NotesBrowseContent")
    if not content then return end

    -- Supprimer les anciens boutons
    for i = 1, 40 do
        local old = getglobal("RT_NotesBrowseEntry_" .. i)
        if old then old:Hide() else break end
    end

    RT_DB           = RT_DB or {}
    RT_DB.stratNotes = RT_DB.stratNotes or {}

    local keys = {}
    for k in pairs(RT_DB.stratNotes) do
        table.insert(keys, k)
    end
    table.sort(keys)

    if table.getn(keys) == 0 then
        local lbl = getglobal("RT_NotesBrowseEmpty")
        if not lbl then
            lbl = content:CreateFontString("RT_NotesBrowseEmpty", "OVERLAY", "GameFontDisable")
            lbl:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -6)
            lbl:SetWidth(180)
        end
        lbl:SetText(RT_Text("notes_list_empty"))
        lbl:Show()
        return
    end
    local emptyLbl = getglobal("RT_NotesBrowseEmpty")
    if emptyLbl then emptyLbl:Hide() end

    -- Recréer ou réutiliser les boutons
    local totalH = 0
    for ki = 1, table.getn(keys) do
        local key = keys[ki]
        local btnName = "RT_NotesBrowseEntry_" .. ki
        local btn = getglobal(btnName)
        if not btn then
            btn = CreateFrame("Button", btnName, content, "UIPanelButtonTemplate")
            btn:SetWidth(182)
            btn:SetHeight(18)
        end
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4 - (ki-1)*20)
        btn:SetText(key)
        local k2 = key
        btn:SetScript("OnClick", function()
            RT_NotesLoadKey(k2)
            local popup2 = getglobal("RT_NotesBrowsePopup")
            if popup2 then popup2:Hide() end
        end)
        btn:Show()
        totalH = 4 + ki * 20
    end
    content:SetHeight(math.max(totalH + 10, 40))
    local browseScroll = getglobal("RT_NotesBrowseScroll")
    if browseScroll then browseScroll:UpdateScrollChildRect() end
end

-- Tente de lire le boss actuel depuis DBM ou BigWigs selon le mode configuré.
-- Remplit RT_NotesKeyEdit si un boss est détecté.
function RT_NotesDetectCurrentBoss()
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    local mode = RT_DB.settings.notesBossAddon or "none"
    local bossName = nil

    if mode == "dbm" then
        -- DBM BC/vanilla : cherche le module actif en combat
        if DBM and DBM.mods then
            for i = 1, table.getn(DBM.mods) do
                local mod = DBM.mods[i]
                if mod and mod.inCombat then
                    bossName = mod.locName or mod.name
                    break
                end
            end
        end
        if not bossName and DBM then
            bossName = DBM.lastBoss or DBM.currentBoss
        end

    elseif mode == "bigwigs" then
        -- BigWigs BC : cherche le module actif (active=true)
        if BigWigs and BigWigs.modules then
            for _, mod in pairs(BigWigs.modules) do
                if mod and mod.active then
                    bossName = mod.moduleName or mod.name
                    break
                end
            end
        end
        -- Fallback style Ace2 registry
        if not bossName and BigWigsLoader and BigWigsLoader.activeModules then
            for name, _ in pairs(BigWigsLoader.activeModules) do
                bossName = name
                break
            end
        end
    end

    if bossName and bossName ~= "" then
        local ke = getglobal("RT_NotesKeyEdit")
        if ke then ke:SetText(bossName) end
        RT_NotesLoadKey(bossName)
        local st = getglobal("RT_NotesStatus")
        if st then
            local src = (mode == "dbm" and "DBM" or "BigWigs")
            st:SetText(RT_ColorOK(RT_Text("notes_addon_status_detected", {src=src, boss=bossName})))
        end
    else
        local st = getglobal("RT_NotesStatus")
        if st and mode ~= "none" then
            local src = (mode == "dbm" and "DBM" or "BigWigs")
            st:SetText(RT_ColorErr(RT_Text("notes_addon_status_none", {src=src})))
        end
    end
    return bossName
end

function RT_NotesAddonSetMode(mode)
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    RT_DB.settings.notesBossAddon = mode
    -- Mettre à jour l'apparence des boutons
    local btnNone = getglobal("RT_NotesAddonBtnNone")
    local btnDBM  = getglobal("RT_NotesAddonBtnDBM")
    local btnBW   = getglobal("RT_NotesAddonBtnBW")
    local function setActive(btn, active)
        if not btn then return end
        if active then
            btn:SetNormalFontObject(GameFontHighlightSmall)
        else
            btn:SetNormalFontObject(GameFontDisableSmall)
        end
    end
    setActive(btnNone, mode == "none")
    setActive(btnDBM,  mode == "dbm")
    setActive(btnBW,   mode == "bigwigs")
    local st = getglobal("RT_NotesStatus")
    if st then
        local modeTxt = RT_Text("notes_addon_none")
        if mode == "dbm" then modeTxt = RT_Text("notes_addon_dbm") end
        if mode == "bigwigs" then modeTxt = RT_Text("notes_addon_bigwigs") end
        st:SetText(RT_ColorGold(RT_Text("notes_addon_mode_set", {mode=modeTxt})))
    end
end

function RT_NotesLoadKey(key)
    RT_DB           = RT_DB or {}
    RT_DB.stratNotes = RT_DB.stratNotes or {}

    local keyEdit  = getglobal("RT_NotesKeyEdit")
    local textEdit = getglobal("RT_NotesTextEdit")
    local status   = getglobal("RT_NotesStatus")

    if keyEdit  then keyEdit:SetText(key) end
    if textEdit then textEdit:SetText(RT_DB.stratNotes[key] or "") end
    if status then
        local exists = RT_DB.stratNotes[key] and RT_DB.stratNotes[key] ~= ""
        if exists then
            status:SetText(RT_ColorGold(RT_Text("notes_loaded", {key=key})))
        else
            status:SetText("|cffAAAAAA" .. RT_Text("notes_new_key", {key=key}) .. "|r")
        end
    end
end

-- ============================================================
-- Check — Annonce raid des manquants
-- ============================================================

function RT_CheckAnnounceMissing()
    local log = getglobal("RT_CheckLog")
    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    local units = {}
    if nRaid > 0 then
        for i = 1, nRaid do table.insert(units, "raid" .. i) end
    elseif nParty > 0 then
        table.insert(units, "player")
        for i = 1, nParty do table.insert(units, "party" .. i) end
    else
        if log then log:AddMessage(RT_ColorErr(RT_Text("check_no_raid"))) end
        return
    end
    local cfg = RT_CheckBuffConfig()
    local missingFlask, missingFood, missingWeapon = {}, {}, {}
    for i = 1, table.getn(units) do
        local unit = units[i]
        if UnitExists(unit) then
            local name = UnitName(unit) or "?"
            if cfg.flask  and not RT_UnitHasBuffPattern(unit, RT_FLASK_TEX)  then table.insert(missingFlask,  name) end
            if cfg.food   and not RT_UnitHasBuffPattern(unit, RT_FOOD_TEX)   then table.insert(missingFood,   name) end
            if cfg.weapon and not RT_UnitHasBuffPattern(unit, RT_WEAPON_TEX) then table.insert(missingWeapon, name) end
        end
    end
    local channel, channelShort = RT_GetBestAnnounceChannel()
    local sent = 0
    if table.getn(missingFlask)  > 0 then
        SendChatMessage("[RT] Flasque manquante : "     .. table.concat(missingFlask,  ", "), channel); sent = sent + 1
    end
    if table.getn(missingFood)   > 0 then
        SendChatMessage("[RT] Nourriture manquante : "  .. table.concat(missingFood,   ", "), channel); sent = sent + 1
    end
    if table.getn(missingWeapon) > 0 then
        SendChatMessage("[RT] Enchant arme manquant : " .. table.concat(missingWeapon, ", "), channel); sent = sent + 1
    end
    if sent == 0 then
        local what = {}
        if cfg.flask  then table.insert(what, "flasques") end
        if cfg.food   then table.insert(what, "nourriture") end
        if cfg.weapon then table.insert(what, "armes") end
        local label = table.getn(what) > 0 and table.concat(what, "+") or "buffs"
        SendChatMessage("[RT] Raid pret — " .. label .. " OK", channel)
    end
    if log then
        log:AddMessage(RT_ColorOK("Annonce /" .. (channelShort or channel) .. " — " .. sent .. " rappel(s)"))
    end
end

-- ============================================================
-- Buff HUD flottant (déplaçable)
-- ============================================================

-- (RT_BUFF_HUD_LAST_BOSS et RT_BUFF_HUD_DETECT_TIMER sont des globaux initialisés avant OnUpdate)

function RT_BuffHUDToggle()
    local hud = getglobal("RT_BuffHUD")
    if not hud then return end
    if hud:IsShown() then
        hud:Hide()
        RT_DB = RT_DB or {}
        RT_DB.settings = RT_DB.settings or {}
        RT_DB.settings.buffHUD = RT_DB.settings.buffHUD or {}
        RT_DB.settings.buffHUD.enabled = false
        local b = getglobal("RT_BuffHUDToggleBtn")
        if b then b:SetText("⬜ HUD: OFF") end
    else
        hud:Show()
        RT_DB = RT_DB or {}
        RT_DB.settings = RT_DB.settings or {}
        RT_DB.settings.buffHUD = RT_DB.settings.buffHUD or {}
        RT_DB.settings.buffHUD.enabled = true
        RT_BuffHUDDisplay()
        local b = getglobal("RT_BuffHUDToggleBtn")
        if b then b:SetText("⬛ HUD: ON") end
    end
end

function RT_BuffHUDDisplay()
    local log = getglobal("RT_BuffHUDLog")
    if not log then return end
    log:Clear()

    local CHECK_OK   = "|cff00FF00OK|r"
    local CHECK_MISS = "|cffFF3333NO|r"
    local CHECK_PART = "|cffFFAA00~~|r"
    local CHECK_UNK  = "|cff888888 ?|r"

    local total = RT_CountPlayers()
    if total == 0 then
        log:AddMessage("|cff888888Aucun roster chargé.|r")
        log:AddMessage("|cff666666Import CSV ou actualiser raid.|r")
        return
    end

    log:AddMessage(RT_ColorTitle("─ BUFFS DE RAID (" .. total .. " joueurs)"))
    local classes = {
        { key = "Priest", label = "Prêtres" },
        { key = "Mage",   label = "Mages"   },
        { key = "Druid",  label = "Druides"  },
    }
    for classIdx = 1, table.getn(classes) do
        local ci = classes[classIdx]
        local assignments = RT_BuffBuildGroupAssignments(ci.key)
        if table.getn(assignments) > 0 then
            for rowIdx = 1, table.getn(assignments) do
                local row = assignments[rowIdx]
                local status = RT_BuffCheckGroupStatus(ci.key, row.groups)
                local icon = CHECK_UNK
                if     status == "ok"      then icon = CHECK_OK
                elseif status == "missing" then icon = CHECK_MISS
                elseif status == "partial" then icon = CHECK_PART end
                local short = string.sub(row.name, 1, 16)
                log:AddMessage(icon .. " " .. RT_ColorClass(short, ci.key)
                    .. " |cff888888→ G" .. RT_BuffFormatGroups(row.groups) .. "|r")
            end
        else
            log:AddMessage("|cff555555" .. ci.label .. " : aucun|r")
        end
    end

    log:AddMessage(RT_ColorTitle("─ DÉMONISTES"))
    local warlocks = RT_BuffBuildWarlockAssignments()
    if table.getn(warlocks) == 0 then
        log:AddMessage("|cff555555Aucun Démoniste|r")
    else
        for rowIdx = 1, table.getn(warlocks) do
            local row = warlocks[rowIdx]
            log:AddMessage(" " .. RT_ColorClass(RT_PadRight(string.sub(row.name,1,12), 13), "Warlock")
                .. "|cff888888" .. RT_BuffCurseText(row.curse) .. "|r")
        end
    end

    log:AddMessage(RT_ColorTitle("─ CDs RAID"))
    local classMap = RT_BuildClassMap()
    for cdIdx = 1, table.getn(RT_RAID_CDS) do
        local cd = RT_RAID_CDS[cdIdx]
        local players = classMap[cd.class]
        local label = string.sub(RT_Text(cd.key), 1, 18)
        if players and table.getn(players) > 0 then
            log:AddMessage(RT_ColorClass(label, cd.class)
                .. " |cff888888" .. table.concat(players, ", ") .. "|r")
        else
            log:AddMessage("|cff444444" .. label .. " : —|r")
        end
    end
end

function RT_BuffHUDCreate()
    if getglobal("RT_BuffHUD") then return end

    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    local bhs = RT_DB.settings.buffHUD or {}
    RT_DB.settings.buffHUD = bhs

    local hud = CreateFrame("Frame", "RT_BuffHUD", UIParent)
    hud:SetWidth(250)
    hud:SetHeight(400)
    hud:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", bhs.x or -10, bhs.y or -180)
    hud:SetFrameStrata("HIGH")
    hud:SetMovable(true)
    hud:EnableMouse(true)
    hud:RegisterForDrag("LeftButton")
    hud:SetScript("OnDragStart", function() hud:StartMoving() end)
    hud:SetScript("OnDragStop", function()
        hud:StopMovingOrSizing()
        local _, _, _, x, y = hud:GetPoint()
        RT_DB.settings.buffHUD.x = x
        RT_DB.settings.buffHUD.y = y
    end)
    RT_PatchBackdrop(hud)
    hud:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    hud:SetBackdropColor(0.02, 0.02, 0.06, 0.90)
    hud:SetBackdropBorderColor(0.45, 0.55, 0.80, 0.85)
    hud:Hide()

    local hudTitle = hud:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hudTitle:SetPoint("TOPLEFT", hud, "TOPLEFT", 8, -6)
    hudTitle:SetText("◈ Buffs / CDs")
    hudTitle:SetTextColor(1.0, 0.88, 0.2)

    local hudClose = CreateFrame("Button", nil, hud, "UIPanelCloseButton")
    hudClose:SetPoint("TOPRIGHT", hud, "TOPRIGHT", 2, 2)
    hudClose:SetWidth(20)
    hudClose:SetHeight(20)
    hudClose:SetScript("OnClick", function() RT_BuffHUDToggle() end)

    local hudRefresh = CreateFrame("Button", nil, hud, "UIPanelButtonTemplate")
    hudRefresh:SetPoint("TOPRIGHT", hudClose, "TOPLEFT", -2, 0)
    hudRefresh:SetWidth(24)
    hudRefresh:SetHeight(18)
    hudRefresh:SetText("↺")
    hudRefresh:SetScript("OnClick", function() RT_BuffHUDDisplay() end)

    local hudSep = hud:CreateTexture(nil, "ARTWORK")
    hudSep:SetPoint("TOPLEFT", hud, "TOPLEFT", 4, -22)
    hudSep:SetWidth(242)
    hudSep:SetHeight(1)
    hudSep:SetTexture(0.4, 0.5, 0.8, 0.5)

    local hudLog = CreateFrame("ScrollingMessageFrame", "RT_BuffHUDLog", hud)
    hudLog:SetPoint("TOPLEFT", hud, "TOPLEFT", 4, -26)
    hudLog:SetWidth(242)
    hudLog:SetHeight(370)
    hudLog:SetFontObject(GameFontNormalSmall)
    hudLog:SetJustifyH("LEFT")
    hudLog:SetFading(false)
    hudLog:SetMaxLines(200)
    hudLog:EnableMouseWheel(1)
    hudLog:SetScript("OnMouseWheel", function()
        local delta = arg1 or 0
        if delta > 0 then hudLog:ScrollUp()
        elseif delta < 0 then hudLog:ScrollDown() end
    end)

    if bhs.enabled then
        hud:Show()
        RT_BuffHUDDisplay()
    end

    local btn = getglobal("RT_BuffHUDToggleBtn")
    if btn then
        btn:SetText(bhs.enabled and "⬛ HUD: ON" or "⬜ HUD: OFF")
    end
end

-- ============================================================
-- Raid Check — scan des buffs en raid
-- ============================================================

function RT_CheckScanRaid()
    local log = getglobal("RT_CheckLog")
    if not log then return end
    log:Clear()

    local nRaid  = GetNumRaidMembers  and GetNumRaidMembers()  or 0
    local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0

    local units = {}
    if nRaid > 0 then
        for i = 1, nRaid do
            table.insert(units, "raid" .. i)
        end
    elseif nParty > 0 then
        table.insert(units, "player")
        for i = 1, nParty do
            table.insert(units, "party" .. i)
        end
    else
        log:AddMessage(RT_ColorErr(RT_Text("check_no_raid")))
        return
    end

    local cfg = RT_CheckBuffConfig()
    local n = table.getn(units)
    log:AddMessage(RT_ColorGold(RT_Text("check_result_hdr", {n=n})))

    -- En-tête colonnes selon config active
    local colHdr = " Joueur               "
    if cfg.flask  then colHdr = colHdr .. " Flask" end
    if cfg.food   then colHdr = colHdr .. "  Food" end
    if cfg.weapon then colHdr = colHdr .. "  Arme" end
    log:AddMessage("|cffAAAAFF" .. colHdr .. "|r")

    local ok_s, no_s, sk_s = "|cff00ff00OK|r", "|cffff4444✗|r", "|cff888888--|r"
    local missingFlask, missingFood, missingWeapon = {}, {}, {}

    for ui = 1, table.getn(units) do
        local unit = units[ui]
        if UnitExists(unit) then
            local name = UnitName(unit) or "?"
            local padded = name
            while string.len(padded) < 20 do padded = padded .. " " end
            local line = " " .. padded

            if cfg.flask then
                local has = RT_UnitHasBuffPattern(unit, RT_FLASK_TEX)
                line = line .. "  " .. (has and ok_s or no_s)
                if not has then table.insert(missingFlask, name) end
            end
            if cfg.food then
                local has = RT_UnitHasBuffPattern(unit, RT_FOOD_TEX)
                line = line .. "  " .. (has and ok_s or no_s)
                if not has then table.insert(missingFood, name) end
            end
            if cfg.weapon then
                local has = RT_UnitHasBuffPattern(unit, RT_WEAPON_TEX)
                line = line .. "  " .. (has and ok_s or sk_s)
                if not has then table.insert(missingWeapon, name) end
            end
            log:AddMessage(line)
        end
    end

    log:AddMessage("")
    local anyMissing = false
    if cfg.flask  and table.getn(missingFlask)  > 0 then
        log:AddMessage("|cffFF6020" .. RT_Text("check_no_flask") .. "|r " .. table.concat(missingFlask, ", "))
        anyMissing = true
    end
    if cfg.food   and table.getn(missingFood)   > 0 then
        log:AddMessage("|cffFF6020" .. RT_Text("check_no_food") .. "|r " .. table.concat(missingFood, ", "))
        anyMissing = true
    end
    if cfg.weapon and table.getn(missingWeapon) > 0 then
        log:AddMessage("|cffFF6020Arme enchant. manquant :|r " .. table.concat(missingWeapon, ", "))
        anyMissing = true
    end
    if not anyMissing then
        log:AddMessage("|cff00ff00" .. RT_Text("check_all_ok") .. "|r")
    end
end

-- ============================================================
-- Cooldowns de raid
-- ============================================================

function RT_CooldownDisplay()
    local log = getglobal("RT_CooldownLog")
    if not log then return end
    log:Clear()

    local cdcfg   = RT_CheckCDConfig()
    local classMap = RT_BuildClassMap()
    local shown   = 0

    for cdIdx = 1, table.getn(RT_RAID_CDS) do
        local cd = RT_RAID_CDS[cdIdx]
        if cdcfg[cd.key] then
            local players = classMap[cd.class]
            local label   = RT_Text(cd.key)
            local clsColor = "|cffFFFFFF"
            for ci = 1, table.getn(RT_BLESS_CLASSES) do
                if RT_BLESS_CLASSES[ci][1] == cd.class then
                    local c = RT_BLESS_CLASSES[ci][2]
                    clsColor = string.format("|cff%02X%02X%02X",
                        math.floor(c[1]*255), math.floor(c[2]*255), math.floor(c[3]*255))
                    break
                end
            end
            if players and table.getn(players) > 0 then
                log:AddMessage(clsColor .. label .. ":|r " .. table.concat(players, ", "))
            else
                log:AddMessage("|cff555555" .. label .. RT_Text("cd_none") .. "|r")
            end
            shown = shown + 1
        end
    end

    if shown == 0 then
        log:AddMessage("|cff888888Aucun CD selectionne — active les toggles ci-dessus.|r")
    end
end

-- ============================================================
-- Bénédictions Paladin (PallyPower-lite)
-- ============================================================

local function RT_BlessingsUpdatePallySummary()
    local onlyBox = getglobal("RT_BlessPallyOnlyText")
    local box     = getglobal("RT_BlessPallySummary")
    if not onlyBox and not box then return end

    RT_DB = RT_DB or {}
    RT_DB.blessings = RT_DB.blessings or {}
    RT_DB.blessings.palaAssign = RT_DB.blessings.palaAssign or {}
    RT_BlessPalaRows = RT_BlessPalaRows or {}

    local out = {}
    local hasSomething = false

    for ri = 1, 8 do
        local palaName = RT_BlessPalaRows[ri]
        if palaName then
            local assign = RT_DB.blessings.palaAssign[palaName] or {}
            local blessName = RT_GetBlessingName(assign.blessIdx or 1)
            local p10 = RT_BTrim(assign.player10min or "")
            local line = RT_ColorClass(palaName, "Paladin") .. "  |cffd0d0d0->|r  |cff8ec8ff" .. blessName .. "|r"
            if p10 ~= "" then
                line = line .. "  |cffaaaaaa+ 10min:|r " .. p10
            end
            table.insert(out, line)
            hasSomething = true
        end
    end

    if not hasSomething then
        table.insert(out, "|cff888888" .. RT_Text("bless_map_empty") .. "|r")
    end

    local finalText = table.concat(out, "\n")
    if onlyBox then onlyBox:SetText(finalText) end
    if box     then box:SetText(finalText) end

    local nLines = 1
    for _ in string.gfind(finalText, "\n") do
        nLines = nLines + 1
    end
    local onlyContent = getglobal("RT_BlessPallyOnlyContent")
    if onlyContent then
        local h2 = nLines * 14 + 12
        if h2 < 160 then h2 = 160 end
        onlyContent:SetHeight(h2)
    end
    local onlyScroll = getglobal("RT_BlessPallyOnlyScroll")
    if onlyScroll then
        onlyScroll:UpdateScrollChildRect()
        onlyScroll:SetVerticalScroll(0)
    end
end

function RT_BlessingsDisplay()
    RT_DB                       = RT_DB or {}
    RT_DB.blessings             = RT_DB.blessings or {}
    RT_DB.blessings.palaAssign  = RT_DB.blessings.palaAssign or {}
    RT_BlessPalaRows            = RT_BlessPalaRows or {}

    local palas  = RT_GetPaladinsInRaid()
    local nPalas = table.getn(palas)

    local blessStatus = getglobal("RT_BlessStatus")
    if nPalas == 0 then
        if blessStatus then blessStatus:SetText("|cff888888" .. RT_Text("bless_no_pala") .. "|r") end
    else
        if blessStatus then blessStatus:SetText("") end
    end

    -- Populate per-paladin rows (up to 8)
    for ri = 1, 8 do
        local rowFrame  = getglobal("RT_BlessRow_Frame_"..ri)
        local palLbl    = getglobal("RT_BlessRow_Lbl_"..ri)
        local blessBtn  = getglobal("RT_BlessRow_Bless_"..ri)
        local playerBtn = getglobal("RT_BlessRow_Player_"..ri)

        if ri <= nPalas then
            local palaName = palas[ri]
            RT_BlessPalaRows[ri] = palaName
            local assign = RT_DB.blessings.palaAssign[palaName] or {}
            if rowFrame  then rowFrame:Show() end
            if palLbl    then palLbl:SetText(palaName) end
            if blessBtn  then blessBtn:SetText(RT_GetBlessingName(assign.blessIdx or 1)) end
            if playerBtn then
                local p = assign.player10min or ""
                playerBtn:SetText((p ~= "") and p or "—")
            end
        else
            RT_BlessPalaRows[ri] = nil
            if rowFrame then rowFrame:Hide() end
        end
    end

    RT_BlessingsUpdatePallySummary()
end

function RT_BlessCyclePaladin(className, step)
    RT_DB                        = RT_DB or {}
    RT_DB.blessings              = RT_DB.blessings or {}
    RT_DB.blessings.classAssign  = RT_DB.blessings.classAssign or {}

    local assign = RT_DB.blessings.classAssign[className] or {}
    local palas  = RT_GetPaladinsInRaid()

    if table.getn(palas) == 0 then return end

    if IsShiftKeyDown and IsShiftKeyDown() and arg1 == "RightButton" then
        assign.pala = ""
        RT_DB.blessings.classAssign[className] = assign
        local btnClr = getglobal("RT_BlessPane_" .. className .. "_Pala")
        if btnClr then btnClr:SetText(RT_Text("bless_none")) end
        return
    end

    local dir = tonumber(step) or 1
    if dir == 0 then dir = 1 end

    -- Trouver l'index actuel
    local curPala = assign.pala or ""
    local curIdx  = 0
    for i = 1, table.getn(palas) do
        if palas[i] == curPala then curIdx = i; break end
    end

    local nPal = table.getn(palas)
    local nextIdx = curIdx + dir
    if nextIdx < 1 then nextIdx = nPal end
    if nextIdx > nPal then nextIdx = 1 end

    assign.pala = palas[nextIdx] or ""
    RT_DB.blessings.classAssign[className] = assign

    local btn = getglobal("RT_BlessPane_" .. className .. "_Pala")
    if btn then
        btn:SetText((assign.pala ~= "") and assign.pala or RT_Text("bless_none"))
    end
    RT_BlessingsUpdatePallySummary()
end

function RT_BlessCycleBlessing(className, step)
    RT_DB                        = RT_DB or {}
    RT_DB.blessings              = RT_DB.blessings or {}
    RT_DB.blessings.classAssign  = RT_DB.blessings.classAssign or {}

    local assign   = RT_DB.blessings.classAssign[className] or {}
    local blessIdx = assign.blessIdx or 1

    if IsShiftKeyDown and IsShiftKeyDown() and arg1 == "RightButton" then
        blessIdx = 1
    else
        local dir = tonumber(step) or 1
        if dir == 0 then dir = 1 end
        local maxTypes = table.getn(RT_BLESS_TYPES_FR)
        blessIdx = blessIdx + dir
        if blessIdx < 1 then blessIdx = maxTypes end
        if blessIdx > maxTypes then blessIdx = 1 end
    end

    assign.blessIdx = blessIdx
    RT_DB.blessings.classAssign[className] = assign

    local btn = getglobal("RT_BlessPane_" .. className .. "_Bless")
    if btn then
        btn:SetText(RT_GetBlessingName(blessIdx))
    end
    RT_BlessingsUpdatePallySummary()
end

-- Cycle la bénédiction (Grande Bénédiction) du paladin à la rangée rowIdx
function RT_BlessCyclePalaBlessing(rowIdx, dir)
    RT_DB = RT_DB or {}
    RT_DB.blessings = RT_DB.blessings or {}
    RT_DB.blessings.palaAssign = RT_DB.blessings.palaAssign or {}
    RT_BlessPalaRows = RT_BlessPalaRows or {}

    local palaName = RT_BlessPalaRows[rowIdx]
    if not palaName then return end

    local assign = RT_DB.blessings.palaAssign[palaName] or {}
    local blessIdx = assign.blessIdx or 1
    local d = tonumber(dir) or 1
    local maxTypes = table.getn(RT_BLESS_TYPES_FR)
    blessIdx = blessIdx + d
    if blessIdx < 1 then blessIdx = maxTypes end
    if blessIdx > maxTypes then blessIdx = 1 end
    assign.blessIdx = blessIdx
    RT_DB.blessings.palaAssign[palaName] = assign

    local btn = getglobal("RT_BlessRow_Bless_"..rowIdx)
    if btn then btn:SetText(RT_GetBlessingName(blessIdx)) end
    RT_BlessSyncPalaRowToPP(palaName, assign)
    RT_BlessingsUpdatePallySummary()
end

-- Cycle le joueur ciblé pour la bénédiction 10min du paladin à la rangée rowIdx
function RT_BlessCyclePalaPlayer(rowIdx, dir)
    RT_DB = RT_DB or {}
    RT_DB.blessings = RT_DB.blessings or {}
    RT_DB.blessings.palaAssign = RT_DB.blessings.palaAssign or {}
    RT_BlessPalaRows = RT_BlessPalaRows or {}

    local palaName = RT_BlessPalaRows[rowIdx]
    if not palaName then return end

    local assign = RT_DB.blessings.palaAssign[palaName] or {}
    local players = RT_GetAllRaidPlayers()
    if table.getn(players) == 0 then return end

    local curPlayer = assign.player10min or ""
    local curIdx = 0
    for i = 1, table.getn(players) do
        if players[i] == curPlayer then curIdx = i; break end
    end

    local d = tonumber(dir) or 1
    local n = table.getn(players)
    -- curIdx 0 = aucun; indices 1..n = joueurs
    local nextIdx = curIdx + d
    if nextIdx < 0 then nextIdx = n end
    if nextIdx > n then nextIdx = 0 end

    assign.player10min = (nextIdx == 0) and "" or (players[nextIdx] or "")
    RT_DB.blessings.palaAssign[palaName] = assign

    local btn = getglobal("RT_BlessRow_Player_"..rowIdx)
    if btn then
        local p = assign.player10min or ""
        btn:SetText((p ~= "") and p or "—")
    end
    RT_BlessSyncPalaRowToPP(palaName, assign)
    RT_BlessingsUpdatePallySummary()
end

function RT_BlessingsAnnounce()
    RT_DB = RT_DB or {}
    RT_DB.blessings = RT_DB.blessings or {}
    RT_DB.blessings.palaAssign = RT_DB.blessings.palaAssign or {}
    RT_BlessPalaRows = RT_BlessPalaRows or {}

    local lines = {}
    for ri = 1, 8 do
        local palaName = RT_BlessPalaRows[ri]
        if palaName then
            local assign    = RT_DB.blessings.palaAssign[palaName] or {}
            local blessName = RT_GetBlessingName(assign.blessIdx or 1)
            if blessName and blessName ~= "—" and blessName ~= "" then
                local line = palaName .. " -> " .. blessName
                local p10 = RT_BTrim(assign.player10min or "")
                if p10 ~= "" then
                    line = line .. " (10min: " .. p10 .. ")"
                end
                table.insert(lines, line)
            end
        end
    end

    if table.getn(lines) == 0 then
        RT_Print(RT_ColorErr(RT_Text("bless_nothing_to_send")))
        return
    end

    local channel, channelShort = RT_GetBestAnnounceChannel()
    SendChatMessage("[RT] " .. RT_Text("bless_title"), channel)
    for li = 1, table.getn(lines) do
        SendChatMessage(lines[li], channel)
    end

    local blessStatus = getglobal("RT_BlessStatus")
    if blessStatus then
        blessStatus:SetText(RT_ColorGold(RT_Text("bless_broadcast_done", {ch=channelShort})))
    end
    RT_Print(RT_Text("bless_broadcast_done", {ch=channelShort}))
end










































































































































-- ============================================================
-- RT v3 (integre dans rt.lua) - /rt v3 pour ouvrir
-- ============================================================

-- [v3:Compat]
-- RT v3 - Compat.lua (chargement depuis la racine)

RT = RT or {}
RT.version = "3.0-dev"

function RT.Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffAA66FF[RT3]|r " .. tostring(msg))
    end
end

function RT.Pack(...)
    local t = {}
    local n = arg.n or table.getn(arg)
    for i = 1, n do t[i] = arg[i] end
    t.n = n
    return t
end

function RT.Match(s, pattern)
    if not s then return nil end
    local a, b, c1, c2, c3 = string.find(s, pattern)
    if a == nil then return nil end
    if c1 ~= nil then return c1, c2, c3 end
    return string.sub(s, a, b)
end

RT.getn = table.getn
RT.mod  = math.mod

function RT.OnEvent(frame, handler)
    frame:SetScript("OnEvent", function()
        handler(event, arg1, arg2, arg3, arg4, arg5)
    end)
end

function RT.Events(eventList, handler)
    local f = CreateFrame("Frame")
    for i = 1, table.getn(eventList) do
        f:RegisterEvent(eventList[i])
    end
    RT.OnEvent(f, handler)
    return f
end

local _timers   = {}
local _timerSeq = 0
local _ticker   = nil

local function _startTicker()
    if _ticker then return end
    _ticker = CreateFrame("Frame", "RT_Ticker", UIParent)
    _ticker:SetScript("OnUpdate", function()
        local now = GetTime()
        local due
        for id, t in pairs(_timers) do
            if now >= t.at then
                due = due or {}
                table.insert(due, id)
            end
        end
        if not due then return end
        for i = 1, table.getn(due) do
            local id2 = due[i]
            local t2  = _timers[id2]
            if t2 then
                if t2.interval then
                    t2.at = now + t2.interval
                else
                    _timers[id2] = nil
                end
                local ok, err = pcall(t2.fn)
                if not ok then RT.Print("|cffFF4444[timer] " .. tostring(err) .. "|r") end
            end
        end
    end)
end

function RT.After(seconds, fn)
    _startTicker()
    _timerSeq = _timerSeq + 1
    local id = _timerSeq
    _timers[id] = { at = GetTime() + (seconds or 0), fn = fn }
    return id
end

function RT.Every(seconds, fn)
    _startTicker()
    _timerSeq = _timerSeq + 1
    local id = _timerSeq
    _timers[id] = { at = GetTime() + (seconds or 0), fn = fn, interval = seconds }
    return id
end

function RT.Cancel(id)
    if id then _timers[id] = nil end
end

function RT.ClassColor(class)
    local c = RT_CLASS_COLORS and RT_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.80, 0.80, 0.80
end

function RT.RoleColor(role)
    if role == "Melee"  then return 1.00, 0.55, 0.00 end
    if role == "Ranged" then return 0.20, 0.85, 1.00 end
    local c = RT_ROLE_COLORS and RT_ROLE_COLORS[role]
    if c then return c.r, c.g, c.b end
    return 0.60, 0.60, 0.60
end

function RT.NormClass(class)
    if RT_NormalizeClassName then return RT_NormalizeClassName(class or "") end
    return class or ""
end

function RT.NormRole(role)
    if RT_NormalizeRole then return RT_NormalizeRole(role or "") end
    return role or ""
end

-- Détecte le rôle probable à partir de la classe et de la spé
function RT3_RoleFromSpec(cls, spec)
    local c = string.upper(cls  or "")
    local s = string.lower(spec or "")

    -- Tanks
    if c == "WARRIOR" and string.find(s, "prot") then return "Tank" end
    if c == "PALADIN" and string.find(s, "prot") then return "Tank" end
    if c == "DRUID"   and string.find(s, "feral") and string.find(s, "tank") then return "Tank" end

    -- Heals
    if c == "PRIEST"  and (string.find(s, "holy") or string.find(s, "disc")) then return "Heal" end
    if c == "PALADIN" and string.find(s, "holy")  then return "Heal" end
    if c == "DRUID"   and string.find(s, "resto") then return "Heal" end
    if c == "SHAMAN"  and string.find(s, "resto") then return "Heal" end

    -- Ranged
    if c == "HUNTER"  then return "Ranged" end
    if c == "MAGE"    then return "Ranged" end
    if c == "WARLOCK" then return "Ranged" end
    if c == "PRIEST"  and string.find(s, "shadow") then return "Ranged" end
    if c == "DRUID"   and string.find(s, "balance") then return "Ranged" end
    if c == "SHAMAN"  and string.find(s, "ele")    then return "Ranged" end

    -- Melee
    if c == "WARRIOR" then return "Melee" end
    if c == "ROGUE"   then return "Melee" end
    if c == "PALADIN" and string.find(s, "retri") then return "Melee" end
    if c == "DRUID"   and string.find(s, "feral") then return "Melee" end
    if c == "SHAMAN"  and string.find(s, "enh")   then return "Melee" end

    return nil  -- spé inconnue ou absente
end

-- ============================================================
-- Déduction classe + spé canonique depuis un libellé de spé
-- (imports Raid-Helper / softres / CSV, texte libre FR/EN).
-- Raid-Helper suffixe "1" les doublons : Holy1/Protection1 =
-- Paladin, Restoration1 = Shaman (Holy = Priest, Protection =
-- Warrior, Restoration = Druid).
-- Ordre = du plus spécifique au plus générique (match substring).
-- ============================================================
RT3_SPEC_INFO = {
    -- Raid-Helper désambiguïsés (à tester AVANT la forme nue)
    { "protection1",  "Prot",       "PALADIN" },
    { "holy1",        "Holy",       "PALADIN" },
    { "restoration1", "Resto",      "SHAMAN"  },
    -- Druid
    { "guardian",     "Feral Tank", "DRUID"   },
    { "feral",        "Feral",      "DRUID"   },
    { "farouche",     "Feral",      "DRUID"   },
    { "balance",      "Balance",    "DRUID"   },
    { "equilibre",    "Balance",    "DRUID"   },
    { "boomkin",      "Balance",    "DRUID"   },
    -- Hunter
    { "beastmaster",  "BM",         "HUNTER"  },
    { "beast",        "BM",         "HUNTER"  },
    { "marksman",     "MM",         "HUNTER"  },
    { "precision",    "MM",         "HUNTER"  },
    { "survival",     "Surv",       "HUNTER"  },
    { "survie",       "Surv",       "HUNTER"  },
    -- Mage
    { "arcane",       "Arcane",     "MAGE"    },
    { "fire",         "Fire",       "MAGE"    },
    { "frost",        "Frost",      "MAGE"    },
    { "givre",        "Frost",      "MAGE"    },
    -- Paladin
    { "retribution",  "Retri",      "PALADIN" },
    { "vindicte",     "Retri",      "PALADIN" },
    { "retri",        "Retri",      "PALADIN" },
    -- Priest
    { "discipline",   "Disc",       "PRIEST"  },
    { "disc",         "Disc",       "PRIEST"  },
    { "shadow",       "Shadow",     "PRIEST"  },
    { "ombre",        "Shadow",     "PRIEST"  },
    { "smite",        "Disc",       "PRIEST"  },
    -- Rogue
    { "assassination","Assa",       "ROGUE"   },
    { "combat",       "Combat",     "ROGUE"   },
    { "subtlety",     "Subt",       "ROGUE"   },
    { "finesse",      "Subt",       "ROGUE"   },
    -- Shaman
    { "elemental",    "Elem",       "SHAMAN"  },
    { "elementaire",  "Elem",       "SHAMAN"  },
    { "enhancement",  "Enh",        "SHAMAN"  },
    { "amelioration", "Enh",        "SHAMAN"  },
    { "enh",          "Enh",        "SHAMAN"  },
    -- Warlock
    { "affliction",   "Affli",      "WARLOCK" },
    { "demonology",   "Demo",       "WARLOCK" },
    { "demonologie",  "Demo",       "WARLOCK" },
    { "destruction",  "Destro",     "WARLOCK" },
    { "destro",       "Destro",     "WARLOCK" },
    -- Warrior
    { "arms",         "Arms",       "WARRIOR" },
    { "armes",        "Arms",       "WARRIOR" },
    { "fury",         "Fury",       "WARRIOR" },
    { "furie",        "Fury",       "WARRIOR" },
    -- Formes nues (Raid-Helper : classe "premier arrivé")
    { "protection",   "Prot",       "WARRIOR" },
    { "restoration",  "Resto",      "DRUID"   },
    { "holy",         "Holy",       "PRIEST"  },
    { "sacre",        "Holy",       nil       },
    -- Abréviations ambiguës : spé canonique connue, classe indéterminée
    { "resto",        "Resto",      nil       },
    { "prot",         "Prot",       nil       },
}

-- Retourne (specCanonique, classeEN|nil) depuis un libellé libre.
function RT3_SpecInfo(spec)
    if not spec or spec == "" then return nil, nil end
    local s = string.lower(spec)
    for i = 1, table.getn(RT3_SPEC_INFO) do
        local e = RT3_SPEC_INFO[i]
        if string.find(s, e[1], 1, true) then return e[2], e[3] end
    end
    return nil, nil
end

-- Complète automatiquement le roster : classe manquante déduite de la
-- spé, spé normalisée ("Protection1" → "Prot"), rôle affiné (vide/?/DPS
-- → Tank/Heal/Melee/Ranged). Ne touche jamais un Tank/Heal déjà défini.
-- Retourne (classesFixées, rôlesFixés).
function RT3_AutofixRoster()
    local db = RT_DB and RT_DB.roster
    if not db then return 0, 0 end
    local nCls, nRole = 0, 0
    for _, d in pairs(db) do
        local canon, cls = RT3_SpecInfo(d.spec)
        if canon and d.spec ~= canon then d.spec = canon end
        if cls and (not d.class or d.class == "") then
            d.class = RT.NormClass and RT.NormClass(cls) or cls
            nCls = nCls + 1
        end
        local cur = d.role or ""
        if cur == "" or cur == "?" or cur == "DPS" then
            local r = RT3_RoleFromSpec(d.class or "", d.spec or "")
            if r and r ~= cur then
                d.role = r
                nRole = nRole + 1
            end
        end
    end
    return nCls, nRole
end

-- ============================================================
-- Détection de spé via talents + échange entre joueurs
-- ============================================================
-- Ordre RÉEL des onglets de talents en 1.12 (indépendant de la langue).
-- L'index renvoyé par GetTalentTabInfo correspond à cette table.
RT3_TALENT_SPECS = {
    WARRIOR = { "Arms",  "Fury",  "Prot"  },
    PALADIN = { "Holy",  "Prot",  "Retri" },
    HUNTER  = { "BM",    "MM",    "Surv"  },
    ROGUE   = { "Assa",  "Combat","Subt"  },
    PRIEST  = { "Disc",  "Holy",  "Shadow"},
    SHAMAN  = { "Elem",  "Enh",   "Resto" },
    MAGE    = { "Arcane","Fire",  "Frost" },
    WARLOCK = { "Affli", "Demo",  "Destro"},
    DRUID   = { "Balance","Feral","Resto" },
}

-- Lit les talents du joueur LOCAL → renvoie classeEN, spec, points.
-- (En 1.12 on ne peut lire que SES propres talents, pas ceux des autres.)
function RT3_DetectMySpec()
    if not GetNumTalentTabs or not GetTalentTabInfo then return nil end
    local nTabs = GetNumTalentTabs()
    if not nTabs or nTabs < 1 then return nil end
    local best, bestPts = 0, -1
    for t = 1, nTabs do
        local _, _, pts = GetTalentTabInfo(t)
        pts = pts or 0
        if pts > bestPts then bestPts = pts; best = t end
    end
    if best < 1 or bestPts <= 0 then return nil end  -- pas de talents → on ne devine pas
    local _, enCls = UnitClass("player")
    enCls = string.upper(enCls or "")
    local map  = RT3_TALENT_SPECS[enCls]
    local spec = map and map[best] or nil
    return enCls, spec, bestPts
end

-- Écrit la spé d'un joueur dans le roster et recalcule son rôle.
-- class peut être nil → on garde la classe déjà connue.
function RT3_SetPlayerSpec(name, class, spec)
    if not name or name == "" then return false end
    local db = RT.Store.Roster()
    db[name] = db[name] or {}
    if class and class ~= "" then
        local nc = RT.NormClass(class)
        if nc ~= "" then db[name].class = nc end
    end
    if spec and spec ~= "" then
        db[name].spec = spec
        if RT3_RoleFromSpec then
            local role = RT3_RoleFromSpec(db[name].class or class or "", spec)
            if role then db[name].role = role end
        end
    end
    RT.Store.Notify("roster")
    return true
end

-- Diffuse une demande de spé à tout le raid (les joueurs qui ont RT
-- répondent automatiquement et silencieusement via addon).
function RT3_RequestSpecsAddon()
    -- enregistre la sienne tout de suite
    local cls, spec = RT3_DetectMySpec()
    local me = UnitName and UnitName("player") or ""
    if spec and me ~= "" then RT3_SetPlayerSpec(me, cls, spec) end
    if RT_Sync_Send then RT_Sync_Send("SPECREQ") end
end

-- Handlers addon-to-addon (Sync.lua est chargé avant ce bloc).
if RT_Sync_Register then
    -- Quelqu'un demande les spés → on répond avec la nôtre (ciblé).
    RT_Sync_Register("SPECREQ", function(sender)
        local cls, spec = RT3_DetectMySpec()
        local me = UnitName and UnitName("player") or ""
        if spec and me ~= "" and RT_Sync_Whisper then
            RT_Sync_Whisper(sender, "SPEC", me, cls or "", spec)
        end
    end)
    -- On reçoit la spé d'un joueur → on l'enregistre.
    RT_Sync_Register("SPEC", function(sender, pname, pclass, pspec)
        if pname and pname ~= "" and pspec and pspec ~= "" then
            RT3_SetPlayerSpec(pname, pclass, pspec)
        end
    end)
end

RT_V3_COMPAT_LOADED = true

-- [v3:Store]
-- RT v3 - Store.lua (racine)
RT.Store = RT.Store or {}

local _subs = {}

function RT.Store.Subscribe(topic, fn)
    _subs[topic] = _subs[topic] or {}
    table.insert(_subs[topic], fn)
end

function RT.Store.Notify(topic)
    local list = _subs[topic]
    if not list then return end
    for i = 1, table.getn(list) do
        local ok, err = pcall(list[i])
        if not ok then RT.Print("|cffFF4444[store:" .. tostring(topic) .. "] " .. tostring(err) .. "|r") end
    end
end

function RT.Store.DB()
    RT_DB = RT_DB or {}
    return RT_DB
end

function RT.Store.Roster()
    local db = RT.Store.DB()
    db.roster = db.roster or {}
    return db.roster
end

function RT.Store.Loot()
    local db = RT.Store.DB()
    db.loot = db.loot or {}
    return db.loot
end

function RT.Store.Attendance()
    local db = RT.Store.DB()
    db.attendance = db.attendance or {}
    return db.attendance
end

-- [v3:UIKit]
-- RT v3 - UIKit.lua (racine)
RT.UI = RT.UI or {}

local BACKDROP = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

function RT.UI.ApplyBackdrop(frame, r, g, b, a)
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(r or 0.05, g or 0.05, b or 0.08, a or 0.92)
    frame:SetBackdropBorderColor(0.62, 0.50, 0.18, 0.85)
end

local function applyAnchor(frame, anchor)
    if not anchor then return end
    frame:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4] or 0, anchor[5] or 0)
end

-- Remonte la chaîne de parents pour trouver le ScrollFrame et forwarder la molette.
-- Utilisé par les boutons qui bloqueraient sinon la propagation en WoW 1.12.
function RT3_FwdWheel(frame, delta)
    local p = frame:GetParent()
    while p do
        local ok, tp = pcall(p.GetObjectType, p)
        if ok and tp == "ScrollFrame" then
            local cur  = p:GetVerticalScroll()
            local maxS = p:GetVerticalScrollRange()
            local new  = cur - (delta or 0) * 24
            if new < 0    then new = 0    end
            if new > maxS then new = maxS end
            p:SetVerticalScroll(new)
            return
        end
        local ok2, par = pcall(p.GetParent, p)
        if not ok2 then return end
        p = par
    end
end

function RT.UI.Label(parent, opts)
    opts = opts or {}
    local fs = parent:CreateFontString(opts.name, "OVERLAY", opts.font or "GameFontNormal")
    fs:SetText(opts.text or "")
    if opts.color   then fs:SetTextColor(opts.color[1], opts.color[2], opts.color[3]) end
    if opts.width   then fs:SetWidth(opts.width) end
    if opts.justify then fs:SetJustifyH(opts.justify) end
    applyAnchor(fs, opts.anchor)
    return fs
end

function RT.UI.Button(parent, opts)
    opts = opts or {}
    local b = CreateFrame("Button", opts.name, parent, "UIPanelButtonTemplate")
    b:SetWidth(opts.width or 100)
    b:SetHeight(opts.height or 22)
    b:SetText(opts.text or "")
    if opts.onClick then b:SetScript("OnClick", opts.onClick) end
    if opts.color then
        local tex = b:GetNormalTexture()
        if tex then tex:SetVertexColor(opts.color[1], opts.color[2], opts.color[3]) end
    end
    if opts.tooltip and RT_AttachSimpleTooltip then
        RT_AttachSimpleTooltip(b, opts.tooltip)
    end
    -- Forwarding molette : les boutons bloquent la propagation en WoW 1.12
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel", function() RT3_FwdWheel(this, arg1) end)
    applyAnchor(b, opts.anchor)
    return b
end

function RT.UI.Panel(parent, opts)
    opts = opts or {}
    local p = CreateFrame("Frame", opts.name, parent)
    applyAnchor(p, opts.anchor)
    if opts.width  then p:SetWidth(opts.width) end
    if opts.height then p:SetHeight(opts.height) end
    if opts.backdrop ~= false then
        RT.UI.ApplyBackdrop(p, opts.r, opts.g, opts.b, opts.a)
    end
    return p
end

function RT.UI.ScrollArea(parent, opts)
    opts = opts or {}
    local scroll = CreateFrame("ScrollFrame", opts.name, parent, "UIPanelScrollFrameTemplate")
    applyAnchor(scroll, opts.anchor)
    if opts.width  then scroll:SetWidth(opts.width) end
    if opts.height then scroll:SetHeight(opts.height) end
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(opts.childWidth or opts.width or 600)
    child:SetHeight(1)
    scroll:SetScrollChild(child)
    scroll.child = child

    local function doScroll(sf, delta)
        local cur  = sf:GetVerticalScroll()
        local maxS = sf:GetVerticalScrollRange()
        local new  = cur - (delta or 0) * 24
        if new < 0    then new = 0    end
        if new > maxS then new = maxS end
        sf:SetVerticalScroll(new)
    end

    -- Scroll frame reçoit la molette (hors contenu)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function() doScroll(this, arg1) end)

    -- Child forwarde aussi : les frames enfants avec EnableMouse bloquent
    -- la propagation de la molette vers le scroll parent en WoW 1.12.
    child:EnableMouseWheel(true)
    child:SetScript("OnMouseWheel", function() doScroll(this:GetParent(), arg1) end)

    return scroll, child
end

function RT.UI.TextScroll(parent, opts)
    opts = opts or {}
    local w = opts.width or 600
    local scroll, child = RT.UI.ScrollArea(parent, {
        name = opts.name, anchor = opts.anchor, childWidth = w,
    })
    if opts.width  then scroll:SetWidth(w) end
    if opts.height then scroll:SetHeight(opts.height) end
    local fs = child:CreateFontString(
        opts.name and (opts.name .. "Text") or nil,
        "OVERLAY", opts.font or "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -4)
    fs:SetWidth(w - 24)
    fs:SetJustifyH("LEFT")
    fs:SetText("")
    local api = { scroll = scroll, child = child, fs = fs }
    function api:SetText(t)
        self.fs:SetText(t or "")
        self.child:SetHeight((self.fs:GetHeight() or 1) + 20)
        local f2, c2 = self.fs, self.child
        RT.After(0, function() c2:SetHeight((f2:GetHeight() or 1) + 20) end)
    end
    return api
end

function RT.UI.List(parent, opts)
    opts = opts or {}
    local rowH    = opts.rowHeight or 18
    local gap     = opts.gap or 2
    local makeRow = opts.makeRow
    local fillRow = opts.fillRow
    local list = CreateFrame("Frame", opts.name, parent)
    list._pool = {}
    function list:SetItems(items)
        local n = table.getn(items)
        for i = 1, n do
            local row = self._pool[i]
            if not row then
                row = makeRow(self)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT",  self, "TOPLEFT",  0, -((i-1)*(rowH+gap)))
                row:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -((i-1)*(rowH+gap)))
                self._pool[i] = row
            end
            fillRow(row, items[i], i)
            row:Show()
        end
        for i = n + 1, table.getn(self._pool) do
            self._pool[i]:Hide()
        end
        self:SetHeight(n * (rowH + gap) + 4)
    end
    return list
end

-- [v3:Registry]
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
    stTitle:SetText("|cffFFD700Settings|r")

    -- Tooltips
    local stTipLbl = settPanel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    stTipLbl:SetPoint("TOPLEFT", settPanel, "TOPLEFT", 10, -28)
    stTipLbl:SetText("Tooltips:")
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
    stLangLbl:SetText("Language:")
    local stLangInfo = settPanel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    stLangInfo:SetPoint("TOPLEFT", settPanel, "TOPLEFT", 90, -52)
    stLangInfo:SetText("|cff888888EN / FR — soon|r")

    -- Séparateur WhisperBot
    local stWBsep = settPanel:CreateTexture(nil,"BACKGROUND")
    stWBsep:SetPoint("TOPLEFT", settPanel, "TOPLEFT", 8, -68)
    stWBsep:SetPoint("TOPRIGHT", settPanel, "TOPRIGHT", -8, -68)
    stWBsep:SetHeight(1) stWBsep:SetTexture(0.4,0.4,0.6,0.4)
    local stWBLbl = settPanel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    stWBLbl:SetPoint("TOPLEFT", settPanel, "TOPLEFT", 10, -74)
    stWBLbl:SetText("|cff99AAFFAuto whisper (WhisperBot)|r")

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

    makeWBField("Intro:",  "wp_intro", -90)
    makeWBField("Role:",   "wp_role",  -110)
    makeWBField("Group:",  "wp_group", -130)

    local stClose = RT.UI.Button(settPanel, {
        text="Close", width=68, height=18,
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
    if RT_AttachSimpleTooltip then RT_AttachSimpleTooltip(gearBtn, "Addon settings") end

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
            RT.Print("|cffFFAA00[RT3] No module registered.|r")
        end
    end
end



RT.Events({ "VARIABLES_LOADED" }, function()
    local n = table.getn(_mods)
    RT.Print("|cff44FF88v3 charge|r - /rt v3 pour ouvrir (" .. n .. " modules)")
end)

-- [v3:ModDash]
-- ============================================================
-- RT v3 — modules/Dashboard.lua
-- Le command center : agrège l'état du raid et offre les actions
-- clés en un écran. C'est la pièce maîtresse qui rend RT unique.
--
-- N'invente pas de données : lit le roster, RT_AA_LAST, RT_BOSS_STATE,
-- et appelle les pipelines v2 existants (PackPUG, PullTimer, Tactics).
-- ============================================================

local function rosterCounts()
    local t, h, d, total = 0, 0, 0, 0
    for _, data in pairs(RT.Store.Roster()) do
        total = total + 1
        local r = RT.NormRole(data.role or "")
        if r == "Tank" then t = t + 1
        elseif r == "Heal" then h = h + 1
        else d = d + 1 end
    end
    return t, h, d, total
end

local function fmtStatus()
    local L = {}
    local function add(s) table.insert(L, s) end

    -- État du raid
    local nRaid = (GetNumRaidMembers and GetNumRaidMembers()) or 0
    local nParty = (GetNumPartyMembers and GetNumPartyMembers()) or 0
    add("|cffFFD700» RAID STATUS|r")
    if nRaid > 0 then
        add("  |cff44FF44En raid|r : " .. nRaid .. "/40 membres")
    elseif nParty > 0 then
        add("  |cffFFAA00In party|r: " .. (nParty + 1) .. "/5")
    else
        add("  |cff888888Solo (pas en raid)|r")
    end

    -- Composition du roster
    local t, h, d, total = rosterCounts()
    add(" ")
    add("|cffFFD700» ROSTER|r")
    if total == 0 then
        add("  |cff888888empty — scan the raid (Roster tab) or import|r")
    else
        add(string.format("  |cff3399FF%d Tanks|r   |cff33FF33%d Heals|r   |cffFF4D4D%d DPS|r   |cff888888(%d total)|r", t, h, d, total))
    end

    -- Boss courant
    local boss = RT_BOSS_STATE and RT_BOSS_STATE.bossName or ""
    add(" ")
    add("|cffFFD700» CURRENT BOSS|r")
    if boss ~= "" then
        add("  |cffFF7D0A" .. boss .. "|r")
    else
        add("  |cff888888no boss selected (Boss v2 tab)|r")
    end

    -- Résumé de la dernière attribution
    add(" ")
    add("|cffFFD700» ASSIGNMENTS|r")
    if RT_AA_LAST and RT_AA_LAST.tanks and table.getn(RT_AA_LAST.tanks) > 0 then
        local tk = RT_AA_LAST.tanks
        for i = 1, table.getn(tk) do
            local mk = RT_AA_LAST.tankMarkers and RT_AA_LAST.tankMarkers[i] or ""
            local tag = mk ~= "" and ("|cffFFD700[" .. mk .. "]|r ") or ""
            local heal = RT_AA_LAST.healTank and RT_AA_LAST.healTank[i]
            local healTxt = (heal and heal ~= "") and ("  <-  |cff88FF88" .. heal .. "|r") or ""
            add("  " .. tag .. "MT" .. i .. " : " .. tk[i] .. healTxt)
        end
    else
        add("  |cff888888aucune — utilise les actions ci-dessous|r")
    end

    return table.concat(L, "\n")
end

RT.Modules.Register({
    id       = "dash",
    title    = "Dashboard",
    tip      = "Raid overview: headcount, status, shortcuts. The starting point.",
    color    = { 0.70, 0.55, 1.00 },
    tabWidth = 90,

    build = function(panel)
        RT.UI.Label(panel, {
            text = "|cffAA66FFCommand Center|r  —  your raid at a glance",
            font = "GameFontNormalLarge",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -10 },
        })

        -- ── Actions rapides ──
        RT.UI.Button(panel, {
            text = "Compute (Guild)", width = 140, height = 24,
            color = { 0.40, 1.00, 0.60 },
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -40 },
            onClick = function()
                if RT_AA_PackGuild then RT_AA_PackGuild() end
                if panel._status then panel._status:SetText(fmtStatus()) end
            end,
            tooltip = "Analyse le roster et calcule toutes les attributions (sans annoncer).",
        })
        RT.UI.Button(panel, {
            text = "PUG Pack", width = 120, height = 24,
            color = { 0.40, 0.70, 1.00 },
            anchor = { "TOPLEFT", panel, "TOPLEFT", 158, -40 },
            onClick = function()
                if RT_AA_PackPUG then RT_AA_PackPUG() end
                if panel._status then panel._status:SetText(fmtStatus()) end
            end,
            tooltip = "Compute + announce to raid + whisper each player their assignment.",
        })
        RT.UI.Button(panel, {
            text = "Pull 10s", width = 100, height = 24,
            color = { 1.00, 0.55, 0.20 },
            anchor = { "TOPLEFT", panel, "TOPLEFT", 284, -40 },
            onClick = function()
                if RT_PT then RT_PT.Start(10, nil, true) end
            end,
            tooltip = "Starts a 10s pull countdown, visible to the whole raid.",
        })
        RT.UI.Button(panel, {
            text = "Announce strat", width = 120, height = 24,
            anchor = { "TOPLEFT", panel, "TOPLEFT", 390, -40 },
            onClick = function()
                local boss = RT_BOSS_STATE and RT_BOSS_STATE.bossName or ""
                if boss ~= "" and RT_Tactics then RT_Tactics.Post(boss, "RAID")
                else RT.Print("|cffFFAA00No boss selected.|r") end
            end,
            tooltip = "Posts the current boss tactic to the raid channel.",
        })

        -- ── Bloc d'état ──
        local status = RT.UI.TextScroll(panel, {
            name = "RT3_DashStatus",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 8, -76 },
            width = 690, font = "GameFontHighlightSmall",
        })
        status.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)
        panel._status = status

        -- Refresh auto toutes les 2s tant que le dashboard est visible
        RT.Every(2, function()
            if panel:IsVisible() and panel._status then
                panel._status:SetText(fmtStatus())
            end
        end)

        -- Et réactif au roster
        RT.Store.Subscribe("roster", function()
            if panel:IsShown() and panel._status then panel._status:SetText(fmtStatus()) end
        end)
    end,

    show = function(panel)
        if panel._status then panel._status:SetText(fmtStatus()) end
    end,
})

-- [v3:Roster]
-- ============================================================
-- RT v3 — modules/Roster.lua
-- MODULE PILOTE. Démontre toute la stack v3 :
--   • lit le MÊME RT_DB.roster que v2 (zéro duplication)
--   • UI déclarative via RT.UI (aucun pixel codé en dur au hasard)
--   • liste à pool de lignes (RT.UI.List) → pas de fuite de frames
--   • réactif : s'abonne à "roster", se redessine seul au changement
--   • scan du raid + cycle de rôle qui écrivent dans le store partagé
-- ============================================================

-- Cycle de rôle au clic : Tank → Heal → DPS → Melee → Ranged → Tank
local ROLE_CYCLE = {
    ["Tank"] = "Heal", ["Heal"] = "DPS", ["DPS"] = "Melee",
    ["Melee"] = "Ranged", ["Ranged"] = "Tank",
}

-- Cycle de spec par classe (clé = classe uppercase)
local SPEC_LISTS = {
    WARRIOR = {"Prot","Fury","Arms"},
    PALADIN = {"Holy","Prot","Retri"},
    DRUID   = {"Resto","Feral","Balance"},
    PRIEST  = {"Holy","Disc","Shadow"},
    SHAMAN  = {"Resto","Enh","Elem"},
    ROGUE   = {"Combat","Assa","Subt"},
    MAGE    = {"Fire","Frost","Arcane"},
    WARLOCK = {"Affli","Destro","Demo"},
    HUNTER  = {"BM","MM","Surv"},
}
-- Expose pour les autres modules (v3Groups)
RT3_SPEC_LISTS = SPEC_LISTS

-- Construit la liste triée, avec filtre optionnel (nom partiel + rôle)
local function buildItems(nameFilter, roleFilter)
    local db  = RT.Store.Roster()
    local nf  = nameFilter and string.lower(nameFilter) or nil
    local rf  = (roleFilter and roleFilter ~= "All") and roleFilter or nil
    local items = {}
    for name, data in pairs(db) do
        local role = RT.NormRole(data.role or "")
        if rf and role ~= rf then
            -- filtré par rôle : skip
        elseif nf and nf ~= "" and not string.find(string.lower(name), nf, 1, true) then
            -- filtré par nom : skip
        else
            table.insert(items, { name=name, class=data.class or "?", spec=data.spec or "", role=role })
        end
    end
    local order = { Tank=1, Heal=2, DPS=3, Melee=4, Ranged=5 }
    table.sort(items, function(a, b)
        local ra = order[a.role] or 6
        local rb = order[b.role] or 6
        if ra ~= rb then return ra < rb end
        return a.name < b.name
    end)
    return items
end

-- Scanne le raid réel. prune=true → retire aussi les absents (sync complet,
-- bouton "Scanner le raid"). prune=false → ajout seulement (auto à l'ouverture,
-- ne détruit pas un roster importé de gens pas encore en raid).
local function scanRaid(prune)
    local db = RT.Store.Roster()
    local n = (GetNumRaidMembers and GetNumRaidMembers()) or 0
    if n == 0 then
        if prune then RT.Print("|cffFFAA00You're not in a raid.|r") end
        return
    end
    local present = {}
    local added = 0
    for i = 1, n do
        local name, _, _, _, class = GetRaidRosterInfo(i)
        if name and name ~= "" then
            present[name] = true
            if not db[name] then added = added + 1 end
            db[name] = db[name] or {}
            db[name].class = RT.NormClass(class) ~= "" and RT.NormClass(class) or db[name].class
        end
    end
    local removed = 0
    if prune then
        local toRemove = {}
        for name in pairs(db) do
            if not present[name] then table.insert(toRemove, name) end
        end
        for i = 1, table.getn(toRemove) do db[toRemove[i]] = nil end
        removed = table.getn(toRemove)
        RT.Print("Scan: " .. n .. " present, " .. added .. " new, " .. removed .. " removed.")
    elseif added > 0 then
        RT.Print("Scan: " .. added .. " player(s) added from the raid.")
    end
    RT.Store.Notify("roster")
end
-- Accessible depuis les autres modules (Assign "Setup Raid") : ajout seul
RT.ScanRaid = scanRaid

-- Remplit le roster avec un raid de TEST (40 joueurs fictifs) pour
-- dérouler tout le flux Assign/Groupes/Boss sans être en raid.
local function fillDemoRoster()
    local demo = {
        -- Tanks (4)
        {"Tankalor",  "Warrior","Prot",   "Tank"},
        {"Bouclair",  "Warrior","Prot",   "Tank"},
        {"Oursdur",   "Druid",  "Feral",  "Tank"},
        {"Sacretank", "Paladin","Prot",   "Tank"},
        -- Soigneurs (10)
        {"Lumina",    "Paladin","Holy",   "Heal"},
        {"Sacrelux",  "Paladin","Holy",   "Heal"},
        {"Benisseur", "Paladin","Holy",   "Heal"},
        {"Espoir",    "Priest", "Holy",   "Heal"},
        {"Discret",   "Priest", "Disc",   "Heal"},
        {"Soigna",    "Priest", "Holy",   "Heal"},
        {"Sylvana",   "Druid",  "Resto",  "Heal"},
        {"Feuille",   "Druid",  "Resto",  "Heal"},
        {"Totemar",   "Shaman", "Resto",  "Heal"},
        {"Vague",     "Shaman", "Resto",  "Heal"},
        -- Mêlée DPS (13)
        {"Lamefurie", "Warrior","Fury",   "Melee"},
        {"Berserk",   "Warrior","Arms",   "Melee"},
        {"Furax",     "Warrior","Fury",   "Melee"},
        {"Dague",     "Rogue",  "Combat", "Melee"},
        {"Ombrelame", "Rogue",  "Assa",   "Melee"},
        {"Poignard",  "Rogue",  "Combat", "Melee"},
        {"Furtif",    "Rogue",  "Subt",   "Melee"},
        {"Tonnerre",  "Shaman", "Enh",    "Melee"},
        {"Foudrelame","Shaman", "Enh",    "Melee"},
        {"Griffe",    "Druid",  "Feral",  "Melee"},
        {"Croc",      "Druid",  "Feral",  "Melee"},
        {"Retripala", "Paladin","Retri",  "Melee"},
        {"Martelia",  "Paladin","Retri",  "Melee"},
        -- Distance / Casters DPS (13)
        {"Givrette",    "Mage",    "Frost",   "Ranged"},
        {"Flammeche",   "Mage",    "Fire",    "Ranged"},
        {"Arcaniss",    "Mage",    "Arcane",  "Ranged"},
        {"Pyro",        "Mage",    "Fire",    "Ranged"},
        {"Demonia",     "Warlock", "Affli",   "Ranged"},
        {"Vilebroke",   "Warlock", "Destro",  "Ranged"},
        {"Pactombre",   "Warlock", "Demo",    "Ranged"},
        {"Fleche",      "Hunter",  "MM",      "Ranged"},
        {"Pisteur",     "Hunter",  "BM",      "Ranged"},
        {"Traqueur",    "Hunter",  "Surv",    "Ranged"},
        {"Ombrepretre", "Priest",  "Shadow",  "Ranged"},
        {"Lunaire",     "Druid",   "Balance", "Ranged"},
        {"Ventfroid",   "Shaman",  "Ele",     "Ranged"},
    }
    local db = RT.Store.Roster()
    for i = 1, table.getn(demo) do
        local d = demo[i]
        db[d[1]] = { class=d[2], spec=d[3], role=d[4], sr=0 }
    end
    RT.Print("|cff44FF88Demo roster: " .. table.getn(demo) .. " fake players added.|r")
    RT.Store.Notify("roster")
end

RT.Modules.Register({
    id       = "roster",
    title    = "Roster",
    tip      = "Your raid members. Import (raidres), scan the raid, set role/spec in one click. 'Demo' to test.",
    color    = { 0.60, 0.85, 1.00 },
    tabWidth = 72,

    build = function(panel)
        -- En-tête : compteurs (gauche) + boutons (droite)
        local counts = RT.UI.Label(panel, {
            name = "RT3_RosterCounts", font = "GameFontNormal",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -10 },
        })

        RT.UI.Button(panel, {
            text = "Scan raid", width = 120, height = 22,
            color = { 0.40, 1.00, 0.60 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -12, -8 },
            onClick = function() scanRaid(true) end,
            tooltip = "Syncs the roster with the current raid: adds present members AND removes absent ones.",
        })
        RT.UI.Button(panel, {
            text = "Import", width = 96, height = 22,
            color = { 0.30, 0.55, 0.90 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -140, -8 },
            onClick = function()
                if panel._impPanel then
                    if panel._impPanel:IsShown() then panel._impPanel:Hide()
                    else panel._impPanel:Show(); if panel._impEB then panel._impEB:SetFocus() end end
                end
            end,
            tooltip = "Paste a raidres (CSV) or softres (JSON) export to fill the roster.",
        })
        RT.UI.Button(panel, {
            text = "Clear", width = 64, height = 22,
            color = { 0.55, 0.15, 0.10 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -244, -8 },
            onClick = function()
                local db = RT.Store.Roster()
                local names = {}
                for nm in pairs(db) do table.insert(names, nm) end
                for i = 1, table.getn(names) do db[names[i]] = nil end
                RT.Print("Roster cleared.")
                RT.Store.Notify("roster")
            end,
            tooltip = "Clears the entire roster.",
        })
        RT.UI.Button(panel, {
            text = "Demo", width = 60, height = 22,
            color = { 0.45, 0.30, 0.55 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -316, -8 },
            onClick = fillDemoRoster,
            tooltip = "TEST: fills the roster with a fake 40-player raid to try Assign/Groups/Boss without being in a raid.",
        })
        RT.UI.Button(panel, {
            text = "Auto-roles", width = 80, height = 22,
            color = { 0.20, 0.65, 0.35 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -384, -8 },
            tooltip = "Fills missing classes from specs (Holy1=Paladin...), sets each player's role from their spec, and requests the spec of anyone still missing one (RaidTools users reply silently, others by whisper).",
            onClick = function()
                if not RT3_RoleFromSpec then
                    RT.Print("|cffFF4444RT3_RoleFromSpec not loaded.|r") return
                end
                -- Passe 1 : classes déduites des spés + spés normalisées + rôles vides/DPS
                local fixedCls = 0
                if RT3_AutofixRoster then fixedCls = RT3_AutofixRoster() end
                -- Passe 2 : force le rôle depuis la spé pour tout le monde
                local db = RT.Store.Roster()
                local changed, missing = 0, 0
                for name, data in pairs(db) do
                    if not data.spec or data.spec == "" then
                        missing = missing + 1
                    else
                        local role = RT3_RoleFromSpec(data.class or "", data.spec or "")
                        if role then
                            data.role = role
                            changed = changed + 1
                        end
                    end
                end
                if changed > 0 or fixedCls > 0 then RT.Store.Notify("roster") end
                local clsTxt = fixedCls > 0 and (fixedCls .. " class(es) detected, ") or ""
                if missing > 0 then
                    RT.Print("|cff44FF88Auto-roles: " .. clsTxt .. changed .. " role(s) set ; requesting " .. missing .. " missing spec(s)...|r")
                    if RT3_AskSpecs then RT3_AskSpecs(true)
                    else RT.Print("|cffFFAA00(WhisperBot module not loaded yet — open that tab once to activate.)|r") end
                elseif changed > 0 then
                    RT.Print("|cff44FF88Auto-roles: " .. clsTxt .. changed .. " player(s) updated (all specs known).|r")
                else
                    RT.Print("|cffFFAA00Auto-roles: roster empty — scan or import the raid first.|r")
                end
            end,
        })

        -- Barre de recherche + filtres par rôle
        panel._nameFilter = ""
        panel._roleFilter = nil

        -- Forward-declaration : les closures des boutons capturent la référence
        -- directement — pas de lookup panel._refresh au moment du clic.
        local doRefresh  -- sera assigné plus bas

        local searchLabel = panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        searchLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -36)
        searchLabel:SetText("|cff888888Search:|r")

        local searchEB = CreateFrame("EditBox", "RT3_RosterSearch", panel, "InputBoxTemplate")
        searchEB:SetPoint("TOPLEFT", panel, "TOPLEFT", 86, -34)
        searchEB:SetWidth(130) searchEB:SetHeight(16) searchEB:SetAutoFocus(false)
        searchEB:SetScript("OnTextChanged", function()
            panel._nameFilter = this:GetText() or ""
            if doRefresh then doRefresh() end
        end)
        searchEB:SetScript("OnEscapePressed", function()
            this:SetText("") this:ClearFocus()
            panel._nameFilter = ""
            if doRefresh then doRefresh() end
        end)
        searchEB:EnableMouseWheel(true)
        searchEB:SetScript("OnMouseWheel", function() RT3_FwdWheel(this, arg1) end)

        -- Boutons filtres rôle
        local FILT_ROLES = { nil, "Tank", "Heal", "DPS", "Melee", "Ranged" }
        local FILT_TEXTS = { "All", "Tank", "Heal", "DPS", "Melee", "Ranged" }
        local filtBtns = {}
        for fi = 1, 6 do
            local fb = RT.UI.Button(panel, {
                text = FILT_TEXTS[fi], width = 56, height = 16,
                anchor = {"TOPLEFT", panel, "TOPLEFT", 222 + (fi-1)*59, -34},
            })
            filtBtns[fi] = fb
        end
        -- Assigner les handlers APRÈS (évite les problèmes de capture en boucle)
        for fi = 1, 6 do
            local fRole = FILT_ROLES[fi]
            local selfBtn = filtBtns[fi]
            selfBtn:SetScript("OnClick", function()
                panel._roleFilter = fRole
                -- Reset couleur tous les boutons
                for bi = 1, 6 do
                    local tx = filtBtns[bi]:GetNormalTexture()
                    if tx then tx:SetVertexColor(1,1,1) end
                end
                -- Surligner le bouton actif
                local tx = selfBtn:GetNormalTexture()
                if tx then tx:SetVertexColor(0.3,0.85,0.3) end
                if doRefresh then doRefresh() end
            end)
        end
        -- Marquer "Tous" actif par défaut
        local txAll = filtBtns[1]:GetNormalTexture()
        if txAll then txAll:SetVertexColor(0.3,0.85,0.3) end

        -- En-tête de colonnes (décalés de 24px vers le bas)
        RT.UI.Label(panel, { text = "Player", font = "GameFontDisable", anchor = { "TOPLEFT", panel, "TOPLEFT", 16, -56 } })
        RT.UI.Label(panel, { text = "Spec",   font = "GameFontDisable", anchor = { "TOPLEFT", panel, "TOPLEFT", 230, -56 } })
        RT.UI.Label(panel, { text = "Role",   font = "GameFontDisable", anchor = { "TOPLEFT", panel, "TOPLEFT", 400, -56 } })

        -- Zone scrollable + liste à pool (décalée de 24px)
        local scroll, child = RT.UI.ScrollArea(panel, {
            name = "RT3_RosterScroll",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 8, -72 },
            childWidth = 640,
        })
        scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)

        local list = RT.UI.List(child, {
            rowHeight = 18, gap = 2,
            makeRow = function(l)
                local row = CreateFrame("Frame", nil, l)
                row:SetHeight(18)
                row.nameFS = RT.UI.Label(row, {
                    font = "GameFontNormalSmall", width = 200, justify = "LEFT",
                    anchor = { "LEFT", row, "LEFT", 8, 0 },
                })
                row.specFS = RT.UI.Label(row, {
                    font = "GameFontHighlightSmall", width = 165, justify = "LEFT",
                    anchor = { "LEFT", row, "LEFT", 222, 0 },
                })
                -- Invisible click frame on top of spec label
                row._specBtn = CreateFrame("Button", nil, row)
                row._specBtn:SetWidth(160) row._specBtn:SetHeight(18)
                row._specBtn:SetPoint("LEFT", row, "LEFT", 222, 0)
                row._specBtn:EnableMouse(true)
                row._specBtn:EnableMouseWheel(true)
                row._specBtn:SetScript("OnMouseWheel", function() RT3_FwdWheel(this, arg1) end)
                row.roleBtn = RT.UI.Button(row, {
                    width = 70, height = 16,
                    anchor = { "LEFT", row, "LEFT", 392, 0 },
                })
                row.delBtn = RT.UI.Button(row, {
                    text = "X", width = 20, height = 16,
                    color = { 0.55, 0.15, 0.10 },
                    anchor = { "LEFT", row, "LEFT", 470, 0 },
                    tooltip = "Remove this player from the roster.",
                })
                return row
            end,
            fillRow = function(row, item)
                row.nameFS:SetText(item.name)
                row.nameFS:SetTextColor(RT.ClassColor(item.class))

                row.specFS:SetText(item.spec ~= "" and item.spec or "|cff666666—|r")

                local nm = item.name
                -- Spec : clic → menu déroulant des specs de la classe
                row._specBtn:SetScript("OnClick", function()
                    local db = RT.Store.Roster()
                    db[nm] = db[nm] or {}
                    local cls   = string.upper(db[nm].class or "")
                    local specs = SPEC_LISTS[cls] or {"?"}
                    local opts  = {}
                    for i = 1, table.getn(specs) do opts[i] = { label = specs[i] } end
                    if panel._showMenu then
                        panel._showMenu(row._specBtn, opts, function(val)
                            db[nm].spec = val
                            RT.Store.Notify("roster")
                        end)
                    end
                end)

                row.roleBtn:SetText(item.role)
                local fs = row.roleBtn:GetFontString()
                if fs then fs:SetTextColor(RT.RoleColor(item.role)) end

                -- Rôle : clic → menu déroulant (Tank / Heal / DPS / Melee / Ranged)
                row.roleBtn:SetScript("OnClick", function()
                    if not panel._showMenu then return end
                    panel._showMenu(row.roleBtn, {
                        { label = "Tank",   color = { RT.RoleColor("Tank")   } },
                        { label = "Heal",   color = { RT.RoleColor("Heal")   } },
                        { label = "DPS",    color = { RT.RoleColor("DPS")    } },
                        { label = "Melee",  color = { RT.RoleColor("Melee")  } },
                        { label = "Ranged", color = { RT.RoleColor("Ranged") } },
                    }, function(val)
                        local db = RT.Store.Roster()
                        db[nm] = db[nm] or {}
                        db[nm].role = val
                        RT.Store.Notify("roster")
                    end)
                end)

                row.delBtn:SetScript("OnClick", function()
                    local db = RT.Store.Roster()
                    db[nm] = nil
                    RT.Store.Notify("roster")
                end)
            end,
        })
        list:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
        list:SetWidth(630)
        panel._list = list

        -- ── Menu déroulant partagé (rôle / spec) ──────────────────
        local menu = CreateFrame("Frame", "RT3_RosterMenu", panel)
        RT.UI.ApplyBackdrop(menu, 0.06, 0.06, 0.12, 0.98)
        menu:SetFrameStrata("TOOLTIP")
        menu:Hide()
        menu._btns = {}
        menu._anchor = nil
        panel._showMenu = function(anchorBtn, options, onPick)
            -- re-clic sur le même bouton : referme
            if menu:IsShown() and menu._anchor == anchorBtn then
                menu:Hide(); menu._anchor = nil; return
            end
            local n = table.getn(options)
            menu:SetWidth(84)
            menu:SetHeight(n * 18 + 4)
            for i = 1, n do
                local b = menu._btns[i]
                if not b then
                    b = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
                    b:SetWidth(80) b:SetHeight(17)
                    b:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i-1)*18)
                    menu._btns[i] = b
                end
                b:SetText(options[i].label)
                local bfs = b:GetFontString()
                if bfs then
                    local c = options[i].color
                    if c then bfs:SetTextColor(c[1], c[2], c[3]) else bfs:SetTextColor(1,1,1) end
                end
                local val = options[i].label
                b:SetScript("OnClick", function() menu:Hide(); menu._anchor = nil; onPick(val) end)
                b:Show()
            end
            for i = n + 1, table.getn(menu._btns) do menu._btns[i]:Hide() end
            menu:ClearAllPoints()
            menu:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -1)
            menu._anchor = anchorBtn
            menu:Show()
        end

        -- Refresh : recalcule items + compteurs. Branché au store et aux filtres.
        -- doRefresh (forward-declared) pointe ici pour que les boutons filtres
        -- puissent l'appeler sans passer par panel._refresh.
        local function refresh()
            local items = buildItems(panel._nameFilter, panel._roleFilter)
            list:SetItems(items)
            child:SetHeight(list:GetHeight() or 1)

            local t, h, d, m, r = 0, 0, 0, 0, 0
            for i = 1, table.getn(items) do
                local rl = items[i].role
                if     rl == "Tank"   then t = t + 1
                elseif rl == "Heal"   then h = h + 1
                elseif rl == "DPS"    then d = d + 1
                elseif rl == "Melee"  then m = m + 1
                elseif rl == "Ranged" then r = r + 1 end
            end
            counts:SetText(string.format(
                "|cff3399FF%dT|r |cff33FF33%dH|r |cffFF4D4D%dD|r |cffFF8800%dM|r |cff22CCFF%dR|r |cff888888(%d)|r",
                t, h, d, m, r, table.getn(items)))
        end
        doRefresh      = refresh   -- branche la forward-declaration
        panel._refresh = refresh
        RT.Store.Subscribe("roster", refresh)

        -- ── Overlay d'import (raidres CSV / softres JSON) ─────────
        local imp = CreateFrame("Frame", "RT3_RosterImport", panel)
        imp:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -38)
        imp:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
        RT.UI.ApplyBackdrop(imp, 0.04, 0.05, 0.10, 0.98)
        imp:SetFrameStrata("DIALOG")
        imp:EnableMouse(true)
        imp:Hide()
        panel._impPanel = imp

        local impTitle = imp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        impTitle:SetPoint("TOPLEFT", imp, "TOPLEFT", 10, -8)
        impTitle:SetWidth(660) impTitle:SetJustifyH("LEFT")
        impTitle:SetText("|cffFFD700Import roster|r — paste |cff88CCFFraidres CSV|r, |cff88CCFFsignups JSON|r (softres / Raid-Helper) or |cff88CCFFComp Tool JSON|r (fills the Groups too). Format is auto-detected.  (Ctrl+V)")

        -- Fond + zone de collage SCROLLABLE (le ScrollFrame découpe le texte,
        -- sinon une EditBox multiligne déborde par-dessus les boutons).
        local ebBg = imp:CreateTexture(nil, "BACKGROUND")
        ebBg:SetPoint("TOPLEFT", imp, "TOPLEFT", 10, -28)
        ebBg:SetPoint("BOTTOMRIGHT", imp, "BOTTOMRIGHT", -10, 42)
        ebBg:SetTexture(0.02, 0.02, 0.04, 0.95)

        local sf = CreateFrame("ScrollFrame", "RT3_RosterImportSF", imp)
        sf:SetPoint("TOPLEFT", imp, "TOPLEFT", 14, -30)
        sf:SetPoint("BOTTOMRIGHT", imp, "BOTTOMRIGHT", -14, 44)
        sf:EnableMouse(true)
        sf:EnableMouseWheel(true)
        sf:SetScript("OnMouseWheel", function()
            local cur  = this:GetVerticalScroll()
            local maxS = this:GetVerticalScrollRange()
            local new  = cur - (arg1 or 0) * 24
            if new < 0 then new = 0 elseif new > maxS then new = maxS end
            this:SetVerticalScroll(new)
        end)

        local eb = CreateFrame("EditBox", "RT3_RosterImportEB", sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject(GameFontHighlightSmall)
        eb:SetMaxLetters(999999)   -- évite la troncature des gros collages
        eb:SetWidth(800)
        eb:SetHeight(2000)
        eb:SetTextInsets(2, 2, 2, 2)
        eb:SetText("")
        eb:SetScript("OnEscapePressed", function() eb:ClearFocus(); imp:Hide() end)
        eb:SetScript("OnTextChanged", function() sf:UpdateScrollChildRect() end)
        sf:SetScrollChild(eb)
        sf:SetScript("OnMouseDown", function() eb:SetFocus() end)
        panel._impEB = eb

        local impStatus = imp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        impStatus:SetPoint("BOTTOMLEFT", imp, "BOTTOMLEFT", 12, 14)
        impStatus:SetWidth(420) impStatus:SetJustifyH("LEFT")

        local function doImport()
            local text = eb:GetText() or ""
            local trimmed = string.gsub(text, "^%s+", "")
            if trimmed == "" then
                impStatus:SetText("|cffFF4444Empty box — paste the export first.|r")
                return
            end
            local first = string.sub(trimmed, 1, 1)
            local fn, label
            if first == "{" or first == "[" then
                -- 3 formats JSON auto-détectés : signups (signUps) / Comp Tool (slots)
                if string.find(trimmed, '"signUps"', 1, true) then
                    fn, label = RT_ImportSoftResJSON, "Signups JSON"
                elseif string.find(trimmed, '"slots"', 1, true)
                   and string.find(trimmed, '"specName"', 1, true) then
                    fn, label = RT_ImportRaidHelperComp, "Comp Tool JSON"
                else
                    fn, label = RT_ImportSoftResJSON, "JSON"
                end
            else fn, label = RT_ImportRosterOnly, "CSV" end
            if not fn then
                impStatus:SetText("|cffFF4444" .. label .. " parser unavailable.|r")
                return
            end
            -- pcall : un plantage du parseur ne reste pas silencieux
            local pok, a, b = pcall(fn, text)
            if not pok then
                impStatus:SetText("|cffFF4444Parser error: " .. tostring(a) .. "|r")
                RT.Print("|cffFF4444[Import] Error: " .. tostring(a) .. "|r")
                return
            end
            if a then
                local msg = "Import " .. label .. ": " .. tostring(b)
                impStatus:SetText("|cff44FF88" .. msg .. "|r")
                RT.Print("|cff44FF88[Import] " .. msg .. "|r")
                eb:SetText("")
                RT.Store.Notify("roster")
                RT.Store.Notify("groups")
                imp:Hide()
            else
                impStatus:SetText("|cffFF4444Failed: " .. tostring(b) .. "|r")
                RT.Print("|cffFF4444[Import] Failed: " .. tostring(b) .. "|r")
            end
        end

        RT.UI.Button(imp, {
            text = "Confirm import", width = 130, height = 22, color = { 0.30, 0.70, 0.40 },
            anchor = { "BOTTOMRIGHT", imp, "BOTTOMRIGHT", -120, 10 },
            onClick = doImport,
        })
        RT.UI.Button(imp, {
            text = "Cancel", width = 100, height = 22, color = { 0.45, 0.20, 0.20 },
            anchor = { "BOTTOMRIGHT", imp, "BOTTOMRIGHT", -12, 10 },
            onClick = function() imp:Hide() end,
        })
    end,

    show = function(panel)
        -- Auto-scan si le joueur est dans un raid (tient le roster à jour sans clic)
        local n = (GetNumRaidMembers and GetNumRaidMembers()) or 0
        if n > 0 then scanRaid() end
        if panel._refresh then panel._refresh() end
    end,
})

-- [v3:Assign]
-- ============================================================
-- RT v3 — modules/Assign.lua
-- Surface le moteur d'attribution intelligent v2 (RT_AA).
-- C'est le joyau de l'addon : analyse le roster et attribue
-- tanks/markers, soins, groupes, buffs, bénédictions automatiquement.
--
-- Le module v3 NE réimplémente RIEN : il appelle RT_AA_Run / PackGuild
-- / PackPUG / AnnounceAll et affiche RT_AA_LAST proprement.
-- ============================================================

local function fmtAssignment(out)
    if not out then
        return "|cff888888No assignment computed.\n\nClick |cffFFD700Compute|r to analyze the roster,\nor |cff88CCFFPUG Pack|r to compute + announce + whisper each player.|r"
    end
    local L = {}
    local function add(s) table.insert(L, s) end

    -- Tanks
    add("|cffFF4D4D» TANKS|r")
    local tanks = out.tanks or {}
    if table.getn(tanks) == 0 then
        add("  |cff888888no tank in the roster|r")
    else
        for i = 1, table.getn(tanks) do
            local mk = out.tankMarkers and out.tankMarkers[i] or ""
            local tag = mk ~= "" and ("|cffFFD700[" .. mk .. "]|r ") or ""
            add("  " .. tag .. "|cffFFFFFFMT" .. i .. "|r : " .. tanks[i])
        end
    end

    -- Soins tank
    add(" ")
    add("|cff33FF33» TANK HEALS|r")
    local anyHT = false
    for ti = 1, table.getn(out.healTank or {}) do
        if out.healTank[ti] and out.healTank[ti] ~= "" then
            anyHT = true
            add("  MT" .. ti .. " (" .. (tanks[ti] or "?") .. ")  <-  |cff88FF88" .. out.healTank[ti] .. "|r")
        end
    end
    if not anyHT then add("  |cff888888no tank healer assigned|r") end

    -- Soins raid
    if table.getn(out.healRaid or {}) > 0 then
        add("  |cffAAAAAARaid:|r " .. table.concat(out.healRaid, ", "))
    end
    if out.druidNote and out.druidNote ~= "" then
        add("  |cff66CC66" .. out.druidNote .. "|r")
    end

    -- Buffs
    if table.getn(out.buffs or {}) > 0 then
        add(" ")
        add("|cff69CCF0» BUFFS|r")
        for i = 1, table.getn(out.buffs) do
            local b = out.buffs[i]
            local scope = b.scope and ("|cff888888 [" .. b.scope .. "]|r") or ""
            add("  " .. b.name .. " : |cffAACCFF" .. b.buff .. "|r" .. scope)
        end
    end

    -- Malédictions (démonistes)
    if table.getn(out.curses or {}) > 0 then
        add(" ")
        add("|cffAA44FF» CURSES|r |cff666666(1 per warlock, never at the same time)|r")
        for i = 1, table.getn(out.curses) do
            local c = out.curses[i]
            local why = c.why and ("|cff666666  " .. c.why .. "|r") or ""
            add("  |cffCC88FF" .. c.name .. "|r : " .. c.curse .. why)
        end
    end

    -- (Groupes : affichés dans l'onglet Groupes, pas ici)
    -- (Bénédictions : désactivées pour l'instant)

    return table.concat(L, "\n")
end

RT.Modules.Register({
    id       = "assign",
    title    = "Assign *",
    tip      = "The brain: computes tanks/heals/buffs/curses. 'Setup Raid' does it all, 'Announce' sends to /raid.",
    color    = { 1.00, 0.82, 0.20 },
    tabWidth = 80,

    build = function(panel)
        -- Copie l'attribution RT_AA_LAST dans le preset actif de l'onglet Groupes
        local function applyAssignToGroups()
            local out = RT_AA_LAST
            if not out or not out.groups then return end
            local db = RT.Store.DB()
            db.v3grppresets = db.v3grppresets or { active=1, presets={} }
            local pd = db.v3grppresets
            local ap = pd.active or 1
            pd.presets = pd.presets or {}
            if not pd.presets[ap] then pd.presets[ap] = { name="Assign", groups={} } end
            local preset = pd.presets[ap]
            preset.groups = preset.groups or {}
            for g = 1, 8 do
                local old_role = preset.groups[g] and preset.groups[g].role or 1
                preset.groups[g] = { names={}, role=old_role }
                local grp = out.groups[g] or {}
                for s = 1, table.getn(grp) do
                    preset.groups[g].names[s] = grp[s]
                end
            end
            RT.Store.Notify("groups")
        end

        -- Écrit un "défaut Boss" global (noms tanks ordre MT + soins) que
        -- l'onglet Boss recopie dans chaque boss à l'ouverture.
        local function applyAssignToBossDefault()
            local out = RT_AA_LAST
            if not out then return end
            local d = { tanks = {}, htank = {}, hraid = {} }
            for i = 1, table.getn(out.tanks or {}) do d.tanks[i] = out.tanks[i] or "" end
            for ti = 1, table.getn(out.healTank or {}) do d.htank[ti] = out.healTank[ti] or "" end
            for i = 1, table.getn(out.healRaid or {}) do d.hraid[i] = out.healRaid[i] or "" end
            RT.Store.DB().v3boss_default = d
            -- Force le refresh immédiat si l'onglet Boss est déjà ouvert
            if RT3_BossReload then RT3_BossReload() end
        end

        RT.UI.Label(panel, {
            text = "|cffFFD700Smart assignment|r  —  analyzes the roster and assigns everything",
            font = "GameFontNormal",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -10 },
        })

        local preview     -- forward ref
        local refreshMT   -- forward ref (zone tanks MT)

        -- copyGroups=true → recopie les groupes calculés dans le preset Groupes
        -- (Setup Raid / PUG). Calculer ne touche PAS aux groupes (préserve un
        -- "Import Raid" fait manuellement dans l'onglet Groupes).
        local function recompute(fn, copyGroups)
            local n = 0
            for _ in pairs(RT.Store.Roster()) do n = n + 1 end
            if n == 0 then
                RT.Print("|cffFFAA00Empty roster — scan the raid (Roster tab) or import.|r")
                return
            end
            if fn then fn() end
            if copyGroups then applyAssignToGroups() end
            applyAssignToBossDefault()
            if refreshMT then refreshMT() end
            if preview then preview:SetText(fmtAssignment(RT_AA_LAST)) end
        end

        -- Ligne 1 : bouton Setup Raid (1-clic pour tout faire)
        RT.UI.Button(panel, {
            text = "▶ Setup Raid", width = 126, height = 24,
            color = { 0.60, 0.30, 0.00 },
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -32 },
            onClick = function()
                -- 1. Scan si en raid
                if RT.ScanRaid then
                    local n = (GetNumRaidMembers and GetNumRaidMembers()) or 0
                    if n > 0 then RT.ScanRaid() end
                end
                -- 2. Calcule + applique (sans annoncer) + copie dans Groupes
                recompute(RT_AA_PackGuild, true)
                RT.Print("|cff88FF88[RT] Setup done — review and click Announce when ready.|r")
            end,
            tooltip = "Scan raid → compute assignment → copy groups. Does NOT announce.",
        })

        -- Ligne 1 suite : boutons individuels
        RT.UI.Button(panel, {
            text = "Compute", width = 82, height = 24,
            color = { 0.20, 0.60, 0.30 },
            anchor = { "TOPLEFT", panel, "TOPLEFT", 142, -32 },
            onClick = function() recompute(RT_AA_PackGuild, true) end,
            tooltip = "Recomputes tanks/heals/buffs/groups and applies to Boss.",
        })
        RT.UI.Button(panel, {
            text = "Announce", width = 82, height = 24,
            color = { 1.00, 0.75, 0.20 },
            anchor = { "TOPLEFT", panel, "TOPLEFT", 228, -32 },
            onClick = function()
                if RT_AA_LAST then RT_AA_AnnounceAll(RT_AA_LAST)
                else RT.Print("|cffFFAA00Calcule d'abord une attribution.|r") end
            end,
            tooltip = "Announces the last computed assignment to /raid.",
        })
        RT.UI.Button(panel, {
            text = "PUG Pack", width = 82, height = 24,
            color = { 0.40, 0.70, 1.00 },
            anchor = { "TOPLEFT", panel, "TOPLEFT", 314, -32 },
            onClick = function() recompute(RT_AA_PackPUG, true) end,
            tooltip = "Compute + copy groups + announce + whisper each player (PUG mode).",
        })
        RT.UI.Button(panel, {
            text = "Whisper all", width = 82, height = 24,
            anchor = { "TOPLEFT", panel, "TOPLEFT", 400, -32 },
            onClick = function()
                if RT_AA_LAST then RT_AA_WhisperPersonal(RT_AA_LAST)
                else RT.Print("|cffFFAA00Calcule d'abord une attribution.|r") end
            end,
            tooltip = "Whispers each player their role/group/healing.",
        })

        -- ── Zone éditable : TANKS + SOINS (attribution manuelle) ──
        local MT_MARK = { "Skull", "Cross", "Square", "Moon" }
        local helpFS = panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        helpFS:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -60)
        helpFS:SetText("|cff888888Click a filled slot = |cffFFD700select|r (green). Click another = |cffFFD700swap|r. Empty slot = type a name. Tanks → MT1 Skull · MT2 Cross · MT3 Square · MT4 Moon|r")

        local tankBoxes, htBoxes, hrBoxes = {}, {}, {}

        -- Slot sélectionné pour swap (clic-sélection, comme l'onglet Groupes)
        -- { btn, store, idx }
        local selSlot = nil

        local function slotDeselect()
            if selSlot then
                local tex = selSlot.btn:GetNormalTexture()
                if tex then tex:SetVertexColor(1, 1, 1) end
                selSlot = nil
            end
        end

        -- Crée label + 4 boutons cliquables (clic pour sélectionner/swap).
        -- Un clic sur un slot vide ouvre une popup pour saisir un nom.
        local function mkBoxes(y, labelText, color, store, isTank)
            local lb = panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            lb:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y-2)
            lb:SetWidth(54) lb:SetJustifyH("LEFT")
            lb:SetText(color..labelText.."|r")
            local boxes = {}
            for i = 1, 4 do
                local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
                btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 68 + (i-1)*134, y)
                btn:SetWidth(128) btn:SetHeight(18)
                btn:SetText("")
                local ii, ss = i, store
                btn:SetScript("OnClick", function()
                    if selSlot then
                        if selSlot.btn == btn then
                            -- Désélectionne
                            slotDeselect()
                        else
                            -- Swap les deux slots (quelle que soit la ligne)
                            local nameA = btn:GetText() or ""
                            local nameB = selSlot.btn:GetText() or ""
                            btn:SetText(nameB)
                            selSlot.btn:SetText(nameA)
                            RT_AA_LAST = RT_AA_LAST or {}
                            RT_AA_LAST[ss]            = RT_AA_LAST[ss] or {}
                            RT_AA_LAST[selSlot.store] = RT_AA_LAST[selSlot.store] or {}
                            RT_AA_LAST[ss][ii]                     = nameB
                            RT_AA_LAST[selSlot.store][selSlot.idx] = nameA
                            slotDeselect()
                            applyAssignToBossDefault()
                            if preview then preview:SetText(fmtAssignment(RT_AA_LAST)) end
                        end
                    else
                        local cur = btn:GetText() or ""
                        if cur == "" then
                            -- Slot vide : saisie manuelle via popup
                            RT3_ASSIGN_SLOT = { store=ss, idx=ii, btn=btn }
                            StaticPopup_Show("RT3_ASSIGN_ENTER")
                        else
                            -- Sélectionne ce slot (vert)
                            selSlot = { btn=btn, store=ss, idx=ii }
                            local tex = btn:GetNormalTexture()
                            if tex then tex:SetVertexColor(0.3, 0.85, 0.3) end
                        end
                    end
                end)
                boxes[i] = btn
            end
            return boxes
        end

        StaticPopupDialogs["RT3_ASSIGN_ENTER"] = {
            text        = "Enter a player name:",
            button1     = "OK",
            button2     = "Cancel",
            hasEditBox  = 1,
            OnAccept    = function()
                local name = getglobal(this:GetParent():GetName().."EditBox"):GetText()
                if RT3_ASSIGN_SLOT and name and name ~= "" then
                    local sl = RT3_ASSIGN_SLOT
                    sl.btn:SetText(name)
                    RT_AA_LAST = RT_AA_LAST or {}
                    RT_AA_LAST[sl.store] = RT_AA_LAST[sl.store] or {}
                    RT_AA_LAST[sl.store][sl.idx] = name
                    applyAssignToBossDefault()
                    if preview then preview:SetText(fmtAssignment(RT_AA_LAST)) end
                end
                RT3_ASSIGN_SLOT = nil
            end,
            OnCancel    = function() RT3_ASSIGN_SLOT = nil end,
            timeout     = 0, whileDead = 1, hideOnEscape = 1,
        }

        tankBoxes = mkBoxes(-78,  "Tanks",  "|cffFF7777", "tanks",    true)
        htBoxes   = mkBoxes(-102, "T.Heal", "|cff66DD66", "healTank", false)
        hrBoxes   = mkBoxes(-126, "S.Raid", "|cff66DD66", "healRaid", false)

        local function applySlotColor(btn, name)
            local fs = btn:GetFontString()
            if not fs then return end
            if name and name ~= "" then
                local db = RT.Store.Roster()
                local r, g, b = RT.ClassColor((db[name] or {}).class)
                fs:SetTextColor(r, g, b)
            else
                fs:SetTextColor(0.8, 0.8, 0.8)
            end
        end

        refreshMT = function()
            local L  = RT_AA_LAST or {}
            local t, ht, hr = L.tanks or {}, L.healTank or {}, L.healRaid or {}
            for i = 1, 4 do
                tankBoxes[i]:SetText(t[i] or "")
                htBoxes[i]:SetText(ht[i] or "")
                hrBoxes[i]:SetText(hr[i] or "")
                applySlotColor(tankBoxes[i], t[i])
                applySlotColor(htBoxes[i],   ht[i])
                applySlotColor(hrBoxes[i],   hr[i])
            end
        end

        preview = RT.UI.TextScroll(panel, {
            name = "RT3_AssignPreview",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 8, -152 },
            width = 690, height = 272, font = "GameFontHighlightSmall",
        })
        preview.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)
        panel._preview = preview
        panel._refreshMT = refreshMT

        RT.Store.Subscribe("roster", function()
            -- Le roster a changé : on n'efface pas l'attrib existante,
            -- mais on rafraîchit l'affichage si une attrib est présente.
            if panel:IsShown() and RT_AA_LAST then
                preview:SetText(fmtAssignment(RT_AA_LAST))
            end
        end)
    end,

    show = function(panel)
        if panel._preview then panel._preview:SetText(fmtAssignment(RT_AA_LAST)) end
        if panel._refreshMT then panel._refreshMT() end
    end,
})

-- [v3:Strats]
-- ============================================================
-- RT v3 — modules/Strats.lua
-- Navigateur de tactiques. Surface RT_Tactics (base vanilla v2).
-- Gauche : liste des boss filtrables. Droite : aperçu + post raid.
-- ============================================================

local function getTactics(query)
    if RT_Tactics and RT_Tactics.FindAll then
        return RT_Tactics.FindAll(query or "")
    end
    return {}
end

local function fmtTactic(t)
    if not t then
        return "|cff888888Select a boss on the left to see its tactic.|r"
    end
    local L = {}
    table.insert(L, "|cffFFD700" .. (t.boss or "?") .. "|r  |cff888888" .. (t.raid or "") .. "|r")
    table.insert(L, " ")
    for i = 1, table.getn(t.lines or {}) do
        table.insert(L, "|cffDDDDDD" .. t.lines[i] .. "|r")
    end
    return table.concat(L, "\n")
end

RT.Modules.Register({
    id       = "strats",
    title    = "Strats",
    tip      = "Boss tactics (search by name). The WhisperBot can send them with ?strat <boss>.",
    color    = { 0.60, 0.90, 1.00 },
    tabWidth = 64,

    build = function(panel)
        RT.UI.Label(panel, {
            text = "|cff8FD8FFStrats|r  —  tactiques par boss, postables en raid",
            font = "GameFontNormal",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -10 },
        })

        local preview   -- forward ref
        panel._selected = nil

        -- ── Gauche : recherche + liste des boss ──
        RT.UI.Label(panel, {
            text = "Search:", font = "GameFontDisable",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -36 },
        })
        local search = CreateFrame("EditBox", "RT3_StratsSearch", panel, "InputBoxTemplate")
        search:SetPoint("TOPLEFT", panel, "TOPLEFT", 100, -34)
        search:SetWidth(180)
        search:SetHeight(20)
        search:SetAutoFocus(false)
        search:SetScript("OnEscapePressed", function() search:ClearFocus() end)

        local scroll, child = RT.UI.ScrollArea(panel, {
            name = "RT3_StratsListScroll",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 8, -60 },
            childWidth = 290,
        })
        scroll:SetWidth(300)
        scroll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 8)

        local list = RT.UI.List(child, {
            rowHeight = 18, gap = 1,
            makeRow = function(l)
                local b = CreateFrame("Button", nil, l, "UIPanelButtonTemplate")
                b:SetHeight(18)
                local fs = b:GetFontString()
                if fs then fs:SetPoint("LEFT", b, "LEFT", 4, 0) end
                return b
            end,
            fillRow = function(row, item)
                local fs = row:GetFontString()
                if item.type == "header" then
                    row:SetText("|cffFFD700" .. (item.raid or "?") .. "|r")
                    if fs then fs:SetJustifyH("LEFT") end
                    row:EnableMouse(false)
                    row:SetScript("OnClick", nil)
                    local nt = row:GetNormalTexture()
                    local ht = row:GetHighlightTexture()
                    if nt then nt:SetAlpha(0) end
                    if ht then ht:SetAlpha(0) end
                else
                    row:SetText("  " .. (item.boss or "?"))
                    if fs then fs:SetJustifyH("LEFT") end
                    row:EnableMouse(true)
                    local nt = row:GetNormalTexture()
                    local ht = row:GetHighlightTexture()
                    if nt then nt:SetAlpha(1) end
                    if ht then ht:SetAlpha(1) end
                    local tac = item
                    row:SetScript("OnClick", function()
                        panel._selected = tac
                        if preview then preview:SetText(fmtTactic(tac)) end
                    end)
                end
            end,
        })
        list:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
        list:SetWidth(280)

        local function refreshList()
            local query = search:GetText() or ""
            local items = {}
            if string.len(query) == 0 then
                -- Vue groupée par raid
                local all    = getTactics("")
                local byRaid = {}
                local order  = {}
                for i = 1, table.getn(all) do
                    local t = all[i]
                    local r = t.raid or "Divers"
                    if not byRaid[r] then
                        byRaid[r] = {}
                        table.insert(order, r)
                    end
                    table.insert(byRaid[r], t)
                end
                table.sort(order)
                for ri = 1, table.getn(order) do
                    local r = order[ri]
                    table.insert(items, { type="header", raid=r })
                    local bosses = byRaid[r]
                    table.sort(bosses, function(a, b) return (a.boss or "") < (b.boss or "") end)
                    for bi = 1, table.getn(bosses) do
                        local t = bosses[bi]
                        table.insert(items, { type="boss", boss=t.boss, raid=t.raid, lines=t.lines })
                    end
                end
            else
                -- Vue filtrée plate
                local all = getTactics(query)
                for i = 1, table.getn(all) do
                    local t = all[i]
                    table.insert(items, { type="boss", boss=t.boss, raid=t.raid, lines=t.lines })
                end
            end
            list:SetItems(items)
            child:SetHeight(list:GetHeight() or 1)
        end
        search:SetScript("OnTextChanged", refreshList)
        panel._refreshList = refreshList

        -- ── Droite : aperçu + post ──
        preview = RT.UI.TextScroll(panel, {
            name = "RT3_StratsPreview",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 318, -60 },
            width = 380, font = "GameFontHighlightSmall",
        })
        preview.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 38)
        panel._preview = preview

        RT.UI.Button(panel, {
            text = "Post /Raid", width = 110, height = 22,
            color = { 1.00, 0.55, 0.20 },
            anchor = { "BOTTOMLEFT", panel, "BOTTOMLEFT", 318, 8 },
            onClick = function()
                if panel._selected and RT_Tactics then RT_Tactics.Post(panel._selected.boss, "RAID")
                else RT.Print("|cffFFAA00Select a boss first.|r") end
            end,
        })
        RT.UI.Button(panel, {
            text = "Post /Party", width = 110, height = 22,
            anchor = { "BOTTOMLEFT", panel, "BOTTOMLEFT", 434, 8 },
            onClick = function()
                if panel._selected and RT_Tactics then RT_Tactics.Post(panel._selected.boss, "PARTY")
                else RT.Print("|cffFFAA00Select a boss first.|r") end
            end,
        })
    end,

    show = function(panel)
        if panel._refreshList then panel._refreshList() end
        if panel._preview then panel._preview:SetText(fmtTactic(panel._selected)) end
    end,
})

-- [v3:Groups]
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

-- [v3:GroupOpt]
-- ============================================================
-- RT v3 - GroupOpt.lua  (0 local chunk-level — toutes fonctions globales)
--
-- Pools :
--   tanks      → spreads dans groupes mêlée (1 par groupe)
--   melee      → Warrior/Rogue/Paladin Retri/Druid Feral/Shaman Enh
--   hunters    → Hunter (Trueshot Aura buff physique) → groupes mêlée
--   casters    → Mage/Warlock/Shadow Priest/Balance Druid/Ele Shaman
--   shamHeals  → Shaman Heal → autorisés en mêlée pour totems (Windfury)
--   otherHeals → Priest/Druid/Paladin Heal → groupes heal dédiés
--
-- Règles strictes :
--   Max 1 Shaman par groupe (pénalité forte -20)
--   Hunters avec physiques, pas avec casters
--   Paladin Holy préféré dans groupes heal (Devotion Aura)
--   Caster idéal : Shaman + Druid Balance + Shadow Priest + casters
-- ============================================================

function RT3_IsHunter(cls)
    return cls == "HUNTER"
end

function RT3_IsCasterClass(cls, spec)
    if cls == "MAGE" or cls == "WARLOCK" then return true end
    if cls == "PRIEST" and string.find(spec or "", "Shadow") then return true end
    if cls == "DRUID"  and string.find(spec or "", "Balance") then return true end
    if cls == "SHAMAN" and string.find(spec or "", "Ele") then return true end
    return false
end

function RT3_IsMeleeClass(cls, spec)
    if cls == "WARRIOR" or cls == "ROGUE" then return true end
    if cls == "PALADIN" and string.find(spec or "", "Retri") then return true end
    if cls == "DRUID"   and string.find(spec or "", "Feral") then return true end
    if cls == "SHAMAN"  and string.find(spec or "", "Enh") then return true end
    return false
end

-- Retourne true si le groupe contient déjà un joueur de cette classe
local function groupHas(gpList, cls, specPat)
    for i = 1, table.getn(gpList) do
        local p = gpList[i]
        if (p.class or "") == cls then
            if not specPat or string.find(p.spec or "", specPat) then
                return true
            end
        end
    end
    return false
end

-- Score de synergie d'un joueur pour un groupe cible
-- targetRole = "melee" | "caster" | "heal"
function RT3_SynergyScore(player, groupList, targetRole)
    local score = 0
    local cls  = player.class or ""
    local spec = player.spec  or ""
    local role = player.role  or ""

    -- ── Shamans : anchor de buff de groupe ───────────────────────
    if cls == "SHAMAN" then
        if string.find(spec, "Enh") then
            -- Windfury : priorité maximale physique
            if targetRole == "melee"  then score = score + 12 end
        elseif string.find(spec, "Res") then
            -- Windfury pour mêlée, Mana Tide pour heal/casters
            if targetRole == "melee"  then score = score + 9 end
            if targetRole == "caster" then score = score + 10 end
            if targetRole == "heal"   then score = score + 10 end
        else
            -- Ele : Mana Spring excellent pour casters
            if targetRole == "caster" then score = score + 11 end
            if targetRole == "heal"   then score = score + 8 end
            if targetRole == "melee"  then score = score + 5 end
        end
        -- Pénalité forte si déjà un Shaman dans ce groupe
        if groupHas(groupList, "SHAMAN") then score = score - 20 end
    end

    -- ── Paladins ─────────────────────────────────────────────────
    if cls == "PALADIN" then
        if string.find(spec, "Holy") then
            -- Devotion Aura : très utile en heal ou caster (mitigation physique)
            if targetRole == "heal"   then score = score + 9 end
            if targetRole == "caster" then score = score + 6 end
            if targetRole == "melee"  then score = score + 3 end
            if groupHas(groupList, "PALADIN", "Holy") then score = score - 8 end
        elseif string.find(spec, "Retri") then
            if targetRole == "melee"  then score = score + 7 end
            if groupHas(groupList, "PALADIN") then score = score - 5 end
        else
            -- Prot : Aura Dévouement, bien en mêlée
            if targetRole == "melee"  then score = score + 8 end
            if targetRole == "caster" then score = score + 4 end
            if groupHas(groupList, "PALADIN") then score = score - 5 end
        end
    end

    -- ── Warrior : Battle Shout (AP groupe physique) ──────────────
    if cls == "WARRIOR" then
        if targetRole == "melee" then score = score + 4 end
        if groupHas(groupList, "WARRIOR") then score = score - 3 end
    end

    -- ── Druid Feral : Leader of the Pack (crit groupe) ──────────
    if cls == "DRUID" and string.find(spec, "Feral") then
        if targetRole == "melee" then score = score + 5 end
        if groupHas(groupList, "DRUID", "Feral") then score = score - 4 end
    end

    -- ── Hunter : Trueshot Aura (AP physique groupe) ──────────────
    if cls == "HUNTER" then
        if targetRole == "melee" then score = score + 7 end
        if targetRole == "caster" then score = score - 4 end  -- pas utile aux casters
        if groupHas(groupList, "HUNTER") then score = score - 3 end
    end

    -- ── Shadow Priest : Shadow Weaving (dég. ombre +) ──────────
    if cls == "PRIEST" and string.find(spec, "Shadow") then
        if targetRole == "caster" then score = score + 8 end
        if groupHas(groupList, "PRIEST", "Shadow") then score = score - 6 end
    end

    -- ── Druid Balance : bien dans groupe caster ─────────────────
    if cls == "DRUID" and string.find(spec, "Balance") then
        if targetRole == "caster" then score = score + 5 end
    end

    -- ── Tank : 1 seul par groupe mêlée ─────────────────────────
    if role == "Tank" then
        if targetRole == "melee" then score = score + 2 end
        for i = 1, table.getn(groupList) do
            if (groupList[i].role or "") == "Tank" then score = score - 15; break end
        end
    end

    return score
end

-- ── Algorithme principal ─────────────────────────────────────────
function RT3_OptimizeGroups()
    local db = RT.Store.Roster()
    local tanks, melee, hunters, casters, shamHeals, otherHeals = {}, {}, {}, {}, {}, {}

    for name, data in pairs(db) do
        local cls  = string.upper(data.class or "")
        local spec = data.spec or ""
        local role = RT_NormalizeRole(data.role or "")
        local p = { name=name, class=cls, spec=spec, role=role }

        if role == "Tank" then
            table.insert(tanks, p)
        elseif role == "Heal" then
            if cls == "SHAMAN" then table.insert(shamHeals, p)
            else                    table.insert(otherHeals, p) end
        elseif cls == "HUNTER" then
            -- Hunter → groupes physiques (Trueshot Aura buff melee)
            table.insert(hunters, p)
        elseif RT3_IsCasterClass(cls, spec) then
            table.insert(casters, p)
        else
            table.insert(melee, p)
        end
    end

    local nTank      = table.getn(tanks)
    local nMelee     = table.getn(melee)
    local nHunt      = table.getn(hunters)
    local nCaster    = table.getn(casters)
    local nShamHeal  = table.getn(shamHeals)
    local nOtherHeal = table.getn(otherHeals)
    if nTank+nMelee+nHunt+nCaster+nShamHeal+nOtherHeal == 0 then return nil end

    -- Tri : anchors de buff en premier (Shaman Enh > Shaman Resto > Paladin > …)
    local function anchorOrder(p)
        local c=p.class or ""; local s=p.spec or ""
        if p.role == "Tank"                             then return 0 end
        if c=="SHAMAN"  and string.find(s,"Enh")       then return 1 end
        if c=="SHAMAN"  and string.find(s,"Res")       then return 2 end
        if c=="SHAMAN"                                  then return 3 end
        if c=="HUNTER"                                  then return 4 end
        if c=="PALADIN"                                 then return 5 end
        if c=="DRUID"   and string.find(s,"Feral")     then return 6 end
        if c=="WARRIOR"                                 then return 7 end
        if c=="PRIEST"  and string.find(s,"Shadow")    then return 8 end
        if c=="DRUID"   and string.find(s,"Balance")   then return 9 end
        return 10
    end

    -- Pool mêlée combiné : tanks + melee + hunters (tous physiques)
    local physPool = {}
    for i=1,nTank  do table.insert(physPool, tanks[i])   end
    for i=1,nMelee do table.insert(physPool, melee[i])   end
    for i=1,nHunt  do table.insert(physPool, hunters[i]) end

    table.sort(physPool,   function(a,b) return anchorOrder(a)<anchorOrder(b) end)
    table.sort(casters,    function(a,b) return anchorOrder(a)<anchorOrder(b) end)
    table.sort(shamHeals,  function(a,b) return anchorOrder(a)<anchorOrder(b) end)
    table.sort(otherHeals, function(a,b) return anchorOrder(a)<anchorOrder(b) end)

    local nPhys    = table.getn(physPool)
    local nPhysG   = (nPhys    > 0) and math.max(1, math.ceil(nPhys    / 5)) or 0
    local nCasterG = (nCaster  > 0) and math.max(1, math.ceil(nCaster  / 5)) or 0

    -- Plafonner à 8 total
    local nonHeal = nPhysG + nCasterG
    if nonHeal > 8 then
        if nCasterG > 1 then nCasterG=nCasterG-1; nonHeal=nonHeal-1 end
        if nonHeal > 8 and nPhysG > 1 then nPhysG=nPhysG-1; nonHeal=nonHeal-1 end
    end
    local nHealG = math.max(0, 8 - nonHeal)

    -- Structure interne
    local gpP={}; local gpN={}
    for g=1,8 do gpP[g]={}; gpN[g]={} end

    local function addP(g,p) table.insert(gpP[g],p); table.insert(gpN[g],p.name) end

    local function assignPool(pool, gS, gE, role, cap)
        if gS>gE or gS>8 then return end
        local maxC=cap or 5
        for i=1,table.getn(pool) do
            local p=pool[i]
            local bestG=gS; local bestScore=-9999
            for g=gS,gE do
                if g>8 then break end
                if table.getn(gpP[g])<maxC then
                    local syn  = RT3_SynergyScore(p, gpP[g], role)
                    local size = -(table.getn(gpP[g]))*3
                    if syn+size>bestScore then bestScore=syn+size; bestG=g end
                end
            end
            if table.getn(gpP[bestG])<maxC then addP(bestG,p)
            else p._ov=true end
        end
    end

    local function fillOverflow(pool, gS, gE)
        for i=1,table.getn(pool) do
            local p=pool[i]
            if p._ov then
                local bestG=nil; local bestFr=0
                for g=gS,gE do
                    local fr=5-table.getn(gpP[g])
                    if fr>bestFr then bestFr=fr; bestG=g end
                end
                if bestG then p._ov=nil; addP(bestG,p) end
            end
        end
    end

    -- ── Phase 1 : PHYSIQUES (tanks spreads 1/groupe, hunters avec mêlée) ──
    local physEnd = nPhysG
    assignPool(physPool, 1, physEnd, "melee", 5)

    -- Shaman Heal dans les slots libres des groupes physiques
    if nShamHeal > 0 then
        assignPool(shamHeals, 1, physEnd, "melee", 5)
    end

    -- ── Phase 2 : CASTERS ──────────────────────────────────────────
    local casterStart = physEnd + 1
    local casterEnd   = physEnd + nCasterG
    if nCasterG > 0 then
        assignPool(casters, casterStart, casterEnd, "caster", 5)
        -- Shaman Heal overflow → casters (Mana Spring/Tide pour casters)
        fillOverflow(shamHeals, casterStart, casterEnd)
    end

    -- ── Phase 3 : HEAL dédiés (Paladin Holy en tête pour Devotion) ──
    local healStart = casterEnd + 1
    local healEnd   = math.min(8, healStart + nHealG - 1)
    if nHealG > 0 then
        assignPool(otherHeals, healStart, healEnd, "heal", 5)
    end

    -- ── Phase 4 : Overflow → slots libres groupes caster/heal uniquement ──
    fillOverflow(otherHeals, casterStart, 8)
    fillOverflow(physPool, 1, 8)
    fillOverflow(casters, 1, 8)

    return gpN
end

-- Résumé textuel des buffs actifs d'un groupe
function RT3_GroupBuffSummary(players)
    if not players then return "" end
    local buffs={}; local seen={}
    for i=1,table.getn(players) do
        local p=players[i]; local c=(p.class or ""); local s=(p.spec or "")
        if c=="SHAMAN" and not seen.sham then
            seen.sham=true
            if string.find(s,"Enh") then
                table.insert(buffs,"|cff22CCFF+Windfury|r")
            elseif string.find(s,"Res") then
                table.insert(buffs,"|cff22CCFF+Windfury+Tide|r")
            else
                table.insert(buffs,"|cff22CCFF+ManaSpring|r")
            end
        end
        if c=="PALADIN" and not seen.pal then
            seen.pal=true; table.insert(buffs,"|cffF58CBA+Devo|r")
        end
        if c=="DRUID" and string.find(s,"Feral") and not seen.feral then
            seen.feral=true; table.insert(buffs,"|cffFF7D0A+LoTP|r")
        end
        if c=="WARRIOR" and not seen.warr then
            seen.warr=true; table.insert(buffs,"|cffC79C6E+BShout|r")
        end
        if c=="HUNTER" and not seen.hunt then
            seen.hunt=true; table.insert(buffs,"|cffABD473+TrueAura|r")
        end
        if c=="PRIEST" and string.find(s,"Shadow") and not seen.spriest then
            seen.spriest=true; table.insert(buffs,"|cffAAAAFF+SWeaving|r")
        end
        if (p.role or "")=="Tank" and not seen.tank then
            seen.tank=true; table.insert(buffs,"|cff4499FF[Tank]|r")
        end
    end
    return table.concat(buffs," ")
end

-- [v3:Boss]
-- ============================================================
-- RT v3 - modules/Boss.lua
-- Liste par raid + assignation style v2
-- ============================================================

-- (MARKER_TEX inliné partout pour économiser un local chunk)
local MARKERS = {
    { idx=8, name="Tete de Mort", tc={0.75,1.00,0.50,1.00} },
    { idx=7, name="Croix",        tc={0.50,0.75,0.50,1.00} },
    { idx=6, name="Carre",        tc={0.25,0.50,0.50,1.00} },
    { idx=5, name="Lune",         tc={0.00,0.25,0.50,1.00} },
    { idx=4, name="Triangle",     tc={0.75,1.00,0.00,0.50} },
    { idx=3, name="Diamant",      tc={0.50,0.75,0.00,0.50} },
    { idx=2, name="Cercle",       tc={0.25,0.50,0.00,0.50} },
    { idx=1, name="Etoile",       tc={0.00,0.25,0.00,0.50} },
    { idx=0, name="None",         tc=nil                    },
}
local PRESET_MARK = {
    Skull=8, Cross=7, Square=6, Moon=5, Triangle=4, Diamond=3, Circle=2, Star=1
}

-- Groupes de soins (fixe, style v2)
local HG = {
    { key="htank",  label="H.Tanks", defCnt=4 },
    { key="hraid",  label="H.Raid",  defCnt=6 },
    { key="hmelee", label="H.Melee", defCnt=3 },
    { key="hcast",  label="H.Cast",  defCnt=3 },
}

-- MAX_TC=8  TC_PER_R=4  MAX_HG=10  (inlinés pour rester sous 200 locals/chunk)

local DEFAULT_BOSSES = {
    "Lucifron","Magmadar","Gehennas","Garr","Shazzrah","Baron Geddon","Golemagg","Sulfuron","Majordomo","Ragnaros",
    "Razorgore","Vaelastrasz","Broodlord Lashlayer","Firemaw","Ebonroc","Flamegor","Chromaggus","Nefarian",
    "Onyxia",
    "Venoxis","Jeklik","Mandokir","Thekal","Arlokk","Hakkar",
    "Kurinnaxx","Rajaxx","Moam","Buru","Ayamiss","Ossirian",
    "Skeram","Sartura","Fankriss","Viscidus","Huhuran","Twin Emperors","Ouro","C'Thun",
    "Anub'Rekhan","Faerlina","Maexxna","Noth","Heigan","Loatheb",
    "Razuvious","Gothik","Four Horsemen","Patchwerk","Grobbulus","Gluth","Thaddius",
    "Sapphiron","Kel'Thuzad",
    "Attumen","Moroes","Maiden of Virtue","Opera","The Curator","Illhoof",
    "Shade of Aran","Netherspite","Chess Event","Prince Malchezaar","Nightbane",
    "Master Blacksmith Rolfen","Brood Queen Araxxna","Grizikil","Clawlord Howlfang","Lord Blackwald II",
    "Keeper Gnarlmoon","Ley-Watcher Incantagos","Anomalus","Echo of Medivh","King (Chess fight)",
    "Sanv Tas'dal","Kruul","Rupturan the Broken","Mephistroth",
}

local function getBossDB()
    local db = RT.Store.DB()
    if not db.v3boss then db.v3boss = {} end
    return db.v3boss
end

local function getHGData(e, key, defCnt)
    if not e[key] then e[key] = { cnt=defCnt or 3, slots={} } end
    if not e[key].cnt then e[key].cnt = defCnt or 3 end
    if not e[key].slots then e[key].slots = {} end
    return e[key]
end

local function getBossEntry(boss)
    local bdb = getBossDB()
    if not bdb[boss] then
        bdb[boss] = { tc=2, tanks={}, note="" }
    end
    local e = bdb[boss]
    if not e.tc    then e.tc    = 2  end
    if not e.tanks then e.tanks = {} end
    if not e.note  then e.note  = "" end
    -- Migration: tank strings → tables
    for i = 1, table.getn(e.tanks) do
        if type(e.tanks[i]) == "string" then
            e.tanks[i] = { name=e.tanks[i], mark=0 }
        end
    end
    -- Assure tc slots dans tanks[]
    while table.getn(e.tanks) < e.tc do
        table.insert(e.tanks, { name="", mark=0 })
    end
    -- Init groupes soin
    for gi = 1, table.getn(HG) do
        local hg = getHGData(e, HG[gi].key, HG[gi].defCnt)
        while table.getn(hg.slots) < hg.cnt do
            table.insert(hg.slots, "")
        end
    end
    return e
end

local function getGroupedBosses()
    local grps  = {}
    local order = {}
    if RT_Tactics and RT_Tactics.FindAll then
        local all = RT_Tactics.FindAll("")
        for i = 1, table.getn(all) do
            local t  = all[i]
            local r  = t.raid or "Divers"
            if not grps[r] then grps[r] = {}; table.insert(order, r) end
            table.insert(grps[r], t.boss)
        end
        table.sort(order)
        for ri = 1, table.getn(order) do table.sort(grps[order[ri]]) end
    else
        grps["Divers"] = DEFAULT_BOSSES
        order = {"Divers"}
    end
    return grps, order
end

local function markerForIdx(idx)
    for i = 1, table.getn(MARKERS) do
        if MARKERS[i].idx == idx then return MARKERS[i] end
    end
    return MARKERS[table.getn(MARKERS)]
end

local function nextMarkIdx(current)
    if not current or current <= 0 then return 8 end
    return current - 1
end

local function applyMarkToName(name, markIdx)
    if not SetRaidTarget then return end
    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    for i = 1, n do
        local pname = GetRaidRosterInfo(i)
        if pname == name then SetRaidTarget("raid"..i, markIdx) return end
    end
    RT.Print("|cffFF8888Introuvable dans le raid: "..name.."|r")
end

-- ── Base de packs de trash par raid (marqueur = mob à tank) ───
-- Globale (pas un local de chunk) ; marks suivent l'ordre des MT.
RT_TRASH_PRESETS = {
    ["Molten Core"] = {
        { name="Pack Lucifron",      tc=2, marks={"Skull","Cross"},          note="Flamewaker Protector on Skull. Interrupt the Flamewakers' heals." },
        { name="Core Hounds",        tc=2, marks={"Skull","Cross"},          note="Kill the hounds together (~10s) or they resurrect." },
        { name="Firesworn (Garr)",   tc=1, marks={"Skull"},                  note="Explode on death. Kill away from the raid." },
    },
    ["Blackwing Lair"] = {
        { name="Suppression Room",   tc=2, marks={"Skull","Cross"},          note="Disarm the Suppression Devices. Chain pulls." },
        { name="Death Talon Drakonid",tc=2, marks={"Skull","Cross"},         note="Separate tanks. Focus Skull, interrupt." },
    },
    ["Temple of Ahn"] = {
        { name="Anubisath (entrance)",tc=2, marks={"Skull","Cross"},         note="Big adds. Tank each, focus Skull." },
        { name="Qiraji Champion",    tc=2, marks={"Skull","Cross"},          note="CC casters if possible. Kill Skull then Cross." },
    },
    ["Naxxramas"] = {
        { name="Spider Wing",        tc=2, marks={"Skull","Cross"},          note="Random Web Wrap. Focus Skull." },
        { name="Abomination Wing",   tc=2, marks={"Skull","Cross"},          note="Slimes: avoid merging." },
        { name="Military Quarter",   tc=3, marks={"Skull","Cross","Square"}, note="Death Knights: interrupt. Manage summons." },
        { name="Construction Quarter",tc=2, marks={"Skull","Cross"},        note="Patchwork/Stitched: poison. Focus together." },
    },
}

-- Popup de saisie pour ajouter un pack de trash perso
StaticPopupDialogs["RT3_ADD_TRASH"] = {
    text = "Nom du pack de trash :",
    button1 = "Add",
    button2 = "Cancel",
    hasEditBox = 1,
    maxLetters = 40,
    OnShow = function()
        -- this = cadre dialog (fiable) → on mémorise l'EditBox pour OnAccept
        RT_TRASH_POPUP_EB = getglobal(this:GetName().."EditBox")
        if RT_TRASH_POPUP_EB then RT_TRASH_POPUP_EB:SetText(""); RT_TRASH_POPUP_EB:SetFocus() end
    end,
    OnAccept = function()
        if RT_TRASH_POPUP_EB and RT_BossDoAddTrash then
            RT_BossDoAddTrash(RT_TRASH_POPUP_EB:GetText())
        end
    end,
    EditBoxOnEnterPressed = function()
        if RT_TRASH_POPUP_EB and RT_BossDoAddTrash then
            RT_BossDoAddTrash(RT_TRASH_POPUP_EB:GetText())
        end
        this:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function() this:GetParent():Hide() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

-- ─────────────────────────────────────────────────────────────
RT.Modules.Register({
    id       = "boss",
    title    = "Boss",
    tip      = "Per boss: tanks + target markers, group healing, tactic note. Trash packs (orange) are under each raid.",
    color    = { 1.00, 0.30, 0.30 },
    tabWidth = 50,

    build = function(panel)

        -- ── GAUCHE : liste boss par raid ─────────────────────────
        local listScroll, listChild = RT.UI.ScrollArea(panel, {
            name="RT3_BossListScroll",
            anchor={"TOPLEFT", panel, "TOPLEFT", 6, -10},
            childWidth=220,
        })
        listScroll:SetWidth(232)
        listScroll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 6, 8)

        -- ── DROITE : panneau detail ───────────────────────────────
        local det = CreateFrame("Frame","RT3_BossDetail",panel)
        det:SetPoint("TOPLEFT",     panel, "TOPLEFT",     246, -6)
        det:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT",  -6,  6)
        RT.UI.ApplyBackdrop(det, 0.05, 0.02, 0.02, 0.92)
        det._current = nil

        -- En-tête: nom boss + bouton preset
        local bossTitle = det:CreateFontString(nil,"OVERLAY","GameFontNormal")
        bossTitle:SetPoint("TOPLEFT", det, "TOPLEFT", 8, -8)
        bossTitle:SetWidth(240)
        bossTitle:SetText("|cff666666— Select a boss —|r")

        local presetBtn = RT.UI.Button(det, {
            text="Load Preset", width=128, height=20, color={0.15,0.35,0.55},
            anchor={"TOPRIGHT", det, "TOPRIGHT", -4, -6},
        })

        local trashBtn = RT.UI.Button(det, {
            text="+ Trash", width=62, height=20, color={0.45,0.30,0.10},
            anchor={"TOPRIGHT", det, "TOPRIGHT", -136, -6},
            tooltip="Adds a custom trash pack to the raid of the selected entry.",
        })
        trashBtn:SetScript("OnClick", function()
            local raid = det._current and det._entryRaid and det._entryRaid[det._current]
            if not raid then
                RT.Print("|cffFFAA00Select a boss/trash of the desired raid first.|r")
                return
            end
            det._addTrashRaid = raid
            StaticPopup_Show("RT3_ADD_TRASH")
        end)

        local sepTop = det:CreateTexture(nil,"BACKGROUND")
        sepTop:SetPoint("TOPLEFT",  det, "TOPLEFT",  4, -30)
        sepTop:SetPoint("TOPRIGHT", det, "TOPRIGHT", -4, -30)
        sepTop:SetHeight(1) sepTop:SetTexture(0.6,0.2,0.2,0.6)

        -- Zone scrollable (contenu principal)
        local dScroll, child = RT.UI.ScrollArea(det, {
            name="RT3_BossCScroll",
            anchor={"TOPLEFT", det, "TOPLEFT", 0, -32},
            childWidth=400,
        })
        dScroll:SetPoint("BOTTOMRIGHT", det, "BOTTOMRIGHT", -22, 0)

        -- Layout constants  (CW ≈ 396 px dans la zone scroll)
        local CW        = 396
        local TANK_H    = 22    -- hauteur d'une rangee de tanks
        local TANK_SW   = 126   -- largeur d'un slot tank (marker+EB+X), 3/rangée
        local TANK_GAP  = 6
        local HG_H      = 18    -- hauteur d'un slot soin
        local HG_SW     = 126   -- largeur d'un slot soin (EB+X), 3/rangée
        local HG_GAP    = 6

        -- ── SECTION TANKS ─────────────────────────────────────────
        local tankLbl = child:CreateFontString(nil,"OVERLAY","GameFontNormal")
        tankLbl:SetText("|cffFF7777TANKS|r")

        -- Contrôle du nb de tanks: [-] (N tanks) [+]
        local tcMinBtn = CreateFrame("Button","RT3_BTCMinus",child,"UIPanelButtonTemplate")
        tcMinBtn:SetWidth(22) tcMinBtn:SetHeight(18)
        tcMinBtn:SetText("-")

        local tcLbl = child:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        tcLbl:SetJustifyH("LEFT")
        tcLbl:SetWidth(160)

        local tcPluBtn = CreateFrame("Button","RT3_BTCPlus",child,"UIPanelButtonTemplate")
        tcPluBtn:SetWidth(22) tcPluBtn:SetHeight(18)
        tcPluBtn:SetText("+")

        tcMinBtn:SetScript("OnClick", function()
            if not det._current then return end
            local e = getBossEntry(det._current)
            e.tc = math.max(1, e.tc - 1)
            det._refresh()
        end)
        tcPluBtn:SetScript("OnClick", function()
            if not det._current then return end
            local e = getBossEntry(det._current)
            e.tc = math.min(8, e.tc + 1)
            while table.getn(e.tanks) < e.tc do
                table.insert(e.tanks, { name="", mark=0 })
            end
            det._refresh()
        end)

        -- Pool de slots tanks (8 frames, 4 par rangee)
        local tankSlots = {}
        for i = 1, 8 do
            local sf = CreateFrame("Frame", nil, child)
            sf:SetWidth(TANK_SW) sf:SetHeight(TANK_H)
            sf:SetPoint("TOPLEFT", child, "TOPLEFT", -9999, -9999)

            local bg = sf:CreateTexture(nil,"BACKGROUND")
            bg:SetAllPoints()
            if math.mod(i,2)==0 then bg:SetTexture(0.12,0.04,0.04,0.7)
            else                      bg:SetTexture(0.08,0.02,0.02,0.6) end

            -- Bouton marqueur
            local mBtn = CreateFrame("Button", nil, sf)
            mBtn:SetWidth(20) mBtn:SetHeight(TANK_H)
            mBtn:SetPoint("LEFT", sf, "LEFT", 1, 0)
            mBtn:EnableMouse(true)
            local mTex = mBtn:CreateTexture(nil,"OVERLAY")
            mTex:SetWidth(16) mTex:SetHeight(16)
            mTex:SetPoint("CENTER", mBtn, "CENTER", 0, 0)
            mTex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons") mTex:Hide()
            local mLbl = mBtn:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            mLbl:SetAllPoints() mLbl:SetJustifyH("CENTER")
            mLbl:SetText("|cff444444·|r")
            mBtn._tex=mTex; mBtn._lbl=mLbl; sf._mBtn=mBtn

            local ri = i
            mBtn:SetScript("OnClick", function()
                if not det._current then return end
                local e = getBossEntry(det._current)
                if type(e.tanks[ri])~="table" then return end
                e.tanks[ri].mark = nextMarkIdx(e.tanks[ri].mark or 0)
                det._refresh()
            end)

            -- EditBox nom
            local eb = CreateFrame("EditBox","RT3_BT"..i,sf,"InputBoxTemplate")
            eb:SetPoint("LEFT",  sf, "LEFT",  22, 0)
            eb:SetPoint("RIGHT", sf, "RIGHT", -22, 0)
            eb:SetHeight(TANK_H-4) eb:SetAutoFocus(false)
            eb:SetScript("OnEscapePressed", function() eb:ClearFocus() end)
            eb:SetScript("OnEnterPressed", function()
                if not det._current then eb:ClearFocus() return end
                local e = getBossEntry(det._current)
                if type(e.tanks[ri])=="table" then
                    e.tanks[ri].name = eb:GetText() or ""
                end
                eb:ClearFocus()
            end)
            sf._eb = eb

            -- X
            local xb = CreateFrame("Button", nil, sf, "UIPanelButtonTemplate")
            xb:SetWidth(20) xb:SetHeight(TANK_H-4)
            xb:SetPoint("RIGHT", sf, "RIGHT", -1, 0)
            xb:SetText("X")
            local xfs = xb:GetFontString(); if xfs then xfs:SetTextColor(1,0.4,0.4) end
            xb:SetScript("OnClick", function()
                if not det._current then return end
                local e = getBossEntry(det._current)
                if type(e.tanks[ri])=="table" then
                    e.tanks[ri] = { name="", mark=0 }
                    det._refresh()
                end
            end)

            sf:Hide()
            tankSlots[i] = sf
        end

        -- ── SECTION SOINS ─────────────────────────────────────────
        local soinsLbl = child:CreateFontString(nil,"OVERLAY","GameFontNormal")
        soinsLbl:SetText("|cff77FF77SOINS|r")

        local sepSoin = child:CreateTexture(nil,"BACKGROUND")
        sepSoin:SetHeight(1) sepSoin:SetTexture(0.2,0.6,0.2,0.5)

        -- Pre-créer les 4 groupes soin
        local hgHdr   = {}   -- { lbl, minBtn, cntFS, pluBtn }
        local hgSlots = {}   -- hgSlots[gi][si] = { _eb, _xb }

        for gi = 1, table.getn(HG) do
            local hgDef = HG[gi]

            local hdrLbl = child:CreateFontString(nil,"OVERLAY","GameFontNormal")
            hdrLbl:SetText("|cffAAAAFF"..hgDef.label.."|r")

            local hdrMin = CreateFrame("Button","RT3_BHGMinus"..gi,child,"UIPanelButtonTemplate")
            hdrMin:SetWidth(20) hdrMin:SetHeight(16) hdrMin:SetText("-")

            local hdrCnt = child:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            hdrCnt:SetWidth(26) hdrCnt:SetJustifyH("CENTER")

            local hdrPlu = CreateFrame("Button","RT3_BHGPlus"..gi,child,"UIPanelButtonTemplate")
            hdrPlu:SetWidth(20) hdrPlu:SetHeight(16) hdrPlu:SetText("+")

            local gk = hgDef.key
            hdrMin:SetScript("OnClick", function()
                if not det._current then return end
                local e  = getBossEntry(det._current)
                local hg = getHGData(e, gk, hgDef.defCnt)
                hg.cnt = math.max(0, hg.cnt - 1)
                det._refresh()
            end)
            hdrPlu:SetScript("OnClick", function()
                if not det._current then return end
                local e  = getBossEntry(det._current)
                local hg = getHGData(e, gk, hgDef.defCnt)
                hg.cnt = math.min(10, hg.cnt + 1)
                while table.getn(hg.slots) < hg.cnt do table.insert(hg.slots,"") end
                det._refresh()
            end)

            hgHdr[gi] = { lbl=hdrLbl, min=hdrMin, cnt=hdrCnt, plu=hdrPlu }

            hgSlots[gi] = {}
            for si = 1, 10 do
                local sf = CreateFrame("Frame", nil, child)
                sf:SetWidth(HG_SW) sf:SetHeight(HG_H)
                sf:SetPoint("TOPLEFT", child, "TOPLEFT", -9999, -9999)

                local bg2 = sf:CreateTexture(nil,"BACKGROUND")
                bg2:SetAllPoints()
                if math.mod(si,2)==0 then bg2:SetTexture(0.02,0.08,0.02,0.5)
                else                       bg2:SetTexture(0.01,0.05,0.01,0.4) end

                local eb2 = CreateFrame("EditBox","RT3_BHG"..gi.."S"..si,sf,"InputBoxTemplate")
                eb2:SetPoint("LEFT",  sf, "LEFT",   1, 0)
                eb2:SetPoint("RIGHT", sf, "RIGHT", -22, 0)
                eb2:SetHeight(HG_H-3) eb2:SetAutoFocus(false)
                eb2:SetScript("OnEscapePressed", function() eb2:ClearFocus() end)
                local gki, sii = gk, si
                eb2:SetScript("OnEnterPressed", function()
                    if not det._current then eb2:ClearFocus() return end
                    local e  = getBossEntry(det._current)
                    local hg = getHGData(e, gki, 3)
                    hg.slots[sii] = eb2:GetText() or ""
                    eb2:ClearFocus()
                end)
                sf._eb = eb2

                local xb2 = CreateFrame("Button", nil, sf, "UIPanelButtonTemplate")
                xb2:SetWidth(20) xb2:SetHeight(HG_H-3)
                xb2:SetPoint("RIGHT", sf, "RIGHT", -1, 0)
                xb2:SetText("X")
                local xfs2 = xb2:GetFontString(); if xfs2 then xfs2:SetTextColor(0.5,1.0,0.3) end
                xb2:SetScript("OnClick", function()
                    if not det._current then return end
                    local e  = getBossEntry(det._current)
                    local hg = getHGData(e, gki, 3)
                    hg.slots[sii] = ""
                    det._refresh()
                end)

                sf:Hide()
                hgSlots[gi][si] = sf
            end
        end

        -- ── NOTE + POST ───────────────────────────────────────────
        local noteLbl = child:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        noteLbl:SetText("|cffCCCCCCNote :|r")

        local noteEB = CreateFrame("EditBox","RT3_BossNote",child,"InputBoxTemplate")
        noteEB:SetHeight(20) noteEB:SetAutoFocus(false)
        noteEB:SetScript("OnEscapePressed", function() noteEB:ClearFocus() end)
        noteEB:SetScript("OnTextChanged", function()
            if not det._current then return end
            getBossEntry(det._current).note = noteEB:GetText() or ""
        end)

        local postBtn = RT.UI.Button(child, {
            text="Post Assignments /Raid", width=200, height=22, color={0.60,0.20,0.20},
            anchor={"TOPLEFT", child, "TOPLEFT", 4, -9999},
        })
        postBtn:SetScript("OnClick", function()
            if not det._current then return end
            local boss = det._current
            local e    = getBossEntry(boss)
            -- Tanks
            local tn = {}
            for i = 1, e.tc do
                local tk = e.tanks[i]
                if type(tk)=="table" and (tk.name or "")~="" then
                    local mk  = markerForIdx(tk.mark or 0)
                    local pre = (mk and mk.tc) and ("["..mk.name.."] ") or ""
                    table.insert(tn, pre..tk.name)
                end
            end
            if table.getn(tn)>0 then
                SendChatMessage("["..boss.."] Tanks: "..table.concat(tn," / "), "RAID")
            end
            -- Groupes soin
            for gi = 1, table.getn(HG) do
                local hgDef = HG[gi]
                local hg    = getHGData(e, hgDef.key, hgDef.defCnt)
                if hgDef.key == "htank" then
                    -- Soins tank : appairer chaque soigneur à SON tank (MT i)
                    local hn = {}
                    for si = 1, hg.cnt do
                        local sf = hgSlots[gi] and hgSlots[gi][si]
                        local nm = (sf and sf._eb and sf._eb:GetText()) or (hg.slots[si] or "")
                        if nm~="" then
                            local tk = e.tanks[si]
                            local tn2 = (type(tk)=="table" and (tk.name or "")) or ""
                            if tn2~="" then
                                table.insert(hn, "MT"..si.." ("..tn2..") <- "..nm)
                            else
                                table.insert(hn, "MT"..si.." <- "..nm)
                            end
                        end
                    end
                    if table.getn(hn)>0 then
                        SendChatMessage("["..boss.."] Tank heals: "..table.concat(hn," / "), "RAID")
                    end
                else
                    local hn = {}
                    for si = 1, hg.cnt do
                        local sf = hgSlots[gi] and hgSlots[gi][si]
                        local nm = (sf and sf._eb and sf._eb:GetText()) or (hg.slots[si] or "")
                        if nm~="" then table.insert(hn, nm) end
                    end
                    if table.getn(hn)>0 then
                        SendChatMessage("["..boss.."] "..hgDef.label..": "..table.concat(hn," / "), "RAID")
                    end
                end
            end
            if (e.note or "")~="" then
                SendChatMessage("["..boss.."] "..e.note, "RAID")
            end
        end)

        -- ── REFRESH ───────────────────────────────────────────────
        local function refresh()
            if not det._current then return end
            local e  = getBossEntry(det._current)
            local cy = -4  -- y courant (negatif = vers le bas)

            -- Label TANKS
            tankLbl:ClearAllPoints()
            tankLbl:SetPoint("TOPLEFT", child, "TOPLEFT", 4, cy)
            cy = cy - 20

            -- Contrôle nb tanks : [-] N tanks [+]
            tcMinBtn:ClearAllPoints()
            tcMinBtn:SetPoint("TOPLEFT", child, "TOPLEFT", 4, cy+1)
            tcLbl:ClearAllPoints()
            tcLbl:SetPoint("TOPLEFT", child, "TOPLEFT", 28, cy)
            tcLbl:SetText("|cffAAAAFF"..e.tc.." tank"..(e.tc>1 and "s" or "").." |r|cff555555(clic marqueur · Enter=sauver · X=vider)|r")
            tcPluBtn:ClearAllPoints()
            tcPluBtn:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, cy+1)
            cy = cy - 24

            -- Slots tanks (3 par rangee, 8 max)
            local tcRows = math.ceil(e.tc / 3)
            for i = 1, 8 do
                local sf = tankSlots[i]
                sf:ClearAllPoints()
                if i <= e.tc then
                    local col = math.mod(i-1, 3)
                    local row = math.floor((i-1) / 3)
                    local tx  = 4 + col * (TANK_SW + TANK_GAP)
                    local ty  = cy - row * TANK_H
                    sf:SetPoint("TOPLEFT", child, "TOPLEFT", tx, ty)
                    sf:SetWidth(TANK_SW)
                    local tk = e.tanks[i]
                    if type(tk)~="table" then tk={name="",mark=0} end
                    local m = markerForIdx(tk.mark or 0)
                    if m and m.tc then
                        sf._mBtn._tex:SetTexCoord(m.tc[1],m.tc[2],m.tc[3],m.tc[4])
                        sf._mBtn._tex:Show(); sf._mBtn._lbl:Hide()
                    else
                        sf._mBtn._tex:Hide()
                        sf._mBtn._lbl:SetText("|cff444444·|r"); sf._mBtn._lbl:Show()
                    end
                    sf._eb:SetText(tk.name or "")
                    sf:Show()
                else
                    sf:Hide()
                end
            end
            cy = cy - tcRows * TANK_H - 10

            -- Séparateur + SOINS
            sepSoin:ClearAllPoints()
            sepSoin:SetPoint("TOPLEFT",  child, "TOPLEFT",  4, cy)
            sepSoin:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, cy)
            cy = cy - 4
            soinsLbl:ClearAllPoints()
            soinsLbl:SetPoint("TOPLEFT", child, "TOPLEFT", 4, cy)
            cy = cy - 20

            -- Groupes soin
            for gi = 1, table.getn(HG) do
                local hgDef = HG[gi]
                local hd    = hgHdr[gi]
                local hg    = getHGData(e, hgDef.key, hgDef.defCnt)
                local cnt   = hg.cnt or 0

                -- Ligne header: [Label]..........[-](N)[+]
                hd.lbl:ClearAllPoints()
                hd.lbl:SetPoint("TOPLEFT", child, "TOPLEFT", 4, cy)

                hd.cnt:ClearAllPoints()
                hd.cnt:SetPoint("TOPLEFT", child, "TOPLEFT", 80, cy)
                hd.cnt:SetText("|cff888888("..cnt..")|r")

                hd.plu:ClearAllPoints()
                hd.plu:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, cy+1)
                hd.min:ClearAllPoints()
                hd.min:SetPoint("TOPRIGHT", child, "TOPRIGHT", -28, cy+1)
                cy = cy - 20

                -- Slots (HG_SW par slot, 3 par rangee)
                local hgRows = (cnt > 0) and math.ceil(cnt / 3) or 0
                for si = 1, 10 do
                    local sf = hgSlots[gi][si]
                    sf:ClearAllPoints()
                    if si <= cnt then
                        local col = math.mod(si-1, 3)
                        local row = math.floor((si-1) / 3)
                        local sx  = 4 + col * (HG_SW + HG_GAP)
                        local sy  = cy - row * HG_H
                        sf:SetPoint("TOPLEFT", child, "TOPLEFT", sx, sy)
                        sf:SetWidth(HG_SW)
                        sf._eb:SetText(hg.slots[si] or "")
                        sf:Show()
                    else
                        sf:Hide()
                    end
                end
                cy = cy - hgRows * HG_H - 10
            end

            -- Note + Post
            cy = cy - 2
            noteLbl:ClearAllPoints()
            noteLbl:SetPoint("TOPLEFT", child, "TOPLEFT", 4, cy)
            cy = cy - 18
            noteEB:ClearAllPoints()
            noteEB:SetPoint("TOPLEFT",  child, "TOPLEFT",  4, cy)
            noteEB:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, cy)
            cy = cy - 28
            postBtn:ClearAllPoints()
            postBtn:SetPoint("TOPLEFT", child, "TOPLEFT", 4, cy)

            child:SetHeight(math.abs(cy) + 40)
        end
        det._refresh = refresh

        -- Applique le preset (marqueurs + note) au boss, en gardant les noms déjà saisis
        local function applyPreset(boss, e)
            local preset = RT_BOSS_PRESETS and RT_BOSS_PRESETS[boss]
            if not preset then return false end
            e.tc = preset.tank_count or e.tc or 2
            local marks = preset.tank_marks or {}
            if not e.tanks then e.tanks = {} end
            for i = 1, e.tc do
                if type(e.tanks[i]) ~= "table" then e.tanks[i] = { name="", mark=0 } end
                e.tanks[i].mark = PRESET_MARK[marks[i] or ""] or e.tanks[i].mark or 0
            end
            if (e.note or "") == "" then e.note = preset.note or "" end
            return true
        end

        -- Recopie les NOMS de l'attribution Assign (défaut global) dans le boss
        -- si les slots sont vides (ne touche pas aux marqueurs du preset)
        local function applyAssignDefault(e)
            local d = RT.Store.DB().v3boss_default
            if not d then return end
            -- Tanks : noms par position MT1..MTn
            -- Tanks : Assign pilote l'ordre MT → on synchronise par position
            -- (jusqu'à e.tc, le nb de tanks fixé par le preset du boss)
            if d.tanks then
                for i = 1, (e.tc or 0) do
                    if type(e.tanks[i]) ~= "table" then e.tanks[i] = { name="", mark=0 } end
                    if d.tanks[i] and d.tanks[i] ~= "" then e.tanks[i].name = d.tanks[i] end
                end
            end
            -- Soins : H.Tanks ← S.Tank, H.Raid ← S.Raid (Assign pilote)
            local map = { htank=d.htank, hraid=d.hraid }
            for gi = 1, table.getn(HG) do
                local key = HG[gi].key
                local src = map[key]
                if src then
                    local hg = getHGData(e, key, HG[gi].defCnt)
                    for s = 1, table.getn(src) do
                        if src[s] and src[s] ~= "" then hg.slots[s] = src[s] end
                    end
                end
            end
        end

        -- Stockage des packs de trash perso : db.v3trash[raid] = { "nom", ... }
        local function getTrashDB()
            local db = RT.Store.DB()
            if not db.v3trash then db.v3trash = {} end
            return db.v3trash
        end

        -- Applique un preset de trash (mêmes champs que preset boss)
        local function applyTrashPreset(e, preset)
            if type(preset) ~= "table" then return end
            e.tc = preset.tc or e.tc or 2
            local marks = preset.marks or {}
            if not e.tanks then e.tanks = {} end
            for i = 1, e.tc do
                if type(e.tanks[i]) ~= "table" then e.tanks[i] = { name="", mark=0 } end
                e.tanks[i].mark = PRESET_MARK[marks[i] or ""] or e.tanks[i].mark or 0
            end
            if (e.note or "") == "" then e.note = preset.note or "" end
        end

        -- Chargement d'un boss OU d'un trash
        local function loadBoss(boss)
            det._current = boss
            local tp = det._trashMap and det._trashMap[boss]
            if tp then
                bossTitle:SetText("|cffFF9933» "..boss.."|r")
            else
                bossTitle:SetText("|cffFF6666"..boss.."|r")
            end
            local e = getBossEntry(boss)
            -- 1ère ouverture : charge le preset (marqueurs/note) automatiquement
            if not e._presetLoaded then
                e._presetLoaded = true
                if type(tp) == "table" then applyTrashPreset(e, tp)
                else applyPreset(boss, e) end
            end
            -- synchronise les noms tanks (par position MT) + soins depuis Assign
            applyAssignDefault(e)
            noteEB:SetText(e.note or "")
            refresh()
        end
        det._loadBoss = loadBoss

        -- Bouton : recharge le preset (force marqueurs + note)
        presetBtn:SetScript("OnClick", function()
            if not det._current then return end
            local boss = det._current
            local e = getBossEntry(boss)
            if applyPreset(boss, e) then
                applyAssignDefault(e)
                noteEB:SetText(e.note or "")
                RT.Print("|cff44FF88Preset reloaded: "..boss.."|r")
                refresh()
            else
                RT.Print("|cffFF8888Aucun preset pour: "..boss.."|r")
            end
        end)

        -- ── BUILD LISTE BOSS (+ TRASH) PAR RAID ───────────────────
        -- Pools de frames pour pouvoir reconstruire (ajout de trash)
        local hdrPool, btnPool = {}, {}

        local function getHdr(i)
            local hf = hdrPool[i]
            if not hf then
                hf = CreateFrame("Frame", nil, listChild)
                hf:SetWidth(218) hf:SetHeight(17)
                local hbg = hf:CreateTexture(nil,"BACKGROUND")
                hbg:SetAllPoints() hbg:SetTexture(0.10,0.08,0.15,0.95)
                hf._fs = hf:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                hf._fs:SetPoint("LEFT", hf, "LEFT", 5, 0)
                hdrPool[i] = hf
            end
            return hf
        end

        local function getBtn(i)
            local btn = btnPool[i]
            if not btn then
                btn = CreateFrame("Button", nil, listChild, "UIPanelButtonTemplate")
                btn:SetWidth(210) btn:SetHeight(16)
                local bfs = btn:GetFontString()
                if bfs then bfs:SetJustifyH("LEFT"); bfs:SetPoint("LEFT",btn,"LEFT",4,0) end
                btnPool[i] = btn
            end
            return btn
        end

        local function selectEntry(name, btn)
            loadBoss(name)
            if det._activeBtn then
                local af = det._activeBtn:GetNormalTexture()
                if af then af:SetVertexColor(0.25,0.20,0.30) end
            end
            local nt = btn:GetNormalTexture()
            if nt then nt:SetVertexColor(0.5,0.15,0.15) end
            det._activeBtn = btn
        end

        local function buildBossList()
            for i = 1, table.getn(hdrPool) do hdrPool[i]:Hide() end
            for i = 1, table.getn(btnPool) do btnPool[i]:Hide() end
            det._trashMap  = {}
            det._entryRaid = {}

            local grps, order = getGroupedBosses()
            local tdb = getTrashDB()
            local hi, bj = 0, 0
            local y = 0
            for ri = 1, table.getn(order) do
                local raid = order[ri]

                hi = hi + 1
                local hf = getHdr(hi)
                hf:ClearAllPoints()
                hf:SetPoint("TOPLEFT", listChild, "TOPLEFT", 2, -y)
                hf._fs:SetText("|cffFFD700"..raid.."|r")
                hf:Show()
                y = y + 19

                -- Boss (depuis les tactiques)
                local bosses = grps[raid] or {}
                for bi = 1, table.getn(bosses) do
                    local nm = bosses[bi]
                    bj = bj + 1
                    local btn = getBtn(bj)
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", listChild, "TOPLEFT", 8, -y)
                    btn:SetText(nm)
                    local bfs = btn:GetFontString(); if bfs then bfs:SetTextColor(1,1,1) end
                    det._entryRaid[nm] = raid
                    local n = nm
                    btn:SetScript("OnClick", function() selectEntry(n, btn) end)
                    btn:Show()
                    y = y + 17
                end

                -- Trash : presets + perso
                local tl = {}
                local pre = RT_TRASH_PRESETS[raid]
                if pre then
                    for k = 1, table.getn(pre) do
                        table.insert(tl, { name=pre[k].name, preset=pre[k] })
                    end
                end
                local cust = tdb[raid] or {}
                for k = 1, table.getn(cust) do
                    table.insert(tl, { name=cust[k], preset=true })
                end
                for k = 1, table.getn(tl) do
                    local t = tl[k]
                    bj = bj + 1
                    local btn = getBtn(bj)
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", listChild, "TOPLEFT", 8, -y)
                    btn:SetText("» "..t.name)
                    local bfs = btn:GetFontString(); if bfs then bfs:SetTextColor(1.0,0.6,0.2) end
                    det._entryRaid[t.name] = raid
                    det._trashMap[t.name]  = t.preset
                    local n = t.name
                    btn:SetScript("OnClick", function() selectEntry(n, btn) end)
                    btn:Show()
                    y = y + 17
                end

                y = y + 4
            end
            listChild:SetHeight(y + 4)
        end
        buildBossList()

        -- Ajout d'un trash perso (appelé par la popup)
        RT_BossDoAddTrash = function(name)
            name = name or ""
            name = string.gsub(name, "^%s+", "")
            name = string.gsub(name, "%s+$", "")
            if name == "" then return end
            local raid = det._addTrashRaid
            if not raid then return end
            local tdb = getTrashDB()
            tdb[raid] = tdb[raid] or {}
            table.insert(tdb[raid], name)
            buildBossList()
            RT.Print("|cff44FF88Trash added to "..raid..": "..name.."|r")
        end

        panel._detail = det

        -- Hook global : Assign peut forcer un reload immédiat sans passer par show()
        RT3_BossReload = function()
            local d = panel._detail
            if d and d._current and d._loadBoss then
                d._loadBoss(d._current)
            end
        end
    end,

    show = function(panel)
        local det = panel._detail
        if det and det._current and det._loadBoss then
            -- recharge le boss courant : récupère l'ordre MT à jour depuis Assign
            det._loadBoss(det._current)
        end
    end,
})

-- [v3:Consumes]
-- ============================================================
-- RT v3 - modules/Consomes.lua
-- Checklist des consommables par joueur
-- ============================================================

local _cData = {}  -- { [name] = { flask=false, food=false, pret=false } }

local COL_NAME  = 8
local COL_FLASK = 170
local COL_FOOD  = 280
local COL_PRET  = 390
local ROW_H     = 20

local function getOrCreate(name)
    if not _cData[name] then
        _cData[name] = { flask = false, food = false, pret = false }
    end
    return _cData[name]
end

RT.Modules.Register({
    id       = "consomes",
    title    = "Consumes",
    tip      = "Recommended consumables per role (flasks, potions, elixirs) to remind the raid.",
    color    = { 0.60, 1.00, 0.40 },
    tabWidth = 80,

    build = function(panel)
        local titleFS = RT.UI.Label(panel, {
            text   = "|cff99FF44Consumables|r",
            font   = "GameFontNormal",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -10 },
        })
        panel._cTitle = titleFS

        RT.UI.Button(panel, {
            text = "Reset checks", width = 100, height = 22, color = { 0.55, 0.20, 0.10 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -12, -8 },
            onClick = function()
                _cData = {}
                if panel._cRefresh then panel._cRefresh() end
            end,
        })

        RT.UI.Button(panel, {
            text = "Announce Missing", width = 130, height = 22, color = { 0.60, 0.40, 0.10 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -118, -8 },
            tooltip = "Announces the list of players not marked Ready to raid (or party) chat.",
            onClick = function()
                local missing = {}
                for name, v in pairs(_cData) do
                    if not v.pret then table.insert(missing, name) end
                end
                local chan = nil
                if GetNumRaidMembers and GetNumRaidMembers() > 0 then chan = "RAID"
                elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then chan = "PARTY" end
                if not chan then
                    RT.Print("|cffFFAA00You're not in a group — nothing announced.|r")
                elseif table.getn(missing) > 0 then
                    SendChatMessage("Not ready: " .. table.concat(missing, ", "), chan)
                else
                    SendChatMessage("Everyone is ready!", chan)
                end
            end,
        })

        RT.UI.Button(panel, {
            text = "Whisper missing", width = 116, height = 22, color = { 0.20, 0.55, 0.75 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -254, -8 },
            tooltip = "Whispers every player not marked Ready to remind them to get flask/food up.",
            onClick = function()
                local sent = 0
                for name, v in pairs(_cData) do
                    if not v.pret then
                        local target = name
                        RT.After(sent * 0.3, function()
                            SendChatMessage("[RaidTools] Reminder: get your consumes up (flask/food) — pull soon!", "WHISPER", nil, target)
                        end)
                        sent = sent + 1
                    end
                end
                if sent > 0 then
                    RT.Print("|cff44CCFF[Consumes]|r Reminder whispered to " .. sent .. " player(s).")
                else
                    RT.Print("|cff44FF88[Consumes]|r Everyone is marked ready — no whisper sent.")
                end
            end,
        })

        RT.UI.Button(panel, {
            text = "Scan Raid", width = 80, height = 22, color = { 0.20, 0.40, 0.70 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -376, -8 },
            tooltip = "Re-scans raid members and auto-detects flask/food buffs.",
            onClick = function()
                if panel._cRefresh then panel._cRefresh() end
            end,
        })

        -- Column headers
        local hdrs = {
            { COL_NAME,  "Player",  120 },
            { COL_FLASK, "Flask/Eli", 100 },
            { COL_FOOD,  "Food", 100 },
            { COL_PRET,  "Ready", 80 },
        }
        for i = 1, table.getn(hdrs) do
            local h = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            h:SetPoint("TOPLEFT", panel, "TOPLEFT", hdrs[i][1], -34)
            h:SetText("|cffAAAAFF" .. hdrs[i][2] .. "|r")
            h:SetWidth(hdrs[i][3])
        end

        local hdrSep = panel:CreateTexture(nil, "BACKGROUND")
        hdrSep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  6, -46)
        hdrSep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -46)
        hdrSep:SetHeight(1)
        hdrSep:SetTexture(0.3, 0.3, 0.5, 0.8)

        -- Scroll area for rows
        local scroll, child = RT.UI.ScrollArea(panel, {
            name       = "RT3_ConsScroll",
            anchor     = { "TOPLEFT", panel, "TOPLEFT", 6, -48 },
            childWidth = 680,
        })
        scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)

        -- Pre-create 40 rows
        local rows = {}
        for i = 1, 40 do
            local rf = CreateFrame("Frame", nil, child)
            rf:SetHeight(ROW_H)
            rf:SetPoint("TOPLEFT",  child, "TOPLEFT",  0, -(i - 1) * ROW_H)
            rf:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -(i - 1) * ROW_H)

            if math.mod(i, 2) == 0 then
                local bg = rf:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetTexture(0.08, 0.08, 0.12, 0.5)
            end

            local nameLbl = rf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameLbl:SetPoint("LEFT", rf, "LEFT", COL_NAME, 0)
            nameLbl:SetWidth(150)
            nameLbl:SetJustifyH("LEFT")
            rf._name = nameLbl

            local makeCheck = function(colX, key)
                local btn = CreateFrame("Button", nil, rf)
                btn:SetWidth(90)
                btn:SetHeight(ROW_H - 2)
                btn:SetPoint("LEFT", rf, "LEFT", colX, 0)
                local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                fs:SetAllPoints()
                fs:SetJustifyH("CENTER")
                fs:SetText("|cff444444[ ]|r")
                btn._fs  = fs
                btn._key = key
                btn:EnableMouse(true)
                btn:EnableMouseWheel(true)
                btn:SetScript("OnMouseWheel", function() RT3_FwdWheel(this, arg1) end)
                btn:SetScript("OnClick", function()
                    local pname = rf._playerName
                    if not pname then return end
                    local v = getOrCreate(pname)
                    v[key] = not v[key]
                    if v[key] then
                        fs:SetText("|cff44FF44[X]|r")
                    else
                        fs:SetText("|cff444444[ ]|r")
                    end
                    if key == "pret" and panel._cRefresh then panel._cRefresh() end
                end)
                return btn
            end

            rf._btnFlask = makeCheck(COL_FLASK, "flask")
            rf._btnFood  = makeCheck(COL_FOOD,  "food")
            rf._btnPret  = makeCheck(COL_PRET,  "pret")
            rf._playerName = nil
            rf:Hide()
            rows[i] = rf
        end
        child:SetHeight(40 * ROW_H)

        local function refresh()
            -- Build name→unit map before sorting (pour conserver l'association)
            local names    = {}
            local unitOfName = {}
            if GetNumRaidMembers then
                local n = GetNumRaidMembers()
                for i = 1, n do
                    local name = GetRaidRosterInfo(i)
                    if name then
                        table.insert(names, name)
                        unitOfName[name] = "raid" .. i
                    end
                end
            end
            table.sort(names)
            local count = table.getn(names)
            for i = 1, 40 do
                local rf = rows[i]
                if i <= count then
                    local pname = names[i]
                    local unit  = unitOfName[pname] or ""
                    rf._playerName = pname
                    rf._name:SetText(pname)
                    local v = getOrCreate(pname)
                    -- Auto-detect flask/food via UnitBuff (utilise RT_UnitHasBuffPattern du v2)
                    if unit ~= "" and RT_UnitHasBuffPattern and RT_FLASK_TEX then
                        if RT_UnitHasBuffPattern(unit, RT_FLASK_TEX) then
                            v.flask = true
                        end
                    end
                    if unit ~= "" and RT_UnitHasBuffPattern and RT_FOOD_TEX then
                        if RT_UnitHasBuffPattern(unit, RT_FOOD_TEX) then
                            v.food = true
                        end
                    end
                    if v.flask then rf._btnFlask._fs:SetText("|cff44FF44[X]|r")
                    else             rf._btnFlask._fs:SetText("|cff444444[ ]|r") end
                    if v.food  then rf._btnFood._fs:SetText("|cff44FF44[X]|r")
                    else             rf._btnFood._fs:SetText("|cff444444[ ]|r")  end
                    if v.pret  then rf._btnPret._fs:SetText("|cff44FF44[X]|r")
                    else             rf._btnPret._fs:SetText("|cff444444[ ]|r")  end
                    rf:Show()
                else
                    rf._playerName = nil
                    rf:Hide()
                end
            end
            child:SetHeight(count * ROW_H + 4)
            if panel._cTitle then
                local ready = 0
                for j = 1, count do
                    local v = _cData[names[j]]
                    if v and v.pret then ready = ready + 1 end
                end
                if count > 0 then
                    local col = (ready == count) and "44FF44" or "FFAA00"
                    panel._cTitle:SetText("|cff99FF44Consumables|r  |cff" .. col .. ready .. "/" .. count .. " ready|r")
                else
                    panel._cTitle:SetText("|cff99FF44Consumables|r  |cff888888(not in a raid)|r")
                end
            end
        end
        panel._cRefresh = refresh
    end,

    show = function(panel)
        if panel._cRefresh then panel._cRefresh() end
    end,
})

-- [v3:WhisperBot]
-- ============================================================
-- RT v3 - modules/WhisperBot.lua
-- Bot whisper + recrutement intelligent (1 seul local chunk)
-- ============================================================

local WB = {
    log         = {},
    disp        = nil,   -- FontString log
    pending     = {},    -- { [name] = { step, gear } }
    roster      = {},    -- { [name] = { role, gear } }
    specPending = {},    -- { [name] = true }  joueurs à qui on a demandé leur spé
    counts      = { tank=0, heal=0, dps=0 },
    cDisp       = nil,   -- FontString compteurs
    GEAR_RANK   = { pregear=1, phase1=2, phase2=3 },
    GEAR_LABEL  = { pregear="Pre-Gear", phase1="Phase 1", phase2="Phase 2" },
}

-- Tokens reconnus dans une réponse texte → spé canonique (menu RT).
-- L'ordre compte : on teste du plus spécifique au plus générique.
WB.SPEC_TOKENS = {
    {"protection","Prot"}, {"prot","Prot"}, {"tank","Prot"},
    {"fury","Fury"}, {"furie","Fury"}, {"arms","Arms"}, {"armes","Arms"},
    {"retri","Retri"}, {"vindi","Retri"}, {"ret","Retri"},
    {"holy","Holy"}, {"sacre","Holy"}, {"sacré","Holy"},
    {"disc","Disc"}, {"shadow","Shadow"}, {"ombre","Shadow"},
    {"resto","Resto"}, {"restau","Resto"}, {"soin","Resto"}, {"heal","Resto"},
    {"feral","Feral"}, {"farouche","Feral"},
    {"balance","Balance"}, {"equilibre","Balance"}, {"boomkin","Balance"},
    {"enha","Enh"}, {"enh","Enh"},
    {"elem","Elem"}, {"elementaire","Elem"}, {"ele","Elem"},
    {"fire","Fire"}, {"feu","Fire"}, {"frost","Frost"}, {"givre","Frost"}, {"gel","Frost"},
    {"arcane","Arcane"},
    {"affli","Affli"}, {"demono","Demo"}, {"demo","Demo"}, {"destru","Destro"}, {"destro","Destro"},
    {"combat","Combat"}, {"assa","Assa"}, {"finesse","Assa"}, {"subt","Subt"},
    {"beast","BM"}, {"bete","BM"}, {"bm","BM"}, {"precision","MM"}, {"marks","MM"}, {"mm","MM"},
    {"surv","Surv"}, {"survie","Surv"},
}

-- Devine la spé canonique depuis un texte libre (réponse au whisper).
function WB.specFromText(text)
    local s = string.lower(text or "")
    for i = 1, table.getn(WB.SPEC_TOKENS) do
        local tok = WB.SPEC_TOKENS[i]
        if string.find(s, tok[1], 1, true) then return tok[2] end
    end
    return nil
end

-- Construit la question de spé, adaptée à la classe du joueur si connue
-- (ex: Warrior -> "Arms, Fury or Prot?"). Sinon question générique.
function WB.specQuestion(classToken)
    local cls = string.upper(classToken or "")
    local specs = RT3_TALENT_SPECS and RT3_TALENT_SPECS[cls]
    if not specs then
        return "[RaidTools] What's your spec? Just reply with your spec (e.g. Prot, Resto, Fury, Shadow, Enh...). Thanks!"
    end
    return "[RaidTools] What's your spec? (" .. specs[1] .. " / " .. specs[2] .. " / " .. specs[3] .. ") Just reply with one. Thanks!"
end

-- Envoie un whisper à chaque membre du raid pour demander sa spé.
-- onlyMissing=true → seulement ceux sans spé connue.
function WB.askSpecs(onlyMissing)
    -- 1) les joueurs qui ont RT répondent automatiquement (addon)
    if RT3_RequestSpecsAddon then RT3_RequestSpecsAddon() end
    -- 2) whisper aux autres
    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    if n == 0 then
        RT.Print("|cffFFAA00You're not in a raid (RaidTools users' specs still come in).|r")
        return
    end
    local me  = UnitName and UnitName("player") or ""
    local db  = RT.Store.Roster()
    local sent = 0
    local hasRT = RT_SYNC_MEMBERS or {}
    for i = 1, n do
        local pname, _, _, _, _, classToken = GetRaidRosterInfo(i)
        if pname and pname ~= "" and pname ~= me then
            local known = db[pname] and db[pname].spec
            if hasRT[pname] then
                -- déjà RaidTools : répond en silence via addon, pas de whisper
            elseif not (onlyMissing and known and known ~= "") then
                WB.specPending[pname] = true
                -- envoi étalé (anti-spam / déconnexion) : 0.4s entre chaque
                local target = pname
                local cls = classToken or (db[pname] and db[pname].class) or ""
                local msg = WB.specQuestion(cls)
                RT.After(sent * 0.4, function()
                    SendChatMessage(RT_ChatSafe(msg), "WHISPER", nil, target)
                end)
                sent = sent + 1
            end
        end
    end
    RT.Print("|cff44CCFF[Spec]|r Request: " .. sent .. " whisper(s) sent; RaidTools users reply silently. Answers fill the roster.")
end

-- Point d'entrée global : appelable depuis le Roster (bouton Auto-roles) ou
-- tout autre module, même si l'onglet WhisperBot n'a jamais été ouvert.
function RT3_AskSpecs(onlyMissing) return WB.askSpecs(onlyMissing) end

-- Traite la réponse d'un joueur à qui on a demandé sa spé.
function WB.handleSpecReply(sender, text)
    WB.specPending[sender] = nil
    local db   = RT.Store.Roster()
    local cls  = db[sender] and db[sender].class or ""
    local spec = WB.specFromText(text)
    if not spec then
        -- pas de token reconnu : on stocke le texte brut, le rôle est déduit si possible
        spec = text
    end
    if RT3_SetPlayerSpec then RT3_SetPlayerSpec(sender, nil, spec) end
    local role = (db[sender] and db[sender].role) or "?"
    SendChatMessage(RT_ChatSafe("Thanks! Spec recorded: " .. spec .. " (" .. role .. ")."), "WHISPER", nil, sender)
    WB.addLog("|cff44CCFF[Spec]|r " .. sender .. " = " .. spec .. " -> " .. role)
end

-- ============================================================
-- LFM (annonce de recrutement) + Compo (annonce de composition)
-- ============================================================
WB.LFM_CHANS  = { "SAY", "YELL", "GUILD", "WORLD", "LFG" }
WB.LFM_LABELS = { SAY="Say", YELL="Yell", GUILD="Guild", WORLD="World", LFG="LFG" }

-- Places encore à pourvoir (max - actuels), jamais négatif.
function WB.remainingSlots(bd)
    local s = (bd.recruit and bd.recruit.slots) or {}
    local function rem(k) local v = (s[k] or 0) - (WB.counts[k] or 0); if v < 0 then v = 0 end; return v end
    return rem("tank"), rem("heal"), rem("dps")
end

-- Construit le texte LFM en remplaçant {tank} {heal} {dps}.
function WB.buildLFMText(bd)
    local msg = (bd.lfm and bd.lfm.msg) or ""
    if msg == "" then return "" end
    local t, h, d = WB.remainingSlots(bd)
    msg = string.gsub(msg, "{tank}", tostring(t))
    msg = string.gsub(msg, "{heal}", tostring(h))
    msg = string.gsub(msg, "{dps}",  tostring(d))
    return msg
end

-- Résout (chatType, chanArg) pour SendChatMessage selon le canal choisi.
function WB.resolveChannel(key)
    if key == "WORLD" then
        local idx = GetChannelName and GetChannelName("World") or 0
        if idx and idx > 0 then return "CHANNEL", idx end
        return nil
    elseif key == "LFG" then
        local idx = GetChannelName and (GetChannelName("LookingForGroup") or GetChannelName("World")) or 0
        if idx and idx > 0 then return "CHANNEL", idx end
        return nil
    elseif key == "GUILD" then
        return "GUILD", nil
    elseif key == "YELL" then
        return "YELL", nil
    end
    return "SAY", nil
end

function WB.postLFM(bd)
    local text = WB.buildLFMText(bd)
    if text == "" then
        RT.Print("|cffFFAA00[LFM] Type your LFM message in the field first.|r")
        return
    end
    local key = (bd.lfm and bd.lfm.channel) or "SAY"
    local ctype, carg = WB.resolveChannel(key)
    if not ctype then
        RT.Print("|cffFF4444[LFM] Channel '" .. (WB.LFM_LABELS[key] or key) .. "' not found (not joined?). Try Say/Yell.|r")
        return
    end
    SendChatMessage(RT_ChatSafe(text), ctype, nil, carg)
    WB.addLog("|cff66DD66[LFM " .. (WB.LFM_LABELS[key] or key) .. "]|r " .. text)
end

-- Compte la composition depuis le roster RT.
function WB.buildCompoText()
    local db = RT.Store.Roster()
    local c = { Tank=0, Heal=0, Melee=0, Ranged=0, DPS=0 }
    local total = 0
    for _, data in pairs(db) do
        local r = RT.NormRole(data.role or "DPS")
        c[r] = (c[r] or 0) + 1
        total = total + 1
    end
    return "Comp: " .. c.Tank .. " Tank, " .. c.Heal .. " Heal, " ..
           c.Melee .. " Melee, " .. c.Ranged .. " Ranged" ..
           (c.DPS > 0 and (", " .. c.DPS .. " DPS") or "") ..
           "  (" .. total .. ")"
end

-- Annonce la compo dans le chat du raid (ou groupe).
function WB.announceCompo()
    local text = WB.buildCompoText()
    local chan = "SAY"
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then chan = "RAID"
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then chan = "PARTY" end
    SendChatMessage(RT_ChatSafe(text), chan, nil, nil)
    WB.addLog("|cff88CCFF[Comp]|r " .. text)
end

function WB.getData()
    local db = RT.Store.DB()
    if not db.v3bot then
        db.v3bot = {
            enabled    = false,
            autoinvite = false,
            templates  = {
                loot = "Your loot assignment will be announced before the pull.",
                join = "Welcome! One moment, I'm checking your application.",
                info = "Whisper ?join to apply for the raid.",
            },
            recruit = { minGear="phase1", slots={ tank=2, heal=6, dps=22 } },
            lfm     = { msg="LFM raid - need {tank} tank {heal} heal {dps} dps - /w me", channel="SAY" },
        }
    end
    if db.v3bot.autoinvite == nil then db.v3bot.autoinvite = false end
    if not db.v3bot.recruit then
        db.v3bot.recruit = { minGear="phase1", slots={ tank=2, heal=6, dps=22 } }
    end
    if not db.v3bot.recruit.slots then
        db.v3bot.recruit.slots = { tank=2, heal=6, dps=22 }
    end
    if not db.v3bot.lfm then
        db.v3bot.lfm = { msg="LFM raid - need {tank} tank {heal} heal {dps} dps - /w me", channel="SAY" }
    end
    if db.v3bot.tacAuto == nil then db.v3bot.tacAuto = true end
    -- Migration FR → EN : remplace UNIQUEMENT les textes par défaut non
    -- personnalisés (ceux encore égaux aux anciens défauts français).
    db.v3bot.templates = db.v3bot.templates or {}
    local OLD = {
        loot = "Ton attribution sera annoncee avant le pull.",
        join = "Bienvenue ! Un instant, je verifie ton dossier.",
        info = "Tape ?join pour postuler au raid.",
    }
    local NEWT = {
        loot = "Your loot assignment will be announced before the pull.",
        join = "Welcome! One moment, I'm checking your application.",
        info = "Whisper ?join to apply for the raid.",
    }
    for k, v in pairs(OLD) do
        if db.v3bot.templates[k] == v then db.v3bot.templates[k] = NEWT[k] end
    end
    if db.v3bot.lfm.msg == "LFM raid - besoin {tank} tank {heal} heal {dps} dps - /w moi" then
        db.v3bot.lfm.msg = "LFM raid - need {tank} tank {heal} heal {dps} dps - /w me"
    end
    return db.v3bot
end

function WB.addLog(line)
    table.insert(WB.log, line)
    if table.getn(WB.log) > 40 then table.remove(WB.log, 1) end
    if WB.disp then WB.disp:SetText(table.concat(WB.log, "\n")) end
end

function WB.updateCounts(bd)
    if not WB.cDisp then return end
    local s = (bd.recruit and bd.recruit.slots) or { tank=0, heal=0, dps=0 }
    WB.cDisp:SetText(
        "|cffFF8888Tank " .. WB.counts.tank .. "/" .. (s.tank or 0) .. "|r   " ..
        "|cff88FF88Heal " .. WB.counts.heal .. "/" .. (s.heal or 0) .. "|r   " ..
        "|cffAAAAFFDPS "  .. WB.counts.dps  .. "/" .. (s.dps  or 0) .. "|r"
    )
end

function WB.parseGear(cmd)
    if string.find(cmd, "phase2") or string.find(cmd, "p2") or cmd == "2" then
        return "phase2"
    elseif string.find(cmd, "phase1") or string.find(cmd, "p1") or cmd == "1" then
        return "phase1"
    elseif string.find(cmd, "pregear") or string.find(cmd, "pre") or string.find(cmd, "p0") or cmd == "0" then
        return "pregear"
    end
    return nil
end

function WB.parseRole(cmd)
    if string.find(cmd, "^tank") or string.find(cmd, "^mt") or string.find(cmd, "^ot") then
        return "tank"
    elseif string.find(cmd, "^heal") or string.find(cmd, "^soig") or string.find(cmd, "^soin") then
        return "heal"
    elseif string.find(cmd, "^dps") or string.find(cmd, "^cac") or
           string.find(cmd, "^mel") or string.find(cmd, "^rdps") or
           string.find(cmd, "^dd") then
        return "dps"
    end
    return nil
end

function WB.recruitStep(sender, cmd, bd)
    local state = WB.pending[sender]
    if not state then return end
    local rc = bd.recruit or {}

    if state.step == "waiting_gear" then
        local gear = WB.parseGear(cmd)
        if not gear then
            SendChatMessage("I didn't get that. Reply: pregear / phase1 / phase2", "WHISPER", nil, sender)
            WB.addLog("|cffAAAAFF[" .. sender .. "]|r " .. cmd .. " -> (unknown gear)")
            return
        end
        local minRank  = WB.GEAR_RANK[rc.minGear or "phase1"] or 2
        local candRank = WB.GEAR_RANK[gear] or 0
        if candRank < minRank then
            WB.pending[sender] = nil
            local needed = WB.GEAR_LABEL[rc.minGear or "phase1"] or "Phase 1"
            SendChatMessage("Sorry! Minimum gear required: " .. needed .. ". Keep gearing up!", "WHISPER", nil, sender)
            WB.addLog("|cffFF4444[DECLINED gear]|r " .. sender .. " (" .. (WB.GEAR_LABEL[gear] or gear) .. ")")
        else
            WB.pending[sender].step = "waiting_role"
            WB.pending[sender].gear = gear
            local s   = rc.slots or {}
            local msg = "Gear OK (" .. (WB.GEAR_LABEL[gear] or gear) .. ")! Which role? (tank/heal/dps)" ..
                        "  [Tank " .. WB.counts.tank .. "/" .. (s.tank or 0) ..
                        " Heal " .. WB.counts.heal .. "/" .. (s.heal or 0) ..
                        " DPS "  .. WB.counts.dps  .. "/" .. (s.dps  or 0) .. "]"
            SendChatMessage(msg, "WHISPER", nil, sender)
            WB.addLog("|cffFFD700[" .. sender .. "]|r gear=" .. (WB.GEAR_LABEL[gear] or gear) .. " -> role?")
        end

    elseif state.step == "waiting_role" then
        if cmd == "?cancel" or cmd == "cancel" or cmd == "annuler" then
            WB.pending[sender] = nil
            SendChatMessage("Application cancelled.", "WHISPER", nil, sender)
            WB.addLog("|cff888888[" .. sender .. "]|r cancelled")
            return
        end
        local role = WB.parseRole(cmd)
        if not role then
            SendChatMessage("I didn't get that. Reply: tank / heal / dps", "WHISPER", nil, sender)
            WB.addLog("|cffAAAAFF[" .. sender .. "]|r " .. cmd .. " -> (unknown role)")
            return
        end
        local s       = rc.slots or {}
        local slotMax = s[role] or 0
        local slotCur = WB.counts[role] or 0
        if slotCur >= slotMax then
            WB.pending[sender] = nil
            local alts = {}
            for _, r in ipairs({"tank","heal","dps"}) do
                if (WB.counts[r] or 0) < (s[r] or 0) then
                    table.insert(alts, string.upper(r))
                end
            end
            local altStr = table.getn(alts) > 0 and ("  Open: " .. table.concat(alts," / ")) or "  Raid is full."
            SendChatMessage(string.upper(role) .. " spots are full (" .. slotCur .. "/" .. slotMax .. ")." .. altStr, "WHISPER", nil, sender)
            WB.addLog("|cffFF8844[FULL " .. string.upper(role) .. "]|r " .. sender)
        else
            WB.counts[role] = slotCur + 1
            WB.roster[sender] = { role=role, gear=state.gear }
            WB.pending[sender] = nil
            InviteByName(sender)
            SendChatMessage("Welcome! Accepted as " .. string.upper(role) .. " (" .. (WB.GEAR_LABEL[state.gear] or "?") .. "). Invite sent!", "WHISPER", nil, sender)
            WB.addLog("|cff44FF88[ACCEPTED " .. string.upper(role) .. "]|r " .. sender)
            WB.updateCounts(bd)
        end
    end
end

-- ============================================================
-- Tactics hub (inspiré de Tactica) : détection du boss ciblé,
-- fenêtre de post rapide, préview locale, tactiques custom.
-- ============================================================

WB.tacSeen = {}   -- boss déjà suggérés cette session (anti-spam)

-- Tactique correspondant à la cible courante (hostile, vivante) — match exact.
function WB.tacDetect()
    if not UnitExists or not UnitExists("target") then return nil end
    if UnitIsDead and UnitIsDead("target") then return nil end
    if UnitCanAttack and not UnitCanAttack("player", "target") then return nil end
    local tname = UnitName("target")
    if not tname or tname == "" then return nil end
    if RT_Tactics and RT_Tactics.Find then
        local t = RT_Tactics.Find(tname)
        -- Find fait aussi du match partiel : ne garde que l'exact (anti faux-positif)
        if t and string.lower(t.boss or "") == string.lower(tname) then return t end
    end
    return nil
end

function WB.tacFmt(t)
    if not t then return "|cff888888Select a boss on the left, or target one in-game.|r" end
    local L = { "|cffFFD700" .. (t.boss or "?") .. "|r  |cff888888" .. (t.raid or "") .. "|r", " " }
    for i = 1, table.getn(t.lines or {}) do
        table.insert(L, "|cffDDDDDD" .. t.lines[i] .. "|r")
    end
    return table.concat(L, "\n")
end

function WB.tacSelect(t)
    WB.tacSel = t
    if WB.tacFrame then
        if WB.tacFrame._prev then WB.tacFrame._prev:SetText(WB.tacFmt(t)) end
        if WB.tacFrame._custEB and t then WB.tacFrame._custEB:SetText(t.boss or "") end
    end
end

-- Poste la tactique sélectionnée. channel="SELF" = préview locale dans le chat.
function WB.tacPost(channel)
    local t = WB.tacSel
    if not t then RT.Print("|cffFFAA00[Tactics] Select a boss first.|r") return end
    if channel == "SELF" then
        RT.Print("|cffFFD700[Tactics preview] " .. t.boss .. "|r")
        for i = 1, table.getn(t.lines or {}) do RT.Print("  " .. t.lines[i]) end
        return
    end
    if RT_Tactics and RT_Tactics.Post then RT_Tactics.Post(t.boss, channel) end
end

-- Ouvre (et crée au besoin) la fenêtre Tactics. preselect = tactique à afficher.
function WB.tacOpen(preselect)
    if not WB.tacFrame then
        local f = CreateFrame("Frame", "RT3_WBTacFrame", UIParent)
        WB.tacFrame = f
        f:SetWidth(600) f:SetHeight(430)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        f:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0.05, 0.05, 0.09, 0.96)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", f, "TOP", 0, -10)
        title:SetText("|cffFFD700Boss Tactics|r  |cff666666— post strategies to your raid|r")

        local closeB = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeB:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

        -- Auto-detect toggle
        local autoBtn = RT.UI.Button(f, {
            text = "Auto-detect: ON", width = 122, height = 20, color = { 0.10, 0.50, 0.10 },
            anchor = { "TOPLEFT", f, "TOPLEFT", 12, -28 },
            tooltip = "When ON: targeting a raid boss (while in a group, out of combat) opens this window with its strategy preselected.",
        })
        autoBtn:SetScript("OnClick", function()
            local bd = WB.getData()
            bd.tacAuto = not bd.tacAuto
            local tex = autoBtn:GetNormalTexture()
            if bd.tacAuto then
                autoBtn:SetText("Auto-detect: ON")
                if tex then tex:SetVertexColor(0.10, 0.50, 0.10) end
            else
                autoBtn:SetText("Auto-detect: OFF")
                if tex then tex:SetVertexColor(0.45, 0.15, 0.10) end
            end
        end)
        f._autoBtn = autoBtn

        RT.UI.Button(f, {
            text = "Use my target", width = 108, height = 20, color = { 0.55, 0.35, 0.10 },
            anchor = { "TOPLEFT", f, "TOPLEFT", 140, -28 },
            tooltip = "Selects the strategy matching your current target.",
            onClick = function()
                local t = WB.tacDetect()
                if t then WB.tacSelect(t)
                else RT.Print("|cffFFAA00[Tactics] No known boss targeted.|r") end
            end,
        })

        -- Search + boss list (left)
        local search = CreateFrame("EditBox", "RT3_WBTacSearch", f, "InputBoxTemplate")
        search:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -54)
        search:SetWidth(200) search:SetHeight(20)
        search:SetAutoFocus(false)
        search:SetScript("OnEscapePressed", function() search:ClearFocus() end)

        local scroll, child = RT.UI.ScrollArea(f, {
            name = "RT3_WBTacScroll",
            anchor = { "TOPLEFT", f, "TOPLEFT", 12, -78 },
            childWidth = 210,
        })
        scroll:SetWidth(220)
        scroll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 66)

        local list = RT.UI.List(child, {
            rowHeight = 17, gap = 1,
            makeRow = function(l)
                local b = CreateFrame("Button", nil, l, "UIPanelButtonTemplate")
                b:SetHeight(17)
                local fs = b:GetFontString()
                if fs then fs:SetPoint("LEFT", b, "LEFT", 4, 0) end
                return b
            end,
            fillRow = function(row, item)
                local fs = row:GetFontString()
                if item.type == "header" then
                    row:SetText("|cffFFD700" .. (item.raid or "?") .. "|r")
                    row:EnableMouse(false)
                    local nt = row:GetNormalTexture()
                    local ht = row:GetHighlightTexture()
                    if nt then nt:SetAlpha(0) end
                    if ht then ht:SetAlpha(0) end
                else
                    row:SetText("  " .. (item.boss or "?"))
                    row:EnableMouse(true)
                    local nt = row:GetNormalTexture()
                    local ht = row:GetHighlightTexture()
                    if nt then nt:SetAlpha(1) end
                    if ht then ht:SetAlpha(1) end
                    local tac = item
                    row:SetScript("OnClick", function() WB.tacSelect(tac) end)
                end
                if fs then fs:SetJustifyH("LEFT") end
            end,
        })
        list:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
        list:SetWidth(205)

        local function refreshList()
            local query = search:GetText() or ""
            local items = {}
            local all = (RT_Tactics and RT_Tactics.FindAll) and RT_Tactics.FindAll(query) or {}
            if string.len(query) == 0 then
                local byRaid, order = {}, {}
                for i = 1, table.getn(all) do
                    local t = all[i]
                    local r = t.raid or "Misc"
                    if not byRaid[r] then byRaid[r] = {}; table.insert(order, r) end
                    table.insert(byRaid[r], t)
                end
                table.sort(order)
                for ri = 1, table.getn(order) do
                    table.insert(items, { type = "header", raid = order[ri] })
                    local bosses = byRaid[order[ri]]
                    table.sort(bosses, function(a, b) return (a.boss or "") < (b.boss or "") end)
                    for bi = 1, table.getn(bosses) do table.insert(items, bosses[bi]) end
                end
            else
                items = all
            end
            list:SetItems(items)
            child:SetHeight(list:GetHeight() or 1)
        end
        search:SetScript("OnTextChanged", refreshList)
        f._refreshList = refreshList

        -- Preview (right)
        local prev = RT.UI.TextScroll(f, {
            name = "RT3_WBTacPreview",
            anchor = { "TOPLEFT", f, "TOPLEFT", 246, -54 },
            width = 320, font = "GameFontHighlightSmall",
        })
        prev.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 66)
        f._prev = prev

        -- Custom tactic row
        local custLb = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        custLb:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 44)
        custLb:SetText("|cff69CCF0Custom:|r boss name + text, Save. Custom entries appear in the list and in ?strat.")

        local custEB = CreateFrame("EditBox", "RT3_WBTacCustBoss", f, "InputBoxTemplate")
        custEB:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 22)
        custEB:SetWidth(120) custEB:SetHeight(18) custEB:SetAutoFocus(false)
        custEB:SetScript("OnEscapePressed", function() custEB:ClearFocus() end)
        f._custEB = custEB

        local custTxt = CreateFrame("EditBox", "RT3_WBTacCustText", f, "InputBoxTemplate")
        custTxt:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 146, 22)
        custTxt:SetWidth(250) custTxt:SetHeight(18) custTxt:SetAutoFocus(false)
        custTxt:SetScript("OnEscapePressed", function() custTxt:ClearFocus() end)
        f._custTxt = custTxt

        RT.UI.Button(f, {
            text = "Save", width = 52, height = 20, color = { 0.15, 0.50, 0.20 },
            anchor = { "BOTTOMLEFT", f, "BOTTOMLEFT", 402, 21 },
            tooltip = "Saves (or replaces) a custom tactic for this boss name.",
            onClick = function()
                local b = custEB:GetText() or ""
                local x = custTxt:GetText() or ""
                if RT_Tactics and RT_Tactics.AddCustom and RT_Tactics.AddCustom(b, x) then
                    custTxt:SetText("")
                    if f._refreshList then f._refreshList() end
                else
                    RT.Print("|cffFFAA00[Tactics] Enter a boss name AND a tactic text.|r")
                end
            end,
        })
        RT.UI.Button(f, {
            text = "Delete", width = 58, height = 20, color = { 0.50, 0.15, 0.10 },
            anchor = { "BOTTOMLEFT", f, "BOTTOMLEFT", 458, 21 },
            tooltip = "Deletes the custom tactic with this boss name.",
            onClick = function()
                if RT_Tactics and RT_Tactics.DeleteCustom then
                    RT_Tactics.DeleteCustom(custEB:GetText() or "")
                    if f._refreshList then f._refreshList() end
                end
            end,
        })

        -- Bottom action row
        RT.UI.Button(f, {
            text = "Post /Raid", width = 96, height = 22, color = { 1.00, 0.55, 0.20 },
            anchor = { "BOTTOMLEFT", f, "BOTTOMLEFT", 246, 0 },
            onClick = function() WB.tacPost("RAID") end,
        })
        RT.UI.Button(f, {
            text = "Post /Party", width = 96, height = 22,
            anchor = { "BOTTOMLEFT", f, "BOTTOMLEFT", 346, 0 },
            onClick = function() WB.tacPost("PARTY") end,
        })
        RT.UI.Button(f, {
            text = "Preview", width = 80, height = 22, color = { 0.30, 0.40, 0.55 },
            anchor = { "BOTTOMLEFT", f, "BOTTOMLEFT", 446, 0 },
            tooltip = "Prints the strategy only for you (chat), without sending anything to the raid.",
            onClick = function() WB.tacPost("SELF") end,
        })
    end

    -- refresh state
    local bd = WB.getData()
    local autoBtn = WB.tacFrame._autoBtn
    if autoBtn then
        local tex = autoBtn:GetNormalTexture()
        if bd.tacAuto then
            autoBtn:SetText("Auto-detect: ON")
            if tex then tex:SetVertexColor(0.10, 0.50, 0.10) end
        else
            autoBtn:SetText("Auto-detect: OFF")
            if tex then tex:SetVertexColor(0.45, 0.15, 0.10) end
        end
    end
    if WB.tacFrame._refreshList then WB.tacFrame._refreshList() end
    if preselect then WB.tacSelect(preselect)
    else WB.tacSelect(WB.tacSel) end
    WB.tacFrame:Show()
end

-- Event frame (stored in WB, not as a chunk-level local)
WB.frame = CreateFrame("Frame", "RT3_WBFrame")
WB.frame:RegisterEvent("CHAT_MSG_WHISPER")
WB.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
WB.frame:SetScript("OnEvent", function()
    if event == "PLAYER_TARGET_CHANGED" then
        -- Suggestion façon Tactica : boss connu ciblé → ouvre la fenêtre (1x/boss)
        local bd = WB.getData()
        if not bd.tacAuto then return end
        if UnitAffectingCombat and UnitAffectingCombat("player") then return end
        local grp = (GetNumRaidMembers and GetNumRaidMembers() or 0)
                  + (GetNumPartyMembers and GetNumPartyMembers() or 0)
        if grp == 0 then return end
        local t = WB.tacDetect()
        if t and not WB.tacSeen[t.boss] then
            WB.tacSeen[t.boss] = true
            RT.Print("|cffFFD700[Tactics]|r Boss detected: |cffFF7D0A" .. t.boss .. "|r")
            WB.tacOpen(t)
        end
        return
    end
    if event ~= "CHAT_MSG_WHISPER" then return end

    local msg    = arg1 or ""
    local sender = arg2 or ""

    -- Réponse à une demande de spé (capturée même si le BOT est OFF)
    if WB.specPending[sender] then
        WB.handleSpecReply(sender, msg)
        return
    end

    local bd = WB.getData()
    if not bd.enabled then return end

    local cmd    = string.lower(msg)
    cmd = string.gsub(cmd, "^%s+", "")
    cmd = string.gsub(cmd, "%s+$", "")
    -- Accepte les commandes avec OU sans préfixe (?, !, ., /) et espaces:
    -- "join", "?join", "! join", "/join" deviennent tous "join"
    local c2 = string.gsub(cmd, "^[%?%!%./]+%s*", "")

    -- Recruitment conversation in progress?
    if bd.autoinvite and WB.pending[sender] then
        WB.recruitStep(sender, c2, bd)
        return
    end

    local reply  = nil
    local didAct = false

    if string.find(c2, "^loot") or string.find(c2, "^attrib") then
        reply = bd.templates.loot or ""
    elseif string.find(c2, "^sr") then
        local db2 = RT.Store.DB()
        local sr  = (db2.softres or db2.sr or {})[sender]
        if sr then
            if type(sr) == "table" then
                local items = {}
                for _, v in pairs(sr) do table.insert(items, tostring(v)) end
                reply = "Your SR: " .. table.concat(items, ", ")
            else
                reply = "Your SR: " .. tostring(sr)
            end
        else
            reply = "No SR recorded for you."
        end
    elseif string.find(c2, "^join") or string.find(c2, "^postuler") or string.find(c2, "^recrutement") then
        if bd.autoinvite then
            if WB.roster[sender] then
                reply = "You're already in the raid!"
            else
                WB.pending[sender] = { step="waiting_gear" }
                local needed = WB.GEAR_LABEL[bd.recruit and bd.recruit.minGear or "phase1"] or "Phase 1"
                reply = "Hi! What's your gear? (pregear / phase1 / phase2)  -  Required: " .. needed
            end
        else
            reply = bd.templates.join or ""
        end
    elseif string.find(c2, "^info") then
        reply = bd.templates.info or ""
    elseif string.find(c2, "^spec") or string.find(c2, "^classe") then
        local n = GetNumRaidMembers and GetNumRaidMembers() or 0
        local found = false
        for i = 1, n do
            local pname, rk, sg, lv, cls = GetRaidRosterInfo(i)
            if pname == sender then
                found = true
                reply = "Class: " .. (cls or "?") .. " | Lvl: " .. (lv or "?") .. " | Group " .. (sg or "?")
                break
            end
        end
        if not found then reply = "You're not in the raid." end
    elseif string.find(c2, "^compo") or string.find(c2, "^comp") then
        reply = WB.buildCompoText()
    elseif string.find(c2, "^role") then
        local n = GetNumRaidMembers and GetNumRaidMembers() or 0
        local found = false
        for i = 1, n do
            local pname, rk, sg, lv, cls = GetRaidRosterInfo(i)
            if pname == sender then
                found = true
                local c = cls and string.upper(cls) or ""
                local r = "DPS"
                if c == "WARRIOR" then r = "Tank"
                elseif c == "DRUID" then r = "Tank/Heal/DPS"
                elseif c == "PALADIN" then r = "Tank/Heal/DPS"
                elseif c == "PRIEST" then r = "Heal"
                elseif c == "SHAMAN" then r = "Heal/DPS"
                end
                reply = "Suggested role: " .. r .. " (" .. (cls or "?") .. ")"
                break
            end
        end
        if not found then reply = "You're not in the raid." end
    elseif string.find(c2, "^groupe") or string.find(c2, "^group") then
        -- Cherche dans l'attribution calculée
        local found_g = nil
        if RT_AA_LAST and RT_AA_LAST.groups then
            for g = 1, 8 do
                local grp = RT_AA_LAST.groups[g] or {}
                for s = 1, table.getn(grp) do
                    if grp[s] == sender then found_g = g; break end
                end
                if found_g then break end
            end
        end
        -- Groupe en jeu (sous-groupe réel dans le raid)
        local raid_g = nil
        local nb = GetNumRaidMembers and GetNumRaidMembers() or 0
        for i = 1, nb do
            local pname, _, sg = GetRaidRosterInfo(i)
            if pname == sender then raid_g = sg; break end
        end
        if found_g then
            reply = "Assigned: Group " .. found_g
            if raid_g and tonumber(raid_g) ~= found_g then
                reply = reply .. "  (Currently in-game: Grp " .. raid_g .. ")"
            end
        elseif raid_g then
            reply = "Group " .. raid_g .. "  (no assignment computed)"
        else
            reply = "You're not in the raid."
        end
    elseif string.find(c2, "^mt") or string.find(c2, "^tank") then
        if RT_AA_LAST and RT_AA_LAST.tanks and table.getn(RT_AA_LAST.tanks) > 0 then
            local parts = {}
            for i = 1, table.getn(RT_AA_LAST.tanks) do
                table.insert(parts, "MT" .. i .. ": " .. RT_AA_LAST.tanks[i])
            end
            reply = table.concat(parts, "  -  ")
        else
            reply = "No tank assigned (run Setup Raid first)."
        end
    elseif string.find(c2, "^strat") then
        local boss = string.gsub(c2, "^strat%s*", "")
        if boss == "" then
            reply = "Usage: ?strat <boss name>"
        elseif RT_Tactics and RT_Tactics.FindAll then
            local res = RT_Tactics.FindAll(boss)
            if res and table.getn(res) > 0 then
                local lns   = res[1].lines or {}
                local count = math.min(table.getn(lns), 3)
                for li = 1, count do
                    SendChatMessage(RT_ChatSafe(lns[li]), "WHISPER", nil, sender)
                end
                didAct = true
                WB.addLog("|cff44FFFF[" .. sender .. "]|r !strat " .. boss)
            else
                reply = "No tactic for: " .. boss
            end
        else
            reply = "Tactics database unavailable."
        end
    end

    if reply and reply ~= "" then
        SendChatMessage(RT_ChatSafe(reply), "WHISPER", nil, sender)
        WB.addLog("|cffFFD700[" .. sender .. "]|r " .. msg .. " -> " .. reply)
    elseif not didAct then
        WB.addLog("|cff888888[" .. sender .. "]|r " .. msg)
    end
end)

RT.Modules.Register({
    id       = "whisperbot",
    title    = "WhisperBot",
    tip      = "Pug hub: auto recruitment (?join), multi-channel LFM, spec request, comp announce, boss tactics window with auto-detection, and auto replies (?mt ?group ?comp ?strat).",
    color    = { 1.00, 0.80, 0.20 },
    tabWidth = 90,

    build = function(panel)
        -- BOT toggle
        local tBtn = RT.UI.Button(panel, {
            text="BOT: OFF", width=100, height=28, color={0.55,0.15,0.10},
            anchor={"TOPLEFT",panel,"TOPLEFT",12,-10},
        })
        tBtn:SetScript("OnClick", function()
            local bd  = WB.getData()
            bd.enabled = not bd.enabled
            local tex  = tBtn:GetNormalTexture()
            if bd.enabled then
                tBtn:SetText("BOT: ON")
                if tex then tex:SetVertexColor(0.10,0.55,0.10) end
            else
                tBtn:SetText("BOT: OFF")
                if tex then tex:SetVertexColor(0.55,0.15,0.10) end
            end
        end)
        panel._wbToggle = tBtn

        -- RECRUITMENT toggle
        local aiBtn = RT.UI.Button(panel, {
            text="RECRUITMENT: OFF", width=148, height=28, color={0.25,0.25,0.55},
            anchor={"TOPLEFT",panel,"TOPLEFT",118,-10},
        })
        aiBtn:SetScript("OnClick", function()
            local bd  = WB.getData()
            bd.autoinvite = not bd.autoinvite
            local tex  = aiBtn:GetNormalTexture()
            if bd.autoinvite then
                aiBtn:SetText("RECRUITMENT: ON")
                if tex then tex:SetVertexColor(0.10,0.55,0.10) end
            else
                aiBtn:SetText("RECRUITMENT: OFF")
                if tex then tex:SetVertexColor(0.25,0.25,0.55) end
            end
        end)
        panel._wbAIBtn = aiBtn

        -- Button: ask the whole raid for their spec
        RT.UI.Button(panel, {
            text="Request specs", width=126, height=28, color={0.20,0.55,0.75},
            anchor={"TOPRIGHT",panel,"TOPRIGHT",-10,-10},
            tooltip="Whisper every raid member to ask their spec. Players who have RaidTools answer automatically; replies fill the roster and set the role.",
            onClick=function() WB.askSpecs(false) end,
        })

        -- Button: tactics hub (boss detection, quick post, customs)
        RT.UI.Button(panel, {
            text="Tactics", width=76, height=28, color={0.75,0.55,0.15},
            anchor={"TOPRIGHT",panel,"TOPRIGHT",-142,-10},
            tooltip="Opens the Boss Tactics window: browse/search all strategies, post to raid, preview, custom tactics, and auto-detection when you target a boss.",
            onClick=function() WB.tacOpen() end,
        })

        local infoL = panel:CreateFontString(nil,"OVERLAY","GameFontDisable")
        infoL:SetPoint("TOPLEFT",panel,"TOPLEFT",274,-14)
        infoL:SetText("?join ?spec ?role ?comp ?sr ?strat")

        -- ── Row 2: announcements (LFM / channel / comp) ────────────
        RT.UI.Button(panel, {
            text="Post LFM", width=104, height=22, color={0.20,0.55,0.30},
            anchor={"TOPLEFT",panel,"TOPLEFT",12,-44},
            tooltip="Posts your LFM message (field on the right) to the chosen channel. {tank} {heal} {dps} are replaced by the spots still open.",
            onClick=function() WB.postLFM(WB.getData()) end,
        })
        local chanBtn = RT.UI.Button(panel, {
            text="Channel: Say", width=104, height=22, color={0.30,0.40,0.55},
            anchor={"TOPLEFT",panel,"TOPLEFT",120,-44},
            tooltip="LFM broadcast channel: Say / Yell / Guild / World / LFG.",
        })
        chanBtn:SetScript("OnClick", function()
            local bd  = WB.getData()
            local cur = bd.lfm.channel or "SAY"
            local idx = 1
            for i = 1, table.getn(WB.LFM_CHANS) do
                if WB.LFM_CHANS[i] == cur then idx = i; break end
            end
            idx = idx + 1
            if idx > table.getn(WB.LFM_CHANS) then idx = 1 end
            bd.lfm.channel = WB.LFM_CHANS[idx]
            chanBtn:SetText("Channel: " .. (WB.LFM_LABELS[bd.lfm.channel] or bd.lfm.channel))
        end)
        panel._wbChanBtn = chanBtn

        RT.UI.Button(panel, {
            text="Announce comp", width=120, height=22, color={0.25,0.45,0.65},
            anchor={"TOPLEFT",panel,"TOPLEFT",228,-44},
            tooltip="Announces the current roster composition (Tank/Heal/Melee/Ranged) in raid chat.",
            onClick=function() WB.announceCompo() end,
        })

        -- Champ message LFM
        local lfmEB = CreateFrame("EditBox","RT3_WB_lfm",panel,"InputBoxTemplate")
        lfmEB:SetPoint("TOPLEFT",panel,"TOPLEFT",360,-44)
        lfmEB:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-12,-44)
        lfmEB:SetHeight(20) lfmEB:SetAutoFocus(false)
        lfmEB:SetScript("OnEscapePressed", function() lfmEB:ClearFocus() end)
        lfmEB:SetScript("OnTextChanged", function()
            local bd = WB.getData()
            bd.lfm.msg = lfmEB:GetText() or ""
        end)
        panel._wbLfmEB = lfmEB

        local s1 = panel:CreateTexture(nil,"BACKGROUND")
        s1:SetPoint("TOPLEFT",panel,"TOPLEFT",6,-72)
        s1:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-6,-72)
        s1:SetHeight(1) s1:SetTexture(0.3,0.3,0.5,0.6)

        -- Templates
        local TMPL = {
            {key="loot", label="?loot / ?attrib"},
            {key="join",  label="?join  (first reply)"},
            {key="info",  label="?info"},
        }
        panel._wbInputs = {}
        for i = 1, table.getn(TMPL) do
            local t  = TMPL[i]
            local oy = 76 + (i-1)*50
            local lb = panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            lb:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-oy)
            lb:SetText("|cff69CCF0" .. t.label .. "|r  :")
            local inp = CreateFrame("EditBox","RT3_WB_"..t.key,panel,"InputBoxTemplate")
            inp:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-oy-18)
            inp:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-10,-oy-18)
            inp:SetHeight(20) inp:SetAutoFocus(false)
            inp:SetScript("OnEscapePressed", function() inp:ClearFocus() end)
            local k = t.key
            inp:SetScript("OnTextChanged", function()
                local bd = WB.getData()
                bd.templates[k] = inp:GetText() or ""
            end)
            panel._wbInputs[t.key] = inp
        end

        local s2 = panel:CreateTexture(nil,"BACKGROUND")
        s2:SetPoint("TOPLEFT",panel,"TOPLEFT",6,-224)
        s2:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-6,-224)
        s2:SetHeight(1) s2:SetTexture(0.3,0.3,0.5,0.6)

        local rLbl = panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
        rLbl:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-228)
        rLbl:SetText("|cffFFD700Auto recruitment|r")

        RT.UI.Button(panel, {
            text="Reset counts", width=120, height=20, color={0.4,0.1,0.4},
            anchor={"TOPRIGHT",panel,"TOPRIGHT",-10,-226},
            onClick=function()
                WB.counts  = { tank=0, heal=0, dps=0 }
                WB.pending = {}
                WB.roster  = {}
                WB.updateCounts(WB.getData())
            end,
        })

        -- Min gear cycle button
        local mgBtn = CreateFrame("Button","RT3_WBMGBtn",panel,"UIPanelButtonTemplate")
        mgBtn:SetWidth(140) mgBtn:SetHeight(22)
        mgBtn:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-248)
        mgBtn:SetText("Min: Phase 1")
        mgBtn:SetScript("OnClick", function()
            local bd  = WB.getData()
            local cur = bd.recruit.minGear or "phase1"
            local nxt = "phase1"
            if cur == "pregear" then nxt = "phase1"
            elseif cur == "phase1" then nxt = "phase2"
            elseif cur == "phase2" then nxt = "pregear"
            end
            bd.recruit.minGear = nxt
            mgBtn:SetText("Min: " .. (WB.GEAR_LABEL[nxt] or nxt))
        end)
        panel._wbMGBtn = mgBtn

        -- Slot inputs
        local SLOTS = { {"tank","Tank",160}, {"heal","Heal",228}, {"dps","DPS",296} }
        panel._wbSlot = {}
        for i = 1, table.getn(SLOTS) do
            local sk, sn, ox = SLOTS[i][1], SLOTS[i][2], SLOTS[i][3]
            local sl = panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            sl:SetPoint("TOPLEFT",panel,"TOPLEFT",ox,-250)
            sl:SetText(sn..":")
            local inp = CreateFrame("EditBox","RT3_WBSl_"..sk,panel,"InputBoxTemplate")
            inp:SetPoint("TOPLEFT",panel,"TOPLEFT",ox+30,-248)
            inp:SetWidth(34) inp:SetHeight(20) inp:SetAutoFocus(false)
            inp:SetNumeric(true)
            inp:SetScript("OnEscapePressed", function() inp:ClearFocus() end)
            local kk = sk
            inp:SetScript("OnTextChanged", function()
                local bd = WB.getData()
                bd.recruit.slots[kk] = tonumber(inp:GetText()) or 0
                WB.updateCounts(bd)
            end)
            panel._wbSlot[sk] = inp
        end

        -- Count display
        local cD = panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
        cD:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-274)
        cD:SetText("|cffFF8888Tank 0/2|r   |cff88FF88Heal 0/6|r   |cffAAAAFFDPS 0/22|r")
        WB.cDisp = cD
        panel._wbCDisp = cD

        local s3 = panel:CreateTexture(nil,"BACKGROUND")
        s3:SetPoint("TOPLEFT",panel,"TOPLEFT",6,-292)
        s3:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-6,-292)
        s3:SetHeight(1) s3:SetTexture(0.3,0.3,0.5,0.6)

        RT.UI.Button(panel, {
            text="Clear Log", width=80, height=20, color={0.3,0.3,0.3},
            anchor={"TOPRIGHT",panel,"TOPRIGHT",-10,-296},
            onClick=function()
                WB.log = {}
                if WB.disp then WB.disp:SetText("") end
            end,
        })
        local logL = panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        logL:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-296)
        logL:SetText("|cffAAAAFFRecent activity:|r")

        local logD = RT.UI.TextScroll(panel, {
            name="RT3_WBLog", anchor={"TOPLEFT",panel,"TOPLEFT",8,-316},
            width=680, font="GameFontHighlightSmall",
        })
        logD.scroll:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-28,8)
        WB.disp = logD
        panel._wbLog = logD
    end,

    show = function(panel)
        local bd = WB.getData()
        if panel._wbToggle then
            local tex = panel._wbToggle:GetNormalTexture()
            if bd.enabled then
                panel._wbToggle:SetText("BOT: ON")
                if tex then tex:SetVertexColor(0.10,0.55,0.10) end
            else
                panel._wbToggle:SetText("BOT: OFF")
                if tex then tex:SetVertexColor(0.55,0.15,0.10) end
            end
        end
        if panel._wbAIBtn then
            local tex = panel._wbAIBtn:GetNormalTexture()
            if bd.autoinvite then
                panel._wbAIBtn:SetText("RECRUITMENT: ON")
                if tex then tex:SetVertexColor(0.10,0.55,0.10) end
            else
                panel._wbAIBtn:SetText("RECRUITMENT: OFF")
                if tex then tex:SetVertexColor(0.25,0.25,0.55) end
            end
        end
        if panel._wbInputs then
            for k, inp in pairs(panel._wbInputs) do
                inp:SetText((bd.templates and bd.templates[k]) or "")
            end
        end
        if panel._wbChanBtn then
            local key = (bd.lfm and bd.lfm.channel) or "SAY"
            panel._wbChanBtn:SetText("Channel: " .. (WB.LFM_LABELS[key] or key))
        end
        if panel._wbLfmEB then
            panel._wbLfmEB:SetText((bd.lfm and bd.lfm.msg) or "")
        end
        if panel._wbMGBtn then
            local rc = bd.recruit or {}
            panel._wbMGBtn:SetText("Min: " .. (WB.GEAR_LABEL[rc.minGear or "phase1"] or "Phase 1"))
        end
        if panel._wbSlot then
            local s = (bd.recruit and bd.recruit.slots) or {}
            for key, inp in pairs(panel._wbSlot) do
                inp:SetText(tostring(s[key] or 0))
            end
        end
        WB.cDisp = panel._wbCDisp
        WB.updateCounts(bd)
        WB.disp = panel._wbLog
        if WB.disp and table.getn(WB.log) > 0 then
            WB.disp:SetText(table.concat(WB.log, "\n"))
        end
    end,
})

-- [v3:Minimap]
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
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[RT] Menu not loaded.|r")
        end
    end)

    RTMB:SetScript("OnDragStart", function() this:SetScript("OnUpdate", RT3MB_Drag) end)
    RTMB:SetScript("OnDragStop",  function() this:SetScript("OnUpdate", nil) end)

    RTMB:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffFFD700RT — Raid Tool|r")
        GameTooltip:AddLine("Left-click: open the menu", 1, 1, 1)
        GameTooltip:AddLine("Drag: move the button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    RTMB:SetScript("OnLeave", function() GameTooltip:Hide() end)

    RTMB:RegisterEvent("VARIABLES_LOADED")
    RTMB:RegisterEvent("PLAYER_ENTERING_WORLD")
    RTMB:SetScript("OnEvent", function() RT3MB_Position() end)

    RT3MB_Position()
end

