# Combat performance evidence

## Demo handoff: ordinary journey (2026-09-26)

`tests/journey_runtime.tscn -- --journey-timing` ran the real journey pilot at
ordinary native speed, with no fixed-FPS flag, recorder, encoder or concurrent
test suite. Effects remained high, VSync enabled, max_fps=0, actual client size
1920×1055 on the local Radeon. Three seconds of warmup precede sampling. PNG
capture is disabled during sampling; the completed-journey image is taken afterward.

The complete 158.923-second timing interval loses focus in 2367 samples and has
1519 no-draw samples. Its raw 55.88 FPS is **not a valid whole-route FPS result**.
All chronological samples remain in `build/demo-journey-timing.json`.
The prefix consisting of every sample in the first 30 seconds after warmup
(no individual samples removed, no fastest-window selection) is valid: 1797
samples over 29.985 seconds, 59.93 delivered FPS, p95 17.599 ms, p99 18.513 ms,
maximum 53.278 ms, zero lost-focus/no-draw samples. This covers initial travel,
capture and ordinary combat, not a whole-route or target-hardware certification.
Prefix calculation: `build/demo-journey-prefix.json`. The full functional journey
succeeds independently of timing validity; see `journey-verification.md`.
Stable 60 FPS throughout the full game and heavy stress load remains unfinished.

Local device: AMD Radeon(TM) Graphics, Windows, native Godot 4.7.2 OpenGL compatibility,
1920×1080 configured window, 480×270 world viewport, effects high. The latest native
measurement reports an actual client size of 1920×1055. These are development samples,
not a hardware compatibility certification or a guarantee of delivered frame pacing.

## Current duration-based scenario

`tests/stress.tscn` now runs `static20`, `static30`, `moving30` and `obstructed30`. Each case uses
three seconds of warm-up followed by twenty seconds of physics simulation. The
moving case also has 120 drops, actual trainer movement and camera tracking. All
cases retain two companions, damage, status effects, projectiles and particles;
increased health keeps the enemy population alive. The native benchmark explicitly
caps at 60 FPS; this does not change the game's settings. Headless runs validate
fixture behavior only, never rendering performance. The obstructed case adds a real
collision wall and repeatedly traverses around it. The fixture autopilot caches
its route for 24 ticks or until its destination changes; issuing AStar every tick
would measure test code that the player's direct movement does not use.

After each measured interval, new casts and actor simulation stop. Five seconds
of physics time let actual projectile and effect lifetimes expire, outside the
timing sample. Reports record node/orphan populations each simulation second and
check that all transient collections are empty. The exact registered, inactive
audio pool nodes are accounted separately and must remain within Audio.VOICE_LIMIT;
unexpected added nodes still fail cleanup. No forced effect deletion is used.

```powershell
& 'tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path . tests/stress.tscn -- --profile-combat
```

Optional arguments: `--stress-case=moving30`, `--stress-seconds=60` (1–120),
`--stress-output=report-name`. Default output: `build/performance-duration.json`.
`--stress-uncapped` removes the fixture's engine FPS cap, matching the game's
default max_fps=0. It does not disable VSync or force a fixed simulation timestep;
reports retain VSync mode, screen refresh and focus validity separately.
Do not run alongside video encoding, other Godot renderers or test suites.

Format 2 reports preserve chronological wall-time samples, actual drawn/physics
frame counters, focus, window size, source hashes, draw calls and per-viewport
CPU/GPU timings. Source hashes include the fixture, timing collector, navigation,
actor/brain/presentation, HUD/labels/markers/effects and ground shader/layout.
Delivered FPS uses drawn frames divided by wall time. Percentiles
use nearest rank. Focus loss or samples with no rendered frame invalidate pacing;
headless reports therefore deliberately fail `pacing_sample_valid`. A one-tick
boundary difference is possible between the configured simulation interval and
the process-sampled physics counter. Each finished report owns a deep copy of its
timeline so starting the next case cannot erase it.

