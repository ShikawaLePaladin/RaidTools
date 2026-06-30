-- ============================================================
-- RT v3 - modules/WhisperBot.lua
-- Bot whisper + recrutement intelligent (1 seul local chunk)
-- ============================================================

local WB = {
    log     = {},
    disp    = nil,   -- FontString log
    pending = {},    -- { [name] = { step, gear } }
    roster  = {},    -- { [name] = { role, gear } }
    counts  = { tank=0, heal=0, dps=0 },
    cDisp   = nil,   -- FontString compteurs
    GEAR_RANK  = { pregear=1, phase1=2, phase2=3 },
    GEAR_LABEL = { pregear="Pre-Gear", phase1="Phase 1", phase2="Phase 2" },
}

function WB.getData()
    local db = RT.Store.DB()
    if not db.v3bot then
        db.v3bot = {
            enabled    = false,
            autoinvite = false,
            templates  = {
                loot = "Ton attribution sera annoncee avant le pull.",
                join = "Bienvenue ! Un instant, je verifie ton dossier.",
                info = "Tape ?join pour postuler au raid.",
            },
            recruit = { minGear="phase1", slots={ tank=2, heal=6, dps=22 } },
        }
    end
    if db.v3bot.autoinvite == nil then db.v3bot.autoinvite = false end
    if not db.v3bot.recruit then
        db.v3bot.recruit = { minGear="phase1", slots={ tank=2, heal=6, dps=22 } }
    end
    if not db.v3bot.recruit.slots then
        db.v3bot.recruit.slots = { tank=2, heal=6, dps=22 }
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
            SendChatMessage("Je n'ai pas compris. Reponds: pregear / phase1 / phase2", "WHISPER", nil, sender)
            WB.addLog("|cffAAAAFF[" .. sender .. "]|r " .. cmd .. " -> (gear inconnu)")
            return
        end
        local minRank  = WB.GEAR_RANK[rc.minGear or "phase1"] or 2
        local candRank = WB.GEAR_RANK[gear] or 0
        if candRank < minRank then
            WB.pending[sender] = nil
            local needed = WB.GEAR_LABEL[rc.minGear or "phase1"] or "Phase 1"
            SendChatMessage("Desolee ! Gear minimum requis: " .. needed .. ". Continue a progresser !", "WHISPER", nil, sender)
            WB.addLog("|cffFF4444[REFUSE gear]|r " .. sender .. " (" .. (WB.GEAR_LABEL[gear] or gear) .. ")")
        else
            WB.pending[sender].step = "waiting_role"
            WB.pending[sender].gear = gear
            local s   = rc.slots or {}
            local msg = "Gear OK (" .. (WB.GEAR_LABEL[gear] or gear) .. ") ! Quel role ? (tank/heal/dps)" ..
                        "  [Tank " .. WB.counts.tank .. "/" .. (s.tank or 0) ..
                        " Heal " .. WB.counts.heal .. "/" .. (s.heal or 0) ..
                        " DPS "  .. WB.counts.dps  .. "/" .. (s.dps  or 0) .. "]"
            SendChatMessage(msg, "WHISPER", nil, sender)
            WB.addLog("|cffFFD700[" .. sender .. "]|r gear=" .. (WB.GEAR_LABEL[gear] or gear) .. " -> role?")
        end

    elseif state.step == "waiting_role" then
        if cmd == "?cancel" or cmd == "cancel" or cmd == "annuler" then
            WB.pending[sender] = nil
            SendChatMessage("Candidature annulee.", "WHISPER", nil, sender)
            WB.addLog("|cff888888[" .. sender .. "]|r annule")
            return
        end
        local role = WB.parseRole(cmd)
        if not role then
            SendChatMessage("Je n'ai pas compris. Reponds: tank / heal / dps", "WHISPER", nil, sender)
            WB.addLog("|cffAAAAFF[" .. sender .. "]|r " .. cmd .. " -> (role inconnu)")
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
            local altStr = table.getn(alts) > 0 and ("  Dispo: " .. table.concat(alts," / ")) or "  Raid complet."
            SendChatMessage("Places " .. string.upper(role) .. " completes (" .. slotCur .. "/" .. slotMax .. ")." .. altStr, "WHISPER", nil, sender)
            WB.addLog("|cffFF8844[PLEIN " .. string.upper(role) .. "]|r " .. sender)
        else
            WB.counts[role] = slotCur + 1
            WB.roster[sender] = { role=role, gear=state.gear }
            WB.pending[sender] = nil
            InviteByName(sender)
            SendChatMessage("Bienvenue ! Accepte en tant que " .. string.upper(role) .. " (" .. (WB.GEAR_LABEL[state.gear] or "?") .. "). Invitation envoyee !", "WHISPER", nil, sender)
            WB.addLog("|cff44FF88[ACCEPTE " .. string.upper(role) .. "]|r " .. sender)
            WB.updateCounts(bd)
        end
    end
