if RTM_DISABLED then return end
-- ============================================================
-- RaidTools Membre — RTM_Overlays.lua
--
-- DEUX OVERLAYS, AU CHOIX DU JOUEUR (un seul affiché à la fois) :
--   « recap »  : mon récap — qui je suis (nom, rôle du plan), le boss courant, MES postes et tâches.
--                (pas de groupe : la version Membre n'en parle pas)
--   « role »   : « Mon rôle » — une pastille compacte : mon poste en gros, ma tâche dessous.
--                (pas de stratégie : elle est dans la fenêtre Raid)
-- Les deux se déplacent à la souris (position mémorisée) et restent lisibles en combat.
-- Boss courant : le boss ciblé s'il est dans le plan (RT.OctoFan.CurrentBoss).
-- Lua 5.0 strict.
-- ============================================================

RTM = RTM or {}
local M = RTM

local ROLE_FR = { tank = "Tank", heal = "Heal", melee = "Mêlée", ranged = "Dist" }
local ROLE_COLOR = {
    tank   = { 0.45, 0.65, 1.00 },
    heal   = { 0.35, 0.90, 0.45 },
    melee  = { 1.00, 0.55, 0.35 },
    ranged = { 0.75, 0.55, 1.00 },
}
local CLASS_COLORS = {
    WARRIOR = { 0.78, 0.61, 0.43 }, PRIEST = { 1.00, 1.00, 1.00 }, MAGE = { 0.41, 0.80, 0.94 },
    WARLOCK = { 0.58, 0.51, 0.79 }, DRUID = { 1.00, 0.49, 0.04 }, PALADIN = { 0.96, 0.55, 0.73 },
    ROGUE = { 1.00, 0.96, 0.41 }, HUNTER = { 0.67, 0.83, 0.45 }, SHAMAN = { 0.00, 0.44, 0.87 },
}
local FONT = "Fonts\\FRIZQT__.TTF"
local SQUARE = "Interface\\Buttons\\WHITE8X8"

local function State()
    local db = RT.Store.DB()
    db.rtm = db.rtm or {}
    return db.rtm
end

function M.GetOverlay()
    local m = State().overlay
    if m == "recap" or m == "role" or m == "none" then return m end
    return "recap"
end

-- ---------- données ----------

local function HasName(list, me)
    if RT.OctoFan and RT.OctoFan.HasName then return RT.OctoFan.HasName(list, me) end
    return false
end

local function CurrentBoss()
    if RT.OctoFan and RT.OctoFan.CurrentBoss then return RT.OctoFan.CurrentBoss() end
    return nil
end

-- mes postes : sur le boss donné, sinon sur tout le plan
local function MyPosts(plan, me, boss)
    local out = {}
    if not (plan and plan.assign) then return out end
    if boss then
        for poste, slot in pairs(plan.assign[boss] or {}) do
            if HasName(slot.player, me) then table.insert(out, { boss = boss, poste = poste, task = slot.task or "" }) end
        end
    else
        for _, b in ipairs(plan.bossOrder or {}) do
            for poste, slot in pairs(plan.assign[b] or {}) do
                if HasName(slot.player, me) then table.insert(out, { boss = b, poste = poste, task = slot.task or "" }) end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.boss ~= b.boss then return a.boss < b.boss end
        return a.poste < b.poste
    end)
    return out
end

local function RoleOfPoste(poste)
    local _, _, w = string.find(poste or "", "^(%a+)")
    if w == "Tank" then return "tank" end
    if w == "Heal" then return "heal" end
    if w == "CaC" then return "melee" end
    return "ranged"
end

local function Hex(c)
    return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
end

local function Trunc(s, n)
    s = s or ""
    if string.len(s) > n then return string.sub(s, 1, n - 2) .. ".." end
    return s
end

-- ---------- cadre déplaçable ----------

