# 1.6.0-beta.3

First public beta for World of Warcraft: The Burning Crusade Anniversary
2.5.6.

## Highlights

- Swing-aware two-handed Arms priority: swing, Slam, Mortal Strike/Whirlwind,
  then safe filler.
- Execute remains a filler below 20%; no weapon swapping is recommended.
- Sweeping Strikes, Whirlwind, Mortal Strike, Execute, and separate Cleave
  queue advice for multi-target combat.
- Rage protection for Heroic Strike/Cleave and the next core sequence.
- Level-adaptive recommendations while the character is still leveling.
- Optional assigned Sunder Armor, talented Demoralizing Shout maintenance,
  and stance advice.
- Blizzard, Bartender4, and Dominos action-button highlighting.
- Built-in 34-scenario priority test and privacy-safe 60-second diagnostic
  report.

## Rotation audit in this build

- Always favors a valid post-swing Slam before ordinary damage abilities.
- Prevents filler globals from covering the next Slam window.
- Keeps Mortal Strike and Whirlwind ahead of Victory Rush at level 70.
- Avoids expensive high-Rage Overpower stance dances.
- Keeps default level-70 Thunder Clap out of the damage priority while
  retaining it for leveling AoE.

This remains a beta because broad level-70 raid and heroic-dungeon feedback is
needed. If a recommendation looks wrong, run `/arh record`, reproduce it for
up to 60 seconds, then paste `/arh report` into a CurseForge comment. The
report contains no character, realm, account, or target names.
