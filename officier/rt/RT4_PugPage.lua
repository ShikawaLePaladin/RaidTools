-- ============================================================
-- RT v5 — RT4_PugPage.lua
--
-- LA PAGE PUG (une seule page) : tout ce qu'il faut pour mener un
-- groupe/raid de PUG, sans toucher aux onglets experts.
--   - WhisperBot : toggle + réponses auto + LFM (canal + message)
--   - Auto-Invite : mot-clé + max + start/stop + retry 30s
--   - Assign rapide : Compute PUG (+ annonce), Pull timer
--   - Roster live compact (rôles T/H/D depuis le scan)
-- Les données vivent dans RT_DB.v3bot / RT_DB.ai : les modules
-- historiques (onglets WhisperBot/Invite) les relisent tels quels.
-- Lua 5.0 strict. Chargé après RT4_GuildPage.lua.
-- ============================================================

local ui = {}

local function GetBot()
    local db = RT.Store.DB()
    if not db.v3bot then
        db.v3bot = { enabled = false, autoinvite = false, tacAuto = true }
    end
    local bd = db.v3bot
    if bd.autoinvite == nil then bd.autoinvite = false end
    if bd.tacAuto == nil then bd.tacAuto = true end
    -- mêmes valeurs par défaut que WB.getData (rt.lua) : sans elles le bot ne
    -- répond plus à ?loot / ?join / ?info (réponse vide = pas de réponse)
    bd.templates = bd.templates or {}
    if bd.templates.loot == nil then bd.templates.loot = "Your loot assignment will be announced before the pull." end
    if bd.templates.join == nil then bd.templates.join = "Welcome! One moment, I'm checking your application." end
    if bd.templates.info == nil then bd.templates.info = "Whisper ?join to apply for the raid." end
    bd.recruit = bd.recruit or { minGear = "phase1", slots = { tank = 2, heal = 6, dps = 22 } }
    bd.recruit.slots = bd.recruit.slots or { tank = 2, heal = 6, dps = 22 }
    if not bd.lfm then
        bd.lfm = { msg = "LFM raid - need {tank} tank {heal} heal {dps} dps - /w me", channel = "SAY" }
    end
    return bd
end

local function GetAI()
    local db = RT.Store.DB()
    if not db.ai then db.ai = {} end
    return db.ai
end

local LFM_CHANS = { "SAY", "YELL", "GUILD", "WORLD", "LFG" }

-- Actions de leadership réservées officier/RL (sinon un membre coupe
-- le bot du RL ou relance une annonce dans le raid sans faire exprès).
local function IsLead()
    if RT4 and RT4.CanUse and RT4.CanUse("whisperbot") then return true end
    -- seul(e) : on rassemble son propre groupe, personne d'autre n'est concerné
    if (GetNumRaidMembers() or 0) == 0 and (GetNumPartyMembers() or 0) == 0 then return true end
    return false
end
local function GateLead()
    if not IsLead() then
        RT.Print("|cff59BFF2PUG|r : réservé aux officiers/RL (force ton accès sur l'Accueil).")
        return false
    end
    return true
end