local function MakeFrame(name, w, h, posKey, defPoint)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetWidth(w)
    f:SetHeight(h)
    local st = State()
    local pos = st[posKey]
    if pos and pos.x and pos.y then
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        f:SetPoint(defPoint[1], UIParent, defPoint[2], defPoint[3], defPoint[4])
    end
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local l, b = f:GetLeft(), f:GetBottom()
        if l and b then State()[posKey] = { x = l, y = b } end
    end)
    f:SetFrameStrata("LOW")
    f:SetBackdrop({
        bgFile = SQUARE, edgeFile = SQUARE, tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.02, 0.02, 0.05, 0.62)
    f:SetBackdropBorderColor(0.35, 0.28, 0.16, 0.55)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetWidth(16)
    close:SetHeight(16)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    close:SetScript("OnClick", function() M.SetOverlay("none") end)
    f:Hide()
    return f
end

-- ============================================================
-- Overlay 1 : mon RÉCAP
-- ============================================================

local recap = nil
local function BuildRecap()
    if recap then return end
    recap = MakeFrame("RTM_Recap", 252, 80, "recapPos", { "RIGHT", "RIGHT", -10, 60 })
    recap.hdr = recap:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    recap.hdr:SetPoint("TOPLEFT", recap, "TOPLEFT", 7, -5)
    recap.hdr:SetJustifyH("LEFT")
    recap.hdr:SetWidth(222)
    recap.boss = recap:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recap.boss:SetPoint("TOPLEFT", recap, "TOPLEFT", 7, -22)
    recap.boss:SetJustifyH("LEFT")
    recap.boss:SetWidth(238)
    recap.posts = recap:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    recap.posts:SetPoint("TOPLEFT", recap, "TOPLEFT", 7, -37)
    recap.posts:SetJustifyH("LEFT")
    recap.posts:SetWidth(238)
end

local function RefreshRecap()
    BuildRecap()
    local me = UnitName("player") or "?"
    local plan = RT.Store.DB().octofan
    local boss = CurrentBoss()
    local _, cls = UnitClass("player")
    local col = CLASS_COLORS[cls or ""] or { 1, 0.82, 0.27 }
    local info = {}
    local ri = plan and plan.roster and plan.roster[me]
    if ri and ri.role and ROLE_FR[ri.role] then table.insert(info, ROLE_FR[ri.role]) end
    if ri and ri.spec and ri.spec ~= "" then table.insert(info, ri.spec) end
    recap.hdr:SetText(Hex(col) .. me .. "|r" .. (table.getn(info) > 0 and ("  |cff999999" .. table.concat(info, " · ") .. "|r") or ""))
    recap.boss:SetText(boss and ("|cffFFCC44" .. boss .. "|r") or "|cff666666aucun boss (cible un boss)|r")
    local posts = MyPosts(plan, me, boss)
    local lines = {}
    for i = 1, table.getn(posts) do
        if i > 6 then break end
        local p = posts[i]
        if boss then
            table.insert(lines, "|cff66CCFF" .. p.poste .. "|r" .. ((p.task ~= "") and (" — " .. p.task) or ""))
        else
            table.insert(lines, "|cffFFCC44" .. p.boss .. "|r : |cff66CCFF" .. p.poste .. "|r")
        end
    end
    if table.getn(lines) == 0 then
        if not plan then lines[1] = "|cff666666pas de plan reçu|r"
        elseif boss then lines[1] = "|cff888888rien pour toi sur ce boss|r"
        else lines[1] = "|cff888888aucune assignation|r" end
    end
    recap.posts:SetText(table.concat(lines, "\n"))
    local h = recap.posts:GetHeight()
    if type(h) ~= "number" or h < 12 then h = 12 end
    recap:SetHeight(37 + h + 8)
end

-- ============================================================
-- Overlay 2 : MON RÔLE (pastille compacte)
-- ============================================================

local role = nil
local function BuildRole()
    if role then return end
    role = MakeFrame("RTM_Role", 216, 62, "rolePos", { "RIGHT", "RIGHT", -10, -20 })
    role.big = role:CreateFontString(nil, "OVERLAY")
    role.big:SetFont(FONT, 20, "OUTLINE")
    role.big:SetPoint("TOPLEFT", role, "TOPLEFT", 9, -6)
    role.big:SetJustifyH("LEFT")
    role.big:SetWidth(176)
    role.task = role:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    role.task:SetPoint("TOPLEFT", role, "TOPLEFT", 9, -30)
    role.task:SetJustifyH("LEFT")
    role.task:SetWidth(198)
    role.foot = role:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    role.foot:SetPoint("TOPLEFT", role, "TOPLEFT", 9, -46)
    role.foot:SetJustifyH("LEFT")
    role.foot:SetWidth(198)
end

local function RefreshRole()
    BuildRole()
    local me = UnitName("player") or "?"
    local plan = RT.Store.DB().octofan
    local boss = CurrentBoss()
    local posts = MyPosts(plan, me, boss)
    if table.getn(posts) > 0 then
        local p = posts[1]
        local c = ROLE_COLOR[RoleOfPoste(p.poste)]
        role.big:SetText(string.upper(p.poste) .. ((table.getn(posts) > 1) and ("  +" .. (table.getn(posts) - 1)) or ""))
        role.big:SetTextColor(c[1], c[2], c[3])
        role.task:SetText(Trunc(p.task, 44))
        role.foot:SetText("|cff888888" .. (boss or p.boss) .. "|r")
    else
        local ri = plan and plan.roster and plan.roster[me]
        if ri and ri.role and ROLE_FR[ri.role] then
            local c = ROLE_COLOR[ri.role]
            role.big:SetText(string.upper(ROLE_FR[ri.role]))
            role.big:SetTextColor(c[1], c[2], c[3])
        else
            role.big:SetText("—")
            role.big:SetTextColor(0.6, 0.6, 0.6)
        end
        role.task:SetText(plan and (boss and "rien pour toi sur ce boss" or "cible un boss") or "pas de plan reçu")
        role.task:SetTextColor(0.6, 0.6, 0.65)
        role.foot:SetText(boss and ("|cff888888" .. boss .. "|r") or "")
    end
    if table.getn(posts) > 0 then role.task:SetTextColor(0.87, 0.87, 0.87) end
end

-- ============================================================
-- Choix de l'overlay
-- ============================================================

function M.RefreshOverlays()
    local m = M.GetOverlay()
    if m == "recap" and recap and recap:IsShown() then RefreshRecap() end
    if m == "role" and role and role:IsShown() then RefreshRole() end
end

function M.SetOverlay(mode)
    if mode ~= "recap" and mode ~= "role" then mode = "none" end
    State().overlay = mode
    if mode == "recap" then
        BuildRecap()
        RefreshRecap()
        recap:Show()
    elseif recap then
        recap:Hide()
    end
    if mode == "role" then
        BuildRole()
        RefreshRole()
        role:Show()
    elseif role then
        role:Hide()
    end
end

-- clic sur le même overlay : on le coupe
function M.ToggleOverlay(mode)
    if M.GetOverlay() == mode then M.SetOverlay("none") else M.SetOverlay(mode) end
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + arg1
    if this.t < 1 then return end
    this.t = 0
    M.RefreshOverlays()
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        M.SetOverlay(M.GetOverlay())
    else
        M.RefreshOverlays()
    end
end)

if RT.Store and RT.Store.Subscribe then
    RT.Store.Subscribe("octofan", function() M.RefreshOverlays() end)
end
