-- ============================================================
-- RT v3 - modules/WhisperBot.lua
-- Bot whisper + recrutement intelligent (1 seul local chunk)
-- ============================================================

local WB = {
    log         = {},
    disp        = nil,   -- FontString log
    pending     = {},    -- { [name] = { step, gear } }
    roster      = {},    -- { [name] = { role, gear } }
    specPending = {},    -- { [name] = true }  joueurs à qui on a demandé leur spé
    counts      = { tank=0, heal=0, dps=0 },
    cDisp       = nil,   -- FontString compteurs
    GEAR_RANK   = { pregear=1, phase1=2, phase2=3 },
    GEAR_LABEL  = { pregear="Pre-Gear", phase1="Phase 1", phase2="Phase 2" },
}

-- Tokens reconnus dans une réponse texte → spé canonique (menu RT).
-- L'ordre compte : on teste du plus spécifique au plus générique.
WB.SPEC_TOKENS = {
    {"protection","Prot"}, {"prot","Prot"}, {"tank","Prot"},
    {"fury","Fury"}, {"furie","Fury"}, {"arms","Arms"}, {"armes","Arms"},
    {"retri","Retri"}, {"vindi","Retri"}, {"ret","Retri"},
    {"holy","Holy"}, {"sacre","Holy"}, {"sacré","Holy"},
    {"disc","Disc"}, {"shadow","Shadow"}, {"ombre","Shadow"},
    {"resto","Resto"}, {"restau","Resto"}, {"soin","Resto"}, {"heal","Resto"},
    {"feral","Feral"}, {"farouche","Feral"},
    {"balance","Balance"}, {"equilibre","Balance"}, {"boomkin","Balance"},
    {"enha","Enh"}, {"enh","Enh"},
    {"elem","Elem"}, {"elementaire","Elem"}, {"ele","Elem"},
    {"fire","Fire"}, {"feu","Fire"}, {"frost","Frost"}, {"givre","Frost"}, {"gel","Frost"},
    {"arcane","Arcane"},
    {"affli","Affli"}, {"demono","Demo"}, {"demo","Demo"}, {"destru","Destro"}, {"destro","Destro"},
    {"combat","Combat"}, {"assa","Assa"}, {"finesse","Assa"}, {"subt","Subt"},
    {"beast","BM"}, {"bete","BM"}, {"bm","BM"}, {"precision","MM"}, {"marks","MM"}, {"mm","MM"},
    {"surv","Surv"}, {"survie","Surv"},
}

-- Devine la spé canonique depuis un texte libre (réponse au whisper).
function WB.specFromText(text)
    local s = string.lower(text or "")
    for i = 1, table.getn(WB.SPEC_TOKENS) do
        local tok = WB.SPEC_TOKENS[i]
        if string.find(s, tok[1], 1, true) then return tok[2] end
    end
    return nil
end

-- Construit la question de spé, adaptée à la classe du joueur si connue
-- (ex: Warrior -> "Arms, Fury or Prot?"). Sinon question générique.
function WB.specQuestion(classToken)
    local cls = string.upper(classToken or "")
    local specs = RT3_TALENT_SPECS and RT3_TALENT_SPECS[cls]
    if not specs then
        return "[RaidTools] What's your spec? Just reply with your spec (e.g. Prot, Resto, Fury, Shadow, Enh...). Thanks!"
    end
    return "[RaidTools] What's your spec? (" .. specs[1] .. " / " .. specs[2] .. " / " .. specs[3] .. ") Just reply with one. Thanks!"
end

-- Envoie un whisper à chaque membre du raid pour demander sa spé.
-- onlyMissing=true → seulement ceux sans spé connue.
function WB.askSpecs(onlyMissing)
    -- 1) les joueurs qui ont RT répondent automatiquement (addon)
    if RT3_RequestSpecsAddon then RT3_RequestSpecsAddon() end
    -- 2) whisper aux autres
    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    if n == 0 then
        RT.Print("|cffFFAA00You're not in a raid (RaidTools users' specs still come in).|r")
        return
    end
    local me  = UnitName and UnitName("player") or ""
    local db  = RT.Store.Roster()
    local sent = 0
    local hasRT = RT_SYNC_MEMBERS or {}
    for i = 1, n do
        local pname, _, _, _, _, classToken = GetRaidRosterInfo(i)
        if pname and pname ~= "" and pname ~= me then
            local known = db[pname] and db[pname].spec
            if hasRT[pname] then
                -- déjà RaidTools : répond en silence via addon, pas de whisper
            elseif not (onlyMissing and known and known ~= "") then
                WB.specPending[pname] = true
                -- envoi étalé (anti-spam / déconnexion) : 0.4s entre chaque
                local target = pname
                local cls = classToken or (db[pname] and db[pname].class) or ""
                local msg = WB.specQuestion(cls)
                RT.After(sent * 0.4, function()
                    SendChatMessage(RT_ChatSafe(msg), "WHISPER", nil, target)
                end)
                sent = sent + 1
            end
        end
    end
    RT.Print("|cff44CCFF[Spec]|r Request: " .. sent .. " whisper(s) sent; RaidTools users reply silently. Answers fill the roster.")
end

-- Point d'entrée global : appelable depuis le Roster (bouton Auto-roles) ou
-- tout autre module, même si l'onglet WhisperBot n'a jamais été ouvert.
function RT3_AskSpecs(onlyMissing) return WB.askSpecs(onlyMissing) end

-- Traite la réponse d'un joueur à qui on a demandé sa spé.
function WB.handleSpecReply(sender, text)
    WB.specPending[sender] = nil
    local db   = RT.Store.Roster()
    local cls  = db[sender] and db[sender].class or ""
    local spec = WB.specFromText(text)
    if not spec then
        -- pas de token reconnu : on stocke le texte brut, le rôle est déduit si possible
        spec = text
    end
    if RT3_SetPlayerSpec then RT3_SetPlayerSpec(sender, nil, spec) end
    local role = (db[sender] and db[sender].role) or "?"
    SendChatMessage(RT_ChatSafe("Thanks! Spec recorded: " .. spec .. " (" .. role .. ")."), "WHISPER", nil, sender)
    WB.addLog("|cff44CCFF[Spec]|r " .. sender .. " = " .. spec .. " -> " .. role)
