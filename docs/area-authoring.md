# Authored first-slice areas

`AreaData.layout` references an editor-native `AreaLayout` Resource. Current layouts are `resources/layouts/haven.tres` and `resources/layouts/grove.tres`. They are hand-authored content and are not overwritten by `tools/build_content.py`; that generator only rebuilds the AreaData references and translations.

The haven connects the camp, restorative spring and eastern gate. The grove has an entrance pack followed by a fork: the upper trail passes the spring landmark and elite ruins; the lower trail crosses two encounter clearings. Both join the guardian arena. A cross-trail connects the lower clearing to the upper route. This is the authored first slice; procedural arrangement, additional biomes and weather remain future work.

## Resource fields

- `entry`: trainer arrival position in world coordinates.
- `paths`: a `points` polyline and full `width` in world units. All paths together may contain up to 32 segments. The renderer and minimap consume the same geometry.
- `clearings`: center `at`, elliptical `radii` and `surface` (`dirt` or `stone`), at most 12. The ground shader retains coarse sampling and dithered edges.
- `props`: atlas `cell` 0–5, foot position `at`, visual `height` and `solid`. Solid footprints are height × 0.23 wide and 22 units deep. Navigation and the actual StaticBody2D use these same dimensions. Place tall canopies around readable routes, not over combat centers.
- `lights`: position, HTML color, energy and radius.
- `encounters`: stable `id`, species, explicit positions, level, kind (`wild`, `elite`, `boss`) and optional elite affix ID. Current levels progress from one at the entrance to three in the farther clearings. Combat balance still needs playtesting.
- `interactions`: stable `id`, position, localized `label`, radius, action (`camp`, `rest`, `exit`) and exit target. Declare destinations in `AreaData.exits` as well. Prompts, interaction checks and minimap markers read these entries.

Existing encounter save IDs remain `encounter:area.grove:pack:N:M`, `encounter:area.grove:elite` and `encounter:area.grove:boss`. Do not repurpose IDs for unrelated encounters. Saved defeated/captured IDs still suppress spawns. When a saved actor position is blocked by revised geometry, restoration finds a clear nearby position; enemies fall back to their authored origin and the trainer to the area entry if no nearby point exists.

## Verification

`LayoutValidator` rejects malformed content, duplicate identities, missing exit destinations, shader-capacity overflow, blocked entry/road centerlines/interactions and spawn footprints. `tests/layout_checks.gd` additionally checks navigation connectivity, renderer/collider agreement, save identity continuity and old blocked saved positions.

`tests/layout_runtime.tscn` physically walks the trainer through three haven destinations and twenty grove waypoints, checks clearance and motion bounds, and requires directional walking frames. Companions follow normally; enemies are frozen so the fixture isolates traversal, not combat difficulty. It is included in `tools/test.ps1`. Run it natively with Movie Maker for `build/layout-tour.avi`; `build/layout-tour.mp4` is the review copy. `build/layout-*.png` and `build/haven-final.png` / `boss-final.png` show the authored composition at the actual world resolution.

Current art repeats a small existing prop/ground atlas. Layout and collision checks are not evidence that world-art polish or the full gameplay quality gate is finished.
