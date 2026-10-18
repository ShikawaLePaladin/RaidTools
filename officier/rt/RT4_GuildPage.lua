-- ============================================================
-- RT v5 — RT4_GuildPage.lua
--
-- LA PAGE GUILDE (une seule page, comme le Raid Planner du site) :
--   - colonne gauche : navigation raids -> boss
--   - centre : SCHÉMA du boss (importé du site, lecture seule) +
--     assignations + strat FR + trash
--   - droite : MON RÔLE sur ce boss + état du raid
--   - barre d'actions : Annoncer / Envoyer au raid / Pull / Trash->AM
-- Panneau "Outils" : accès aux modules experts (groups, consumes...)
-- Schémas : fichier RT_OctoFanSchemas.lua (bouton "🗺️ Fichier schémas"
-- du site), format OS1/Z/A/B/C/M/T/R/P, coordonnées en % 0-100.
-- Lua 5.0 strict. Chargé après RT4_RaidRecap.lua.
-- ============================================================

local SCHEMA_ICON = {
    star = 1, circle = 2, diamond = 3, triangle = 4,
    moon = 5, square = 6, cross = 7, skull = 8,
}
local ROLE_COLOR = {
    tank  = { 0.45, 0.65, 1.00 },
    heal  = { 0.35, 0.90, 0.45 },
    melee = { 1.00, 0.55, 0.35 },
    ranged = { 0.75, 0.55, 1.00 },
}

-- ============================================================
-- État de sélection
-- ============================================================

