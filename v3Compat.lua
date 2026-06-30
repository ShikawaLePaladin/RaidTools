-- RT v3 - Compat.lua (chargement depuis la racine)
SLASH_RT3COMPAT_1 = "/rt3compat"
SlashCmdList["RT3COMPAT"] = function()
    DEFAULT_CHAT_FRAME:AddMessage("v3Compat.lua CHARGE OK")
end

RT = RT or {}
RT.version = "3.0-dev"

function RT.Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffAA66FF[RT3]|r " .. tostring(msg))
    end
end

function RT.Pack(...)
    local t = {}
    local n = arg.n or table.getn(arg)
    for i = 1, n do t[i] = arg[i] end
    t.n = n
    return t
end

function RT.Match(s, pattern)
    if not s then return nil end
    local a, b, c1, c2, c3 = string.find(s, pattern)
    if a == nil then return nil end
    if c1 ~= nil then return c1, c2, c3 end
    return string.sub(s, a, b)
end

RT.getn = table.getn
RT.mod  = math.mod

function RT.OnEvent(frame, handler)
    frame:SetScript("OnEvent", function()
        handler(event, arg1, arg2, arg3, arg4, arg5)
    end)
end

function RT.Events(eventList, handler)
    local f = CreateFrame("Frame")
    for i = 1, table.getn(eventList) do
        f:RegisterEvent(eventList[i])
    end
    RT.OnEvent(f, handler)
    return f
end

local _timers   = {}
local _timerSeq = 0
local _ticker   = nil

local function _startTicker()
    if _ticker then return end
    _ticker = CreateFrame("Frame", "RT_Ticker", UIParent)
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
            local id2 = due[i]
            local t2  = _timers[id2]
            if t2 then
                if t2.interval then
                    t2.at = now + t2.interval
                else
                    _timers[id2] = nil
                end
                local ok, err = pcall(t2.fn)
                if not ok then RT.Print("|cffFF4444[timer] " .. tostring(err) .. "|r") end
            end
        end
    end)
end

function RT.After(seconds, fn)
    _startTicker()
    _timerSeq = _timerSeq + 1
    local id = _timerSeq
    _timers[id] = { at = GetTime() + (seconds or 0), fn = fn }
    return id
end

function RT.Every(seconds, fn)
    _startTicker()
    _timerSeq = _timerSeq + 1
    local id = _timerSeq
    _timers[id] = { at = GetTime() + (seconds or 0), fn = fn, interval = seconds }
    return id
end

function RT.Cancel(id)
    if id then _timers[id] = nil end
end

function RT.ClassColor(class)
    local c = RT_CLASS_COLORS and RT_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.80, 0.80, 0.80
end

function RT.RoleColor(role)
    if role == "Melee"  then return 1.00, 0.55, 0.00 end
    if role == "Ranged" then return 0.20, 0.85, 1.00 end
    local c = RT_ROLE_COLORS and RT_ROLE_COLORS[role]
    if c then return c.r, c.g, c.b end
    return 0.60, 0.60, 0.60
end

function RT.NormClass(class)
    if RT_NormalizeClassName then return RT_NormalizeClassName(class or "") end
    return class or ""
end

function RT.NormRole(role)
    if RT_NormalizeRole then return RT_NormalizeRole(role or "") end
    return role or ""
end

RT_V3_COMPAT_LOADED = true
