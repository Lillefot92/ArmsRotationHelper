-- ============================================================
-- Arms Rotation Helper - Core.lua
-- Compatibility helpers, saved settings, combat state, localized
-- spell data, target tracking, and main-hand swing tracking.
--
-- This addon is an advisor. It never casts a spell or presses a
-- protected action for the player.
-- ============================================================

local ADDON_NAME, ns = ...

local BOOKTYPE_SPELL_VALUE = BOOKTYPE_SPELL or "spell"
local RAGE_POWER_TYPE = (Enum and Enum.PowerType and Enum.PowerType.Rage) or 1

ns.RAGE_POWER_TYPE = RAGE_POWER_TYPE
ns.VERSION = "1.6.1-beta.1"

-- Base-rank spell IDs are used only as stable, locale-independent
-- identifiers. When an ability is trained, the highest known rank
-- found in the spellbook is used for cooldown, cost, and cast-time
-- queries.
ns.ABILITIES = {
    HEROIC_STRIKE       = { id = 78,    target = true },
    BATTLE_SHOUT        = { id = 6673 },
    CHARGE              = { id = 100,   target = true },
    REND                = { id = 772,   target = true },
    THUNDER_CLAP        = { id = 6343 },
    HAMSTRING           = { id = 1715,  target = true },
    SUNDER_ARMOR        = { id = 7386,  target = true },
    BLOODRAGE           = { id = 2687 },
    OVERPOWER           = { id = 7384,  target = true },
    DEMORALIZING_SHOUT  = { id = 1160 },
    CLEAVE              = { id = 845,   target = true },
    EXECUTE             = { id = 5308,  target = true },
    SLAM                = { id = 1464,  target = true },
    INTERCEPT           = { id = 20252, target = true },
    BERSERKER_RAGE      = { id = 18499 },
    WHIRLWIND           = { id = 1680,  target = true },
    MORTAL_STRIKE       = { id = 12294, target = true },
    RECKLESSNESS        = { id = 1719 },
    VICTORY_RUSH        = { id = 34428, target = true },
    COMMANDING_SHOUT    = { id = 469 },
    SWEEPING_STRIKES    = { id = 12328 },
    DEATH_WISH          = { id = 12292 },

    BATTLE_STANCE       = { id = 2457 },
    DEFENSIVE_STANCE    = { id = 71 },
    BERSERKER_STANCE    = { id = 2458 },
}

ns.CONFIG = {
    -- Live game data is preferred. These are fallbacks only.
    COSTS = {
        HEROIC_STRIKE      = 15,
        BATTLE_SHOUT       = 10,
        CHARGE             = 0,
        REND               = 10,
        THUNDER_CLAP       = 20,
        HAMSTRING          = 10,
        SUNDER_ARMOR       = 15,
        BLOODRAGE          = 0,
        OVERPOWER          = 5,
        DEMORALIZING_SHOUT = 10,
        CLEAVE             = 20,
        EXECUTE            = 15,
        SLAM               = 15,
        WHIRLWIND          = 25,
        MORTAL_STRIKE      = 30,
        VICTORY_RUSH       = 0,
        SWEEPING_STRIKES   = 30,
        DEATH_WISH         = 0,
        RECKLESSNESS       = 0,
    },

    EXECUTE_HP_PCT            = 20,
    OVERPOWER_WINDOW          = 5,
    SLAM_REACTION_WINDOW      = 0.85,
    SLAM_GCD_WAIT_TOLERANCE   = 0.25,
    GCD_DURATION              = 1.50,
    IMPROVED_SLAM_MAX_CAST_MS = 750,
    SHOUT_REFRESH_AT          = 5,
    DEMO_SHOUT_REFRESH_AT     = 3,
    DEMO_SHOUT_MIN_TTD        = 10,
    REND_MIN_TTD              = 8,
    REND_MAX_TARGET_HP_PCT    = 90,
    SUNDER_MIN_TTD            = 12,
    SUNDER_LEVELING_MAX_STACK = 3,
    ENEMY_MEMORY              = 3.5,
    AOE_ENEMY_THRESHOLD       = 2,
    SWING_EARLY_TOLERANCE     = 0.25,
    RAGE_RESERVE_BUFFER       = 8,
    OVERPOWER_SWITCH_MAX_RAGE = 25,
    UI_TICK                   = 0.05,
    COOLDOWN_ROW_TICK         = 0.20,
}

-- Stance indices returned by GetShapeshiftForm() for Warriors.
ns.STANCE = {
    BATTLE = 1,
    DEFENSIVE = 2,
    BERSERKER = 3,
}

local IMPROVED_DEMO_SHOUT_RANK_SPELLS = {
    12324,
    12876,
    12877,
    12878,
    12879,
}

local ABILITY_STANCES = {
    CHARGE             = { [1] = true },
    OVERPOWER          = { [1] = true },
    REND               = { [1] = true, [2] = true },
    THUNDER_CLAP       = { [1] = true, [2] = true },
    SLAM               = { [1] = true, [3] = true },
    MORTAL_STRIKE      = { [1] = true, [3] = true },
    WHIRLWIND          = { [3] = true },
    EXECUTE            = { [1] = true, [3] = true },
    SWEEPING_STRIKES   = { [1] = true, [3] = true },
    RECKLESSNESS       = { [3] = true },
    VICTORY_RUSH       = { [1] = true, [3] = true },
}

local PREFERRED_STANCE = {
    CHARGE             = 1,
    OVERPOWER          = 1,
    REND               = 1,
    THUNDER_CLAP       = 1,
    SLAM               = 3,
    MORTAL_STRIKE      = 3,
    WHIRLWIND          = 3,
    EXECUTE            = 3,
    SWEEPING_STRIKES   = 3,
    RECKLESSNESS       = 3,
    VICTORY_RUSH       = 3,
}