local sel = { raidSlug = nil, bossSlug = nil, phase = "p1" }
local ui = {}          -- refs des widgets de la page
-- UN pool par TYPE (une texture n'est pas une fontstring) ; notePool = textes 'T' (largeur fixe 90)
local texPool, fontPool, notePool, btnPool = {}, {}, {}, {}
local texUsed, fontUsed, noteUsed, drawUsedB = 0, 0, 0, 0
local labelPos = {}    -- positions des labels posés (anti-collision)

local function GetSchemas()
    local db = RT.Store.DB()
    db.octofanSchemas = db.octofanSchemas or {}
    return db.octofanSchemas
end

local function GetPlan()
    local db = RT.Store.DB()
    return db.octofan
end

-- ============================================================
-- Parse du fichier schémas (au login)
-- ============================================================

local MAX_BLOCKS, MAX_ZONES, MAX_ARROWS, MAX_SYMS, MAX_TIPS = 64, 16, 16, 64, 16
local schemaVer = 0   -- invalide l'index des noms de boss (kill tracking)

-- pourcentage 0-100 (le test >= 0 rejette aussi NaN)
local function Pct(v, d)
    v = tonumber(v) or d
    if not (v >= 0) then v = 0 elseif v > 100 then v = 100 end
    return v
end

local function ParseSchemas(text)
    if not text or text == "" then return 0 end
    local blocks = 0
    -- MERGE (pas remplacement) : les schémas reçus en relay ou rechargés
    -- depuis le fichier s'ajoutent à ceux déjà connus, boss par boss.
    local S = RT.Store.DB().octofanSchemas
    if type(S) ~= "table" then S = {} end
    local rSlug, bSlug, ph = nil, nil, nil
    local count = 0
    text = string.gsub(text, "[\r\n]", ";")
    for line in string.gfind(text .. ";", "([^;]*);") do
        local parts = {}
        for v in string.gfind(line .. "|", "([^|]*)|") do
            table.insert(parts, v)
        end
        local tag = parts[1]
        if tag == "OS1" then
            -- entrée potentiellement non fiable (relay) : champs obligatoires
            if not parts[2] or parts[2] == "" or not parts[4] or parts[4] == "" then
                rSlug, bSlug, ph = nil, nil, nil
            else
            blocks = blocks + 1
            if blocks > MAX_BLOCKS then
                rSlug, bSlug, ph = nil, nil, nil
            else
            rSlug, bSlug, ph = parts[2], parts[4], parts[6]
            if not ph or ph == "" then ph = "p1" end
            local rName = (parts[3] and parts[3] ~= "") and parts[3] or rSlug
            local bName = (parts[5] and parts[5] ~= "") and parts[5] or bSlug
            local R = S[rSlug] or { name = rName, bosses = {} }
            R.name = rName
            local B = R.bosses[bSlug] or { name = bName, phases = {} }
            B.name = bName
            -- ordre de rencontre = ordre du fichier (NavList trie dessus)
            R.nb = R.nb or 0
            if not B.order then R.nb = R.nb + 1; B.order = R.nb end
            B.phases[ph] = { zones = {}, arrows = {}, syms = {}, tips = {} }
            R.bosses[bSlug] = B
            S[rSlug] = R
            end
            end
        elseif rSlug and tag == "Z" then
            local p = S[rSlug].bosses[bSlug].phases[ph]
            if table.getn(p.zones) < MAX_ZONES then
                table.insert(p.zones, { x = Pct(parts[2], 0), y = Pct(parts[3], 0),
                    rx = Pct(parts[4], 6), ry = Pct(parts[5], 9),
                    kind = parts[6] or "danger", label = parts[7] or "" })
                count = count + 1
            end
        elseif rSlug and tag == "A" then
            local p = S[rSlug].bosses[bSlug].phases[ph]
            if table.getn(p.arrows) < MAX_ARROWS then
                table.insert(p.arrows, { x1 = Pct(parts[2], 0), y1 = Pct(parts[3], 0),
                    x2 = Pct(parts[4], 0), y2 = Pct(parts[5], 0) })
                count = count + 1
            end
        elseif rSlug and (tag == "B" or tag == "C" or tag == "M" or tag == "T" or tag == "R") then
            local p = S[rSlug].bosses[bSlug].phases[ph]
            if table.getn(p.syms) < MAX_SYMS then
                local sym = { type = tag, x = Pct(parts[2], 0), y = Pct(parts[3], 0) }
                if tag == "C" then sym.count = parts[4] or "" ; sym.label = parts[5] or ""
                elseif tag == "M" then sym.symbol = parts[4] or "star" ; sym.label = parts[5] or ""
                elseif tag == "R" then sym.role = parts[4] or "tank" ; sym.poste = parts[5] or "" ; sym.label = parts[6] or ""
                else sym.label = parts[4] or "" end
                table.insert(p.syms, sym)
                count = count + 1
            end
        elseif rSlug and tag == "P" then
            local tips = S[rSlug].bosses[bSlug].phases[ph].tips
            if table.getn(tips) < MAX_TIPS then table.insert(tips, parts[2] or "") end
        elseif tag == "END" then
            rSlug, bSlug, ph = nil, nil, nil -- plus aucun enregistrement orphelin apres END
        end
    end
    local db = RT.Store.DB()
    db.octofanSchemas = S
    schemaVer = schemaVer + 1
    if count > 0 then
        db.octofanSchemasRaw = text -- pour la diffusion raid (Envoyer = plan + schémas)
    end
    return count
end

local bootSchemas = CreateFrame("Frame")
bootSchemas:RegisterEvent("PLAYER_LOGIN")
bootSchemas:SetScript("OnEvent", function()
    if RT_OCTOFAN_SCHEMAS and RT_OCTOFAN_SCHEMAS ~= "" then
        local n = ParseSchemas(RT_OCTOFAN_SCHEMAS)
        if n > 0 then
            RT.Print("|cffAA66FFRaidTools|r: " .. n .. " élément(s) de schéma chargé(s) depuis le site.")
        end
        RT_OCTOFAN_SCHEMAS = nil
    end
end)

-- ============================================================
-- Renderer de schéma (lecture seule)
-- ============================================================

local CW, CH = 320, 180 -- zone de dessin (ratio 16:9, comme le site)

-- Site du raid planner : lien partageable d'un schema (?boss=<slug>, gere par le site).
local SITE_URL = "https://octofan.vercel.app/raid/"
-- Boss dont une image de fond est livree dans rt\img\<slug>.blp (512x256, issue du site).
local SCHEMA_IMG = {
    lucifron = true, magmadar = true, garr = true, baron_geddon = true, incindis = true,
    golemagg = true, majordomo = true, ragnaros = true, shazzrah = true, sulfuron = true,
}

-- premier nom d'un poste multi-joueurs (cible / whisper)
local function FirstName(who)
    local _, _, f = string.find(who or "", "^%s*([^,]+)")
    if f then f = string.gsub(f, "%s+$", "") end
    return f
end

local function PoolTex(parent)
    texUsed = texUsed + 1
    local t = texPool[texUsed]
    if not t then
        t = parent:CreateTexture(nil, "ARTWORK")
        texPool[texUsed] = t
    end
    t:Show()
    t:ClearAllPoints()
    t:SetVertexColor(1, 1, 1, 1)   -- une icone ne doit pas heriter de la teinte d'une zone
    return t
end

local function PoolFont(parent)
    fontUsed = fontUsed + 1
    local f = fontPool[fontUsed]
    if not f then
        f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fontPool[fontUsed] = f
    end
    f:Show()
    f:ClearAllPoints()
    return f
end

local function PoolNote(parent)
    noteUsed = noteUsed + 1
    local f = notePool[noteUsed]
    if not f then
        f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f:SetWidth(90)
        notePool[noteUsed] = f
    end
    f:Show()
    f:ClearAllPoints()
    return f
end

-- Boutons cliquables (labels de rôles) : clic = cibler le joueur,
-- clic droit = whisper prérempli.
local function PoolBtn(parent)
    drawUsedB = drawUsedB + 1
    local b = btnPool[drawUsedB]
    if not b then
        b = CreateFrame("Button", nil, parent)
        b:EnableMouse(true)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        b:GetHighlightTexture():SetAlpha(0.25)
        btnPool[drawUsedB] = b
    end
    b:Show()
    b:ClearAllPoints()
    return b
end

-- Flèche façon site : ligne CONTINUE (points denses de 2.5px, écart 7px)
-- + tête en chevron au bout (le SVG du site, version 1.12 sans rotation).
local function DrawDashed(parent, x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 8 then return end
    local ux, uy = dx / len, dy / len -- direction
    local steps = math.floor(len / 7)
    if steps > 28 then steps = 28 end
    if steps < 2 then steps = 2 end
    for i = 0, steps do
        local fx = x1 + dx * (i / steps)
        local fy = y1 + dy * (i / steps)
        local tex = PoolTex(parent)
        if not tex then return end
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:SetVertexColor(0.94, 0.91, 0.85, 0.95)
        tex:SetWidth(2.5)
        tex:SetHeight(2.5)
        tex:SetPoint("CENTER", parent, "TOPLEFT", fx, -fy)
    end
    -- tête de flèche : chevron (2 points en arrière à ±28°)
    local backA = 28 * math.pi / 180
    for _, side in ipairs({ 1, -1 }) do
        local ang = math.atan2(-uy, ux) + side * backA
        local hx = x2 + math.cos(ang) * -9
        local hy = y2 - math.sin(ang) * -9
        local tex = PoolTex(parent)
        if not tex then return end
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:SetVertexColor(0.98, 0.80, 0.27, 1)
        tex:SetWidth(5)
        tex:SetHeight(5)
        tex:SetPoint("CENTER", parent, "TOPLEFT", hx, -hy)
    end
    local tip = PoolTex(parent)
    if not tip then return end
    tip:SetTexture("Interface\\Buttons\\WHITE8X8")
    tip:SetVertexColor(0.98, 0.80, 0.27, 1)
    tip:SetWidth(6.5)
    tip:SetHeight(6.5)
    tip:SetPoint("CENTER", parent, "TOPLEFT", x2, -y2)
end

-- Enregistre un label centre (cx, haut = ly) comme obstacle : les labels de roles (places ensuite) s'ecartent.
local function RegLabel(f, cx, ly)
    local w = f:GetStringWidth()
    if type(w) ~= "number" or w <= 0 then w = 40 end
    table.insert(labelPos, { cx - w / 2, ly, w })
end

-- Anneau d'ellipse (la bordure des zones du site) : 22 points sur le
-- pourtour + halo de remplissage derrière (UI-Minimap-Background).
local function DrawZone(canvas, z)
    local cx = z.x / 100 * CW
    local cy = z.y / 100 * CH
    local rx = math.max((z.rx or 6) * CW / 100, 7)
    local ry = math.max((z.ry or 9) * CH / 100, 7)
    local fr, fg, fb
    if z.kind == "safe" then
        fr, fg, fb = 0.36, 0.95, 0.48
    else
        fr, fg, fb = 1.00, 0.28, 0.20
    end
    -- remplissage (halo doux)
    local fill = PoolTex(canvas)
    if fill then
        fill:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        fill:SetVertexColor(fr, fg, fb, z.kind == "safe" and 0.22 or 0.26)
        fill:SetWidth(rx * 2)
        fill:SetHeight(ry * 2)
        fill:SetPoint("CENTER", canvas, "TOPLEFT", cx, -cy)
    end
    -- anneau : points sur le pourtour de l'ellipse
    for i = 0, 21 do
        local a = i * math.pi / 11
        local px = cx + rx * math.cos(a)
        local py = cy + ry * math.sin(a)
        local tex = PoolTex(canvas)
        if not tex then return end
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:SetVertexColor(fr, fg, fb, 0.9)
        tex:SetWidth(2)
        tex:SetHeight(2)
        tex:SetPoint("CENTER", canvas, "TOPLEFT", px, -py)
    end
    -- kind "mark" : croix au centre (comme le site)
    if z.kind == "mark" then
        local k = 0.55
        for _, sign in ipairs({ 1, -1 }) do
            for s = -k, k, 0.14 do
                local tex = PoolTex(canvas)
                if not tex then return end
                tex:SetTexture("Interface\\Buttons\\WHITE8X8")
                tex:SetVertexColor(1, 0.25, 0.19, 0.95)
                tex:SetWidth(2)
                tex:SetHeight(2)
                tex:SetPoint("CENTER", canvas, "TOPLEFT",
                    cx + s * rx, -(cy + sign * s * ry))
            end
        end
    end
    if z.label ~= "" then
        local f = PoolFont(canvas)
        if not f then return end
        f:SetText(z.label)
        f:SetTextColor(0.95, 0.9, 0.8)
        f:SetPoint("BOTTOM", canvas, "TOPLEFT", cx, -(cy - ry) + 3)
        RegLabel(f, cx, cy - ry - 14)
    end
end

local function SchemaDraw(canvas, phaseData, assign)
    if not canvas or not canvas.CreateTexture then return end
    texUsed, fontUsed, noteUsed, drawUsedB = 0, 0, 0, 0
    labelPos = {}
    for i = 1, table.getn(texPool) do texPool[i]:Hide() end
    for i = 1, table.getn(fontPool) do fontPool[i]:Hide() end
    for i = 1, table.getn(notePool) do notePool[i]:Hide() end
    for i = 1, table.getn(btnPool) do btnPool[i]:Hide() end
    if not phaseData then return end

    -- zones : halo + anneau de bordure + label (rendu façon site)
    for _, z in ipairs(phaseData.zones or {}) do
        DrawZone(canvas, z)
    end

    -- flèches
    for _, a in ipairs(phaseData.arrows or {}) do
        DrawDashed(canvas, a.x1 / 100 * CW, a.y1 / 100 * CH, a.x2 / 100 * CW, a.y2 / 100 * CH)
    end

    -- symboles : 2 passes (d'abord ce qui n'est pas un role, puis les roles, qui evitent les labels deja poses)
    for pass = 1, 2 do
    for _, s in ipairs(phaseData.syms or {}) do
    if (pass == 2) == (s.type == "R") then
        local px, py = s.x / 100 * CW, s.y / 100 * CH
        if s.type == "B" then
            local t = PoolTex(canvas)
            if not t then return end
            t:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
            t:SetWidth(16) t:SetHeight(16)
            t:SetPoint("CENTER", canvas, "TOPLEFT", px, -py)
            if s.label ~= "" then
                local f = PoolFont(canvas)
                if not f then return end
                f:SetText(s.label)
                f:SetTextColor(1, 0.5, 0.45)
                f:SetPoint("TOP", canvas, "TOPLEFT", px, -py - 9)
                RegLabel(f, px, py + 9)
            end
        elseif s.type == "C" then
            local t = PoolTex(canvas)
            if not t then return end
            t:SetTexture("Interface\\Buttons\\WHITE8X8")
            t:SetVertexColor(0.85, 0.30, 0.25, 0.95)
            t:SetWidth(10) t:SetHeight(10)
            t:SetPoint("CENTER", canvas, "TOPLEFT", px, -py)
            local lbl = s.label
            if s.count ~= "" then lbl = lbl .. " x" .. s.count end
            if lbl ~= "" then
                local f = PoolFont(canvas)
                if not f then return end
                f:SetText(lbl)
                f:SetTextColor(1, 0.8, 0.75)
                f:SetPoint("TOP", canvas, "TOPLEFT", px, -py - 6)
                RegLabel(f, px, py + 6)
            end
        elseif s.type == "M" then
            local idx = SCHEMA_ICON[s.symbol] or 1
            local t = PoolTex(canvas)
            if not t then return end
            t:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. idx)
            t:SetWidth(14) t:SetHeight(14)
            t:SetPoint("CENTER", canvas, "TOPLEFT", px, -py)
            if s.label ~= "" then
                local f = PoolFont(canvas)
                if not f then return end
                f:SetText(s.label)
                f:SetTextColor(0.95, 0.95, 0.85)
                f:SetPoint("TOP", canvas, "TOPLEFT", px, -py - 8)
                RegLabel(f, px, py + 8)
            end
        elseif s.type == "T" then
            local f = PoolNote(canvas)
            f:SetText(s.label)
            f:SetTextColor(0.95, 0.85, 0.55)
            f:SetPoint("CENTER", canvas, "TOPLEFT", px, -py)
        elseif s.type == "R" then
            local col = ROLE_COLOR[s.role] or ROLE_COLOR.tank
            -- halo doux derrière le point (rendu rond comme le site)
            local glow = PoolTex(canvas)
            if glow then
                glow:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
                glow:SetVertexColor(col[1], col[2], col[3], 0.45)
                glow:SetWidth(20)
                glow:SetHeight(20)
                glow:SetPoint("CENTER", canvas, "TOPLEFT", px, -py)
            end
            local t = PoolTex(canvas)
            if not t then return end
            t:SetTexture("Interface\\Buttons\\WHITE8X8")
            t:SetVertexColor(col[1], col[2], col[3], 1)
            t:SetWidth(7) t:SetHeight(7)
            t:SetPoint("CENTER", canvas, "TOPLEFT", px, -py)
            -- poste + joueur assigné (du plan importé si présent)
            local who = ""
            local plan = GetPlan()
            if assign and s.poste ~= "" then
                local slot = assign[s.poste]
                if slot and slot.player then who = slot.player end
            end
            local txt = s.poste ~= "" and s.poste or s.label
            if who ~= "" then txt = txt .. " : " .. who end
            if txt ~= "" then
                -- label CLIQUABLE : clic = cibler le joueur, clic droit = whisper
                local b = PoolBtn(canvas)
                local f = b:GetFontString()
                if not f then
                    f = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    b:SetFontString(f)
                    f:SetJustifyH("LEFT")
                    f:ClearAllPoints()
                    f:SetPoint("LEFT", b, "LEFT", 0, 0)   -- texte collé à gauche (la collision suppose x = lx)
                end
                f:SetText(txt)
                f:SetTextColor(col[1], col[2], col[3])
                b:SetWidth(130)
                b:SetHeight(11)
                -- anti-collision : si un label déjà posé est trop près,
                -- on décale de 9 px vers le bas (les rôles du site partagent
                -- souvent la même position).
                local lx, ly = px + 9, py - 4
                local lw = f:GetStringWidth() or 90
                for _, q in ipairs(labelPos) do
                    if lx < q[1] + q[3] and q[1] < lx + lw and math.abs(q[2] - ly) < 11 then
                        ly = q[2] + 11
                    end
                end
                if ly > CH - 11 then ly = CH - 11 end   -- jamais sous le cadre du schéma
                table.insert(labelPos, { lx, ly, lw })
                b:SetPoint("TOPLEFT", canvas, "TOPLEFT", lx, -ly)
                local target = FirstName(who)   -- "Bob, Alice" -> "Bob"
                b:SetScript("OnClick", function()
                    if target and target ~= "" then
                        if arg1 == "RightButton" then
                            ChatFrame_OpenChat("/w " .. target .. " ")
                        else
                            TargetByName(target)
                        end
                    end
                end)
                b:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                    GameTooltip:SetText(txt ..
                        (who ~= "" and "\n|cff888888Clic : cibler · Clic droit : whisper|r" or ""), 1, 0.9, 0.6)
                    GameTooltip:Show()
                end)
                b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
        end
    end
    end
    end
