-- ============================================================
-- Arms Rotation Helper - Display.lua
-- Main recommendation, optional stance prompt, swing timer,
-- next-swing queue advice, cooldown availability, action-bar
-- glow, test preview, deterministic simulation, and debug diagnostics.
-- ============================================================

local ADDON_NAME, ns = ...

-- ------------------------------------------------------------
-- Movable root: every visual element inherits its scale.
-- ------------------------------------------------------------

local root = CreateFrame("Frame", "ArmsRotationHelperRoot", UIParent)
root:SetSize(110, 185)
root:SetPoint("CENTER", UIParent, "CENTER", 0, 250)
root:SetFrameStrata("MEDIUM")
root:SetMovable(true)
root:SetClampedToScreen(true)
root:RegisterForDrag("LeftButton")
root:Show()

root:SetScript("OnDragStart", function(self)
    if ns.db and not ns.db.locked then self:StartMoving() end
end)

root:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    ns.db.point, ns.db.x, ns.db.y = point, x, y
end)

ns.rootFrame = root

local function ApplyBackdrop(frame, alpha)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, alpha or 0.72)
end

-- ------------------------------------------------------------
-- Main recommendation
-- ------------------------------------------------------------

local mainFrame = CreateFrame(
    "Frame",
    "ArmsRotationHelperMainIcon",
    root,
    "BackdropTemplate"
)
mainFrame:SetSize(64, 64)
mainFrame:SetPoint("TOP", root, "TOP", 0, 0)
ApplyBackdrop(mainFrame, 0.72)
mainFrame:Hide()

local mainTexture = mainFrame:CreateTexture(nil, "ARTWORK")
mainTexture:SetPoint("TOPLEFT", 5, -5)
mainTexture:SetPoint("BOTTOMRIGHT", -5, 5)
mainTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local testBanner = CreateFrame(
    "Frame",
    "ArmsRotationHelperTestBanner",
    root,
    "BackdropTemplate"
)
testBanner:SetSize(190, 22)
testBanner:SetPoint("BOTTOM", mainFrame, "TOP", 0, 6)
ApplyBackdrop(testBanner, 0.92)
testBanner:SetBackdropBorderColor(1.00, 0.20, 0.16, 1)
testBanner:Hide()

local testBannerText = testBanner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
testBannerText:SetPoint("CENTER")
testBannerText:SetText("|cffff3b30TEST MODE|r")

local captionFrame = CreateFrame(
    "Frame",
    "ArmsRotationHelperCaption",
    root,
    "BackdropTemplate"
)
captionFrame:SetSize(276, 38)
captionFrame:SetPoint("TOP", mainFrame, "BOTTOM", 0, -1)
ApplyBackdrop(captionFrame, 0.82)
captionFrame:Hide()

local nameText = captionFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
nameText:SetPoint("TOP", captionFrame, "TOP", 0, -4)
nameText:SetWidth(220)
nameText:SetJustifyH("CENTER")
nameText:SetShadowColor(0, 0, 0, 1)
nameText:SetShadowOffset(1, -1)

local reasonText = captionFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
reasonText:SetPoint("TOP", nameText, "BOTTOM", 0, -1)
reasonText:SetWidth(260)
reasonText:SetJustifyH("CENTER")
reasonText:SetTextColor(0.88, 0.88, 0.88, 1)
reasonText:SetShadowColor(0, 0, 0, 1)
reasonText:SetShadowOffset(1, -1)

-- ------------------------------------------------------------
-- Secondary stance prompt
-- ------------------------------------------------------------

local stanceFrame = CreateFrame(
    "Frame",
    "ArmsRotationHelperStanceIcon",
    root,
    "BackdropTemplate"
)
stanceFrame:SetSize(32, 32)
stanceFrame:SetPoint("RIGHT", mainFrame, "LEFT", -10, 0)
ApplyBackdrop(stanceFrame, 0.68)
stanceFrame:Hide()

local stanceTexture = stanceFrame:CreateTexture(nil, "ARTWORK")
stanceTexture:SetPoint("TOPLEFT", 3, -3)
stanceTexture:SetPoint("BOTTOMRIGHT", -3, 3)
stanceTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local stanceText = stanceFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
stanceText:SetPoint("TOP", stanceFrame, "BOTTOM", 0, -1)
stanceText:SetText("STANCE")