end

-- ============================================================
-- LFM (annonce de recrutement) + Compo (annonce de composition)
-- ============================================================
WB.LFM_CHANS  = { "SAY", "YELL", "GUILD", "WORLD", "LFG" }
WB.LFM_LABELS = { SAY="Say", YELL="Yell", GUILD="Guild", WORLD="World", LFG="LFG" }

-- Places encore à pourvoir (max - actuels), jamais négatif.
function WB.remainingSlots(bd)
    local s = (bd.recruit and bd.recruit.slots) or {}
    local function rem(k) local v = (s[k] or 0) - (WB.counts[k] or 0); if v < 0 then v = 0 end; return v end
    return rem("tank"), rem("heal"), rem("dps")
end

-- Construit le texte LFM en remplaçant {tank} {heal} {dps}.
function WB.buildLFMText(bd)
    local msg = (bd.lfm and bd.lfm.msg) or ""
    if msg == "" then return "" end
    local t, h, d = WB.remainingSlots(bd)
    msg = string.gsub(msg, "{tank}", tostring(t))
    msg = string.gsub(msg, "{heal}", tostring(h))
    msg = string.gsub(msg, "{dps}",  tostring(d))
    return msg
end

-- Résout (chatType, chanArg) pour SendChatMessage selon le canal choisi.
function WB.resolveChannel(key)
    if key == "WORLD" then
        local idx = GetChannelName and GetChannelName("World") or 0
        if idx and idx > 0 then return "CHANNEL", idx end
        return nil
    elseif key == "LFG" then
        local idx = GetChannelName and (GetChannelName("LookingForGroup") or GetChannelName("World")) or 0
        if idx and idx > 0 then return "CHANNEL", idx end
        return nil
    elseif key == "GUILD" then
        return "GUILD", nil
    elseif key == "YELL" then
        return "YELL", nil
    end
    return "SAY", nil
end

function WB.postLFM(bd)
    local text = WB.buildLFMText(bd)
    if text == "" then
        RT.Print("|cffFFAA00[LFM] Type your LFM message in the field first.|r")
        return
    end
    local key = (bd.lfm and bd.lfm.channel) or "SAY"
    local ctype, carg = WB.resolveChannel(key)
    if not ctype then
        RT.Print("|cffFF4444[LFM] Channel '" .. (WB.LFM_LABELS[key] or key) .. "' not found (not joined?). Try Say/Yell.|r")
        return
    end
    SendChatMessage(RT_ChatSafe(text), ctype, nil, carg)
    WB.addLog("|cff66DD66[LFM " .. (WB.LFM_LABELS[key] or key) .. "]|r " .. text)
end

-- Compte la composition depuis le roster RT.
function WB.buildCompoText()
    local db = RT.Store.Roster()
    local c = { Tank=0, Heal=0, Melee=0, Ranged=0, DPS=0 }
    local total = 0
    for _, data in pairs(db) do
        local r = RT.NormRole(data.role or "DPS")
        c[r] = (c[r] or 0) + 1
        total = total + 1
    end
    return "Comp: " .. c.Tank .. " Tank, " .. c.Heal .. " Heal, " ..
           c.Melee .. " Melee, " .. c.Ranged .. " Ranged" ..
           (c.DPS > 0 and (", " .. c.DPS .. " DPS") or "") ..
           "  (" .. total .. ")"
end

-- Annonce la compo dans le chat du raid (ou groupe).
function WB.announceCompo()
    local text = WB.buildCompoText()
    local chan = "SAY"
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then chan = "RAID"
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then chan = "PARTY" end
    SendChatMessage(RT_ChatSafe(text), chan, nil, nil)
    WB.addLog("|cff88CCFF[Comp]|r " .. text)
end

function WB.getData()
    local db = RT.Store.DB()
    if not db.v3bot then
        db.v3bot = {
            enabled    = false,
            autoinvite = false,
            templates  = {
                loot = "Your loot assignment will be announced before the pull.",
                join = "Welcome! One moment, I'm checking your application.",
                info = "Whisper ?join to apply for the raid.",
            },
            recruit = { minGear="phase1", slots={ tank=2, heal=6, dps=22 } },
            lfm     = { msg="LFM raid - need {tank} tank {heal} heal {dps} dps - /w me", channel="SAY" },
        }
    end
    if db.v3bot.autoinvite == nil then db.v3bot.autoinvite = false end
    if not db.v3bot.recruit then
        db.v3bot.recruit = { minGear="phase1", slots={ tank=2, heal=6, dps=22 } }
    end
    if not db.v3bot.recruit.slots then
        db.v3bot.recruit.slots = { tank=2, heal=6, dps=22 }
    end
    if not db.v3bot.lfm then
        db.v3bot.lfm = { msg="LFM raid - need {tank} tank {heal} heal {dps} dps - /w me", channel="SAY" }
    end
    if db.v3bot.tacAuto == nil then db.v3bot.tacAuto = true end
    -- Migration FR → EN : remplace UNIQUEMENT les textes par défaut non
    -- personnalisés (ceux encore égaux aux anciens défauts français).
    db.v3bot.templates = db.v3bot.templates or {}
    local OLD = {
        loot = "Ton attribution sera annoncee avant le pull.",
        join = "Bienvenue ! Un instant, je verifie ton dossier.",
        info = "Tape ?join pour postuler au raid.",
    }
    local NEWT = {
        loot = "Your loot assignment will be announced before the pull.",
        join = "Welcome! One moment, I'm checking your application.",
        info = "Whisper ?join to apply for the raid.",
    }
    for k, v in pairs(OLD) do
        if db.v3bot.templates[k] == v then db.v3bot.templates[k] = NEWT[k] end
    end
    if db.v3bot.lfm.msg == "LFM raid - besoin {tank} tank {heal} heal {dps} dps - /w moi" then
        db.v3bot.lfm.msg = "LFM raid - need {tank} tank {heal} heal {dps} dps - /w me"
    end
    return db.v3bot
end

function WB.addLog(line)
    table.insert(WB.log, line)
    if table.getn(WB.log) > 40 then table.remove(WB.log, 1) end
    if WB.disp then WB.disp:SetText(table.concat(WB.log, "\n")) end
end

