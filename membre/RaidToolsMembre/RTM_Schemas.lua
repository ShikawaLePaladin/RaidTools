-- RaidTools Membre — lecture des schémas OS1 (extrait de RT4_GuildPage.lua par build.js)
if RTM_DISABLED then return end

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


RT4 = RT4 or {}
RT4.ParseSchemas = ParseSchemas
