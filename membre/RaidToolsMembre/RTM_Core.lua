-- ============================================================
-- RaidTools Membre — RTM_Core.lua
--
-- Noyau minimal de la version MEMBRE : juste de quoi faire tourner la page Raid (schéma, assignations,
-- stratégie), le récap et l'overlay « Mon rôle ». Pas de bots, pas d'import, pas d'outils d'officier.
-- Il fournit la même interface (RT.Print, RT.Store, RT.UI...) que le RaidTools complet, pour que les modules
-- partagés (OctoFanBridge, RT_SchemaView) tournent à l'identique dans les deux versions.
--
-- Données : variable sauvegardée RTM_DB (distincte de RT_DB du RaidTools complet).
-- Si le RaidTools complet ("rt") est chargé, cette version se désactive : on ne mélange pas les deux.
-- Lua 5.0 strict.
-- ============================================================

RT_ADDON_DIR = "RaidToolsMembre"

if IsAddOnLoaded and IsAddOnLoaded("rt") then
    RTM_DISABLED = true
    local warn = CreateFrame("Frame")
    warn:RegisterEvent("PLAYER_LOGIN")
    warn:SetScript("OnEvent", function()
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffAA66FFRaidTools Membre|r : le RaidTools complet (dossier rt) est installé, la version Membre se désactive. " ..
                "Retire un des deux dossiers.")
        end
    end)
    return
end

RT = RT or {}
RT.version = "5.1-membre"
RT.isMember = true

function RT.Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffAA66FFRaidTools|r " .. tostring(msg))
    end
end

-- ---------- Minuteur ----------
local _timers, _timerSeq, _ticker = {}, 0, nil
local function _startTicker()
    if _ticker then return end
    _ticker = CreateFrame("Frame", "RTM_Ticker", UIParent)
    _ticker:SetScript("OnUpdate", function()
        local now = GetTime()
        local due
        for id, t in pairs(_timers) do
            if now >= t.at then
                due = due or {}
                table.insert(due, id)
            end
        end
        if not due then return end
        for i = 1, table.getn(due) do
            local t2 = _timers[due[i]]
            if t2 then
                if t2.interval then t2.at = now + t2.interval else _timers[due[i]] = nil end
                local ok, err = pcall(t2.fn)
                if not ok then RT.Print("|cffFF4444[timer] " .. tostring(err) .. "|r") end
            end
        end
    end)
end
function RT.After(seconds, fn)
    _startTicker()
    _timerSeq = _timerSeq + 1
    _timers[_timerSeq] = { at = GetTime() + (seconds or 0), fn = fn }
    return _timerSeq
end

-- ---------- Données ----------
RT.Store = RT.Store or {}
local _subs = {}
function RT.Store.Subscribe(topic, fn)
    _subs[topic] = _subs[topic] or {}
    table.insert(_subs[topic], fn)
end
function RT.Store.Notify(topic)
    local list = _subs[topic]
    if not list then return end
    for i = 1, table.getn(list) do
        local ok, err = pcall(list[i])
        if not ok then RT.Print("|cffFF4444[store:" .. tostring(topic) .. "] " .. tostring(err) .. "|r") end
    end
end
function RT.Store.DB()
    RTM_DB = RTM_DB or {}
    return RTM_DB
end
function RT.Store.Roster()
    local db = RT.Store.DB()
    db.roster = db.roster or {}
    return db.roster
end

-- ---------- Interface ----------
function RT_AttachSimpleTooltip(frame, text)
    if not frame or not text or text == "" then return end
    frame:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 0.85, 0.2, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

RT.UI = RT.UI or {}
local BACKDROP = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
function RT.UI.ApplyBackdrop(frame, r, g, b, a)
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(r or 0.05, g or 0.05, b or 0.08, a or 0.92)
    frame:SetBackdropBorderColor(0.62, 0.50, 0.18, 0.85)
end

local function applyAnchor(frame, anchor)
    if not anchor then return end
    frame:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4] or 0, anchor[5] or 0)
