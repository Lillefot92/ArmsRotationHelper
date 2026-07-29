-- ============================================================
-- Arms Rotation Helper - Simulator.lua
-- Deterministic, non-combat scenarios for exercising the real
-- rotation evaluator without touching the player's live state.
-- ============================================================

local ADDON_NAME, ns = ...

local STEP_DURATION = 3.5

local LEVELING_KNOWN = {
    "HEROIC_STRIKE",
    "BATTLE_SHOUT",
    "CHARGE",
    "REND",
    "THUNDER_CLAP",
}

local ENDGAME_KNOWN = {
    "HEROIC_STRIKE",
    "BATTLE_SHOUT",
    "CHARGE",
    "REND",
    "THUNDER_CLAP",
    "SUNDER_ARMOR",
    "BLOODRAGE",
    "OVERPOWER",
    "CLEAVE",
    "EXECUTE",
    "SLAM",
    "WHIRLWIND",
    "MORTAL_STRIKE",
    "VICTORY_RUSH",
    "COMMANDING_SHOUT",
    "SWEEPING_STRIKES",
}

local SCENARIO_ORDER = {
    "leveling",
    "slam",
    "rage",
    "execute",
    "overpower",
    "aoe",
    "cleave",
}

local SCENARIO_LABELS = {
    leveling = "Leveling",
    slam = "Slam rhythm",
    rage = "Rage protection",
    execute = "Execute phase",
    overpower = "Overpower stance",
    aoe = "AoE priority",
    cleave = "Cleave and pooling",
    all = "Complete suite",
}