ns.state = {
    playerGUID             = UnitGUID("player"),
    rage                   = 0,
    maxRage                = 100,
    inCombat               = false,
    moving                 = false,
    stance                 = 0,

    targetExists           = false,
    targetAttackable       = false,
    targetGUID             = nil,
    targetHPPercent        = 100,
    targetHealth           = 0,
    targetHealthMax        = 0,
    targetTTD              = 999,
    targetFirstSeenAt      = 0,
    targetLastSampleAt     = 0,
    targetLastHealth       = 0,
    targetSmoothedDPS      = 0,

    rendExpiration         = 0,
    sunderExpiration       = 0,
    sunderStacks           = 0,
    demoShoutExpiration    = 0,
    improvedDemoShoutRank  = 0,
    improvedDemoShoutMaxRank = 5,
    battleShoutExpiration  = 0,
    commandingExpiration   = 0,
    sweepingExpiration     = 0,

    overpowerWindowEnd     = 0,
    overpowerTargetGUID    = nil,

    mainhandSpeed          = 0,
    lastMainhandSwing      = 0,
    nextMainhandSwing      = 0,
    slamWindowStart        = 0,
    slamWindowEnd          = 0,
    swingTargetGUID        = nil,
    lastSwingWasReplacement = false,
    ignoredExtraAttacks    = 0,
    pendingExtraAttacks    = 0,
    lastSlamAt             = 0,

    nearbyEnemies          = {},
    enemyCount             = 0,
    knownSpells            = nil,
}

-- ------------------------------------------------------------
-- Saved settings
-- ------------------------------------------------------------

local function InitDB()
    ArmsRotationHelperDB = ArmsRotationHelperDB or {}
    local db = ArmsRotationHelperDB

    if db.schemaVersion  == nil then db.schemaVersion = 2 end
    if db.point          == nil then db.point = "CENTER" end
    if db.x              == nil then db.x = 0 end
    if db.y              == nil then db.y = 250 end
    if db.scale          == nil then db.scale = 1.0 end
    if db.showIcon       == nil then db.showIcon = true end
    if db.showGlow       == nil then db.showGlow = true end
    if db.showCooldowns  == nil then db.showCooldowns = true end
    if db.showSwingBar   == nil then db.showSwingBar = true end
    if db.showQueue      == nil then db.showQueue = true end
    if db.showWaitIndicator == nil then db.showWaitIndicator = true end
    if db.stanceAdvice   == nil then db.stanceAdvice = true end
    if db.locked         == nil then db.locked = true end
    if db.debugMode      == nil then db.debugMode = false end
    if db.testMode       == nil then db.testMode = false end
    if db.mode           == nil then db.mode = "auto" end
    if db.maintainSunder == nil then db.maintainSunder = false end
    if db.maintainDemoShout == nil then db.maintainDemoShout = false end
    if db.assignedShout  == nil then db.assignedShout = "battle" end

    if db.mode ~= "auto" and db.mode ~= "single" and db.mode ~= "aoe" then
        db.mode = "auto"
    end
    if db.assignedShout ~= "battle" and db.assignedShout ~= "commanding" then
        db.assignedShout = "battle"
    end

    ns.db = db
end

-- ------------------------------------------------------------
-- Error reporting
-- ------------------------------------------------------------

local seenErrors = {}

function ns.ReportOnce(context, err)
    local key = tostring(context) .. ":" .. tostring(err)
    if seenErrors[key] then return end
    seenErrors[key] = true
    print("|cffff6640Arms Rotation Helper|r: " .. tostring(context)
        .. " hit an error and was skipped (" .. tostring(err)
        .. "). Please report this message.")
end

-- ------------------------------------------------------------
-- WoW API compatibility helpers
-- ------------------------------------------------------------

function ns.GetSpellName(spellIdentifier)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellIdentifier)
        if ok and name then return name end
    end
    if GetSpellInfo then
        local name = GetSpellInfo(spellIdentifier)
        return name
    end
    return nil
end

function ns.GetSpellIcon(spellIdentifier)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spellIdentifier)
        if ok and icon then return icon end
    end
    if GetSpellTexture then
        local icon = GetSpellTexture(spellIdentifier)
        if icon then return icon end
    end
    if GetSpellInfo then
        local _, _, icon = GetSpellInfo(spellIdentifier)
        if icon then return icon end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function ns.GetSpellCastTimeMS(spellIdentifier)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellIdentifier)
        if ok and info then
            return info.castTime or 0
        end
    end
    if GetSpellInfo then
        local _, _, _, castTime = GetSpellInfo(spellIdentifier)
        return castTime or 0
    end
    return 0
end

function ns.GetCooldown(spellIdentifier)
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spellIdentifier)
        if ok and info then
            return info.startTime or 0, info.duration or 0, info.isEnabled
        end
    end
    if GetSpellCooldown then
        local start, duration, enabled = GetSpellCooldown(spellIdentifier)
        return start or 0, duration or 0, enabled
    end
    return 0, 0, nil
end

function ns.GetGCDInfo()
    -- 61304 is Blizzard's hidden global-cooldown spell. If it is not
    -- exposed by this client, the function safely returns no active GCD.
    return ns.GetCooldown(61304)
end

function ns.GetGCDRemaining()
    local start, duration = ns.GetGCDInfo()
    if not start or not duration or start == 0 or duration == 0 then return 0 end
    return math.max(0, start + duration - GetTime())
end

local function IsSameCooldown(startA, durationA, startB, durationB)
    if not startA or not startB or startA == 0 or startB == 0 then return false end
    return math.abs(startA - startB) <= 0.05
        and math.abs((durationA or 0) - (durationB or 0)) <= 0.05
end

function ns.GetCooldownRemaining(spellIdentifier, ignoreGCD)
    local start, duration = ns.GetCooldown(spellIdentifier)
    if start == 0 or duration == 0 then return 0 end
    if ignoreGCD then
        local gcdStart, gcdDuration = ns.GetGCDInfo()
        if IsSameCooldown(start, duration, gcdStart, gcdDuration) then
            return 0
        end
    end
    return math.max(0, start + duration - GetTime())
end

function ns.GetSpellRageCost(spellIdentifier, fallback)
    local getCosts = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
    if getCosts then
        local ok, costs = pcall(getCosts, spellIdentifier)
        if ok and costs then
            for _, costInfo in ipairs(costs) do
                if costInfo.type == RAGE_POWER_TYPE then
                    return costInfo.cost or fallback
                end
            end
        end
    end
    return fallback
end

