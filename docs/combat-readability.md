# Combat identity and warnings

CombatMarkers is one world-space presentation node, limited to four entries:
trainer, active slot one, active slot two, and a valid hostile focus target.
It draws above bodies and decorative effects, so overlapping boss/creature sprites
cannot cover the team identifiers. A diamond identifies the trainer, numerals
identify slots, and a cross identifies focus; meaning does not depend on color.
HUD companion names use the same slot numerals. The glyphs are built from hard
pixel rectangles in the existing coarse world viewport, not smooth text textures.

Overlapping badges use a bounded set of horizontal offsets with a short leader
to their owner. Actor movement, replacement, focus changes and defeat update the
existing layer. Unchanged entries skip redraw. No actor references survive inside
the marker list; identity/position records prevent freed-source access. The layer
continues presentation checks through pause so trainer defeat clears its marker,
without ticking any gameplay state. Hidden/dead/removed actors do not get markers.

Marker attachment uses the opaque bounds of the currently displayed frame.
`tools/register_visible_bounds.py` reads source alpha at the renderer's threshold
and writes `visible_bounds` into the seven animation Resources (402 frames).
It never edits source images. Main hero and creature registration pipelines run
it after their other registrars; run it explicitly after an individual atlas tool.
Runtime transforms include scale, anchor offsets, mirroring and bird lift. Older
frames without this optional metadata fall back to the sprite rectangle.
Content validation rejects malformed/out-of-frame bounds.

Ground warnings retain the authored radius, timing and damage. Their outer and
expanding boundaries now have a dark backing stroke, and ticks use the same
contrast treatment. Warning/marker materials ignore local lights and survive
minimum decorative-effect quality. This changes visibility, not combat behavior.

## Evidence and limits

`tests/combat_readability_runtime.tscn` reports thirteen checks, including coincident
team members, nonoverlapping badges, unchanged combat/RNG state, real party swap,
matching HUD numbering, focus removal, paused defeat cleanup and area replacement.
`tools/test.ps1` runs the headless lifecycle check with a deadline and mandatory
completion marker. `build/combat-readability-native.log` verifies the rendered run;
`build/combat-readability-{overlap-low,separated,swapped}.png` provides actual frames.
Overlap and separated scenes were visually inspected, then attachment was revised
to use opaque bounds. Minimum effect quality is explicitly exercised.

The fixture deliberately overlaps frozen actors to expose occlusion. It is not a
performance measurement, accessibility certification, or proof of every future
art palette/layout. Markers identify location; they do not make an occluded body's
entire animation visible.
