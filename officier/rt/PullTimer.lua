-- ============================================================
-- RT v2 — PullTimer.lua
-- Compte à rebours de pull visible à tout le raid
-- Sync via Sync.lua (TIMER message)
-- BigWigs compatible (/bwpull N)
-- Compatible WoW 1.12 / TurtleWoW
-- ============================================================

RT_PT = RT_PT or {}

local PT_FRAME      = nil
local PT_RUNNING    = false
local PT_SECONDS    = 0
local PT_ELAPSED    = 0
local PT_SENDER     = ""

-- ── Frame visuelle ─────────────────────────────────────────
local function PT_CreateFrame()
    if PT_FRAME then return end

    local f = CreateFrame("Frame", "RT_PullTimerFrame", UIParent)
    f:SetWidth(200)
    f:SetHeight(90)
    f:SetPoint("TOP", UIParent, "TOP", 0, -180)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:Hide()
    PT_FRAME = f

    -- Fond semi-transparent
    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left=4, right=4, top=4, bottom=4 },
    })
    f:SetBackdropColor(0.0, 0.0, 0.0, 0.75)
    f:SetBackdropBorderColor(1.0, 0.3, 0.1, 1.0)

    -- Label "PULL DANS"
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOP", f, "TOP", 0, -8)
    label:SetText("|cffFFAA00PULL DANS|r")
    PT_FRAME.label = label

    -- Nombre (grand)
    local numText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    numText:SetPoint("CENTER", f, "CENTER", 0, 4)
    numText:SetFont("Fonts\\FRIZQT__.TTF", 48, "OUTLINE")
    numText:SetText("10")
    PT_FRAME.numText = numText

    -- Nom de l'RL qui a lancé
    local senderText = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    senderText:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)
    senderText:SetText("")
    PT_FRAME.senderText = senderText

    -- Barre de progression
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  5, 4)
    bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 4)
    bar:SetHeight(4)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1.0, 0.3, 0.1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    PT_FRAME.bar = bar

    -- OnUpdate tick (1.12 : pas de self/elapsed — on utilise GetTime)
    local _ptLast = GetTime()
    f:SetScript("OnUpdate", function()
        if not PT_RUNNING then return end
        local now = GetTime()
        local dt = now - _ptLast
        _ptLast = now
        PT_ELAPSED = PT_ELAPSED + dt
        local remaining = PT_SECONDS - PT_ELAPSED
        if remaining <= 0 then
            PT_FRAME.numText:SetText("|cffFF0000GO!|r")
            PT_FRAME.bar:SetValue(0)
            PT_FRAME:SetBackdropBorderColor(1.0, 0.0, 0.0, 1.0)
            -- Masque après 2s
            if remaining < -2 then
                RT_PT.Stop()
            end
            return
        end
        local secs = math.ceil(remaining)
        -- Couleur selon urgence
        local r, g, b = 0.0, 1.0, 0.0
        if secs <= 3 then
            r, g, b = 1.0, 0.0, 0.0
        elseif secs <= 5 then
            r, g, b = 1.0, 0.6, 0.0
        end
        PT_FRAME.numText:SetText("|cff" ..
            string.format("%02X%02X%02X", math.floor(r*255), math.floor(g*255), math.floor(b*255)) ..
            tostring(secs) .. "|r")
        PT_FRAME.bar:SetValue(remaining / PT_SECONDS)
        -- Annonce dans le chat à 5, 3, 2, 1
        if PT_ELAPSED > 0 then
            local prevSecs = math.ceil(PT_SECONDS - (PT_ELAPSED - dt))
            if secs ~= prevSecs then
                if secs == 5 or secs == 3 or secs == 2 or secs == 1 then
                    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
                    local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
                    if nRaid > 0 then
                        pcall(SendChatMessage, "Pull dans " .. secs .. "...", "RAID")
                    elseif nParty > 0 then
                        pcall(SendChatMessage, "Pull dans " .. secs .. "...", "PARTY")
                    end
                elseif secs == 0 then
                    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
                    if nRaid > 0 then pcall(SendChatMessage, "PULL !", "RAID")
                    else pcall(SendChatMessage, "PULL !", "PARTY") end
                end
            end
        end
    end)

    PT_FRAME.frame = f
end

-- ── Démarrer le timer ──────────────────────────────────────
function RT_PT.Start(seconds, sender, broadcast)
    seconds = tonumber(seconds) or 10
    if seconds < 1 then seconds = 1 end
    if seconds > 60 then seconds = 60 end

    if not PT_FRAME then PT_CreateFrame() end

    PT_RUNNING  = true
    PT_SECONDS  = seconds
    PT_ELAPSED  = 0
    PT_SENDER   = sender or (UnitName and UnitName("player") or "RL")

    PT_FRAME.frame:Show()
    PT_FRAME.frame:SetBackdropBorderColor(1.0, 0.3, 0.1, 1.0)
    PT_FRAME.senderText:SetText("|cff888888par " .. PT_SENDER .. "|r")
    PT_FRAME.numText:SetText(tostring(seconds))
    PT_FRAME.bar:SetValue(1)

    -- Broadcast au raid
    if broadcast ~= false and RT_Sync_Send then
        RT_Sync_Send("TIMER", "START", tostring(seconds))
    end

    -- BigWigs/DBM compat (si présent)
    if BigWigsLoader and BigWigsLoader.SendMessage then
        pcall(BigWigsLoader.SendMessage, BigWigsLoader, "BigWigs_StartPull", RT_PT, seconds)
    end

    RT_Print("|cffFFAA00[Timer]|r Compte à rebours de " .. seconds .. "s lancé.")
end

function RT_PT.Stop()
    PT_RUNNING = false
    if PT_FRAME and PT_FRAME.frame then
        PT_FRAME.frame:Hide()
    end
end

function RT_PT.Cancel(broadcast)
    RT_PT.Stop()
    if broadcast ~= false and RT_Sync_Send then
        RT_Sync_Send("TIMER", "CANCEL")
    end
    RT_Print("|cffFFAA00[Timer]|r Annulé.")
end

-- ── Réception Sync ─────────────────────────────────────────
if RT_Sync_Register then
    RT_Sync_Register("TIMER", function(sender, action, val)
        if action == "START" then
            local secs = tonumber(val) or 10
            RT_PT.Start(secs, sender, false)  -- false = pas re-broadcast
        elseif action == "CANCEL" then
            RT_PT.Stop()
        end
    end)
end

-- ── UI dans le header RT ───────────────────────────────────
-- Bouton [Pull 10s] visible en haut du main frame (ajouté par rt.lua)
function RT_PT_StartFromUI()
    local input = getglobal("RT_PullTimerInput")
    local secs  = input and tonumber(input:GetText()) or 10
    RT_PT.Start(secs, nil, true)
end

-- ── Commandes slash : /rt timer N ─────────────────────────
function RT_PT_SlashCmd(arg)
    local a = RT_BTrim and RT_BTrim(arg or "") or (arg or "")
    if a == "" or a == "cancel" or a == "stop" then
        RT_PT.Cancel(true)
    else
        local n = tonumber(a)
        if n then RT_PT.Start(n, nil, true)
        else RT_Print("Usage: /rt timer <secondes>  ou  /rt timer cancel") end
    end
end