local scenarios = {
    leveling = {
        {
            label = "Refresh Battle Shout first",
            known = LEVELING_KNOWN,
            improvedSlam = false,
            state = {
                rage = 20,
                battleShoutExpiration = 0,
                rendExpiration = 0,
            },
            cooldowns = { BATTLE_SHOUT = 0, REND = 0 },
            expectedMain = "BATTLE_SHOUT",
        },
        {
            label = "Apply Rend to a durable target",
            known = LEVELING_KNOWN,
            improvedSlam = false,
            state = {
                rage = 30,
                targetTTD = 20,
                rendExpiration = 0,
            },
            cooldowns = { REND = 0 },
            expectedMain = "REND",
        },
        {
            label = "Queue Heroic Strike only at high Rage",
            known = LEVELING_KNOWN,
            improvedSlam = false,
            state = { rage = 80, targetTTD = 6 },
            cooldowns = { HEROIC_STRIKE = 0 },
            expectedQueue = "HEROIC_STRIKE",
        },
    },
    slam = {
        {
            label = "White swing landed: Slam immediately",
            state = { rage = 45 },
            cooldowns = { SLAM = 0, MORTAL_STRIKE = 0 },
            slamWindowOpen = true,
            swingProgress = 0.99,
            expectedMain = "SLAM",
        },
        {
            label = "Outside the Slam window: Mortal Strike",
            state = { rage = 60 },
            cooldowns = { MORTAL_STRIKE = 0 },
            expectedMain = "MORTAL_STRIKE",
        },
        {
            label = "Mortal Strike unavailable: Whirlwind",
            state = { rage = 60 },
            cooldowns = { MORTAL_STRIKE = 4, WHIRLWIND = 0 },
            expectedMain = "WHIRLWIND",
        },
    },
    rage = {
        {
            label = "Protect ready Mortal Strike from Slam",
            state = { rage = 40 },
            cooldowns = { SLAM = 0, MORTAL_STRIKE = 0 },
            slamWindowOpen = true,
            swingProgress = 0.99,
            expectedMain = "MORTAL_STRIKE",
        },
        {
            label = "Slam once Rage also funds Mortal Strike",
            state = { rage = 45 },
            cooldowns = { SLAM = 0, MORTAL_STRIKE = 0 },
            slamWindowOpen = true,
            swingProgress = 0.99,
            expectedMain = "SLAM",
        },
        {
            label = "Hold Whirlwind for imminent Mortal Strike",
            state = { rage = 40 },
            cooldowns = { MORTAL_STRIKE = 1.5, WHIRLWIND = 0 },
        },
    },
    execute = {
        {
            label = "Execute phase still keeps post-swing Slam",
            state = { rage = 60, targetHPPercent = 15 },
            cooldowns = {
                SLAM = 0,
                MORTAL_STRIKE = 0,
                WHIRLWIND = 0,
                EXECUTE = 0,
            },
            slamWindowOpen = true,
            swingProgress = 0.99,
            expectedMain = "SLAM",
        },
        {
            label = "Execute phase keeps ready Mortal Strike",
            state = { rage = 60, targetHPPercent = 15 },
            cooldowns = {
                MORTAL_STRIKE = 0,
                WHIRLWIND = 0,
                EXECUTE = 0,
            },
            expectedMain = "MORTAL_STRIKE",
        },
        {
            label = "Execute phase keeps safe Whirlwind",
            state = { rage = 60, targetHPPercent = 15 },
            cooldowns = {
                MORTAL_STRIKE = 5,
                WHIRLWIND = 0,
                EXECUTE = 0,
            },
            expectedMain = "WHIRLWIND",
        },
        {
            label = "Execute fills an otherwise empty global",
            state = { rage = 35, targetHPPercent = 15 },
            cooldowns = {
                MORTAL_STRIKE = 5,
                WHIRLWIND = 5,
                EXECUTE = 0,
            },
            expectedMain = "EXECUTE",
        },
    },
    overpower = {
        {
            label = "Matching dodge proc recommends Battle Stance",
            state = {
                rage = 30,
                stance = ns.STANCE.BERSERKER,
                overpowerWindow = "matching",
            },
            cooldowns = {
                MORTAL_STRIKE = 5,
                WHIRLWIND = 5,
                OVERPOWER = 0,
            },
            expectedMain = "OVERPOWER",
            expectedStance = ns.STANCE.BATTLE,
        },
        {
            label = "Dodge proc from another target is ignored",
            state = {
                rage = 30,
                stance = ns.STANCE.BERSERKER,
                overpowerWindow = "other",
            },
            cooldowns = {
                MORTAL_STRIKE = 5,
                WHIRLWIND = 5,
                OVERPOWER = 0,
            },
        },
    },
    aoe = {
        {
            label = "Two targets: pooled Sweeping Strikes",
            state = { rage = 80, enemyCount = 2 },
            cooldowns = {
                SWEEPING_STRIKES = 0,
                WHIRLWIND = 0,
                MORTAL_STRIKE = 0,
            },
            expectedMain = "SWEEPING_STRIKES",
        },
        {
            label = "Three targets: Whirlwind under Sweeping Strikes",
            state = { rage = 50, enemyCount = 3, sweepingActive = true },
            cooldowns = { WHIRLWIND = 0 },
            expectedMain = "WHIRLWIND",
        },
        {
            label = "Four targets: Mortal Strike after Whirlwind",
            state = { rage = 50, enemyCount = 4, sweepingActive = true },
            cooldowns = { WHIRLWIND = 5, MORTAL_STRIKE = 0 },
            expectedMain = "MORTAL_STRIKE",
        },
        {
            label = "Four targets: Execute the priority target",
            state = {
                rage = 35,
                enemyCount = 4,
                targetHPPercent = 15,
                sweepingActive = true,
            },
            cooldowns = {
                WHIRLWIND = 5,
                MORTAL_STRIKE = 5,
                EXECUTE = 0,
            },
            expectedMain = "EXECUTE",
        },
        {
            label = "Four targets: Slam only with surplus Rage",
            state = { rage = 65, enemyCount = 4, sweepingActive = true },
            cooldowns = {
                WHIRLWIND = 5,
                MORTAL_STRIKE = 5,
                SLAM = 0,
            },
            slamWindowOpen = true,
            swingProgress = 0.99,
            expectedMain = "SLAM",
        },
    },
    cleave = {
        {
            label = "Pool Rage: suppress Cleave before Sweeping Strikes",
            state = { rage = 70, enemyCount = 3 },
            cooldowns = {
                SWEEPING_STRIKES = 0,
                WHIRLWIND = 5,
                MORTAL_STRIKE = 5,
                CLEAVE = 0,
            },
        },
        {
            label = "High Rage: Whirlwind plus queued Cleave",
            state = { rage = 100, enemyCount = 3, sweepingActive = true },
            cooldowns = {
                SWEEPING_STRIKES = 0,
                WHIRLWIND = 0,
                CLEAVE = 0,
            },
            expectedMain = "WHIRLWIND",
            expectedQueue = "CLEAVE",
        },
        {
            label = "Hold Cleave below the protected threshold",
            state = { rage = 60, enemyCount = 3, sweepingActive = true },
            cooldowns = {
                SWEEPING_STRIKES = 0,
                WHIRLWIND = 0,
                CLEAVE = 0,
            },
            expectedMain = "WHIRLWIND",
        },
    },
}

