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

-- Rotation evaluation normally reads the live game APIs. The simulator
-- supplies an isolated context so the exact same priority functions can be
-- exercised without replacing or mutating ns.state.
local evaluationContext

local function State()
    return (evaluationContext and evaluationContext.state) or ns.state
end

local function Settings()
    return (evaluationContext and evaluationContext.db) or ns.db
end

local function Now()
    return (evaluationContext and evaluationContext.now) or GetTime()
end

local function AbilityCost(key)
    if evaluationContext and evaluationContext.costs
        and evaluationContext.costs[key] ~= nil then
        return evaluationContext.costs[key]
    end
    return ns.GetAbilityCost(key)
end

local function CooldownRemaining(key)
    if evaluationContext and evaluationContext.cooldowns
        and evaluationContext.cooldowns[key] ~= nil then
        return evaluationContext.cooldowns[key]
    end
    return ns.GetAbilityCooldownRemaining(key, true)
end

local function GCDRemaining()
    if evaluationContext and evaluationContext.gcdRemaining ~= nil then
        return evaluationContext.gcdRemaining
    end
    return ns.GetGCDRemaining()
end

local function SwingRemaining()
    if evaluationContext and evaluationContext.swingRemaining ~= nil then
        return evaluationContext.swingRemaining
    end
    return ns.GetSwingRemaining()
end

local function ImprovedSlamReady()
    if evaluationContext and evaluationContext.improvedSlam ~= nil then
        return evaluationContext.improvedSlam
    end
    return ns.IsImprovedSlamReady()
end

local function SlamWindowOpen()
    if evaluationContext and evaluationContext.slamWindowOpen ~= nil then
        return evaluationContext.slamWindowOpen
    end
    return ns.IsSlamWindowOpen()
end

local function PreferredStance(key)
    return ns.GetPreferredStanceForAbility(key, State().stance)
end

local function Decision(key, reason)
    if not key then return nil end
    local preferredStance
    if Settings().stanceAdvice then
        preferredStance = PreferredStance(key)
    end
    return {
        ability = key,
        reason = reason or "",
        stance = preferredStance,
    }
end

local function Knows(key)
    if evaluationContext and evaluationContext.known then
        return evaluationContext.known[key] == true
    end
    return ns.PlayerKnowsAbility(key)
end

local function HasRage(key, extra)
    return State().rage >= AbilityCost(key) + (extra or 0)
end

local function Ready(key, tolerance)
    return Knows(key)
        and CooldownRemaining(key) <= (tolerance or 0.15)
end

local function TargetAbilityAvailable(key, tolerance)
    if not State().targetAttackable then return false end
    if not Ready(key, tolerance) then return false end
    if not HasRage(key) then return false end
    if evaluationContext and evaluationContext.inRange
        and evaluationContext.inRange[key] ~= nil then
        return evaluationContext.inRange[key]
    end
    return ns.IsAbilityInRange(key, "target")
end

local function GetAssignedShout()
    if Settings().assignedShout == "commanding" and Knows("COMMANDING_SHOUT") then
        return "COMMANDING_SHOUT", State().commandingExpiration
    end
    return "BATTLE_SHOUT", State().battleShoutExpiration
end

local function ShouldRefreshShout()
    local key, expiration = GetAssignedShout()
    if not Knows(key) or not HasRage(key) then return nil end
    local remaining = (expiration or 0) - Now()
    if expiration == 0 or remaining <= ns.CONFIG.SHOUT_REFRESH_AT then
        return key
    end
    return nil
end

local function GetTargetMode()
    local count = State().enemyCount or 0
    if Settings().mode == "single" then
        return false, math.max(1, count)
    elseif Settings().mode == "aoe" then
        return true, math.max(ns.CONFIG.AOE_ENEMY_THRESHOLD, count)
    end
    return count >= ns.CONFIG.AOE_ENEMY_THRESHOLD, count
end