-- ------------------------------------------------------------
-- Next-swing Heroic Strike / Cleave queue prompt
-- ------------------------------------------------------------

local queueFrame = CreateFrame(
    "Frame",
    "ArmsRotationHelperQueueIcon",
    root,
    "BackdropTemplate"
)
queueFrame:SetSize(32, 32)
queueFrame:SetPoint("LEFT", mainFrame, "RIGHT", 10, 0)
ApplyBackdrop(queueFrame, 0.68)
queueFrame:Hide()

local queueTexture = queueFrame:CreateTexture(nil, "ARTWORK")
queueTexture:SetPoint("TOPLEFT", 3, -3)
queueTexture:SetPoint("BOTTOMRIGHT", -3, 3)
queueTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local queueText = queueFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
queueText:SetPoint("TOP", queueFrame, "BOTTOM", 0, -1)
queueText:SetText("QUEUE")

-- ------------------------------------------------------------
-- Main-hand swing bar
-- ------------------------------------------------------------

local swingBar = CreateFrame(
    "Frame",
    "ArmsRotationHelperSwingBar",
    root,
    "BackdropTemplate"
)
swingBar:SetSize(106, 14)
swingBar:SetPoint("TOP", mainFrame, "BOTTOM", 0, -42)
swingBar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
swingBar:SetBackdropColor(0.04, 0.04, 0.04, 0.85)
swingBar:Hide()

local swingFill = swingBar:CreateTexture(nil, "ARTWORK")
swingFill:SetPoint("LEFT", swingBar, "LEFT", 3, 0)
swingFill:SetHeight(8)
swingFill:SetColorTexture(0.20, 0.55, 1.00, 0.90)

local swingText = swingBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
swingText:SetPoint("CENTER", swingBar, "CENTER", 0, 0)

-- ------------------------------------------------------------
-- Cooldown availability row
-- ------------------------------------------------------------

local cooldownRow = CreateFrame("Frame", "ArmsRotationHelperCooldownRow", root)
cooldownRow:SetSize(190, 45)
cooldownRow:SetPoint("TOP", swingBar, "BOTTOM", 0, -10)
cooldownRow:Hide()

local COOLDOWN_ICON_SIZE = 32
local COOLDOWN_ICON_GAP = 10

local function CreateCooldownIcon(parent, labelText)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(COOLDOWN_ICON_SIZE, COOLDOWN_ICON_SIZE)
    frame:Hide()

    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints()

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    label:SetPoint("TOP", frame, "BOTTOM", 0, -1)
    label:SetWidth(90)
    label:SetJustifyH("CENTER")
    label:SetText(labelText or "")

    return {
        frame = frame,
        texture = texture,
        cooldown = cooldown,
        label = label,
        cachedIcon = nil,
    }
end

local deathWishIcon = CreateCooldownIcon(cooldownRow)
local recklessnessIcon = CreateCooldownIcon(cooldownRow)
local trinketIcons = {
    CreateCooldownIcon(cooldownRow),
    CreateCooldownIcon(cooldownRow),
}

local trinket0Slot = GetInventorySlotInfo("Trinket0Slot")
local trinket1Slot = GetInventorySlotInfo("Trinket1Slot")
local TRINKET_SLOTS = { trinket0Slot, trinket1Slot }
local trinketCache = {}

local function SetReadyColor(texture, ready, wrongStance)
    if not ready then
        texture:SetDesaturated(true)
        texture:SetVertexColor(0.58, 0.58, 0.58)
    elseif wrongStance then
        texture:SetDesaturated(false)
        texture:SetVertexColor(1.00, 0.82, 0.18)
    else
        texture:SetDesaturated(false)
        texture:SetVertexColor(1, 1, 1)
    end
end

local function UpdateAbilityCooldownIcon(entry, key)
    local identifier = ns.GetAbilityIdentifier(key)
    local start, duration = ns.GetCooldown(identifier)
    local remaining = ns.GetAbilityCooldownRemaining(key, true)
    local ready = remaining <= 0.15

    local icon = ns.GetAbilityIcon(key)
    if entry.cachedIcon ~= icon then
        entry.texture:SetTexture(icon)
        entry.cachedIcon = icon
    end
    entry.label:SetText(ns.GetAbilityName(key) or key)
    entry.cooldown:SetCooldown(start or 0, duration or 0)

    local wrongStance = ns.GetPreferredStanceForAbility(key) ~= nil
    SetReadyColor(entry.texture, ready, wrongStance)