The [Godot Performance documentation](https://docs.godotengine.org/en/stable/classes/class_performance.html)
notes that some monitors update with a delay; they cannot replace the frame clock.
[RenderingServer timings](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html)
are collected for both the world and root viewports, plus CPU frame setup. They
are diagnostic components, not a substitute for delivered frame timing.

## Longer movement, obstruction and cleanup audit

`build/performance-moving60-current.json` retains a 60-second native open-route
sample: 30 enemies, 4,137 combat events, 3,600 physics ticks and 9,600 units of
trainer movement. It made zero AStar searches and lost focus for 1,197 samples;
its 57.36 delivered FPS is excluded from pacing acceptance. This exposed the
need for the separate physical-wall case rather than a pathfinder optimization.

The first native 120-second wall run (`build/performance-obstructed120-current.json`)
made 616 AStar searches, 40 wall crossings and 7,973 combat events across 7,200
physics ticks. All 30 enemies survived; sampled bodies stayed collision-clear,
both companions had zero recovery teleports and all transient effects expired.
Its original strict node-count assertion failed (518 before / 532 after). The
subsequent node-identity audit identified the bounded native spatial audio pool
as retained by design, rather than an effect lifetime leak. The original failed
report is preserved; do not relabel it as a passing cleanup test. It also lost
focus for 2,181 samples and had 949 callbacks without a drawn frame, so its timing
is not valid pacing evidence. Navigation script sections totaled 349.5 ms across
1,301 calls (including direct routes), maximum 1.649 ms; these are diagnostic
script timings, not a whole-frame performance claim.

`build/obstructed-pool-native.json` verifies the corrected node-identity audit in
a ten-second native run: 63 searches, three crossings, 662 combat events, zero
companion recoveries, zero unexpected nodes, no orphans and all effect/projectile
collections empty after natural expiration. Exactly 13 registered inactive audio
voices remain, below the existing limit of 24. This shorter run kept focus and
delivered 56.68 FPS, mean/p95/p99 17.64/23.48/29.96 ms at max_fps=0, VSync enabled,
60 Hz and 1920×1055. That does not meet a stable 60 FPS target; no speedup is
claimed. Headless `build/obstructed-initial.json` separately passed ten simulation
seconds (64 searches, three crossings), with audio disabled and exact node recovery.

The corrected 120-second native run, `build/obstructed120-pool-verified.json`, passes
fixture and cleanup validity: 7,200 physics ticks, 7,973 combat events, 616 AStar
searches, 40 crossings, 30 living enemies and zero companion recovery teleports.
Every sampled body remains clear. Cleanup retains exactly the 518 initial nodes
plus 14 identified inactive pool voices: no unexpected nodes, no orphans and zero
projectiles, particles, rings, floating labels or hazards. Peak population is 574
nodes / 21 projectiles / 180 particles. Its 17,105 unfocused/no-draw samples make
it invalid for pacing: use it only as a bounded simulation/lifetime audit, not as
evidence that rendering sustained the full run. No further retry was made merely
to obtain a passing FPS result. A longer campaign soak and controlled, focused
target-hardware timing still remain acceptance work.

## Dense-loot label optimization

World labels now cache text widths and the stable rarity-sorted filtered indices.
Overlap checks inspect nearby 32-pixel horizontal bands instead of every earlier
rectangle. Camera movement still repositions labels, selected pickup still gets
priority, and the candidate budget remains 64. Filtering, reveal, drop revisions,
area changes and translation changes invalidate the appropriate caches.

Matched focused native samples, 30 enemies / 120 drops / moving camera / all visual
layers / high effects / VSync / benchmark cap 60 / actual window 1920×1055:

| Metric | Before | After |
| --- | ---: | ---: |
| Delivered FPS | 53.93 | 59.62 |
| Frame mean / p95 / p99, ms | 18.54 / 25.74 / 34.22 | 16.77 / 19.35 / 21.96 |
| Frames above 25 ms | 64 / 1078 | 4 / 1192 |
| Label draw average / maximum, ms | 3.008 / 6.014 | 1.643 / 3.150 |
| Physics frames / combat events | 1199 / 1372 | 1200 / 1374 |

Evidence: `build/duration-moving-before.json` and
`build/duration-moving-after-focused.json`, with matching `.log` files. Both report
valid pacing, no lost-focus samples and all thirty enemies alive. Average label
draw CPU cost fell about 45%; this short local pair does not certify stable 60 FPS
across the game, machines or long sessions. This route made zero AStar searches,
so it is not a crowded pathfinding benchmark.

Retained excluded evidence: `build/duration-moving-after.json` lost focus for 836
samples and is invalid for pacing. The initial `build/duration-baseline.json`
predates the timeline ownership fix; its aggregate summaries survive but its
per-case timelines are not valid evidence. Earlier 300-frame samples below use a
different fixture and must not be compared as an isolated before/after speedup.

Seven label checks compare 240 placements against the previous exhaustive
algorithm, including screen edges, and exercise filter/reveal/order/cache rules.
Seven timing checks cover stalls, counter differences, invalid focus/headless
samples and report ownership. `tests/render_loot_density.tscn` additionally verifies
nonoverlap, actual pickup, filtering, reveal, English labels and camera movement
in a native render (`build/loot-density.log`, `verified=true`). It placed 41 labels
from the initial 120 drops and all thirty eligible labels after rarity filtering.

## Historical 300-frame scenario

The previous `tests/stress.tscn` ran 20, then 30 enemies around the trainer, two companions,
projectiles, particles and status effects. Each case discards 60 warm-up frames and
samples 300 frames. Enemies receive increased health to sustain the encounter.
Its last unprofiled isolated sample is `build/performance-layout-isolated.json` with `build/layout-stress-isolated.log`. Earlier live-status results remain in `build/performance-live-status.json`.

| Native VSync run | 20 enemies mean / p95 | 30 enemies mean / p95 |
| --- | --- | --- |
| After combat animations, before HUD/effects changes | 17.44 / 21.01 ms | 18.05 / 26.60 ms |
| After HUD/effects changes | 16.89 / 17.79 ms | 17.52 / 21.00 ms |
| After functional traits/passives, isolated follow-up | 16.67 / 18.21 ms | 18.59 / 30.54 ms |
| After configurable input/filter and readable labels | 16.96 / 19.35 ms | 18.66 / 31.72 ms |
| Fresh baseline after directional art / trainer defeat | 16.68 / 18.07 ms | 16.77 / 19.97 ms |
| Shared sprite material and compiled modifier terms | 16.67 / 18.36 ms | 17.01 / 19.23 ms |
| Clearance navigation and bounded route replanning | 16.67 / 17.88 ms | 16.66 / 18.38 ms |
| Live effect indicators and distinct status glyphs | 16.67 / 18.02 ms | 16.71 / 19.13 ms |
| Authored area layouts, isolated follow-up | 19.02 / 31.96 ms | 20.84 / 35.73 ms |

The earlier live-status follow-up is in `build/performance-live-status.json`. At 30 enemies its p99 is
21.08 ms and 1 of the 300 measured frames exceeds 25 ms (20 enemies: p99 19.24 ms,
zero frames above 25 ms). The fresh baseline already improved relative to the older
sample without a performance code change, so the old/new difference cannot be
credited to this optimization. Whole-frame improvement is not established.
It uses the existing command
loadouts with the new passive rules enabled, not a benchmark of all four newly
unlocked area commands. It is not a dense-loot label benchmark either. The 30-enemy p95 remains high and needs further
profiling/longer measurement. No performance improvement is claimed for this change.
An earlier attempt overlapped the tail of a visual render and is retained separately
as `build/performance-overlap-progression.json`; it is not used in the table.

Remaining timing variation is visible. More representative movement, long-session,
graphics-driver and target-machine measurements are needed before release acceptance.

The first live-status run recorded 30-enemy mean 17.11 ms / p95 20.96 ms / p99
35.40 ms, with eight frames over 25 ms (`build/performance-live-status-first.json`).
The final row followed removal of unnecessary glyph-row string serialization and
batched adjacent glyph pixels into horizontal rectangles. These short samples are
not a controlled comparison and do not prove that those edits caused the change.
No stable-60-FPS or overall speedup claim follows from either run. Both keep all
visual layers enabled. Live status strips use four shared HUD refreshes, not
additional per-actor process callbacks.

## Profiling

Run the scene with `-- --profile-combat` to include aggregate GDScript sections in
the report. `CombatProfiler` is disabled by default. It measures actor state,
decisions, motion, presentation, navigation, HUD and effects. Native Godot
`--gpu-profile` was also used; canvas rendering was the main reported GPU section.

The stationary fight did not call navigation: replacing its pathfinder would not
address this particular measurement. HUD profiling exposed repeated Control/portrait
creation and approximately 3.5–5.8 ms worst sampled HUD updates in the uncapped run.
After caching cards and updating text at its actual display precision, the same
script section peaked below 1 ms in that run. Live health/energy bars still update
every rendered frame. Minimap dots/text refresh at 10 Hz; static world labels redraw
only after relevant changes. Empty effects stop processing and wake for new effects.

To separate work cost from display synchronization, an additional run used
`--fixed-fps 60 --disable-vsync tests/stress.tscn -- --profile-combat`.
It simulates the same six seconds per case while rendering without realtime waiting.
The after-change means were 6.49 / 7.00 ms, p95 10.55 / 10.73 ms for 20 / 30 enemies.
These numbers describe uncapped work cost, **not** delivered interactive frame pacing.
The baseline uncapped run additionally used GPU profiling, so whole-frame before/after
percentages from those two runs are not an isolated benchmark.

Detailed samples: `build/performance-profile-before.json`,
`build/performance-uncapped-before.json`, `build/performance-uncapped-after.json`.
Godot Performance monitor values are sampled aggregates and are not interchangeable
with the per-frame wall-clock distribution; use the latter for reported frame timing.

## Material and stat-query investigation

All identical sprite shaders now use `shaders/sprite_pixels.tres`. Individual flash,
cosmetic tint and atlas selection remain per Sprite2D; no per-instance uniforms are
stored in the shared resource. In matched fixed-60/uncapped samples this removed
seven draw calls per frame: 20 enemies mean 283.61 → 276.61; 30 enemies
363.82 → 356.82. It did not produce a consistent whole-frame speedup.
Reports: `build/performance-material-before.json`, `build/performance-material-after.json`.

Render-only diagnostic flags in `tests/stress.tscn` hide effects, actor presentation
or UI separately while retaining simulation and target visibility. At 30 enemies
the uncapped means were 6.54 / 6.55 / 6.69 ms respectively, versus 6.95 ms with all
layers visible. These runs suggest distributed cost; they do not identify a single
cause of the interactive pacing spikes. Reports: `build/performance-no-*.json`.
Never use hidden-layer timings as delivered-game results.

`StatsComponent` now compiles source-dependent flat/add/multiply/override terms on
source replacement/removal instead of scanning every modifier for every query.
Base stat, level and scaling are still read live; source-order override semantics
and deep-copy ownership are retained. The isolated `tests/stats_benchmark.tscn`
compares the previous scan formula to current queries with 12 sources and 36
modifiers, 120,000 queries per sample, five alternating-order repetitions.
Median scan: 1511.89 ms; compiled: 163.86 ms (~9.23× faster for this query workload).
All paired checksums agree. This is a modifier-heavy microbenchmark, not an FPS
claim, and excludes the source-rebuild cost. The actual small stress encounter has
fewer modifier sources and did not establish an overall frame-time gain.
Historical evidence: `build/stats-benchmark-pre-bounds.json`,
`build/performance-compiled-stats.json`. The original query report was preserved
before the final probability bound was added. The current scan reference and
compiled query both apply that bound; `build/stats-benchmark.json` and
`build/stats-benchmark-bounded.log` verify equal checksums for all five repetitions
with those semantics. This rerun is not an isolated before/after timing comparison
and establishes no new FPS improvement.

Stress reports now include mean/peak draw calls, p99, frames above 25 ms, quality,
VSync mode and diagnostic arguments. The short stationary scenario is still
insufficient for navigation, dense loot, moving-camera and long-session acceptance.

## Navigation correctness and bounded work

`tests/navigation_runtime.tscn` separately exercises physical wall bypass, narrow
passage, destination reversal, companion recovery, HOLD and a too-wide boss.
The native recording passed all six scenarios; the ordinary wall bypass made six
AStar searches over 390 physics ticks with no recovery teleport. In that recording,
41 timed navigation queries totaled 7.24 ms, max 1.30 ms. These are query timings in
a small diagnostic fixture, not a crowded-navigation FPS measurement.

An initial recovery case exposed a new repeated-search problem: once stuck time
exceeded its threshold, resetting the repath timer every frame made 128 searches.
Keeping the regular bounded retry interval reduced that case to eight native
searches without changing its successful recovery. Radius grids are built during
area setup to avoid the first moving enemy constructing them during combat.
Native evidence: `build/navigation-runtime.json`; headless counterpart is stored
separately in `build/navigation-runtime-headless.json` by `tools/test.ps1`.

## Authored-layout sample

The new isolated unprofiled run records p99 39.98/52.40 ms and 36/62 frames above 25 ms for twenty/thirty enemies. No other Godot recorder or ffmpeg job was running during that follow-up. An earlier run overlapped video encoding; its thirty-enemy mean was 42.09 ms and it is retained only as `build/performance-layout-contended.json`.

The subsequent `--profile-combat` run is stored in `build/performance-layout-profile.json`. Its twenty-enemy mean/p95 were 17.12/20.24 ms; the thirty-enemy mean dropped to 8.60 ms despite VSync reporting enabled, so it is not a matched pacing comparison. Thirty-enemy aggregated actor state/decisions/motion/presentation totals were 143/149/68/141 ms across 7,161–7,623 calls; no single measured script call exceeded 0.58 ms. Effects draw peaked at 1.36 ms. These aggregates do not account for all engine/render/driver work or identify the cause of whole-frame stalls.

The layout renderer adds data-driven road/clearing shader loops and changes visible prop placement. Current samples do not establish their isolated cost. Stable 60 FPS remains unverified; longer matched measurements with visibility/focus and host load controlled are still required. Do not describe the authored layout as a performance optimization.

## Loot placement hot loop (2026-09-26)

A fresh 15-second native `obstructed30` profile with all visual layers and the updated combat audio identified loot-label placement/drawing as the largest measured script section: mean 1.840 ms, peak 5.334 ms. Baseline evidence: `build/obstructed-profile-current.{json,log}`. The run was focused throughout and drew on every sample.

A first candidate replaced the existing horizontal strips with a two-axis spatial grid. It produced identical rectangles, but was slower on dense inputs. Its rejected five-repetition measurements remain in `build/loot-layout-grid-rejected.{json,log}`. The production code retains horizontal strips.

The retained change computes horizontal clamping/rounding once per label, skips vertically out-of-bounds candidates before constructing a rectangle, and queries the at-most-two relevant strips directly. The fixed 22px label height, with 2px collision padding on each side, is smaller than the 32px strip. Candidate order, bounds, spacing, priority, limit, selection and tooltip geometry are unchanged.

`tests/loot_layout_benchmark.tscn` compares a frozen copy of the previous production strip algorithm with current placement. It alternates execution order across five repetitions of 100 layouts each, at 240 candidate drops, for spread and dense coordinates. Every returned rectangle agrees. Median times per 100 layouts: spread 232.988 → 179.245 ms (23.1% lower); dense 243.105 → 182.955 ms (24.7% lower). This is an isolated placement benchmark, not an FPS claim. Report: `build/loot-layout-benchmark.json`. Source regressions also compare exhaustive placement at four viewport sizes, fractional/half-pixel coordinates, oversized text, edges and offscreen positions.

The matched native follow-up (`build/obstructed-profile-labels.{json,log}`) keeps the same 15-second duration, 30 enemies, 120 drops, five wall crossings, 995 combat events and 91 navigation searches. Both runs pass body-clearance and natural cleanup checks, with zero companion recovery teleports. Mean measured label draw CPU falls from 1.840 to 1.683 ms (8.5%); peak from 5.334 to 3.963 ms. Draw-call means remain essentially unchanged (751.72 / 751.20), as expected from a CPU-only layout change.

Delivered FPS in these two focused, VSync-enabled samples was 53.71 / 55.51; p95 frame time 26.375 / 25.635 ms. This small whole-frame difference is not evidence of stable 60 FPS or an isolated global speedup. The performance gate remains open. Neither sample overlapped a recorder, encoder or test suite. Native dense-loot rendering separately passed pickup, filter, reveal, English and moved-camera cases (`build/loot-layout-native.log`); Russian/English screenshots were inspected.

## Batched ground-loot markers (2026-09-26)

GameWorld now draws the same filtered ground-marker population through one MultiMesh. Each instance contains its translucent vertical beam followed by its opaque rarity-colored coin, retaining per-item painter order. Instance transforms/colors update on the existing redraw events; the mesh is reused across pickup, filtering and reveal. No item, label, pickup or save state moves into the renderer.

`tests/render_loot_markers.tscn` compares the old immediate-mode commands and the new mesh in two native 480×270 viewports at the game's half-scale. It includes all rarities, fractional positions and coincident differently colored drops, then adds ambient/point lighting and camera-like panning. Every comparison has a maximum per-channel difference of one out of 255 (vertex-color quantization), with nonempty reference output. For 122 instances, the fixture's total draw calls drop from 246 to 3. Images and the report are `build/loot-markers-{plain,lit,panned}-{before,after}.png` and `build/loot-markers-render.json`; the lit pair was visually inspected.

The first prototype used a 64-segment coin. Although it reduced draw calls, the first 15-second native before/after samples delivered 58.51 / 51.82 FPS, so draw-call reduction was not treated as an overall speedup. This early result is retained as `build/loot-batch-after-64.json` (and its original log). Sixteen segments pass the same raster comparison with less geometry; no causal claim about the early FPS difference is made.

To compare work cost, the previous draw loop was temporarily restored between native runs using `--fixed-fps 60 --disable-vsync`, the same 15-second obstructed simulation and all layers enabled. Final code uses the batch. `build/loot-batch-work-before.json` / `loot-batch-work-after.json` record mean frame intervals 13.341 / 12.572 ms, p95 17.587 / 16.813 ms, mean render CPU 2.243 / 1.683 ms, and mean render GPU 4.407 / 3.864 ms. Mean draw calls are 752.35 / 514.04. These fixed-step, uncapped runs compare work, not interactive delivered FPS; both were focused and pass scenario/cleanup checks.

The final separate 30-second interactive native run (`build/loot-batch-final30.json`) has 1,989 combat events, 170 navigation searches and ten wall crossings with thirty living enemies. Body clearance and natural cleanup pass, with no missing-draw or lost-focus samples. It delivers 56.44 FPS, p95 24.205 ms and p99 37.922 ms; mean draw calls are 509.70. Stable 60 FPS is still not achieved. No recorder, encoder or source tests ran concurrently with these measurements.

Six headless checks cover population, nonmutation, resource reuse, shrinking, clearing and repopulation. The native fixture runs ten data checks, additionally reading ordered transforms/colors and their updates from the actual renderer. The dummy headless backend does not provide that GPU readback; native color readback has a measured maximum float error of 0.000393, within the independently checked one-level raster tolerance. The first source test attempt incorrectly required exact GPU values headlessly and is retained in the failed package's `verification/tests.log` (`20260926-125918-b8ea0b`). The actual dense-loot native fixture also verifies batch population after pickup/filter/reveal/camera changes (`build/loot-batch-density.log`); it checks that the batch count equals the live filtered drop count rather than only testing isolated mesh data.
