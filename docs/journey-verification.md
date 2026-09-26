# First-journey verification

`tests/journey_runtime.tscn` drives one new journey with ordinary movement,
attack, command, capture, potion, dodge and interaction inputs. Equipment and
party swaps use the same actions as menu buttons; target selection uses the
player's explicit focus target. Enemy AI, damage, health, loot and progression
remain active. The pilot does not grant health, XP, equipment, invulnerability,
teleports or successful captures.

The authored route equips the three starter items, walks from the haven into
the grove, captures a fire creature, changes the build, clears ordinary packs
and the elite, making two ordinary return trips to the haven's healing spring
(before the elite and before the guardian). Success requires all three objectives, all guardian phases, the
collected unique reward, walking-frame coverage, and an actual save/load that
preserves party, inventory, selected slots, objectives and trainer health while
keeping the defeated boss removed. The save fixture uses its own user-file
path, not the player's journey.

This is an integration pilot for the default seeded content. It demonstrates
that these systems can complete a connected gameplay loop. It is not human
playtesting, a balance approval, a replay-determinism certification, or proof
that arbitrary strategies/seeds and future content work.

## Findings and changes

- Companion formation previously depended on engine object allocation IDs.
  Active slots now determine the formation, and spawn coordinates/faction set
  repath staggering. Checks reverse slots without reallocating actors and compare
  cadence between actors with identical spawn data but different object IDs.
- The initial pilot escaped each pending boss circle separately, replacing its
  destination with the last circle's suggestion. This could enter earlier waves.
  The pilot now chooses a reachable endpoint outside all pending circles and
  retains it until the threat expires. Potion checks use a 0.1-second input cadence.
  These are pilot changes; enemy damage, health and player resources are unchanged.
- The first run collected the guardian relic before reaching the boss.
  `build/journey-before-loot-fix.json` retains that failed run. Ordinary loot
  previously selected all registry keys except the last one, so registry order
  accidentally controlled reward eligibility. `RulesData.loot_tables` now
  explicitly declares common, elite and boss drops. The generator uses its
  seeded RNG and validates item IDs, weights, chance, rarity and level. Common
  chance remains 40%, elite drops remain guaranteed, and the boss table
  guarantees the level-five unique relic. Registry-order reversal checks preserve
  the complete generated sequence, including item IDs and affixes.
- Companions originally stood inside committed ground attacks. ActorBrain now
  searches a bounded set of safe endpoints and uses existing physical navigation
  to leave hostile telegraphs. It waits outside overlapping pending waves,
  ignores friendly/cancelled sources, and honors HOLD. Failed endpoint searches
  retry at most every 0.2 seconds. A compact live hazard registry avoids scanning
  every projectile/effect node for each AI tick.
- A retreat reached a clear strip at `(35.44413, 305.8614)` with no direct visible
  connection to the 16-pixel AStar grid. Navigation now tests up to sixteen short
  cardinal bends, each with full collision clearance, before entering the grid.
  The regression uses the actual grove geometry and checks every route segment.
- Fully replenished abilities retain a harmless live charge cache, while load
  restores their default full count implicitly. Cooldown serialization now omits
  those redundant full entries without modifying live state. Spent charges,
  active timers and the global cooldown remain exact in the round-trip checks.

## Focused hazard fixture

`tests/hazard_avoidance_runtime.tscn` uses actual movement, telegraphs and damage
for six cases: one circle, overlapping waves, a physical wall, HOLD, friendly
source and cancelled source. Moving cases require unchanged health, multiple
walking frames, clear motion and no teleport. HOLD requires remaining stationary
and actually taking the hit. Every case checks that hazard ownership is cleaned
up and route-search counts stay bounded.

The rendered capture is `build/hazard-avoidance.mp4`; the corresponding native
log is `build/hazard-avoidance-native.log`. Headless and rendered fixtures serve
different purposes: the former checks state, while the latter also demonstrates
the visible escape animation. Neither is a frame-pacing benchmark.

## Verified journey (2026-09-26)

The revised headless and rendered runs both completed in 142.017 seconds of
simulation, with 354 combat events, all three boss phases, 21 trainer frame IDs,
all objectives, the unique reward and a successful save/load comparison.
Reports: `build/journey-headless.json` and `build/journey-native.json`.
The rendered run is `build/journey.mp4`; its log is `build/journey-native.log`.
The capture/build and completed-journey stills were inspected. Matching these
two runs does not certify determinism across platforms or other seeds.

The native movie above predates the subsequent arrival-placement fix. Its final
report exposed companions still at the area entrance after loading. The current
headless journey rerun additionally compares party placements and trainer
position/facing, and passes. Native first-frame/restored-HOLD/legacy placement
evidence for that fix is `build/arrival-native.log` and `build/arrival-*.png`,
documented in `docs/saves.md`; the older movie is not evidence of the new load order.

## Commands

The demo handoff rerun uses ordinary native timing, without `--fixed-fps` or a
movie encoder: `tests/journey_runtime.tscn -- --journey-timing`. It completes in
162.317 simulation seconds, with 355 combat events, all three guardian phases,
21 trainer frame IDs, all objectives, the unique reward and successful save/load.
The loaded session retains `demo_completed()` and displays the results screen.
Reports/logs: `build/demo-journey-native.{json,log}`; inspected final screenshot:
`build/demo-journey-complete.png`. The changed event counts/timing compared with
the earlier fixed-step pilot are not treated as replay determinism evidence.
The timing mode suppresses intermediate PNG capture and only captures results
after sampling ends. Its performance limits are documented in `performance.md`.

The full `tools/test.ps1` includes the headless journey and hazard scenarios with
deadlines, nonzero-exit/error checks and required completion markers. A standalone
native journey can be run with:

```powershell
& tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 60 --write-movie build/journey.avi --quit-after 21800 tests/journey_runtime.tscn
```

The first native pilot attempt is retained as `build/journey-native-first.json`.
It is a failed experiment, not completion evidence. Explicit focus selection in
the revised pilot removes ambient desktop-pointer targeting from its decisions.