end

-- Remonte la chaîne de parents pour trouver le ScrollFrame et lui passer la molette
-- (les boutons bloquent la propagation de la molette en 1.12).
function RT3_FwdWheel(frame, delta)
    local p = frame:GetParent()
    while p do
        local ok, tp = pcall(p.GetObjectType, p)
        if ok and tp == "ScrollFrame" then
            local cur = p:GetVerticalScroll()
            local maxS = p:GetVerticalScrollRange()
            local new = cur - (delta or 0) * 24
            if new < 0 then new = 0 end
            if new > maxS then new = maxS end
            p:SetVerticalScroll(new)
            return
        end
        local ok2, par = pcall(p.GetParent, p)
        if not ok2 then return end
        p = par
    end
end

function RT.UI.Button(parent, opts)
    opts = opts or {}
    local b = CreateFrame("Button", opts.name, parent, "UIPanelButtonTemplate")
    b:SetWidth(opts.width or 100)
    b:SetHeight(opts.height or 22)
    b:SetText(opts.text or "")
    if opts.onClick then b:SetScript("OnClick", opts.onClick) end
    if opts.tooltip and RT_AttachSimpleTooltip then RT_AttachSimpleTooltip(b, opts.tooltip) end
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel", function() RT3_FwdWheel(this, arg1) end)
    applyAnchor(b, opts.anchor)
    return b
end

function RT.UI.ScrollArea(parent, opts)
    opts = opts or {}
    local scroll = CreateFrame("ScrollFrame", opts.name, parent, "UIPanelScrollFrameTemplate")
    applyAnchor(scroll, opts.anchor)
    if opts.width then scroll:SetWidth(opts.width) end
    if opts.height then scroll:SetHeight(opts.height) end
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(opts.childWidth or opts.width or 600)
    child:SetHeight(1)
    scroll:SetScrollChild(child)
    scroll.child = child
    local function doScroll(sf, delta)
        local cur = sf:GetVerticalScroll()
        local maxS = sf:GetVerticalScrollRange()
        local new = cur - (delta or 0) * 24
        if new < 0 then new = 0 end
        if new > maxS then new = maxS end
        sf:SetVerticalScroll(new)
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function() doScroll(this, arg1) end)
    child:EnableMouseWheel(true)
    child:SetScript("OnMouseWheel", function() doScroll(this:GetParent(), arg1) end)
    return scroll, child
end

function RT.UI.TextScroll(parent, opts)
    opts = opts or {}
    local w = opts.width or 600
    local scroll, child = RT.UI.ScrollArea(parent, { name = opts.name, anchor = opts.anchor, childWidth = w })
    if opts.width then scroll:SetWidth(w) end
    if opts.height then scroll:SetHeight(opts.height) end
    local fs = child:CreateFontString(opts.name and (opts.name .. "Text") or nil, "OVERLAY", opts.font or "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -4)
    fs:SetWidth(w - 24)
    fs:SetJustifyH("LEFT")
    fs:SetText("")
    local api = { scroll = scroll, child = child, fs = fs }
    function api:SetText(t)
        self.fs:SetText(t or "")
        self.child:SetHeight((self.fs:GetHeight() or 1) + 20)
        self.scroll:SetVerticalScroll(0)
        local f2, c2, s2 = self.fs, self.child, self.scroll
        RT.After(0, function()
            c2:SetHeight((f2:GetHeight() or 1) + 20)
            if s2.UpdateScrollChildRect then s2:UpdateScrollChildRect() end
        end)
    end
    return api
end

-- Pas d'onglets de modules dans la version Membre : les pages d'officier (import, assignation...) sont ignorées.
RT.Modules = RT.Modules or {}
function RT.Modules.Register() end
function RT.Modules.Show() if RTV and RTV.Open then RTV.Open() end end

RT4 = RT4 or {}
RT4.RaidRefresh = function() RT.Store.Notify("octofan") end
