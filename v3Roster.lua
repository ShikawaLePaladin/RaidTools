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
            tooltip = "Sets each player's role from their spec, and requests the spec of anyone still missing one (RaidTools users reply silently, others by whisper). Incoming replies fill the role automatically.",
            onClick = function()
                if not RT3_RoleFromSpec then
                    RT.Print("|cffFF4444RT3_RoleFromSpec not loaded.|r") return
                end
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
                if changed > 0 then RT.Store.Notify("roster") end
                if missing > 0 then
                    RT.Print("|cff44FF88Auto-roles: " .. changed .. " role(s) set ; requesting " .. missing .. " missing spec(s)...|r")
                    if RT3_AskSpecs then RT3_AskSpecs(true)
                    else RT.Print("|cffFFAA00(WhisperBot module not loaded yet — open that tab once to activate.)|r") end
                elseif changed > 0 then
                    RT.Print("|cff44FF88Auto-roles: " .. changed .. " player(s) updated (all specs known).|r")
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
        impTitle:SetText("|cffFFD700Import roster|r — paste the |cff88CCFFraidres (CSV Attendees)|r or |cff88CCFFsoftres (JSON)|r export, then click Import.  (Ctrl+V to paste)")

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
            if first == "{" or first == "[" then fn, label = RT_ImportSoftResJSON, "JSON"
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