local function CanUseVictoryRush()
    if not TargetAbilityAvailable("VICTORY_RUSH") then return false end
    local usable, insufficientPower
    if evaluationContext and evaluationContext.usable
        and evaluationContext.usable.VICTORY_RUSH ~= nil then
        usable = evaluationContext.usable.VICTORY_RUSH
        insufficientPower = evaluationContext.insufficientPower
            and evaluationContext.insufficientPower.VICTORY_RUSH == true
    else
        usable, insufficientPower = ns.IsAbilityUsable("VICTORY_RUSH")
    end
    return usable and not insufficientPower
end

local function CanUseOverpower()
    local s = State()
    if s.targetHPPercent <= ns.CONFIG.EXECUTE_HP_PCT then return false end
    if s.overpowerWindowEnd <= Now() then return false end
    if not s.overpowerTargetGUID or s.overpowerTargetGUID ~= s.targetGUID then return false end
    return TargetAbilityAvailable("OVERPOWER")
end

-- Bloodrage is intentionally kept simple: it is a low-Rage recovery
-- suggestion, never allowed to replace a ready core attack.
local function CanUseBloodrage()
    return State().inCombat
        and State().rage < 10
        and Ready("BLOODRAGE")
end

local function ShouldMaintainSunder()
    if not TargetAbilityAvailable("SUNDER_ARMOR") then return false end
    if State().targetTTD < 8 then return false end

    if Settings().maintainSunder then
        local remaining = State().sunderExpiration - Now()
        return State().sunderStacks < 5 or remaining <= 3
    end

    -- While leveling, Sunder is a useful long-target filler before
    -- the complete Improved Slam raid rotation is available.
    if not ImprovedSlamReady()
        and State().targetHPPercent >= 60
        and State().targetTTD >= ns.CONFIG.SUNDER_MIN_TTD then
        return State().sunderStacks < ns.CONFIG.SUNDER_LEVELING_MAX_STACK
    end
    return false
end

local function ShouldApplyLevelingRend()
    if ImprovedSlamReady() then return false end
    if not TargetAbilityAvailable("REND") then return false end
    if State().rendExpiration > Now() then return false end
    if State().targetHPPercent <= 35 then return false end
    return State().targetTTD >= ns.CONFIG.REND_MIN_TTD
end

local function MortalStrikeShouldBeReserved()
    if not Knows("MORTAL_STRIKE") then return false end
    local remaining = CooldownRemaining("MORTAL_STRIKE")
    if remaining > 2.0 then return false end
    return State().rage < AbilityCost("MORTAL_STRIKE")
        + AbilityCost("WHIRLWIND")
end

local function CanUseSingleTargetWhirlwind()
    if not TargetAbilityAvailable("WHIRLWIND") then return false end
    return not MortalStrikeShouldBeReserved()
end

local function CoreAttackWouldBeStarvedBySlam(aoeActive)
    local slamCost = AbilityCost("SLAM")
    local rage = State().rage

    if aoeActive and TargetAbilityAvailable("WHIRLWIND")
        and rage >= AbilityCost("WHIRLWIND")
        and rage < AbilityCost("WHIRLWIND") + slamCost then
        return true
    end

    if TargetAbilityAvailable("MORTAL_STRIKE")
        and rage >= AbilityCost("MORTAL_STRIKE")
        and rage < AbilityCost("MORTAL_STRIKE") + slamCost then
        return true
    end
    return false
end

local function CanSlamNow(aoeActive, surplusOnly)
    if not ImprovedSlamReady() then return false end
    if not SlamWindowOpen() then return false end
    if State().moving then return false end
    if GCDRemaining() > ns.CONFIG.SLAM_GCD_WAIT_TOLERANCE then return false end
    if not TargetAbilityAvailable("SLAM", ns.CONFIG.SLAM_GCD_WAIT_TOLERANCE) then return false end
    if CoreAttackWouldBeStarvedBySlam(aoeActive) then return false end

    if surplusOnly then
        local reserve = 0
        if aoeActive and Knows("WHIRLWIND") then
            reserve = AbilityCost("WHIRLWIND")
        elseif Knows("MORTAL_STRIKE") then
            reserve = AbilityCost("MORTAL_STRIKE")
        end
        return State().rage >= AbilityCost("SLAM") + reserve
    end
    return true
end