end

-- Event frame (stored in WB, not as a chunk-level local)
WB.frame = CreateFrame("Frame", "RT3_WBFrame")
WB.frame:RegisterEvent("CHAT_MSG_WHISPER")
WB.frame:SetScript("OnEvent", function()
    if event ~= "CHAT_MSG_WHISPER" then return end
    local bd = WB.getData()
    if not bd.enabled then return end

    local msg    = arg1 or ""
    local sender = arg2 or ""
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
                reply = "Tes SR : " .. table.concat(items, ", ")
            else
                reply = "Ton SR : " .. tostring(sr)
            end
        else
            reply = "Aucun SR enregistre pour toi."
        end
    elseif string.find(c2, "^join") or string.find(c2, "^postuler") or string.find(c2, "^recrutement") then
        if bd.autoinvite then
            if WB.roster[sender] then
                reply = "Tu es deja dans le raid !"
            else
                WB.pending[sender] = { step="waiting_gear" }
                local needed = WB.GEAR_LABEL[bd.recruit and bd.recruit.minGear or "phase1"] or "Phase 1"
                reply = "Bonjour ! Quel est ton gear ? (pregear / phase1 / phase2)  -  Requis: " .. needed
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
                reply = "Classe: " .. (cls or "?") .. " | Niv: " .. (lv or "?") .. " | Groupe " .. (sg or "?")
                break
            end
        end
        if not found then reply = "Tu n'es pas dans le raid." end
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
                reply = "Role suggere: " .. r .. " (" .. (cls or "?") .. ")"
                break
            end
        end
        if not found then reply = "Tu n'es pas dans le raid." end
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
            reply = "Attrib: Groupe " .. found_g
            if raid_g and tonumber(raid_g) ~= found_g then
                reply = reply .. "  (Actuel en jeu: Grp " .. raid_g .. ")"
            end
        elseif raid_g then
            reply = "Groupe " .. raid_g .. "  (aucune attrib calculee)"
        else
            reply = "Tu n'es pas dans le raid."
        end
    elseif string.find(c2, "^mt") or string.find(c2, "^tank") then
        if RT_AA_LAST and RT_AA_LAST.tanks and table.getn(RT_AA_LAST.tanks) > 0 then
            local parts = {}
            for i = 1, table.getn(RT_AA_LAST.tanks) do
                table.insert(parts, "MT" .. i .. ": " .. RT_AA_LAST.tanks[i])
            end
            reply = table.concat(parts, "  -  ")
        else
            reply = "Aucun tank assigne (lance Setup Raid d'abord)."
        end
    elseif string.find(c2, "^strat") then
        local boss = string.gsub(c2, "^strat%s*", "")
        if boss == "" then
            reply = "Usage: ?strat <nom du boss>"
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
                reply = "Aucune tactique pour: " .. boss
            end
        else
            reply = "Base de tactiques indisponible."
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
    tip      = "Recrutement auto par message privé (?join) et réponses aux joueurs (?mt, ?groupe, ?strat). Active BOT + RECRUTEMENT.",
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

        -- RECRUTEMENT toggle
        local aiBtn = RT.UI.Button(panel, {
            text="RECRUTEMENT: OFF", width=148, height=28, color={0.25,0.25,0.55},
            anchor={"TOPLEFT",panel,"TOPLEFT",118,-10},
        })
        aiBtn:SetScript("OnClick", function()
            local bd  = WB.getData()
            bd.autoinvite = not bd.autoinvite
            local tex  = aiBtn:GetNormalTexture()
            if bd.autoinvite then
                aiBtn:SetText("RECRUTEMENT: ON")
                if tex then tex:SetVertexColor(0.10,0.55,0.10) end
            else
                aiBtn:SetText("RECRUTEMENT: OFF")
                if tex then tex:SetVertexColor(0.25,0.25,0.55) end
            end
        end)
        panel._wbAIBtn = aiBtn

        local infoL = panel:CreateFontString(nil,"OVERLAY","GameFontDisable")
        infoL:SetPoint("TOPLEFT",panel,"TOPLEFT",274,-14)
        infoL:SetText("?join · ?spec · ?role · ?sr · ?loot · ?info · ?strat <boss>")

        local s1 = panel:CreateTexture(nil,"BACKGROUND")
        s1:SetPoint("TOPLEFT",panel,"TOPLEFT",6,-44)
        s1:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-6,-44)
        s1:SetHeight(1) s1:SetTexture(0.3,0.3,0.5,0.6)

        -- Templates
        local TMPL = {
            {key="loot", label="?loot / ?attrib"},
            {key="join",  label="?join  (reponse initiale)"},
            {key="info",  label="?info"},
        }
        panel._wbInputs = {}
        for i = 1, table.getn(TMPL) do
            local t  = TMPL[i]
            local oy = 48 + (i-1)*50
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
        s2:SetPoint("TOPLEFT",panel,"TOPLEFT",6,-196)
        s2:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-6,-196)
        s2:SetHeight(1) s2:SetTexture(0.3,0.3,0.5,0.6)

        local rLbl = panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
        rLbl:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-200)
        rLbl:SetText("|cffFFD700Recrutement automatique|r")

        RT.UI.Button(panel, {
            text="Reset Compteurs", width=120, height=20, color={0.4,0.1,0.4},
            anchor={"TOPRIGHT",panel,"TOPRIGHT",-10,-198},
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
        mgBtn:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-220)
        mgBtn:SetText("Requis: Phase 1")
        mgBtn:SetScript("OnClick", function()
            local bd  = WB.getData()
            local cur = bd.recruit.minGear or "phase1"
            local nxt = "phase1"
            if cur == "pregear" then nxt = "phase1"
            elseif cur == "phase1" then nxt = "phase2"
            elseif cur == "phase2" then nxt = "pregear"
            end
            bd.recruit.minGear = nxt
            mgBtn:SetText("Requis: " .. (WB.GEAR_LABEL[nxt] or nxt))
        end)
        panel._wbMGBtn = mgBtn

        -- Slot inputs
        local SLOTS = { {"tank","Tank",160}, {"heal","Heal",228}, {"dps","DPS",296} }
        panel._wbSlot = {}
        for i = 1, table.getn(SLOTS) do
            local sk, sn, ox = SLOTS[i][1], SLOTS[i][2], SLOTS[i][3]
            local sl = panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            sl:SetPoint("TOPLEFT",panel,"TOPLEFT",ox,-222)
            sl:SetText(sn..":")
            local inp = CreateFrame("EditBox","RT3_WBSl_"..sk,panel,"InputBoxTemplate")
            inp:SetPoint("TOPLEFT",panel,"TOPLEFT",ox+30,-220)
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
        cD:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-246)
        cD:SetText("|cffFF8888Tank 0/2|r   |cff88FF88Heal 0/6|r   |cffAAAAFFDPS 0/22|r")
        WB.cDisp = cD
        panel._wbCDisp = cD

        local s3 = panel:CreateTexture(nil,"BACKGROUND")
        s3:SetPoint("TOPLEFT",panel,"TOPLEFT",6,-264)
        s3:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-6,-264)
        s3:SetHeight(1) s3:SetTexture(0.3,0.3,0.5,0.6)

        RT.UI.Button(panel, {
            text="Clear Log", width=80, height=20, color={0.3,0.3,0.3},
            anchor={"TOPRIGHT",panel,"TOPRIGHT",-10,-268},
            onClick=function()
                WB.log = {}
                if WB.disp then WB.disp:SetText("") end
            end,
        })
        local logL = panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        logL:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-268)
        logL:SetText("|cffAAAAFFActivite recente :|r")

        local logD = RT.UI.TextScroll(panel, {
            name="RT3_WBLog", anchor={"TOPLEFT",panel,"TOPLEFT",8,-288},
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
                panel._wbAIBtn:SetText("RECRUTEMENT: ON")
                if tex then tex:SetVertexColor(0.10,0.55,0.10) end
            else
                panel._wbAIBtn:SetText("RECRUTEMENT: OFF")
                if tex then tex:SetVertexColor(0.25,0.25,0.55) end
            end
        end
        if panel._wbInputs then
            for k, inp in pairs(panel._wbInputs) do
                inp:SetText((bd.templates and bd.templates[k]) or "")
            end
        end
        if panel._wbMGBtn then
            local rc = bd.recruit or {}
            panel._wbMGBtn:SetText("Requis: " .. (WB.GEAR_LABEL[rc.minGear or "phase1"] or "Phase 1"))
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
