# Arms Rotation Helper

Arms Rotation Helper is a swing-aware PvE rotation advisor for two-handed Arms
Warriors in World of Warcraft: The Burning Crusade Anniversary.

This beta adapts to the abilities the current character actually knows, so it
can be tested while leveling and naturally grows into the level-70 Slam
rotation. It only recommends actions; it never casts spells or automates input.

## What it shows

- A primary ability recommendation.
- A main-hand swing bar and short post-swing Slam window.
- A separate Heroic Strike or Cleave next-swing queue suggestion.
- Optional stance advice.
- Action-bar highlighting for Blizzard bars, Bartender4, and Dominos.
- A small cooldown row for Death Wish, Recklessness, and equipped trinkets.
- Automatic single-target/AoE selection, with manual overrides.
- A deterministic rotation simulator for validating priorities without a
  level-70 character or live combat.
- An in-game settings panel for rotation, display, positioning, preview, and
  simulator controls.

## Rotation model

The level-70 single-target model is built around the established two-handed
Arms rhythm:

1. Slam immediately after a main-hand swing when it will not starve a ready
   core attack.
2. Mortal Strike.
3. Whirlwind, while preserving the next Mortal Strike.
4. Execute as filler below 20% when the core actions are unavailable.
5. Overpower, assigned Improved Demoralizing Shout, assigned Sunder Armor,
   shout refresh, and Bloodrage as situational filler.

The AoE model pools enough Rage for Sweeping Strikes before recommending it,
then favors Whirlwind, Mortal Strike, Execute on the priority target, and
Cleave. Slam is only recommended with surplus Rage in multi-target combat.

Heroic Strike and Cleave are deliberately kept out of the main icon. Their
separate queue icon appears only at high Rage and protects Rage for an upcoming
Slam, Mortal Strike, Whirlwind, or Sweeping Strikes sequence.

No weapon-swap Execute model is included.

Before a fully improved Slam is known, the addon uses a leveling priority:
assigned shout, Victory Rush, Overpower, Mortal Strike/Whirlwind when learned,
Execute, worthwhile Rend, optional Sunder assignment, and Bloodrage. At very
low levels, quiet time between recommendations is expected: keep auto-attacking
and avoid spending Rage on Heroic Strike unless its queue icon appears.

Improved Demoralizing Shout maintenance is opt-in and is available only when
the character has at least one point in that talent. It remains a filler
assignment and never replaces Slam, Mortal Strike, Whirlwind, or Execute.

## Commands

Use `/arh` or `/armshelper` to open the settings panel. Every setting remains
available as a slash command for quick access.

- `/arh` or `/arh config` - open or close the settings panel.
- `/arh help` - print the complete command list.
- `/arh unlock` and `/arh lock` - move or lock the complete display.
- `/arh scale 1.2` - set the display scale from 0.3 to 3.
- `/arh mode auto|single|aoe` - choose target-count behavior.
- `/arh shout battle|commanding` - select the assigned shout.
- `/arh stance` - toggle optional stance advice.
- `/arh swing` - toggle the main-hand swing bar.
- `/arh queue` - toggle Heroic Strike/Cleave queue advice.
- `/arh sunder` - toggle the five-stack Sunder Armor assignment.
- `/arh demo` - toggle talented Demoralizing Shout maintenance.
- `/arh icon`, `/arh glow`, `/arh cooldowns` - toggle display parts.
- `/arh test` - preview the high-level display.
- `/arh sim` - run the complete rotation simulator.
- `/arh sim leveling|slam|rage|execute|overpower|demoralizing|aoe|cleave` - run one
  scenario group.
- `/arh sim next|stop|check|list` - control the simulator or run all automated
  priority checks.
- `/arh debug` - show live state and decision information.
- `/arh debug spells` - print localized spellbook entries.
- `/arh reset` - reset display position and scale.

## Settings panel

The panel is available directly through `/arh` and is also linked from
`Escape > Options > AddOns > Arms Rotation Helper`. Older clients use the
legacy Interface Options fallback.

Changes apply immediately. The panel includes target mode, assigned shout,
stance, Sunder, and talented Demoralizing Shout options, all display toggles,
scale and locking controls, display preview, named simulator scenarios, manual
simulator steps, and the complete 26-check rotation test.

## Installation

1. Exit World of Warcraft.
2. Back up any existing `ArmsRotationHelper` folder.
3. Extract the archive into:
   `World of Warcraft/_anniversary_/Interface/AddOns`
4. Confirm that the final path contains
   `ArmsRotationHelper/ArmsRotationHelper.toc`.
5. Start the game, enable the addon, then enter `/arh`.
6. Enter `/arh sim check`; the development build should report every scenario
   as passed.

See `TESTING.md` for the beta checklist and useful bug-report details.

## Rotation simulator

The simulator uses the same priority evaluator as live combat, but supplies
isolated test data for Rage, target health, enemy count, cooldowns, stance, and
the post-swing Slam window. It never replaces or writes to the player's combat
state.

`/arh sim` cycles through the full suite in 3.5-second steps. A blue
`SIMULATION` banner and automatic diagnostic panel remain visible for the
complete run. Action-bar glow and the live cooldown row are suppressed during
simulation so test recommendations cannot be mistaken for live prompts.

Use `/arh sim stop` to return immediately to live recommendations.

## Design references

The default priority is based on the current Wowhead TBC Arms Warrior PvE
rotation guide and cross-checked against the open-source WoWSims TBC Warrior
rotation model:

- https://www.wowhead.com/tbc/guide/classes/warrior/dps-rotation-cooldowns-abilities-pve
- https://github.com/wowsims/tbc/blob/v1.9.3/sim/warrior/dps/rotation.go

## Beta limitations

- Automatic enemy counting is inferred from recent combat-log interactions. It
  cannot know every nearby unengaged enemy; use `/arh mode aoe` when needed.
- The addon does not predict future Rage from incoming damage.
- A player must validate the level-70 sequence in real dungeons and raids before
  the project should be called release-ready.
- A public license and final CurseForge author/project metadata still need to be
  selected before publication.