if RT.Modules and RT.Modules.Register then
RT.Modules.Register({
    id    = "pug",
    title = "PUG",
    tip   = "La page PUG : WhisperBot, auto-invite, LFM, assign rapide.",
    color = { 0.35, 0.75, 0.95 },

    build = function(panel)
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
        title:SetText("|cff59BFF2PUG|r — rassemble, remplis, lance")

        -- ══ Colonne gauche : WhisperBot + Invite ══
        local left = CreateFrame("Frame", nil, panel)
        left:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -34)
        left:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -352, 8)
        RT.UI.ApplyBackdrop(left, 0.02, 0.02, 0.05, 0.85)

        -- ── WhisperBot ──
        local wbLbl = left:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        wbLbl:SetPoint("TOPLEFT", left, "TOPLEFT", 10, -8)
        wbLbl:SetText("|cff99AAFFWhisperBot|r — réponses auto aux whispers")

        local wbBtn = RT.UI.Button(left, {
            text = "BOT : OFF", width = 110, height = 24,
            anchor = { "TOPLEFT", left, "TOPLEFT", 10, -26 },
            tooltip = "Répond automatiquement aux candidats (?join ?role ?group...).",
        })
        ui.wbBtn = wbBtn
        wbBtn:SetScript("OnClick", function()
            if not GateLead() then return end
            local bd = GetBot()
            bd.enabled = not bd.enabled
            RT.Print("|cff99AAFFWhisperBot|r : " .. (bd.enabled and "|cff44FF44ON|r" or "|cffff6060OFF|r"))
            if ui.refresh then ui.refresh() end
        end)

        local aiTog = RT.UI.Button(left, {
            text = "Recrutement ?join : OFF", width = 170, height = 24,
            anchor = { "TOPLEFT", wbBtn, "TOPRIGHT", 8, 0 },
            tooltip = "ATTENTION : ON = un joueur qui whisper ?join est interrogé (gear/rôle) puis INVITÉ automatiquement. (?role ?spec ?group répondent déjà quand le BOT est ON.)",
        })
        ui.aiTog = aiTog
        aiTog:SetScript("OnClick", function()
            if not GateLead() then return end
            local bd = GetBot()
            bd.autoinvite = not bd.autoinvite
            if ui.refresh then ui.refresh() end
        end)

        -- LFM
        local lfmLbl = left:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lfmLbl:SetPoint("TOPLEFT", wbLbl, "BOTTOMLEFT", 0, -64)
        lfmLbl:SetText("|cff99AAFFLFM|r — annonce de recrutement")

        local chanBtn = RT.UI.Button(left, {
            text = "Canal : SAY", width = 90, height = 22,
            anchor = { "TOPLEFT", lfmLbl, "BOTTOMLEFT", 0, -4 },
            tooltip = "Canal de l'annonce LFM (Say/Yell/Guild/World/LFG).",
        })
        ui.chanBtn = chanBtn
        chanBtn:SetScript("OnClick", function()
            if not GateLead() then return end
            local bd = GetBot()
            local cur = bd.lfm.channel or "SAY"
            local idx = 1
            for i = 1, table.getn(LFM_CHANS) do
                if LFM_CHANS[i] == cur then idx = i break end
            end
            bd.lfm.channel = LFM_CHANS[math.mod(idx, table.getn(LFM_CHANS)) + 1]
            if ui.refresh then ui.refresh() end
        end)

        local msgEB = CreateFrame("EditBox", "RT5_PugLfmMsg", left, "InputBoxTemplate")
        msgEB:SetPoint("LEFT", chanBtn, "RIGHT", 10, 0)
        msgEB:SetWidth(130)
        msgEB:SetHeight(20)
        msgEB:SetAutoFocus(false)
        msgEB:SetScript("OnEscapePressed", function() this:ClearFocus() end)
        msgEB:SetScript("OnEnterPressed", function()
            if not GateLead() then
                if ui.refresh then ui.refresh() end
                this:ClearFocus()
                return
            end
            GetBot().lfm.msg = this:GetText() or ""
            this:ClearFocus()
        end)
        ui.msgEB = msgEB

        local postB = RT.UI.Button(left, {
            text = "Poster", width = 70, height = 22,
            anchor = { "LEFT", msgEB, "RIGHT", 8, 0 },
            tooltip = "Poste le message LFM sur le canal choisi ({tank} {heal} {dps} = places restantes).",
        })
        postB:SetScript("OnClick", function()
            if not GateLead() then return end
            local bd = GetBot()
            local msg = bd.lfm.msg or ""
            if msg == "" then RT.Print("|cff59BFF2LFM|r : écris d'abord le message.") return end
            local slots = (bd.recruit and bd.recruit.slots) or { tank = 2, heal = 6, dps = 22 }
            local have = { Tank = 0, Heal = 0, DPS = 0 }
            for _, data in pairs(RT.Store.Roster()) do
                local r = RT.NormRole and RT.NormRole(data.role or "") or "DPS"
                if r ~= "Tank" and r ~= "Heal" then r = "DPS" end
                have[r] = have[r] + 1
            end
            local function rem(k, h) local v = (slots[k] or 0) - h if v < 0 then v = 0 end return tostring(v) end
            msg = string.gsub(msg, "{tank}", rem("tank", have.Tank))
            msg = string.gsub(msg, "{heal}", rem("heal", have.Heal))
            msg = string.gsub(msg, "{dps}", rem("dps", have.DPS))
            local key = bd.lfm.channel or "SAY"
            local ctype, carg = "SAY", nil
            if key == "YELL" then ctype = "YELL"
            elseif key == "GUILD" then ctype = "GUILD"
            elseif key == "WORLD" or key == "LFG" then
                local idx = GetChannelName("World")
                if key == "LFG" then idx = GetChannelName("LookingForGroup") end
                if not idx or idx <= 0 then
                    RT.Print("|cffFF4444LFM|r : canal " .. key .. " introuvable (non rejoint). Essaie Say/Yell.")
                    return
                end
                ctype, carg = "CHANNEL", idx
            end
            SendChatMessage(msg, ctype, nil, carg)
        end)

        -- ── Auto-Invite ──
        local invLbl = left:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        invLbl:SetPoint("TOPLEFT", lfmLbl, "BOTTOMLEFT", 0, -46)
        invLbl:SetText("|cff59BFF2Auto-Invite|r — les joueurs whisper le mot-clé")

        local kwEB = CreateFrame("EditBox", "RT5_PugKw", left, "InputBoxTemplate")
        kwEB:SetPoint("TOPLEFT", invLbl, "BOTTOMLEFT", 6, -6)
        kwEB:SetWidth(90)
        kwEB:SetHeight(20)
        kwEB:SetAutoFocus(false)
        kwEB:SetScript("OnEscapePressed", function() this:ClearFocus() end)
        ui.kwEB = kwEB

        local startB = RT.UI.Button(left, {
            text = "▶ Inviter", width = 90, height = 22,
            anchor = { "LEFT", kwEB, "RIGHT", 14, 0 },
            tooltip = "Démarre l'auto-invite sur ce mot-clé (les joueurs qui le whisper sont invités).",
        })
        startB:SetScript("OnClick", function()
            if not GateLead() then return end
            if not RT_AI then RT.Print("|cffff6060Auto-Invite indisponible.|r") return end
            RT_AI.EnsureDB()
            local kw = kwEB:GetText() or ""
            if string.gsub(kw, "%s", "") == "" then kw = "inv" end
            kw = string.lower((string.gsub(kw, "^%s*(.-)%s*$", "%1")))
            GetAI().keyword = kw
            RT_AI.Start(kw, tonumber(GetAI().maxPlayers) or 40)
            RT.Print("|cff59BFF2Auto-Invite|r : ON — mot-clé \"" .. kw .. "\".")
            if ui.refresh then ui.refresh() end
        end)
        local stopB = RT.UI.Button(left, {
            text = "■ Stop", width = 70, height = 22,
            anchor = { "LEFT", startB, "RIGHT", 6, 0 },
        })
        stopB:SetScript("OnClick", function()
            if not GateLead() then return end
            if RT_AI then
                RT_AI.Stop()
                RT.Print("|cff59BFF2Auto-Invite|r : OFF.")
            end
            if ui.refresh then ui.refresh() end
        end)
        ui.startB = startB

        -- Assign rapide : UN bouton clair (l'ancien Compute/Annoncer
        -- lançaient le même pipeline), + calculer sans annoncer.
        local asLbl = left:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        asLbl:SetPoint("TOPLEFT", invLbl, "BOTTOMLEFT", 0, -46)
        asLbl:SetText("|cffFFCC44Assign rapide|r — remplir le raid en 1 clic")

        local compB = RT.UI.Button(left, {
            text = "⚡ Remplir & annoncer", width = 210, height = 26,
            anchor = { "TOPLEFT", asLbl, "BOTTOMLEFT", 0, -4 },
            tooltip = "Calcule tanks/heals/décurses depuis le roster, annonce au raid et whisper à chacun (officiers/RL).",
        })
        compB:SetScript("OnClick", function()
            if not GateLead() then return end
            if RT_AA_PackPUG then RT_AA_PackPUG() end
        end)
        local calcB = RT.UI.Button(left, {
            text = "📋 Calculer sans annoncer", width = 190, height = 24,
            anchor = { "TOPLEFT", compB, "BOTTOMLEFT", 0, -6 },
            tooltip = "Calcule les assignations sans rien annoncer (tout le monde peut voir).",
        })
        calcB:SetScript("OnClick", function()
            if RT_AA_PackGuild then RT_AA_PackGuild() end
        end)
        local pullB = RT.UI.Button(left, {
            text = "⏱ Pull 10s", width = 120, height = 24,
            anchor = { "LEFT", calcB, "RIGHT", 8, 0 },
            tooltip = "Compte à rebours de pull annoncé au raid.",
        })
        pullB:SetScript("OnClick", function()
            if RT_PT and RT_PT.Start then RT_PT.Start(10, nil, true) end
        end)

        -- note pour les membres (réglages leadership réservés)
        ui.lockHint = left:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ui.lockHint:SetPoint("TOPLEFT", pullB, "BOTTOMLEFT", 0, -6)
        ui.lockHint:SetJustifyH("LEFT")
        ui.lockHint:SetWidth(330)
        ui.lockHint:SetText("|cff888888BOT, invite, LFM et annonces sont réservés aux officiers/RL.|r")
        ui.lockHint:Hide()

        -- ══ Colonne droite : roster live ══
        local right = CreateFrame("Frame", nil, panel)
        right:SetPoint("TOPLEFT", panel, "TOPLEFT", 352, -34)
        right:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
        RT.UI.ApplyBackdrop(right, 0.02, 0.02, 0.05, 0.85)
        local rLbl = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rLbl:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -6)
        ui.rLbl = rLbl
        ui.roster = RT.UI.TextScroll(right, {
            name = "RT5_PugRoster",
            anchor = { "TOPLEFT", right, "TOPLEFT", 6, -24 },
            width = 296,
        })
        ui.roster.scroll:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -6, 6)

        -- ── Refresh ──
        local LOCKED_LABELS = { ui.wbBtn, ui.aiTog, ui.chanBtn, ui.startB }
        ui.refresh = function()
            local bd = GetBot()
            local lead = IsLead()
            -- boutons de leadership grisés pour un membre
            for i = 1, table.getn(LOCKED_LABELS) do
                local b = LOCKED_LABELS[i]
                if b and b.GetFontString then
                    local fs = b:GetFontString()
                    if fs then
                        if lead then fs:SetTextColor(1, 1, 1)
                        else fs:SetTextColor(0.55, 0.55, 0.55) end
                    end
                end
            end
            if ui.lockHint then
                if lead then ui.lockHint:Hide() else ui.lockHint:Show() end
            end
            if ui.wbBtn and ui.wbBtn.SetText then
                ui.wbBtn:SetText(bd.enabled and "BOT : ON" or "BOT : OFF")
                local tex = ui.wbBtn:GetNormalTexture()
                if tex then
                    tex:SetVertexColor(bd.enabled and 0.10 or 0.55, bd.enabled and 0.55 or 0.15, bd.enabled and 0.10 or 0.10)
                end
            end
            if ui.aiTog and ui.aiTog.SetText then
                ui.aiTog:SetText(bd.autoinvite and "Recrutement ?join : ON" or "Recrutement ?join : OFF")
            end
            if ui.chanBtn and ui.chanBtn.SetText then
                ui.chanBtn:SetText("Canal : " .. (bd.lfm.channel or "SAY"))
            end
            if ui.msgEB then ui.msgEB:SetText(bd.lfm.msg or "") end
            if ui.kwEB then ui.kwEB:SetText(GetAI().keyword or "inv") end
            if ui.startB and ui.startB.SetText then
                local on = RT_AI and RT_AI.IsActive and RT_AI.IsActive()
                ui.startB:SetText(on and "● actif" or "▶ Inviter")
            end

            -- roster live (T/H/D)
            local nRaid = (GetNumRaidMembers and GetNumRaidMembers()) or 0
            local nParty = (GetNumPartyMembers and GetNumPartyMembers()) or 0
            local roster = RT.Store.Roster and RT.Store.Roster() or {}
            local t, h, d = 0, 0, 0
            local L = {}
            local names = {}
            for name in pairs(roster) do table.insert(names, name) end
            table.sort(names)
            for _, name in ipairs(names) do
                local r = RT.NormRole and RT.NormRole(roster[name].role or "") or "?"
                if r == "Tank" then t = t + 1
                elseif r == "Heal" then h = h + 1
                else d = d + 1 end
                table.insert(L, string.format("  %s — %s", name, r))
            end
            if ui.rLbl and ui.rLbl.SetText then
                ui.rLbl:SetText(string.format(
                    "|cffFFCC44Roster live|r — %s joueur(s)  |cffFF4D4D%dT|r |cff44FF44%dH|r |cff6699FF%dD|r",
                    table.getn(names), t, h, d))
            end
            if table.getn(L) == 0 then
                table.insert(L, "")
                table.insert(L, "|cff888888Roster vide — scanne le raid|r")
                table.insert(L, "|cff888888(onglet Roster dans Outils, ou /rt scan).|r")
            end
            local foot = ""
            if nRaid > 0 then foot = "\n\n|cff888888Raid : " .. nRaid .. "/40|r"
            elseif nParty > 0 then foot = "\n\n|cff888888Groupe : " .. (nParty + 1) .. "/5|r" end
            if ui.roster and ui.roster.SetText then
                ui.roster:SetText(table.concat(L, "\n") .. foot)
            end
        end
    end,

    show = function(panel)
        if ui.refresh then ui.refresh() end
    end,
})
end