end

-- ============================================================
-- Sources de navigation : schémas + plan importé
-- ============================================================

local function SortBosses(bosses)
    table.sort(bosses, function(a, b)
        local oa, ob = a.order or 9999, b.order or 9999
        if oa ~= ob then return oa < ob end
        return (a.name or "") < (b.name or "")
    end)
end

local function NavList()
    -- retour : { {slug, name, bosses={{slug,name,order}}, source="schemas"|"plan"} }
    local out = {}
    local S = GetSchemas()
    local seen = {}
    for slug, R in pairs(S) do
        local bosses = {}
        for bslug, B in pairs(R.bosses or {}) do
            table.insert(bosses, { slug = bslug, name = B.name or bslug, order = B.order })
        end
        if table.getn(bosses) > 0 then
            SortBosses(bosses)   -- ordre de rencontre (fichier), pas l'ordre alphabétique
            table.insert(out, { slug = slug, name = R.name or slug, bosses = bosses, source = "schemas" })
            seen[slug] = true
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)   -- pairs() : ordre indéfini
    local plan = GetPlan()
    if plan and plan.raid and plan.raid ~= "" and not seen[plan.raid] then
        local bosses = {}
        for _, b in ipairs(plan.bossOrder or {}) do
            table.insert(bosses, { slug = b, name = b })
        end
        if table.getn(bosses) > 0 then
            table.insert(out, { slug = plan.raid, name = plan.raid, bosses = bosses, source = "plan" })
            seen[plan.raid] = true
        end
    end
    return out