function ns.GetItemSpellName(itemLink)
    if not itemLink then return nil end
    if C_Item and C_Item.GetItemSpell then
        local ok, name = pcall(C_Item.GetItemSpell, itemLink)
        if ok and name then return name end
    end
    if GetItemSpell then
        local ok, name = pcall(GetItemSpell, itemLink)
        if ok and name then return name end
    end
    return nil
end

function ns.GetItemCooldownInfo(slot)
    local start, duration, enabled = GetInventoryItemCooldown("player", slot)
    start, duration = start or 0, duration or 0
    local remaining = math.max(0, start + duration - GetTime())
    local ready = enabled ~= 0 and (start == 0 or duration == 0 or remaining <= 0.15)
    return ready, start, duration
end

-- ------------------------------------------------------------
-- Localized abilities and known ranks
-- ------------------------------------------------------------

function ns.RefreshAbilityMetadata()
    for _, ability in pairs(ns.ABILITIES) do
        ability.name = ns.GetSpellName(ability.id) or ability.name
        ability.icon = ns.GetSpellIcon(ability.id)
    end
end

function ns.RefreshKnownSpells()
    local known = {}
    local ok = pcall(function()
        local tabCount = GetNumSpellTabs and GetNumSpellTabs() or 0
        for tab = 1, tabCount do
            local _, _, offset, spellCount = GetSpellTabInfo(tab)
            if offset and spellCount then
                for index = offset + 1, offset + spellCount do
                    local name = GetSpellBookItemName(index, BOOKTYPE_SPELL_VALUE)
                    if name then
                        local spellType, spellID
                        if GetSpellBookItemInfo then
                            spellType, spellID = GetSpellBookItemInfo(index, BOOKTYPE_SPELL_VALUE)
                        end
                        if spellType == "SPELL" or spellType == "spell" or spellType == nil then
                            known[name] = {
                                id = spellID,
                                bookIndex = index,
                            }
                        end
                    end
                end
            end
        end
    end)

    if ok and next(known) ~= nil then
        ns.state.knownSpells = known
    end
end

function ns.GetAbilityName(key)
    local ability = ns.ABILITIES[key]
    return ability and (ability.name or ns.GetSpellName(ability.id)) or nil
end

function ns.GetAbilityIcon(key)
    local ability = ns.ABILITIES[key]
    if not ability then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    return ability.icon or ns.GetSpellIcon(ability.id)
end

function ns.GetAbilityIdentifier(key)
    local ability = ns.ABILITIES[key]
    if not ability then return nil end
    local name = ns.GetAbilityName(key)
    local known = name and ns.state.knownSpells and ns.state.knownSpells[name]
    return (known and known.id) or ability.id
end

function ns.PlayerKnowsAbility(key)
    local ability = ns.ABILITIES[key]
    if not ability then return false end
    local name = ns.GetAbilityName(key)
    if not ns.state.knownSpells then
        if IsPlayerSpell then
            local ok, result = pcall(IsPlayerSpell, ability.id)
            if ok and result ~= nil then return result == true end
        end
        return false
    end
    return name ~= nil and ns.state.knownSpells[name] ~= nil
end

function ns.GetAbilityCost(key)
    local identifier = ns.GetAbilityIdentifier(key)
    return ns.GetSpellRageCost(identifier, ns.CONFIG.COSTS[key] or 0)
end

function ns.GetAbilityCastTimeMS(key)
    return ns.GetSpellCastTimeMS(ns.GetAbilityIdentifier(key))
end

function ns.GetAbilityCooldownRemaining(key, ignoreGCD)
    return ns.GetCooldownRemaining(ns.GetAbilityIdentifier(key), ignoreGCD)
end

function ns.IsAbilityReady(key, tolerance)
    return ns.GetAbilityCooldownRemaining(key, true) <= (tolerance or 0.15)
end

function ns.IsAbilityInRange(key, unit)
    local ability = ns.ABILITIES[key]
    if not ability or not ability.target then return true end
    unit = unit or "target"
    local name = ns.GetAbilityName(key)
    if not name or not IsSpellInRange then return true end
    local result = IsSpellInRange(name, unit)
    return result == nil or result == 1
end

function ns.IsAbilityUsable(key)
    local identifier = ns.GetAbilityIdentifier(key)
    if not identifier or not IsUsableSpell then return true, false end
    local usable, insufficientPower = IsUsableSpell(identifier)
    return usable == true, insufficientPower == true
end

-- ------------------------------------------------------------
-- Aura and stance helpers
-- ------------------------------------------------------------

local function CasterMatches(sourceUnit, requiredCaster)
    if not requiredCaster then return true end
    if not sourceUnit then return false end
    if UnitIsUnit then
        local ok, same = pcall(UnitIsUnit, sourceUnit, requiredCaster)
        if ok then return same == true end
    end
    return sourceUnit == requiredCaster
end

function ns.FindAura(unit, abilityOrName, harmful, requiredCaster)
    if not UnitExists(unit) then return nil end

    local name = ns.ABILITIES[abilityOrName] and ns.GetAbilityName(abilityOrName) or abilityOrName
    if not name then return nil end

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local filter = harmful and "HARMFUL" or "HELPFUL"
        local index = 1
        while true do
            local data = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
            if not data then return nil end
            if data.name == name and CasterMatches(data.sourceUnit, requiredCaster) then
                return {
                    expirationTime = data.expirationTime or 0,
                    duration = data.duration or 0,
                    applications = data.applications or 0,
                    sourceUnit = data.sourceUnit,
                    spellId = data.spellId,
                }
            end
            index = index + 1
        end
    end

    local index = 1
    while true do
        local auraName, _, count, _, duration, expirationTime, sourceUnit, _, _, spellId
        if harmful then
            auraName, _, count, _, duration, expirationTime, sourceUnit, _, _, spellId = UnitDebuff(unit, index)
        else
            auraName, _, count, _, duration, expirationTime, sourceUnit, _, _, spellId = UnitBuff(unit, index)
        end
        if not auraName then return nil end
        if auraName == name and CasterMatches(sourceUnit, requiredCaster) then
            return {
                expirationTime = expirationTime or 0,
                duration = duration or 0,
                applications = count or 0,
                sourceUnit = sourceUnit,
                spellId = spellId,
            }
        end
        index = index + 1
    end
end

function ns.GetStance()
    return (GetShapeshiftForm and GetShapeshiftForm()) or 0
end