function WB.updateCounts(bd)
    if not WB.cDisp then return end
    local s = (bd.recruit and bd.recruit.slots) or { tank=0, heal=0, dps=0 }
    WB.cDisp:SetText(
        "|cffFF8888Tank " .. WB.counts.tank .. "/" .. (s.tank or 0) .. "|r   " ..
        "|cff88FF88Heal " .. WB.counts.heal .. "/" .. (s.heal or 0) .. "|r   " ..
        "|cffAAAAFFDPS "  .. WB.counts.dps  .. "/" .. (s.dps  or 0) .. "|r"
    )
end

function WB.parseGear(cmd)
    if string.find(cmd, "phase2") or string.find(cmd, "p2") or cmd == "2" then
        return "phase2"
    elseif string.find(cmd, "phase1") or string.find(cmd, "p1") or cmd == "1" then
        return "phase1"
    elseif string.find(cmd, "pregear") or string.find(cmd, "pre") or string.find(cmd, "p0") or cmd == "0" then
        return "pregear"
    end
    return nil
end

function WB.parseRole(cmd)
    if string.find(cmd, "^tank") or string.find(cmd, "^mt") or string.find(cmd, "^ot") then
        return "tank"
    elseif string.find(cmd, "^heal") or string.find(cmd, "^soig") or string.find(cmd, "^soin") then
        return "heal"
    elseif string.find(cmd, "^dps") or string.find(cmd, "^cac") or
           string.find(cmd, "^mel") or string.find(cmd, "^rdps") or
           string.find(cmd, "^dd") then
        return "dps"
    end
    return nil
end

function WB.recruitStep(sender, cmd, bd)
    local state = WB.pending[sender]
    if not state then return end
    local rc = bd.recruit or {}

    if state.step == "waiting_gear" then
        local gear = WB.parseGear(cmd)
        if not gear then
            SendChatMessage("I didn't get that. Reply: pregear / phase1 / phase2", "WHISPER", nil, sender)
            WB.addLog("|cffAAAAFF[" .. sender .. "]|r " .. cmd .. " -> (unknown gear)")
            return
        end
        local minRank  = WB.GEAR_RANK[rc.minGear or "phase1"] or 2
        local candRank = WB.GEAR_RANK[gear] or 0
        if candRank < minRank then
            WB.pending[sender] = nil
            local needed = WB.GEAR_LABEL[rc.minGear or "phase1"] or "Phase 1"
            SendChatMessage("Sorry! Minimum gear required: " .. needed .. ". Keep gearing up!", "WHISPER", nil, sender)
            WB.addLog("|cffFF4444[DECLINED gear]|r " .. sender .. " (" .. (WB.GEAR_LABEL[gear] or gear) .. ")")
        else
            WB.pending[sender].step = "waiting_role"
            WB.pending[sender].gear = gear
            local s   = rc.slots or {}
            local msg = "Gear OK (" .. (WB.GEAR_LABEL[gear] or gear) .. ")! Which role? (tank/heal/dps)" ..
                        "  [Tank " .. WB.counts.tank .. "/" .. (s.tank or 0) ..
                        " Heal " .. WB.counts.heal .. "/" .. (s.heal or 0) ..
                        " DPS "  .. WB.counts.dps  .. "/" .. (s.dps  or 0) .. "]"
            SendChatMessage(msg, "WHISPER", nil, sender)
            WB.addLog("|cffFFD700[" .. sender .. "]|r gear=" .. (WB.GEAR_LABEL[gear] or gear) .. " -> role?")
        end

    elseif state.step == "waiting_role" then
        if cmd == "?cancel" or cmd == "cancel" or cmd == "annuler" then
            WB.pending[sender] = nil
            SendChatMessage("Application cancelled.", "WHISPER", nil, sender)
            WB.addLog("|cff888888[" .. sender .. "]|r cancelled")
            return
        end
        local role = WB.parseRole(cmd)
        if not role then
            SendChatMessage("I didn't get that. Reply: tank / heal / dps", "WHISPER", nil, sender)
            WB.addLog("|cffAAAAFF[" .. sender .. "]|r " .. cmd .. " -> (unknown role)")
            return
        end
        local s       = rc.slots or {}
        local slotMax = s[role] or 0
        local slotCur = WB.counts[role] or 0
        if slotCur >= slotMax then
            WB.pending[sender] = nil
            local alts = {}
            for _, r in ipairs({"tank","heal","dps"}) do
                if (WB.counts[r] or 0) < (s[r] or 0) then
                    table.insert(alts, string.upper(r))
                end
            end
            local altStr = table.getn(alts) > 0 and ("  Open: " .. table.concat(alts," / ")) or "  Raid is full."
            SendChatMessage(string.upper(role) .. " spots are full (" .. slotCur .. "/" .. slotMax .. ")." .. altStr, "WHISPER", nil, sender)
            WB.addLog("|cffFF8844[FULL " .. string.upper(role) .. "]|r " .. sender)
        else
            WB.counts[role] = slotCur + 1
            WB.roster[sender] = { role=role, gear=state.gear }
            WB.pending[sender] = nil
            InviteByName(sender)
            SendChatMessage("Welcome! Accepted as " .. string.upper(role) .. " (" .. (WB.GEAR_LABEL[state.gear] or "?") .. "). Invite sent!", "WHISPER", nil, sender)
            WB.addLog("|cff44FF88[ACCEPTED " .. string.upper(role) .. "]|r " .. sender)
            WB.updateCounts(bd)
        end
    end
end

-- ============================================================
-- Tactics hub (inspiré de Tactica) : détection du boss ciblé,
-- fenêtre de post rapide, préview locale, tactiques custom.
-- ============================================================

WB.tacSeen = {}   -- boss déjà suggérés cette session (anti-spam)

-- Tactique correspondant à la cible courante (hostile, vivante) — match exact.
function WB.tacDetect()
    if not UnitExists or not UnitExists("target") then return nil end
    if UnitIsDead and UnitIsDead("target") then return nil end
    if UnitCanAttack and not UnitCanAttack("player", "target") then return nil end
    local tname = UnitName("target")
    if not tname or tname == "" then return nil end
    if RT_Tactics and RT_Tactics.Find then
        local t = RT_Tactics.Find(tname)
        -- Find fait aussi du match partiel : ne garde que l'exact (anti faux-positif)
        if t and string.lower(t.boss or "") == string.lower(tname) then return t end
    end
    return nil
