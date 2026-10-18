-- ============================================================
-- RT v5 — RT_SchemaEdit.lua
--
-- RETOUCHES PERSONNELLES DU SCHÉMA (partagé par RaidTools complet et RaidTools Membre).
-- Le schéma du site reste la base ; ici on ne stocke que TES retouches par-dessus, par raid / boss / phase :
--   - déplacer un élément (jeton, monstre, marque, zone, extrémité de flèche, note)
--   - supprimer un élément (clic droit)
--   - agrandir / réduire une zone (molette sur sa poignée)
--   - ajouter des jetons de rôle, des marques, des monstres, des zones, des flèches, des notes
-- Si le schéma du site change, tes retouches suivent (elles visent l'élément, pas sa position) ;
-- celles qui visent un élément disparu sont ignorées.
-- Stockage : db.octofanUI.schemaMods["raid/boss/phase"] = { rev, seq, mv = {id -> champs}, hide = {id -> true}, add = { {id, k, ...} } }
-- (que des chaînes / nombres / booléens : prêt à être envoyé au raid plus tard).
-- Lua 5.0 strict (pas de #, %, select, string.match) ; les scripts des widgets lisent leurs données sur `this`
-- (une variable de boucle n'existe plus quand la fonction est appelée plus tard).
-- ============================================================

RTV = RTV or {}
local V = RTV

local SQUARE = "Interface\\Buttons\\WHITE8X8"
local ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local SYMS = { "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull" }
local HIST_MAX = 30

local on = false
local panel = nil
local hist = {}
local lastWheel = { id = nil, at = 0 }

-- ============================================================
-- Données
-- ============================================================

local function DB() return RT.Store.DB() end

local function Peek(key)
    if not key then return nil end
    local u = DB().octofanUI
    return u and u.schemaMods and u.schemaMods[key] or nil
end

local function Get(key)
    local db = DB()
    db.octofanUI = db.octofanUI or {}
    db.octofanUI.schemaMods = db.octofanUI.schemaMods or {}
    local m = db.octofanUI.schemaMods[key]
    if not m then
        m = { rev = 0, seq = 0, mv = {}, hide = {}, add = {} }
        db.octofanUI.schemaMods[key] = m
    end
    m.mv = m.mv or {}
    m.hide = m.hide or {}
    m.add = m.add or {}
    return m
end

local function Copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = Copy(v) end
    return c
end

local function R1(v) return math.floor(v * 10 + 0.5) / 10 end

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Le schéma de base + tes retouches = ce qui est dessiné. Chaque élément reçoit un identifiant stable (_id) :
-- type + nom + numéro d'ordre (pas sa position, qui est justement ce que tu changes).
function V.ApplyMods(key, pd)
    if not pd then return pd end
    local m = Peek(key)
    local out = {}
    for k, v in pairs(pd) do out[k] = v end
    out.zones, out.arrows, out.syms = {}, {}, {}
    local occ = {}
    local function Take(list, dst, prefix, namefn)
        for _, e in ipairs(list or {}) do
            local c = {}
            for k, v in pairs(e) do c[k] = v end
            local base = prefix .. ":" .. namefn(e)
            occ[base] = (occ[base] or 0) + 1
            local id = base .. ":" .. occ[base]
            c._id = id
            if not (m and m.hide and m.hide[id]) then
                local mv = m and m.mv and m.mv[id]
                if mv then
                    for k, v in pairs(mv) do c[k] = v end
                end
                table.insert(dst, c)
            end
        end
    end
    Take(pd.zones, out.zones, "z", function(e) return (e.kind or "") .. ":" .. (e.label or "") end)
    Take(pd.arrows, out.arrows, "a", function(e) return "" end)
    Take(pd.syms, out.syms, "s", function(e)
        local nm = e.label or e.symbol or e.role or ""
        if e.poste and e.poste ~= "" then nm = e.poste end
        return (e.type or "") .. ":" .. nm
    end)
    if m and m.add then
        for _, a in ipairs(m.add) do
            local c = {}
            for k, v in pairs(a) do c[k] = v end
            c._id = a.id
            c._user = true
            local dst = out.syms
            if a.k == "z" then dst = out.zones elseif a.k == "a" then dst = out.arrows end
            table.insert(dst, c)
        end
    end
    return out
end

function V.SigPart(key)
    local m = Peek(key)
    return tostring(m and m.rev or 0) .. (on and "e" or "")
end

local function AddedIndex(m, id)
    for i = 1, table.getn(m.add) do
        if m.add[i].id == id then return i end
    end
    return nil
end

local function Push(key)
    local m = Peek(key)
    table.insert(hist, { key = key, snap = m and Copy(m) or false })
    if table.getn(hist) > HIST_MAX then table.remove(hist, 1) end
end

local function Touch(key)
    local m = Get(key)
    m.rev = (m.rev or 0) + 1
    V.Refresh(true)
end

function V.EditMove(key, id, fields, nopush)
    if not key or not id then return end
    if not nopush then Push(key) end
    local m = Get(key)
    local ai = AddedIndex(m, id)
    local dst
    if ai then
        dst = m.add[ai]
    else
        m.mv[id] = m.mv[id] or {}
        dst = m.mv[id]
    end
    for k, v in pairs(fields) do dst[k] = v end
    Touch(key)
end

function V.EditDelete(key, id)
    if not key or not id then return end
    Push(key)
    local m = Get(key)
    local ai = AddedIndex(m, id)
    if ai then
        table.remove(m.add, ai)
        m.mv[id] = nil
    else
        m.hide[id] = true
    end
    Touch(key)
end

local function AddEl(el)
    local key = V.curKey
    if not key then return end
    Push(key)
    local m = Get(key)
    m.seq = (m.seq or 0) + 1
    el.id = "u" .. m.seq
    table.insert(m.add, el)
    Touch(key)
end

function V.EditUndo()
    local h = table.remove(hist)
    if not h then RT.Print("Rien à annuler.") return end
    local db = DB()
    db.octofanUI = db.octofanUI or {}
    db.octofanUI.schemaMods = db.octofanUI.schemaMods or {}
    local rev = (db.octofanUI.schemaMods[h.key] and db.octofanUI.schemaMods[h.key].rev or 0) + 1
    if h.snap then
        h.snap.rev = rev
        db.octofanUI.schemaMods[h.key] = h.snap
    else
        db.octofanUI.schemaMods[h.key] = nil
    end
    V.Refresh(true)
end

function V.EditReset(key)
    if not key then return end
    Push(key)
    local db = DB()
    if db.octofanUI and db.octofanUI.schemaMods then db.octofanUI.schemaMods[key] = nil end
    V.Refresh(true)
end

-- ============================================================
-- Poignées (une par élément éditable, au-dessus du schéma)
-- ============================================================

local function HandleList(canvas)
    local P = canvas.rtvh
    if not P then
        P = { list = {}, n = 0 }
        canvas.rtvh = P
    end
    return P
end

function V.HideHandles(canvas)
    local P = canvas.rtvh
    if not P then return end
    for i = 1, table.getn(P.list) do P.list[i]:Hide() end
    P.n = 0
end

local function DragUpdate()
    local cv = this.cv
    local cx, cy = GetCursorPosition()
    local s = cv:GetEffectiveScale()
    if type(s) ~= "number" or s <= 0 then s = 1 end
    cx, cy = cx / s, cy / s
    local l, t = cv:GetLeft(), cv:GetTop()
    if type(l) ~= "number" or type(t) ~= "number" then return end
    local x = Clamp(cx - l, 0, this.cw)
    local y = Clamp(t - cy, 0, this.ch)
    this.nx, this.ny = x, y
    this:ClearAllPoints()
    this:SetPoint("CENTER", cv, "TOPLEFT", x, -y)
end

local function OnDragStart()
    this.dragging = true
    GameTooltip:Hide()
    this:SetScript("OnUpdate", DragUpdate)
end

local function OnDragStop()
    this:SetScript("OnUpdate", nil)
    if not this.dragging then return end
    this.dragging = false
    local nx, ny = this.nx, this.ny
    this.nx = nil
    if not nx then return end
    local px, py = R1(nx / this.cw * 100), R1(ny / this.ch * 100)
    local fields
    if this.part == 1 then fields = { x1 = px, y1 = py }
    elseif this.part == 2 then fields = { x2 = px, y2 = py }
    else fields = { x = px, y = py } end
    V.EditMove(V.curKey, this.eid, fields)
end

local function OnClick()
    if arg1 == "RightButton" then
        GameTooltip:Hide()
        V.EditDelete(V.curKey, this.eid)
    end
end

local function OnEnter()
    this.bg:SetAlpha(0.6)
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(this.tip or "", 0.6, 0.9, 1)
    GameTooltip:AddLine("Glisser : déplacer  ·  Clic droit : supprimer", 0.8, 0.8, 0.8)
    if this.zrx then GameTooltip:AddLine("Molette : agrandir / réduire la zone", 0.8, 0.8, 0.8) end
    GameTooltip:Show()
end

local function OnLeave()
    this.bg:SetAlpha(0.3)
    GameTooltip:Hide()
end

local function OnWheel()
    if not this.zrx then return end
    local f = 1 / 1.12
    if arg1 > 0 then f = 1.12 end
    local rx, ry = Clamp(this.zrx * f, 1.5, 45), Clamp(this.zry * f, 1.5, 45)
    this.zrx, this.zry = rx, ry
    local same = (lastWheel.id == this.eid) and (GetTime() - lastWheel.at < 1.5)
    lastWheel.id, lastWheel.at = this.eid, GetTime()
    V.EditMove(V.curKey, this.eid, { rx = R1(rx), ry = R1(ry) }, same)
end

local function MakeHandle(canvas, cx, cy, w, h, id, part, tip, r, g, b)
    local P = HandleList(canvas)
    P.n = P.n + 1
    local f = P.list[P.n]
    if not f then
        f = CreateFrame("Button", nil, canvas)
        f:SetFrameLevel(canvas:GetFrameLevel() + 6)
        f:EnableMouse(true)
        f:EnableMouseWheel(true)
        f:RegisterForClicks("RightButtonUp")
        f:RegisterForDrag("LeftButton")
        f.bg = f:CreateTexture(nil, "OVERLAY")
        f.bg:SetAllPoints(f)
        f.bg:SetTexture(SQUARE)
        f:SetScript("OnDragStart", OnDragStart)
        f:SetScript("OnDragStop", OnDragStop)
        f:SetScript("OnClick", OnClick)
        f:SetScript("OnEnter", OnEnter)
        f:SetScript("OnLeave", OnLeave)
        f:SetScript("OnMouseWheel", OnWheel)
        P.list[P.n] = f
    end
    f.cv = canvas
    f.cw, f.ch = canvas:GetWidth(), canvas:GetHeight()
    f.eid, f.part, f.tip = id, part, tip
    f.zrx, f.zry, f.dragging = nil, nil, false
    f:SetWidth(w)
    f:SetHeight(h)
    f:ClearAllPoints()
    f:SetPoint("CENTER", canvas, "TOPLEFT", cx, -cy)
    f.bg:SetVertexColor(r, g, b, 1)
    f.bg:SetAlpha(0.3)
    f:Show()
    return f
end

function V.EditHandles(canvas, L)
    if panel and panel.info then
        local key = V.curKey or ""
        local m = Peek(key)
        local n = 0
        if m then
            for _ in pairs(m.mv or {}) do n = n + 1 end
            for _ in pairs(m.hide or {}) do n = n + 1 end
            n = n + table.getn(m.add or {})
        end
        panel.info:SetText("|cff999999" .. key .. "|r\n" .. (n > 0 and ("|cff66ccff" .. n .. " retouche(s)|r") or "|cff888888aucune retouche|r"))
    end
    for _, z in ipairs(L.zones) do
        if z.id then
            local f = MakeHandle(canvas, z.cx, z.cy, 16, 16, z.id, 0, "Zone", 1, 0.9, 0.3)
            f.zrx, f.zry = z.srx, z.sry
        end
    end
    for _, a in ipairs(L.arrows) do
        if a.id then
            MakeHandle(canvas, a.x1, a.y1, 14, 14, a.id, 1, "Flèche : départ", 0.4, 1, 0.5)
            MakeHandle(canvas, a.x2, a.y2, 14, 14, a.id, 2, "Flèche : pointe", 1, 0.7, 0.2)
        end
    end
    for _, ic in ipairs(L.icons) do
        if ic.id then
            local sz = ic.size
            if sz < 16 then sz = 16 end
            MakeHandle(canvas, ic.x + ic.size / 2, ic.y + ic.size / 2, sz, sz, ic.id, 0, "Marque / monstre", 0.4, 0.9, 1)
        end
    end
    for _, n in ipairs(L.notes) do
        if n.id then
            MakeHandle(canvas, n.x + n.w / 2, n.y + n.h / 2, n.w, n.h, n.id, 0, "Note", 1, 0.85, 0.4)
        end
    end
    for _, tk in ipairs(L.tokens) do
        if tk.id then
            MakeHandle(canvas, tk.x, tk.y, tk.r * 2, tk.r * 2, tk.id, 0, (tk.poste ~= "" and tk.poste or "Jeton"), 0.4, 0.9, 1)
        end
    end
end

-- ============================================================
-- Le panneau d'édition (remplace la colonne de droite pendant les retouches)
-- ============================================================

local function Pos()
    local m = V.curKey and Peek(V.curKey)
    local n = m and m.seq or 0
    return 50 + math.mod(n, 5) * 3, 50 + math.mod(n, 4) * 3
end

local function TextBoxValue()
    local t = panel and panel.edit and panel.edit:GetText() or ""
    t = string.gsub(t, "^%s*(.-)%s*$", "%1")
    return t
end

-- « Tank 3 », « Heal 2 »... : le premier numéro libre parmi les postes déjà présents sur ce schéma
local function AutoPoste(prefix)
    local used = {}
    local pd = V.curPD
    if pd then
        for _, s in ipairs(pd.syms or {}) do
            if s.type == "R" and s.poste then
                local _, _, n = string.find(s.poste, "^" .. prefix .. "%s*(%d+)")
                if n then used[tonumber(n)] = true end
            end
        end
    end
    local i = 1
    while used[i] do i = i + 1 end
    return prefix .. " " .. i
end

-- Les fonctions ci-dessous reçoivent leurs paramètres : chaque bouton a sa propre copie (pas de variable de boucle capturée).
local function MkButton(p, text, x, y, w, tip, fn)
    local b = RT.UI.Button(p, { text = text, width = w, height = 20, anchor = { "TOPLEFT", p, "TOPLEFT", x, -y }, tooltip = tip })
    b:SetScript("OnClick", fn)
    return b
end

local function MkRole(p, text, x, y, w, prefix, role)
    return MkButton(p, text, x, y, w, "Ajoute un jeton « " .. text .. " » (le nom du joueur s'affiche s'il est assigné à ce poste).", function()
        local poste = TextBoxValue()
        if poste == "" then poste = AutoPoste(prefix) end
        local px, py = Pos()
        AddEl({ k = "s", type = "R", role = role, poste = poste, label = poste, x = px, y = py })
    end)
end

local function MkMark(p, symbol, x, y)
    local b = CreateFrame("Button", nil, p)
    b:SetWidth(26)
    b:SetHeight(26)
    b:SetPoint("TOPLEFT", p, "TOPLEFT", x, -y)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(b)
    t:SetTexture(ICON .. (symbol == "star" and 1 or symbol == "circle" and 2 or symbol == "diamond" and 3 or symbol == "triangle" and 4
        or symbol == "moon" and 5 or symbol == "square" and 6 or symbol == "cross" and 7 or 8))
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    b:SetScript("OnClick", function()
        local px, py = Pos()
        AddEl({ k = "s", type = "M", symbol = symbol, label = TextBoxValue(), x = px, y = py })
    end)
    b:SetScript("OnEnter", function()
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText("Ajoute la marque (" .. symbol .. ")", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function MkOther(p, text, x, y, w, tip, fn)
    return MkButton(p, text, x, y, w, tip, function()
        local px, py = Pos()
        fn(px, py, TextBoxValue())
    end)
end

local function BuildPanel()
    local ui = V._ui
    local p = CreateFrame("Frame", nil, ui.right)
    p:SetAllPoints(ui.right)
    p:SetFrameLevel(ui.right:GetFrameLevel() + 20)
    p:EnableMouse(true)
    RT.UI.ApplyBackdrop(p, 0.04, 0.05, 0.09, 1)

    local t = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -8)
    t:SetText("|cffFFCC44Retoucher le schéma|r")
    p.info = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.info:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -26)
    p.info:SetWidth(240)
    p.info:SetJustifyH("LEFT")
    local help = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -58)
    help:SetWidth(240)
    help:SetJustifyH("LEFT")
    help:SetText("|cffcccccc• Glisse un carré bleu pour déplacer un élément.\n• Clic droit dessus : le supprimer.\n• Molette sur le carré jaune d'une zone : la redimensionner.\n• Tes retouches restent sur ton PC.|r")

    local lt = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lt:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -128)
    lt:SetText("Texte (nom du poste, du monstre, de la note…)")
    local eb = CreateFrame("EditBox", "RTV_EditText", p)
    eb:SetWidth(240)
    eb:SetHeight(22)
    eb:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -144)
    eb:SetFontObject(ChatFontNormal)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(40)
    eb:SetBackdrop({ bgFile = SQUARE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    eb:SetBackdropColor(0, 0, 0, 0.9)
    eb:SetTextInsets(6, 6, 0, 0)
    eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    p.edit = eb

    local h1 = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h1:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -176)
    h1:SetText("Ajouter un joueur")
    MkRole(p, "Tank", 10, 194, 56, "Tank", "tank")
    MkRole(p, "Heal", 70, 194, 56, "Heal", "heal")
    MkRole(p, "CaC", 130, 194, 56, "CaC", "melee")
    MkRole(p, "Dist", 190, 194, 56, "Dist", "ranged")

    local h2 = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h2:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -222)
    h2:SetText("Ajouter une marque")
    for i = 1, table.getn(SYMS) do
        MkMark(p, SYMS[i], 10 + (i - 1) * 30, 240)
    end

    local h3 = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h3:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -274)
    h3:SetText("Ajouter autre chose")
    MkOther(p, "Monstre", 10, 292, 76, "Un carré rouge de monstre (le texte ci-dessus = son nom).", function(x, y, txt)
        AddEl({ k = "s", type = "C", label = (txt ~= "" and txt or "Monstre"), x = x, y = y })
    end)
    MkOther(p, "Boss", 90, 292, 76, "L'icône du boss.", function(x, y, txt)
        AddEl({ k = "s", type = "B", label = txt, x = x, y = y })
    end)
    MkOther(p, "Note", 170, 292, 76, "Un texte libre sur le schéma (écris-le dans la case ci-dessus).", function(x, y, txt)
        AddEl({ k = "s", type = "T", label = (txt ~= "" and txt or "Note"), x = x, y = y })
    end)
    MkOther(p, "Zone danger", 10, 316, 118, "Zone rouge (à éviter).", function(x, y, txt)
        AddEl({ k = "z", kind = "danger", x = x, y = y, rx = 8, ry = 12, label = txt })
    end)
    MkOther(p, "Zone sûre", 132, 316, 114, "Zone verte (où aller).", function(x, y, txt)
        AddEl({ k = "z", kind = "safe", x = x, y = y, rx = 8, ry = 12, label = txt })
    end)
    MkOther(p, "Flèche", 10, 340, 118, "Une flèche : déplace son départ (vert) et sa pointe (orange).", function(x, y, txt)
        AddEl({ k = "a", x1 = 38, y1 = 50, x2 = 62, y2 = 50 })
    end)

    MkButton(p, "Annuler", 10, 384, 76, "Annule la dernière retouche.", function() V.EditUndo() end)
    local reset = MkButton(p, "Tout remettre", 90, 384, 100, "Efface TOUTES tes retouches de cette phase (re-clique pour confirmer).", function()
        if p.confirmAt and GetTime() - p.confirmAt < 4 then
            p.confirmAt = nil
            p.resetB:SetText("Tout remettre")
            V.EditReset(V.curKey)
        else
            p.confirmAt = GetTime()
            p.resetB:SetText("Confirmer ?")
        end
    end)
    p.resetB = reset
    MkButton(p, "Terminer", 194, 384, 52, "Quitte le mode retouche.", function() V.SetEdit(false) end)

    p:SetScript("OnUpdate", function()
        if this.confirmAt and GetTime() - this.confirmAt >= 4 then
            this.confirmAt = nil
            this.resetB:SetText("Tout remettre")
        end
    end)
    p:Hide()
    return p
end

function V.SetEdit(v)
    local ui = V._ui
    if not ui or not ui.canvas then return end
    on = v and true or false
    if on and not panel then panel = BuildPanel() end
    ui.canvas.rtvEdit = on
    if panel then
        if on then panel:Show() else panel:Hide() end
    end
    if ui.editB and ui.editB.GetFontString then
        local fs = ui.editB:GetFontString()
        if fs then
            if on then fs:SetTextColor(0.4, 0.9, 1) else fs:SetTextColor(1, 1, 1) end
        end
    end
    V.Refresh(true)
end

function V.ToggleEdit() V.SetEdit(not on) end
function V.IsEdit() return on end
