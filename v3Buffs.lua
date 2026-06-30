-- ============================================================
-- RT v3 - modules/Buffs.lua
-- Assignation des buffs de classe pour le raid
-- ============================================================

local BUFF_LIST = {
    { id="ai",     label="Arcane Intelligence",      class="|cff69CCF0Mage|r"     },
    { id="motw",   label="Marque du Monde Sauvage",  class="|cff00FF00Druide|r"   },
    { id="fort",   label="Mot de Pouvoir: Force",    class="|cffFFFFFFPretre|r"   },
    { id="ds",     label="Esprit Divin",              class="|cffFFFFFFPretre|r"   },
    { id="kings",  label="Bened. des Rois",           class="|cffF58CBADin|r"      },
    { id="might",  label="Bened. de la Puissance",    class="|cffF58CBADin|r"      },
    { id="wisdom", label="Bened. de Sagesse",         class="|cffF58CBADin|r"      },
    { id="salv",   label="Bened. du Salut",           class="|cffF58CBADin|r"      },
    { id="ss",     label="Pierre d'Ame (Demoniste)",  class="|cff9482C9Demo|r"     },
}

local function getBufData()
    local db = RT.Store.DB()
    if not db.v3buffs then
        db.v3buffs = {}
        for i = 1, table.getn(BUFF_LIST) do
            db.v3buffs[BUFF_LIST[i].id] = { "", "" }
        end
    end
    return db.v3buffs
end

RT.Modules.Register({
    id       = "buffs",
    title    = "Buffs",
    color    = { 0.40, 0.80, 1.00 },
    tabWidth = 54,

    build = function(panel)
        RT.UI.Label(panel, {
            text   = "|cff66CCFFBuffs|r - responsables par type",
            font   = "GameFontNormal",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -10 },
        })

        RT.UI.Button(panel, {
            text = "Post /Raid", width = 90, height = 22, color = { 0.60, 0.40, 0.10 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -12, -8 },
            onClick = function()
                local d = getBufData()
                for i = 1, table.getn(BUFF_LIST) do
                    local b = BUFF_LIST[i]
                    local slots = d[b.id] or {}
                    local names = {}
                    for s = 1, table.getn(slots) do
                        if slots[s] and slots[s] ~= "" then
                            table.insert(names, slots[s])
                        end
                    end
                    if table.getn(names) > 0 then
                        SendChatMessage("[Buff] " .. b.label .. " : " .. table.concat(names, ", "), "RAID")
                    end
                end
            end,
        })

        -- Scan Raid: auto-fill buff slots by detecting classes in raid
        RT.UI.Button(panel, {
            text = "Scan Raid", width = 86, height = 22, color = { 0.20, 0.50, 0.70 },
            anchor = { "TOPRIGHT", panel, "TOPRIGHT", -108, -8 },
            onClick = function()
                local d  = getBufData()
                -- Clear all slots first
                for i = 1, table.getn(BUFF_LIST) do
                    d[BUFF_LIST[i].id] = { "", "" }
                end
                -- Group raid members by class
                local buckets = {}
                local n = GetNumRaidMembers and GetNumRaidMembers() or 0
                for i = 1, n do
                    local name, r, sg, lv, className = GetRaidRosterInfo(i)
                    local cls = className and string.upper(className) or ""
                    if name and cls ~= "" then
                        if not buckets[cls] then buckets[cls] = {} end
                        table.insert(buckets[cls], name)
                    end
                end
                -- Map classes to their buff IDs (round-robin assignment)
                local classBuffs = {
                    MAGE    = { "ai" },
                    DRUID   = { "motw" },
                    PRIEST  = { "fort", "ds" },
                    PALADIN = { "kings", "might", "wisdom", "salv" },
                    WARLOCK = { "ss" },
                }
                for cls, buffIds in pairs(classBuffs) do
                    local members = buckets[cls] or {}
                    local nm = table.getn(members)
                    if nm > 0 then
                        for bi = 1, table.getn(buffIds) do
                            local bid = buffIds[bi]
                            if not d[bid] then d[bid] = { "", "" } end
                            local i1 = math.mod(bi - 1, nm) + 1
                            local i2 = math.mod(bi, nm) + 1
                            d[bid][1] = members[i1] or ""
                            d[bid][2] = (nm >= 2 and i2 ~= i1) and (members[i2] or "") or ""
                        end
                    end
                end
                if panel._bufRefresh then panel._bufRefresh() end
                RT.Print("|cff44FF88Scan termine: " .. n .. " joueurs.|r")
            end,
        })

        -- Column headers
        local C = { 6, 200, 304, 502 }
        local headers = { "Buff", "Classe", "Joueur 1", "Joueur 2" }
        for i = 1, 4 do
            local h = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            h:SetPoint("TOPLEFT", panel, "TOPLEFT", C[i], -34)
            h:SetText("|cffAAAAFF" .. headers[i] .. "|r")
        end

        local sep = panel:CreateTexture(nil, "BACKGROUND")
        sep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  6, -48)
        sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -48)
        sep:SetHeight(1)
        sep:SetTexture(0.3, 0.3, 0.5, 0.8)

        local rowH = 27
        panel._bufInputs = {}

        local function bufRefresh()
            local d = getBufData()
            for i = 1, table.getn(BUFF_LIST) do
                local b      = BUFF_LIST[i]
                local slots  = d[b.id] or { "", "" }
                local inputs = panel._bufInputs and panel._bufInputs[b.id] or {}
                for s = 1, 2 do
                    if inputs[s] then inputs[s]:SetText(slots[s] or "") end
                end
            end
        end
        panel._bufRefresh = bufRefresh

        for i = 1, table.getn(BUFF_LIST) do
            local b  = BUFF_LIST[i]
            local oy = 50 + (i - 1) * rowH

            local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lbl:SetPoint("TOPLEFT", panel, "TOPLEFT", C[1] + 2, -oy - 2)
            lbl:SetText(b.label)
            lbl:SetWidth(C[2] - C[1] - 4)
            lbl:SetJustifyH("LEFT")

            local clbl = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            clbl:SetPoint("TOPLEFT", panel, "TOPLEFT", C[2], -oy - 2)
            clbl:SetText(b.class)
            clbl:SetWidth(C[3] - C[2] - 4)

            panel._bufInputs[b.id] = {}
            for s = 1, 2 do
                local inp = CreateFrame("EditBox", "RT3_Buf_" .. b.id .. "_" .. s, panel, "InputBoxTemplate")
                inp:SetPoint("TOPLEFT", panel, "TOPLEFT", C[s + 2], -oy)
                inp:SetWidth(190)
                inp:SetHeight(20)
                inp:SetAutoFocus(false)
                inp:SetScript("OnEscapePressed", function() inp:ClearFocus() end)
                local bid = b.id
                local si  = s
                inp:SetScript("OnTextChanged", function()
                    local d = getBufData()
                    if not d[bid] then d[bid] = { "", "" } end
                    d[bid][si] = inp:GetText() or ""
                end)
                panel._bufInputs[b.id][s] = inp
            end

            if math.mod(i, 2) == 0 then
                local rs = panel:CreateTexture(nil, "BACKGROUND")
                rs:SetPoint("TOPLEFT",  panel, "TOPLEFT",  6, -(oy + rowH - 2))
                rs:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -(oy + rowH - 2))
                rs:SetHeight(1)
                rs:SetTexture(0.12, 0.12, 0.20, 0.6)
            end
        end
    end,

    show = function(panel)
        if panel._bufRefresh then panel._bufRefresh() end
    end,
})
