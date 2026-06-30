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
    title    = "Consomes",
    tip      = "Consommables recommandés par rôle (flacons, potions, élixirs) à rappeler au raid.",
    color    = { 0.60, 1.00, 0.40 },
    tabWidth = 80,

    build = function(panel)
        RT.UI.Label(panel, {
            text   = "|cff99FF44Consommables|r - checklist par joueur du raid",
            font   = "GameFontNormal",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -10 },
        })

        RT.UI.Button(panel, {
            text = "Reset Coches", width = 100, height = 22, color = { 0.55, 0.20, 0.10 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -12, -8 },
            onClick = function()
                _cData = {}
                if panel._cRefresh then panel._cRefresh() end
            end,
        })

        RT.UI.Button(panel, {
            text = "Announce Missing", width = 130, height = 22, color = { 0.60, 0.40, 0.10 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -118, -8 },
            onClick = function()
                local missing = {}
                for name, v in pairs(_cData) do
                    if not v.pret then table.insert(missing, name) end
                end
                if table.getn(missing) > 0 then
                    SendChatMessage("Pas prets: " .. table.concat(missing, ", "), "RAID")
                else
                    SendChatMessage("Tout le monde est pret !", "RAID")
                end
            end,
        })

        RT.UI.Button(panel, {
            text = "Scan Raid", width = 80, height = 22, color = { 0.20, 0.40, 0.70 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -254, -8 },
            onClick = function()
                if panel._cRefresh then panel._cRefresh() end
            end,
        })

        -- Column headers
        local hdrs = {
            { COL_NAME,  "Joueur",  120 },
            { COL_FLASK, "Flask/Eli", 100 },
            { COL_FOOD,  "Nourriture", 100 },
            { COL_PRET,  "Pret", 80 },
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
        end
        panel._cRefresh = refresh
    end,

    show = function(panel)
        if panel._cRefresh then panel._cRefresh() end
    end,
})
