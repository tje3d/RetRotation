-- Configuration
local MAX_ICONS = 5          -- How many spells to show in the queue
local ICON_SIZE = 40         -- Size of the icons
local SPACING = 5            -- Space between icons
local GLOW_NEXT = true       -- Highlight the first icon
local SCALE = 1.0            -- Overall scale

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
    end
end)

mainFrame:RegisterEvent("PLAYER_LOGIN")
mainFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
mainFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")