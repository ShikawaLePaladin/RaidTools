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
    { idx=0, name="Aucun",        tc=nil                    },
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
        { name="Pack Lucifron",      tc=2, marks={"Skull","Cross"},          note="Flamewaker Protector au Skull. Interrompre les soins des Flamewaker." },
        { name="Core Hounds",        tc=2, marks={"Skull","Cross"},          note="Tuer les chiens groupes (~10s) sinon resurrection." },
        { name="Firesworn (Garr)",   tc=1, marks={"Skull"},                  note="Explosent a la mort. Tuer a l'ecart du raid." },
    },
    ["Blackwing Lair"] = {
        { name="Suppression Room",   tc=2, marks={"Skull","Cross"},          note="Desamorcer les Suppression Devices. Pull en chaine." },
        { name="Death Talon Drakonid",tc=2, marks={"Skull","Cross"},         note="Tanks separes. Focus Skull, interrompre." },
    },
    ["Temple of Ahn"] = {
        { name="Anubisath (entree)", tc=2, marks={"Skull","Cross"},          note="Gros adds. Tank chacun, focus Skull." },
        { name="Qiraji Champion",    tc=2, marks={"Skull","Cross"},          note="CC les casters si possible. Kill Skull puis Cross." },
    },
    ["Naxxramas"] = {
        { name="Aile Araignee",      tc=2, marks={"Skull","Cross"},          note="Web Wrap aleatoire. Focus Skull." },
        { name="Aile Abomination",   tc=2, marks={"Skull","Cross"},          note="Slimes : eviter la fusion." },
        { name="Quartier Militaire", tc=3, marks={"Skull","Cross","Square"}, note="Death Knights : interrompre. Gerer les invocations." },
        { name="Quartier Construction",tc=2, marks={"Skull","Cross"},        note="Patchwork/Stitched : poison. Focus groupe." },
    },
}

-- Popup de saisie pour ajouter un pack de trash perso
StaticPopupDialogs["RT3_ADD_TRASH"] = {
    text = "Nom du pack de trash :",
    button1 = "Ajouter",
    button2 = "Annuler",
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
    tip      = "Par boss : tanks + marqueurs de cible, soins par groupe, note tactique. Les packs de trash (orange) sont sous chaque raid.",
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
        bossTitle:SetText("|cff666666— Sélectionne un boss —|r")

        local presetBtn = RT.UI.Button(det, {
            text="Charger Preset", width=128, height=20, color={0.15,0.35,0.55},
            anchor={"TOPRIGHT", det, "TOPRIGHT", -4, -6},
        })

        local trashBtn = RT.UI.Button(det, {
            text="+ Trash", width=62, height=20, color={0.45,0.30,0.10},
            anchor={"TOPRIGHT", det, "TOPRIGHT", -136, -6},
            tooltip="Ajoute un pack de trash perso au raid de l'entrée sélectionnée.",
        })
        trashBtn:SetScript("OnClick", function()
            local raid = det._current and det._entryRaid and det._entryRaid[det._current]
            if not raid then
                RT.Print("|cffFFAA00Sélectionne d'abord un boss/trash du raid voulu.|r")
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
                        SendChatMessage("["..boss.."] Soins tank: "..table.concat(hn," / "), "RAID")
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
                RT.Print("|cff44FF88Preset rechargé: "..boss.."|r")
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
            RT.Print("|cff44FF88Trash ajouté à "..raid..": "..name.."|r")
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
