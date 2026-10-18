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

-- Détecte le rôle probable à partir de la classe et de la spé
function RT3_RoleFromSpec(cls, spec)
    local c = string.upper(cls  or "")
    local s = string.lower(spec or "")

    -- Tanks
    if c == "WARRIOR" and string.find(s, "prot") then return "Tank" end
    if c == "PALADIN" and string.find(s, "prot") then return "Tank" end
    if c == "DRUID"   and string.find(s, "feral") and string.find(s, "tank") then return "Tank" end

    -- Heals
    if c == "PRIEST"  and (string.find(s, "holy") or string.find(s, "disc")) then return "Heal" end
    if c == "PALADIN" and string.find(s, "holy")  then return "Heal" end
    if c == "DRUID"   and string.find(s, "resto") then return "Heal" end
    if c == "SHAMAN"  and string.find(s, "resto") then return "Heal" end

    -- Ranged
    if c == "HUNTER"  then return "Ranged" end
    if c == "MAGE"    then return "Ranged" end
    if c == "WARLOCK" then return "Ranged" end
    if c == "PRIEST"  and string.find(s, "shadow") then return "Ranged" end
    if c == "DRUID"   and string.find(s, "balance") then return "Ranged" end
    if c == "SHAMAN"  and string.find(s, "ele")    then return "Ranged" end

    -- Melee
    if c == "WARRIOR" then return "Melee" end
    if c == "ROGUE"   then return "Melee" end
    if c == "PALADIN" and string.find(s, "retri") then return "Melee" end
    if c == "DRUID"   and string.find(s, "feral") then return "Melee" end
    if c == "SHAMAN"  and string.find(s, "enh")   then return "Melee" end

    return nil  -- spé inconnue ou absente
end

-- ============================================================
-- Déduction classe + spé canonique depuis un libellé de spé
-- (imports Raid-Helper / softres / CSV, texte libre FR/EN).
-- Raid-Helper suffixe "1" les doublons : Holy1/Protection1 =
-- Paladin, Restoration1 = Shaman (Holy = Priest, Protection =
-- Warrior, Restoration = Druid).
-- Ordre = du plus spécifique au plus générique (match substring).
-- ============================================================
RT3_SPEC_INFO = {
    -- Raid-Helper désambiguïsés (à tester AVANT la forme nue)
    { "protection1",  "Prot",       "PALADIN" },
    { "holy1",        "Holy",       "PALADIN" },
    { "restoration1", "Resto",      "SHAMAN"  },
    -- Druid
    { "guardian",     "Feral Tank", "DRUID"   },
    { "feral",        "Feral",      "DRUID"   },
    { "farouche",     "Feral",      "DRUID"   },
    { "balance",      "Balance",    "DRUID"   },
    { "equilibre",    "Balance",    "DRUID"   },
    { "boomkin",      "Balance",    "DRUID"   },
    -- Hunter
    { "beastmaster",  "BM",         "HUNTER"  },
    { "beast",        "BM",         "HUNTER"  },
    { "marksman",     "MM",         "HUNTER"  },
    { "precision",    "MM",         "HUNTER"  },
    { "survival",     "Surv",       "HUNTER"  },
    { "survie",       "Surv",       "HUNTER"  },
    -- Mage
    { "arcane",       "Arcane",     "MAGE"    },
    { "fire",         "Fire",       "MAGE"    },
    { "frost",        "Frost",      "MAGE"    },
    { "givre",        "Frost",      "MAGE"    },
    -- Paladin
    { "retribution",  "Retri",      "PALADIN" },
    { "vindicte",     "Retri",      "PALADIN" },
    { "retri",        "Retri",      "PALADIN" },
    -- Priest
    { "discipline",   "Disc",       "PRIEST"  },
    { "disc",         "Disc",       "PRIEST"  },
    { "shadow",       "Shadow",     "PRIEST"  },
    { "ombre",        "Shadow",     "PRIEST"  },
    { "smite",        "Disc",       "PRIEST"  },
    -- Rogue
    { "assassination","Assa",       "ROGUE"   },
    { "combat",       "Combat",     "ROGUE"   },
    { "subtlety",     "Subt",       "ROGUE"   },
    { "finesse",      "Subt",       "ROGUE"   },
    -- Shaman
    { "elemental",    "Elem",       "SHAMAN"  },
    { "elementaire",  "Elem",       "SHAMAN"  },
    { "enhancement",  "Enh",        "SHAMAN"  },
    { "amelioration", "Enh",        "SHAMAN"  },
    { "enh",          "Enh",        "SHAMAN"  },
    -- Warlock
    { "affliction",   "Affli",      "WARLOCK" },
    { "demonology",   "Demo",       "WARLOCK" },
    { "demonologie",  "Demo",       "WARLOCK" },
    { "destruction",  "Destro",     "WARLOCK" },
    { "destro",       "Destro",     "WARLOCK" },
    -- Warrior
    { "arms",         "Arms",       "WARRIOR" },
    { "armes",        "Arms",       "WARRIOR" },
    { "fury",         "Fury",       "WARRIOR" },
    { "furie",        "Fury",       "WARRIOR" },
    -- Formes nues (Raid-Helper : classe "premier arrivé")
    { "protection",   "Prot",       "WARRIOR" },
    { "restoration",  "Resto",      "DRUID"   },
    { "holy",         "Holy",       "PRIEST"  },
    { "sacre",        "Holy",       nil       },
    -- Abréviations ambiguës : spé canonique connue, classe indéterminée
    { "resto",        "Resto",      nil       },
    { "prot",         "Prot",       nil       },
}