end

function WB.tacFmt(t)
    if not t then return "|cff888888Select a boss on the left, or target one in-game.|r" end
    local L = { "|cffFFD700" .. (t.boss or "?") .. "|r  |cff888888" .. (t.raid or "") .. "|r", " " }
    for i = 1, table.getn(t.lines or {}) do
        table.insert(L, "|cffDDDDDD" .. t.lines[i] .. "|r")
    end
    return table.concat(L, "\n")
end

function WB.tacSelect(t)
    WB.tacSel = t
    if WB.tacFrame then
        if WB.tacFrame._prev then WB.tacFrame._prev:SetText(WB.tacFmt(t)) end
        if WB.tacFrame._custEB and t then WB.tacFrame._custEB:SetText(t.boss or "") end
    end
end

-- Poste la tactique sélectionnée. channel="SELF" = préview locale dans le chat.
function WB.tacPost(channel)
    local t = WB.tacSel
    if not t then RT.Print("|cffFFAA00[Tactics] Select a boss first.|r") return end
    if channel == "SELF" then
        RT.Print("|cffFFD700[Tactics preview] " .. t.boss .. "|r")
        for i = 1, table.getn(t.lines or {}) do RT.Print("  " .. t.lines[i]) end
        return
    end
    if RT_Tactics and RT_Tactics.Post then RT_Tactics.Post(t.boss, channel) end
end

-- Ouvre (et crée au besoin) la fenêtre Tactics. preselect = tactique à afficher.
function WB.tacOpen(preselect)
    if not WB.tacFrame then
        local f = CreateFrame("Frame", "RT3_WBTacFrame", UIParent)
        WB.tacFrame = f
        f:SetWidth(600) f:SetHeight(430)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        f:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0.05, 0.05, 0.09, 0.96)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", f, "TOP", 0, -10)
        title:SetText("|cffFFD700Boss Tactics|r  |cff666666— post strategies to your raid|r")

        local closeB = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeB:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

        -- Auto-detect toggle
        local autoBtn = RT.UI.Button(f, {
            text = "Auto-detect: ON", width = 122, height = 20, color = { 0.10, 0.50, 0.10 },
            anchor = { "TOPLEFT", f, "TOPLEFT", 12, -28 },
            tooltip = "When ON: targeting a raid boss (while in a group, out of combat) opens this window with its strategy preselected.",
        })
        autoBtn:SetScript("OnClick", function()
            local bd = WB.getData()
            bd.tacAuto = not bd.tacAuto
            local tex = autoBtn:GetNormalTexture()
            if bd.tacAuto then
                autoBtn:SetText("Auto-detect: ON")
                if tex then tex:SetVertexColor(0.10, 0.50, 0.10) end
            else
                autoBtn:SetText("Auto-detect: OFF")
                if tex then tex:SetVertexColor(0.45, 0.15, 0.10) end
            end
        end)
        f._autoBtn = autoBtn

        RT.UI.Button(f, {
            text = "Use my target", width = 108, height = 20, color = { 0.55, 0.35, 0.10 },
            anchor = { "TOPLEFT", f, "TOPLEFT", 140, -28 },
            tooltip = "Selects the strategy matching your current target.",
            onClick = function()
                local t = WB.tacDetect()
                if t then WB.tacSelect(t)
                else RT.Print("|cffFFAA00[Tactics] No known boss targeted.|r") end
            end,
        })

        -- Search + boss list (left)
        local search = CreateFrame("EditBox", "RT3_WBTacSearch", f, "InputBoxTemplate")
        search:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -54)
        search:SetWidth(200) search:SetHeight(20)
        search:SetAutoFocus(false)
        search:SetScript("OnEscapePressed", function() search:ClearFocus() end)

        local scroll, child = RT.UI.ScrollArea(f, {
            name = "RT3_WBTacScroll",
            anchor = { "TOPLEFT", f, "TOPLEFT", 12, -78 },
            childWidth = 210,
        })
        scroll:SetWidth(220)
        scroll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 66)

        local list = RT.UI.List(child, {
            rowHeight = 17, gap = 1,
            makeRow = function(l)
                local b = CreateFrame("Button", nil, l, "UIPanelButtonTemplate")
                b:SetHeight(17)
                local fs = b:GetFontString()
                if fs then fs:SetPoint("LEFT", b, "LEFT", 4, 0) end
                return b
            end,
            fillRow = function(row, item)
                local fs = row:GetFontString()
                if item.type == "header" then
                    row:SetText("|cffFFD700" .. (item.raid or "?") .. "|r")
                    row:EnableMouse(false)
                    local nt = row:GetNormalTexture()
                    local ht = row:GetHighlightTexture()
                    if nt then nt:SetAlpha(0) end
                    if ht then ht:SetAlpha(0) end
                else
                    row:SetText("  " .. (item.boss or "?"))
                    row:EnableMouse(true)
                    local nt = row:GetNormalTexture()
                    local ht = row:GetHighlightTexture()
                    if nt then nt:SetAlpha(1) end
                    if ht then ht:SetAlpha(1) end
                    local tac = item
                    row:SetScript("OnClick", function() WB.tacSelect(tac) end)
                end
                if fs then fs:SetJustifyH("LEFT") end
            end,
        })
        list:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
        list:SetWidth(205)

        local function refreshList()
            local query = search:GetText() or ""
            local items = {}
            local all = (RT_Tactics and RT_Tactics.FindAll) and RT_Tactics.FindAll(query) or {}
            if string.len(query) == 0 then
                local byRaid, order = {}, {}
                for i = 1, table.getn(all) do
                    local t = all[i]
                    local r = t.raid or "Misc"
                    if not byRaid[r] then byRaid[r] = {}; table.insert(order, r) end
                    table.insert(byRaid[r], t)
                end
                table.sort(order)
                for ri = 1, table.getn(order) do
                    table.insert(items, { type = "header", raid = order[ri] })
                    local bosses = byRaid[order[ri]]
                    table.sort(bosses, function(a, b) return (a.boss or "") < (b.boss or "") end)
                    for bi = 1, table.getn(bosses) do table.insert(items, bosses[bi]) end
                end
            else
                items = all
            end
            list:SetItems(items)
            child:SetHeight(list:GetHeight() or 1)
        end
        search:SetScript("OnTextChanged", refreshList)
        f._refreshList = refreshList

        -- Preview (right)
        local prev = RT.UI.TextScroll(f, {
            name = "RT3_WBTacPreview",
            anchor = { "TOPLEFT", f, "TOPLEFT", 246, -54 },
            width = 320, font = "GameFontHighlightSmall",
        })
        prev.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 66)
        f._prev = prev

        -- Custom tactic row
        local custLb = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        custLb:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 44)
        custLb:SetText("|cff69CCF0Custom:|r boss name + text, Save. Custom entries appear in the list and in ?strat.")

        local custEB = CreateFrame("EditBox", "RT3_WBTacCustBoss", f, "InputBoxTemplate")
        custEB:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 22)
        custEB:SetWidth(120) custEB:SetHeight(18) custEB:SetAutoFocus(false)
        custEB:SetScript("OnEscapePressed", function() custEB:ClearFocus() end)
        f._custEB = custEB

        local custTxt = CreateFrame("EditBox", "RT3_WBTacCustText", f, "InputBoxTemplate")
        custTxt:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 146, 22)
        custTxt:SetWidth(250) custTxt:SetHeight(18) custTxt:SetAutoFocus(false)
        custTxt:SetScript("OnEscapePressed", function() custTxt:ClearFocus() end)
        f._custTxt = custTxt

        RT.UI.Button(f, {
            text = "Save", width = 52, height = 20, color = { 0.15, 0.50, 0.20 },
            anchor = { "BOTTOMLEFT", f, "BOTTOMLEFT", 402, 21 },
            tooltip = "Saves (or replaces) a custom tactic for this boss name.",
            onClick = function()
                local b = custEB:GetText() or ""
                local x = custTxt:GetText() or ""
                if RT_Tactics and RT_Tactics.AddCustom and RT_Tactics.AddCustom(b, x) then
                    custTxt:SetText("")
                    if f._refreshList then f._refreshList() end
                else
                    RT.Print("|cffFFAA00[Tactics] Enter a boss name AND a tactic text.|r")
                end
            end,
        })
        RT.UI.Button(f, {
            text = "Delete", width = 58, height = 20, color = { 0.50, 0.15, 0.10 },
            anchor = { "BOTTOMLEFT", f, "BOTTOMLEFT", 458, 21 },
            tooltip = "Deletes the custom tactic with this boss name.",
            onClick = function()
                if RT_Tactics and RT_Tactics.DeleteCustom then
                    RT_Tactics.DeleteCustom(custEB:GetText() or "")
                    if f._refreshList then f._refreshList() end
                end
            end,
        })

        -- Bottom action row
        RT.UI.Button(f, {
            text = "Post /Raid", width = 96, height = 22, color = { 1.00, 0.55, 0.20 },
            anchor = { "BOTTOMLEFT", f, "BOTTOMLEFT", 246, 0 },
            onClick = function() WB.tacPost("RAID") end,
        })
        RT.UI.Button(f, {
            text = "Post /Party", width = 96, height = 22,
            anchor = { "BOTTOMLEFT", f, "BOTTOMLEFT", 346, 0 },
            onClick = function() WB.tacPost("PARTY") end,
        })
        RT.UI.Button(f, {
            text = "Preview", width = 80, height = 22, color = { 0.30, 0.40, 0.55 },
            anchor = { "BOTTOMLEFT", f, "BOTTOMLEFT", 446, 0 },
            tooltip = "Prints the strategy only for you (chat), without sending anything to the raid.",
            onClick = function() WB.tacPost("SELF") end,
        })
    end

    -- refresh state
    local bd = WB.getData()
    local autoBtn = WB.tacFrame._autoBtn
    if autoBtn then
        local tex = autoBtn:GetNormalTexture()
        if bd.tacAuto then
            autoBtn:SetText("Auto-detect: ON")
            if tex then tex:SetVertexColor(0.10, 0.50, 0.10) end
        else
            autoBtn:SetText("Auto-detect: OFF")
            if tex then tex:SetVertexColor(0.45, 0.15, 0.10) end
        end
    end
    if WB.tacFrame._refreshList then WB.tacFrame._refreshList() end
    if preselect then WB.tacSelect(preselect)
    else WB.tacSelect(WB.tacSel) end
    WB.tacFrame:Show()
