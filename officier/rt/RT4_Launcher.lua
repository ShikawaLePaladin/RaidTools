-- ============================================================
-- RT v5 — RT4_Launcher.lua
--
-- Onglet "Accueil" : le point d'entrée de l'addon.
-- Design : en-tête (joueur + accès), deux grandes CARTES de mode
-- cliquables (Guilde dorée / PUG bleue, badge ACTIF), barre de
-- raccourcis uniforme, ligne d'état vivante.
-- Lua 5.0 strict. Chargé après RT4_Roles.lua.
-- ============================================================

local ROLE_ORDER = { "auto", "member", "officer", "admin" }
local ROLE_NAME = {
    auto    = "AUTO",
    member  = "Membre",
    officer = "Officier/RL",
    admin   = "Admin",
}

local function ModeText()
    local m = "pug"
    if RT.OctoFan and RT.OctoFan.GetMode then m = RT.OctoFan.GetMode() end
    return m
end

-- Carte de mode : frame à backdrop cliquable (plus riche qu'un
-- UIPanelButtonTemplate : bordure colorée, contenu multi-lignes).
local function ModeCard(panel, x, id, icon, name, line1, line2, line3, borderColor)
    local card = CreateFrame("Frame", nil, panel)
    card:SetWidth(316)
    card:SetHeight(104)
    card:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -118)
    card:EnableMouse(true)
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    card:SetBackdropColor(0.06, 0.05, 0.10, 0.95)
    card:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 0.9)

    local ic = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ic:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)
    ic:SetText(icon .. " " .. name)

    local badge = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badge:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -12)
    card._badge = badge

    local desc = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -36)
    desc:SetJustifyH("LEFT")
    desc:SetWidth(284)
    desc:SetText(line1 .. "\n" .. line2 .. "\n" .. line3)

    local enter = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enter:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, 8)
    enter:SetText("|cff888888[ Entrer ]|r")
    card._enter = enter

    card:SetScript("OnMouseUp", function()
        if arg1 ~= "LeftButton" then return end
        if not (RT.OctoFan and RT.OctoFan.SetMode) then
            RT.Print("|cffAA66FFRaidTools|r: module OctoFan non chargé — mode inchangé.")
            return
        end
        RT.OctoFan.SetMode(id)
        RT.Print("|cffAA66FFRaidTools|r: mode " .. name .. ".")
        if _G.RT3_MainFrame then
            RT.Modules.Show(id == "guild" and "raid" or "pug")
        end
    end)
    card:SetScript("OnEnter", function()
        card:SetBackdropColor(0.10, 0.09, 0.16, 0.98)
        card:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
    end)
    card:SetScript("OnLeave", function()
        card:SetBackdropColor(0.06, 0.05, 0.10, 0.95)
        card:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 0.9)
    end)
    return card
end

