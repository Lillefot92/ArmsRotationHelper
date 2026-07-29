# Changelog

## 1.6.0-beta.3 (development)

### Rotation simulator

- Added 23 deterministic scenario checks covering leveling, post-swing Slam,
  Mortal Strike/Whirlwind Rage protection, Execute filler, target-specific
  Overpower, two- to four-target AoE, Sweeping Strikes pooling, and Cleave.
- Refactored the live priority evaluator to accept an isolated simulation
  context without replacing or mutating the player's combat state.
- Added `/arh sim`, named scenario groups, manual step control, and a complete
  self-check command.
- Added a blue simulation banner and automatic pass/fail diagnostics.
- Suppressed action-bar glow and the live cooldown row during simulation to
  prevent test recommendations from being mistaken for live combat prompts.

## 1.6.0-beta.2

### Live-test polish

- Fixed the swing bar showing `SLAM` after ordinary white swings on characters
  that do not know the improved Slam profile.
- Added a high-contrast caption panel behind the ability name and decision
  reason.
- Added a prominent `TEST MODE` banner and a matching debug-panel warning so
  simulated preview recommendations cannot be mistaken for live decisions.

## 1.6.0-beta.1

### Rotation

- Reworked the addon around a two-handed, post-swing Slam priority.
- Added single-target Whirlwind and protected Mortal Strike timing.
- Added the no-weapon-swap Execute filler model.
- Added Rage pooling for Sweeping Strikes and a separate AoE priority.
- Added level-adaptive recommendations for characters that do not yet know the
  complete level-70 toolkit.
- Made Sunder Armor maintenance opt-in.
- Added assigned Battle Shout or Commanding Shout selection.

### Swing and state tracking

- Added haste-aware main-hand swing prediction.
- Added Slam swing-reset handling.
- Added correct TBC handling for extra attacks that do not reset the underlying
  main-hand timer.
- Distinguished Heroic Strike and Cleave swing replacements from ordinary
  white swings.
- Limited Rend checks to the player's own debuff.
- Added target-specific Overpower dodge windows.
- Added target time-to-die estimation and recent-enemy counting.
- Replaced English spell-name assumptions with localized spell metadata.

### Display

- Added a main-hand swing bar.
- Added separate stance and Heroic Strike/Cleave queue icons.
- Added cooldown/trinket tracking.
- Added action-bar glow support for direct spells and spell macros on Blizzard,
  Bartender4, and Dominos bars.
- Added display test mode and a live debug panel.

### Compatibility

- Updated the interface version for the TBC Anniversary 2.5.6 client.
- Added fallbacks for both modern `C_Spell` APIs and legacy Classic APIs.