function ns.GetStanceKey(stanceIndex)
    if stanceIndex == ns.STANCE.BATTLE then return "BATTLE_STANCE" end
    if stanceIndex == ns.STANCE.DEFENSIVE then return "DEFENSIVE_STANCE" end
    if stanceIndex == ns.STANCE.BERSERKER then return "BERSERKER_STANCE" end
    return nil
end

function ns.GetStanceLabel(stanceIndex)
    local key = ns.GetStanceKey(stanceIndex)
    return key and ns.GetAbilityName(key) or "Unknown Stance"
end

function ns.IsAbilityStanceAllowed(key)
    local allowed = ABILITY_STANCES[key]
    if not allowed then return true end
    return allowed[ns.state.stance] == true
end

function ns.GetPreferredStanceForAbility(key, stanceIndex)
    local current = stanceIndex
    if current == nil then current = ns.state.stance end
    local allowed = ABILITY_STANCES[key]
    if not allowed or allowed[current] then return nil end
    return PREFERRED_STANCE[key]
end

function ns.IsImprovedSlamReady()
    if not ns.PlayerKnowsAbility("SLAM") then return false end
    local castTime = ns.GetAbilityCastTimeMS("SLAM")
    return castTime > 0 and castTime <= ns.CONFIG.IMPROVED_SLAM_MAX_CAST_MS
end

function ns.RefreshTalentState()
    local rank = 0
    local maxRank = 5
    local expectedName = ns.GetSpellName(IMPROVED_DEMO_SHOUT_RANK_SPELLS[1])

    if GetNumTalents and GetTalentInfo then
        local tabCount = (GetNumTalentTabs and GetNumTalentTabs()) or 3
        for tabIndex = 1, tabCount do
            local talentCount = GetNumTalents(tabIndex) or 0
            for talentIndex = 1, talentCount do
                local name, icon, tier, column, currentRank, talentMaxRank =
                    GetTalentInfo(tabIndex, talentIndex)
                local nameMatches = expectedName and name == expectedName
                local positionMatches = tabIndex == 2
                    and tier == 2
                    and column == 2
                    and icon == 132366

                if nameMatches or positionMatches then
                    rank = currentRank or 0
                    maxRank = talentMaxRank or 5
                    break
                end
            end
            if rank > 0 then break end
        end
    end

    -- Passive talent ranks are also player spells on supported Classic
    -- clients. This is a fallback for clients whose talent UI is not loaded.
    if rank == 0 and IsPlayerSpell then
        for index, spellID in ipairs(IMPROVED_DEMO_SHOUT_RANK_SPELLS) do
            local ok, known = pcall(IsPlayerSpell, spellID)
            if ok and known then rank = index end
        end
    end

    ns.state.improvedDemoShoutRank = rank
    ns.state.improvedDemoShoutMaxRank = maxRank
    return rank, maxRank
end

function ns.HasImprovedDemoShout()
    return (ns.state.improvedDemoShoutRank or 0) > 0
end

-- ------------------------------------------------------------
-- Enemy and swing tracking
-- ------------------------------------------------------------

local function HasFlag(flags, flag)
    if not flags or not flag then return true end
    local bitLibrary = bit or bit32
    if not bitLibrary or not bitLibrary.band then return true end
    return bitLibrary.band(flags, flag) ~= 0
end

local function IsHostileCombatLogObject(flags)
    return HasFlag(flags, COMBATLOG_OBJECT_REACTION_HOSTILE)
end

function ns.MarkEnemy(guid, flags)
    if not guid or guid == ns.state.playerGUID then return end
    if flags and not IsHostileCombatLogObject(flags) then return end
    ns.state.nearbyEnemies[guid] = GetTime()
end

function ns.CountNearbyEnemies()
    local now = GetTime()
    local count = 0
    for guid, seenAt in pairs(ns.state.nearbyEnemies) do
        if now - seenAt > ns.CONFIG.ENEMY_MEMORY then
            ns.state.nearbyEnemies[guid] = nil
        else
            count = count + 1
        end
    end

    if ns.state.targetAttackable and ns.state.targetGUID
        and not ns.state.nearbyEnemies[ns.state.targetGUID] then
        count = math.max(1, count)
    end
    return count
end

function ns.GetMainhandSpeed()
    if not UnitAttackSpeed then return 0 end
    local speed = UnitAttackSpeed("player")
    return speed or 0
end

function ns.RescaleSwingRemaining(remaining, oldSpeed, newSpeed)
    remaining = math.max(0, tonumber(remaining) or 0)
    oldSpeed = tonumber(oldSpeed) or 0
    newSpeed = tonumber(newSpeed) or 0

    if remaining <= 0 or oldSpeed <= 0 or newSpeed <= 0 then
        return remaining
    end

    local fractionRemaining = remaining / oldSpeed
    fractionRemaining = math.max(0, math.min(1, fractionRemaining))
    return fractionRemaining * newSpeed
end

function ns.UpdateAttackSpeed()
    local now = GetTime()
    local oldSpeed = ns.state.mainhandSpeed or 0
    local newSpeed = ns.GetMainhandSpeed()

    if newSpeed <= 0 then return end
    if oldSpeed > 0 and ns.state.nextMainhandSwing > now then
        local remaining = ns.state.nextMainhandSwing - now
        ns.state.nextMainhandSwing = now
            + ns.RescaleSwingRemaining(remaining, oldSpeed, newSpeed)
    end
    ns.state.mainhandSpeed = newSpeed
    if oldSpeed > 0 and math.abs(newSpeed - oldSpeed) > 0.01
        and ns.Diagnostics_AddEvent then
        ns.Diagnostics_AddEvent("SWING_SPEED", newSpeed)
    end
end

function ns.ResetSwingTracking()
    ns.state.mainhandSpeed = ns.GetMainhandSpeed()
    ns.state.lastMainhandSwing = 0
    ns.state.nextMainhandSwing = 0
    ns.state.slamWindowStart = 0
    ns.state.slamWindowEnd = 0
    ns.state.swingTargetGUID = nil
    ns.state.lastSwingWasReplacement = false
    ns.state.pendingExtraAttacks = 0
end

