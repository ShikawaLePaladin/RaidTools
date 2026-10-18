-- ============================================================
-- RT v4 — RT4_Roles.lua
--
-- Couche "rôle" : Membre / Officier / Admin.
--   - détection auto (grade de guilde, chef de raid) + override manuel
--   - gate des onglets du shell v3 : un Membre ne voit / n'ouvre que
--     les onglets autorisés (le monolithe rt.lua fournit tout le
--     moteur, on ne fait qu'organiser — zéro modification de rt.lua).
--   - remplace RT.Modules.Show / Toggle / BuildShell par des wrappers
--     (les originaux sont conservés et appelés).
--
-- Chargé APRÈS rt.lua (rt.toc). Lua 5.0 strict.
-- ============================================================

RT4 = RT4 or {}

local LEVEL = { member = 1, officer = 2, admin = 3 }
RT4.LEVEL = LEVEL

-- Quel onglet demande quel niveau (tout ce qui n'y figure pas = Membre)
local TAB_ACCESS = {
    dash       = 2,
    roster     = 2,
    assign     = 2,
    groups     = 2,
    boss       = 2,
    invite     = 2,
    whisperbot = 2,
}

local ROLE_LABEL = {
    member  = "|cff88FF88👤 Membre|r",
    officer = "|cff66CCFF🎖 Officier / RL|r",
    admin   = "|cffFFCC44👑 Admin|r",
}
RT4.ROLE_LABEL = ROLE_LABEL

function RT4.GetDB()
    local db = RT.Store.DB()
    db.rt4 = db.rt4 or {}
    return db.rt4
end

-- Niveau effectif (override manuel ou auto)
function RT4.GetLevel()
    local db = RT4.GetDB()
    local ov = db.role
    if ov and LEVEL[ov] then
        return LEVEL[ov], "forcé"
    end
    return LEVEL[RT4.AutoRole() or "member"], "auto"
end

-- Détection auto : chef de guilde -> admin, officier -> officer,
-- chef de raid/party PUG -> officer, sinon member.
function RT4.AutoRole()
    if IsGuildLeader and IsGuildLeader() then
        return "admin"
    end
    -- grade de guilde (1.12 : GetGuildInfo retourne le NOM du rang)
    local _, rankName, rankIdx = GetGuildInfo("player")
    -- index de rang (0 = chef de guilde, 1 = 1er rang d'officier par convention) : independant du nom du grade
    if rankIdx ~= nil and rankIdx <= 1 then return "officer" end
    if rankName and rankName ~= "" then
        local low = string.lower(rankName)
        if string.find(low, "offic", 1, true) or string.find(low, "raid lead", 1, true)
            or string.find(low, "maitre", 1, true) or string.find(low, "master", 1, true)
            or string.find(low, "chef de", 1, true) or string.find(low, "ma\195\174tre", 1, true) then
            return "officer"
        end
    end
    -- chef de raid / de groupe (PUG)
    if IsRaidLeader and IsRaidLeader() then return "officer" end
    if IsRaidOfficer and IsRaidOfficer() then return "officer" end
    if IsPartyLeader and IsPartyLeader() then return "officer" end
    return "member"
end

-- Libellé complet de l'accès, ex. "👤 Membre (auto)" ou
-- "🎖 Officier / RL (forcé · auto = 👤 Membre)"
function RT4.AccessLabel()
    local db = RT4.GetDB()
    local autoRole = RT4.AutoRole() or "member"
    if db.role and db.role ~= "auto" then
        return (RT4.ROLE_LABEL[db.role] or db.role) ..
            "  |cff888888(forcé · auto = " .. (RT4.ROLE_LABEL[autoRole] or "?") .. ")|r"
    end
    return (RT4.ROLE_LABEL[autoRole] or "?") .. "  |cff888888(auto)|r"
end

-- Bouton d'acces dans l'en-tete du shell (a cote de S et X) : AUTO -> Membre -> Officier/RL -> Admin
local ACCESS_ORDER = { "auto", "member", "officer", "admin" }
local ACCESS_NAME = { auto = "AUTO", member = "Membre", officer = "Officier/RL", admin = "Admin" }
RT4.ACCESS_NAME = ACCESS_NAME

function RT4.AccessButtonText()
    local db = RT4.GetDB()
    return "Accès : " .. (ACCESS_NAME[db.role or "auto"] or "AUTO")
end

function RT4.CycleAccess()
    local db = RT4.GetDB()
    local cur = db.role or "auto"
    local nxt = "auto"
    for i = 1, table.getn(ACCESS_ORDER) do
        if ACCESS_ORDER[i] == cur then
            nxt = ACCESS_ORDER[math.mod(i, table.getn(ACCESS_ORDER)) + 1]
            break
        end
    end
    db.role = nxt
    RT4.ApplyAccess()
    RT.Print("|cffAA66FFRaidTools|r: accès = " .. (ACCESS_NAME[nxt] or nxt) .. ".")
end

function RT4.EnsureAccessButton()
    local f = _G.RT3_MainFrame
    if not f then return end
    if not RT4.accessBtn then
        local b = CreateFrame("Button", "RT4_AccessBtn", f, "UIPanelButtonTemplate")
        b:SetWidth(112)
        b:SetHeight(22)
        b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -66, -10)   -- juste a gauche de S (-38) et X (-10)
        b:SetScript("OnClick", function() RT4.CycleAccess() end)
        b:SetScript("OnEnter", function()
            GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Niveau d'accès", 1, 0.82, 0)
            GameTooltip:AddLine("Clic : AUTO (grade guilde / chef de raid) → Membre → Officier/RL → Admin.", 0.8, 0.8, 0.8)
            GameTooltip:AddLine(RT4.AccessLabel(), 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        RT4.accessBtn = b
    end
    RT4.accessBtn:SetText(RT4.AccessButtonText())
end

-- Pull : diffuse a tout le raid (RT_Sync TIMER ; les receveurs acceptent n'importe quel emetteur) -> officier/RL
function RT4.StartPull(sec)
    if not RT4.CanUse("whisperbot") then
        RT.Print("|cffAA66FFRaidTools|r: le pull est réservé aux officiers/RL.")
        return
    end
    if RT_PT and RT_PT.Start then RT_PT.Start(sec or 10, nil, true) end
end

function RT4.CanUse(id)
    local lvl = RT4.GetLevel()
    local need = TAB_ACCESS[id] or 1
    return lvl >= need
end

-- ────────────────────────────────────────────────────────────
-- Tables d'onglets + mode courant (DÉFINIES AVANT les wrappers
-- qui les utilisent — sinon CurrentMode est nil au clic droit).
-- ────────────────────────────────────────────────────────────
local TITLES = {
    ["Dashboard"] = "dash", ["Roster"] = "roster", ["Assign"] = "assign",
    ["Assign *"] = "assign", ["Strats"] = "strats", ["Groups"] = "groups",
    ["Boss"] = "boss", ["Consumes"] = "consomes", ["WhisperBot"] = "whisperbot",
    ["Invite"] = "invite", ["octofan"] = "octofan", ["OctoFan"] = "octofan",
    ["Accueil"] = "home", ["Raid"] = "raid", ["Outils"] = "outils",
    ["PUG"] = "pug", ["Équipe"] = "equipe", ["Boss PUG"] = "bossq",
}

-- Ordre d'affichage. Les modules experts (dash/roster/assign/boss/
-- consomes/invite/whisperbot/octofan) ne sont PLUS des onglets :
-- ce qui sert reste accessible via Outils, le reste dort.
local ORDER = { "home", "raid", "pug", "equipe", "bossq", "groups", "strats",
    "outils", "dash", "roster", "assign", "boss", "consomes", "invite",
    "whisperbot", "octofan" }

-- Les onglets PAR MODE (l'analyse du proprio) :
--   GUILDE : Accueil · Raid (schémas/plan) · Groups (direct, officiers) · Strats · Outils
--   PUG    : Accueil · PUG · Équipe · Boss PUG · Outils
local MODE_TABS = {
    guild = { home = true, raid = true, groups = true, strats = true, outils = true },
    pug   = { home = true, pug = true, equipe = true, bossq = true, outils = true },
}

local function CurrentMode()
    if RT.OctoFan and RT.OctoFan.GetMode then
        return RT.OctoFan.GetMode()
    end
    return "pug"
end

-- ────────────────────────────────────────────────────────────
-- Gate du shell : on remplace Show/Toggle/BuildShell par des
-- wrappers qui appellent les originaux après filtrage.
-- ────────────────────────────────────────────────────────────

local origShow   = RT.Modules.Show
local origToggle = RT.Modules.Toggle

RT4.seenHome = false

function RT.Modules.Show(id)
    if id ~= "home" and not RT4.CanUse(id) then
        local db = RT4.GetDB()
        local key = (db.role and db.role ~= "auto" and db.role) or RT4.AutoRole() or "member"
        RT.Print("|cffAA66FFRaidTools|r: onglet \"" .. tostring(id) ..
            "\" réservé aux officiers/RL — ton accès : " ..
            (ROLE_LABEL[key] or "Membre") .. ".")
        id = "home"
    end
    RT4.currentPage = id
    return origShow(id)
end

function RT.Modules.Toggle()
    -- Première ouverture de la session : écran d'accueil
    if not RT4.seenHome then
        RT4.seenHome = true
        RT4.currentPage = "home"
        origShow("home")
        if not _G.RT3_MainFrame then RT.Modules.BuildShell() end
        if _G.RT3_MainFrame then _G.RT3_MainFrame:Show() end
        return
    end
    return origToggle()
end

-- Ouvre /rt : la page du mode courant (Raid en guilde, PUG sinon)
function RT4.OpenShell()
    if not _G.RT3_MainFrame then
        RT.Modules.Toggle()
        return
    end
    if _G.RT3_MainFrame:IsShown() then
        _G.RT3_MainFrame:Hide()
    else
        RT4.currentPage = CurrentMode() == "guild" and "raid" or "pug"
        origShow(RT4.currentPage)
        _G.RT3_MainFrame:Show()
    end
end

-- ────────────────────────────────────────────────────────────
-- Filtrage visuel des onglets après BuildShell : on scanne les
-- enfants de RT3_MainFrame (les tabs sont des boutons dont le
-- texte = titre du module) et on masque ceux interdits.
-- ────────────────────────────────────────────────────────────

local function ScanTabs()
    local f = _G.RT3_MainFrame
    if not f then return end
    -- repérer la fontstring du titre (état vivant : mode/boss/effectif)
    -- NB : le monolithe colore le titre LETTRE PAR LETTRE -> "RAID TOOLS"
    -- n'existe pas en clair ; la queue "OctoWow Beta" si.
    if not RT4.titleFS then
        local regs = { f:GetRegions() }
        for i = 1, table.getn(regs) do
            local r = regs[i]
            if r.GetObjectType and r:GetObjectType() == "FontString" then
                local t = r.GetText and r:GetText() or ""
                if string.find(t, "OctoWow Beta", 1, true) then
                    RT4.titleFS = r
                    break
                end
            end
        end
    end
    local kids = { f:GetChildren() }
    RT4.tabById = RT4.tabById or {}
    for i = 1, table.getn(kids) do
        local c = kids[i]
        if c.GetObjectType and c:GetObjectType() == "Button" and c.GetText then
            local txt = c:GetText()
            local id = txt and TITLES[txt]
            if id then RT4.tabById[id] = c end
        end
    end
    RT4.ApplyAccess()
end

-- Recalcule la GÉOMÉTRIE du shell après filtrage : le BuildShell du
-- monolithe dimensionne la hauteur pour TOUS les tabs (3 rangées avant
-- filtrage) et pousse le contenu vers le bas (panelOffY) -> après masquage
-- des onglets il restait un trou + des panneaux mal placés qui pouvaient
-- dépasser du cadre. On refait le calcul avec les tabs VISIBLES.
local KNOWN_PANELS = { "home", "raid", "pug", "equipe", "bossq", "groups", "strats",
    "outils", "dash", "roster", "assign", "boss", "consomes", "invite",
    "whisperbot", "octofan" }

function RT4.FixShellLayout()
    local f = _G.RT3_MainFrame
    if not f or not RT4.tabById then return end
    local MAX_W, TAB_GAP, START_X, ROW_STEP = 676, 4, 16, 28
    -- comptage des rangées réellement visibles (même algo que ApplyAccess)
    local curX, curRow = START_X, 0
    for _, id in ipairs(ORDER) do
        local tab = RT4.tabById[id]
        if tab and tab.IsObjectType and tab:IsShown() then
            local w = tab:GetWidth() or 72
            if curX + w > MAX_W then
                curRow = curRow + 1
                curX = START_X
            end
            curX = curX + w + TAB_GAP
        end
    end
    local numRows = curRow + 1
    local extraH = (numRows - 1) * ROW_STEP
    local panelOffY = -44 - extraH - 30
    f:SetHeight(470 + extraH)
    -- repositionner TOUS les panneaux de modules au nouveau panelOffY
    for _, id in ipairs(KNOWN_PANELS) do
        local p = _G["RT3_Panel_" .. id]
        if p and p.ClearAllPoints then
            p:ClearAllPoints()
            p:SetPoint("TOPLEFT", f, "TOPLEFT", 12, panelOffY)
            p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
        end
    end
    -- tout panneau affiché qui n'est PAS la page courante : caché (tue
    -- les panneaux fantômes qui dépassent du cadre, vus sur les screens)
    for _, id in ipairs(KNOWN_PANELS) do
        local p = _G["RT3_Panel_" .. id]
        if p and p.IsShown and p:IsShown() and id ~= RT4.currentPage then
            p:Hide()
        end
    end
    -- shell dérivé hors écran (drag accidentel) : recentré. Un drag
    -- volontaire qui reste DANS l'écran est respecté.
    if f.GetLeft and f:GetLeft() ~= nil then
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        if f:GetLeft() < 0 or f:GetBottom() < 0
            or f:GetRight() > sw or f:GetTop() > sh then
            f:ClearAllPoints()
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
end

-- Masque les onglets interdits ET repositionne compact les visibles
-- (Accueil en premier — sinon les onglets cachés laissent des trous).
function RT4.ApplyAccess()
    if not RT4.tabById then return end
    local f = _G.RT3_MainFrame
    if not f then return end
    local allowed = MODE_TABS[CurrentMode()] or MODE_TABS.pug
    local MAX_W, TAB_GAP, START_X, ROW_STEP = 676, 4, 16, 28
    local curX, curRow = START_X, 0
    for _, id in ipairs(ORDER) do
        local tab = RT4.tabById[id]
        if tab and tab.IsObjectType then
            if allowed[id] and RT4.CanUse(id) then
                tab:Show()
                local w = tab:GetWidth() or 72
                if curX + w > MAX_W then
                    curRow = curRow + 1
                    curX = START_X
                end
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT", f, "TOPLEFT", curX, -44 - curRow * ROW_STEP)
                curX = curX + w + TAB_GAP
            else
                tab:Hide()
            end
        end
    end
    RT4.EnsureAccessButton()
    RT4.FixShellLayout()
end

-- La bascule Guilde/PUG (mode) masque/montre les onglets en direct
-- et saute à la page du mode si le shell est ouvert (sinon le panneau
-- de l'ancien mode reste affiché sans son onglet).
RT.Store.Subscribe("octofan_mode", function()
    RT4.ApplyAccess() -- inclut FixShellLayout
    -- shell construit (ouvert OU ferme) : on saute a la page du mode, sinon un /rt
    -- ulterieur reaffiche la page de l'ancien mode (dont l'onglet est cache)
    if _G.RT3_MainFrame then
        RT4.currentPage = CurrentMode() == "guild" and "raid" or "pug"
        origShow(RT4.currentPage)
    end
end)

-- Wrapper BuildShell : scan après la construction (une fois)
local origBuild = RT.Modules.BuildShell
RT.Modules.BuildShell = function()
    local f = origBuild()
    ScanTabs()
    return f
end

-- Le rôle peut changer en cours de session (grade guilde, promotion
-- en raid) : re-scan léger toutes les 30s.
local tick = CreateFrame("Frame")
tick.last = 0
tick:SetScript("OnUpdate", function()
    this.last = this.last + arg1
    if this.last < 30 then return end
    this.last = 0
    RT4.ApplyAccess() -- inclut FixShellLayout
end)

-- Titre vivant : "RAID TOOLS · Guilde · Boss · 24/40" (2s, shell ouvert)
local ttick = CreateFrame("Frame")
ttick.t = 0
ttick:SetScript("OnUpdate", function()
    this.t = this.t + arg1
    if this.t < 2 then return end
    this.t = 0
    local f = _G.RT3_MainFrame
    if not RT4.titleFS or not RT4.titleFS.SetText then return end
    if not f or not f.IsVisible or not f:IsVisible() then return end
    local mode = CurrentMode() == "guild" and "|cffFFCC44Guilde|r" or "|cff59BFF2PUG|r"
    local boss = RT_BOSS_STATE and RT_BOSS_STATE.bossName or ""
    local nR = (GetNumRaidMembers and GetNumRaidMembers()) or 0
    local nP = (GetNumPartyMembers and GetNumPartyMembers()) or 0
    local who = nR > 0 and (nR .. "/40") or (nP > 0 and ((nP + 1) .. "/5") or "")
    local txt = "|cffFFCC44RAID TOOLS|r  ·  " .. mode
    if boss ~= "" then txt = txt .. "  ·  " .. boss end
    if who ~= "" then txt = txt .. "  ·  " .. who end
    RT4.titleFS:SetText(txt)
end)

-- ────────────────────────────────────────────────────────────
-- /rt4diag : déverse la géométrie réelle de tous les cadres
-- (position, taille, visibilité, parent) pour diagnostiquer les
-- dépassements/fantômes avec des chiffres au lieu de screens.
-- ────────────────────────────────────────────────────────────
SLASH_RT4DIAG1 = "/rt4diag"
SlashCmdList["RT4DIAG"] = function()
    local function geo(name)
        local f = type(name) == "string" and _G[name] or name
        local label = (type(name) == "string" and name) or (f and f._diagLabel) or tostring(name)
        if not f or not f.GetLeft then
            return string.format("  %-28s (absent)", tostring(name))
        end
        local l, b = f:GetLeft() or -999, f:GetBottom() or -999
        local w, h = f:GetWidth() or 0, f:GetHeight() or 0
        local vis = f.IsShown and (f:IsShown() and "SHOWN" or "hidden") or "?"
        local par = f.GetParent and f:GetParent() and (f:GetParent().GetName and f:GetParent():GetName() or "(anonyme)") or "UIParent"
        return string.format("  %-28s l=%6.0f b=%6.0f w=%5.0f h=%5.0f %-6s parent=%s",
            label, l, b, w, h, vis, par)
    end
    RT.Print("|cffAA66FF/rt4diag|r — scale UI : " .. string.format("%.2f", UIParent:GetEffectiveScale() or 1))
    RT.Print(geo("RT3_MainFrame"))
    local panels = { "home", "raid", "pug", "equipe", "bossq", "groups", "strats",
        "outils", "dash", "roster", "assign", "boss", "consomes", "invite",
        "whisperbot", "octofan" }
    for _, id in ipairs(panels) do
        local p = _G["RT3_Panel_" .. id]
        if p and p.IsShown and p:IsShown() then
            RT.Print(geo("RT3_Panel_" .. id))
        end
    end
    -- mes sous-cadres enregistrés au build
    for _, df in ipairs(RT4.diagFrames or {}) do
        RT.Print(geo(df))
    end
    -- tout enfant de UIParent suspect (grand cadre indépendant)
    local kids = { UIParent:GetChildren() }
    for i = 1, table.getn(kids) do
        local c = kids[i]
        if c.GetWidth and c:GetWidth() and c:GetWidth() > 500 and c:GetHeight() and c:GetHeight() > 250 then
            local nm = c.GetName and c:GetName() or "(anonyme #" .. i .. ")"
            if nm ~= "RT3_MainFrame" then
                RT.Print("SUSPECT UIParent: " .. geo(c))
            end
        end
    end
    RT.Print("|cff888888Fin du dump — envoie ces lignes.|r")
end

-- Enregistrement des cadres à diagnostiquer (appelé par les builds)
function RT4.Diag(frame, label)
    RT4.diagFrames = RT4.diagFrames or {}
    frame._diagLabel = label
    table.insert(RT4.diagFrames, frame)
end

-- ────────────────────────────────────────────────────────────
-- FIX monolithe : SetNormalFontObject n'existe PAS en 1.12 —
-- RT_NotesAddonSetMode (notes, boutons None/DBM/BigWigs) crashait.
-- Surcharge globale : même logique, texte coloré à la place.
-- ────────────────────────────────────────────────────────────
function RT_NotesAddonSetMode(mode)
    RT_DB = RT_DB or {}
    RT_DB.settings = RT_DB.settings or {}
    RT_DB.settings.notesBossAddon = mode
    local function setActive(name, active)
        local btn = getglobal(name)
        if not btn then return end
        local fs = btn.GetFontString and btn:GetFontString()
        if fs and fs.SetTextColor then
            if active then fs:SetTextColor(1, 0.82, 0.27)
            else fs:SetTextColor(0.5, 0.5, 0.5) end
        end
    end
    setActive("RT_NotesAddonBtnNone", mode == "none")
    setActive("RT_NotesAddonBtnDBM",  mode == "dbm")
    setActive("RT_NotesAddonBtnBW",   mode == "bigwigs")
    local st = getglobal("RT_NotesStatus")
    if st and RT_Text and RT_ColorGold then
        local modeTxt = RT_Text("notes_addon_none")
        if mode == "dbm" then modeTxt = RT_Text("notes_addon_dbm") end
        if mode == "bigwigs" then modeTxt = RT_Text("notes_addon_bigwigs") end
        st:SetText(RT_ColorGold(RT_Text("notes_addon_mode_set", { mode = modeTxt })))
    end
end

RT.Print("|cffAA66FFRaidTools v4|r: couche rôles active (auto + override dans l'accueil).")
