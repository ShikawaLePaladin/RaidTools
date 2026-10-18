-- ============================================================
-- RT v2 — Attendance.lua
-- Suivi des présences et kills de boss
-- Compatible WoW 1.12 / TurtleWoW
-- ============================================================

RT_Attend = RT_Attend or {}

-- RT_DB.attendance[bossName] = { kills={date,...}, players={date={name,...}} }

-- ── Enregistrer un kill ────────────────────────────────────
function RT_Attend.RecordKill(bossName)
    if not bossName or bossName == "" then return end
    RT_DB = RT_DB or {}
    RT_DB.attendance = RT_DB.attendance or {}
    RT_DB.attendance[bossName] = RT_DB.attendance[bossName] or { kills={}, players={} }

    local date = date and date("%Y-%m-%d") or "unknown"
    -- Évite les doublons (même boss, même jour)
    local kills = RT_DB.attendance[bossName].kills
    for i = 1, table.getn(kills) do
        if kills[i] == date then return end
    end
    table.insert(kills, date)

    -- Snapshot des joueurs présents
    local presentPlayers = {}
    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if nRaid > 0 then
        for i = 1, nRaid do
            local name = GetRaidRosterInfo and GetRaidRosterInfo(i)
            if name and name ~= "" then
                table.insert(presentPlayers, name)
            end
        end
    else
        local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
        for i = 0, nParty do
            local unit = i == 0 and "player" or ("party" .. i)
            local name = UnitName and UnitName(unit) or ""
            if name ~= "" then table.insert(presentPlayers, name) end
        end
    end
    RT_DB.attendance[bossName].players[date] = presentPlayers

    RT_Print("|cff88FF88[Attendance] Kill enregistré : " .. bossName .. " (" .. date .. ") — " .. table.getn(presentPlayers) .. " joueurs.|r")
    if RT_Sync_Send then RT_Sync_Send("ATTEND", bossName, date) end
end

-- ── Stats d'un joueur ──────────────────────────────────────
function RT_Attend.GetPlayerStats(playerName)
    RT_DB = RT_DB or {}
    local att = RT_DB.attendance or {}
    local stats = { kills={}, total=0 }
    for boss, data in pairs(att) do
        for dateKey, players in pairs(data.players or {}) do
            for i = 1, table.getn(players) do
                if players[i] == playerName then
                    table.insert(stats.kills, { boss=boss, date=dateKey })
                    stats.total = stats.total + 1
                    break
                end
            end
        end
    end
    table.sort(stats.kills, function(a,b) return a.date > b.date end)
    return stats
end

-- ── Liste de présence pour un boss ────────────────────────
function RT_Attend.GetBossHistory(bossName)
    RT_DB = RT_DB or {}
    if not RT_DB.attendance or not RT_DB.attendance[bossName] then
        return nil
    end
    return RT_DB.attendance[bossName]
end

-- ── Sync reception ─────────────────────────────────────────
if RT_Sync_Register then
    RT_Sync_Register("ATTEND", function(sender, bossName, dateKey)
        -- Reçu d'un autre joueur — on note que ce boss a été kill
        RT_DB = RT_DB or {}
        RT_DB.attendance = RT_DB.attendance or {}
        if bossName and bossName ~= "" and dateKey and dateKey ~= "" then
            RT_DB.attendance[bossName] = RT_DB.attendance[bossName] or { kills={}, players={} }
        end
    end)
end

-- ── Détection automatique de kill via CHAT_MSG_COMBAT_HOSTILE_DEATH ─
local RT_AttendFrame = CreateFrame("Frame", "RT_AttendFrame", UIParent)
RT_AttendFrame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
RT_AttendFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
RT_AttendFrame._lastBossKill = nil

local _attendLastBossKill = nil
RT_AttendFrame:SetScript("OnEvent", function()
    local ev = event or ""
    local msg = arg1 or ""
    if ev == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
        local bossName = RT_BOSS_STATE and RT_BOSS_STATE.bossName or ""
        if bossName ~= "" and string.find(msg, bossName, 1, true) then
            _attendLastBossKill = bossName
        end
    elseif ev == "PLAYER_REGEN_ENABLED" then
        if _attendLastBossKill then
            RT_Attend.RecordKill(_attendLastBossKill)
            _attendLastBossKill = nil
        end
    end
end)

