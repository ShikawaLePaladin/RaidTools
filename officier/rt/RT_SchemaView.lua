-- ============================================================
-- RT v5 — RT_SchemaView.lua
--
-- LA FENÊTRE « RAID » AGRANDIE (partagée par RaidTools complet et RaidTools Membre) :
--   - colonne gauche : raids -> boss (✓ = boss tombé)
--   - centre : le SCHÉMA en grand (16:9, ~70-90 % de la largeur de l'écran), fond du boss,
--     jetons de rôle avec le NOM du joueur placé sans chevauchement (les jetons qui se
--     superposent sont écartés, chaque nom cherche une place libre autour de son jeton)
--   - dessous : préparation, stratégie, trash
--   - droite : MON RÔLE sur ce boss + TOUTES les assignations (clic : cibler, clic droit : chuchoter)
--
-- Ne dépend que de RT.Store.DB() / RT.Print / RT.UI.TextScroll (+ RT.UI.Button, RT.UI.ApplyBackdrop).
-- Données lues : db.octofanSchemas (schémas OS1) et db.octofan (plan OFP).
-- RT_ADDON_DIR (facultatif) : dossier de l'addon, pour l'image de fond (défaut "rt").
-- Lua 5.0 strict (pas de #, %, select, string.match).
-- ============================================================

RTV = RTV or {}
local V = RTV

local SITE_URL = "https://octofan.vercel.app/raid/"
local SCHEMA_IMG = {
    lucifron = true, magmadar = true, garr = true, baron_geddon = true, incindis = true,
    golemagg = true, majordomo = true, ragnaros = true, shazzrah = true, sulfuron = true,
}
local SCHEMA_ICON = {
    star = 1, circle = 2, diamond = 3, triangle = 4,
    moon = 5, square = 6, cross = 7, skull = 8,
}
local ROLE_COLOR = {
    tank   = { 0.45, 0.65, 1.00 },
    heal   = { 0.35, 0.90, 0.45 },
    melee  = { 1.00, 0.55, 0.35 },
    ranged = { 0.75, 0.55, 1.00 },
}
local CLASS_COLOR = {
    WARRIOR = { 0.78, 0.61, 0.43 }, PRIEST = { 1.00, 1.00, 1.00 }, MAGE = { 0.41, 0.80, 0.94 },
    WARLOCK = { 0.58, 0.51, 0.79 }, DRUID = { 1.00, 0.49, 0.04 }, PALADIN = { 0.96, 0.55, 0.73 },
    ROGUE = { 1.00, 0.96, 0.41 }, HUNTER = { 0.67, 0.83, 0.45 }, SHAMAN = { 0.00, 0.44, 0.87 },
}
local FONT = "Fonts\\FRIZQT__.TTF"
local CIRCLE = "Interface\\Minimap\\UI-Minimap-Background"
local SQUARE = "Interface\\Buttons\\WHITE8X8"

-- ============================================================
-- Données
-- ============================================================

local function DB() return RT.Store.DB() end
local function Schemas() return DB().octofanSchemas or {} end
local function Plan() return DB().octofan end

-- boss dont l'image de fond est livree (liste generee : RT_BossImages.lua ; liste d'origine en secours)
local function HasImg(slug)
    return SCHEMA_IMG[slug] or (RT_SCHEMA_IMG and RT_SCHEMA_IMG[slug]) or false
end

local function Hex(c)
    return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
end

-- Un poste peut contenir plusieurs joueurs ("Bob, Alice") : comparaison EXACTE par nom.
local function IsMe(field, me)
    if not field or not me then return false end
    local lme = string.lower(me)
    for piece in string.gfind(field, "[^,]+") do
        local tok = string.gsub(piece, "^%s*(.-)%s*$", "%1")
        if string.lower(tok) == lme then return true end
    end
    return false
end

local function FirstName(who)
    local _, _, f = string.find(who or "", "^%s*([^,]+)")
    if f then f = string.gsub(f, "%s+$", "") end
    return f
end

local function ClassOf(name)
    local plan = Plan()
    local r = plan and plan.roster and name and plan.roster[name]
    if r and r.class then return CLASS_COLOR[string.upper(r.class)] end
    return nil
end

local function Trunc(s, n)
    s = s or ""
    if string.len(s) > n then return string.sub(s, 1, n - 2) .. ".." end
    return s
end

-- Navigation raids -> boss (schémas du site, sinon le plan)
local function NavList()
    local out, seen = {}, {}
    for slug, R in pairs(Schemas()) do
        local bosses = {}
        for bslug, B in pairs(R.bosses or {}) do
            table.insert(bosses, { slug = bslug, name = B.name or bslug, order = B.order })
        end
        if table.getn(bosses) > 0 then
            table.sort(bosses, function(a, b)
                local oa, ob = a.order or 9999, b.order or 9999
                if oa ~= ob then return oa < ob end
                return (a.name or "") < (b.name or "")
            end)
            table.insert(out, { slug = slug, name = R.name or slug, bosses = bosses })
            seen[slug] = true
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    local plan = Plan()
    if plan and plan.raid and plan.raid ~= "" and not seen[plan.raid] then
        local bosses = {}
        for _, b in ipairs(plan.bossOrder or {}) do
            table.insert(bosses, { slug = b, name = b })
        end
        if table.getn(bosses) > 0 then
            table.insert(out, { slug = plan.raid, name = plan.raid, bosses = bosses })
        end
    end
    return out
end

-- ============================================================
-- MISE EN PAGE (fonction pure : testable hors du jeu)
--   phaseData : { zones, arrows, syms, tips } en % (0-100)
--   assign    : plan.assign[boss] = { [poste] = { player, task } }
--   measure(text, taille) -> largeur en pixels
-- Retourne les primitives à dessiner, en pixels du canevas (origine en haut à gauche).
-- ============================================================

local function ShortCode(poste)
    local _, _, l, d = string.find(poste or "", "^(%a)%a*%s*(%d*)")
    if not l then return "?" end
    return string.upper(l) .. (d or "")
end

-- Version SIMPLIFIEE pour le petit schéma (320x180) : on garde le boss, les monstres, les zones et les flèches,
-- au plus 3 tanks, 1-2 points de heals, 1 point de CaC et 1 point de casters (sans noms de joueurs : « Heals », « CaC », « Dist »).
local function Simplify(pd)
    if not pd then return nil end
    local out = { zones = pd.zones or {}, arrows = pd.arrows or {}, tips = pd.tips or {}, syms = {} }
    local tanks, groups = {}, { heal = {}, melee = {}, ranged = {} }
    local adds, seenAdds = 0, {}
    for _, s in ipairs(pd.syms or {}) do
        if s.type == "R" then
            if s.role == "heal" or s.role == "melee" or s.role == "ranged" then table.insert(groups[s.role], s)
            else table.insert(tanks, s) end
        elseif s.type == "C" then
            -- monstres : un seul par nom (deux « Core Hound » superposés rendent le petit schéma illisible), 3 au plus
            local key = s.label or ""
            if not seenAdds[key] and adds < 3 then
                seenAdds[key] = true
                adds = adds + 1
                table.insert(out.syms, s)
            end
        elseif s.type ~= "T" then
            table.insert(out.syms, s)
        end
    end
    table.sort(tanks, function(a, b)
        if (a.poste or "") ~= (b.poste or "") then return (a.poste or "") < (b.poste or "") end
        return (a.x or 0) < (b.x or 0)
    end)
    for i = 1, 3 do
        if tanks[i] then table.insert(out.syms, tanks[i]) end
    end
    local LABEL = { heal = "Heals", melee = "CaC", ranged = "Dist" }
    for role, list in pairs(groups) do
        local n = table.getn(list)
        if n > 0 then
            local pts = {}
            if n >= 2 and role == "heal" then
                -- deux points de heals : les deux plus éloignés servent de graines, les autres vont au plus proche
                local ai, bi, far = 1, 2, -1
                for i = 1, n do
                    for j = i + 1, n do
                        local dx, dy = list[i].x - list[j].x, list[i].y - list[j].y
                        local d = dx * dx + dy * dy
                        if d > far then far, ai, bi = d, i, j end
                    end
                end
                local A, B = { x = 0, y = 0, n = 0 }, { x = 0, y = 0, n = 0 }
                for i = 1, n do
                    local da = (list[i].x - list[ai].x) ^ 2 + (list[i].y - list[ai].y) ^ 2
                    local db = (list[i].x - list[bi].x) ^ 2 + (list[i].y - list[bi].y) ^ 2
                    local G = (da <= db) and A or B
                    G.x, G.y, G.n = G.x + list[i].x, G.y + list[i].y, G.n + 1
                end
                if A.n > 0 then table.insert(pts, { x = A.x / A.n, y = A.y / A.n }) end
                if B.n > 0 then table.insert(pts, { x = B.x / B.n, y = B.y / B.n }) end
                -- deux points presque confondus : un seul
                if table.getn(pts) == 2 and (pts[1].x - pts[2].x) ^ 2 + (pts[1].y - pts[2].y) ^ 2 < 100 then
                    pts = { { x = (pts[1].x + pts[2].x) / 2, y = (pts[1].y + pts[2].y) / 2 } }
                end
            else
                local sx, sy = 0, 0
                for i = 1, n do sx, sy = sx + list[i].x, sy + list[i].y end
                pts = { { x = sx / n, y = sy / n } }
            end
            for _, p in ipairs(pts) do
                table.insert(out.syms, { type = "R", role = role, x = p.x, y = p.y, poste = "", label = LABEL[role], grp = LABEL[role] })
            end
        end
    end
    return out
end
V.Simplify = Simplify

local function Layout(phaseData, assign, CW, CH, measure, small)
    local L = { zones = {}, arrows = {}, icons = {}, notes = {}, tokens = {}, labels = {}, texts = {} }
    if not phaseData then return L end
    local K = CW / 320
    local D = math.floor(16 + 5.5 * K)               -- diamètre d'un jeton
    if D > 36 then D = 36 end
    if D < 16 then D = 16 end
    local FS = math.floor(11 + 1.8 * K)               -- taille des textes
    if FS > 18 then FS = 18 end
    if small then D, FS = 23, 12 end                  -- petit schéma : jetons et textes plus gros que l'échelle ne le voudrait
    L.D, L.FS, L.K = D, FS, K

    -- obstacles : rectangles déjà occupés (jetons, icônes, textes posés)
    local obst = {}
    local function AddObst(x, y, w, h) table.insert(obst, { x, y, w, h }) end
    local function Penalty(x, y, w, h)
        local pen = 0
        for i = 1, table.getn(obst) do
            local o = obst[i]
            local ix = math.min(x + w, o[1] + o[3]) - math.max(x, o[1])
            local iy = math.min(y + h, o[2] + o[4]) - math.max(y, o[2])
            if ix > 0 and iy > 0 then pen = pen + ix * iy end
        end
        if x < 0 then pen = pen + (-x) * h * 4 end
        if y < 0 then pen = pen + (-y) * w * 4 end
        if x + w > CW then pen = pen + (x + w - CW) * h * 4 end
        if y + h > CH then pen = pen + (y + h - CH) * w * 4 end
        return pen
    end
    local function Clamp(x, y, w, h)
        if x + w > CW - 2 then x = CW - 2 - w end
        if x < 2 then x = 2 end
        if y + h > CH - 2 then y = CH - 2 - h end
        if y < 2 then y = 2 end
        return x, y
    end
    -- première position candidate sans chevauchement (sinon la moins gênante)
    local function Place(w, h, cands)
        local best, bx, by = nil, nil, nil
        for i = 1, table.getn(cands) do
            local x, y = Clamp(cands[i][1], cands[i][2], w, h)
            local pen = Penalty(x, y, w, h) + i * 2
            if best == nil or pen < best then best, bx, by = pen, x, y end
            if Penalty(x, y, w, h) < 1 then break end
        end
        AddObst(bx, by, w, h)
        return bx, by
    end

    -- zones et flèches : dessinées sous le reste, pas des obstacles
    local zlabels = {}
    for _, z in ipairs(phaseData.zones or {}) do
        local cx, cy = z.x / 100 * CW, z.y / 100 * CH
        local rx = math.max((z.rx or 6) * CW / 100, D * 0.6)
        local ry = math.max((z.ry or 9) * CH / 100, D * 0.6)
        table.insert(L.zones, { cx = cx, cy = cy, rx = rx, ry = ry, kind = z.kind or "danger", id = z._id, srx = z.rx or 6, sry = z.ry or 9 })
        if z.label and z.label ~= "" then table.insert(zlabels, { cx = cx, cy = cy, rx = rx, ry = ry, text = z.label }) end
    end
    for _, a in ipairs(phaseData.arrows or {}) do
        table.insert(L.arrows, { x1 = a.x1 / 100 * CW, y1 = a.y1 / 100 * CH, x2 = a.x2 / 100 * CW, y2 = a.y2 / 100 * CH, id = a._id })
    end

    -- icônes (boss, adds, marqueurs) : position fixe
    local roles, notes, icolabels = {}, {}, {}
    for _, s in ipairs(phaseData.syms or {}) do
        local px, py = s.x / 100 * CW, s.y / 100 * CH
        if s.type == "R" then
            table.insert(roles, s)
        elseif s.type == "T" then
            table.insert(notes, { px = px, py = py, text = s.label or "", id = s._id })
        else
            local size, tex, col, lbl, lcol = D, nil, nil, s.label or "", { 0.95, 0.95, 0.85 }
            if s.type == "B" then
                size = math.floor(D * 1.5); tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"; lcol = { 1, 0.55, 0.5 }
            elseif s.type == "C" then
                size = math.floor(D * 0.8); tex = SQUARE; col = { 0.85, 0.30, 0.25, 0.95 }; lcol = { 1, 0.82, 0.78 }
                if s.count and s.count ~= "" then lbl = lbl .. " x" .. s.count end
            else
                tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. (SCHEMA_ICON[s.symbol] or 1)
                size = math.floor(D * 1.1)
            end
            local ix, iy = Clamp(px - size / 2, py - size / 2, size, size)
            table.insert(L.icons, { x = ix, y = iy, size = size, tex = tex, col = col, id = s._id })
            AddObst(ix, iy, size, size)
            if lbl ~= "" then table.insert(icolabels, { ix = ix, iy = iy, size = size, text = lbl, col = lcol }) end
        end
    end

    -- jetons de rôle : écartés des autres jetons ET des icônes
    local placed = {}
    local function TokenFree(x, y)
        for i = 1, table.getn(placed) do
            local dx, dy = x - placed[i].x, y - placed[i].y
            if dx * dx + dy * dy < (D * 1.08) * (D * 1.08) then return false end
        end
        for i = 1, table.getn(L.icons) do
            local ic = L.icons[i]
            local nx = math.max(ic.x, math.min(x, ic.x + ic.size))
            local ny = math.max(ic.y, math.min(y, ic.y + ic.size))
            local dx, dy = x - nx, y - ny
            if dx * dx + dy * dy < (D / 2 + 1) * (D / 2 + 1) then return false end
        end
        return true
    end
    table.sort(roles, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        if a.x ~= b.x then return a.x < b.x end
        return (a.poste or "") < (b.poste or "")
    end)
    for _, s in ipairs(roles) do
        local px, py = s.x / 100 * CW, s.y / 100 * CH
        local half = D / 2 + 2
        if px < half then px = half end
        if px > CW - half then px = CW - half end
        if py < half then py = half end
        if py > CH - half then py = CH - half end
        local tx, ty = px, py
        if not TokenFree(tx, ty) then
            local found = false
            for ring = 1, 8 do
                for a = 0, 7 do
                    local ang = (a * 45 + ring * 17) * math.pi / 180
                    local qx = px + math.cos(ang) * ring * D * 0.62
                    local qy = py + math.sin(ang) * ring * D * 0.62
                    if qx >= half and qx <= CW - half and qy >= half and qy <= CH - half and TokenFree(qx, qy) then
                        tx, ty = qx, qy
                        found = true
                        break
                    end
                end
                if found then break end
            end
        end
        local who = ""
        if assign and s.poste and s.poste ~= "" then
            local slot = assign[s.poste]
            if slot and slot.player then who = slot.player end
        end
        local tk = { x = tx, y = ty, r = D / 2, role = s.role or "tank", poste = s.poste or "", label = s.label or "",
            code = ShortCode(s.poste ~= "" and s.poste or s.label), who = who, grp = s.grp, id = s._id }
        if s.grp then tk.code = string.sub(s.grp, 1, 1) end
        table.insert(placed, tk)
        table.insert(L.tokens, tk)
        AddObst(tx - D / 2, ty - D / 2, D, D)
    end

    -- 1. les NOMS : chacun cherche une place libre autour de son jeton (le plus important)
    local ORDER = { 0, 180, 90, 270, 45, 135, 315, 225, 20, 160, 200, 340, 70, 110, 250, 290 }
    for _, tk in ipairs(L.tokens) do
        local text = (tk.who ~= "") and Trunc(tk.who, 24) or (tk.poste ~= "" and tk.poste or tk.label)
        if text ~= "" then
            local w = measure(text, FS) + 6
            local h = FS + 4
            local cands = {}
            for k = 0, 4 do
                for _, deg in ipairs(ORDER) do
                    local a = deg * math.pi / 180
                    local ca, sa = math.cos(a), math.sin(a)
                    local cx = tk.x + ca * (tk.r + 3 + (w / 2) * math.abs(ca) + k * (h * 0.9))
                    local cy = tk.y + sa * (tk.r + 3 + (h / 2) * math.abs(sa) + k * (h * 0.9))
                    table.insert(cands, { cx - w / 2, cy - h / 2 })
                end
            end
            local bx, by = Place(w, h, cands)
            table.insert(L.labels, { x = bx, y = by, w = w, h = h, text = text, who = tk.who, poste = tk.poste,
                role = tk.role, free = (tk.who == "" and not tk.grp) })
        end
    end

    -- 2. les NOTES du schéma (texte libre, centré sur son point d'origine, déplacé si besoin)
    for _, n in ipairs(notes) do
        local w = 130 + 20 * K
        local lines = math.ceil(measure(n.text, FS) * 1.3 / w) + 0
        if lines < 1 then lines = 1 end
        local h = (lines + 0) * (FS + 2) + 6
        local cands = {}
        for k = 0, 5 do
            local dy = k * (h * 0.7 + 4)
            table.insert(cands, { n.px - w / 2, n.py - h / 2 - dy })
            table.insert(cands, { n.px - w / 2, n.py - h / 2 + dy })
            table.insert(cands, { n.px - w / 2 - k * w * 0.5, n.py - h / 2 })
            table.insert(cands, { n.px - w / 2 + k * w * 0.5, n.py - h / 2 })
        end
        local x, y = Place(w, h, cands)
        table.insert(L.notes, { x = x, y = y, w = w, h = h, text = n.text, fs = FS - 1, id = n.id })
    end

    -- 3. les labels des icônes (dessous de préférence)
    for _, ic in ipairs(icolabels) do
        local w = measure(ic.text, FS) + 4
        local h = FS + 2
        local cx = ic.ix + ic.size / 2
        local cands = {
            { cx - w / 2, ic.iy + ic.size + 1 }, { cx - w / 2, ic.iy - h - 1 },
            { ic.ix + ic.size + 2, ic.iy + (ic.size - h) / 2 }, { ic.ix - w - 2, ic.iy + (ic.size - h) / 2 },
            { cx - w / 2, ic.iy + ic.size + h + 2 }, { cx - w / 2, ic.iy - 2 * h - 2 },
        }
        local x, y = Place(w, h, cands)
        table.insert(L.texts, { x = x, y = y, w = w, h = h, text = ic.text, fs = FS, col = ic.col })
    end

    -- 4. les labels des zones (au-dessus de l'ellipse de préférence)
    for _, zl in ipairs(zlabels) do
        local w = measure(zl.text, FS) + 4
        local h = FS + 2
        local cands = {
            { zl.cx - w / 2, zl.cy - zl.ry - h - 2 }, { zl.cx - w / 2, zl.cy + zl.ry + 2 },
            { zl.cx + zl.rx + 2, zl.cy - h / 2 }, { zl.cx - zl.rx - w - 2, zl.cy - h / 2 },
            { zl.cx - w / 2, zl.cy - h / 2 },
        }
        local x, y = Place(w, h, cands)
        table.insert(L.texts, { x = x, y = y, w = w, h = h, text = zl.text, fs = FS, col = { 0.98, 0.93, 0.80 } })
    end
    return L
end
V.Layout = Layout
V.ShortCode = ShortCode

-- ============================================================
-- Rendu sur un canevas (pools : on ne détruit jamais un widget en 1.12)
-- ============================================================

local measureFS = nil

local function Measure(text, size)
    if not measureFS then
        measureFS = UIParent:CreateFontString(nil, "OVERLAY")
        measureFS:Hide()
    end
    measureFS:SetFont(FONT, size, "OUTLINE")
    measureFS:SetText(text or "")
    local w = measureFS:GetStringWidth()
    if type(w) ~= "number" or w <= 0 then w = string.len(text or "") * size * 0.55 end
    return w
end

-- Les widgets sont mis en reserve PAR CANEVAS (la fenetre agrandie et le petit schema de la page Guilde ont chacun la leur).
local function Pool(canvas)
    local P = canvas.rtvp
    if not P then
        P = { tex = {}, ntex = {}, fs = {}, nfs = 0, btn = {}, nbtn = 0 }
        canvas.rtvp = P
    end
    return P
end

local function Tex(canvas, layer)
    local P = Pool(canvas)
    local pl = P.tex[layer]
    if not pl then pl = {}; P.tex[layer] = pl; P.ntex[layer] = 0 end
    P.ntex[layer] = P.ntex[layer] + 1
    local t = pl[P.ntex[layer]]
    if not t then
        t = canvas:CreateTexture(nil, layer)
        pl[P.ntex[layer]] = t
    end
    t:Show()
    t:ClearAllPoints()
    t:SetTexCoord(0, 1, 0, 1)
    t:SetVertexColor(1, 1, 1, 1)
    return t
end

local function Font(canvas, size, flags)
    local P = Pool(canvas)
    P.nfs = P.nfs + 1
    local f = P.fs[P.nfs]
    if not f then
        f = canvas:CreateFontString(nil, "OVERLAY")
        P.fs[P.nfs] = f
    end
    f:SetFont(FONT, size, flags or "OUTLINE")
    f:SetWidth(0)
    f:SetJustifyH("LEFT")
    f:Show()
    f:ClearAllPoints()
    return f
end

local function Btn(canvas)
    local P = Pool(canvas)
    P.nbtn = P.nbtn + 1
    local b = P.btn[P.nbtn]
    if not b then
        b = CreateFrame("Button", nil, canvas)
        b:EnableMouse(true)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints(b)
        b.bg:SetTexture(SQUARE)
        b.fs = b:CreateFontString(nil, "OVERLAY")
        b.fs:SetJustifyH("LEFT")
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        P.btn[P.nbtn] = b
    end
    b:Show()
    b:ClearAllPoints()
    return b
end

local function ResetPools(canvas)
    if V.HideHandles then V.HideHandles(canvas) end     -- poignees de retouche (RT_SchemaEdit.lua)
    local P = Pool(canvas)
    for layer, pl in pairs(P.tex) do
        for i = 1, table.getn(pl) do pl[i]:Hide() end
        P.ntex[layer] = 0
    end
    for i = 1, table.getn(P.fs) do P.fs[i]:Hide() end
    for i = 1, table.getn(P.btn) do P.btn[i]:Hide() end
    P.nfs, P.nbtn = 0, 0
end
local function DrawZone(canvas, z)
    local fr, fg, fb = 1.00, 0.28, 0.20
    if z.kind == "safe" then fr, fg, fb = 0.36, 0.95, 0.48 end
    local fill = Tex(canvas, "BORDER")
    fill:SetTexture(CIRCLE)
    fill:SetVertexColor(fr, fg, fb, (z.kind == "safe") and 0.24 or 0.28)
    fill:SetWidth(z.rx * 2)
    fill:SetHeight(z.ry * 2)
    fill:SetPoint("CENTER", canvas, "TOPLEFT", z.cx, -z.cy)
    local per = math.pi * (3 * (z.rx + z.ry) - math.sqrt((3 * z.rx + z.ry) * (z.rx + 3 * z.ry)))
    local n = math.floor(per / 7)
    if n < 24 then n = 24 end
    if n > 64 then n = 64 end
    for i = 0, n - 1 do
        local a = i * 2 * math.pi / n
        local t = Tex(canvas, "BORDER")
        t:SetTexture(SQUARE)
        t:SetVertexColor(fr, fg, fb, 0.95)
        t:SetWidth(4)
        t:SetHeight(4)
        t:SetPoint("CENTER", canvas, "TOPLEFT", z.cx + z.rx * math.cos(a), -(z.cy + z.ry * math.sin(a)))
    end
    if z.kind == "mark" then
        for _, sign in ipairs({ 1, -1 }) do
            for s = -0.55, 0.55, 0.11 do
                local t = Tex(canvas, "BORDER")
                t:SetTexture(SQUARE)
                t:SetVertexColor(1, 0.25, 0.19, 0.95)
                t:SetWidth(3)
                t:SetHeight(3)
                t:SetPoint("CENTER", canvas, "TOPLEFT", z.cx + s * z.rx, -(z.cy + sign * s * z.ry))
            end
        end
    end
end

local function DrawArrow(canvas, a, K)
    local dx, dy = a.x2 - a.x1, a.y2 - a.y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 10 then return end
    local ux, uy = dx / len, dy / len
    local steps = math.floor(len / 8)
    if steps > 70 then steps = 70 end
    if steps < 2 then steps = 2 end
    local th = 4.5
    for i = 0, steps do
        local t = Tex(canvas, "BORDER")
        t:SetTexture(SQUARE)
        t:SetVertexColor(0.97, 0.93, 0.85, 0.95)
        t:SetWidth(th)
        t:SetHeight(th)
        t:SetPoint("CENTER", canvas, "TOPLEFT", a.x1 + dx * (i / steps), -(a.y1 + dy * (i / steps)))
    end
    local head = 8 + 3 * K
    if head > 18 then head = 18 end
    for _, side in ipairs({ 1, -1 }) do
        local ang = math.atan2(-uy, ux) + side * (28 * math.pi / 180)
        for j = 1, 3 do
            local t = Tex(canvas, "BORDER")
            t:SetTexture(SQUARE)
            t:SetVertexColor(0.98, 0.80, 0.27, 1)
            t:SetWidth(5)
            t:SetHeight(5)
            t:SetPoint("CENTER", canvas, "TOPLEFT",
                a.x2 - math.cos(ang) * head * (j / 3), -(a.y2 + math.sin(ang) * head * (j / 3)))
        end
    end
    local tip = Tex(canvas, "BORDER")
    tip:SetTexture(SQUARE)
    tip:SetVertexColor(0.98, 0.80, 0.27, 1)
    tip:SetWidth(7)
    tip:SetHeight(7)
    tip:SetPoint("CENTER", canvas, "TOPLEFT", a.x2, -a.y2)
end

-- Dessine une mise en page. assignInfo[poste] = { player, task } pour les infobulles / clics.
local function Render(canvas, L, assign)
    ResetPools(canvas)
    for _, z in ipairs(L.zones) do DrawZone(canvas, z) end
    for _, a in ipairs(L.arrows) do DrawArrow(canvas, a, L.K or 1) end
    for _, ic in ipairs(L.icons) do
        local t = Tex(canvas, "ARTWORK")
        t:SetTexture(ic.tex)
        if ic.col then t:SetVertexColor(ic.col[1], ic.col[2], ic.col[3], ic.col[4] or 1) end
        t:SetWidth(ic.size)
        t:SetHeight(ic.size)
        t:SetPoint("TOPLEFT", canvas, "TOPLEFT", ic.x, -ic.y)
    end
    for _, tx in ipairs(L.texts) do
        local f = Font(canvas, tx.fs)
        f:SetText(tx.text)
        f:SetTextColor(tx.col[1], tx.col[2], tx.col[3])
        f:SetPoint("TOPLEFT", canvas, "TOPLEFT", tx.x + 2, -tx.y)
    end
    for _, n in ipairs(L.notes) do
        local f = Font(canvas, n.fs)
        f:SetWidth(n.w)
        f:SetJustifyH("CENTER")
        f:SetText(n.text)
        f:SetTextColor(0.98, 0.88, 0.58)
        f:SetPoint("TOPLEFT", canvas, "TOPLEFT", n.x, -n.y)
    end
    for _, tk in ipairs(L.tokens) do
        local col = ROLE_COLOR[tk.role] or ROLE_COLOR.tank
        local halo = Tex(canvas, "ARTWORK")
        halo:SetTexture(CIRCLE)
        halo:SetVertexColor(0, 0, 0, 0.9)
        halo:SetWidth(tk.r * 2 + 5)
        halo:SetHeight(tk.r * 2 + 5)
        halo:SetPoint("CENTER", canvas, "TOPLEFT", tk.x, -tk.y)
        local disc = Tex(canvas, "ARTWORK")
        disc:SetTexture(CIRCLE)
        disc:SetVertexColor(col[1], col[2], col[3], 1)
        disc:SetWidth(tk.r * 2 - 1)
        disc:SetHeight(tk.r * 2 - 1)
        disc:SetPoint("CENTER", canvas, "TOPLEFT", tk.x, -tk.y)
        local g = Font(canvas, math.floor(L.FS * 0.85))
        g:SetJustifyH("CENTER")
        g:SetWidth(tk.r * 2 + 6)
        g:SetText(tk.code)
        g:SetTextColor(0.02, 0.02, 0.05)
        g:SetPoint("CENTER", canvas, "TOPLEFT", tk.x, -tk.y)
    end
    for _, lb in ipairs(L.labels) do
        local b = Btn(canvas)
        b:SetWidth(lb.w)
        b:SetHeight(lb.h)
        b:SetPoint("TOPLEFT", canvas, "TOPLEFT", lb.x, -lb.y)
        b.bg:SetVertexColor(0, 0, 0, 0.75)
        b.fs:SetFont(FONT, L.FS, "OUTLINE")
        b.fs:ClearAllPoints()
        b.fs:SetPoint("LEFT", b, "LEFT", 3, 0)
        b.fs:SetText(lb.text)
        local c
        if lb.free then c = { 0.62, 0.62, 0.66 }
        else c = ClassOf(FirstName(lb.who)) or ROLE_COLOR[lb.role] or { 1, 1, 1 } end
        b.fs:SetTextColor(c[1], c[2], c[3])
        -- Lua 5.0 : la variable de boucle (lb) n'existe plus quand la fonction est appelee plus tard (nil) -> on copie ce qu'il faut
        local target = FirstName(lb.who)
        local poste = lb.poste
        local who = lb.who or ""
        local slot = assign and assign[poste]
        b:SetScript("OnClick", function()
            if target and target ~= "" then
                if arg1 == "RightButton" then
                    if ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. target .. " ") end
                elseif TargetByName then
                    TargetByName(target)
                end
            end
        end)
        b:SetScript("OnEnter", function()
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            local tt = poste .. ((who ~= "") and (" : " .. who) or " (libre)")
            if slot and slot.task and slot.task ~= "" then tt = tt .. "\n|cffcccccc" .. slot.task .. "|r" end
            if target and target ~= "" then tt = tt .. "\n|cff888888Clic : cibler · Clic droit : chuchoter|r" end
            GameTooltip:SetText(tt, 1, 0.9, 0.6)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    if canvas.rtvEdit and V.EditHandles then V.EditHandles(canvas, L) end
end
V.Render = Render

-- Petit schema (page Guilde, 320x180) : version simplifiee dessinee sur le canevas fourni
function V.DrawSmall(canvas, pd, assign, CW, CH, key)
    if key and pd and V.ApplyMods then pd = V.ApplyMods(key, pd) end     -- tes retouches (RT_SchemaEdit.lua)
    local L = Layout(Simplify(pd), assign, CW, CH, Measure, true)
    Render(canvas, L, assign)
end

-- ============================================================
-- La fenêtre
-- ============================================================

local sel = { raid = nil, boss = nil, phase = "p1" }
local ui = {}
local frame = nil

local NAVW, RIGHTW, PAD, HEADH, BOTH = 150, 262, 8, 36, 124

local function Dims()
    local uw, uh = UIParent:GetWidth(), UIParent:GetHeight()
    if type(uw) ~= "number" or uw < 600 or type(uh) ~= "number" or uh < 400 then uw, uh = 1280, 800 end
    local scale = 1
    local st = DB().settings
    if st and st.viewSmall then scale = 0.78 end
    local cw = (uw * 0.92 - NAVW - RIGHTW - PAD * 4) * scale
    local ch = cw * 9 / 16
    local maxH = uh * 0.94 * scale
    if HEADH + ch + BOTH + PAD * 3 > maxH then
        ch = maxH - HEADH - BOTH - PAD * 3
        cw = ch * 16 / 9
    end
    if cw > 980 then cw = 980; ch = cw * 9 / 16 end
    if cw < 360 then cw = 360; ch = cw * 9 / 16 end
    cw, ch = math.floor(cw), math.floor(ch)
    return NAVW + cw + RIGHTW + PAD * 4, HEADH + ch + BOTH + PAD * 3, cw, ch
end

local function BossData()
    local S = Schemas()
    local R = sel.raid and S[sel.raid]
    local B = R and sel.boss and R.bosses and R.bosses[sel.boss]
    local plan = Plan()
    local name = B and B.name or nil
    if not name and plan and plan.raid == sel.raid then name = sel.boss end
    local phKey = nil
    if B and B.phases then
        if B.phases[sel.phase] then phKey = sel.phase
        else
            for i = 1, 3 do
                if B.phases["p" .. i] then phKey = "p" .. i; break end
            end
            if not phKey then
                for k in pairs(B.phases) do phKey = k; break end
            end
        end
    end
    local pd = phKey and B.phases[phKey] or nil
    local assign = plan and plan.assign and name and plan.assign[name] or nil
    return R, B, name, phKey, pd, assign
end

local function KillsOf(raidSlug)
    local k = DB().octofanKills
    return k and k[raidSlug] or nil
end

local function BgOn()
    local st = DB().settings
    return not (st and st.schemaBg == false)
end

local function SelectBoss(raid, boss)
    if raid ~= sel.raid or boss ~= sel.boss then sel.phase = "p1" end
    sel.raid, sel.boss = raid, boss
    if V.Refresh then V.Refresh(true) end
end

local function Step(dir)
    local nav = NavList()
    for i = 1, table.getn(nav) do
        if nav[i].slug == sel.raid then
            local bs = nav[i].bosses
            local n = table.getn(bs)
            if n == 0 then return end
            local idx = 1
            for j = 1, n do
                if bs[j].slug == sel.boss then idx = j; break end
            end
            idx = math.mod(idx - 1 + dir + n, n) + 1
            SelectBoss(sel.raid, bs[idx].slug)
            return
        end
    end
end

local linkBox = nil
local function ShowLink(url)
    if not linkBox then
        local f = CreateFrame("Frame", "RTV_LinkBox", UIParent)
        f:SetWidth(440)
        f:SetHeight(78)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        RT.UI.ApplyBackdrop(f, 0.03, 0.03, 0.06, 0.97)
        local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
        t:SetText("Lien du schéma : Ctrl+C pour copier, puis colle-le dans ton navigateur")
        local eb = CreateFrame("EditBox", "RTV_LinkEdit", f)
        eb:SetWidth(414)
        eb:SetHeight(22)
        eb:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)
        eb:SetFontObject(ChatFontNormal)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(300)
        eb:SetBackdrop({ bgFile = SQUARE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        eb:SetBackdropColor(0, 0, 0, 0.9)
        eb:SetTextInsets(6, 6, 0, 0)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        eb:SetScript("OnEnterPressed", function() f:Hide() end)
        eb:SetScript("OnTextChanged", function()
            if f.url and this:GetText() ~= f.url then
                this:SetText(f.url)
                this:HighlightText()
            end
        end)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
        f.edit = eb
        f:Hide()
        linkBox = f
    end
    linkBox.url = url
    linkBox:Show()
    linkBox.edit:SetText(url)
    linkBox.edit:SetFocus()
    linkBox.edit:HighlightText()
end

local function Build()
    if frame then return end
    local W, H, CW, CH = Dims()
    ui.CW, ui.CH = CW, CH
    frame = CreateFrame("Frame", "RTV_Window", UIParent)
    frame:SetWidth(W)
    frame:SetHeight(H)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("FULLSCREEN")      -- au-dessus de la fenêtre RaidTools complète (DIALOG) quand on l'ouvre depuis elle
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    RT.UI.ApplyBackdrop(frame, 0.03, 0.03, 0.06, 0.97)
    table.insert(UISpecialFrames, "RTV_Window")

    ui.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ui.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -10)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

    -- barre d'outils (à droite du titre)
    local function Tool(text, w, x, tip, fn)
        local b = RT.UI.Button(frame, { text = text, width = w, height = 20, anchor = { "TOPRIGHT", frame, "TOPRIGHT", -x, -8 }, tooltip = tip })
        b:SetScript("OnClick", fn)
        return b
    end
    local x = 34
    ui.linkB = Tool("Lien", 44, x, "Adresse de ce schéma sur le site (Ctrl+C pour copier).", function()
        local url = SITE_URL
        if sel.boss and HasImg(sel.boss) then url = SITE_URL .. "?boss=" .. sel.boss end
        ShowLink(url)
    end)
    x = x + 48
    ui.bgB = Tool("Fond", 44, x, "Affiche ou masque l'image de fond du schéma.", function()
        local db = DB()
        db.settings = db.settings or {}
        db.settings.schemaBg = not BgOn()
        V.Refresh(true)
    end)
    x = x + 48
    ui.editB = Tool("Éditer", 52, x, "Retouche le schéma à ta façon : déplacer, supprimer, ajouter des marques (rien n'est envoyé au site).", function()
        if V.ToggleEdit then V.ToggleEdit() end
    end)
    x = x + 56
    ui.sizeB = Tool("Taille", 48, x, "Alterne grande fenêtre / fenêtre compacte (rouvre la fenêtre).", function()
        local db = DB()
        db.settings = db.settings or {}
        db.settings.viewSmall = not db.settings.viewSmall
        V.Rebuild()
    end)
    x = x + 56
    ui.nextB = Tool(">", 24, x, "Boss suivant.", function() Step(1) end)
    x = x + 26
    ui.prevB = Tool("<", 24, x, "Boss précédent.", function() Step(-1) end)
    x = x + 34
    ui.phB = {}
    for i = 3, 1, -1 do
        local phaseKey = "p" .. i   -- copie locale : la variable de boucle ne survit pas en Lua 5.0
        local b = Tool("P" .. i, 28, x, "Phase " .. i .. " du schéma.", function() sel.phase = phaseKey; V.Refresh(true) end)
        b:Hide()
        ui.phB[i] = b
        x = x + 30
    end

    -- navigation
    local nav = CreateFrame("Frame", nil, frame)
    nav:SetWidth(NAVW)
    nav:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -HEADH - PAD)
    nav:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD)
    RT.UI.ApplyBackdrop(nav, 0.02, 0.02, 0.05, 0.85)
    ui.navRows = {}
    for i = 1, 40 do
        local b = CreateFrame("Button", nil, nav)
        b:SetHeight(17)
        b:SetPoint("TOPLEFT", nav, "TOPLEFT", 7, -(7 + (i - 1) * 17))
        b:SetPoint("RIGHT", nav, "RIGHT", -7, 0)
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("LEFT", b, "LEFT", 2, 0)
        t:SetJustifyH("LEFT")
        b:SetFontString(t)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        b:GetHighlightTexture():SetAlpha(0.3)
        b:Hide()
        ui.navRows[i] = b
    end

    -- schéma
    local canvas = CreateFrame("Frame", nil, frame)
    canvas:SetWidth(CW)
    canvas:SetHeight(CH)
    canvas:SetPoint("TOPLEFT", frame, "TOPLEFT", NAVW + PAD * 2, -HEADH - PAD)
    canvas:SetBackdrop({ bgFile = SQUARE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    canvas:SetBackdropColor(0.05, 0.06, 0.09, 1)
    canvas:SetBackdropBorderColor(0.45, 0.38, 0.22, 1)
    ui.canvas = canvas
    local bg = canvas:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", canvas, "TOPLEFT", 3, -3)
    bg:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -3, 3)
    bg:Hide()
    ui.bg = bg
    ui.empty = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ui.empty:SetPoint("CENTER", canvas, "CENTER", 0, 0)
    ui.empty:SetWidth(CW - 60)
    ui.empty:SetText("")

    -- préparation / stratégie / trash
    local det = RT.UI.TextScroll(frame, {
        name = "RTV_Details",
        anchor = { "TOPLEFT", canvas, "BOTTOMLEFT", 0, -PAD },
        width = CW,
    })
    det.scroll:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -22, -(PAD + BOTH))
    ui.details = det

    -- colonne droite : mon rôle + assignations
    local right = CreateFrame("Frame", nil, frame)
    right:SetPoint("TOPLEFT", canvas, "TOPRIGHT", PAD, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)
    RT.UI.ApplyBackdrop(right, 0.02, 0.02, 0.05, 0.85)
    ui.right = right
    local mh = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mh:SetPoint("TOPLEFT", right, "TOPLEFT", 10, -8)
    mh:SetText("|cffFFCC44Mon rôle|r")
    ui.myRole = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ui.myRole:SetPoint("TOPLEFT", right, "TOPLEFT", 10, -26)
    ui.myRole:SetWidth(RIGHTW - 22)
    ui.myRole:SetJustifyH("LEFT")
    -- « Assignations » se place sous « Mon rôle », quelle que soit sa hauteur (plusieurs postes, tâches longues)
    local ah = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ah:SetPoint("TOPLEFT", ui.myRole, "BOTTOMLEFT", 0, -12)
    ah:SetText("|cffFFCC44Assignations|r")
    local holder = CreateFrame("Frame", nil, right)
    holder:SetPoint("TOPLEFT", ah, "BOTTOMLEFT", -2, -4)
    holder:SetPoint("RIGHT", right, "RIGHT", -8, 0)
    holder:SetHeight(20)
    ui.maxRows = math.floor((H - HEADH - PAD * 3 - 110) / 27)
    if ui.maxRows > 16 then ui.maxRows = 16 end
    if ui.maxRows < 6 then ui.maxRows = 6 end
    ui.rows = {}
    for i = 1, 16 do
        local r = CreateFrame("Button", nil, holder)
        r:SetHeight(27)
        r:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -((i - 1) * 27))
        r:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        r:GetHighlightTexture():SetAlpha(0.25)
        r.l1 = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.l1:SetPoint("TOPLEFT", r, "TOPLEFT", 2, -1)
        r.l1:SetJustifyH("LEFT")
        r.l2 = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.l2:SetPoint("TOPLEFT", r, "TOPLEFT", 2, -14)
        r.l2:SetJustifyH("LEFT")
        r.l2:SetTextColor(0.62, 0.62, 0.66)
        r:Hide()
        ui.rows[i] = r
    end
    frame:Hide()
