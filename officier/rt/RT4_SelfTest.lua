-- ============================================================
-- RT v5 — RT4_SelfTest.lua
--
-- /rtselftest : vérifie EN JEU, sans rien modifier, que les maillons clés
-- répondent (codage du relais, lecture/écriture d'un plan, taille des
-- messages, schémas, droits, bots, modules). Affiche OK / ÉCHEC par ligne.
-- Lua 5.0 strict. Chargé en dernier (après OctoFanBridge.lua).
-- ============================================================

local function Say(ok, label, detail)
    local tag = ok and "|cff44ff44OK|r    " or "|cffff4444ÉCHEC|r "
    local d = ""
    if detail and detail ~= "" then d = " |cff999999(" .. detail .. ")|r" end
    RT.Print(tag .. label .. d)
end

local function RunSelfTest()
    local pass, fail = 0, 0
    local function T(ok, label, detail)
        if ok then pass = pass + 1 else fail = fail + 1 end
        Say(ok, label, detail)
    end
    RT.Print("|cffFFD700=== RaidTools : auto-test ===|r")

    local OF = RT.OctoFan
    T(OF ~= nil, "module OctoFan chargé")
    if not OF then return end

    -- 1. codec du relais : | ; accents et lettres rares doivent revenir à l'identique
    local sample = "OFP1|Plan test|Molten Core|2026-10-09;R|tank|Nom|PALADIN|Prot|2;A|Lucifron|Tank 1|Nom|MT : très bien;END"
    local enc = OF._HexEnc and OF._HexEnc(sample)
    local dec = enc and OF._HexDec and OF._HexDec(enc)
    T(dec == sample, "relais : codage aller-retour des caractères spéciaux")

    -- 2. plan : lecture, écriture, relecture
    local p = OF._Parse and OF._Parse(sample)
    T(p ~= nil and p.title == "Plan test" and table.getn(p.rosterOrder or {}) == 1,
        "plan : lecture d'un exemple")
    local again = p and OF._Serialize and OF._Parse(OF._Serialize(p))
    T(again ~= nil and p ~= nil and again.title == p.title and table.getn(again.bossOrder or {}) == table.getn(p.bossOrder or {}),
        "plan : écriture puis relecture identique")

    -- 3. taille des messages du relais (limite client : 254 octets, préfixe compris)
    local big = ""
    local i
    for i = 1, 60 do big = big .. "A|Boss" .. i .. "|Poste|Joueur" .. i .. "|Tâche accentuée;" end
    local chunks = OF._SplitChunks and OF._SplitChunks(big)
    local worst = 0
    if chunks then
        for i = 1, table.getn(chunks) do
            local n = string.len(OF._HexEnc(chunks[i]))
            if n > worst then worst = n end
        end
    end
    -- en-tête "id(8):idx(3):total(3):" = 17 + préfixe 4
    T(chunks ~= nil and worst + 17 + 4 <= 254, "relais : chaque message tient dans 254 octets",
        "plus gros : " .. (worst + 21) .. " octets")

    -- 4. plan actuel
    local db = RT.Store.DB()
    local cur = db.octofan
    if cur then
        T(not (OF._PlanIsCorrupt and OF._PlanIsCorrupt(cur)), "plan actuel : structure saine",
            (cur.title or "?") .. " " .. (cur.date or ""))
        if cur.localEdit then
            Say(true, "plan actuel : modifié en jeu (un plan reçu demandera confirmation avant de le remplacer)")
        end
    else
        Say(true, "plan actuel : aucun (normal si rien n'a été importé)")
    end

    -- 5. schémas
    local S = db.octofanSchemas
    local raids, bosses = 0, 0
    if type(S) == "table" then
        local rk, R
        for rk, R in pairs(S) do
            if type(R) == "table" and type(R.bosses) == "table" then
                raids = raids + 1
                local bk
                for bk in pairs(R.bosses) do bosses = bosses + 1 end
            end
        end
    end
    T(bosses > 0, "schémas : chargés", raids .. " raid(s), " .. bosses .. " boss")
    T(RT4 ~= nil and RT4.RaidRefresh ~= nil and RT4.ParseSchemas ~= nil, "page Raid : fonctions présentes")
    T(RTV ~= nil and RTV.Open ~= nil and RTV.Layout ~= nil, "fenêtre Raid agrandie (RTV) présente")

    -- 6. droits
    local canEdit = OF.CanEditAssign and OF.CanEditAssign()
    Say(true, "droits : modifier les assignations = " .. (canEdit and "oui" or "non (chef/assistant requis)"))

    -- 7. bots de chuchotement
    local v2 = RT_DB and RT_DB.settings and RT_DB.settings.whisperBot
    local v3 = RT.WBv3On and RT.WBv3On()
    Say(true, "bots : v2 " .. (v2 and "ON" or "OFF") .. ", v3 " .. (v3 and "ON" or "OFF") ..
        ((v2 and v3) and " (v3 répond seul à attrib/loot/sr, pas de doublon)" or ""))

    -- 8. API du client
    T(SendAddonMessage ~= nil and GetNumRaidMembers ~= nil and GetRaidRosterInfo ~= nil, "client : API de groupe disponible")

    RT.Print("|cffFFD700=== " .. pass .. " OK, " .. fail .. " échec(s) ===|r")
    if fail == 0 then
        RT.Print("Tout est bon. Pour tester le relais complet : un chef envoie son plan (bouton Envoyer au raid), les autres le voient arriver.")
    else
        RT.Print("|cffff6060Copie les lignes ÉCHEC et envoie-les-moi.|r")
    end
end

SLASH_RTSELFTEST1 = "/rtselftest"
SlashCmdList["RTSELFTEST"] = RunSelfTest
if RT4 then RT4.SelfTest = RunSelfTest end