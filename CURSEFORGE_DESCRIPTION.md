# Arms Rotation Helper

Arms Rotation Helper is a lightweight, swing-aware PvE priority advisor for
**two-handed Arms Warriors** in World of Warcraft: The Burning Crusade
Anniversary.

It follows the classic Slam rhythm instead of treating the Warrior like a
normal cooldown-only class:

**Main-hand swing → Slam → Mortal Strike / Whirlwind / safe filler**

The addon only recommends actions. It never casts abilities, changes
equipment, targets enemies, or automates player input.

## Features

- Post-swing Slam timing with a live main-hand swing bar.
- Mortal Strike and single-target Whirlwind priority.
- Execute as filler below 20%, with no weapon-swap recommendation.
- Automatic single-target and multi-target profiles, plus manual overrides.
- Sweeping Strikes pooling and separate Cleave queue advice for AoE.
- Separate high-Rage Heroic Strike/Cleave indicator so queued attacks never
  hide the main global-cooldown recommendation.
- Rage protection for upcoming Slam, Mortal Strike, Whirlwind, and Sweeping
  Strikes sequences.
- Level-adaptive recommendations based on the abilities actually learned.
- Optional stance advice, assigned five-stack Sunder Armor, and talented
  Improved Demoralizing Shout maintenance.
- Battle Shout or Commanding Shout assignment.
- Action-button highlighting for Blizzard bars, Bartender4, and Dominos.
- Cooldown and trinket row.
- In-game settings under `Escape → Options → AddOns`, or `/arh`.
- Built-in 34-scenario priority self-test.
- Privacy-safe 60-second diagnostic report for useful bug reports.

## Single-target priority

The level-70 two-handed profile uses:

1. Maintain an assigned Sunder Armor if enabled.
2. Slam immediately after a main-hand swing.
3. Mortal Strike.
4. Whirlwind without starving an imminent Mortal Strike.
5. Execute below 20% only as an otherwise-safe filler.
6. Victory Rush, low-Rage Overpower, assigned debuffs, and shout refreshes as
   fillers that do not cover the next Slam window.

If movement prevents Slam, the addon falls back to Mortal Strike, Whirlwind,
and Execute.

## Multi-target priority

The two-handed AoE profile pools Rage for Sweeping Strikes and then favors:

1. Sweeping Strikes.
2. Whirlwind.
3. Mortal Strike.
4. Execute on the priority target.
5. Cleave through the separate next-swing queue indicator.
6. Slam only with surplus Rage.

Automatic enemy counting uses recent combat-log interactions. If it cannot see
an unengaged nearby enemy, force the profile with `/arh mode aoe`.

## Commands and testing

- `/arh` — open settings.
- `/arh sim check` — run all 34 deterministic priority checks.
- `/arh mode auto|single|aoe` — select target-count behavior.
- `/arh record` — record up to 60 seconds of anonymous decision data.
- `/arh report` — open the selected, copyable diagnostic report.

If a recommendation looks wrong, please include the complete `/arh report`
text in a CurseForge comment. It contains no account, character, realm, or
target names; no chat, GUIDs, or item links.

## Scope

This beta supports **two-handed Arms PvE**. Dual-wield Arms, tanking, and PvP
priorities are intentionally outside its scope.

The rotation is based on the current Wowhead TBC Warrior DPS guide and
cross-checked against the open-source WoWSims TBC Warrior model. Player
feedback from level-70 raids and heroic dungeons will drive the next updates.