-- ── Construction de l'UI Attendance ───────────────────────
function RT_BuildUIAttendance(parent)
    local p = parent

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -4)
    title:SetText("|cff88FF88Attendance|r  —  Historique des kills et présences")
    title:SetTextColor(0.3, 1.0, 0.5)

    -- Bouton enregistrer un kill manuel
    local recordBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    recordBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -4)
    recordBtn:SetWidth(130)
    recordBtn:SetHeight(22)
    recordBtn:SetText("Enregistrer Kill")
    local rTex = recordBtn:GetNormalTexture()
    if rTex then rTex:SetVertexColor(0.1, 0.7, 0.2) end
    recordBtn:SetScript("OnClick", function()
        local boss = RT_BOSS_STATE and RT_BOSS_STATE.bossName or ""
        if boss ~= "" then
            RT_Attend.RecordKill(boss)
            RT_AttendRefreshDisplay()
        else
            RT_Print("|cffFFAA00[Attendance] Aucun boss sélectionné dans l'onglet Boss.|r")
        end
    end)

    -- Recherche joueur
    local searchLabel = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    searchLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -32)
    searchLabel:SetText("Joueur:")

    local searchEdit = CreateFrame("EditBox", "RT_AttendSearchEdit", p, "InputBoxTemplate")
    searchEdit:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
    searchEdit:SetWidth(160)
    searchEdit:SetHeight(20)
    searchEdit:SetAutoFocus(false)
    searchEdit:SetText("")
    searchEdit:SetScript("OnEscapePressed", function() searchEdit:ClearFocus() end)
    searchEdit:SetScript("OnEnterPressed", function()
        RT_AttendRefreshDisplay(searchEdit:GetText())
        searchEdit:ClearFocus()
    end)

    local searchBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    searchBtn:SetPoint("LEFT", searchEdit, "RIGHT", 4, 0)
    searchBtn:SetWidth(70)
    searchBtn:SetHeight(20)
    searchBtn:SetText("Chercher")
    searchBtn:SetScript("OnClick", function()
        RT_AttendRefreshDisplay(searchEdit:GetText())
    end)

    local allBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    allBtn:SetPoint("LEFT", searchBtn, "RIGHT", 4, 0)
    allBtn:SetWidth(90)
    allBtn:SetHeight(20)
    allBtn:SetText("Tout afficher")
    allBtn:SetScript("OnClick", function()
        searchEdit:SetText("")
        RT_AttendRefreshDisplay("")
    end)

    -- Zone d'affichage scroll
    local attScroll = CreateFrame("ScrollFrame", "RT_AttendScroll", p, "UIPanelScrollFrameTemplate")
    attScroll:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -58)
    attScroll:SetWidth(716)
    attScroll:SetHeight(360)

    local attContent = CreateFrame("Frame", "RT_AttendContent", attScroll)
    attContent:SetWidth(698)
    attContent:SetHeight(3000)
    attScroll:SetScrollChild(attContent)

    local attText = attContent:CreateFontString("RT_AttendText", "OVERLAY", "GameFontNormalSmall")
    attText:SetPoint("TOPLEFT", attContent, "TOPLEFT", 4, -4)
    attText:SetWidth(690)
    attText:SetJustifyH("LEFT")
    attText:SetText("|cff888888Aucun historique disponible.|r")

    -- Affichage initial
    RT_AttendRefreshDisplay("")
end

function RT_AttendRefreshDisplay(playerFilter)
    local textWidget = getglobal("RT_AttendText")
    if not textWidget then return end
    RT_DB = RT_DB or {}
    local att = RT_DB.attendance or {}
    local lines = {}

    if playerFilter and RT_BTrim and RT_BTrim(playerFilter) ~= "" then
        -- Mode joueur : montrer tous les kills de ce joueur
        local pf = RT_BTrim(playerFilter)
        local stats = RT_Attend.GetPlayerStats(pf)
        table.insert(lines, "|cffFFD700" .. pf .. "|r  —  " .. stats.total .. " boss kill(s)")
        for i = 1, table.getn(stats.kills) do
            local k = stats.kills[i]
            table.insert(lines, "  |cff88FF88✓|r  " .. k.date .. "  |cffCCCCCC" .. k.boss .. "|r")
        end
        if stats.total == 0 then
            table.insert(lines, "|cff888888(aucun kill enregistré pour ce joueur)|r")
        end
    else
        -- Mode global : montrer tous les boss
        local bossNames = {}
        for boss in pairs(att) do table.insert(bossNames, boss) end
        table.sort(bossNames)
        if table.getn(bossNames) == 0 then
            textWidget:SetText("|cff888888Aucun kill enregistré. Les kills se sauvegardent automatiquement ou via le bouton 'Enregistrer Kill'.|r")
            return
        end
        for bi = 1, table.getn(bossNames) do
            local boss  = bossNames[bi]
            local data  = att[boss]
            local nKills = table.getn(data.kills or {})
            table.insert(lines, "|cffFFD700" .. boss .. "|r  |cff888888" .. nKills .. " kill(s)|r")
            -- Derniers kills
            local kills = data.kills or {}
            for ki = table.getn(kills), math.max(1, table.getn(kills)-2), -1 do
                local dateKey   = kills[ki]
                local players   = data.players and data.players[dateKey] or {}
                local nPresent  = table.getn(players)
                table.insert(lines, "  |cff44FF44" .. dateKey .. "|r  " .. nPresent .. " joueurs")
            end
        end
    end

    textWidget:SetText(table.concat(lines, "\n"))
end