end

local function UpdateTrinketIcon(entry, slot)
    local itemLink = GetInventoryItemLink("player", slot)
    if not itemLink then return false end

    local cached = trinketCache[itemLink]
    if not cached then
        local spellName = ns.GetItemSpellName(itemLink)
        if not spellName then
            -- Do not negatively cache: item data can arrive after login.
            return false
        end
        cached = {
            name = GetItemInfo(itemLink) or spellName,
            icon = GetInventoryItemTexture("player", slot),
        }
        trinketCache[itemLink] = cached
    end

    if entry.cachedIcon ~= cached.icon then
        entry.texture:SetTexture(cached.icon)
        entry.cachedIcon = cached.icon
    end
    entry.label:SetText(cached.name)

    local ready, start, duration = ns.GetItemCooldownInfo(slot)
    entry.cooldown:SetCooldown(start or 0, duration or 0)
    SetReadyColor(entry.texture, ready, false)
    return true
end

local function LayoutCooldownRow(activeFrames)
    local count = #activeFrames
    if count == 0 then return end
    local width = count * COOLDOWN_ICON_SIZE + (count - 1) * COOLDOWN_ICON_GAP
    local startX = -width / 2 + COOLDOWN_ICON_SIZE / 2

    for index, frame in ipairs(activeFrames) do
        frame:ClearAllPoints()
        frame:SetPoint(
            "TOP",
            cooldownRow,
            "TOP",
            startX + (index - 1) * (COOLDOWN_ICON_SIZE + COOLDOWN_ICON_GAP),
            0
        )
    end
end

local function UpdateCooldownRow(snapshot)
    if not ns.db.showCooldowns or (snapshot and snapshot.simulation) then
        cooldownRow:Hide()
        return
    end

    local active = {}

    if ns.PlayerKnowsAbility("DEATH_WISH") then
        UpdateAbilityCooldownIcon(deathWishIcon, "DEATH_WISH")
        table.insert(active, deathWishIcon.frame)
    else
        deathWishIcon.frame:Hide()
    end

    if ns.PlayerKnowsAbility("RECKLESSNESS") then
        UpdateAbilityCooldownIcon(recklessnessIcon, "RECKLESSNESS")
        table.insert(active, recklessnessIcon.frame)
    else
        recklessnessIcon.frame:Hide()
    end

    for index, slot in ipairs(TRINKET_SLOTS) do
        if slot and UpdateTrinketIcon(trinketIcons[index], slot) then
            table.insert(active, trinketIcons[index].frame)
        else
            trinketIcons[index].frame:Hide()
        end
    end

    if #active == 0 then
        cooldownRow:Hide()
        return
    end

    cooldownRow:Show()
    for _, frame in ipairs(active) do frame:Show() end
    LayoutCooldownRow(active)
end

-- ------------------------------------------------------------
-- Action-bar lookup and non-secure glow
-- ------------------------------------------------------------

local glow = CreateFrame(
    "Frame",
    "ArmsRotationHelperGlow",
    UIParent,
    "BackdropTemplate"
)
glow:SetFrameStrata("HIGH")
glow:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
})
glow:SetBackdropBorderColor(1, 0.85, 0.1, 1)
glow:Hide()

local glowAnimation = glow:CreateAnimationGroup()
glowAnimation:SetLooping("REPEAT")

local fadeOut = glowAnimation:CreateAnimation("Alpha")
fadeOut:SetFromAlpha(1)
fadeOut:SetToAlpha(0.28)
fadeOut:SetDuration(0.55)
fadeOut:SetOrder(1)

local fadeIn = glowAnimation:CreateAnimation("Alpha")
fadeIn:SetFromAlpha(0.28)
fadeIn:SetToAlpha(1)
fadeIn:SetDuration(0.55)
fadeIn:SetOrder(2)

local BAR_PREFIXES = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarLeftButton",
    "MultiBarRightButton",
    "MultiBar5Button",
    "MultiBar6Button",
    "MultiBar7Button",
}

local actionSlotsByName = {}

local function AddActionSlot(name, slot)
    if not name then return end
    actionSlotsByName[name] = actionSlotsByName[name] or {}
    table.insert(actionSlotsByName[name], slot)
