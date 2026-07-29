-- ============================================================
-- Arms Rotation Helper - Rotation.lua
-- Level-adaptive two-handed PvE recommendations.
--
-- The endgame profile is swing-driven:
--   main-hand swing -> Slam -> Mortal Strike / Whirlwind / filler
--
-- Heroic Strike and Cleave are evaluated separately because they
-- are queued for the next main-hand swing and must not hide the
-- primary GCD recommendation.
-- ============================================================

local ADDON_NAME, ns = ...

local function Decision(key, reason)
    if not key then return nil end
    local preferredStance
    if ns.db.stanceAdvice then
        preferredStance = ns.GetPreferredStanceForAbility(key)
    end
    return {
        ability = key,
        reason = reason or "",
        stance = preferredStance,
    }
end

local function Knows(key)
    return ns.PlayerKnowsAbility(key)
end

local function HasRage(key, extra)
    return ns.state.rage >= ns.GetAbilityCost(key) + (extra or 0)
end

local function Ready(key, tolerance)
    return Knows(key) and ns.IsAbilityReady(key, tolerance)
end

local function TargetAbilityAvailable(key, tolerance)
    if not ns.state.targetAttackable then return false end
    if not Ready(key, tolerance) then return false end
    if not HasRage(key) then return false end
    return ns.IsAbilityInRange(key, "target")
end

local function GetAssignedShout()
    if ns.db.assignedShout == "commanding" and Knows("COMMANDING_SHOUT") then
        return "COMMANDING_SHOUT", ns.state.commandingExpiration
    end
    return "BATTLE_SHOUT", ns.state.battleShoutExpiration
end

local function ShouldRefreshShout()
    local key, expiration = GetAssignedShout()
    if not Knows(key) or not HasRage(key) then return nil end
    local remaining = (expiration or 0) - GetTime()
    if expiration == 0 or remaining <= ns.CONFIG.SHOUT_REFRESH_AT then
        return key
    end
    return nil
end

local function GetTargetMode()
    local count = ns.state.enemyCount or 0
    if ns.db.mode == "single" then
        return false, math.max(1, count)
    elseif ns.db.mode == "aoe" then
        return true, math.max(ns.CONFIG.AOE_ENEMY_THRESHOLD, count)
    end
    return count >= ns.CONFIG.AOE_ENEMY_THRESHOLD, count
end

local function CanUseVictoryRush()
    if not TargetAbilityAvailable("VICTORY_RUSH") then return false end
    local usable, insufficientPower = ns.IsAbilityUsable("VICTORY_RUSH")
    return usable and not insufficientPower
end

local function CanUseOverpower()
    local s = ns.state
    if s.targetHPPercent <= ns.CONFIG.EXECUTE_HP_PCT then return false end
    if s.overpowerWindowEnd <= GetTime() then return false end
    if not s.overpowerTargetGUID or s.overpowerTargetGUID ~= s.targetGUID then return false end
    return TargetAbilityAvailable("OVERPOWER")
end

-- Bloodrage is intentionally kept simple: it is a low-Rage recovery
-- suggestion, never allowed to replace a ready core attack.
local function CanUseBloodrage()
    return ns.state.inCombat
        and ns.state.rage < 10
        and Ready("BLOODRAGE")
end

local function ShouldMaintainSunder()
    if not TargetAbilityAvailable("SUNDER_ARMOR") then return false end
    if ns.state.targetTTD < 8 then return false end

    if ns.db.maintainSunder then
        local remaining = ns.state.sunderExpiration - GetTime()
        return ns.state.sunderStacks < 5 or remaining <= 3
    end

    -- While leveling, Sunder is a useful long-target filler before
    -- the complete Improved Slam raid rotation is available.
    if not ns.IsImprovedSlamReady()
        and ns.state.targetHPPercent >= 60
        and ns.state.targetTTD >= ns.CONFIG.SUNDER_MIN_TTD then
        return ns.state.sunderStacks < ns.CONFIG.SUNDER_LEVELING_MAX_STACK
    end
    return false
end

