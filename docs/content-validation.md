# Content authoring validation

Run `tools/validate-content.ps1` after editing Resources. It imports the project,
launches `debug/ValidateContent.tscn` without gameplay and requires both exit code 0
and `CONTENT VALIDATION valid=true`. `build/content-validation.json` contains the
engine version, per-registry resource counts and error list. The current catalog
has 53 Resources including RulesData. A missing completion marker, script error or
nonzero exit fails the command; a frame deadline alone is not evidence of success.

The Content Viewer also has **Проверить данные**. It validates its loaded Resources
and shows counts plus source/field diagnostics. Use the command in a fresh process
to validate edited files on disk. This is an authoring tool, not player-facing UI.

The registry sorts filenames for reproducible loading, checks Resource class
before reading its ID and rejects duplicate IDs without replacing the first
entry. Duplicate diagnostics include both source paths. Load errors are retained
separately from semantic errors: revalidation preserves each load error once,
recomputes semantic errors, and clears repaired errors instead of accumulating
old reports. Renaming a valid file still does not change its content ID.

Validation is split into small components:

- `ContentFields`: registry identity/type guard, finite base stats, species
  parameters, ability timing/range/power, status durations/ticks/stacks, item
  category/slot/rarity and trait categories.
- `ContentValidator`: ability/trait references, glyphs, modifiers, triggers,
  conditions, ability effects and weighted loot tables.
- `RuleValidator`: rule scalars, declared type chart, reaction parameters,
  item/elite affix identities and nested modifiers/triggers, and ordered boss
  thresholds with valid intervals/radii/waves.
- `AnimationValidator`: finite animation timing/scales, idle indices, frame
  sources, numeric atlas rectangles/anchors/opaque bounds and sequence indices.
  It validates dictionary shapes before texture resolution or Rect2 construction.
- `LayoutValidator`: playable finite area size/levels, authored paths/props,
  interactions/encounters, references and collision-clear geometry.

Declare a new element as a type-chart row (an empty row is allowed); it is then
available to species, abilities, statuses and reactions without adding a code
enum. Trainer slots are nonempty data IDs rather than a hardcoded boots/charm list.
The current command UI explicitly supports two active companions; validation
rejects a conflicting active-limit setting rather than silently hiding slots.

`tests/content_validation_checks.gd` has 72 checks, included in the full suite.
It mutates independent in-memory registry copies and confirms live content remains
unchanged. Coverage includes NaN/infinity/negative values, malformed nested data,
missing rules, wrong Resource classes, duplicate registration, repeat/repair
behavior, damaged animation sources/coordinates/sequences, affix IDs, type-chart
rows, boss phases and positive extension cases for a new element and trainer slot.
Authored cooldowns/status durations and charge/stack counts must also fit the
existing save schema's limits; finite but unpersistable values are rejected.

The full test script additionally injects an invalid windup only into a subprocess's
memory, then runs the real validation scene. That process must exit 1 and report
invalid content; a fresh process must exit 0 and report valid content. The failed
report is retained separately at `build/content-validation-invalid.json`; no authored
Resource file is changed by this negative test.

Native `tests/render_validation.tscn` verifies valid, invalid and repaired reports
in the Content Viewer. `build/validation-viewer.log` has all three assertions true;
the invalid screenshot was inspected and names the exact ability file and field.

Limits: this is structural/reference/range validation, not an art, animation-facing,
balance or performance acceptance test. It does not certify arbitrary future
fields, localization completeness, new AI profiles or procedural biome content.
Runtime, rendered and journey tests remain necessary.
