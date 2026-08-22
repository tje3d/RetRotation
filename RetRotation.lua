-- Configuration
local MAX_ICONS = 5          -- How many spells to show in the queue
local ICON_SIZE = 40         -- Size of the icons
local SPACING = 5            -- Space between icons
local GLOW_NEXT = true       -- Highlight the first icon
local SCALE = 1.0            -- Overall scale

-- Reminder settings (Seal & Aura watch)
local REMIND_SEAL   = true   -- Warn when no Seal is active
local REMIND_AURA   = true   -- Warn when the Aura requirement is not met
local AURA_MODE     = "ANY"  -- "ANY"      = any Paladin aura counts as OK
                             -- "CRUSADER" = only Crusader Aura counts as OK
local PULSE_MISSING = true   -- Pulse the icon while something is missing
local PLAY_SOUND    = true   -- Play a warning sound when a Seal/Aura drops

-- Spell IDs (Used to look up names and textures)
local RAW_SPELLS = {
    CS      = 35395, -- Crusader Strike
    JUDGE   = 53408, -- Judgement of Wisdom
    DS      = 53385, -- Divine Storm
    EXO     = 879,   -- Exorcism
    CONS    = 26573, -- Consecration
    HW      = 2812,  -- Holy Wrath
    HOW     = 24275, -- Hammer of Wrath
}

local BUFFS = {
    ART_OF_WAR = 59578,
    SEAL_CMD   = 20375,
}

-- Seal & Aura watch
-- WotLK Seals: Command, Vengeance, Righteousness, Wisdom, Light, Justice
local SEALS = {
    20375, -- Seal of Command
    53736, -- Seal of Vengeance (Horde) / 31801 Ally
    31801, -- Seal of Vengeance (Alliance)
    20165, -- Seal of Justice
    21084, -- Seal of Righteousness
    20164, -- Seal of Light
    20166, -- Seal of Wisdom
}
-- Auras: Crusader is the raid favourite; the rest count when mode is "ANY"
-- NOTE: UnitAura matches by NAME, so rank-1 IDs cover every rank of the aura.
local AURA_CRUSADER = 32223 -- Crusader Aura (single rank)
local ANY_AURAS = {
    465,    -- Devotion Aura
    7294,   -- Retribution Aura
    19746,  -- Concentration Aura
    20218,  -- Sanctity Aura
    19891,  -- Fire Resistance Aura
    19876,  -- Shadow Resistance Aura
    19877,  -- Frost Resistance Aura
}

-- Frame Setup
local addonName, ns = ...
local mainFrame = CreateFrame("Frame", "RetRotationFrame", UIParent)
mainFrame:SetSize((ICON_SIZE * MAX_ICONS) + (SPACING * (MAX_ICONS - 1)), ICON_SIZE)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
mainFrame:SetScale(SCALE)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:SetClampedToScreen(true)

-- Background
mainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
mainFrame:SetBackdropColor(0, 0, 0, 0.5)

-- Hide by default until we verify class/spec
mainFrame:Hide()

-- Create Icon Pool
local icons = {}
for i = 1, MAX_ICONS do
    local name = "RetRotationBtn" .. i
    local btn = CreateFrame("CheckButton", name, mainFrame, "ActionButtonTemplate")
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:SetPoint("LEFT", (i - 1) * (ICON_SIZE + SPACING), 0)
    btn:EnableMouse(false)
    
    -- Manually map XML children
    btn.icon = _G[name .. "Icon"]
    btn.cooldown = _G[name .. "Cooldown"]
    
    -- State caching to prevent flickering
    btn.lastTexture = nil
    btn.lastStart = 0
    btn.lastDuration = 0
    btn.lastOOM = nil
    btn.lastGlow = nil
    
    -- Adjust border
    local normal = _G[name .. "NormalTexture"]
    if normal then 
        normal:SetWidth(ICON_SIZE * 1.6) 
        normal:SetHeight(ICON_SIZE * 1.6) 
    end

    icons[i] = btn
end

--------------------------------------------------------------------
-- Seal & Aura Reminder
--------------------------------------------------------------------
local REMIND_SIZE = ICON_SIZE  -- Reminder icon size

