# 1.6.1-beta.1

Clarity and stacked-haste validation update for World of Warcraft: The
Burning Crusade Anniversary 2.5.6.

## Intentional wait indicator

- Added an optional dimmed watch when a filler global would cover the next
  swing and lose the post-swing Slam opportunity.
- The watch uses a muted blue border, never glows an action-bar button, and
  explains the hold on hover.
- The indicator is enabled by default and can be changed in settings or with
  `/arh wait`.
- Display preview and the simulator now demonstrate the wait state clearly.

## Stacked-haste checks

- Added deterministic coverage for Haste Potion, Potion plus Dragonspine
  Trophy, DST-only, and return-to-base weapon speeds.
- Verified that each speed change preserves the remaining fraction of the
  active swing instead of restarting it.
- Added an in-game `Stacked haste` scenario covering safe filler, an imminent
  swing hold, and immediate post-swing Slam at faster speeds.
- Expanded the built-in priority suite from 34 to 39 passing checks.

## Unchanged rotation model

- Main-hand swing → Slam → Mortal Strike / Whirlwind → safe filler.
- Execute remains a filler below 20%; no weapon swapping is recommended.
- Single-target and AoE priorities, Sweeping Strikes pooling, and separate
  Heroic Strike/Cleave queue advice remain intact.

This remains a beta because broad level-70 raid and heroic-dungeon feedback is
needed. If a recommendation looks wrong, run `/arh record`, reproduce it for
up to 60 seconds, then paste `/arh report` into a CurseForge comment. The
report contains no character, realm, account, or target names.
