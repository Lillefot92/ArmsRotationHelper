# Beta Testing Checklist

This build is deliberately labeled beta. The Lua files have been syntax-checked,
but the recommendations still need in-game validation across leveling, dungeons,
and level-70 raid conditions.

## Before testing

1. Exit World of Warcraft and back up the existing addon folder.
2. Install the beta and start the Anniversary client.
3. Run `/console scriptErrors 1`, then `/reload`.
4. Run `/arh test`. Confirm the main, stance, queue, swing, and cooldown visuals
   appear and move together after `/arh unlock`. A red `TEST MODE` banner must
   remain visible for the complete preview.
5. Turn test mode off with `/arh test`.

## Settings panel checks

1. Run `/arh` and confirm the settings panel opens. Run `/arh` again to close
   it, then reopen it with `/arh config`.
2. Open `Escape > Options > AddOns > Arms Rotation Helper` and confirm its
   button opens the full panel.
3. Change target mode and assigned shout with both dropdowns. Close and reopen
   the panel; both selections should remain.
4. Toggle every display checkbox and confirm the recommendation display updates
   immediately.
5. Unlock the recommendation display, drag it, lock it again, and adjust the
   scale slider.
6. Use `Reset position and scale` and confirm the display returns to its default
   location and 100% scale.
7. Start and stop display preview from the panel.
8. Select one simulator scenario, start it, advance one step, stop it, and run
   the 26 priority checks from the panel.
9. Start a diagnostic recording, confirm the status counts down from 60
   seconds, stop it, and open the report. The report should already be
   selected for Ctrl+C.

## Remote diagnostic recording

This is the preferred test while waiting for a level-70 tester:

1. Set the intended target mode and maintenance assignments before recording.
2. Stand ready at the target dummy; do not start preview or the simulator.
3. Enter `/arh record` immediately before attacking.
4. Play normally for 30-60 seconds. The recorder stops automatically at 60
   seconds, or `/arh record stop` ends it early.
5. Enter `/arh report`, press Ctrl+C, and paste the complete text into the test
   report. A short video remains helpful but is no longer required.
6. Confirm performed abilities appear as anonymous `A` rows, such as
   `A REND cast` or `A HEROIC_STRIKE replacement`.
7. Confirm the privacy line says the report contains no player, realm,
   account, or target names, chat, GUIDs, or item links.
8. Use `/arh record clear` after sharing if desired. The report is also erased
   automatically by `/reload`, logout, or closing the game.

Start display preview or the simulator during an active recording only to test
the safeguard: recording should stop before simulated recommendations begin.

## Simulator checks

1. Run `/arh sim check`. It should report `26/26 simulator checks passed`.
2. Run `/arh sim`. Confirm that a blue `SIMULATION` banner and the simulator
   diagnostic panel stay visible throughout the complete suite.
3. Confirm each diagnostic step says `RESULT: PASS`.
4. Confirm simulated recommendations do not glow live action-bar buttons and
   that the live trinket/cooldown row is hidden during the run.
5. Use `/arh sim next` to advance immediately, then `/arh sim stop` to restore
   live recommendations.

Individual groups can be repeated with:

- `/arh sim leveling` - low-level shout, Rend, and high-Rage Heroic Strike.
- `/arh sim slam` - post-swing Slam, Mortal Strike, and Whirlwind rhythm.
- `/arh sim rage` - Mortal Strike/Whirlwind Rage protection.
- `/arh sim execute` - no-weapon-swap Execute filler priority.
- `/arh sim overpower` - target-specific dodge proc and stance advice.
- `/arh sim demoralizing` - talented Demo Shout assignment and refresh rules.
- `/arh sim aoe` - two-, three-, and four-target priorities.
- `/arh sim cleave` - Sweeping Strikes pooling and Cleave queue thresholds.

## Level 7 checks

- Select an attackable target out of combat. Charge should appear when usable,
  unless a castable assigned shout needs refreshing first.
- After entering combat, Battle Shout should be maintained when Rage permits.
- Rend should be recommended only when it is missing and the target is expected
  to live long enough.
- After Rend is active, periods with no primary icon are normal. Continue white
  swinging and building Rage.
- After at least one main-hand attack is observed, the swing bar should restart
  on every ordinary white swing.
- The swing bar must continue showing remaining swing time at this level; it
  must not display `SLAM` when Slam or the complete Improved Slam profile is
  unavailable.
- Heroic Strike should only appear in the small queue icon at high Rage, not as
  an ordinary low-Rage main recommendation.
- `/arh stance` should cleanly hide or show stance prompts.

Use `/arh debug` while checking these items. The debug panel should show current
Rage, target health, target time-to-die, swing time, known profile, and the
reason for each recommendation.

## Ability milestone checks while leveling

Repeat a short target-dummy or outdoor test whenever a new Warrior ability is
learned:

- Sunder Armor: never maintained by default; `/arh sunder` enables the assigned
  five-stack behavior on sufficiently durable targets.
- Improved Demoralizing Shout: the panel option must remain disabled at 0/5,
  enable at 1–5/5, and recommend Demo Shout only when the opt-in assignment is
  active and the player's own debuff is missing or nearly expired.
- Overpower: appears only for the target that dodged and disappears after use or
  after the dodge window expires.
- Cleave: appears in the queue position during multi-target combat.
- Execute: appears below 20%; in the future Slam profile it remains filler after
  Slam, Mortal Strike, and Whirlwind.
- Slam: the addon should not switch to the endgame Slam profile until its
  spellbook cast time indicates the fully improved fast cast.
- Whirlwind and Mortal Strike: single-target Whirlwind must not consume Rage
  needed for an imminent Mortal Strike.

## Level-70 single-target checks

Test on a target dummy or durable boss target:

- Let a white main-hand swing land. Slam should flash immediately after that
  swing, not late in the following swing cycle.
- Casting Slam should restart the predicted main-hand timer.
- A haste gain or loss should rescale the remaining swing time without restarting
  the bar from zero.
- Sword Specialization/Windfury-style extra attacks should not restart the
  underlying TBC swing timer.
- Mortal Strike should be prioritized when ready.
- Whirlwind should be used on one target when it will not starve Mortal Strike.
- Below 20%, Execute should fill otherwise empty globals; it should not replace a
  valid post-swing Slam, ready Mortal Strike, or safe Whirlwind.
- No weapon swap should be suggested or performed.
- Heroic Strike should be suppressed below 20% and whenever its Rage cost would
  compromise the protected core sequence.

## Dungeon and AoE checks

- In `/arh mode auto`, two recently engaged enemies should activate the AoE
  profile. Use `/arh mode aoe` to test it deterministically.
- Sweeping Strikes should wait until enough Rage is pooled for the intended
  follow-up.
- Whirlwind should lead the repeatable multi-target attacks.
- Cleave should use the separate queue icon.
- Slam should appear only as surplus-Rage AoE filler.
- Return to `/arh mode auto` after forced testing.

## Action-bar and localization checks

- Put a recommended ability directly on a Blizzard action bar. Its visible
  button should glow.
- Repeat with a macro whose recognized spell is that ability.
- If installed, repeat on Bartender4 or Dominos.
- On a non-English client, run `/arh debug spells`; learned abilities should
  print with localized names and recommendations should retain valid icons.

## Bug report template

Include:

- The complete `/arh report` text when possible.
- Client language (the report already includes version and build).
- Relevant talent details not represented by the recorded profile.
- The recommendation shown and the recommendation expected.
- A short video or screenshot of `/arh debug` if available.
- The exact Lua error text, if any.
- Whether the ability was placed directly or through a macro, and which action
  bar addon was used.