-- Reminder frame sits above the rotation bar, same width
local remindFrame = CreateFrame("Frame", "RetRotationReminderFrame", UIParent)
remindFrame:SetSize(mainFrame:GetWidth(), REMIND_SIZE)
remindFrame:SetPoint("BOTTOM", mainFrame, "TOP", 0, SPACING)
remindFrame:SetScale(SCALE)
remindFrame:SetMovable(true)
remindFrame:EnableMouse(true)
remindFrame:RegisterForDrag("LeftButton")
remindFrame:SetScript("OnDragStart", remindFrame.StartMoving)
remindFrame:SetScript("OnDragStop", remindFrame.StopMovingOrSizing)
remindFrame:SetClampedToScreen(true)

-- Seal slot (left) and Aura slot (right), centered as a pair
local function CreateReminderSlot(name, parent)
    local btn = CreateFrame("CheckButton", name, parent, "ActionButtonTemplate")
    btn:SetSize(REMIND_SIZE, REMIND_SIZE)
    btn:EnableMouse(false)

    -- Manually map XML children
    btn.icon = _G[name .. "Icon"]
    btn.cooldown = _G[name .. "Cooldown"]

    local normal = _G[name .. "NormalTexture"]
    if normal then
        normal:SetWidth(REMIND_SIZE * 1.6)
        normal:SetHeight(REMIND_SIZE * 1.6)
    end

    -- "MISSING" overlay text (e.g. "NO SEAL"), anchored inside the icon
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    label:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
    btn.label = label
    return btn
end

local sealSlot = CreateReminderSlot("RetRotationSealSlot", remindFrame)
local auraSlot = CreateReminderSlot("RetRotationAuraSlot", remindFrame)
sealSlot:SetPoint("CENTER", remindFrame, "CENTER", -(REMIND_SIZE / 2 + SPACING / 2), 0)
auraSlot:SetPoint("CENTER", remindFrame, "CENTER", (REMIND_SIZE / 2 + SPACING / 2), 0)

-- Icon textures shown while something is missing
-- (resolved via GetSpellInfo at display time; fallback paths hardcoded above)
sealSlot.textureID = 21084 -- Seal of Righteousness art stands in for "any seal"
auraSlot.textureID = AURA_CRUSADER

sealSlot.labelText = "NO SEAL"
auraSlot.labelText = AURA_MODE == "CRUSADER" and "NO CRUSADER" or "NO AURA"

sealSlot.lastShown = nil
sealSlot.lastPulse = nil
auraSlot.lastShown = nil
auraSlot.lastPulse = nil

-- Hide by default until visibility is confirmed
remindFrame:Hide()

-- Helper: Get Localized Spell Name
local SPELL_MAP = {}
local function InitSpells()
    for key, id in pairs(RAW_SPELLS) do
        local name, _, texture = GetSpellInfo(id)
        if name then
            SPELL_MAP[key] = { name = name, texture = texture, id = id }
        end
    end
end

-- Helper: Check if player is Retribution Paladin
local function IsRetributionPaladin()
    local _, class = UnitClass("player")
    if class ~= "PALADIN" then
        return false
    end
    
    -- Check for Retribution talents by checking talent points in Ret tree
    -- In WotLK, talent tree 3 is Retribution for Paladins
    local _, _, pointsSpent = GetTalentTabInfo(3)
    
    -- Consider it Ret spec if at least 31 points in Ret tree
    if pointsSpent and pointsSpent >= 31 then
        return true
    end
    
    return false
end

-- Helper: Update Frame Visibility
local function UpdateFrameVisibility()
    if IsRetributionPaladin() then
        mainFrame:Show()
    else
        mainFrame:Hide()
        remindFrame:Hide() -- OnUpdate won't fire while mainFrame is hidden
    end
end

-- Helper: Check Aura by Name
local function HasBuff(unit, spellID)
    local name = GetSpellInfo(spellID)
    if not name then return false end
    return UnitAura(unit, name) ~= nil
end

-- Helper: Check Target Type
local function IsTargetDemonOrUndead()
    if not UnitExists("target") then return false end
    local t = UnitCreatureType("target")
    return t == "Demon" or t == "Undead"
end

--------------------------------------------------------------------
-- Seal & Aura Reminder Logic
--------------------------------------------------------------------
-- True if the player currently has any of the given spell IDs active
local function HasAnyOf(unit, ids)
    for i = 1, #ids do
        if HasBuff(unit, ids[i]) then return true end
    end
    return false