local function IsExpectedMainhandSwing(now)
    if ns.state.nextMainhandSwing <= 0 then return true end
    local tolerance = math.min(
        ns.CONFIG.SWING_EARLY_TOLERANCE,
        math.max(0.08, ns.state.mainhandSpeed * 0.10)
    )
    return now + tolerance >= ns.state.nextMainhandSwing
end

function ns.RecordMainhandSwing(now, replacement, destGUID)
    now = now or GetTime()
    ns.UpdateAttackSpeed()

    -- TBC extra attacks do not reset the underlying main-hand timer.
    -- SPELL_EXTRA_ATTACKS is emitted immediately before the extra swing.
    if not replacement and ns.state.pendingExtraAttacks > 0 then
        ns.state.pendingExtraAttacks = ns.state.pendingExtraAttacks - 1
        ns.state.ignoredExtraAttacks = ns.state.ignoredExtraAttacks + 1
        if ns.Diagnostics_AddEvent then
            ns.Diagnostics_AddEvent(
                "EXTRA_ATTACK_IGNORED",
                ns.state.pendingExtraAttacks
            )
        end
        return false
    end

    if not IsExpectedMainhandSwing(now) then
        ns.state.ignoredExtraAttacks = ns.state.ignoredExtraAttacks + 1
        if ns.Diagnostics_AddEvent then
            ns.Diagnostics_AddEvent("EARLY_SWING_IGNORED")
        end
        return false
    end

    ns.state.lastMainhandSwing = now
    ns.state.nextMainhandSwing = now + math.max(0.1, ns.state.mainhandSpeed)
    ns.state.slamWindowStart = now
    ns.state.slamWindowEnd = now + ns.CONFIG.SLAM_REACTION_WINDOW
    ns.state.swingTargetGUID = destGUID
    ns.state.lastSwingWasReplacement = replacement == true
    if ns.Diagnostics_AddEvent then
        ns.Diagnostics_AddEvent(
            replacement and "REPLACEMENT_SWING" or "MAINHAND_SWING",
            ns.state.mainhandSpeed
        )
    end
    return true
end

local function RecordSlamCompletion(now)
    ns.UpdateAttackSpeed()
    ns.state.lastSlamAt = now
    ns.state.slamWindowStart = 0
    ns.state.slamWindowEnd = 0
    ns.state.nextMainhandSwing = now + math.max(0.1, ns.state.mainhandSpeed)
    if ns.Diagnostics_AddEvent then
        ns.Diagnostics_AddEvent("SLAM_CAST", ns.state.mainhandSpeed)
    end
end

function ns.GetSwingRemaining()
    if ns.state.nextMainhandSwing <= 0 then return 0 end
    return math.max(0, ns.state.nextMainhandSwing - GetTime())
end

function ns.GetSwingProgress()
    local speed = ns.state.mainhandSpeed or 0
    if speed <= 0 or ns.state.nextMainhandSwing <= 0 then return 0 end
    return math.max(0, math.min(1, 1 - ns.GetSwingRemaining() / speed))
end

function ns.IsSlamWindowOpen()
    local now = GetTime()
    if now < ns.state.slamWindowStart or now > ns.state.slamWindowEnd then return false end
    if ns.state.swingTargetGUID and ns.state.targetGUID
        and ns.state.swingTargetGUID ~= ns.state.targetGUID then
        return false
    end
    return true
end

-- ------------------------------------------------------------
-- Live state refresh
-- ------------------------------------------------------------

local function ResetTargetSampling(guid, health, now)
    ns.state.targetGUID = guid
    ns.state.targetFirstSeenAt = now
    ns.state.targetLastSampleAt = now
    ns.state.targetLastHealth = health or 0
    ns.state.targetSmoothedDPS = 0
    ns.state.targetTTD = 999
end

local function UpdateTargetSampling(health, now)
    local elapsed = now - (ns.state.targetLastSampleAt or now)
    if elapsed < 0.25 then return end

    local previous = ns.state.targetLastHealth or health
    local lost = previous - health
    if lost > 0 then
        local currentDPS = lost / elapsed
        if ns.state.targetSmoothedDPS <= 0 then
            ns.state.targetSmoothedDPS = currentDPS
        else
            ns.state.targetSmoothedDPS =
                ns.state.targetSmoothedDPS * 0.65 + currentDPS * 0.35
        end
    elseif lost < 0 then
        ns.state.targetSmoothedDPS = ns.state.targetSmoothedDPS * 0.75
    end

    ns.state.targetLastHealth = health
    ns.state.targetLastSampleAt = now
    if ns.state.targetSmoothedDPS > 0 then
        ns.state.targetTTD = health / ns.state.targetSmoothedDPS
    else
        ns.state.targetTTD = 999
    end
end

local function UpdateTargetState(now)
    local exists = UnitExists("target")
        and not UnitIsDeadOrGhost("target")
        and UnitCanAttack("player", "target")

    if not exists then
        ns.state.targetExists = false
        ns.state.targetAttackable = false
        ns.state.targetGUID = nil
        ns.state.targetHPPercent = 100
        ns.state.targetHealth = 0
        ns.state.targetHealthMax = 0
        ns.state.targetTTD = 999
        ns.state.rendExpiration = 0
        ns.state.sunderExpiration = 0
        ns.state.sunderStacks = 0
        ns.state.demoShoutExpiration = 0
        return
    end

    local guid = UnitGUID("target")
    local health = UnitHealth("target") or 0
    local healthMax = UnitHealthMax("target") or 0

    ns.state.targetExists = true
    ns.state.targetAttackable = true
    ns.state.targetHealth = health
    ns.state.targetHealthMax = healthMax
    ns.state.targetHPPercent = healthMax > 0 and (health / healthMax * 100) or 100

    if guid ~= ns.state.targetGUID then
        ResetTargetSampling(guid, health, now)
    else
        UpdateTargetSampling(health, now)
    end

    local rend = ns.FindAura("target", "REND", true, "player")
    ns.state.rendExpiration = rend and rend.expirationTime or 0

    local sunder = ns.FindAura("target", "SUNDER_ARMOR", true)
    ns.state.sunderExpiration = sunder and sunder.expirationTime or 0
    ns.state.sunderStacks = sunder and sunder.applications or 0

    local demoShout = ns.FindAura(
        "target",
        "DEMORALIZING_SHOUT",
        true,
        "player"
    )
    ns.state.demoShoutExpiration =
        demoShout and demoShout.expirationTime or 0

    if ns.state.inCombat and guid then
        ns.state.nearbyEnemies[guid] = now
    end
