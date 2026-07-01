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