if RT.Modules and RT.Modules.Register then
RT.Modules.Register({
    id    = "home",
    title = "Accueil",
    tip   = "Choix du mode Guilde/PUG, accès, raccourcis.",
    color = { 1.0, 0.82, 0.27 },

    build = function(panel)
        -- ── En-tête : titre à gauche, joueur + accès à droite ──
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
        title:SetText("|cffFFCC44⚔ RAIDTOOLS|r")

        local whoLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        whoLbl:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -14)
        whoLbl:SetJustifyH("RIGHT")
        panel._whoLbl = whoLbl

        -- (le bouton d'accès est maintenant dans l'en-tête du shell, à côté de S et X)

        -- ── Les deux cartes de mode ──
        local cardG = ModeCard(panel, 24, "guild", "🏰", "GUILDE",
            "Schémas des boss + plan partagé du site",
            "Mon rôle, marks trash auto, kills suivis",
            "Pour les raids organisés de la guilde",
            { 0.72, 0.55, 0.20 })
        local cardP = ModeCard(panel, 356, "pug", "🌍", "PUG",
            "WhisperBot, LFM, auto-invite",
            "Scan rapide, assign en 1 clic, pull",
            "Pour monter un raid à la minute",
            { 0.25, 0.50, 0.75 })

        -- ── Barre de raccourcis (grille uniforme) ──
        local qLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        qLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -238)
        qLbl:SetText("|cffFFD700Accès rapide|r")

        local bx = 24
        local function mkShortcut(label, w, onClick, tip)
            local b = RT.UI.Button(panel, {
                text = label, width = w, height = 28,
                anchor = { "TOPLEFT", panel, "TOPLEFT", bx, -260 },
                tooltip = tip,
            })
            b:SetScript("OnClick", onClick)
            bx = bx + w + 10
            return b
        end
        mkShortcut("👤 Mon rôle", 124, function()
            if RT.OctoFan and RT.OctoFan.ShowMyRole then RT.OctoFan.ShowMyRole() end
        end, "Ta fenêtre d'assignations et de strats (le plan importé).")
        mkShortcut("📋 Mon récap", 124, function()
            if RT4.ToggleRecap then RT4.ToggleRecap() end
        end, "Ton récap perso : ton rôle, tes assignations sur le boss, ton groupe.")
        mkShortcut("⏱ Pull 10s", 110, function()
            RT4.StartPull(10)
        end, "Compte à rebours annoncé au raid.")
        mkShortcut("🎯 Marks", 110, function()
            if AutoMarkerOW_ToggleUI then AutoMarkerOW_ToggleUI()
            else RT.Print("|cffAA66FFRaidTools|r: AutoMarkerOW n'est pas installé.") end
        end, "Marquage automatique (AutoMarkerOW).")
        mkShortcut("↺ Kills", 90, function()
            if RT4.RaidResetKills then RT4.RaidResetKills() end
        end, "Réinitialise le suivi des boss tués.")

        -- ── Ligne d'état vivante ──
        local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 24, 14)
        status:SetJustifyH("LEFT")
        status:SetWidth(660)
        panel._status = status

        local ftick = CreateFrame("Frame")
        ftick.t = 0
        ftick:SetScript("OnUpdate", function()
            this.t = this.t + arg1
            if this.t < 2 then return end
            this.t = 0
            if panel._status and panel._status.SetText and panel:IsVisible() and panel._show then
                panel._show()
            end
        end)

        panel._show = function()
            local db = RT4.GetDB()
            local autoRole = RT4.AutoRole() or "member"
            local effRole = (db.role and db.role ~= "auto" and db.role) or autoRole
            if panel._whoLbl then
                panel._whoLbl:SetText("|cffFFD700" .. (UnitName("player") or "?") .. "|r  ·  " ..
                    (RT4.ROLE_LABEL and RT4.ROLE_LABEL[effRole] or effRole) ..
                    "  ·  " .. (RT.OctoFan and RT.OctoFan.GetMode and
                    (RT.OctoFan.GetMode() == "guild" and "🏰 Guilde" or "🌍 PUG") or "?"))
            end
            if panel._roleBtn then
                panel._roleBtn:SetText("Accès : " .. (ROLE_NAME[db.role or "auto"] or "AUTO"))
            end
            local m = ModeText()
            if cardG and cardG._badge then
                cardG._badge:SetText(m == "guild" and "|cffFFCC44● ACTIF|r" or "")
            end
            if cardP and cardP._badge then
                cardP._badge:SetText(m ~= "guild" and "|cff59BFF2● ACTIF|r" or "")
            end
            if cardG and cardG._enter then
                cardG._enter:SetText(m == "guild" and "|cffFFCC44[ Tu es ici ]|r" or "|cff888888[ Entrer ]|r")
            end
            if cardP and cardP._enter then
                cardP._enter:SetText(m ~= "guild" and "|cff59BFF2[ Tu es ici ]|r" or "|cff888888[ Entrer ]|r")
            end
            -- ligne d'état
            local plan = RT.Store.DB().octofan
            local bd = RT.Store.DB().v3bot
            local nR = (GetNumRaidMembers and GetNumRaidMembers()) or 0
            local nP = (GetNumPartyMembers and GetNumPartyMembers()) or 0
            local bits = {}
            if plan and plan.title and plan.title ~= "" then
                table.insert(bits, "|cff66CCFFPlan « " .. plan.title .. " »|r")
            end
            if bd and bd.enabled then table.insert(bits, "|cff44FF44WhisperBot ON|r") end
            if nR > 0 then table.insert(bits, "|cffFFD700Raid " .. nR .. "/40|r")
            elseif nP > 0 then table.insert(bits, "Groupe " .. (nP + 1) .. "/5") end
            if table.getn(bits) == 0 then
                table.insert(bits, "|cff888888Importe un plan depuis le site (bouton 💾) ou reçois-le du leader (📡).|r")
            end
            if panel._status then panel._status:SetText(table.concat(bits, "   ·   ")) end
        end
    end,

    show = function(panel)
        if panel._show then panel._show() end
    end,
})
end