end

local function BossesOf(raidSlug)
    local nav = NavList()
    for i = 1, table.getn(nav) do
        if nav[i].slug == raidSlug then return nav[i].bosses end
    end
    return {}
end

local function SelectBoss(raidSlug, bossSlug)
    if raidSlug ~= sel.raidSlug or bossSlug ~= sel.bossSlug then sel.phase = "p1" end
    sel.raidSlug = raidSlug
    sel.bossSlug = bossSlug
    if ui.refresh then ui.refresh() end
end

-- ============================================================
-- Kill tracking : quand le chat annonce la mort d'un boss connu,
-- le marquer ✓ (persistant par raid) et avancer au boss suivant.
-- ============================================================

local function GetKills()
    local db = RT.Store.DB()
    db.octofanKills = db.octofanKills or {}
    return db.octofanKills
end

-- Un kill compte pour "ce raid" pendant KILL_FRESH secondes (une soirée) :
-- au-delà, le boss peut être re-tué (reset d'instance) et ré-enregistré.
local KILL_FRESH = 8 * 3600
local function KillIsFresh(v)
    return type(v) == "number" and (time() - v) < KILL_FRESH
end

-- Index nom (minuscule) -> { R = raid, B = boss } ; reconstruit seulement si
-- schémas ou plan ont changé (au lieu de NavList() à CHAQUE mort de mob).
local nameIdx, idxPlan, idxVer = nil, nil, -1
local function BossIndex()
    local plan = GetPlan()
    if nameIdx and idxPlan == plan and idxVer == schemaVer then return nameIdx end
    nameIdx, idxPlan, idxVer = {}, plan, schemaVer
    local nav = NavList()
    for i = 1, table.getn(nav) do
        local R = nav[i]
        for j = 1, table.getn(R.bosses) do
            local B = R.bosses[j]
            local full = string.lower(B.name or "")
            if full ~= "" then
                local entry = { R = R, B = B, nparts = 1 }
                if not nameIdx[full] then nameIdx[full] = entry end
                -- rencontre à deux PNJ ("A & B") : chaque PNJ est reconnu, le kill
                -- compte quand les deux sont tombés
                if string.find(full, " & ", 1, true) then
                    local n = 0
                    for piece in string.gfind(full, "[^&]+") do
                        local part = string.gsub(piece, "^%s*(.-)%s*$", "%1")
                        if part ~= "" then n = n + 1; if not nameIdx[part] then nameIdx[part] = entry end end
                    end
                    entry.nparts = n
                end
            end
        end
    end
    return nameIdx
end

local function PartsDown(entry, lowName)
    if entry.nparts < 2 then return true end
    entry.dead = entry.dead or {}
    entry.dead[lowName] = GetTime()
    local n = 0
    for _, t in pairs(entry.dead) do
        if GetTime() - t < 120 then n = n + 1 end
    end
    return n >= entry.nparts
end

-- Messages de mort 1.12 (CHAT_MSG_COMBAT_HOSTILE_DEATH). Les formes FR
-- "Vous avez tué" / "est tué par" sont NON VÉRIFIÉES (%S* tolère l'encodage).
local DEATH_PAT = {
    "^(.-) dies%.", "^(.-) meurt%.",
    "^You have slain (.-)!", "^(.-) is slain by ",
    "^Vous avez tu%S* (.-) ?!", "^(.-) est tu%S* par ",
}
local function DeadName(msg)
    for i = 1, table.getn(DEATH_PAT) do
        local _, _, n = string.find(msg, DEATH_PAT[i])
        if n then
            n = string.gsub(n, "^%s*(.-)%s*$", "%1")
            if n ~= "" then return n end
        end
    end
    return nil
end

local killFrame = CreateFrame("Frame")
killFrame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
killFrame:SetScript("OnEvent", function()
    if event ~= "CHAT_MSG_COMBAT_HOSTILE_DEATH" or not arg1 then return end
    local name = DeadName(arg1)
    if not name then return end
    local low = string.lower(name)
    local entry = BossIndex()[low]
    if not entry then return end
    local R, B = entry.R, entry.B
    if not PartsDown(entry, low) then return end
    local K = GetKills()
    K[R.slug] = K[R.slug] or {}
    if KillIsFresh(K[R.slug][B.slug]) then return end
    K[R.slug][B.slug] = time()
    RT.Print("|cff44FF44OK|r " .. (B.name or B.slug) .. " - boss tombé (" .. (R.name or R.slug) .. ").")
    local nRaid = GetNumRaidMembers() or 0
    -- annonce : le chef de raid SEULEMENT (sinon chaque assistant avec l'addon double le message)
    if nRaid > 0 and IsRaidLeader and IsRaidLeader() then
        SendChatMessage((B.name or B.slug) .. " down !", "RAID", nil, nil)
    end
    -- attendance : snapshot des présents (clé dédiée : db.attendance appartient à Attendance.lua)
    if nRaid > 0 then
        local db = RT.Store.DB()
        db.raidAttend = db.raidAttend or {}
        local here, away, off = {}, {}, 0
        local myZone = GetRealZoneText and GetRealZoneText() or nil
        for i = 1, nRaid do
            local n, _, _, _, _, _, z, online = GetRaidRosterInfo(i)
            if n then
                if not online then off = off + 1
                elseif myZone and z and z ~= myZone then table.insert(away, n)
                else table.insert(here, n) end
            end
        end
        table.insert(db.raidAttend, 1, {
            when = date("%Y-%m-%d %H:%M"), ts = time(),
            raid = R.slug, boss = B.name or B.slug,
            count = table.getn(here), offline = off, away = away, players = here,
        })
        while table.getn(db.raidAttend) > 200 do
            table.remove(db.raidAttend)
        end
    end
    -- avance auto : prochain boss PAS ENCORE tué, dans l'ordre de la rencontre
    if R.slug == sel.raidSlug and B.slug == sel.bossSlug then
        local n = table.getn(R.bosses)
        local idx = 1
        for i = 1, n do
            if R.bosses[i].slug == B.slug then idx = i break end
        end
        for step = 1, n - 1 do
            local cand = R.bosses[math.mod(idx - 1 + step, n) + 1]
            if not KillIsFresh(K[R.slug][cand.slug]) then
                sel.bossSlug = cand.slug
                sel.phase = "p1"
                break
            end
        end
    end
    if ui.refresh then ui.refresh() end
end)

-- Un poste peut contenir plusieurs joueurs ("Bob, Alice") : comparaison EXACTE
-- par nom (le find plain "bob" matchait aussi "Bobby" / "Robobo").
local function IsMe(field, me)
    if not field or not me then return false end
    local lme = string.lower(me)
    for piece in string.gfind(field, "[^,]+") do
        local tok = string.gsub(piece, "^%s*(.-)%s*$", "%1")
        if string.lower(tok) == lme then return true end
    end
    return false
end

-- ============================================================
-- La page Raid (module "raid")
-- ============================================================

if RT.Modules and RT.Modules.Register then
RT.Modules.Register({
    id    = "raid",
    title = "Raid",
    tip   = "La page du raid : schémas, assignations, strat, ton rôle.",
    color = { 1.0, 0.82, 0.27 },

    build = function(panel)
        -- ── Barre d'actions ──
        local acts = {}
        local actX = 8 -- distance du bord DROIT du panneau au bord droit du prochain bouton
        local function Act(text, w, onClick, tip)
            local b = RT.UI.Button(panel, {
                text = text, width = w, height = 22,
                anchor = { "TOPRIGHT", panel, "TOPRIGHT", -actX, -8 },
                tooltip = tip,
            })
            actX = actX + w + 6
            b:SetScript("OnClick", onClick)
            table.insert(acts, b)
            return b
        end
        Act("🎯 Trash->AM", 96, function()
            if RT.OctoFan and RT.OctoFan.PushTrash then RT.OctoFan.PushTrash(false) end
        end, "Pousse les packs trash du plan comme règles AutoMarkerOW.")
        Act("📡 Envoyer", 76, function()
            if RT.OctoFan and RT.OctoFan.SendToRaid then RT.OctoFan.SendToRaid() end
        end, "Diffuse le plan aux autres RaidTools du raid.")
        Act("⏱ Pull 10s", 70, function()
            if RT_PT and RT_PT.Start then RT_PT.Start(10, nil, true) end
        end, "Compte à rebours de pull annoncé au raid.")
        Act("📣 Annoncer", 78, function()
            local boss = sel.bossSlug
            if boss and RT_Tactics then
                local cands = { ui.bossName, boss, (string.gsub(boss, "_", " ")) }
                for i = 1, 3 do
                    local c = cands[i]
                    if c and c ~= "" and RT_Tactics.Find(c) then
                        RT_Tactics.Post(c, "RAID")
                        return
                    end
                end
                RT.Print("|cffAA66FFRaid|r: aucune tactique connue pour ce boss.")
            else RT.Print("|cffAA66FFRaid|r: sélectionne un boss.") end
        end, "Poste la tactique du boss au raid.")
        Act("↺ Kills", 62, function()
            local K = GetKills()
            if sel.raidSlug then K[sel.raidSlug] = nil end
            RT.Print("|cffAA66FFRaid|r: kills réinitialisés pour ce raid.")
            if ui.refresh then ui.refresh() end
        end, "Réinitialise le suivi des boss tués pour ce raid.")

        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
        title:SetText("|cffFFCC44Raid|r — schéma, assignations, strat")
        ui.title = title

        -- ── Colonne gauche : navigation ──
        local nav = CreateFrame("Frame", nil, panel)
        nav:SetWidth(168)
        nav:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -34)
        nav:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -520, 8)
        RT.UI.ApplyBackdrop(nav, 0.02, 0.02, 0.05, 0.85)
        ui.navRows = {}
        for i = 1, 44 do
            local b = CreateFrame("Button", nil, nav)
            b:SetHeight(16)
            b:SetPoint("TOPLEFT", nav, "TOPLEFT", 6, -(6 + (i - 1) * 16))
            b:SetPoint("RIGHT", nav, "RIGHT", -6, 0)
            local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t:SetPoint("TOPLEFT", b, "TOPLEFT", 2, 0)
            t:SetJustifyH("LEFT")
            b:SetFontString(t)
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            b:GetHighlightTexture():SetAlpha(0.3)
            b:Hide()
            ui.navRows[i] = b
        end

        -- ── Centre : schéma + détails ──
        local center = CreateFrame("Frame", nil, panel)
        center:SetWidth(356)
        center:SetPoint("TOPLEFT", panel, "TOPLEFT", 182, -34)
        center:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -158, 8)
        RT.UI.ApplyBackdrop(center, 0.02, 0.02, 0.05, 0.85)

        local bossLbl = center:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bossLbl:SetPoint("TOPLEFT", center, "TOPLEFT", 8, -6)
        ui.bossLbl = bossLbl

        local prevB = RT.UI.Button(center, {
            text = "<", width = 22, height = 18,
            anchor = { "TOPRIGHT", center, "TOPRIGHT", -64, -4 },
        })
        local nextB = RT.UI.Button(center, {
            text = ">", width = 22, height = 18,
            anchor = { "TOPRIGHT", center, "TOPRIGHT", -38, -4 },
        })
        ui.prevB, ui.nextB = prevB, nextB

        local canvas = CreateFrame("Frame", nil, center)
        canvas:SetWidth(CW)
        canvas:SetHeight(CH)
        canvas:SetPoint("TOPLEFT", center, "TOPLEFT", 12, -26)
        canvas:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        canvas:SetBackdropColor(0.05, 0.06, 0.09, 1)
        canvas:SetBackdropBorderColor(0.45, 0.38, 0.22, 1)
        ui.canvas = canvas

        local details = RT.UI.TextScroll(center, {
            name = "RT5_RaidDetails",
            anchor = { "TOPLEFT", canvas, "BOTTOMLEFT", 0, -8 },
            width = 336,
        })
        details.scroll:SetPoint("BOTTOMRIGHT", center, "BOTTOMRIGHT", -6, 6)
        ui.details = details

        -- ── Colonne droite : mon rôle + état ──
        local right = CreateFrame("Frame", nil, panel)
        right:SetWidth(140)
        right:SetPoint("TOPLEFT", panel, "TOPLEFT", 546, -34)
        right:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
        RT.UI.ApplyBackdrop(right, 0.02, 0.02, 0.05, 0.85)
        ui.right = RT.UI.TextScroll(right, {
            name = "RT5_RaidRight",
            anchor = { "TOPLEFT", right, "TOPLEFT", 4, -4 },
            width = 132,
        })
        ui.right.scroll:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -4, 4)

        -- diagnostic /rt4diag
        if RT4 and RT4.Diag then
            RT4.Diag(panel, "Panel_raid")
            RT4.Diag(nav, "raid_nav")
            RT4.Diag(center, "raid_center")
            RT4.Diag(canvas, "raid_canvas")
            RT4.Diag(right, "raid_right")
            RT4.Diag(ui.details.scroll, "raid_details_scroll")
            RT4.Diag(ui.right.scroll, "raid_right_scroll")
        end

        -- ── Comportement ◀ ▶ ──
        local function BossList() return BossesOf(sel.raidSlug) end
        local function Step(dir)
            local bs = BossList()
            local idx = 1
            for i = 1, table.getn(bs) do
                if bs[i].slug == sel.bossSlug then idx = i break end
            end
            local n = table.getn(bs)
            if n > 0 then
                idx = math.mod(idx - 1 + dir + n, n) + 1 -- math.mod = fmod (signe du dividende) : on ajoute n pour rester positif
                SelectBoss(sel.raidSlug, bs[idx].slug)
            end
        end
        prevB:SetScript("OnClick", function() Step(-1) end)
        nextB:SetScript("OnClick", function() Step(1) end)

        -- ── Boutons de phase (P1/P2/P3 si le schéma en a plusieurs) ──
        ui.phBtns = {}
        for i = 1, 3 do
            local pb = RT.UI.Button(center, {
                text = "P" .. i, width = 26, height = 16,
                anchor = { "TOPLEFT", bossLbl, "TOPRIGHT", 8 + (i - 1) * 30, -1 },
                tooltip = "Phase " .. i .. " du schéma.",
            })
            pb:SetScript("OnClick", function()
                sel.phase = "p" .. i
                if ui.refresh then ui.refresh() end
            end)
            pb:Hide()
            ui.phBtns[i] = pb
        end
        -- ── Image de fond du schéma + lien vers le site ──
        local function SchemaBgOn()
            local st = RT.Store.DB().settings
            return not (st and st.schemaBg == false)
        end
        local bgTex = canvas:CreateTexture(nil, "BACKGROUND")
        bgTex:SetPoint("TOPLEFT", canvas, "TOPLEFT", 3, -3)
        bgTex:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -3, 3)
        bgTex:Hide()
        ui.bg = bgTex
        ui.schemaBgOn = SchemaBgOn

        -- Petite fenêtre : l'adresse est sélectionnée, Ctrl+C la copie (on ne peut pas ouvrir un navigateur depuis 1.12)
        local linkBox
        local function ShowLink(url)
            if not linkBox then
                local f = CreateFrame("Frame", "RT5_LinkBox", UIParent)
                f:SetWidth(440)
                f:SetHeight(78)
                f:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
                f:SetFrameStrata("DIALOG")
                RT.UI.ApplyBackdrop(f, 0.03, 0.03, 0.06, 0.96)
                local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                t:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
                t:SetText("Lien du schéma : Ctrl+C pour copier, puis colle-le dans ton navigateur")
                local eb = CreateFrame("EditBox", "RT5_LinkEdit", f)
                eb:SetWidth(414)
                eb:SetHeight(22)
                eb:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)
                eb:SetFontObject(ChatFontNormal)
                eb:SetAutoFocus(false)
                eb:SetMaxLetters(300)
                eb:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 10,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 },
                })
                eb:SetBackdropColor(0, 0, 0, 0.9)
                eb:SetTextInsets(6, 6, 0, 0)
                eb:SetScript("OnEscapePressed", function() f:Hide() end)
                eb:SetScript("OnEnterPressed", function() f:Hide() end)
                -- lecture seule : toute modification revient à l'adresse
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

        local linkB = RT.UI.Button(canvas, {
            text = "Lien", width = 34, height = 16,
            anchor = { "BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -7, 7 },
            tooltip = "Affiche l'adresse de ce schéma sur le site (Ctrl+C pour copier).",
        })
        linkB:SetScript("OnClick", function()
            local url = SITE_URL
            if sel.bossSlug then url = SITE_URL .. "?boss=" .. sel.bossSlug end
            ShowLink(url)
        end)
        local bgB = RT.UI.Button(canvas, {
            text = "Fond", width = 34, height = 16,
            anchor = { "RIGHT", linkB, "LEFT", -4, 0 },
            tooltip = "Affiche ou masque l'image de fond du schéma.",
        })
        bgB:SetScript("OnClick", function()
            local db = RT.Store.DB()
            db.settings = db.settings or {}
            db.settings.schemaBg = not SchemaBgOn()
            if ui.refresh then ui.refresh() end
        end)
        ui.linkB, ui.bgB = linkB, bgB
        -- Agrandir : la meme page en grand (RT_SchemaView.lua) - noms sans chevauchement, assignations et strat a cote
        local bigB = RT.UI.Button(canvas, {
            text = "Agrandir", width = 56, height = 16,
            anchor = { "RIGHT", bgB, "LEFT", -4, 0 },
            tooltip = "Ouvre le schema en grand, avec les noms des joueurs bien lisibles.",
        })
        bigB:SetScript("OnClick", function()
            if RTV and RTV.Open then RTV.Open(sel.raidSlug, sel.bossSlug) end
        end)
        ui.bigB = bigB

        -- ── Colonne droite (mon rôle + état du raid) : texte reconstruit, n'est
        --    réécrit que s'il a changé (SetText remet le scroll en haut) ──
        local function BuildRightText(assign)
            local me = UnitName("player")
            local RL = {}
            table.insert(RL, "|cffFFCC44Mon rôle|r")
            table.insert(RL, "")
            local found = false
            if assign then
                for poste, slot in pairs(assign) do
                    if IsMe(slot.player, me) then
                        found = true
                        table.insert(RL, "|cff66CCFF" .. poste .. "|r")
                        if slot.task and slot.task ~= "" then
                            table.insert(RL, "  " .. slot.task)
                        end
                    end
                end
            end
            if not found then table.insert(RL, "|cff888888Rien sur ce boss|r") end
            table.insert(RL, "")
            if RT_AA_LAST and RT_AA_LAST.tanks and table.getn(RT_AA_LAST.tanks) > 0 then
                table.insert(RL, "|cffFFCC44Tanks :|r")
                for i = 1, table.getn(RT_AA_LAST.tanks) do
                    table.insert(RL, "  MT" .. i .. " " .. RT_AA_LAST.tanks[i])
                end
                table.insert(RL, "")
            end
            local nMembers = (GetNumRaidMembers and GetNumRaidMembers()) or 0
            if nMembers > 0 then
                local alive, dead = {}, {}
                for i = 1, nMembers do
                    -- 9 retours en 1.12 (zone en 7e) : un _ de plus avant online
                    local _, _, sg, _, _, _, _, online, isDead = GetRaidRosterInfo(i)
                    if sg then
                        alive[sg] = (alive[sg] or 0) + 1
                        if isDead or not online then dead[sg] = (dead[sg] or 0) + 1 end
                    end
                end
                local gl = {}
                for g = 1, 8 do
                    if alive[g] then
                        local ok = alive[g] - (dead[g] or 0)
                        local col = (dead[g] or 0) == 0 and "|cff44FF44" or "|cffFFAA44"
                        table.insert(gl, col .. "G" .. g .. " " .. ok .. "/" .. alive[g] .. "|r")
                    end
                end
                if table.getn(gl) > 0 then
                    table.insert(RL, "|cffFFCC44Groupes :|r")
                    table.insert(RL, table.concat(gl, " "))
                end
            end
            local nRaid = (GetNumRaidMembers and GetNumRaidMembers()) or 0
            local nParty = (GetNumPartyMembers and GetNumPartyMembers()) or 0
            table.insert(RL, "|cff888888Raid : " .. (nRaid > 0 and (nRaid .. "/40") or
                (nParty > 0 and ((nParty + 1) .. "/5") or "solo")) .. "|r")
            local mode = (RT.OctoFan and RT.OctoFan.GetMode and RT.OctoFan.GetMode()) or "pug"
            table.insert(RL, "|cff888888Mode : " .. (mode == "guild" and "🏰 Guilde" or "🌍 PUG") .. "|r")
            return table.concat(RL, "\n")
        end
        local function RefreshRight()
            if not (ui.right and ui.right.SetText) then return end
            local txt = BuildRightText(ui.curAssign)
            if txt ~= ui.rightText then
                ui.rightText = txt
                ui.right:SetText(txt)
            end
        end
        -- l'état du raid (morts, hors ligne, effectif) bouge sans clic : 2 s tant que la page est affichée
        right:SetScript("OnUpdate", function()
            this.t = (this.t or 0) + arg1
            if this.t < 2 then return end
            this.t = 0
            RefreshRight()
        end)

        -- ── Refresh global de la page ──
        -- guarded : la page peut être rechargée (build) pendant qu'un
        -- ticker/bascule appelle encore l'ancienne closure -> pcall + refs
        -- locales, jamais de SetText sur un widget nil/détruit.
        ui.refresh = function()
            local S = GetSchemas()
            local nav = NavList()

            -- auto-sélection au premier affichage
            if not sel.raidSlug then
                local first = nav[1]
                if first then
                    sel.raidSlug = first.slug
                    sel.bossSlug = first.bosses[1] and first.bosses[1].slug or nil
                end
            end

            -- nav
            local row = 1
            for _, R in ipairs(nav) do
                if row > 44 then break end
                local b = ui.navRows[row]
                if not b or not b.SetText then break end
                b:SetText("|cffFFCC44[+] " .. (R.name or R.slug) .. "|r")
                b.rKind, b.rSlug, b.rRaid = "raid", R.slug, R.slug
                b:SetScript("OnClick", function()
                    SelectBoss(this.rRaid, nil)
                end)
                b:Show()
                row = row + 1
                if R.slug == sel.raidSlug then
                    if not sel.bossSlug and R.bosses[1] then
                        sel.bossSlug = R.bosses[1].slug
                    end
                    local K = GetKills()
                    local kd = K[R.slug]
                    for _, B in ipairs(R.bosses) do
                        if row > 44 then break end
                        local bb = ui.navRows[row]
                        if not bb or not bb.SetText then break end
                        local mark = (B.slug == sel.bossSlug) and "|cffFFCC44▶ " or "   "
                        local done = kd and kd[B.slug] and "|cff44FF44✓|r " or ""
                        bb:SetText(done .. mark .. (B.name or B.slug))
                        bb.rKind, bb.rSlug, bb.rRaid = "boss", B.slug, R.slug
                        bb:SetScript("OnClick", function()
                            SelectBoss(this.rRaid, this.rSlug)
                        end)
                        bb:Show()
                        row = row + 1
                    end
                end
            end
            for j = row, 44 do
                local hb = ui.navRows[j]
                if hb and hb.Hide then hb:Hide() end
            end

            -- centre
            local R = sel.raidSlug and S[sel.raidSlug]
            local plan = GetPlan()
            local bossName = nil
            local B = R and sel.bossSlug and R.bosses[sel.bossSlug]
            if B then bossName = B.name end
            if not bossName and plan and plan.raid == sel.raidSlug then
                bossName = sel.bossSlug -- slug = display name dans le plan
            end
            if ui.bossLbl and ui.bossLbl.SetText then
                ui.bossLbl:SetText(bossName and ("|cffFFD700" .. bossName .. "|r") or "|cff888888Sélectionne un boss|r")
            end

            -- schéma (phase courante)
            local phKey = nil
            if B and B.phases then
                if B.phases[sel.phase] then phKey = sel.phase
                else
                    for i = 1, 3 do
                        if B.phases["p" .. i] then phKey = "p" .. i break end
                    end
                    if not phKey then
                        for k in pairs(B.phases) do phKey = k break end
                    end
                end
            end
            local phaseData = phKey and B.phases[phKey] or nil
            -- boutons de phase (visibles seulement si plusieurs phases)
            if ui.phBtns then
                local phasesT = B and B.phases or nil
                local nph = 0
                for i = 1, 3 do
                    local pd = phasesT and phasesT["p" .. i] or nil
                    if pd and ((table.getn(pd.zones or {}) + table.getn(pd.arrows or {})
                        + table.getn(pd.syms or {}) + table.getn(pd.tips or {})) > 0) then nph = nph + 1 end
                end
                for i = 1, 3 do
                    local pb = ui.phBtns[i]
                    if not pb or not pb.Show then break end
                    local pd = phasesT and phasesT["p" .. i] or nil
                    local has = pd and ((table.getn(pd.zones or {}) + table.getn(pd.arrows or {})
                        + table.getn(pd.syms or {}) + table.getn(pd.tips or {})) > 0) and true or false
                    if has and nph > 1 then pb:Show() else pb:Hide() end
                    local fs = pb.GetFontString and pb:GetFontString()
                    if fs then
                        if phKey == "p" .. i then fs:SetTextColor(1, 0.82, 0.27)
                        else fs:SetTextColor(1, 1, 1) end
                    end
                end
            end
            local assign = plan and plan.assign and bossName and plan.assign[bossName]
            ui.bossName = bossName
            ui.curAssign = assign
            -- image de fond (si livrée pour ce boss et si le joueur ne l'a pas coupée)
            if ui.bg then
                if phaseData and sel.bossSlug and (SCHEMA_IMG[sel.bossSlug] or (RT_SCHEMA_IMG and RT_SCHEMA_IMG[sel.bossSlug])) and ui.schemaBgOn and ui.schemaBgOn() then
                    ui.bg:SetTexture("Interface\\AddOns\\rt\\img\\" .. sel.bossSlug)
                    ui.bg:SetVertexColor(0.6, 0.6, 0.6, 1)
                    ui.bg:Show()
                else
                    ui.bg:Hide()
                end
            end
            if RTV and RTV.DrawSmall then pcall(RTV.DrawSmall, canvas, phaseData, assign, CW, CH, (sel.raidSlug and sel.bossSlug and phKey) and (sel.raidSlug .. "/" .. sel.bossSlug .. "/" .. phKey) or nil) else pcall(SchemaDraw, canvas, phaseData, assign) end
            canvas:Show()
            if not phaseData and not bossName then
                canvas:Hide()
            end

            -- détails : assignations + strat + tips + trash
            local L = {}
            if phaseData and table.getn(phaseData.tips or {}) > 0 then
                table.insert(L, "|cff88FF88Préparation :|r")
                for _, t in ipairs(phaseData.tips) do table.insert(L, "  • " .. t) end
                table.insert(L, "")
            end
            if assign then
                table.insert(L, "|cffFFCC44Assignations :|r")
                for poste, slot in pairs(assign) do
                    local who = slot.player or "?"
                    if slot.task and slot.task ~= "" then who = who .. " — " .. slot.task end
                    table.insert(L, "  |cff66CCFF" .. poste .. "|r : " .. who)
                end
                table.insert(L, "")
            end
            local strat = plan and plan.strats and bossName and plan.strats[bossName]
            if strat and strat ~= "" then
                table.insert(L, "|cffFFCC44Stratégie :|r")
                for line in string.gfind(strat .. "\n", "([^\n]*)\n") do
                    if line ~= "" then table.insert(L, "  |cff999999" .. line .. "|r") end
                end
                table.insert(L, "")
            end
            if plan and table.getn(plan.trash or {}) > 0 then
                table.insert(L, "|cffFFCC44Trash :|r")
                for _, pk in ipairs(plan.trash) do
                    local marks = {}
                    for _, m in ipairs(pk.marks or {}) do
                        table.insert(marks, (m.mob or "?") .. (m.tank ~= "" and ("->" .. m.tank) or ""))
                    end
                    if table.getn(marks) > 0 then
                        table.insert(L, "  " .. (pk.name or "Pack") .. " : " .. table.concat(marks, ", "))
                    end
                end
            end
            if table.getn(L) == 0 then
                table.insert(L, "|cff888888Pas de données pour ce boss.|r")
                table.insert(L, "|cff888888Importe un plan (onglet OctoFan) ou les schémas|r")
                table.insert(L, "|cff888888(bouton 🗺️ Fichier schémas du site).|r")
            end
            if ui.details and ui.details.SetText then
                ui.details:SetText(table.concat(L, "\n"))
            end

            RefreshRight()
        end
    end,

    show = function(panel)
        -- Écran membre : ouvrir directement le boss ciblé si possible
        if UnitExists("target") and not UnitIsPlayer("target") then
            local tgt = string.lower(UnitName("target") or "")
            if tgt ~= "" and tgt ~= "unknown entity" then
                local list = BossesOf(sel.raidSlug)
                for _, B in ipairs(list) do
                    local bn = string.lower(B.name or "")
                    if bn ~= "" and (string.find(bn, tgt, 1, true) or string.find(tgt, bn, 1, true)) then
                        if sel.bossSlug ~= B.slug then sel.phase = "p1" end
                        sel.bossSlug = B.slug
                        break
                    end
                end
            end
        end
        if panel._refresh then panel._refresh() end
        if ui.refresh then ui.refresh() end
    end,
})
end

