-- RT - Raid Tool | JSON Import Parser (RaidHelper + SoftRes)
-- Compatible Lua 5.0 (WoW 1.12)
-- ============================================================

-- string.match n'existe pas en Lua 5.0
local function strmatch(s, pattern)
    if not s then return nil end
    local _, _, cap = string.find(s, pattern)
    return cap
end

-- Classes Discord a ignorer (absent du raid)
local RT_SKIP_CLASS = {
    ["Absence"] = true,
    ["Late"]    = true,
}
-- Categories custom Discord (pas une vraie classe WoW)
local RT_CUSTOM_CLASS = {
    ["Tank"]      = true,
    ["Bench"]     = true,
    ["Tentative"] = true,
}

-- Extrait la valeur d'un champ "key":"value" dans un bloc JSON plat
local function RT_GetField(obj, key)
    -- Champ texte : "key":"valeur"
    local val = strmatch(obj, '"' .. key .. '":"([^"]*)"')
    if val then return val end
    -- Champ numerique : "key":123
    val = strmatch(obj, '"' .. key .. '":(%d+)')
    return val
end

-- Trouve le contenu entre le premier '[' apres arrayKey et son ']' correspondant
-- Retourne la sous-chaine (sans les crochets externes)
local function RT_FindArrayStr(jsonStr, arrayKey)
    local keyPos = string.find(jsonStr, '"' .. arrayKey .. '"', 1, true)
    if not keyPos then return nil end

    -- Chercher le '[' qui suit la cle
    local bracketPos = string.find(jsonStr, "[", keyPos, true)
    if not bracketPos then return nil end

    local depth = 1
    local i     = bracketPos + 1
    local len   = string.len(jsonStr)
    while i <= len and depth > 0 do
        local c = string.sub(jsonStr, i, i)
        if     c == "[" then depth = depth + 1
        elseif c == "]" then depth = depth - 1 end
        i = i + 1
    end

    if depth == 0 then
        -- retourne le contenu entre [ et ]
        return string.sub(jsonStr, bracketPos + 1, i - 2)
    end
    return nil
end

-- Extrait tous les objets {…} de premier niveau dans une chaine
-- (les objets imbriques sont inclus dans leur parent)
local function RT_ExtractObjects(str)
    local objects = {}
    local i   = 1
    local len = string.len(str)
    while i <= len do
        local startPos = string.find(str, "{", i, true)
        if not startPos then break end

        local depth = 1
        local j     = startPos + 1
        while j <= len and depth > 0 do
            local c = string.sub(str, j, j)
            if     c == "{" then depth = depth + 1
            elseif c == "}" then depth = depth - 1 end
            j = j + 1
        end

        if depth == 0 then
            table.insert(objects, string.sub(str, startPos, j - 1))
            i = j
        else
            break
        end
    end
    return objects
end

local function RT_SoftResNormalizeRole(role)
    if not role then return "?" end
    local r = string.lower(role)
    if string.find(r, "tank")   then return "Tank"   end
    if string.find(r, "heal")   then return "Heal"   end
    if string.find(r, "melee")  then return "Melee"  end
    if string.find(r, "ranged") then return "Ranged" end
    return "?"
end

local function RT_SoftResNormalizeClass(class)
    if not class then return "" end
    local classMap = {
        ["warrior"] = "Warrior", ["paladin"] = "Paladin",
        ["hunter"]  = "Hunter",  ["rogue"]   = "Rogue",
        ["priest"]  = "Priest",  ["shaman"]  = "Shaman",
        ["mage"]    = "Mage",    ["warlock"] = "Warlock",
        ["druid"]   = "Druid",
    }
    return classMap[string.lower(class)] or class
end