local function SweepingStrikesRequiredRage()
    local required = AbilityCost("SWEEPING_STRIKES")

    if Knows("WHIRLWIND") then
        required = required + AbilityCost("WHIRLWIND")
    elseif Knows("MORTAL_STRIKE") then
        required = required + AbilityCost("MORTAL_STRIKE")
    end

    if Knows("CLEAVE") then
        required = required + AbilityCost("CLEAVE")
    end
    return math.min(State().maxRage or 100, required)
end

local function CanUseSweepingStrikes()
    if not Ready("SWEEPING_STRIKES") then return false end
    if State().sweepingExpiration > Now() then return false end
    return State().rage >= SweepingStrikesRequiredRage()
end

local function PrecombatDecision()
    if CanUseVictoryRush() then
        return Decision("VICTORY_RUSH", "Use the free attack before it expires")
    end

    local shout = ShouldRefreshShout()
    if shout and State().rage >= AbilityCost(shout) then
        return Decision(shout, "Maintain your assigned shout")
    end

    if State().targetAttackable
        and not State().inCombat
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

    if State().targetHPPercent <= ns.CONFIG.EXECUTE_HP_PCT
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
    if State().targetHPPercent <= ns.CONFIG.EXECUTE_HP_PCT
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
    if not ImprovedSlamReady() then
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

    if State().targetHPPercent <= ns.CONFIG.EXECUTE_HP_PCT
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
    local swingHorizon = math.max(1.5, SwingRemaining() + 1.5)

    if aoeActive then
        if Knows("WHIRLWIND")
            and CooldownRemaining("WHIRLWIND") <= swingHorizon then
            return AbilityCost("WHIRLWIND")
        end
        if Knows("MORTAL_STRIKE")
            and CooldownRemaining("MORTAL_STRIKE") <= swingHorizon then
            return AbilityCost("MORTAL_STRIKE")
        end
    else
        if Knows("MORTAL_STRIKE")
            and CooldownRemaining("MORTAL_STRIKE") <= swingHorizon then
            return AbilityCost("MORTAL_STRIKE")
        end
        if Knows("WHIRLWIND")
            and CooldownRemaining("WHIRLWIND") <= swingHorizon then
            return AbilityCost("WHIRLWIND")
        end
    end
    return 0
end

local function QueueDecision(aoeActive)
    if not Settings().showQueue then return nil end
    if not State().inCombat or not State().targetAttackable then return nil end
    if State().nextMainhandSwing <= Now() then return nil end

    -- Preserve Rage for Execute rather than consuming the next white
    -- swing and its Rage generation.
    if State().targetHPPercent <= ns.CONFIG.EXECUTE_HP_PCT then return nil end

    local key = aoeActive and "CLEAVE" or "HEROIC_STRIKE"
    if not TargetAbilityAvailable(key) then return nil end

    if aoeActive and Ready("SWEEPING_STRIKES")
        and State().sweepingExpiration <= Now()
        and State().rage < SweepingStrikesRequiredRage() then
        return nil
    end

    local reserve = UpcomingCoreReserve(aoeActive) + ns.CONFIG.RAGE_RESERVE_BUFFER
    if ImprovedSlamReady() then
        reserve = reserve + AbilityCost("SLAM")
    end

    local threshold = AbilityCost(key) + reserve
    if aoeActive then
        threshold = math.max(60, threshold)
    else
        threshold = math.max(70, threshold)
    end
    threshold = math.min(State().maxRage or 100, threshold)

    if State().rage >= threshold then
        return {
            ability = key,
            reason = "Queue next swing at " .. threshold .. "+ Rage",
            threshold = threshold,
        }
    end
    return nil
end

local function EvaluateSnapshot()
    local aoeActive, enemyCount = GetTargetMode()
    local slamBuild = ImprovedSlamReady()
    local decision

    if not State().inCombat then
        decision = PrecombatDecision()
    end

    if not decision and State().targetAttackable then
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

function ns.Rotation_GetSnapshot(context)
    local previousContext = evaluationContext
    evaluationContext = context
    local ok, result = pcall(EvaluateSnapshot)
    evaluationContext = previousContext

    if not ok then error(result, 0) end
    return result
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