end

function ns.RefreshState()
    local now = GetTime()
    ns.state.rage = UnitPower("player", RAGE_POWER_TYPE) or 0
    ns.state.maxRage = UnitPowerMax("player", RAGE_POWER_TYPE) or 100
    ns.state.inCombat = not not UnitAffectingCombat("player")
    ns.state.moving = GetUnitSpeed and (GetUnitSpeed("player") or 0) > 0 or false
    ns.state.stance = ns.GetStance()
    ns.UpdateAttackSpeed()
    UpdateTargetState(now)

    local battleShout = ns.FindAura("player", "BATTLE_SHOUT", false)
    local commanding = ns.FindAura("player", "COMMANDING_SHOUT", false)
    local sweeping = ns.FindAura("player", "SWEEPING_STRIKES", false, "player")
    ns.state.battleShoutExpiration = battleShout and battleShout.expirationTime or 0
    ns.state.commandingExpiration = commanding and commanding.expirationTime or 0
    ns.state.sweepingExpiration = sweeping and sweeping.expirationTime or 0
    ns.state.enemyCount = ns.CountNearbyEnemies()

    if ns.state.overpowerWindowEnd <= now then
        ns.state.overpowerWindowEnd = 0
        ns.state.overpowerTargetGUID = nil
    end
end

-- ------------------------------------------------------------
-- Combat log
-- ------------------------------------------------------------

local function EventIsPlayerAttack(subevent)
    return subevent == "SWING_DAMAGE"
        or subevent == "SWING_MISSED"
        or subevent == "SPELL_DAMAGE"
        or subevent == "SPELL_MISSED"
        or subevent == "RANGE_DAMAGE"
        or subevent == "RANGE_MISSED"
end

local function GetMissType(cle, subevent)
    if subevent == "SWING_MISSED" then return cle[12] end
    if subevent == "SPELL_MISSED" or subevent == "RANGE_MISSED" then return cle[15] end
    return nil
end

local function IsOffhandSwing(cle, subevent)
    if subevent == "SWING_DAMAGE" then return cle[21] == true end
    if subevent == "SWING_MISSED" then return cle[13] == true end
    return false
end

local function GetCombatLogAbilityKey(cle)
    local eventSpellName = cle[13]
    if not eventSpellName then return nil end

    for key in pairs(ns.ABILITIES) do
        if eventSpellName == ns.GetAbilityName(key) then
            return key
        end
    end
    return nil
end