local function ShouldApplyLevelingRend()
    if ns.IsImprovedSlamReady() then return false end
    if not TargetAbilityAvailable("REND") then return false end
    if ns.state.rendExpiration > GetTime() then return false end
    if ns.state.targetHPPercent <= 35 then return false end
    return ns.state.targetTTD >= ns.CONFIG.REND_MIN_TTD
end

local function MortalStrikeShouldBeReserved()
    if not Knows("MORTAL_STRIKE") then return false end
    local remaining = ns.GetAbilityCooldownRemaining("MORTAL_STRIKE", true)
    if remaining > 2.0 then return false end
    return ns.state.rage < ns.GetAbilityCost("MORTAL_STRIKE")
        + ns.GetAbilityCost("WHIRLWIND")
end

local function CanUseSingleTargetWhirlwind()
    if not TargetAbilityAvailable("WHIRLWIND") then return false end
    return not MortalStrikeShouldBeReserved()
end

local function CoreAttackWouldBeStarvedBySlam(aoeActive)
    local slamCost = ns.GetAbilityCost("SLAM")
    local rage = ns.state.rage

    if aoeActive and TargetAbilityAvailable("WHIRLWIND")
        and rage >= ns.GetAbilityCost("WHIRLWIND")
        and rage < ns.GetAbilityCost("WHIRLWIND") + slamCost then
        return true
    end

    if TargetAbilityAvailable("MORTAL_STRIKE")
        and rage >= ns.GetAbilityCost("MORTAL_STRIKE")
        and rage < ns.GetAbilityCost("MORTAL_STRIKE") + slamCost then
        return true
    end
    return false
end

local function CanSlamNow(aoeActive, surplusOnly)
    if not ns.IsImprovedSlamReady() then return false end
    if not ns.IsSlamWindowOpen() then return false end
    if ns.state.moving then return false end
    if ns.GetGCDRemaining() > ns.CONFIG.SLAM_GCD_WAIT_TOLERANCE then return false end
    if not TargetAbilityAvailable("SLAM", ns.CONFIG.SLAM_GCD_WAIT_TOLERANCE) then return false end
    if CoreAttackWouldBeStarvedBySlam(aoeActive) then return false end

    if surplusOnly then
        local reserve = 0
        if aoeActive and Knows("WHIRLWIND") then
            reserve = ns.GetAbilityCost("WHIRLWIND")
        elseif Knows("MORTAL_STRIKE") then
            reserve = ns.GetAbilityCost("MORTAL_STRIKE")
        end
        return ns.state.rage >= ns.GetAbilityCost("SLAM") + reserve
    end
    return true
end

local function SweepingStrikesRequiredRage()
    local required = ns.GetAbilityCost("SWEEPING_STRIKES")

    if Knows("WHIRLWIND") then
        required = required + ns.GetAbilityCost("WHIRLWIND")
    elseif Knows("MORTAL_STRIKE") then
        required = required + ns.GetAbilityCost("MORTAL_STRIKE")
    end

    if Knows("CLEAVE") then
        required = required + ns.GetAbilityCost("CLEAVE")
    end
    return math.min(ns.state.maxRage or 100, required)
end

local function CanUseSweepingStrikes()
    if not Ready("SWEEPING_STRIKES") then return false end
    if ns.state.sweepingExpiration > GetTime() then return false end
    return ns.state.rage >= SweepingStrikesRequiredRage()
end

local function PrecombatDecision()
    if CanUseVictoryRush() then
        return Decision("VICTORY_RUSH", "Use the free attack before it expires")
    end

    local shout = ShouldRefreshShout()
    if shout and ns.state.rage >= ns.GetAbilityCost(shout) then
        return Decision(shout, "Maintain your assigned shout")
    end

    if ns.state.targetAttackable
        and not ns.state.inCombat
        and TargetAbilityAvailable("CHARGE") then
        return Decision("CHARGE", "Open the fight and generate Rage")
    end
    return nil
end