end

-- Returns sealOK, auraOK for the current player state
local function GetReminderState()
    local hasSeal = HasAnyOf("player", SEALS)
    local hasAura = false
    if AURA_MODE == "CRUSADER" then
        hasAura = HasBuff("player", AURA_CRUSADER)
    else
        hasAura = HasBuff("player", AURA_CRUSADER) or HasAnyOf("player", ANY_AURAS)
    end
    return hasSeal, hasAura
end

-- Show/hide + pulse a reminder slot; returns true when it is visible this tick
local function UpdateReminderSlot(slot, missing)
    local show = missing == true

    if slot.lastShown ~= show then
        if show then
            slot.label:SetText(slot.labelText)
            local _, _, tex = GetSpellInfo(slot.textureID)
            slot.icon:SetTexture(tex or "Interface\\Icons\\Spell_Holy_RighteousnessAura")
            slot:Show()
        else
            slot:Hide()
        end
        slot.lastShown = show
    end

    -- Pulse alpha while visible (blink between 1.0 and 0.5)
    if show then
        local pulse = true
        if PULSE_MISSING then
            pulse = math.floor(GetTime() * 2) % 2 == 0
        end
        local targetAlpha = pulse and 1 or 0.5
        if slot.lastPulse ~= pulse then
            slot:SetAlpha(targetAlpha)
            slot.lastPulse = pulse
        end
    end
    return show
end

-- True while at least one reminder was visible on the previous tick
local remindWasAlerting = false

local function UpdateReminders()
    if not IsRetributionPaladin() then
        remindFrame:Hide()
        remindWasAlerting = false
        return
    end

    local sealOK, auraOK = GetReminderState()
    local sealMissing = REMIND_SEAL and not sealOK
    local auraMissing = REMIND_AURA and not auraOK

    -- Play warning sound when going from "all good" -> "something missing"
    -- (WotLK 3.3.5a: PlaySound takes just the sound ID)
    local alerting = (sealMissing == true) or (auraMissing == true)
    if PLAY_SOUND and alerting and not remindWasAlerting then
        PlaySound("RaidWarning")
    end
    remindWasAlerting = alerting

    local anyVisible = UpdateReminderSlot(sealSlot, sealMissing)
    if UpdateReminderSlot(auraSlot, auraMissing) then
        anyVisible = true
    end

    if anyVisible then
        if not remindFrame:IsShown() then remindFrame:Show() end
    else
        if remindFrame:IsShown() then remindFrame:Hide() end
    end
end

-- Helper: Get Priority List based on State
local function GetCurrentPriority()
    local isAoE = HasBuff("player", BUFFS.SEAL_CMD)
    local isExecute = UnitCanAttack("player", "target") and (UnitHealth("target")/UnitHealthMax("target") <= 0.2)
    local isDemon = IsTargetDemonOrUndead()

    local prio = {}
    local function Get(key) return SPELL_MAP[key] end
    
    if not SPELL_MAP.CS then return {} end

    if isAoE then
        if isExecute then
            prio = {Get("HOW"), Get("JUDGE"), Get("DS"), Get("CONS"), Get("CS"), Get("HW"), Get("EXO")}
        elseif isDemon then
            prio = {Get("JUDGE"), Get("DS"), Get("CONS"), Get("CS"), Get("HW"), Get("EXO")}
        else
            prio = {Get("JUDGE"), Get("DS"), Get("CONS"), Get("CS"), Get("HW"), Get("EXO")}
        end
    else
        if isExecute then
            prio = {Get("HOW"), Get("JUDGE"), Get("DS"), Get("CS"), Get("CONS"), Get("EXO"), Get("HW")}
        elseif isDemon then
            prio = {Get("JUDGE"), Get("DS"), Get("CS"), Get("CONS"), Get("EXO"), Get("HW")}
        else
            prio = {Get("JUDGE"), Get("DS"), Get("CS"), Get("CONS"), Get("EXO"), Get("HW")}
        end
    end
    return prio
end

-- Reuse table to reduce garbage collection
local spellData = {} 