local function HandleCombatLogEvent()
    local cle = { CombatLogGetCurrentEventInfo() }
    local now = GetTime()
    local subevent = cle[2]
    local sourceGUID = cle[4]
    local sourceFlags = cle[6]
    local destGUID = cle[8]
    local destFlags = cle[10]

    if subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" then
        ns.state.nearbyEnemies[destGUID] = nil
        if ns.state.overpowerTargetGUID == destGUID then
            ns.state.overpowerTargetGUID = nil
            ns.state.overpowerWindowEnd = 0
        end
        return
    end

    if sourceGUID == ns.state.playerGUID then
        local abilityKey
        if subevent == "SPELL_CAST_SUCCESS"
            or subevent == "SPELL_DAMAGE"
            or subevent == "SPELL_MISSED" then
            abilityKey = GetCombatLogAbilityKey(cle)
        end

        if EventIsPlayerAttack(subevent) and destGUID then
            ns.MarkEnemy(destGUID, destFlags)
        end

        local missType = GetMissType(cle, subevent)
        if missType == "DODGE" and destGUID then
            ns.state.overpowerTargetGUID = destGUID
            ns.state.overpowerWindowEnd = now + ns.CONFIG.OVERPOWER_WINDOW
        end

        if subevent == "SPELL_EXTRA_ATTACKS" then
            ns.state.pendingExtraAttacks = ns.state.pendingExtraAttacks
                + math.max(1, tonumber(cle[15]) or 1)
        elseif (subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED")
            and not IsOffhandSwing(cle, subevent) then
            ns.RecordMainhandSwing(now, false, destGUID)
        elseif (subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED")
            and (abilityKey == "HEROIC_STRIKE" or abilityKey == "CLEAVE") then
            ns.RecordMainhandSwing(now, true, destGUID)
            if ns.Diagnostics_AddAbilityUse then
                ns.Diagnostics_AddAbilityUse(abilityKey, "replacement")
            end
        elseif subevent == "SPELL_CAST_SUCCESS" then
            -- Heroic Strike and Cleave are recorded only when their queued
            -- replacement swing actually lands or misses.
            if abilityKey
                and abilityKey ~= "HEROIC_STRIKE"
                and abilityKey ~= "CLEAVE"
                and ns.Diagnostics_AddAbilityUse then
                ns.Diagnostics_AddAbilityUse(abilityKey, "cast")
            end

            if abilityKey == "SLAM" then
                RecordSlamCompletion(now)
            elseif abilityKey == "OVERPOWER" then
                ns.state.overpowerTargetGUID = nil
                ns.state.overpowerWindowEnd = 0
            end
        end
    elseif destGUID == ns.state.playerGUID and EventIsPlayerAttack(subevent) then
        ns.MarkEnemy(sourceGUID, sourceFlags)
    end
end

-- ------------------------------------------------------------
-- Events
-- ------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
ns.eventFrame = eventFrame

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("UNIT_ATTACK_SPEED")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName ~= ADDON_NAME then return end
        InitDB()
        ns.RefreshAbilityMetadata()
        ns.RefreshKnownSpells()
        ns.RefreshTalentState()
        ns.state.playerGUID = UnitGUID("player")
        ns.ResetSwingTracking()
        ns.RefreshState()
        if ns.Display_ApplySettings then ns.Display_ApplySettings() end
        print("|cff4477ffArms Rotation Helper|r " .. ns.VERSION
            .. " loaded. Type /arh for settings.")
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.state.playerGUID = UnitGUID("player")
        ns.RefreshAbilityMetadata()
        ns.RefreshKnownSpells()
        ns.RefreshTalentState()
        ns.ResetSwingTracking()
        ns.RefreshState()
    elseif event == "SPELLS_CHANGED" or event == "CHARACTER_POINTS_CHANGED" then
        ns.RefreshKnownSpells()
        ns.RefreshAbilityMetadata()
        ns.RefreshTalentState()
        if ns.Settings_Refresh then ns.Settings_Refresh() end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        ns.ResetSwingTracking()
    elseif event == "UNIT_ATTACK_SPEED" then
        local unit = ...
        if unit == "player" then ns.UpdateAttackSpeed() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.Diagnostics_AddEvent then
            ns.Diagnostics_AddEvent("COMBAT_END")
        end
        ns.state.nearbyEnemies = {}
        ns.state.enemyCount = ns.state.targetAttackable and 1 or 0
        ns.ResetSwingTracking()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if ns.Diagnostics_AddEvent then
            ns.Diagnostics_AddEvent("COMBAT_START")
        end
        ns.RefreshState()
    elseif event == "PLAYER_TARGET_CHANGED" then
        ns.RefreshState()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local ok, err = pcall(HandleCombatLogEvent)
        if not ok then ns.ReportOnce("Combat log handling", err) end
    end
end)

-- ------------------------------------------------------------
-- Slash commands
-- ------------------------------------------------------------

local function Trim(text)
    return (text:match("^%s*(.-)%s*$"))
end

local function RefreshSettingsPanel()
    if ns.Settings_Refresh then ns.Settings_Refresh() end
end

local function ToggleSetting(key)
    ns.db[key] = not ns.db[key]
    if ns.Display_ApplySettings then ns.Display_ApplySettings() end
    RefreshSettingsPanel()
    return ns.db[key]
end

local function OnOff(value)
    return value and "ON" or "OFF"
end

local function PrintSimulatorCheck(prefix)
    if not ns.Simulator_RunSelfCheck then
        print(prefix .. "Simulator is not available.")
        return
    end

    local passed, total, failures = ns.Simulator_RunSelfCheck()
    local color = passed == total and "|cff40ff40" or "|cffff4040"
    print(prefix .. color .. passed .. "/" .. total
        .. " simulator checks passed.|r")
    for _, failure in ipairs(failures) do
        print("  |cffff6640FAIL|r " .. failure)
    end
end

local function StartSimulator(prefix, name)
    if not ns.Simulator_Start then
        print(prefix .. "Simulator is not available.")
        return
    end

    if ns.Diagnostics_IsActive and ns.Diagnostics_IsActive()
        and ns.Diagnostics_Stop then
        ns.Diagnostics_Stop("simulator")
        print(prefix .. "Diagnostic recording stopped before simulation.")
    end

    local ok, err = ns.Simulator_Start(name)
    if not ok then
        print(prefix .. err)
        print(prefix .. "Use /arh sim list to see available scenarios.")
        return
    end

    print(prefix .. "Simulator started: "
        .. ns.Simulator_GetScenarioLabel(name) .. ".")
    print(prefix .. "Each step lasts 3.5 seconds. Use /arh sim next or /arh sim stop.")
    PrintSimulatorCheck(prefix)
    RefreshSettingsPanel()
end

SLASH_ARMSROTATIONHELPER1 = "/arh"
SLASH_ARMSROTATIONHELPER2 = "/armshelper"

SlashCmdList["ARMSROTATIONHELPER"] = function(message)
    message = Trim(message or ""):lower()
    local prefix = "|cff4477ffArms Rotation Helper|r: "

    if message == "" or message == "config" or message == "options" then
        if ns.Settings_Toggle then
            ns.Settings_Toggle()
        else
            print(prefix .. "Settings panel is not available.")
        end
    elseif message == "lock" then
        ns.db.locked = true
        if ns.Display_ApplySettings then ns.Display_ApplySettings() end
        RefreshSettingsPanel()
        print(prefix .. "Locked.")
    elseif message == "unlock" then
        ns.db.locked = false
        if ns.Display_ApplySettings then ns.Display_ApplySettings() end
        RefreshSettingsPanel()
        print(prefix .. "Unlocked. Drag the main display, then use /arh lock.")
    elseif message == "icon" then
        print(prefix .. "Main icon: " .. OnOff(ToggleSetting("showIcon")))
    elseif message == "glow" then
        print(prefix .. "Action-bar glow: " .. OnOff(ToggleSetting("showGlow")))
    elseif message == "cooldowns" then
        print(prefix .. "Cooldown and trinket row: " .. OnOff(ToggleSetting("showCooldowns")))
    elseif message == "swing" then
        print(prefix .. "Swing bar: " .. OnOff(ToggleSetting("showSwingBar")))
    elseif message == "queue" then
        print(prefix .. "Heroic Strike/Cleave queue indicator: " .. OnOff(ToggleSetting("showQueue")))
    elseif message == "wait" then
        print(prefix .. "Intentional wait indicator: "
            .. OnOff(ToggleSetting("showWaitIndicator")))
    elseif message == "stance" then
        print(prefix .. "Optional stance advice: " .. OnOff(ToggleSetting("stanceAdvice")))
    elseif message == "sunder" then
        print(prefix .. "Maintain five Sunder Armor stacks: " .. OnOff(ToggleSetting("maintainSunder")))
    elseif message == "demo" then
        local rank = ns.state.improvedDemoShoutRank or 0
        if rank <= 0 and not ns.db.maintainDemoShout then
            print(prefix .. "Demoralizing Shout maintenance requires at least "
                .. "one point in Improved Demoralizing Shout.")
        else
            print(prefix .. "Maintain Improved Demoralizing Shout: "
                .. OnOff(ToggleSetting("maintainDemoShout"))
                .. " (talent rank " .. rank .. "/"
                .. (ns.state.improvedDemoShoutMaxRank or 5) .. ").")
        end
    elseif message == "debug" then
        print(prefix .. "Debug panel: " .. OnOff(ToggleSetting("debugMode")))
    elseif message == "test" then
        if not ns.db.testMode
            and ns.Diagnostics_IsActive
            and ns.Diagnostics_IsActive()
            and ns.Diagnostics_Stop then
            ns.Diagnostics_Stop("preview")
            print(prefix .. "Diagnostic recording stopped before display preview.")
        end
        if ns.Simulator_IsActive and ns.Simulator_IsActive() then
            ns.Simulator_Stop()
        end
        ns.db.testMode = not ns.db.testMode
        if ns.Display_SetTestMode then ns.Display_SetTestMode(ns.db.testMode) end
        RefreshSettingsPanel()
        print(prefix .. "Display test mode: " .. OnOff(ns.db.testMode))
    elseif message == "sim" or message == "sim all" then
        StartSimulator(prefix, "all")
    elseif message == "sim stop" then
        if ns.Simulator_Stop and ns.Simulator_Stop() then
            RefreshSettingsPanel()
            print(prefix .. "Simulator stopped. Live recommendations restored.")
        else
            print(prefix .. "Simulator is already stopped.")
        end
    elseif message == "sim next" then
        if ns.Simulator_Next and ns.Simulator_Next() then
            RefreshSettingsPanel()
            print(prefix .. "Advanced to the next simulator step.")
        else
            print(prefix .. "Start it first with /arh sim.")
        end
    elseif message == "sim check" then
        PrintSimulatorCheck(prefix)
    elseif message == "record" or message == "record start" then
        if not ns.Diagnostics_Start then
            print(prefix .. "Diagnostic recorder is not available.")
        elseif message == "record"
            and ns.Diagnostics_IsActive
            and ns.Diagnostics_IsActive() then
            ns.Diagnostics_Stop()
            print(prefix .. "Diagnostic recording stopped. Use /arh report.")
        else
            local ok, err = ns.Diagnostics_Start()
            if ok then
                print(prefix .. "Recording live decisions for up to 60 seconds. "
                    .. "Use /arh record stop when finished.")
            else
                print(prefix .. tostring(err))
            end
        end
    elseif message == "record stop" then
        if ns.Diagnostics_Stop and ns.Diagnostics_Stop() then
            print(prefix .. "Diagnostic recording stopped. Use /arh report.")
        else
            print(prefix .. "No diagnostic recording is active.")
        end
    elseif message == "record clear" then
        if ns.Diagnostics_Clear then ns.Diagnostics_Clear() end
        print(prefix .. "Diagnostic report cleared.")
    elseif message == "report" then
        if ns.Diagnostics_OpenReport then
            ns.Diagnostics_OpenReport()
        else
            print(prefix .. "Diagnostic report window is not available.")
        end
    elseif message == "sim list" then
        local names = ns.Simulator_GetScenarioNames
            and ns.Simulator_GetScenarioNames() or {}
        print(prefix .. "Simulator scenarios:")
        print("  all - complete suite")
        for _, name in ipairs(names) do
            print("  " .. name .. " - " .. ns.Simulator_GetScenarioLabel(name))
        end
    elseif message:match("^sim%s+") then
        local name = message:match("^sim%s+(%a+)")
        StartSimulator(prefix, name)
    elseif message == "mode" then
        local order = { auto = "single", single = "aoe", aoe = "auto" }
        ns.db.mode = order[ns.db.mode] or "auto"
        RefreshSettingsPanel()
        print(prefix .. "Target mode: " .. ns.db.mode)
    elseif message:match("^mode%s+") then
        local value = message:match("^mode%s+(%a+)")
        if value == "auto" or value == "single" or value == "aoe" then
            ns.db.mode = value
            RefreshSettingsPanel()
            print(prefix .. "Target mode set to " .. value .. ".")
        else
            print(prefix .. "Use /arh mode auto, /arh mode single, or /arh mode aoe.")
        end
    elseif message:match("^shout%s+") then
        local value = message:match("^shout%s+(%a+)")
        if value == "battle" or value == "commanding" then
            ns.db.assignedShout = value
            RefreshSettingsPanel()
            print(prefix .. "Assigned shout set to " .. value .. ".")
        else
            print(prefix .. "Use /arh shout battle or /arh shout commanding.")
        end
    elseif message:match("^scale%s+") then
        local value = tonumber(message:match("^scale%s+([%d%.]+)"))
        if value and value >= 0.3 and value <= 3 then
            ns.db.scale = value
            if ns.Display_ApplySettings then ns.Display_ApplySettings() end
            RefreshSettingsPanel()
            print(prefix .. "Scale set to " .. value .. ".")
        else
            print(prefix .. "Give a number from 0.3 to 3, for example /arh scale 1.2.")
        end
    elseif message == "reset" then
        ns.db.point, ns.db.x, ns.db.y, ns.db.scale = "CENTER", 0, 250, 1.0
        if ns.Display_ApplySettings then ns.Display_ApplySettings() end
        RefreshSettingsPanel()
        print(prefix .. "Position and scale reset.")
    elseif message == "debug spells" then
        local list = {}
        for name in pairs(ns.state.knownSpells or {}) do
            table.insert(list, name)
        end
        table.sort(list)
        print(prefix .. #list .. " known spellbook entries:")
        if #list > 0 then print("  " .. table.concat(list, ", ")) end
    else
        print(prefix .. "commands:")
        print("  /arh                      - open the settings panel")
        print("  /arh help                 - show this command list")
        print("  /arh lock | unlock       - lock or move the display")
        print("  /arh mode auto|single|aoe - target-count behavior")
        print("  /arh shout battle|commanding - select assigned shout")
        print("  /arh stance              - toggle optional stance advice")
        print("  /arh swing               - toggle the main-hand swing bar")
        print("  /arh queue               - toggle HS/Cleave queue advice")
        print("  /arh wait                - toggle intentional wait advice")
        print("  /arh sunder              - toggle five-stack Sunder assignment")
        print("  /arh demo                - toggle talented Demo Shout assignment")
        print("  /arh icon | glow          - toggle main icon/action-bar glow")
        print("  /arh cooldowns            - toggle cooldown and trinket row")
        print("  /arh scale 1.2            - resize the complete display")
        print("  /arh debug                - toggle live diagnostic information")
        print("  /arh test                 - preview the high-level display")
        print("  /arh sim [scenario]       - run deterministic rotation scenarios")
        print("  /arh sim next|stop|check  - control or verify the simulator")
        print("  /arh record [start|stop]  - capture up to 60s of live decisions")
        print("  /arh report               - open the copyable private report")
        print("  /arh record clear         - erase the in-memory report")
        print("  /arh reset                - reset display position and scale")
    end
end