local function LevelingSingleTargetDecision()
    if CanUseVictoryRush() then
        return Decision("VICTORY_RUSH", "Free attack after a kill")
    end

    local shout = ShouldRefreshShout()
    if shout then
        return Decision(shout, "Maintain your assigned shout")
    end

    if CanUseOverpower() then
        return Decision("OVERPOWER", "Dodge window is open")
    end

    if TargetAbilityAvailable("MORTAL_STRIKE") then
        return Decision("MORTAL_STRIKE", "Primary attack")
    end

    if CanUseSingleTargetWhirlwind() then
        return Decision("WHIRLWIND", "Extra single-target damage")
    end

    if ns.state.targetHPPercent <= ns.CONFIG.EXECUTE_HP_PCT
        and TargetAbilityAvailable("EXECUTE") then
        return Decision("EXECUTE", "Finish the target")
    end

    if ShouldApplyLevelingRend() then
        return Decision("REND", "Target should live long enough for the bleed")
    end

    if ShouldMaintainSunder() then
        return Decision("SUNDER_ARMOR", "Long-lived target filler")
    end

    if CanUseBloodrage() then
        return Decision("BLOODRAGE", "Generate Rage")
    end

    return nil
end

local function EndgameSingleTargetDecision()
    if CanSlamNow(false, false) then
        return Decision("SLAM", "Main-hand swing landed - Slam now")
    end

    if CanUseVictoryRush() then
        return Decision("VICTORY_RUSH", "Use the free attack before it expires")
    end

    if TargetAbilityAvailable("MORTAL_STRIKE") then
        return Decision("MORTAL_STRIKE", "Primary attack")
    end

    if CanUseSingleTargetWhirlwind() then
        return Decision("WHIRLWIND", "Use without starving Mortal Strike")
    end

    -- Default two-handed Execute model: preserve Slam/MS/WW and
    -- use Execute only in an otherwise empty GCD.
    if ns.state.targetHPPercent <= ns.CONFIG.EXECUTE_HP_PCT
        and TargetAbilityAvailable("EXECUTE") then
        return Decision("EXECUTE", "Execute-phase filler")
    end

    if CanUseOverpower() then
        return Decision("OVERPOWER", "Filler dodge proc")
    end

    if ShouldMaintainSunder() then
        return Decision("SUNDER_ARMOR", "Maintain assigned armor reduction")
    end

    local shout = ShouldRefreshShout()
    if shout then
        return Decision(shout, "Refresh assigned shout in a filler GCD")
    end

    if CanUseBloodrage() then
        return Decision("BLOODRAGE", "Generate Rage")
    end

    return nil
end

local function AoeDecision(enemyCount)
    if CanUseVictoryRush() then
        return Decision("VICTORY_RUSH", "Free attack after a kill")
    end

    -- Before the endgame Slam profile exists, Battle Shout is a
    -- high-value first global for both solo packs and dungeons.
    if not ns.IsImprovedSlamReady() then
        local shout = ShouldRefreshShout()
        if shout then
            return Decision(shout, "Maintain your assigned shout")
        end
    end

    if CanUseSweepingStrikes() then
        return Decision(
            "SWEEPING_STRIKES",
            "Rage pooled for " .. enemyCount .. " targets"
        )
    end

    if TargetAbilityAvailable("WHIRLWIND") then
        return Decision("WHIRLWIND", "Highest-priority multi-target attack")
    end

    if TargetAbilityAvailable("MORTAL_STRIKE") then
        return Decision("MORTAL_STRIKE", "Primary-target attack")
    end

    if ns.state.targetHPPercent <= ns.CONFIG.EXECUTE_HP_PCT
        and TargetAbilityAvailable("EXECUTE") then
        return Decision("EXECUTE", "Finish the priority target")
    end

    -- In cleave, Slam is deliberately a surplus-Rage action. WW,
    -- Cleave, and MS must remain funded first.
    if CanSlamNow(true, true) then
        return Decision("SLAM", "Surplus Rage after a main-hand swing")
    end

    if CanUseOverpower() then
        return Decision("OVERPOWER", "Filler dodge proc")
    end

    if Ready("THUNDER_CLAP") and HasRage("THUNDER_CLAP") then
        return Decision("THUNDER_CLAP", "Multi-target damage and mitigation")
    end

    if ShouldMaintainSunder() then
        return Decision("SUNDER_ARMOR", "Long-lived primary target")
    end

    local shout = ShouldRefreshShout()
    if shout then
        return Decision(shout, "Refresh assigned shout")
    end

    if CanUseBloodrage() then
        return Decision("BLOODRAGE", "Generate Rage")
    end

    return nil