end

local function Fill(force)
    local nav = NavList()
    local S = Schemas()
    local plan = Plan()
    if not sel.raid then
        local first = nav[1]
        if first then sel.raid = first.slug; sel.boss = first.bosses[1] and first.bosses[1].slug or nil end
    end
    if sel.raid and not sel.boss then
        for i = 1, table.getn(nav) do
            if nav[i].slug == sel.raid and nav[i].bosses[1] then sel.boss = nav[i].bosses[1].slug end
        end
    end
    -- navigation
    local row = 1
    for _, R in ipairs(nav) do
        local b = ui.navRows[row]
        if not b then break end
        b:SetText("|cffFFCC44" .. (R.name or R.slug) .. "|r")
        b.rRaid, b.rBoss = R.slug, nil
        b:SetScript("OnClick", function() SelectBoss(this.rRaid, nil) end)
        b:Show()
        row = row + 1
        if R.slug == sel.raid then
            local kd = KillsOf(R.slug)
            for _, B in ipairs(R.bosses) do
                local bb = ui.navRows[row]
                if not bb then break end
                local mark = (B.slug == sel.boss) and "|cffFFCC44> " or "   "
                local done = (kd and kd[B.slug]) and "|cff44FF44OK|r " or ""
                bb:SetText(done .. mark .. (B.name or B.slug))
                bb.rRaid, bb.rBoss = R.slug, B.slug
                bb:SetScript("OnClick", function() SelectBoss(this.rRaid, this.rBoss) end)
                bb:Show()
                row = row + 1
            end
        end
    end
    for j = row, 40 do ui.navRows[j]:Hide() end

    local R, B, bossName, phKey, pd, assign = BossData()
    local modKey = (sel.raid and sel.boss and phKey) and (sel.raid .. "/" .. sel.boss .. "/" .. phKey) or nil
    V.curKey = modKey
    if pd and V.ApplyMods then pd = V.ApplyMods(modKey, pd) end     -- tes retouches (RT_SchemaEdit.lua)
    V.curPD = pd
    ui.title:SetText("|cffFFD700" .. (bossName or "Raid") .. "|r" .. ((R and R.name) and ("  |cff999999" .. R.name .. "|r") or ""))

    -- phases
    local nph = 0
    local has = {}
    for i = 1, 3 do
        local p = B and B.phases and B.phases["p" .. i] or nil
        if p and (table.getn(p.zones or {}) + table.getn(p.arrows or {}) + table.getn(p.syms or {}) + table.getn(p.tips or {})) > 0 then
            has[i] = true
            nph = nph + 1
        end
    end
    for i = 1, 3 do
        local pb = ui.phB[i]
        if has[i] and nph > 1 then pb:Show() else pb:Hide() end
        local fs = pb:GetFontString()
        if fs then
            if phKey == "p" .. i then fs:SetTextColor(1, 0.82, 0.27) else fs:SetTextColor(1, 1, 1) end
        end
    end

    -- schéma : redessiné seulement si quelque chose a changé
    local sig = tostring(sel.raid) .. "|" .. tostring(sel.boss) .. "|" .. tostring(phKey) .. "|" .. (BgOn() and "1" or "0") .. "|" .. ui.CW
    if assign then
        local keys = {}
        for poste, slot in pairs(assign) do table.insert(keys, poste .. "=" .. (slot.player or "")) end
        table.sort(keys)
        sig = sig .. "|" .. table.concat(keys, ",")
    end
    sig = sig .. "|" .. tostring(DB().octofanSchemasRaw and string.len(DB().octofanSchemasRaw) or 0)
    if V.SigPart then sig = sig .. "|" .. V.SigPart(modKey) end
    if force or sig ~= ui.sig then
        ui.sig = sig
        if pd then
            local L = Layout(pd, assign, ui.CW, ui.CH, Measure)
            Render(ui.canvas, L, assign)
            ui.empty:SetText("")
        else
            ResetPools(ui.canvas)
            ui.empty:SetText("|cff888888Pas de schéma pour ce boss.\nLe chef de raid peut l'envoyer avec son plan.|r")
        end
        if pd and sel.boss and HasImg(sel.boss) and BgOn() then
            ui.bg:SetTexture("Interface\\AddOns\\" .. (RT_ADDON_DIR or "rt") .. "\\img\\" .. sel.boss)
            ui.bg:SetVertexColor(0.5, 0.5, 0.5, 1)
            ui.bg:Show()
        else
            ui.bg:Hide()
        end
    end

    -- mon rôle
    local me = UnitName("player")
    local mine = {}
    if assign then
        for poste, slot in pairs(assign) do
            if IsMe(slot.player, me) then
                local line = "|cff66CCFF" .. poste .. "|r"
                if slot.task and slot.task ~= "" then line = line .. "\n|cffdddddd" .. slot.task .. "|r" end
                table.insert(mine, line)
            end
        end
    end
    table.sort(mine)
    if table.getn(mine) == 0 then
        ui.myRole:SetText(plan and "|cff888888Rien pour toi sur ce boss.|r" or "|cff888888Pas de plan reçu pour l'instant.|r")
    else
        ui.myRole:SetText(table.concat(mine, "\n"))
    end

    -- assignations
    local list = {}
    if assign then
        for poste, slot in pairs(assign) do table.insert(list, { poste = poste, slot = slot }) end
    end
    local order = { Tank = 1, Heal = 2, CaC = 3, Dist = 4 }
    table.sort(list, function(a, b)
        local _, _, la = string.find(a.poste, "^(%a+)")
        local _, _, lb = string.find(b.poste, "^(%a+)")
        local oa, ob = order[la or ""] or 9, order[lb or ""] or 9
        if oa ~= ob then return oa < ob end
        return a.poste < b.poste
    end)
    local maxRows = ui.maxRows or 16
    for i = 1, 16 do
        local r = ui.rows[i]
        local e = list[i]
        if i > maxRows then
            r:Hide()
        elseif i == maxRows and table.getn(list) > maxRows then
            -- plus de postes que de lignes : la dernière ligne annonce le reste (tout est dans l'infobulle du schéma)
            r.l1:SetText("|cff888888+ " .. (table.getn(list) - maxRows + 1) .. " autres postes (voir le schéma)|r")
            r.l2:SetText("")
            r:SetScript("OnClick", nil)
            r:SetScript("OnEnter", nil)
            r:SetScript("OnLeave", nil)
            r:Show()
        elseif e then
            local who = e.slot.player or ""
            local _, _, kind = string.find(e.poste, "^(%a+)")
            local rc = ROLE_COLOR[(kind == "Tank" and "tank") or (kind == "Heal" and "heal") or (kind == "CaC" and "melee") or "ranged"]
            local cc = ClassOf(FirstName(who)) or { 1, 1, 1 }
            r.l1:SetText(Hex(rc) .. e.poste .. "|r  " .. Hex(cc) .. (who ~= "" and who or "—") .. "|r")
            r.l2:SetText(Trunc(e.slot.task or "", 46))
            local target = FirstName(who)
            r:SetScript("OnClick", function()
                if target and target ~= "" then
                    if arg1 == "RightButton" then
                        if ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. target .. " ") end
                    elseif TargetByName then
                        TargetByName(target)
                    end
                end
            end)
            r:SetScript("OnEnter", function()
                GameTooltip:SetOwner(r, "ANCHOR_LEFT")
                GameTooltip:SetText(e.poste .. " : " .. (who ~= "" and who or "libre") ..
                    ((e.slot.task and e.slot.task ~= "") and ("\n|cffcccccc" .. e.slot.task .. "|r") or ""), 1, 0.9, 0.6)
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            r:Show()
        else
            r:Hide()
        end
    end

    -- détails : préparation, stratégie, trash
    local T = {}
    if pd and table.getn(pd.tips or {}) > 0 then
        table.insert(T, "|cff88FF88Préparation :|r")
        for _, t in ipairs(pd.tips) do table.insert(T, "  - " .. t) end
        table.insert(T, "")
    end
    local strat = plan and plan.strats and bossName and plan.strats[bossName]
    if strat and strat ~= "" then
        table.insert(T, "|cffFFCC44Stratégie :|r")
        for line in string.gfind(strat .. "\n", "([^\n]*)\n") do
            if line ~= "" then table.insert(T, "  |cffcccccc" .. line .. "|r") end
        end
        table.insert(T, "")
    end
    if plan and table.getn(plan.trash or {}) > 0 then
        table.insert(T, "|cffFFCC44Trash :|r")
        for _, pk in ipairs(plan.trash) do
            local marks = {}
            for _, m in ipairs(pk.marks or {}) do
                table.insert(marks, (m.mob or "?") .. ((m.tank and m.tank ~= "") and ("->" .. m.tank) or ""))
            end
            if table.getn(marks) > 0 then table.insert(T, "  " .. (pk.name or "Pack") .. " : " .. table.concat(marks, ", ")) end
        end
    end
    if table.getn(T) == 0 then table.insert(T, "|cff888888Pas de stratégie pour ce boss.|r") end
    local txt = table.concat(T, "\n")
    if txt ~= ui.detText then
        ui.detText = txt
        ui.details:SetText(txt)
    end
end

function V.Refresh(force)
    if not frame or not frame:IsShown() then return end
    local ok, err = pcall(Fill, force)
    if not ok then RT.Print("|cffff6060Raid|r : erreur d'affichage : " .. tostring(err)) end
end

-- ouvre sur le boss ciblé si c'est un boss connu
local function PickTargetBoss()
    if not (UnitExists("target") and not UnitIsPlayer("target")) then return end
    local tgt = string.lower(UnitName("target") or "")
    if tgt == "" or tgt == "unknown entity" then return end
    local nav = NavList()
    for i = 1, table.getn(nav) do
        for _, B in ipairs(nav[i].bosses) do
            local bn = string.lower(B.name or "")
            if bn ~= "" and (string.find(bn, tgt, 1, true) or string.find(tgt, bn, 1, true)) then
                if sel.boss ~= B.slug then sel.phase = "p1" end
                sel.raid, sel.boss = nav[i].slug, B.slug
                return
            end
        end
    end
end

function V.Open(raidSlug, bossSlug)
    Build()
    if raidSlug then
        sel.raid = raidSlug
        sel.boss = bossSlug
    else
        PickTargetBoss()
    end
    frame:Show()
    ui.sig = nil
    V.Refresh(true)
end

function V.Toggle()
    if frame and frame:IsShown() then frame:Hide() else V.Open() end
end

function V.Rebuild()
    local was = frame and frame:IsShown()
    if frame then
        frame:Hide()
        -- les widgets ne peuvent pas être détruits en 1.12 : on les retaille et on les replace
        local W, H, CW, CH = Dims()
        ui.CW, ui.CH = CW, CH
        ui.maxRows = math.floor((H - HEADH - PAD * 3 - 110) / 27)
        if ui.maxRows > 16 then ui.maxRows = 16 end
        if ui.maxRows < 6 then ui.maxRows = 6 end
        frame:SetWidth(W)
        frame:SetHeight(H)
        ui.canvas:SetWidth(CW)
        ui.canvas:SetHeight(CH)
        ui.empty:SetWidth(CW - 60)
        ui.details.scroll:SetPoint("BOTTOMRIGHT", ui.canvas, "BOTTOMRIGHT", -22, -(PAD + BOTH))
        ui.details.child:SetWidth(CW - 22)
        ui.details.fs:SetWidth(CW - 46)
        ui.sig = nil
    end
    if was then V.Open(sel.raid, sel.boss) end
end

-- l'état bouge sans clic (plan reçu, assignation changée) : on suit
if RT and RT.Store and RT.Store.Subscribe then
    RT.Store.Subscribe("octofan", function() V.Refresh(false) end)
end
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
    if not frame or not frame:IsShown() then return end
    this.t = (this.t or 0) + arg1
    if this.t < 2 then return end
    this.t = 0
    V.Refresh(false)
end)