end

local function GetMacroActionSpell(macroIndex)
    if not GetMacroSpell then return nil end
    local name, _, spellID = GetMacroSpell(macroIndex)
    if name then return name end
    if spellID then return ns.GetSpellName(spellID) end
    return nil
end

local function RebuildActionCache()
    actionSlotsByName = {}
    for slot = 1, 120 do
        if HasAction(slot) then
            local actionType, id = GetActionInfo(slot)
            if actionType == "spell" and id then
                AddActionSlot(ns.GetSpellName(id), slot)
            elseif actionType == "macro" and id then
                AddActionSlot(GetMacroActionSpell(id), slot)
            end
        end
    end
end

local function FindThirdPartyButton(slot)
    local button = _G["BT4Button" .. slot]
    if button and button:IsVisible() then return button end
    button = _G["DominosActionButton" .. slot]
    if button and button:IsVisible() then return button end
    return nil
end

local function FindBlizzardButton(slot)
    for _, prefix in ipairs(BAR_PREFIXES) do
        for index = 1, 12 do
            local button = _G[prefix .. index]
            if button and button.action == slot and button:IsVisible() then
                return button
            end
        end
    end
    return nil
end

function ns.FindActionButtonForAbility(key)
    local name = ns.GetAbilityName(key)
    local slots = name and actionSlotsByName[name]
    if not slots then return nil end

    for _, slot in ipairs(slots) do
        local button = FindThirdPartyButton(slot) or FindBlizzardButton(slot)
        if button then return button end
    end
    return nil
end

local actionEventFrame = CreateFrame("Frame")
actionEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
actionEventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
actionEventFrame:RegisterEvent("UPDATE_MACROS")
actionEventFrame:RegisterEvent("SPELLS_CHANGED")
actionEventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
actionEventFrame:SetScript("OnEvent", function()
    local ok, err = pcall(RebuildActionCache)
    if not ok then ns.ReportOnce("Action-bar cache", err) end
end)

local function HideGlow()
    glow:Hide()
    glowAnimation:Stop()
end

local function UpdateGlow(snapshot)
    if not ns.db.showGlow or not snapshot or not snapshot.main
        or snapshot.simulation then
        HideGlow()
        return
    end

    local key = snapshot.main.ability
    if snapshot.main.stance then
        key = ns.GetStanceKey(snapshot.main.stance) or key
    end

    local button = ns.FindActionButtonForAbility(key)
    if not button then
        HideGlow()
        return
    end

    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", button, "TOPLEFT", -6, 6)
    glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 6, -6)
    glow:Show()
    if not glowAnimation:IsPlaying() then glowAnimation:Play() end
end

-- ------------------------------------------------------------
-- Debug panel
-- ------------------------------------------------------------

local debugFrame = CreateFrame(
    "Frame",
    "ArmsRotationHelperDebugFrame",
    UIParent,
    "BackdropTemplate"
)
debugFrame:SetSize(330, 20)
debugFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -220)
debugFrame:SetFrameStrata("MEDIUM")
ApplyBackdrop(debugFrame, 0.80)
debugFrame:Hide()

local DEBUG_LINE_COUNT = 24
local debugLines = {}
for index = 1, DEBUG_LINE_COUNT do
    local line = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    line:SetPoint("TOPLEFT", 8, -8 - (index - 1) * 12)
    line:SetJustifyH("LEFT")
    debugLines[index] = line
end