end

-- Event frame (stored in WB, not as a chunk-level local)
WB.frame = CreateFrame("Frame", "RT3_WBFrame")
WB.frame:RegisterEvent("CHAT_MSG_WHISPER")
WB.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
WB.frame:SetScript("OnEvent", function()
    if event == "PLAYER_TARGET_CHANGED" then
        -- Suggestion façon Tactica : boss connu ciblé → ouvre la fenêtre (1x/boss)
        local bd = WB.getData()
        if not bd.tacAuto then return end
        if UnitAffectingCombat and UnitAffectingCombat("player") then return end
        local grp = (GetNumRaidMembers and GetNumRaidMembers() or 0)
                  + (GetNumPartyMembers and GetNumPartyMembers() or 0)
        if grp == 0 then return end
        local t = WB.tacDetect()
        if t and not WB.tacSeen[t.boss] then
            WB.tacSeen[t.boss] = true
            RT.Print("|cffFFD700[Tactics]|r Boss detected: |cffFF7D0A" .. t.boss .. "|r")
            WB.tacOpen(t)
        end
        return
    end
    if event ~= "CHAT_MSG_WHISPER" then return end

    local msg    = arg1 or ""
    local sender = arg2 or ""

    -- Réponse à une demande de spé (capturée même si le BOT est OFF)
    if WB.specPending[sender] then
        WB.handleSpecReply(sender, msg)
        return
    end

    local bd = WB.getData()
    if not bd.enabled then return end

    local cmd    = string.lower(msg)
    cmd = string.gsub(cmd, "^%s+", "")
    cmd = string.gsub(cmd, "%s+$", "")
    -- Accepte les commandes avec OU sans préfixe (?, !, ., /) et espaces:
    -- "join", "?join", "! join", "/join" deviennent tous "join"
    local c2 = string.gsub(cmd, "^[%?%!%./]+%s*", "")

    -- Recruitment conversation in progress?
    if bd.autoinvite and WB.pending[sender] then
        WB.recruitStep(sender, c2, bd)
        return
    end

    local reply  = nil
    local didAct = false

    if string.find(c2, "^loot") or string.find(c2, "^attrib") then
        reply = bd.templates.loot or ""
    elseif string.find(c2, "^sr") then
        local db2 = RT.Store.DB()
        local sr  = (db2.softres or db2.sr or {})[sender]
        if sr then
            if type(sr) == "table" then
                local items = {}
                for _, v in pairs(sr) do table.insert(items, tostring(v)) end
                reply = "Your SR: " .. table.concat(items, ", ")
            else
                reply = "Your SR: " .. tostring(sr)
            end
        else
            reply = "No SR recorded for you."
        end
    elseif string.find(c2, "^join") or string.find(c2, "^postuler") or string.find(c2, "^recrutement") then
        if bd.autoinvite then
            if WB.roster[sender] then
                reply = "You're already in the raid!"
            else
                WB.pending[sender] = { step="waiting_gear" }
                local needed = WB.GEAR_LABEL[bd.recruit and bd.recruit.minGear or "phase1"] or "Phase 1"
                reply = "Hi! What's your gear? (pregear / phase1 / phase2)  -  Required: " .. needed
            end
        else
            reply = bd.templates.join or ""
        end
    elseif string.find(c2, "^info") then
        reply = bd.templates.info or ""
    elseif string.find(c2, "^spec") or string.find(c2, "^classe") then
        local n = GetNumRaidMembers and GetNumRaidMembers() or 0
        local found = false
        for i = 1, n do
            local pname, rk, sg, lv, cls = GetRaidRosterInfo(i)
            if pname == sender then
                found = true
                reply = "Class: " .. (cls or "?") .. " | Lvl: " .. (lv or "?") .. " | Group " .. (sg or "?")
                break
            end
        end
        if not found then reply = "You're not in the raid." end
    elseif string.find(c2, "^compo") or string.find(c2, "^comp") then
        reply = WB.buildCompoText()
    elseif string.find(c2, "^role") then
        local n = GetNumRaidMembers and GetNumRaidMembers() or 0
        local found = false
        for i = 1, n do
            local pname, rk, sg, lv, cls = GetRaidRosterInfo(i)
            if pname == sender then
                found = true
                local c = cls and string.upper(cls) or ""
                local r = "DPS"
                if c == "WARRIOR" then r = "Tank"
                elseif c == "DRUID" then r = "Tank/Heal/DPS"
                elseif c == "PALADIN" then r = "Tank/Heal/DPS"
                elseif c == "PRIEST" then r = "Heal"
                elseif c == "SHAMAN" then r = "Heal/DPS"
                end
                reply = "Suggested role: " .. r .. " (" .. (cls or "?") .. ")"
                break
            end
        end
        if not found then reply = "You're not in the raid." end
    elseif string.find(c2, "^groupe") or string.find(c2, "^group") then
        -- Cherche dans l'attribution calculée
        local found_g = nil
        if RT_AA_LAST and RT_AA_LAST.groups then
            for g = 1, 8 do
                local grp = RT_AA_LAST.groups[g] or {}
                for s = 1, table.getn(grp) do
                    if grp[s] == sender then found_g = g; break end
                end
                if found_g then break end
            end
        end
        -- Groupe en jeu (sous-groupe réel dans le raid)
        local raid_g = nil
        local nb = GetNumRaidMembers and GetNumRaidMembers() or 0
        for i = 1, nb do
            local pname, _, sg = GetRaidRosterInfo(i)
            if pname == sender then raid_g = sg; break end
        end
        if found_g then
            reply = "Assigned: Group " .. found_g
            if raid_g and tonumber(raid_g) ~= found_g then
                reply = reply .. "  (Currently in-game: Grp " .. raid_g .. ")"
            end
        elseif raid_g then
            reply = "Group " .. raid_g .. "  (no assignment computed)"
        else
            reply = "You're not in the raid."
        end
    elseif string.find(c2, "^mt") or string.find(c2, "^tank") then
        if RT_AA_LAST and RT_AA_LAST.tanks and table.getn(RT_AA_LAST.tanks) > 0 then
            local parts = {}
            for i = 1, table.getn(RT_AA_LAST.tanks) do
                table.insert(parts, "MT" .. i .. ": " .. RT_AA_LAST.tanks[i])
            end
            reply = table.concat(parts, "  -  ")
        else
            reply = "No tank assigned (run Setup Raid first)."
        end
    elseif string.find(c2, "^strat") then
        local boss = string.gsub(c2, "^strat%s*", "")
        if boss == "" then
            reply = "Usage: ?strat <boss name>"
        elseif RT_Tactics and RT_Tactics.FindAll then
            local res = RT_Tactics.FindAll(boss)
            if res and table.getn(res) > 0 then
                local lns   = res[1].lines or {}
                local count = math.min(table.getn(lns), 3)
                for li = 1, count do
                    SendChatMessage(RT_ChatSafe(lns[li]), "WHISPER", nil, sender)
                end
                didAct = true
                WB.addLog("|cff44FFFF[" .. sender .. "]|r !strat " .. boss)
            else
                reply = "No tactic for: " .. boss
            end
        else
            reply = "Tactics database unavailable."
        end
    end

    if reply and reply ~= "" then
        SendChatMessage(RT_ChatSafe(reply), "WHISPER", nil, sender)
        WB.addLog("|cffFFD700[" .. sender .. "]|r " .. msg .. " -> " .. reply)
    elseif not didAct then
        WB.addLog("|cff888888[" .. sender .. "]|r " .. msg)
    end
end)