-- ============================================================
-- Panneau Outils v2 : CONTEXTUEL AU MODE (fini la poubelle).
--   GUILDE : Import plan · Attendance (lecture)
--   PUG    : Dashboard (état raid) · Import plan
-- Le reste vit dans les onglets du mode (Groups/Strats/Équipe).
-- ============================================================

if RT.Modules and RT.Modules.Register then
RT.Modules.Register({
    id    = "outils",
    title = "Outils",
    tip   = "Les écrans secondaires, selon ton mode.",
    color = { 0.7, 0.7, 0.85 },

    build = function(panel)
        local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        lbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
        panel._oTitle = lbl

        local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -6)
        panel._oHint = hint

        panel._oBtns = {}
        for i = 1, 9 do
            local b = RT.UI.Button(panel, {
                text = "", width = 300, height = 30,
                anchor = { "TOPLEFT", panel, "TOPLEFT", 24, -56 - (i - 1) * 38 },
            })
            b:Hide()
            panel._oBtns[i] = b
        end

        panel._oRefresh = function()
            local guild = RT.OctoFan and RT.OctoFan.GetMode and RT.OctoFan.GetMode() == "guild"
            local autoOn = not (RT.Store.DB().octofanUI and
                RT.Store.DB().octofanUI.autoSend == false)
            local items = {}
            local function autoSendItem()
                return { "📡 Diffusion auto : " .. (autoOn and "ON" or "OFF"),
                    "Le plan que tu importes part tout seul aux autres RaidTools du raid (leader/officier).",
                    function()
                        local db = RT.Store.DB()
                        db.octofanUI = db.octofanUI or {}
                        db.octofanUI.autoSend = not autoOn
                        RT.Print("|cff33ccffOctoFan|r: diffusion auto " ..
                            (db.octofanUI.autoSend == false and "|cffff6060OFF|r" or "|cff44FF44ON|r") .. ".")
                        if panel._oRefresh then panel._oRefresh() end
                    end }
            end
            local function confirmRelayItem()
                local on = not (RT.Store.DB().octofanUI and RT.Store.DB().octofanUI.confirmRelay == false)
                return { "🔔 Confirmation avant d'appliquer un plan reçu : " .. (on and "ON" or "OFF"),
                    "ON : un plan envoyé par le chef n'est appliqué qu'après ta confirmation, avec la liste des différences. OFF : il est appliqué tout de suite (les différences s'affichent dans le chat).",
                    function()
                        local db = RT.Store.DB()
                        db.octofanUI = db.octofanUI or {}
                        db.octofanUI.confirmRelay = not on
                        RT.Print("|cff33ccffOctoFan|r: confirmation avant application d'un plan reçu " ..
                            (db.octofanUI.confirmRelay == false and "|cffff6060OFF|r" or "|cff44FF44ON|r") .. ".")
                        if panel._oRefresh then panel._oRefresh() end
                    end }
            end
            local function resetPlanItem()
                return { "🗑 Réinitialiser le plan", "Efface le plan local (un 2e clic dans les 6 s confirme). Tu peux le ré-importer ensuite.",
                    function()
                        local now = GetTime and GetTime() or 0
                        if panel._resetArm and (now - panel._resetArm) < 6 then
                            panel._resetArm = nil
                            if RT.OctoFan and RT.OctoFan.ResetPlan then RT.OctoFan.ResetPlan() end
                        else
                            panel._resetArm = now
                            RT.Print("|cff33ccffOctoFan|r: clique encore une fois sous 6 s pour effacer le plan local.")
                        end
                    end }
            end
            if guild then
                panel._oTitle:SetText("|cffFFCC44Outils guilde|r")                panel._oHint:SetText("Le quotidien est dans l'onglet Raid. Ici : les écrans d'appui.")
                table.insert(items, { "📥 Import du plan", "Recharge le plan du site (fichier RT_OctoFanData.lua déjà posé, ou collage).",
                    function() RT.Modules.Show("octofan") end })
                table.insert(items, autoSendItem())
                table.insert(items, confirmRelayItem())
                table.insert(items, { "🎯 Marks auto", "Panneau AutoMarkerOW (marquage automatique des packs).",
                    function() if AutoMarkerOW_ToggleUI then AutoMarkerOW_ToggleUI() end end })
                table.insert(items, { "📋 Mon récap", "Fenêtre : ton rôle, tes assignations, ton groupe.",
                    function() if RT4.ToggleRecap then RT4.ToggleRecap() end end })
                table.insert(items, { "👤 Mon rôle", "Ta fenêtre d'assignations et de strats.",
                    function() if RT.OctoFan and RT.OctoFan.ShowMyRole then RT.OctoFan.ShowMyRole() end end })
                table.insert(items, resetPlanItem())
            else
                panel._oTitle:SetText("|cff59BFF2Outils PUG|r")
                panel._oHint:SetText("Le quotidien est dans l'onglet PUG. Ici : l'état du raid et l'import.")
                table.insert(items, { "📊 Dashboard", "Vue d'ensemble : effectifs, dernière attribution, annonces.",
                    function() if RT4.CanUse("dash") then RT.Modules.Show("dash")
                        else RT.Print("|cff59BFF2Outils|r : réservé aux officiers/RL.") end end })
                table.insert(items, { "📥 Import du plan", "Recharge le plan du site (fichier déjà posé, ou collage).",
                    function() RT.Modules.Show("octofan") end })
                table.insert(items, autoSendItem())
                table.insert(items, confirmRelayItem())
                table.insert(items, { "⚖ Optimiseur (Groups)", "Équilibrage des groupes (Windfury, casters...) — officiers/RL.",
                    function() if RT4.CanUse("groups") then RT.Modules.Show("groups")
                        else RT.Print("|cff59BFF2Outils|r : réservé aux officiers/RL.") end end })
                table.insert(items, { "🎯 Marks auto", "Panneau AutoMarkerOW (marquage automatique des packs).",
                    function() if AutoMarkerOW_ToggleUI then AutoMarkerOW_ToggleUI() end end })
                table.insert(items, { "📋 Mon récap", "Fenêtre : ton rôle, tes assignations, ton groupe.",
                    function() if RT4.ToggleRecap then RT4.ToggleRecap() end end })
                table.insert(items, resetPlanItem())
            end
            for i = 1, table.getn(panel._oBtns) do
                local b = panel._oBtns[i]
                local it = items[i]
                if it then
                    b:SetText(it[1])
                    b:SetScript("OnClick", it[3])
                    if RT_AttachSimpleTooltip then RT_AttachSimpleTooltip(b, it[2]) end
                    b:Show()
                else
                    b:Hide()
                end
            end
        end
    end,

    show = function(panel)
        if panel._oRefresh then panel._oRefresh() end
    end,
})
end

RT.Store.Subscribe("octofan", function()
    if ui.refresh and ui.canvas and ui.canvas:IsVisible() then ui.refresh() end
end)

-- API pour le relay (réception de schémas diffusés par le leader)
RT4 = RT4 or {}
RT4.ParseSchemas = ParseSchemas
RT4.RaidRefresh = function()
    if ui.refresh then ui.refresh() end
end
RT4.RaidResetKills = function()
    local K = GetKills()
    if sel.raidSlug then K[sel.raidSlug] = nil end
    RT.Print("|cffAA66FFRaidTools|r: kills réinitialisés.")
    if ui.refresh then ui.refresh() end
end

RT.Print("|cffAA66FFRaidTools v5|r: page Raid (schémas du site) prête.")
