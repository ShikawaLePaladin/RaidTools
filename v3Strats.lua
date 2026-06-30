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
        return "|cff888888Sélectionne un boss à gauche pour voir sa tactique.|r"
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
    tip      = "Tactiques des boss (recherche par nom). Le WhisperBot peut les envoyer avec ?strat <boss>.",
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
            text = "Rechercher :", font = "GameFontDisable",
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
                else RT.Print("|cffFFAA00Sélectionne un boss d'abord.|r") end
            end,
        })
        RT.UI.Button(panel, {
            text = "Post /Party", width = 110, height = 22,
            anchor = { "BOTTOMLEFT", panel, "BOTTOMLEFT", 434, 8 },
            onClick = function()
                if panel._selected and RT_Tactics then RT_Tactics.Post(panel._selected.boss, "PARTY")
                else RT.Print("|cffFFAA00Sélectionne un boss d'abord.|r") end
            end,
        })
    end,

    show = function(panel)
        if panel._refreshList then panel._refreshList() end
        if panel._preview then panel._preview:SetText(fmtTactic(panel._selected)) end
    end,
})