RT.Modules.Register({
    id       = "whisperbot",
    title    = "WhisperBot",
    tip      = "Pug hub: auto recruitment (?join), multi-channel LFM, spec request, comp announce, boss tactics window with auto-detection, and auto replies (?mt ?group ?comp ?strat).",
    color    = { 1.00, 0.80, 0.20 },
    tabWidth = 90,

    build = function(panel)
        -- BOT toggle
        local tBtn = RT.UI.Button(panel, {
            text="BOT: OFF", width=100, height=28, color={0.55,0.15,0.10},
            anchor={"TOPLEFT",panel,"TOPLEFT",12,-10},
        })
        tBtn:SetScript("OnClick", function()
            local bd  = WB.getData()
            bd.enabled = not bd.enabled
            local tex  = tBtn:GetNormalTexture()
            if bd.enabled then
                tBtn:SetText("BOT: ON")
                if tex then tex:SetVertexColor(0.10,0.55,0.10) end
            else
                tBtn:SetText("BOT: OFF")
                if tex then tex:SetVertexColor(0.55,0.15,0.10) end
            end
        end)
        panel._wbToggle = tBtn

        -- RECRUITMENT toggle
        local aiBtn = RT.UI.Button(panel, {
            text="RECRUITMENT: OFF", width=148, height=28, color={0.25,0.25,0.55},
            anchor={"TOPLEFT",panel,"TOPLEFT",118,-10},
        })
        aiBtn:SetScript("OnClick", function()
            local bd  = WB.getData()
            bd.autoinvite = not bd.autoinvite
            local tex  = aiBtn:GetNormalTexture()
            if bd.autoinvite then
                aiBtn:SetText("RECRUITMENT: ON")
                if tex then tex:SetVertexColor(0.10,0.55,0.10) end
            else
                aiBtn:SetText("RECRUITMENT: OFF")
                if tex then tex:SetVertexColor(0.25,0.25,0.55) end
            end
        end)
        panel._wbAIBtn = aiBtn

        -- Button: ask the whole raid for their spec
        RT.UI.Button(panel, {
            text="Request specs", width=126, height=28, color={0.20,0.55,0.75},
            anchor={"TOPRIGHT",panel,"TOPRIGHT",-10,-10},
            tooltip="Whisper every raid member to ask their spec. Players who have RaidTools answer automatically; replies fill the roster and set the role.",
            onClick=function() WB.askSpecs(false) end,
        })

        -- Button: tactics hub (boss detection, quick post, customs)
        RT.UI.Button(panel, {
            text="Tactics", width=76, height=28, color={0.75,0.55,0.15},
            anchor={"TOPRIGHT",panel,"TOPRIGHT",-142,-10},
            tooltip="Opens the Boss Tactics window: browse/search all strategies, post to raid, preview, custom tactics, and auto-detection when you target a boss.",
            onClick=function() WB.tacOpen() end,
        })

        local infoL = panel:CreateFontString(nil,"OVERLAY","GameFontDisable")
        infoL:SetPoint("TOPLEFT",panel,"TOPLEFT",274,-14)
        infoL:SetText("?join ?spec ?role ?comp ?sr ?strat")

        -- ── Row 2: announcements (LFM / channel / comp) ────────────
        RT.UI.Button(panel, {
            text="Post LFM", width=104, height=22, color={0.20,0.55,0.30},
            anchor={"TOPLEFT",panel,"TOPLEFT",12,-44},
            tooltip="Posts your LFM message (field on the right) to the chosen channel. {tank} {heal} {dps} are replaced by the spots still open.",
            onClick=function() WB.postLFM(WB.getData()) end,
        })
        local chanBtn = RT.UI.Button(panel, {
            text="Channel: Say", width=104, height=22, color={0.30,0.40,0.55},
            anchor={"TOPLEFT",panel,"TOPLEFT",120,-44},
            tooltip="LFM broadcast channel: Say / Yell / Guild / World / LFG.",
        })
        chanBtn:SetScript("OnClick", function()
            local bd  = WB.getData()
            local cur = bd.lfm.channel or "SAY"
            local idx = 1
            for i = 1, table.getn(WB.LFM_CHANS) do
                if WB.LFM_CHANS[i] == cur then idx = i; break end
            end
            idx = idx + 1
            if idx > table.getn(WB.LFM_CHANS) then idx = 1 end
            bd.lfm.channel = WB.LFM_CHANS[idx]
            chanBtn:SetText("Channel: " .. (WB.LFM_LABELS[bd.lfm.channel] or bd.lfm.channel))
        end)
        panel._wbChanBtn = chanBtn

        RT.UI.Button(panel, {
            text="Announce comp", width=120, height=22, color={0.25,0.45,0.65},
            anchor={"TOPLEFT",panel,"TOPLEFT",228,-44},
            tooltip="Announces the current roster composition (Tank/Heal/Melee/Ranged) in raid chat.",
            onClick=function() WB.announceCompo() end,
        })

        -- Champ message LFM
        local lfmEB = CreateFrame("EditBox","RT3_WB_lfm",panel,"InputBoxTemplate")
        lfmEB:SetPoint("TOPLEFT",panel,"TOPLEFT",360,-44)
        lfmEB:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-12,-44)
        lfmEB:SetHeight(20) lfmEB:SetAutoFocus(false)
        lfmEB:SetScript("OnEscapePressed", function() lfmEB:ClearFocus() end)
        lfmEB:SetScript("OnTextChanged", function()
            local bd = WB.getData()
            bd.lfm.msg = lfmEB:GetText() or ""
        end)
        panel._wbLfmEB = lfmEB

        local s1 = panel:CreateTexture(nil,"BACKGROUND")
        s1:SetPoint("TOPLEFT",panel,"TOPLEFT",6,-72)
        s1:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-6,-72)
        s1:SetHeight(1) s1:SetTexture(0.3,0.3,0.5,0.6)

        -- Templates
        local TMPL = {
            {key="loot", label="?loot / ?attrib"},
            {key="join",  label="?join  (first reply)"},
            {key="info",  label="?info"},
        }
        panel._wbInputs = {}
        for i = 1, table.getn(TMPL) do
            local t  = TMPL[i]
            local oy = 76 + (i-1)*50
            local lb = panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            lb:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-oy)
            lb:SetText("|cff69CCF0" .. t.label .. "|r  :")
            local inp = CreateFrame("EditBox","RT3_WB_"..t.key,panel,"InputBoxTemplate")
            inp:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-oy-18)
            inp:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-10,-oy-18)
            inp:SetHeight(20) inp:SetAutoFocus(false)
            inp:SetScript("OnEscapePressed", function() inp:ClearFocus() end)
            local k = t.key
            inp:SetScript("OnTextChanged", function()
                local bd = WB.getData()
                bd.templates[k] = inp:GetText() or ""
            end)
            panel._wbInputs[t.key] = inp
        end

        local s2 = panel:CreateTexture(nil,"BACKGROUND")
        s2:SetPoint("TOPLEFT",panel,"TOPLEFT",6,-224)
        s2:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-6,-224)
        s2:SetHeight(1) s2:SetTexture(0.3,0.3,0.5,0.6)

        local rLbl = panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
        rLbl:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-228)
        rLbl:SetText("|cffFFD700Auto recruitment|r")

        RT.UI.Button(panel, {
            text="Reset counts", width=120, height=20, color={0.4,0.1,0.4},
            anchor={"TOPRIGHT",panel,"TOPRIGHT",-10,-226},
            onClick=function()
                WB.counts  = { tank=0, heal=0, dps=0 }
                WB.pending = {}
                WB.roster  = {}
                WB.updateCounts(WB.getData())
            end,
        })

        -- Min gear cycle button
        local mgBtn = CreateFrame("Button","RT3_WBMGBtn",panel,"UIPanelButtonTemplate")
        mgBtn:SetWidth(140) mgBtn:SetHeight(22)
        mgBtn:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-248)
        mgBtn:SetText("Min: Phase 1")
        mgBtn:SetScript("OnClick", function()
            local bd  = WB.getData()
            local cur = bd.recruit.minGear or "phase1"
            local nxt = "phase1"
            if cur == "pregear" then nxt = "phase1"
            elseif cur == "phase1" then nxt = "phase2"
            elseif cur == "phase2" then nxt = "pregear"
            end
            bd.recruit.minGear = nxt
            mgBtn:SetText("Min: " .. (WB.GEAR_LABEL[nxt] or nxt))
        end)
        panel._wbMGBtn = mgBtn

        -- Slot inputs
        local SLOTS = { {"tank","Tank",160}, {"heal","Heal",228}, {"dps","DPS",296} }
        panel._wbSlot = {}
        for i = 1, table.getn(SLOTS) do
            local sk, sn, ox = SLOTS[i][1], SLOTS[i][2], SLOTS[i][3]
            local sl = panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            sl:SetPoint("TOPLEFT",panel,"TOPLEFT",ox,-250)
            sl:SetText(sn..":")
            local inp = CreateFrame("EditBox","RT3_WBSl_"..sk,panel,"InputBoxTemplate")
            inp:SetPoint("TOPLEFT",panel,"TOPLEFT",ox+30,-248)
            inp:SetWidth(34) inp:SetHeight(20) inp:SetAutoFocus(false)
            inp:SetNumeric(true)
            inp:SetScript("OnEscapePressed", function() inp:ClearFocus() end)
            local kk = sk
            inp:SetScript("OnTextChanged", function()
                local bd = WB.getData()
                bd.recruit.slots[kk] = tonumber(inp:GetText()) or 0
                WB.updateCounts(bd)
            end)
            panel._wbSlot[sk] = inp
        end

        -- Count display
        local cD = panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
        cD:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-274)
        cD:SetText("|cffFF8888Tank 0/2|r   |cff88FF88Heal 0/6|r   |cffAAAAFFDPS 0/22|r")
        WB.cDisp = cD
        panel._wbCDisp = cD

        local s3 = panel:CreateTexture(nil,"BACKGROUND")
        s3:SetPoint("TOPLEFT",panel,"TOPLEFT",6,-292)
        s3:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-6,-292)
        s3:SetHeight(1) s3:SetTexture(0.3,0.3,0.5,0.6)

        RT.UI.Button(panel, {
            text="Clear Log", width=80, height=20, color={0.3,0.3,0.3},
            anchor={"TOPRIGHT",panel,"TOPRIGHT",-10,-296},
            onClick=function()
                WB.log = {}
                if WB.disp then WB.disp:SetText("") end
            end,
        })
        local logL = panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        logL:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-296)
        logL:SetText("|cffAAAAFFRecent activity:|r")

        local logD = RT.UI.TextScroll(panel, {
            name="RT3_WBLog", anchor={"TOPLEFT",panel,"TOPLEFT",8,-316},
            width=680, font="GameFontHighlightSmall",
        })
        logD.scroll:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-28,8)
        WB.disp = logD
        panel._wbLog = logD
    end,

    show = function(panel)
        local bd = WB.getData()
        if panel._wbToggle then
            local tex = panel._wbToggle:GetNormalTexture()
            if bd.enabled then
                panel._wbToggle:SetText("BOT: ON")
                if tex then tex:SetVertexColor(0.10,0.55,0.10) end
            else
                panel._wbToggle:SetText("BOT: OFF")
                if tex then tex:SetVertexColor(0.55,0.15,0.10) end
            end
        end
        if panel._wbAIBtn then
            local tex = panel._wbAIBtn:GetNormalTexture()
            if bd.autoinvite then
                panel._wbAIBtn:SetText("RECRUITMENT: ON")
                if tex then tex:SetVertexColor(0.10,0.55,0.10) end
            else
                panel._wbAIBtn:SetText("RECRUITMENT: OFF")
                if tex then tex:SetVertexColor(0.25,0.25,0.55) end
            end
        end
        if panel._wbInputs then
            for k, inp in pairs(panel._wbInputs) do
                inp:SetText((bd.templates and bd.templates[k]) or "")
            end
        end
        if panel._wbChanBtn then
            local key = (bd.lfm and bd.lfm.channel) or "SAY"
            panel._wbChanBtn:SetText("Channel: " .. (WB.LFM_LABELS[key] or key))
        end
        if panel._wbLfmEB then
            panel._wbLfmEB:SetText((bd.lfm and bd.lfm.msg) or "")
        end
        if panel._wbMGBtn then
            local rc = bd.recruit or {}
            panel._wbMGBtn:SetText("Min: " .. (WB.GEAR_LABEL[rc.minGear or "phase1"] or "Phase 1"))
        end
        if panel._wbSlot then
            local s = (bd.recruit and bd.recruit.slots) or {}
            for key, inp in pairs(panel._wbSlot) do
                inp:SetText(tostring(s[key] or 0))
            end
        end
        WB.cDisp = panel._wbCDisp
        WB.updateCounts(bd)
        WB.disp = panel._wbLog
        if WB.disp and table.getn(WB.log) > 0 then
            WB.disp:SetText(table.concat(WB.log, "\n"))
        end
    end,
})
