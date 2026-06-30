-- RT v3 - UIKit.lua (racine)
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

-- Remonte la chaîne de parents pour trouver le ScrollFrame et forwarder la molette.
-- Utilisé par les boutons qui bloqueraient sinon la propagation en WoW 1.12.
function RT3_FwdWheel(frame, delta)
    local p = frame:GetParent()
    while p do
        local ok, tp = pcall(p.GetObjectType, p)
        if ok and tp == "ScrollFrame" then
            local cur  = p:GetVerticalScroll()
            local maxS = p:GetVerticalScrollRange()
            local new  = cur - (delta or 0) * 24
            if new < 0    then new = 0    end
            if new > maxS then new = maxS end
            p:SetVerticalScroll(new)
            return
        end
        local ok2, par = pcall(p.GetParent, p)
        if not ok2 then return end
        p = par
    end
end

function RT.UI.Label(parent, opts)
    opts = opts or {}
    local fs = parent:CreateFontString(opts.name, "OVERLAY", opts.font or "GameFontNormal")
    fs:SetText(opts.text or "")
    if opts.color   then fs:SetTextColor(opts.color[1], opts.color[2], opts.color[3]) end
    if opts.width   then fs:SetWidth(opts.width) end
    if opts.justify then fs:SetJustifyH(opts.justify) end
    applyAnchor(fs, opts.anchor)
    return fs
end

function RT.UI.Button(parent, opts)
    opts = opts or {}
    local b = CreateFrame("Button", opts.name, parent, "UIPanelButtonTemplate")
    b:SetWidth(opts.width or 100)
    b:SetHeight(opts.height or 22)
    b:SetText(opts.text or "")
    if opts.onClick then b:SetScript("OnClick", opts.onClick) end
    if opts.color then
        local tex = b:GetNormalTexture()
        if tex then tex:SetVertexColor(opts.color[1], opts.color[2], opts.color[3]) end
    end
    if opts.tooltip and RT_AttachSimpleTooltip then
        RT_AttachSimpleTooltip(b, opts.tooltip)
    end
    -- Forwarding molette : les boutons bloquent la propagation en WoW 1.12
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel", function() RT3_FwdWheel(this, arg1) end)
    applyAnchor(b, opts.anchor)
    return b
end

function RT.UI.Panel(parent, opts)
    opts = opts or {}
    local p = CreateFrame("Frame", opts.name, parent)
    applyAnchor(p, opts.anchor)
    if opts.width  then p:SetWidth(opts.width) end
    if opts.height then p:SetHeight(opts.height) end
    if opts.backdrop ~= false then
        RT.UI.ApplyBackdrop(p, opts.r, opts.g, opts.b, opts.a)
    end
    return p
end

function RT.UI.ScrollArea(parent, opts)
    opts = opts or {}
    local scroll = CreateFrame("ScrollFrame", opts.name, parent, "UIPanelScrollFrameTemplate")
    applyAnchor(scroll, opts.anchor)
    if opts.width  then scroll:SetWidth(opts.width) end
    if opts.height then scroll:SetHeight(opts.height) end
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(opts.childWidth or opts.width or 600)
    child:SetHeight(1)
    scroll:SetScrollChild(child)
    scroll.child = child

    local function doScroll(sf, delta)
        local cur  = sf:GetVerticalScroll()
        local maxS = sf:GetVerticalScrollRange()
        local new  = cur - (delta or 0) * 24
        if new < 0    then new = 0    end
        if new > maxS then new = maxS end
        sf:SetVerticalScroll(new)
    end

    -- Scroll frame reçoit la molette (hors contenu)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function() doScroll(this, arg1) end)

    -- Child forwarde aussi : les frames enfants avec EnableMouse bloquent
    -- la propagation de la molette vers le scroll parent en WoW 1.12.
    child:EnableMouseWheel(true)
    child:SetScript("OnMouseWheel", function() doScroll(this:GetParent(), arg1) end)

    return scroll, child
end

function RT.UI.TextScroll(parent, opts)
    opts = opts or {}
    local w = opts.width or 600
    local scroll, child = RT.UI.ScrollArea(parent, {
        name = opts.name, anchor = opts.anchor, childWidth = w,
    })
    if opts.width  then scroll:SetWidth(w) end
    if opts.height then scroll:SetHeight(opts.height) end
    local fs = child:CreateFontString(
        opts.name and (opts.name .. "Text") or nil,
        "OVERLAY", opts.font or "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -4)
    fs:SetWidth(w - 24)
    fs:SetJustifyH("LEFT")
    fs:SetText("")
    local api = { scroll = scroll, child = child, fs = fs }
    function api:SetText(t)
        self.fs:SetText(t or "")
        self.child:SetHeight((self.fs:GetHeight() or 1) + 20)
        local f2, c2 = self.fs, self.child
        RT.After(0, function() c2:SetHeight((f2:GetHeight() or 1) + 20) end)
    end
    return api
end

function RT.UI.List(parent, opts)
    opts = opts or {}
    local rowH    = opts.rowHeight or 18
    local gap     = opts.gap or 2
    local makeRow = opts.makeRow
    local fillRow = opts.fillRow
    local list = CreateFrame("Frame", opts.name, parent)
    list._pool = {}
    function list:SetItems(items)
        local n = table.getn(items)
        for i = 1, n do
            local row = self._pool[i]
            if not row then
                row = makeRow(self)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT",  self, "TOPLEFT",  0, -((i-1)*(rowH+gap)))
                row:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -((i-1)*(rowH+gap)))
                self._pool[i] = row
            end
            fillRow(row, items[i], i)
            row:Show()
        end
        for i = n + 1, table.getn(self._pool) do
            self._pool[i]:Hide()
        end
        self:SetHeight(n * (rowH + gap) + 4)
    end
    return list
end
