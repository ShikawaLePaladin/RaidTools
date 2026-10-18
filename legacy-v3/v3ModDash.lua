-- ============================================================
-- RT v3 — modules/Dashboard.lua
-- Le command center : agrège l'état du raid et offre les actions
-- clés en un écran. C'est la pièce maîtresse qui rend RT unique.
--
-- N'invente pas de données : lit le roster, RT_AA_LAST, RT_BOSS_STATE,
-- et appelle les pipelines v2 existants (PackPUG, PullTimer, Tactics).
-- ============================================================

local function rosterCounts()
    local t, h, d, total = 0, 0, 0, 0
    for _, data in pairs(RT.Store.Roster()) do
        total = total + 1
        local r = RT.NormRole(data.role or "")
        if r == "Tank" then t = t + 1
        elseif r == "Heal" then h = h + 1
        else d = d + 1 end
    end
    return t, h, d, total
end

local function fmtStatus()
    local L = {}
    local function add(s) table.insert(L, s) end

    -- État du raid
    local nRaid = (GetNumRaidMembers and GetNumRaidMembers()) or 0
    local nParty = (GetNumPartyMembers and GetNumPartyMembers()) or 0
    add("|cffFFD700» RAID STATUS|r")
    if nRaid > 0 then
        add("  |cff44FF44En raid|r : " .. nRaid .. "/40 membres")
    elseif nParty > 0 then
        add("  |cffFFAA00In party|r: " .. (nParty + 1) .. "/5")
    else
        add("  |cff888888Solo (pas en raid)|r")
    end

    -- Composition du roster
    local t, h, d, total = rosterCounts()
    add(" ")
    add("|cffFFD700» ROSTER|r")
    if total == 0 then
        add("  |cff888888empty — scan the raid (Roster tab) or import|r")
    else
        add(string.format("  |cff3399FF%d Tanks|r   |cff33FF33%d Heals|r   |cffFF4D4D%d DPS|r   |cff888888(%d total)|r", t, h, d, total))
    end

    -- Boss courant
    local boss = RT_BOSS_STATE and RT_BOSS_STATE.bossName or ""
    add(" ")
    add("|cffFFD700» CURRENT BOSS|r")
    if boss ~= "" then
        add("  |cffFF7D0A" .. boss .. "|r")
    else
        add("  |cff888888no boss selected (Boss v2 tab)|r")
    end

    -- Résumé de la dernière attribution
    add(" ")
    add("|cffFFD700» ASSIGNMENTS|r")
    if RT_AA_LAST and RT_AA_LAST.tanks and table.getn(RT_AA_LAST.tanks) > 0 then
        local tk = RT_AA_LAST.tanks
        for i = 1, table.getn(tk) do
            local mk = RT_AA_LAST.tankMarkers and RT_AA_LAST.tankMarkers[i] or ""
            local tag = mk ~= "" and ("|cffFFD700[" .. mk .. "]|r ") or ""
            local heal = RT_AA_LAST.healTank and RT_AA_LAST.healTank[i]
            local healTxt = (heal and heal ~= "") and ("  <-  |cff88FF88" .. heal .. "|r") or ""
            add("  " .. tag .. "MT" .. i .. " : " .. tk[i] .. healTxt)
        end
    else
        add("  |cff888888aucune — utilise les actions ci-dessous|r")
    end

    return table.concat(L, "\n")
end

RT.Modules.Register({
    id       = "dash",
    title    = "Dashboard",
    tip      = "Raid overview: headcount, status, shortcuts. The starting point.",
    color    = { 0.70, 0.55, 1.00 },
    tabWidth = 90,

    build = function(panel)
        RT.UI.Label(panel, {
            text = "|cffAA66FFCommand Center|r  —  your raid at a glance",
            font = "GameFontNormalLarge",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -10 },
        })

        -- ── Actions rapides ──
        RT.UI.Button(panel, {
            text = "Compute (Guild)", width = 140, height = 24,
            color = { 0.40, 1.00, 0.60 },
            anchor = { "TOPLEFT", panel, "TOPLEFT", 12, -40 },
            onClick = function()
                if RT_AA_PackGuild then RT_AA_PackGuild() end
                if panel._status then panel._status:SetText(fmtStatus()) end
            end,
            tooltip = "Analyse le roster et calcule toutes les attributions (sans annoncer).",
        })
        RT.UI.Button(panel, {
            text = "PUG Pack", width = 120, height = 24,
            color = { 0.40, 0.70, 1.00 },
            anchor = { "TOPLEFT", panel, "TOPLEFT", 158, -40 },
            onClick = function()
                if RT_AA_PackPUG then RT_AA_PackPUG() end
                if panel._status then panel._status:SetText(fmtStatus()) end
            end,
            tooltip = "Compute + announce to raid + whisper each player their assignment.",
        })
        RT.UI.Button(panel, {
            text = "Pull 10s", width = 100, height = 24,
            color = { 1.00, 0.55, 0.20 },
            anchor = { "TOPLEFT", panel, "TOPLEFT", 284, -40 },
            onClick = function()
                if RT_PT then RT_PT.Start(10, nil, true) end
            end,
            tooltip = "Starts a 10s pull countdown, visible to the whole raid.",
        })
        RT.UI.Button(panel, {
            text = "Announce strat", width = 120, height = 24,
            anchor = { "TOPLEFT", panel, "TOPLEFT", 390, -40 },
            onClick = function()
                local boss = RT_BOSS_STATE and RT_BOSS_STATE.bossName or ""
                if boss ~= "" and RT_Tactics then RT_Tactics.Post(boss, "RAID")
                else RT.Print("|cffFFAA00No boss selected.|r") end
            end,
            tooltip = "Posts the current boss tactic to the raid channel.",
        })

        -- ── Bloc d'état ──
        local status = RT.UI.TextScroll(panel, {
            name = "RT3_DashStatus",
            anchor = { "TOPLEFT", panel, "TOPLEFT", 8, -76 },
            width = 690, font = "GameFontHighlightSmall",
        })
        status.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)
        panel._status = status

        -- Refresh auto toutes les 2s tant que le dashboard est visible
        RT.Every(2, function()
            if panel:IsVisible() and panel._status then
                panel._status:SetText(fmtStatus())
            end
        end)

        -- Et réactif au roster
        RT.Store.Subscribe("roster", function()
            if panel:IsShown() and panel._status then panel._status:SetText(fmtStatus()) end
        end)
    end,

    show = function(panel)
        if panel._status then panel._status:SetText(fmtStatus()) end
    end,
})