-- Version MEMBRE seulement : suivi des boss tombés (✓ dans la navigation, avance au boss suivant).
-- Le RaidTools complet le fait déjà dans sa page Guilde (même clé db.octofanKills) : on ne double pas.
if RT.isMember then
    local DEATH_PAT = {
        "^(.-) dies%.", "^(.-) meurt%.", "^You have slain (.-)!", "^(.-) is slain by ",
        "^Vous avez tu%S* (.-) ?!", "^(.-) est tu%S* par ",
    }
    local KILL_FRESH = 8 * 3600
    local downParts = {}
    local kf = CreateFrame("Frame")
    kf:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
    kf:SetScript("OnEvent", function()
        if not arg1 then return end
        local name = nil
        for i = 1, table.getn(DEATH_PAT) do
            local _, _, n = string.find(arg1, DEATH_PAT[i])
            if n then
                n = string.gsub(n, "^%s*(.-)%s*$", "%1")
                if n ~= "" then name = n; break end
            end
        end
        if not name then return end
        local low = string.lower(name)
        local nav = NavList()
        for i = 1, table.getn(nav) do
            for _, B in ipairs(nav[i].bosses) do
                local full = string.lower(B.name or "")
                local match, needed = false, 1
                if full == low then
                    match = true
                elseif string.find(full, " & ", 1, true) then
                    -- rencontre à deux PNJ ("A & B") : le kill compte quand les deux sont tombés
                    local n2 = 0
                    for piece in string.gfind(full, "[^&]+") do
                        local part = string.gsub(piece, "^%s*(.-)%s*$", "%1")
                        if part ~= "" then
                            n2 = n2 + 1
                            if part == low then match = true end
                        end
                    end
                    needed = n2
                end
                if match then
                    local key = nav[i].slug .. "/" .. B.slug
                    downParts[key] = downParts[key] or {}
                    downParts[key][low] = GetTime()
                    local cnt = 0
                    for _, t in pairs(downParts[key]) do
                        if GetTime() - t < 120 then cnt = cnt + 1 end
                    end
                    if cnt >= needed then
                        local db = DB()
                        db.octofanKills = db.octofanKills or {}
                        local K = db.octofanKills
                        K[nav[i].slug] = K[nav[i].slug] or {}
                        local v = K[nav[i].slug][B.slug]
                        if not (type(v) == "number" and time() - v < KILL_FRESH) then
                            K[nav[i].slug][B.slug] = time()
                            RT.Print("|cff44FF44OK|r " .. (B.name or B.slug) .. " - boss tombé.")
                            if sel.raid == nav[i].slug and sel.boss == B.slug then
                                local bs = nav[i].bosses
                                local n3 = table.getn(bs)
                                local idx = 1
                                for j = 1, n3 do
                                    if bs[j].slug == B.slug then idx = j; break end
                                end
                                for step = 1, n3 - 1 do
                                    local cand = bs[math.mod(idx - 1 + step, n3) + 1]
                                    local cv = K[nav[i].slug][cand.slug]
                                    if not (type(cv) == "number" and time() - cv < KILL_FRESH) then
                                        sel.boss = cand.slug
                                        sel.phase = "p1"
                                        break
                                    end
                                end
                            end
                            V.Refresh(true)
                        end
                    end
                    return
                end
            end
        end
    end)
end

V.GetSel = function() return sel end
V.NavList = NavList
V._ui = ui