-- Nettoie un nom Discord vers nom WoW :
-- "Appolonios/Benelda" -> "Appolonios"
-- "!ZiggZagg!" -> "ZiggZagg"
-- "#Slimou#-Cornichonne" -> "Slimou"
-- "hélouna(wow),decimus(space)" -> "hélouna"  (accents préservés)
local function RT_CleanPlayerName(name)
    if not name or name == "" then return name end
    local part = strmatch(name, "^([^/|,%-]+)") or name   -- coupe à / | , -
    part = string.gsub(part, "%([^)]*%)", "")             -- retire les (...)
    part = string.gsub(part, "[!#%*%?%[%]\"']", "")       -- décorations Discord
    part = strmatch(part, "^%s*(.-)%s*$") or part         -- trim
    part = strmatch(part, "^(%S+)") or part               -- premier mot
    if part ~= "" then return part end
    return name
end

function RT_ImportSoftResJSON(jsonStr)
    if not jsonStr or jsonStr == "" then
        return false, "JSON vide"
    end

    -- Nettoyer sauts de ligne
    jsonStr = string.gsub(jsonStr, "\r\n", " ")
    jsonStr = string.gsub(jsonStr, "\r",   " ")
    jsonStr = string.gsub(jsonStr, "\n",   " ")
    jsonStr = string.gsub(jsonStr, "\t",   " ")

    -- Extraire les metadonnees globales
    local date  = RT_GetField(jsonStr, "date")
    local title = RT_GetField(jsonStr, "displayTitle")
                  or RT_GetField(jsonStr, "title")

    local isRaidHelper = string.find(jsonStr, '"cClassName"', 1, true) ~= nil

    -- Localiser et extraire le contenu du tableau signUps
    local signUpsStr = RT_FindArrayStr(jsonStr, "signUps")
    if not signUpsStr or string.len(signUpsStr) < 5 then
        return false, "Tableau signUps introuvable"
    end

    -- Extraire les objets individuels du tableau signUps
    local rawObjects = RT_ExtractObjects(signUpsStr)
    if table.getn(rawObjects) == 0 then
        return false, "Aucun objet dans signUps"
    end

    RT_DB         = RT_DB         or {}
    RT_DB.roster  = RT_DB.roster  or {}
    RT_DB.signUps = RT_DB.signUps or {}

    RT_DB.signUps.date       = date  or ""
    RT_DB.signUps.title      = title or "Import"
    RT_DB.signUps.raidHelper = isRaidHelper

    local imported = 0
    local skipped  = 0

    for idx = 1, table.getn(rawObjects) do
        local obj      = rawObjects[idx]
        local name     = RT_GetField(obj, "name")
        local rawClass = RT_GetField(obj, "cClassName") or RT_GetField(obj, "className") or ""

        if not name or name == "" then
            skipped = skipped + 1
        elseif RT_SKIP_CLASS[rawClass] then
            skipped = skipped + 1
        else
            local playerName = RT_CleanPlayerName(name)
            if not playerName or playerName == "" then
                playerName = name
            end

            local roleStr = RT_GetField(obj, "cRoleName") or RT_GetField(obj, "roleName") or ""
            local role    = RT_SoftResNormalizeRole(roleStr)

            local class
            if RT_CUSTOM_CLASS[rawClass] then
                class = ""
                if rawClass == "Tank" then role = "Tank" end
            else
                class = RT_SoftResNormalizeClass(rawClass)
            end

            local spec = RT_GetField(obj, "specName") or RT_GetField(obj, "cSpecName") or ""
            local note = RT_GetField(obj, "note") or ""

            RT_DB.roster[playerName] = {
                class  = class,
                spec   = spec,
                role   = role,
                sr     = 0,
                status = RT_GetField(obj, "status") or "primary",
                note   = note,
            }
            imported = imported + 1
        end
    end

    -- Auto-complétion : classe déduite de la spé (Holy1=Paladin...),
    -- spé normalisée, rôle affiné Melee/Ranged.
    local fixedCls = 0
    if RT3_AutofixRoster then fixedCls = RT3_AutofixRoster() end

    local msg = "Imported " .. imported .. " player(s)"
    if skipped > 0 then
        msg = msg .. " (" .. skipped .. " skipped)"
    end
    if fixedCls > 0 then
        msg = msg .. ", " .. fixedCls .. " class(es) auto-detected from spec"
    end
    if isRaidHelper then
        msg = msg .. " [RaidHelper]"
    end
    return true, msg