RT.Print("|cffAA66FFRaidTools v5|r: page PUG prête (WhisperBot + invite + LFM + assign rapide).")

-- ============================================================
-- Module "Boss PUG" : les assignations par boss, comme le site
-- mais sans schéma — liste des boss à gauche, postes à droite,
-- MT rapides éditables + annonce. (demande proprio : "teste on")
-- ============================================================

local bqSel = nil

if RT.Modules and RT.Modules.Register then
RT.Modules.Register({
    id    = "bossq",
    title = "Boss PUG",
    tabWidth = 74,
    tip   = "Assignations rapides par boss (MT éditables + annonce).",
    color = { 0.90, 0.45, 0.35 },

    build = function(panel)
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
        title:SetText("|cffE6735ABoss PUG|r — qui tank quoi, en un écran")

        -- gauche : la liste des boss (dans un scroll clippé)
        local list = RT.UI.ScrollArea(panel, {
            name = "RT5_BqList",
            width = 246, height = 200,
        })
        list:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -34)
        list:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -442, 8)
        local bqChild = list.child
        panel._bqHdr = bqChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        panel._bqHdr:SetPoint("TOPLEFT", bqChild, "TOPLEFT", 4, -6)
        panel._bqRows = {}
        panel._bqMake = function(i)
            local b = CreateFrame("Button", nil, bqChild)
            b:SetHeight(15)
            b:SetPoint("TOPLEFT", bqChild, "TOPLEFT", 4, -(26 + (i - 1) * 15))
            b:SetPoint("RIGHT", bqChild, "RIGHT", -4, 0)
            local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t:SetPoint("TOPLEFT", b, "TOPLEFT", 2, 0)
            t:SetJustifyH("LEFT")
            b:SetFontString(t)
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            b:GetHighlightTexture():SetAlpha(0.3)
            b:Hide()
            panel._bqRows[i] = b
            return b
        end
        for i = 1, 40 do panel._bqMake(i) end

        -- droite : le détail du boss + MT rapides + annonce
        local det = CreateFrame("Frame", nil, panel)
        det:SetPoint("TOPLEFT", panel, "TOPLEFT", 262, -34)
        det:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
        RT.UI.ApplyBackdrop(det, 0.02, 0.02, 0.05, 0.85)

        local dBoss = det:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dBoss:SetPoint("TOPLEFT", det, "TOPLEFT", 10, -8)
        panel._bqBoss = dBoss

        -- MT rapides : 3 champs éditables
        panel._bqMT = {}
        for i = 1, 3 do
            local lbl = det:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lbl:SetPoint("TOPLEFT", det, "TOPLEFT", 10, -(36 + (i - 1) * 26))
            lbl:SetText("MT" .. i .. " :")
            local eb = CreateFrame("EditBox", "RT5_BqMT" .. i, det, "InputBoxTemplate")
            eb:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
            eb:SetWidth(150)
            eb:SetHeight(20)
            eb:SetAutoFocus(false)
            eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
            eb:SetScript("OnEnterPressed", function()
                local db = RT.Store.DB()
                if bqSel then
                    local p = db.octofan
                    if not p then
                        -- PUG sans plan du site : on crée un plan vide (sinon la saisie était perdue)
                        p = { title = "", raid = "", date = "", roster = {}, rosterOrder = {},
                            assign = {}, bossOrder = {}, trash = {}, strats = {} }
                        db.octofan = p
                    end
                    p.assign = p.assign or {}
                    p.bossOrder = p.bossOrder or {}
                    p.assign[bqSel] = p.assign[bqSel] or {}
                    -- le boss doit figurer dans bossOrder : c'est ce que lisent le relay
                    -- (SerializeOFP), "Mon rôle" et la liste
                    local known = false
                    for _, b in ipairs(p.bossOrder) do
                        if b == bqSel then known = true end
                    end
                    if not known then table.insert(p.bossOrder, bqSel) end
                    local txt = this:GetText() or ""
                    if string.gsub(txt, "%s", "") == "" then
                        p.assign[bqSel]["Tank " .. i] = nil
                    else
                        p.assign[bqSel]["Tank " .. i] = { player = txt, task = "" }
                    end
                    RT.Store.Notify("octofan")
                end
                this:ClearFocus()
                if panel._bqRefresh then panel._bqRefresh() end
            end)
            panel._bqMT[i] = eb
        end

        local annB = RT.UI.Button(det, {
            text = "📣 Annoncer ce boss", width = 170, height = 26,
            anchor = { "TOPLEFT", det, "TOPLEFT", 10, -118 },
            tooltip = "Poste les MT saisis puis la tactique de ce boss (officiers/RL).",
        })
        annB:SetScript("OnClick", function()
            if not bqSel or not GateLead() then return end
            local ch = ((GetNumRaidMembers() or 0) > 0 and "RAID")
                or ((GetNumPartyMembers() or 0) > 0 and "PARTY") or nil
            if not ch then
                RT.Print("|cffE6735ABoss PUG|r : pas de groupe — rien à annoncer.")
                return
            end
            local p = RT.Store.DB().octofan
            local a = p and p.assign and p.assign[bqSel]
            local parts = {}
            for i = 1, 3 do
                local s = a and a["Tank " .. i]
                if s and s.player and s.player ~= "" then
                    table.insert(parts, "MT" .. i .. ": " .. s.player)
                end
            end
            if table.getn(parts) > 0 then
                SendChatMessage(bqSel .. " - " .. table.concat(parts, "  -  "), ch)
            end
            if RT_Tactics then RT_Tactics.Post(bqSel, ch) end
        end)

        panel._bqDet = RT.UI.TextScroll(det, {
            name = "RT5_BqDetail",
            anchor = { "TOPLEFT", det, "TOPLEFT", 8, -152 },
            width = 420,
        })
        panel._bqDet.scroll:SetPoint("BOTTOMRIGHT", det, "BOTTOMRIGHT", -6, 6)

        -- liste des boss disponibles
        panel._bqList = function()
            local out, seen = {}, {}
            local plan = RT.Store.DB().octofan
            if plan then
                for _, b in ipairs(plan.bossOrder or {}) do
                    if not seen[b] then seen[b] = true; table.insert(out, b) end
                end
            end
            -- + tous les boss des schémas (ordre alphabétique stable : next(S) ne l'est pas)
            local extra = {}
            local S = RT.Store.DB().octofanSchemas
            if type(S) == "table" then
                for _, R in pairs(S) do
                    for _, b in pairs(R.bosses or {}) do
                        if b.name and not seen[b.name] then
                            seen[b.name] = true
                            table.insert(extra, b.name)
                        end
                    end
                end
            end
            table.sort(extra)
            for _, b in ipairs(extra) do table.insert(out, b) end
            if table.getn(out) == 0 then
                return out, "Aucun plan ni schéma — importe depuis le site (Outils)."
            end
            if plan and plan.title and plan.title ~= "" then return out, "Plan : " .. plan.title end
            return out, "Boss (schémas) — saisis les MT, ils sont créés à la volée"
        end

        panel._bqRefresh = function()
            local bosses, hdr = panel._bqList()
            if panel._bqHdr then panel._bqHdr:SetText(hdr or "") end
            if not bqSel and table.getn(bosses) > 0 then bqSel = bosses[1] end
            local row = 1
            for _, b in ipairs(bosses) do
                local rb = panel._bqRows[row] or panel._bqMake(row)
                if not rb or not rb.SetText then break end
                rb:SetText((b == bqSel and "|cffFFCC44▶ |r" or "") .. b)
                rb:SetScript("OnClick", function()
                    bqSel = b
                    if panel._bqRefresh then panel._bqRefresh() end
                end)
                rb:Show()
                row = row + 1
            end
            for j = row, table.getn(panel._bqRows) do
                local hb = panel._bqRows[j]
                if hb and hb.Hide then hb:Hide() end
            end
            if bqChild and bqChild.SetHeight then
                bqChild:SetHeight(math.max(row * 15 + 34, 60))
            end

            if panel._bqBoss then
                panel._bqBoss:SetText(bqSel and ("|cffFFD700" .. bqSel .. "|r") or "|cff888888Sélectionne un boss|r")
            end
            local db = RT.Store.DB()
            local assign = (bqSel and db.octofan and db.octofan.assign or {})[bqSel] or {}
            for i = 1, 3 do
                local eb = panel._bqMT[i]
                if eb then
                    local slot = assign["Tank " .. i]
                    eb:SetText(slot and slot.player or "")
                end
            end
            local L = {}
            local n = 0
            for poste, slot in pairs(assign) do
                n = n + 1
                local who = slot.player or "?"
                if slot.task and slot.task ~= "" then who = who .. " — " .. slot.task end
                table.insert(L, "  |cff66CCFF" .. poste .. "|r : " .. who)
            end
            if n == 0 then
                table.insert(L, "|cff888888Pas d'assignations — remplis MT1/MT2/MT3 ci-dessus,|r")
                table.insert(L, "|cff888888ou lance « ⚡ Remplir & annoncer » dans l'onglet PUG.|r")
            end
            if panel._bqDet and panel._bqDet.SetText then
                panel._bqDet:SetText(table.concat(L, "\n"))
            end
        end
    end,

    show = function(panel)
        if panel._bqRefresh then panel._bqRefresh() end
    end,
})
end

