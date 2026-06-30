-- ============================================================
-- RT v3 — modules/Loot.lua
-- Historique de loot + SR+ (Soft Reserve points).
-- Lit RT_DB.loot[player] = { {itemId,itemName,boss,date,sr}, ... }
-- et RT_DB.sr[player] = { points, lastUpdated }.
-- ============================================================

local function fmtLoot(filter)
    local db = RT.Store.DB()
    local loot = db.loot or {}
    local sr   = db.sr or {}
    filter = filter and string.lower(filter) or ""

    -- Collecte les joueurs, triés par points SR puis nom
    local players = {}
    for name in pairs(loot) do
        if filter == "" or string.find(string.lower(name), filter, 1, true) then
            table.insert(players, name)
        end
    end
    table.sort(players, function(a, b)
        local pa = (sr[a] and sr[a].points) or 0
        local pb = (sr[b] and sr[b].points) or 0
        if pa ~= pb then return pa > pb end
        return a < b
    end)

    if table.getn(players) == 0 then
        return "|cff888888Aucun loot enregistré. Importe une feuille SoftRes/loot via l'onglet Import (v2).|r"
    end

    local L = {}
    for pi = 1, table.getn(players) do
        local name = players[pi]
        local pts  = (sr[name] and sr[name].points) or 0
        local items = loot[name] or {}
        local srTag = pts > 0 and ("  |cffFFD700SR+" .. pts .. "|r") or ""
        table.insert(L, "|cff69CCF0" .. name .. "|r" .. srTag .. "  |cff888888(" .. table.getn(items) .. " item(s))|r")
        -- items les plus récents d'abord
        local sorted = {}
        for i = 1, table.getn(items) do sorted[i] = items[i] end
        table.sort(sorted, function(a, b) return (a.date or "") > (b.date or "") end)
        for i = 1, table.getn(sorted) do
            local it = sorted[i]
            table.insert(L, "   |cff88FF88-|r " .. (it.itemName or "?")
                .. "  |cff666666" .. (it.boss or "") .. " · " .. (it.date or "") .. "|r")
        end
    end
    return table.concat(L, "\n")
end

RT.Modules.Register({
    id       = "loot",
    title    = "Loot",
    color    = { 0.40, 0.80, 1.00 },
    tabWidth = 60,

    build = function(panel)
        RT.UI.Label(panel, {
            text = "|cff69CCF0Loot & SR+|r  —  trié par points Soft Reserve",
            font = "GameFontNormal",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -10 },
        })

        local display   -- forward ref

        RT.UI.Label(panel, {
            text = "Filtre joueur :", font = "GameFontDisable",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -36 },
        })
        local search = CreateFrame("EditBox", "RT3_LootSearch", panel, "InputBoxTemplate")
        search:SetPoint("TOPLEFT", panel, "TOPLEFT", 110, -34)
        search:SetWidth(160)
        search:SetHeight(20)
        search:SetAutoFocus(false)
        search:SetScript("OnEscapePressed", function() search:ClearFocus() end)
        search:SetScript("OnTextChanged", function()
            if display then display:SetText(fmtLoot(search:GetText())) end
        end)

        RT.UI.Button(panel, {
            text = "Tout", width = 60, height = 20,
            anchor = { "TOPLEFT", panel, "TOPLEFT", 278, -34 },
            onClick = function()
                search:SetText("")
                if display then display:SetText(fmtLoot("")) end
            end,
        })

        display = RT.UI.TextScroll(panel, {
            name = "RT3_LootDisplay",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 8, -60 },
            width = 690, height = 360, font = "GameFontHighlightSmall",
        })
        display.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)
        panel._display = display
    end,

    show = function(panel)
        if panel._display then panel._display:SetText(fmtLoot("")) end
    end,
})