end

-- ============================================================
-- Import Raid-Helper "Composition Tool"
-- Format : {"slots":[{ name, className, specName, groupNumber,
-- slotNumber, ... }], "groupCount":8, ...}
-- Remplit le roster (classe/spé/rôle) ET les groupes du preset
-- actif de l'onglet Groups (positions déjà décidées dans l'outil).
-- ============================================================
function RT_ImportRaidHelperComp(jsonStr)
    if not jsonStr or jsonStr == "" then
        return false, "Empty paste"
    end
    jsonStr = string.gsub(jsonStr, "\r\n", " ")
    jsonStr = string.gsub(jsonStr, "\r",   " ")
    jsonStr = string.gsub(jsonStr, "\n",   " ")
    jsonStr = string.gsub(jsonStr, "\t",   " ")

    local slotsStr = RT_FindArrayStr(jsonStr, "slots")
    if not slotsStr or string.len(slotsStr) < 5 then
        return false, "No 'slots' array found — is this a Comp Tool export?"
    end
    local rawObjects = RT_ExtractObjects(slotsStr)
    if table.getn(rawObjects) == 0 then
        return false, "No players in 'slots'"
    end

    RT_DB        = RT_DB        or {}
    RT_DB.roster = RT_DB.roster or {}

    -- Préset actif de l'onglet Groups : on le remplace par la compo importée
    RT_DB.v3grppresets = RT_DB.v3grppresets or { active = 1, presets = {} }
    local pd  = RT_DB.v3grppresets
    local act = pd.active or 1
    local gs  = {}
    for g = 1, 8 do gs[g] = { names = {}, role = 1 } end
    pd.presets[act] = pd.presets[act] or { name = "Preset " .. act }
    pd.presets[act].groups = gs

    local imported, grouped, skipped = 0, 0, 0
    for idx = 1, table.getn(rawObjects) do
        local obj  = rawObjects[idx]
        local name = RT_GetField(obj, "name")
        local rawClass = RT_GetField(obj, "className") or ""
        if not name or name == "" or RT_SKIP_CLASS[rawClass] then
            skipped = skipped + 1
        else
            local playerName = RT_CleanPlayerName(name)
            if not playerName or playerName == "" then playerName = name end

            local class, role = "", ""
            if RT_CUSTOM_CLASS[rawClass] then
                if rawClass == "Tank" then role = "Tank" end
            else
                class = RT_SoftResNormalizeClass(rawClass)
            end
            local spec = RT_GetField(obj, "specName") or ""

            local existing = RT_DB.roster[playerName] or {}
            if class ~= "" then existing.class = class end
            if spec  ~= "" then existing.spec  = spec  end
            if role  ~= "" then existing.role  = role  end
            existing.sr     = existing.sr or 0
            existing.status = existing.status or "primary"
            RT_DB.roster[playerName] = existing
            imported = imported + 1

            -- Placement de groupe pré-décidé dans l'outil
            local g = tonumber(RT_GetField(obj, "groupNumber") or "")
            local s = tonumber(RT_GetField(obj, "slotNumber") or "")
            if g and g >= 1 and g <= 8 then
                if not (s and s >= 1 and s <= 5) then
                    -- pas de slot valide : premier emplacement libre
                    s = nil
                    for k = 1, 5 do
                        if not gs[g].names[k] or gs[g].names[k] == "" then s = k; break end
                    end
                end
                if s then
                    gs[g].names[s] = playerName
                    grouped = grouped + 1
                end
            end
        end
    end

    local fixedCls = 0
    if RT3_AutofixRoster then fixedCls = RT3_AutofixRoster() end

    local msg = "Comp Tool: " .. imported .. " player(s), " .. grouped
              .. " placed into groups (preset " .. act .. ")"
    if fixedCls > 0 then msg = msg .. ", " .. fixedCls .. " class(es) auto-detected" end
    if skipped  > 0 then msg = msg .. ", " .. skipped .. " skipped" end
    return true, msg
end