local teamSel = nil

if RT.Modules and RT.Modules.Register then
RT.Modules.Register({
    id    = "equipe",
    title = "Équipe",
    tip   = "Le roster et les assignations en un écran.",
    color = { 0.55, 0.85, 0.55 },

    build = function(panel)
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
        title:SetText("|cff8CD68CÉquipe|r — qui est là, qui fait quoi")
        panel._teamTitle = title

        -- gauche : la liste (dans un scroll clippé — les 40 rangées
        -- fixes débordaient du cadre, vues sur screen)
        local list = RT.UI.ScrollArea(panel, {
            name = "RT5_TeamList",
            width = 246, height = 200,
        })
        list:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -34)
        list:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -442, 8)
        local listChild = list.child
        panel._tHdr = listChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        panel._tHdr:SetPoint("TOPLEFT", listChild, "TOPLEFT", 4, -6)
        panel._tRows = {}
        panel._tMake = function(i)
            local b = CreateFrame("Button", nil, listChild)
            b:SetHeight(15)
            b:SetPoint("TOPLEFT", listChild, "TOPLEFT", 4, -(26 + (i - 1) * 15))
            b:SetPoint("RIGHT", listChild, "RIGHT", -4, 0)
            local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t:SetPoint("TOPLEFT", b, "TOPLEFT", 2, 0)
            t:SetJustifyH("LEFT")
            b:SetFontString(t)
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            b:GetHighlightTexture():SetAlpha(0.3)
            b:Hide()
            panel._tRows[i] = b
            return b
        end
        for i = 1, 40 do panel._tMake(i) end

        -- droite : le détail du joueur sélectionné
        local det = CreateFrame("Frame", nil, panel)
        det:SetPoint("TOPLEFT", panel, "TOPLEFT", 262, -34)
        det:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
        RT.UI.ApplyBackdrop(det, 0.02, 0.02, 0.05, 0.85)
        panel._det = RT.UI.TextScroll(det, {
            name = "RT5_TeamDetail",
            anchor = { "TOPLEFT", det, "TOPLEFT", 6, -6 },
            width = 418,
        })
        panel._det.scroll:SetPoint("BOTTOMRIGHT", det, "BOTTOMRIGHT", -6, 6)

        panel._tRefresh = function()
            local roster = RT.Store.Roster and RT.Store.Roster() or {}
            local names = {}
            for name in pairs(roster) do table.insert(names, name) end
            table.sort(names)
            local t, h, d = 0, 0, 0
            for _, name in ipairs(names) do
                local r = RT.NormRole and RT.NormRole(roster[name].role or "") or "?"
                if r == "Tank" then t = t + 1
                elseif r == "Heal" then h = h + 1
                else d = d + 1 end
            end
            if panel._tHdr then
                panel._tHdr:SetText(string.format(
                    "%d joueur(s)  |cffFF4D4D%dT|r |cff44FF44%dH|r |cff6699FF%dD|r  — clic = détail",
                    table.getn(names), t, h, d))
            end
            local row = 1
            for _, name in ipairs(names) do
                local b = panel._tRows[row] or panel._tMake(row)
                if not b or not b.SetText then break end
                local r = RT.NormRole and RT.NormRole(roster[name].role or "") or "?"
                local tag = r == "Tank" and "|cffFF4D4DT|r" or r == "Heal" and "|cff44FF44H|r" or "|cff6699FFD|r"
                local selMark = teamSel == name and "|cffFFCC44▶ |r" or ""
                b:SetText(selMark .. string.format("%-18s %s", name, tag))
                b:SetScript("OnClick", function()
                    teamSel = name
                    if panel._tRefresh then panel._tRefresh() end
                end)
                b:Show()
                row = row + 1
            end
            for j = row, table.getn(panel._tRows) do
                local hb = panel._tRows[j]
                if hb and hb.Hide then hb:Hide() end
            end
            -- hauteur du child pour le range du scroll
            if listChild and listChild.SetHeight then
                listChild:SetHeight(math.max(row * 15 + 34, 60))
            end

            -- détail
            local L = {}
            if teamSel and roster[teamSel] then
                local data = roster[teamSel]
                table.insert(L, "|cffFFD700" .. teamSel .. "|r")
                table.insert(L, "  Rôle : " .. (RT.NormRole and RT.NormRole(data.role or "") or "?") ..
                    (data.spec and data.spec ~= "" and (" (" .. data.spec .. ")") or "") ..
                    (data.class and data.class ~= "" and ("  " .. data.class) or ""))
                -- assignations du plan (postes où il figure)
                local plan = RT.Store.DB().octofan
                if plan and plan.assign then
                    for boss, postes in pairs(plan.assign) do
                        for poste, slot in pairs(postes) do
                            if slot.player and RT.OctoFan and RT.OctoFan.HasName and RT.OctoFan.HasName(slot.player, teamSel) then
                                table.insert(L, "")
                                table.insert(L, "|cff66CCFF" .. boss .. " — " .. poste .. "|r")
                                if slot.task and slot.task ~= "" then
                                    table.insert(L, "  " .. slot.task)
                                end
                            end
                        end
                    end
                end
                -- MT officielles
                if RT_AA_LAST and RT_AA_LAST.tanks then
                    for i = 1, table.getn(RT_AA_LAST.tanks) do
                        if RT_AA_LAST.tanks[i] == teamSel then
                            table.insert(L, "")
                            table.insert(L, "|cffFFCC44MT" .. i .. " (compute courant)|r")
                        end
                    end
                end
            else
                table.insert(L, "|cff888888Sélectionne un joueur à gauche.|r")
                table.insert(L, "")
                table.insert(L, "|cff888888Son rôle, ses assignations par boss et|r")
                table.insert(L, "|cff888888sa place dans le compute s'affichent ici.|r")
            end
            if panel._det and panel._det.SetText then
                panel._det:SetText(table.concat(L, "\n"))
            end
        end
    end,

    show = function(panel)
        if panel._tRefresh then panel._tRefresh() end
    end,
})
end
