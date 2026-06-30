-- RT v3 - Store.lua (racine)
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
    RT_DB = RT_DB or {}
    return RT_DB
end

function RT.Store.Roster()
    local db = RT.Store.DB()
    db.roster = db.roster or {}
    return db.roster
end

function RT.Store.Loot()
    local db = RT.Store.DB()
    db.loot = db.loot or {}
    return db.loot
end

function RT.Store.Attendance()
    local db = RT.Store.DB()
    db.attendance = db.attendance or {}
    return db.attendance
end