end

local function UpcomingCoreReserve(aoeActive)
    local swingHorizon = math.max(1.5, ns.GetSwingRemaining() + 1.5)

    if aoeActive then
        if Knows("WHIRLWIND")
            and ns.GetAbilityCooldownRemaining("WHIRLWIND", true) <= swingHorizon then
            return ns.GetAbilityCost("WHIRLWIND")
        end
        if Knows("MORTAL_STRIKE")
            and ns.GetAbilityCooldownRemaining("MORTAL_STRIKE", true) <= swingHorizon then
            return ns.GetAbilityCost("MORTAL_STRIKE")
        end
    else
        if Knows("MORTAL_STRIKE")
            and ns.GetAbilityCooldownRemaining("MORTAL_STRIKE", true) <= swingHorizon then
            return ns.GetAbilityCost("MORTAL_STRIKE")
        end
        if Knows("WHIRLWIND")
            and ns.GetAbilityCooldownRemaining("WHIRLWIND", true) <= swingHorizon then
            return ns.GetAbilityCost("WHIRLWIND")
        end
    end
    return 0
end

local function QueueDecision(aoeActive)
    if not ns.db.showQueue then return nil end
    if not ns.state.inCombat or not ns.state.targetAttackable then return nil end
    if ns.state.nextMainhandSwing <= GetTime() then return nil end

    -- Preserve Rage for Execute rather than consuming the next white
    -- swing and its Rage generation.
    if ns.state.targetHPPercent <= ns.CONFIG.EXECUTE_HP_PCT then return nil end

    local key = aoeActive and "CLEAVE" or "HEROIC_STRIKE"
    if not TargetAbilityAvailable(key) then return nil end

    if aoeActive and Ready("SWEEPING_STRIKES")
        and ns.state.sweepingExpiration <= GetTime()
        and ns.state.rage < SweepingStrikesRequiredRage() then
        return nil
    end

    local reserve = UpcomingCoreReserve(aoeActive) + ns.CONFIG.RAGE_RESERVE_BUFFER
    if ns.IsImprovedSlamReady() then
        reserve = reserve + ns.GetAbilityCost("SLAM")
    end

    local threshold = ns.GetAbilityCost(key) + reserve
    if aoeActive then
        threshold = math.max(60, threshold)
    else
        threshold = math.max(70, threshold)
    end
    threshold = math.min(ns.state.maxRage or 100, threshold)

    if ns.state.rage >= threshold then
        return {
            ability = key,
            reason = "Queue next swing at " .. threshold .. "+ Rage",
            threshold = threshold,
        }
    end
    return nil
end

function ns.Rotation_GetSnapshot()
    local aoeActive, enemyCount = GetTargetMode()
    local slamBuild = ns.IsImprovedSlamReady()
    local decision

    if not ns.state.inCombat then
        decision = PrecombatDecision()
    end

    if not decision and ns.state.targetAttackable then
        if aoeActive then
            decision = AoeDecision(math.max(2, enemyCount))
        elseif slamBuild then
            decision = EndgameSingleTargetDecision()
        else
            decision = LevelingSingleTargetDecision()
        end
    end

    local queue = QueueDecision(aoeActive)
    return {
        main = decision,
        queue = queue,
        aoeActive = aoeActive,
        enemyCount = enemyCount,
        slamBuild = slamBuild,
    }
end

-- Compatibility wrappers for older display/debug integrations.
function ns.Rotation_GetNextAbility()
    local snapshot = ns.Rotation_GetSnapshot()
    local main = snapshot.main
    if not main then return nil, "Wait for the next swing", nil end
    return main.ability, main.reason, main.stance
end

function ns.Rotation_GetQueueAbility()
    local snapshot = ns.Rotation_GetSnapshot()
    local queue = snapshot.queue
    if not queue then return nil end
    return queue.ability, queue.reason
end