-- Retourne (specCanonique, classeEN|nil) depuis un libellé libre.
function RT3_SpecInfo(spec)
    if not spec or spec == "" then return nil, nil end
    local s = string.lower(spec)
    for i = 1, table.getn(RT3_SPEC_INFO) do
        local e = RT3_SPEC_INFO[i]
        if string.find(s, e[1], 1, true) then return e[2], e[3] end
    end
    return nil, nil
end

-- Complète automatiquement le roster : classe manquante déduite de la
-- spé, spé normalisée ("Protection1" → "Prot"), rôle affiné (vide/?/DPS
-- → Tank/Heal/Melee/Ranged). Ne touche jamais un Tank/Heal déjà défini.
-- Retourne (classesFixées, rôlesFixés).
function RT3_AutofixRoster()
    local db = RT_DB and RT_DB.roster
    if not db then return 0, 0 end
    local nCls, nRole = 0, 0
    for _, d in pairs(db) do
        local canon, cls = RT3_SpecInfo(d.spec)
        if canon and d.spec ~= canon then d.spec = canon end
        if cls and (not d.class or d.class == "") then
            d.class = RT.NormClass and RT.NormClass(cls) or cls
            nCls = nCls + 1
        end
        local cur = d.role or ""
        if cur == "" or cur == "?" or cur == "DPS" then
            local r = RT3_RoleFromSpec(d.class or "", d.spec or "")
            if r and r ~= cur then
                d.role = r
                nRole = nRole + 1
            end
        end
    end
    return nCls, nRole
end

-- ============================================================
-- Détection de spé via talents + échange entre joueurs
-- ============================================================
-- Ordre RÉEL des onglets de talents en 1.12 (indépendant de la langue).
-- L'index renvoyé par GetTalentTabInfo correspond à cette table.
RT3_TALENT_SPECS = {
    WARRIOR = { "Arms",  "Fury",  "Prot"  },
    PALADIN = { "Holy",  "Prot",  "Retri" },
    HUNTER  = { "BM",    "MM",    "Surv"  },
    ROGUE   = { "Assa",  "Combat","Subt"  },
    PRIEST  = { "Disc",  "Holy",  "Shadow"},
    SHAMAN  = { "Elem",  "Enh",   "Resto" },
    MAGE    = { "Arcane","Fire",  "Frost" },
    WARLOCK = { "Affli", "Demo",  "Destro"},
    DRUID   = { "Balance","Feral","Resto" },
}

-- Lit les talents du joueur LOCAL → renvoie classeEN, spec, points.
-- (En 1.12 on ne peut lire que SES propres talents, pas ceux des autres.)
function RT3_DetectMySpec()
    if not GetNumTalentTabs or not GetTalentTabInfo then return nil end
    local nTabs = GetNumTalentTabs()
    if not nTabs or nTabs < 1 then return nil end
    local best, bestPts = 0, -1
    for t = 1, nTabs do
        local _, _, pts = GetTalentTabInfo(t)
        pts = pts or 0
        if pts > bestPts then bestPts = pts; best = t end
    end
    if best < 1 or bestPts <= 0 then return nil end  -- pas de talents → on ne devine pas
    local _, enCls = UnitClass("player")
    enCls = string.upper(enCls or "")
    local map  = RT3_TALENT_SPECS[enCls]
    local spec = map and map[best] or nil
    return enCls, spec, bestPts
end

-- Écrit la spé d'un joueur dans le roster et recalcule son rôle.
-- class peut être nil → on garde la classe déjà connue.
function RT3_SetPlayerSpec(name, class, spec)
    if not name or name == "" then return false end
    local db = RT.Store.Roster()
    db[name] = db[name] or {}
    if class and class ~= "" then
        local nc = RT.NormClass(class)
        if nc ~= "" then db[name].class = nc end
    end
    if spec and spec ~= "" then
        db[name].spec = spec
        if RT3_RoleFromSpec then
            local role = RT3_RoleFromSpec(db[name].class or class or "", spec)
            if role then db[name].role = role end
        end
    end
    RT.Store.Notify("roster")
    return true
end

-- Diffuse une demande de spé à tout le raid (les joueurs qui ont RT
-- répondent automatiquement et silencieusement via addon).
function RT3_RequestSpecsAddon()
    -- enregistre la sienne tout de suite
    local cls, spec = RT3_DetectMySpec()
    local me = UnitName and UnitName("player") or ""
    if spec and me ~= "" then RT3_SetPlayerSpec(me, cls, spec) end
    if RT_Sync_Send then RT_Sync_Send("SPECREQ") end
end

-- Handlers addon-to-addon (Sync.lua est chargé avant ce bloc).
if RT_Sync_Register then
    -- Quelqu'un demande les spés → on répond avec la nôtre (ciblé).
    RT_Sync_Register("SPECREQ", function(sender)
        local cls, spec = RT3_DetectMySpec()
        local me = UnitName and UnitName("player") or ""
        if spec and me ~= "" and RT_Sync_Whisper then
            RT_Sync_Whisper(sender, "SPEC", me, cls or "", spec)
        end
    end)
    -- On reçoit la spé d'un joueur → on l'enregistre.
    RT_Sync_Register("SPEC", function(sender, pname, pclass, pspec)
        if pname and pname ~= "" and pspec and pspec ~= "" then
            RT3_SetPlayerSpec(pname, pclass, pspec)
        end
    end)
end

RT_V3_COMPAT_LOADED = true
