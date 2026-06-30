-- ============================================================
-- RT v3 — modules/Attendance.lua
-- Présences & kills. Surface RT_Attend (logique v2 inchangée).
-- ============================================================

local function fmtAttendance(filter)
    local db = RT.Store.DB()
    local att = db.attendance or {}

    if filter and RT_BTrim and RT_BTrim(filter) ~= "" then
        -- Vue joueur
        local pf = RT_BTrim(filter)
        local stats = (RT_Attend and RT_Attend.GetPlayerStats and RT_Attend.GetPlayerStats(pf)) or { kills = {}, total = 0 }
        local L = { "|cffFFD700" .. pf .. "|r  —  " .. stats.total .. " boss kill(s)" }
        for i = 1, table.getn(stats.kills) do
            local k = stats.kills[i]
            table.insert(L, "  |cff88FF88-|r  " .. k.date .. "  |cffCCCCCC" .. k.boss .. "|r")
        end
        if stats.total == 0 then
            table.insert(L, "|cff888888(no kill recorded for this player)|r")
        end
        return table.concat(L, "\n")
    end

    -- Vue globale
    local bossNames = {}
    for boss in pairs(att) do table.insert(bossNames, boss) end
    table.sort(bossNames)
    if table.getn(bossNames) == 0 then
        return "|cff888888No kill recorded. Kills are saved automatically in combat, or via 'Record Kill'.|r"
    end
    local L = {}
    for bi = 1, table.getn(bossNames) do
        local boss   = bossNames[bi]
        local data   = att[boss]
        local nKills = table.getn(data.kills or {})
        table.insert(L, "|cffFFD700" .. boss .. "|r  |cff888888" .. nKills .. " kill(s)|r")
        local kills = data.kills or {}
        for ki = table.getn(kills), math.max(1, table.getn(kills) - 2), -1 do
            local dk = kills[ki]
            local players = data.players and data.players[dk] or {}
            table.insert(L, "  |cff44FF44" .. dk .. "|r  " .. table.getn(players) .. " joueurs")
        end
    end
    return table.concat(L, "\n")
end

RT.Modules.Register({
    id       = "attend",
    title    = "Attendance",
    color    = { 0.30, 1.00, 0.50 },
    tabWidth = 84,

    build = function(panel)
        RT.UI.Label(panel, {
            text = "|cff88FF88Attendance|r  —  history of kills and participation",
            font = "GameFontNormal",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -10 },
        })

        local display   -- forward ref

        RT.UI.Button(panel, {
            text = "Record Kill", width = 130, height = 22,
            color = { 0.10, 0.70, 0.20 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -12, -8 },
            onClick = function()
                local boss = RT_BOSS_STATE and RT_BOSS_STATE.bossName or ""
                if boss ~= "" and RT_Attend then
                    RT_Attend.RecordKill(boss)
                    if display then display:SetText(fmtAttendance("")) end
                else
                    RT.Print("|cffFFAA00No boss selected (Boss v2 tab).|r")
                end
            end,
            tooltip = "Records a kill of the currently selected boss + snapshot of present members.",
        })

        RT.UI.Label(panel, {
            text = "Player:", font = "GameFontDisable",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -36 },
        })
        local search = CreateFrame("EditBox", "RT3_AttendSearch", panel, "InputBoxTemplate")
        search:SetPoint("TOPLEFT", panel, "TOPLEFT", 80, -34)
        search:SetWidth(160)
        search:SetHeight(20)
        search:SetAutoFocus(false)
        search:SetScript("OnEscapePressed", function() search:ClearFocus() end)
        search:SetScript("OnTextChanged", function()
            if display then display:SetText(fmtAttendance(search:GetText())) end
        end)

        RT.UI.Button(panel, {
            text = "Tout", width = 60, height = 20,
            anchor = { "TOPLEFT", panel, "TOPLEFT", 248, -34 },
            onClick = function()
                search:SetText("")
                if display then display:SetText(fmtAttendance("")) end
            end,
        })

        display = RT.UI.TextScroll(panel, {
            name = "RT3_AttendDisplay",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 8, -60 },
            width = 690, height = 360, font = "GameFontHighlightSmall",
        })
        display.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)
        panel._display = display
    end,

    show = function(panel)
        if panel._display then panel._display:SetText(fmtAttendance("")) end
    end,
})