local runtime = {
    active = false,
    name = nil,
    stepIndex = 1,
    stepStartedAt = 0,
}

local function CopyTable(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
end

local function KnownSet(list)
    local result = {}
    for _, key in ipairs(list or ENDGAME_KNOWN) do result[key] = true end
    return result
end

local function BuildContext(step)
    local now = GetTime()
    local known = KnownSet(step.known)
    local cooldowns = {}
    local inRange = {}
    local costs = {}

    for key in pairs(known) do
        cooldowns[key] = 99
        if ns.ABILITIES[key] and ns.ABILITIES[key].target then
            inRange[key] = true
        end
        costs[key] = ns.CONFIG.COSTS[key] or 0
    end
    for key, value in pairs(step.cooldowns or {}) do cooldowns[key] = value end

    local state = {
        rage = 50,
        maxRage = 100,
        inCombat = true,
        moving = false,
        stance = step.known == LEVELING_KNOWN
            and ns.STANCE.BATTLE or ns.STANCE.BERSERKER,

        targetExists = true,
        targetAttackable = true,
        targetGUID = "ARH_SIM_TARGET",
        targetHPPercent = 80,
        targetHealth = 80000,
        targetHealthMax = 100000,
        targetTTD = 60,

        rendExpiration = now + 12,
        sunderExpiration = now + 20,
        sunderStacks = 5,
        battleShoutExpiration = now + 120,
        commandingExpiration = now + 120,
        sweepingExpiration = 0,

        overpowerWindowEnd = 0,
        overpowerTargetGUID = nil,

        mainhandSpeed = 3.6,
        lastMainhandSwing = now - 1.0,
        nextMainhandSwing = now + 2.6,
        slamWindowStart = 0,
        slamWindowEnd = 0,
        swingTargetGUID = "ARH_SIM_TARGET",
        lastSwingWasReplacement = false,
        ignoredExtraAttacks = 0,

        enemyCount = 1,
    }

    local stateOverrides = CopyTable(step.state)
    local overpowerWindow = stateOverrides.overpowerWindow
    local sweepingActive = stateOverrides.sweepingActive
    stateOverrides.overpowerWindow = nil
    stateOverrides.sweepingActive = nil
    for key, value in pairs(stateOverrides) do state[key] = value end

    if overpowerWindow then
        state.overpowerWindowEnd = now + 4
        state.overpowerTargetGUID = overpowerWindow == "matching"
            and state.targetGUID or "ARH_SIM_OTHER_TARGET"
    end
    if sweepingActive then state.sweepingExpiration = now + 8 end

    local swingRemaining = step.swingRemaining or 2.6
    state.nextMainhandSwing = now + swingRemaining

    return {
        now = now,
        state = state,
        db = {
            mode = step.mode or "auto",
            assignedShout = "battle",
            maintainSunder = false,
            showQueue = true,
            stanceAdvice = true,
        },
        known = known,
        costs = costs,
        cooldowns = cooldowns,
        inRange = inRange,
        usable = { VICTORY_RUSH = false },
        insufficientPower = { VICTORY_RUSH = false },
        gcdRemaining = step.gcdRemaining or 0,
        swingRemaining = swingRemaining,
        improvedSlam = step.improvedSlam ~= false,
        slamWindowOpen = step.slamWindowOpen == true,
    }
end

local function GetScenarioSteps(name)
    if name ~= "all" then return scenarios[name] end

    local result = {}
    for _, scenarioName in ipairs(SCENARIO_ORDER) do
        for _, step in ipairs(scenarios[scenarioName]) do
            table.insert(result, step)
        end
    end
    return result
end

for scenarioName, steps in pairs(scenarios) do
    for index, step in ipairs(steps) do
        step.scenarioName = scenarioName
        step.scenarioIndex = index
        step.scenarioTotal = #steps
    end
end

local function ActualAbility(decision)
    return decision and decision.ability or nil
end

local function StepPassed(step, snapshot)
    local actualMain = ActualAbility(snapshot.main)
    local actualQueue = ActualAbility(snapshot.queue)
    local actualStance = snapshot.main and snapshot.main.stance or nil
    return actualMain == step.expectedMain
        and actualQueue == step.expectedQueue
        and actualStance == step.expectedStance
end

local function DescribeResult(step, snapshot)
    local expectedMain = step.expectedMain or "WAIT"
    local actualMain = ActualAbility(snapshot.main) or "WAIT"
    local expectedQueue = step.expectedQueue or "NONE"
    local actualQueue = ActualAbility(snapshot.queue) or "NONE"
    local expectedStance = step.expectedStance or 0
    local actualStance = snapshot.main and snapshot.main.stance or 0
    return string.format(
        "%s: main %s/%s, queue %s/%s, stance %d/%d",
        step.label,
        actualMain,
        expectedMain,
        actualQueue,
        expectedQueue,
        actualStance,
        expectedStance
    )
end

function ns.Simulator_GetScenarioNames()
    local result = {}
    for _, name in ipairs(SCENARIO_ORDER) do table.insert(result, name) end
    return result
end

function ns.Simulator_GetScenarioLabel(name)
    return SCENARIO_LABELS[name] or name
end

function ns.Simulator_IsActive()
    return runtime.active
end

function ns.Simulator_Start(name)
    name = name or "all"
    if name ~= "all" and not scenarios[name] then
        return false, "Unknown scenario '" .. tostring(name) .. "'."
    end

    runtime.active = true
    runtime.name = name
    runtime.stepIndex = 1
    runtime.stepStartedAt = GetTime()
    if ns.db and ns.db.testMode and ns.Display_SetTestMode then
        ns.Display_SetTestMode(false)
    end
    return true
end

function ns.Simulator_Stop()
    local wasActive = runtime.active
    runtime.active = false
    runtime.name = nil
    runtime.stepIndex = 1
    runtime.stepStartedAt = 0
    return wasActive
end

function ns.Simulator_Next()
    if not runtime.active then return false end
    local steps = GetScenarioSteps(runtime.name)
    runtime.stepIndex = runtime.stepIndex % #steps + 1
    runtime.stepStartedAt = GetTime()
    return true
end

function ns.Simulator_GetStatus()
    if not runtime.active then return nil end
    local steps = GetScenarioSteps(runtime.name)
    local step = steps[runtime.stepIndex]
    return {
        name = runtime.name,
        label = SCENARIO_LABELS[runtime.name],
        stepIndex = runtime.stepIndex,
        stepTotal = #steps,
        stepLabel = step and step.label,
    }
end

function ns.Simulator_GetSnapshot()
    if not runtime.active then return nil end

    local steps = GetScenarioSteps(runtime.name)
    local now = GetTime()
    local elapsed = now - runtime.stepStartedAt
    if elapsed >= STEP_DURATION then
        local advances = math.floor(elapsed / STEP_DURATION)
        runtime.stepIndex = (runtime.stepIndex - 1 + advances) % #steps + 1
        runtime.stepStartedAt = runtime.stepStartedAt + advances * STEP_DURATION
        elapsed = now - runtime.stepStartedAt
    end

    local step = steps[runtime.stepIndex]
    local context = BuildContext(step)
    local snapshot = ns.Rotation_GetSnapshot(context)
    local passed = StepPassed(step, snapshot)

    snapshot.swingProgressOverride = step.swingProgress or 0.35
    snapshot.simulation = {
        activeName = runtime.name,
        scenarioName = step.scenarioName,
        scenarioLabel = SCENARIO_LABELS[step.scenarioName],
        stepIndex = step.scenarioIndex,
        stepTotal = step.scenarioTotal,
        suiteIndex = runtime.stepIndex,
        suiteTotal = #steps,
        stepLabel = step.label,
        expectedMain = step.expectedMain,
        expectedQueue = step.expectedQueue,
        expectedStance = step.expectedStance,
        passed = passed,
        detail = DescribeResult(step, snapshot),
        state = context.state,
        swingRemaining = context.swingRemaining,
        slamWindowOpen = context.slamWindowOpen,
        gcdRemaining = context.gcdRemaining,
        stepProgress = math.min(1, elapsed / STEP_DURATION),
    }
    return snapshot
end

function ns.Simulator_RunSelfCheck()
    local passed = 0
    local total = 0
    local failures = {}

    for _, scenarioName in ipairs(SCENARIO_ORDER) do
        for _, step in ipairs(scenarios[scenarioName]) do
            total = total + 1
            local snapshot = ns.Rotation_GetSnapshot(BuildContext(step))
            if StepPassed(step, snapshot) then
                passed = passed + 1
            else
                table.insert(failures, DescribeResult(step, snapshot))
            end
        end
    end
    return passed, total, failures
end