local function BuildDebugLines(snapshot)
    local s = ns.state
    local now = GetTime()
    local lines = {}

    table.insert(lines, "=== Arms Rotation Helper " .. ns.VERSION .. " ===")
    if ns.db.testMode then
        table.insert(lines, "*** TEST MODE - SIMULATED RECOMMENDATIONS ***")
    end

    if snapshot.simulation then
        local sim = snapshot.simulation
        local simulatedState = sim.state
        local actualMain = snapshot.main and snapshot.main.ability
        local actualQueue = snapshot.queue and snapshot.queue.ability
        local actualStance = snapshot.main and snapshot.main.stance

        table.insert(lines, "*** ROTATION SIMULATOR - NOT LIVE COMBAT ***")
        table.insert(lines, string.format(
            "Scenario: %s  Step: %d/%d",
            sim.scenarioLabel,
            sim.stepIndex,
            sim.stepTotal
        ))
        if sim.activeName == "all" then
            table.insert(lines, string.format(
                "Complete suite: %d/%d",
                sim.suiteIndex,
                sim.suiteTotal
            ))
        end
        table.insert(lines, sim.stepLabel)
        table.insert(lines, string.format(
            "Rage: %d  Targets: %d  Target HP: %.0f%%",
            simulatedState.rage,
            simulatedState.enemyCount,
            simulatedState.targetHPPercent
        ))
        table.insert(lines, string.format(
            "Swing: %.1fs  Slam window: %s  GCD: %.1fs",
            sim.swingRemaining,
            sim.slamWindowOpen and "OPEN" or "closed",
            sim.gcdRemaining
        ))
        table.insert(lines, "Main actual/expected: "
            .. (actualMain and (ns.GetAbilityName(actualMain) or actualMain) or "WAIT")
            .. " / "
            .. (sim.expectedMain
                and (ns.GetAbilityName(sim.expectedMain) or sim.expectedMain)
                or "WAIT"))
        table.insert(lines, "Queue actual/expected: "
            .. (actualQueue and (ns.GetAbilityName(actualQueue) or actualQueue) or "NONE")
            .. " / "
            .. (sim.expectedQueue
                and (ns.GetAbilityName(sim.expectedQueue) or sim.expectedQueue)
                or "NONE"))
        table.insert(lines, "Stance actual/expected: "
            .. (actualStance and ns.GetStanceLabel(actualStance) or "NONE")
            .. " / "
            .. (sim.expectedStance and ns.GetStanceLabel(sim.expectedStance) or "NONE"))
        table.insert(lines, sim.passed
            and "|cff40ff40RESULT: PASS|r"
            or "|cffff4040RESULT: FAIL - use /arh sim check|r")
        table.insert(lines, "Use /arh sim next or /arh sim stop")
        return lines
    end

    table.insert(lines, string.format("Rage: %d/%d  Combat: %s  Moving: %s",
        s.rage, s.maxRage, s.inCombat and "yes" or "no", s.moving and "yes" or "no"))
    table.insert(lines, "Stance: " .. ns.GetStanceLabel(s.stance))

    if s.targetAttackable then
        table.insert(lines, string.format("Target: %s  HP: %.0f%%  TTD: %.1fs",
            UnitName("target") or "?", s.targetHPPercent, s.targetTTD))
    else
        table.insert(lines, "Target: none/invalid")
    end

    table.insert(lines, string.format("Enemies: %d  Mode: %s  AOE: %s",
        s.enemyCount, ns.db.mode, snapshot.aoeActive and "yes" or "no"))
    table.insert(lines, string.format("MH speed: %.2fs  Next: %.2fs",
        s.mainhandSpeed, ns.GetSwingRemaining()))
    table.insert(lines, string.format("Last MH: %.2fs ago  Replacement: %s",
        s.lastMainhandSwing > 0 and now - s.lastMainhandSwing or 0,
        s.lastSwingWasReplacement and "yes" or "no"))
    table.insert(lines, string.format("Slam window: %s  Improved: %s",
        ns.IsSlamWindowOpen() and "OPEN" or "closed",
        snapshot.slamBuild and "yes" or "no"))
    table.insert(lines, string.format("GCD: %.2fs  Ignored extras: %d",
        ns.GetGCDRemaining(), s.ignoredExtraAttacks))

    local opRemaining = math.max(0, s.overpowerWindowEnd - now)
    table.insert(lines, string.format("Overpower: %.1fs  Correct target: %s",
        opRemaining,
        s.overpowerTargetGUID and s.overpowerTargetGUID == s.targetGUID and "yes" or "no"))
    table.insert(lines, string.format("My Rend: %.1fs  Sunder: %d (%.1fs)",
        math.max(0, s.rendExpiration - now),
        s.sunderStacks,
        math.max(0, s.sunderExpiration - now)))
    table.insert(lines, string.format("My Demo Shout: %.1fs  Improved: %d/%d",
        math.max(0, (s.demoShoutExpiration or 0) - now),
        s.improvedDemoShoutRank or 0,
        s.improvedDemoShoutMaxRank or 5))

    if snapshot.main then
        table.insert(lines, "Main: " .. (ns.GetAbilityName(snapshot.main.ability) or "?"))
        table.insert(lines, "Reason: " .. (snapshot.main.reason or ""))
    else
        table.insert(lines, "Main: wait for swing / build Rage")
        table.insert(lines, "Reason: no higher-priority action")
    end

    if snapshot.queue then
        table.insert(lines, "Queue: " .. (ns.GetAbilityName(snapshot.queue.ability) or "?")
            .. " (" .. (snapshot.queue.reason or "") .. ")")
    else
        table.insert(lines, "Queue: none")
    end

    local coreKeys = {
        "MORTAL_STRIKE", "WHIRLWIND", "SLAM", "EXECUTE",
        "OVERPOWER", "SWEEPING_STRIKES",
    }
    table.insert(lines, "--- Core cooldowns ---")
    for _, key in ipairs(coreKeys) do
        if ns.PlayerKnowsAbility(key) then
            table.insert(lines, string.format("%s: %.1fs",
                ns.GetAbilityName(key) or key,
                ns.GetAbilityCooldownRemaining(key, true)))
        else
            table.insert(lines, (ns.GetAbilityName(key) or key) .. ": not known")
        end
    end

    return lines
