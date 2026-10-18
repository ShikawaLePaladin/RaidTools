if RTM_DISABLED then return end
-- ============================================================
-- RaidTools Membre — RTM_SelfTest.lua
-- /rtmtest : vérifie en jeu que tout est chargé (rien n'est modifié).
-- ============================================================

local function Run()
    local ok, bad = 0, 0
    local function T(cond, label)
        if cond then ok = ok + 1; RT.Print("|cff44ff44OK|r " .. label)
        else bad = bad + 1; RT.Print("|cffff4444ECHEC|r " .. label) end
    end
    T(RT and RT.Store and RT.Store.DB and type(RT.Store.DB()) == "table", "données (RTM_DB)")
    local OF = RT.OctoFan
    T(OF ~= nil and OF._Parse ~= nil and OF._Serialize ~= nil, "module plan (OctoFanBridge) chargé")
    if OF and OF._Parse and OF._Serialize then
        local p = OF._Parse("OFP1|Test|mc|2026-01-01;R|tank|Alpha|Warrior|Protection|1;A|Lucifron|Tank 1|Alpha|Tient le boss;END")
        T(p ~= nil and p.assign and p.assign["Lucifron"] and p.assign["Lucifron"]["Tank 1"] ~= nil, "lecture d'un plan")
        local s = p and OF._Serialize(p)
        T(s ~= nil and string.find(s, "Alpha", 1, true) ~= nil, "relecture / écriture du plan")
    end
    T(OF ~= nil and OF.HasName ~= nil and OF.HasName("Bob, Alice", "alice") == true, "reconnaissance de mon nom dans un poste")
    local n = 0
    for _, R in pairs(RT.Store.DB().octofanSchemas or {}) do
        for _ in pairs(R.bosses or {}) do n = n + 1 end
    end
    T(n > 0, "schémas chargés (" .. n .. " boss)")
    T(RTV ~= nil and RTV.Open ~= nil and RTV.Layout ~= nil, "fenêtre Raid (schéma agrandi)")
    T(RTM ~= nil and RTM.SetOverlay ~= nil and RTM.GetOverlay ~= nil, "overlays Récap / Mon rôle")
    T(RT4 ~= nil and RT4.ParseSchemas ~= nil, "réception des schémas du chef")
    T(RT.OctoFan == nil or RT.OctoFan.PushTrash == nil, "pas d'outils d'officier (version Membre)")
    T(type(SendAddonMessage) == "function" and type(CreateFrame) == "function", "API du client")
    RT.Print("Auto-test : " .. ok .. " OK, " .. bad .. " échec(s).")
end

SLASH_RTMTEST1 = "/rtmtest"
SlashCmdList["RTMTEST"] = function() local okRun, err = pcall(Run); if not okRun then RT.Print("|cffff4444auto-test : " .. tostring(err) .. "|r") end end
