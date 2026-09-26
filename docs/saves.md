# Save persistence and failure behavior

The default file remains `user://journey.json`, version 3, with `.bak` for the
previous valid generation. Both paths are independent of the selected language.
Fixtures override SaveStore.storage_path or pass explicit paths; they never need
to damage the real journey to exercise recovery.

Version 3 now optionally stores trainer facing and `party_state.placements`, keyed
by active creatures' persistent IDs. Each placement contains position and facing.
Shape validation rejects malformed/nonfinite coordinates, zero/oversized direction
vectors and excess placements; content preflight rejects unknown or reserve IDs.
Older v1/v2/v3 files without these optional fields remain readable.

Validated arrival data reaches GameWorld before its actors are created. The
trainer's restored position is established before companion spawning; companions
start at their saved collision-clear positions with animation origins/facing already
initialized. Revised geometry resolves blocked positions to nearby clear ground,
falling back near the trainer when no local point exists. Legacy companions without
positions spawn near the restored trainer, including HOLD. Loading reconstructs
actors without firing summon rewards or swap-in events; ordinary area arrivals and
actual swaps retain their existing gameplay behavior.

Load order:

1. Open the file and reject sizes over 8 MiB before parsing JSON.
2. Validate the JSON tree: at most 100,000 visited values/keys, depth 32,
   10,000 entries per collection, 4,096 characters per string and an aggregate
   text/structure budget. Reject nonfinite values and unsupported Variant types.
3. Validate known fields, including combat timers, integer item level/rarity,
   string IDs, bounded affixes/modifiers, defined stats and modifier operations,
   and signed 64-bit RNG strings. Migrate v1/v2 and fill missing legacy item
   presentation fields. Missing legacy item IDs derive deterministically from
   serialized content and its saved location; migration does not mutate input.
4. Preflight a playable journey against loaded content and ownership rules.
   Reject duplicate creature identity, invalid active indices, unknown required
   species/items/area, invalid equipment slots/categories and nonboolean quests.
   These checks precede replacement of the current party, inventory or world.
   Nonempty item instance IDs must be unique across inventory, stash, trainer
   equipment, every creature's held item and ground drops in every saved area.
   Duplicate ownership rejects the complete candidate; backup recovery uses the
   same rule. Existing explicit IDs are never silently regenerated to hide a duplicate.
5. If primary loading/preflight fails, try the backup with the same checks.
   Successful recovery clears stale error text and reports that the backup was
   used. If both fail, retain the current game unchanged.

The general SaveStore serializer can validate partial fixtures. Main explicitly
passes SavedJourney.valid for full journey loading and writing. Removed optional
ability/status IDs still follow existing normalization rules; missing required
creatures or items cannot silently disappear from an accepted save.

Writes validate first, serialize within the byte limit, write `.tmp`, flush and
check stream status/length. An existing valid primary is copied to `.bak.tmp`
before renaming to `.bak`; a corrupt/content-incompatible primary never replaces
the valid backup. Only then is the new temporary save renamed to the main path.
Failure returns an error and retains committed files where that operation has
not succeeded. This is staged persistence, not a hardware/power-loss guarantee.

The exit button and Window.close_requested both call main.request_exit. A failed
write keeps the game open and paused, with the error visible inside the menu.
A later successful retry saves before quitting. Ordinary save/load results also
appear inside open menus instead of being hidden behind their shade. Autosave
failures are reported even when success notices are suppressed.

Evidence: `tests/save_hardening_checks.gd` adds 35 checks to the main suite,
including exact before/after state on rejected loads, byte-preserving temporary
write failure, oversized-file recovery, preserving the recovery copy on repair,
metadata bounds, legacy normalization and failed-exit retry. `tests/exit_runtime.tscn`
exercises actual keyboard activation of the exit button and separately emits a
window-close request. In each native run it first forces a write failure, verifies
the still-live paused game, captures the visible error, then retries a valid path
and checks the saved party/currency before exit. A process-frame deadline fails if
successful saving does not terminate the fixture. Both modes also run headlessly
from `tools/test.ps1`.

Native evidence: `build/exit-menu.log`, `build/exit-window.log`,
`build/save-exit-{menu,window}-failed.png`. This does not certify physical power loss,
disk removal, future content migrations or long campaigns. Those require additional
acceptance. Global item ownership validation now includes all serialized area snapshots.

`tests/arrival_checks.gd` adds 25 arrival regressions to the full suite, covering
first-tick position/facing, animation origins, HOLD, repeated-load summon-shield
prevention, ordinary-arrival summon behavior, legacy fields, blocked geometry,
downed companions and malformed/foreign placements. The standalone native
`tests/arrival_runtime.tscn` reports all 25 true in `build/arrival-native.log`;
`build/arrival-{restored-hold,legacy-near-trainer,downed}.png` records actual renders.
The first two were visually inspected. The full journey comparison additionally
requires party placement/mode/cooldown state and trainer position/facing to survive.

## Item identity and transactions

World item generators prefix new instance IDs with a deterministic hash of their
stable area ID; starter inventory uses its own scope. Equal seeded roll streams in
different areas retain equal gameplay properties but produce distinct instance IDs.
This adds no random draw. Existing IDs and legacy location-derived IDs are retained.
Area scopes remain stable over travel/load, and saved loot RNG resumes the exact
next generated item including ID and affixes. This does not claim mathematical
collision impossibility for random IDs; preflight rejects any duplicate ownership.

Inventory add rejects missing/duplicate IDs. Transfers reject self/destination
conflicts and commit both containers before either change signal. Equipment exchange,
unequip and ground pickup similarly update all owners before inventory observers run.
A full inventory can exchange equipment because the incoming item frees the return
slot; a failed transfer/unequip keeps its original owners. Silent add/exchange are
used only while those coordinated session/world operations are being committed.

`tests/item_ownership_checks.gd` contributes 31 checks to the full suite. They cover
all ownership locations, duplicate primary/backup behavior, unchanged valid save
bytes on rejected writes, deterministic migration of identical legacy items,
RNG continuation, full-pack exchanges and save snapshots observed inside change
callbacks. Before-fix failures are retained in `build/item-ownership-before.log`
and `build/item-equipment-before.log`; the focused passing run is
`build/item-ownership.log`. Tests use isolated user-file names, not the player's save.

## Composed build values

Individually valid item bonuses can exceed a probability or duration domain when
combined. StatsComponent now clamps the final critical chance to [0,1], including
overrides and equipment previews, without rewriting the modifier contributions.
Status application and refresh cap the composed definition/source/ability duration
at StatusData.MAX_DURATION (3600 seconds). Schema validation, restore, authoring
checks and ability descriptions use that same duration bound. No save-version
change or weaker input validation is needed: the actual live state now satisfies
the existing format, rather than being silently altered only while saving it.

`tests/combat_bounds_checks.gd` adds 26 checks. A generated item with two valid
large bonuses is equipped through the session, applies a real critical hit/burn
to an authored enemy, then saves and loads through the normal session path. The
restored periodic tick matches its captured guaranteed-critical damage and advances
the RNG exactly once. Unequip restores current chance without changing the old
effect's source; reapplication uses the current source and ordinary duration.
Zero/100-percent random endpoints, final-modifier composition, actual item preview
and status refresh are checked too. Tests use `user://combat-bounds-check.json` and
remove only their own test files afterward. Before-fix evidence records 13 failures
in the initial 17-check reproduction (`build/combat-bounds-before.log`); the expanded
26-check pass is `build/combat-bounds-after.log` and is included in the full suite.