-- Main Update Loop
local lastUpdate = 0
mainFrame:SetScript("OnUpdate", function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate < 0.1 then return end
    lastUpdate = 0

    if not SPELL_MAP.CS then InitSpells() end

    -- Seal & Aura reminder check
    UpdateReminders()

    -- Clear table for new frame
    for k in pairs(spellData) do spellData[k] = nil end

    local activePrioList = GetCurrentPriority()
    local now = GetTime()
    local count = 0

    for i, spell in ipairs(activePrioList) do
        if spell then
            local name = spell.name
            
            -- Hammer of Wrath Logic
            local skip = false
            if spell.id == RAW_SPELLS.HOW then
                if not (UnitCanAttack("player", "target") and (UnitHealth("target")/UnitHealthMax("target") <= 0.2)) then
                    skip = true
                end
            end

            if not skip then
                local start, duration, enabled = GetSpellCooldown(name)
                local usable, nomana = IsUsableSpell(name)
                
                -- Is spell known/valid?
                if start then
                    local cooldownLeft = 0
                    if start > 0 and duration > 1.5 then
                        cooldownLeft = (start + duration) - now
                    end
                    
                    count = count + 1
                    spellData[count] = {
                        name = name,
                        texture = spell.texture,
                        cdLeft = cooldownLeft,
                        prioIndex = i,
                        start = start,
                        duration = duration,
                        isOOM = nomana
                    }
                end
            end
        end
    end

    -- Sort: Ready First, then Priority
    table.sort(spellData, function(a, b)
        local cdA = a.cdLeft
        local cdB = b.cdLeft
        
        -- If CDs are very close (e.g. both 0), defer to Priority Index
        if math.abs(cdA - cdB) < 0.1 then
            return a.prioIndex < b.prioIndex
        end
        return cdA < cdB
    end)

    -- Update Icons with State Caching (Prevents Blinking)
    for i = 1, MAX_ICONS do
        local icon = icons[i]
        local data = spellData[i]

        if data then
            if not icon:IsShown() then icon:Show() end
            
            -- 1. Only Update Texture if changed
            if icon.lastTexture ~= data.texture then
                icon.icon:SetTexture(data.texture)
                icon.lastTexture = data.texture
            end
            
            -- 2. Only Update Cooldown if changed
            -- This is the main cause of "blinking" spirals
            if icon.lastStart ~= data.start or icon.lastDuration ~= data.duration then
                if data.start and data.duration then
                    icon.cooldown:SetCooldown(data.start, data.duration)
                else
                    icon.cooldown:Hide()
                end
                icon.lastStart = data.start
                icon.lastDuration = data.duration
            end

            -- 3. Only Update OOM Color if changed
            if icon.lastOOM ~= data.isOOM then
                if data.isOOM then
                    icon.icon:SetVertexColor(0.5, 0.5, 1.0)
                else
                    icon.icon:SetVertexColor(1, 1, 1)
                end
                icon.lastOOM = data.isOOM
            end

            -- 4. Update Glow (Checked State)
            -- We calculate this every frame, but only call SetChecked if it changes
            local shouldGlow = (i == 1 and GLOW_NEXT and data.cdLeft <= 0.5)
            if icon.lastGlow ~= shouldGlow then
                icon:SetChecked(shouldGlow)
                icon.lastGlow = shouldGlow
            end

            -- 5. Alpha (Next vs Queue)
            if i == 1 then
                 if icon:GetAlpha() ~= 1 then icon:SetAlpha(1) end
            else
                 if icon:GetAlpha() ~= 0.6 then icon:SetAlpha(0.6) end
            end
        else
            if icon:IsShown() then 
                icon:Hide() 
                -- Reset state so it updates correctly next time it shows
                icon.lastTexture = nil
                icon.lastStart = -1
            end
        end
    end
end)

mainFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" or event == "LEARNED_SPELL_IN_TAB" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        InitSpells()
        UpdateFrameVisibility()
    elseif event == "UNIT_AURA" then
        -- Buff/debuff change: refresh Seal/Aura reminder immediately
        UpdateReminders()
    end
end)

local periodicCheck = CreateFrame("Frame")
periodicCheck:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed > 2 then -- Check every 2 seconds
        self.elapsed = 0
        UpdateFrameVisibility()
    end
end)

mainFrame:RegisterEvent("PLAYER_LOGIN")
mainFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
mainFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
mainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mainFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
mainFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
mainFrame:RegisterEvent("UNIT_AURA")