end

local function UpdateDebugPanel(snapshot)
    if not ns.db.debugMode and not snapshot.simulation then
        debugFrame:Hide()
        return
    end

    local lines = BuildDebugLines(snapshot)
    debugFrame:SetHeight(#lines * 12 + 16)
    debugFrame:Show()
    for index = 1, DEBUG_LINE_COUNT do
        debugLines[index]:SetText(lines[index] or "")
    end
end

-- ------------------------------------------------------------
-- Main UI updates and test preview
-- ------------------------------------------------------------

local testModeStartedAt = 0

local function BuildTestSnapshot()
    local keys = { "SLAM", "MORTAL_STRIKE", "WHIRLWIND" }
    local elapsed = GetTime() - testModeStartedAt
    local index = math.floor(elapsed / 1.5) % #keys + 1
    local key = keys[index]
    return {
        main = {
            ability = key,
            reason = key == "SLAM"
                and "Main-hand swing landed - Slam now"
                or "Display test preview",
            stance = key == "WHIRLWIND" and ns.STANCE.BERSERKER or nil,
        },
        queue = {
            ability = "HEROIC_STRIKE",
            reason = "Queue next swing",
        },
        aoeActive = false,
        enemyCount = 1,
        slamBuild = true,
        testProgress = (elapsed % 3.6) / 3.6,
    }
end

function ns.Display_SetTestMode(enabled)
    if enabled
        and ns.Diagnostics_IsActive
        and ns.Diagnostics_IsActive()
        and ns.Diagnostics_Stop then
        ns.Diagnostics_Stop("preview")
    end
    ns.db.testMode = enabled == true
    testModeStartedAt = GetTime()
end

local function UpdateMainIcon(snapshot)
    local decision = snapshot and snapshot.main
    if not ns.db.showIcon or not decision then
        mainFrame:Hide()
        captionFrame:Hide()
        return
    end

    mainTexture:SetTexture(ns.GetAbilityIcon(decision.ability))
    nameText:SetText(ns.GetAbilityName(decision.ability) or decision.ability)
    reasonText:SetText(decision.reason or "")
    mainFrame:Show()
    captionFrame:Show()
end

local function UpdateTestBanner(snapshot)
    local sim = snapshot and snapshot.simulation
    if sim then
        testBanner:SetBackdropBorderColor(0.20, 0.75, 1.00, 1)
        testBannerText:SetText(string.format(
            "|cff55ccffSIMULATION: %s %d/%d|r",
            sim.scenarioName:upper(),
            sim.stepIndex,
            sim.stepTotal
        ))
        testBanner:Show()
    elseif ns.db.testMode then
        testBanner:SetBackdropBorderColor(1.00, 0.20, 0.16, 1)
        testBannerText:SetText("|cffff3b30TEST MODE|r")
        testBanner:Show()
    else
        testBanner:Hide()
    end
end

local function UpdateStanceIcon(snapshot)
    local decision = snapshot and snapshot.main
    if not ns.db.stanceAdvice or not decision or not decision.stance then
        stanceFrame:Hide()
        return
    end

    local stanceKey = ns.GetStanceKey(decision.stance)
    if not stanceKey then
        stanceFrame:Hide()
        return
    end

    stanceTexture:SetTexture(ns.GetAbilityIcon(stanceKey))
    stanceText:SetText("STANCE")
    stanceFrame:Show()
end

local function UpdateQueueIcon(snapshot)
    local queue = snapshot and snapshot.queue
    if not ns.db.showQueue or not queue then
        queueFrame:Hide()
        return
    end

    queueTexture:SetTexture(ns.GetAbilityIcon(queue.ability))
    queueText:SetText("QUEUE")
    queueFrame:Show()
end

local function UpdateSwingBar(snapshot)
    local progressOverride = snapshot
        and (snapshot.swingProgressOverride or snapshot.testProgress)
    local hasLiveSwing = ns.state.inCombat
        and ns.state.mainhandSpeed > 0
        and ns.state.nextMainhandSwing > 0

    if not ns.db.showSwingBar
        or (not hasLiveSwing and progressOverride == nil) then
        swingBar:Hide()
        return
    end

    local progress = progressOverride or ns.GetSwingProgress()
    local remaining
    if snapshot and snapshot.simulation then
        remaining = snapshot.simulation.swingRemaining
    elseif progressOverride then
        remaining = (1 - progress) * 3.6
    else
        remaining = ns.GetSwingRemaining()
    end
    swingFill:SetWidth(math.max(1, 100 * progress))

    if snapshot and snapshot.main and snapshot.main.ability == "SLAM" then
        swingFill:SetColorTexture(1.00, 0.72, 0.08, 0.95)
        swingText:SetText("SLAM")
    else
        swingFill:SetColorTexture(0.20, 0.55, 1.00, 0.90)
        swingText:SetText(string.format("%.1f", remaining))
    end
    swingBar:Show()
end

local function SafeUpdate(context, func, ...)
    local ok, err = pcall(func, ...)
    if not ok then ns.ReportOnce(context, err) end
end

local function BuildSnapshot()
    if ns.Simulator_IsActive and ns.Simulator_IsActive() then
        local ok, result = pcall(ns.Simulator_GetSnapshot)
        if ok and result then return result end
        if not ok then ns.ReportOnce("Rotation simulator", result) end
    end
    if ns.db.testMode then return BuildTestSnapshot() end
    local ok, result = pcall(ns.Rotation_GetSnapshot)
    if not ok then
        ns.ReportOnce("Rotation logic", result)
        return {
            main = nil,
            queue = nil,
            aoeActive = false,
            enemyCount = 0,
            slamBuild = false,
        }
    end
    return result
end

function ns.Display_ApplySettings()
    if not ns.db then return end
    root:ClearAllPoints()
    root:SetPoint(ns.db.point, UIParent, ns.db.point, ns.db.x, ns.db.y)
    root:SetScale(ns.db.scale)
    root:EnableMouse(not ns.db.locked)
end

-- ------------------------------------------------------------
-- Update loop
-- ------------------------------------------------------------

local elapsedUI = 0
local elapsedCooldown = 0
local ticker = CreateFrame("Frame")

ticker:SetScript("OnUpdate", function(_, elapsed)
    elapsedUI = elapsedUI + elapsed
    elapsedCooldown = elapsedCooldown + elapsed
    if elapsedUI < ns.CONFIG.UI_TICK then return end
    elapsedUI = 0

    if not ns.db then return end

    local ok, err = pcall(ns.RefreshState)
    if not ok then ns.ReportOnce("State refresh", err) end

    local snapshot = BuildSnapshot()
    SafeUpdate("Diagnostic recorder", ns.Diagnostics_Sample or function() end, snapshot)
    SafeUpdate("Main icon", UpdateMainIcon, snapshot)
    SafeUpdate("Test/simulation banner", UpdateTestBanner, snapshot)
    SafeUpdate("Stance icon", UpdateStanceIcon, snapshot)
    SafeUpdate("Queue icon", UpdateQueueIcon, snapshot)
    SafeUpdate("Swing bar", UpdateSwingBar, snapshot)
    SafeUpdate("Action-bar glow", UpdateGlow, snapshot)
    SafeUpdate("Debug panel", UpdateDebugPanel, snapshot)

    if elapsedCooldown >= ns.CONFIG.COOLDOWN_ROW_TICK then
        elapsedCooldown = 0
        SafeUpdate("Cooldown row", UpdateCooldownRow, snapshot)
    end
end)
