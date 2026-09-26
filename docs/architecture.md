# Runtime boundaries

- `SpeciesData` is shared immutable species configuration. `CreatureInstance` owns stable identity, progression, equipment and `CombatState`. The session owns the trainer's `CombatState`. Neither state depends on a scene node remaining alive.
- `Actor` binds persistent stats, health, energy, statuses, triggers and cooldowns to temporary ability execution, presentation and an optional shared AI controller. Wild/hostile/companion creatures share that implementation. Detachment cancels the current cast but retains its already-paid energy and cooldown.
- `DamageSystem` is the single numeric damage pipeline; type chart, status definitions, item affixes and boss phases are Resources. AbilityController owns windup, activation and recovery; a shared cooldown component owns charges.
- StatsComponent compiles modifier-source terms when sources change. Base values, level and scaling remain live inputs to each query. Replacement preserves source order for overrides; removal exposes any earlier override. Callers supply modifiers through set_source/remove_source; source arrays are deep-copied.
- `TraitData` drives individual traits and species passives. CombatState combines named stat/trigger/ability-modifier sources, so changing equipment cannot erase inherited effects. Trigger keys include source identity and retain legacy unprefixed cooldown compatibility. Status duration and recharge changes use stats, without species-specific branches.
- `SpeciesData.ability_unlocks` defines level gates. Progression validates each individual's basic/command slots on load and preserves eligible choices through evolution. Commands and HUD read the individual loadout. Changing a selection does not clear cooldowns.
- `PartySystem.evolve` delegates persistent changes to Progression and refreshes the existing active actor's SpeciesData/presentation. It does not reload the area or resummon the party. ActorPresentation rebuilds only the animation binding, preserving visual direction and elapsed defeat time; health/status signals remain connected once. Reserve evolution uses the same persistent path. Optional `SpeciesData.portrait` supports an editor-native Texture2D/AtlasTexture, with the existing sprite-cell atlas as fallback.
- `AreaData.layout` owns an authored AreaLayout Resource with paths, clearings, props, lights, encounter positions and interactions. Terrain passes bounded geometry arrays to the ground shader; minimap and world interactions read the same data. SpawnDirector consumes stable encounter IDs and explicit levels/positions, including elite/boss definitions. LayoutValidator checks data and footprint clearance; runtime traversal checks connectivity and physical movement. See `docs/area-authoring.md`.
- Projectile, cone and nova delivery use common targeting and `AbilityResolver`; reactions are evaluated per victim, and secondary chains suppress recursive triggers. Knockback is a separate decaying impulse applied after AI steering.
- `TooltipPresenter` derives trait/item mechanics and ability damage/recharge from runtime data and shared combat calculations. Party details and HUD use the same presenter; the shown damage explicitly excludes target defense, resistances and critical hits.
- `ContextTooltip` is one click-through HUD overlay for item actions/text, creature portraits/cards, held equipment and command descriptions. Controls supply a Callable; only the current hovered/focused source is evaluated at 10 Hz after a short delay. GUI focus signals cover consumed Tab events; labels/portraits draw a visible focus outline. The weak source, modal ownership, clipped ancestor bounds and popup/rebinding checks prevent stale or covered owners from showing descriptions. Placement uses the readable UI viewport. HUD command providers resolve the current active slot on every refresh, so swapping companions or changing stats updates an already open description. Existing status-badge native hover and paused inspection remain separate consumers of the same presenter.
- Ground loot uses that same contextual overlay and item presenter. WorldLabels retains rectangles only for successfully drawn drop names, associates each with its actual item Dictionary, and reuses one child hit Control for the pointer. It validates world identity, label revision, filter/reveal state, array bounds and item reference before describing a drop. Removing an earlier array entry therefore cannot silently retarget old hover data. Item/world identity restarts the tooltip delay when reusing the control. A fallback resolves labels revealed under a stationary pointer without overriding real UI controls; ordinary movement/reveal keys preserve mouse modality. Rendering placement, rarity order, the candidate budget and nearest-item pickup behavior are unchanged.
- Item comparison uses an independent StatsComponent source copy and the same ability-modifier composition as CombatState. Held-source replacement preserves actual equip ordering; trainer comparisons replace only their slot. Preview cannot spend energy, alter health, modify charge queues or consume RNG. Unequip checks inventory capacity before changing ownership and preserves health ratio.
- Status inspection reads persistent CombatState entries, including reserve creatures and retained periodic source snapshots. Damage previews call DamageSystem.calculate with current target defense/types and the snapshot attack; they do not call the damage/critical-roll path. Tick counts include expiry-boundary ticks. UI labels state that shields and blocking are excluded. Inspection pauses combat and reads the current state rather than ticking it itself.
- `GameWorld` coordinates one area. `SpawnDirector` places authored packs with seeded variation. `WorldSnapshot` preserves encounter IDs, drops and separate RNG streams. The session owns party, inventory, stash, equipment and area transitions.
- `TargetingSystem` validates hostility and target life for both AI and commands. `WorldNavigation` uses native AStarGrid2D profiles for body radii, 16-unit cells and real prop collision footprints expanded by body radius plus a small margin. Area setup prebuilds normal/boss profiles. Direct paths and smoothed segments must clear the expanded geometry. Legal positions in conservatively blocked cells connect to visible free nodes; unreachable goals return a reachable partial route or no route.
- ActorBrain owns its route and bounded repath timer; it reacts to goal displacement and geometry revisions without searching every physics tick. Waypoint approach caps velocity to avoid overshoot. Companions stranded far away recover to a collision-clear nearby point with a retry cooldown; HOLD deliberately disables distance recovery and ranged retreat. Party summoning uses the same safe-point query. Recovery only changes placement and movement, never persistent combat state.
- `CharacterAnimation` advances actual frames from travelled distance. `CreatureAnimation` uses data-defined frame sheets. Both consume gameplay state; neither decides hit timing.
- Boss telegraphs commit a direction when their ground markers are created. ActorBrain keeps that direction and zero steering through windup/recovery even after losing the target. CreatureAnimation reads it before normal target-facing logic. GroundHazard counts no elapsed time during the physics tick in which it was created, so its delay and the source's cast countdown share the same start; damage remains exclusively in gameplay. A small boundary tolerance avoids floating-point subtraction leaving the visual windup active at the first impact in a multi-wave phase. Native damage callbacks verify release-pose alignment.
- Trainer combat clips share SpriteAnimationData with walking/defeat: directional and named supplemental atlases supply windup/release/hurt/dodge frames with separate scales. Ability phase progress selects cast poses; dash uses the gameplay-locked direction and remaining duration. Three-pose recoil has a restartable presentation timer independent of the shorter damage flash; recovery clears it. Moving attacks and hits retain walking frames; footstep distance excludes dodge and teleport displacement. Generated combat frames retain fixed cell pivots to preserve torso lean, while alpha baselines keep ground contact.
- `SpriteAnimationData` resolves per-frame source textures/scales and direction-specific clips with a base-clip fallback. Ordinary creatures retain their six original side frames and add front/back frames from separate atlases. CreatureAnimation retains visual facing through idle and defeat, faces a live target for planted casts, and preserves distance-based walking during moving casts. Generated sources remain immutable; registration derives crop/anchor metadata and validates boundaries.
- All five companion species use six-pose falls from supplemental `defeat` sources in the same animation Resource. CreatureAnimation clamps fall time at its configured duration and makes repeated visual fall requests idempotent. ActorPresentation maps normalized fall progress across species refresh, so completed and interrupted falls stay at the corresponding stage even when durations differ. Flying animation data specifies `death_ground_phase`; Volt reaches ground by its third pose. Runtime and content preview share the vertical-offset calculation. None of these presentation transitions advances combat or removes persistent individuals.
- Guardian uses six collapse poses in every direction: front/back from its directional atlas and side/mirrored side from a supplemental atlas. Its configured visual duration is 0.8 seconds. Hostile corpse cleanup uses a pausable SceneTreeTimer, retaining the existing 1.5-second game-time delay. Death rewards are resolved immediately; pausing does not remove the body while its presentation is frozen.
- `CameraController` owns follow and impulses. All combat visuals stay in a common low-resolution viewport. UI lives on its own CanvasLayer.
- GameWorld's ground loot is drawn by one `LootMarkerBatch` MultiMesh using the existing filtered drop list. Beam/coin geometry, ordered instance positions and rarity colors are presentation-only; pickup, labels and saves still use world drop dictionaries. Existing redraw invalidation updates the reusable mesh, and an empty population clears its instances. Native raster comparison covers lighting, fractional positions and overlapping rarities.
- Defeat immediately pauses simulation. ActorPresentation temporarily processes only the trainer's authored falling frames while paused, emits completion and stops processing at the final pose. HUD waits for that completion through a weak actor reference; recovery or a world replacement invalidates pending UI work. The renderer never revives actors or advances combat state.
- Audio binds explicitly to the active world viewport. Spatial voices are capped and reused; repetitive same-sound bursts are rate limited. Cosmetic audio RNG is separate from gameplay RNG.
- `AbilityData.audio_profile` references a shared `AbilityAudioData` Resource with cast/impact sample banks and gains. GameWorld routes actual release and resolved damage to those profiles; shield absorption also gets contact feedback, blocked damage stays silent, and periodic damage uses a quieter fallback. GroundHazard emits its heavy impact at activation even with no victims. Profile lookup contains no species/element branches; nested bank/gain validation runs through the content validator. Existing per-cue throttling and bounded pooled voices apply to every profile.
- CharacterAnimation emits two footfall contacts per six-frame gait using the same resolved travel distance as its poses. ActorPresentation routes these to Audio; no input timer or gameplay-state mutation drives sound. Audio cue entries contain sample arrays and skip the previously chosen sample when alternatives exist. The three original generated boot/earth contacts have a quieter gain; every pooled voice resets gain when reused for another cue. This is currently trainer footfall audio, not material-specific surfaces or a complete creature Foley catalog. Sources and verification: `docs/audio.md`.
- `InputBindings` owns serializable keyboard/mouse assignments and updates only the game's InputMap actions. Command shortcuts use exact modifier matching; both companion slots have independent actions. BindingEditor captures input while paused, blocks gameplay shortcuts and retains an Escape fallback. Settings validate/restore preferences separately from journey saves and commit with a temporary file plus backup.
- Settings applies the validated locale to TranslationServer and the window title. HUD rebuilds only its current panel through a retained Callable after a translation change, refreshing area/party/skill text without recreating the world or advancing combat. A failed language write remains visible inside settings. All player menu/HUD/notification strings use stable keys; the content generator checks matching format placeholders between languages.
- ModalFocus collects currently visible, enabled controls on each Tab event, so expanded creature details and rebuilt binding rows participate immediately. The close button is last in the cycle; capture mode and open native popups keep their own input handling. Initial focus waits for Container layout and uses a generation guard against replaced menus. ScrollContainer follows focus; closing releases menu focus.
- `LootFilter` is a presentation/pickup policy, never a world-state mutation. The same policy selects visible drops and eligible pickups; a held reveal action bypasses it temporarily. WorldSnapshot stores all drops. `WorldLabels` projects positions from the coarse world viewport into the UI viewport, prioritizes the current pickup and avoids overlapping text without changing simulation coordinates.
- WorldLabels caches filtered drop indices in stable rarity order until area/drop/filter/reveal changes. Text widths are bounded and invalidated on translation changes. Per-draw 32-pixel horizontal bands accelerate overlap checks while retaining the same placement offsets, screen bounds, priority and 64-candidate budget. Camera movement still redraws the projected labels. Visible HUD controls reserve their actual bounds plus four pixels, transformed into label coordinates and indexed across every touched band. Weak references and geometry/minimum-size/visibility/exit signals invalidate this cached geometry and immediately clear stale hover targets. Empty text and hidden/removed controls reserve no space. This intentionally changes placement and may reduce the number of visible names while a notification occupies the scene; filtering and pickup are unchanged.
- `StatusStrip` reads persistent CombatState through a weak reference on the HUD's existing 10 Hz refresh. It draws shield amount, remaining time and stacks without ticking state or sampling RNG. Owner replacement updates the weak reference; hidden/removed/distant targets clear the display. Its native tooltip uses the shared TooltipPresenter and updates while open; clicking delegates to the paused inspector. StatusData owns validated 7×7 glyph rows, and StatusGlyph draws integer-aligned contiguous pixel runs in both world and UI viewports. No per-status Controls or per-actor callbacks are introduced.

## Collision bits

1: solid world; 2: actor physics bodies; 3: hurtboxes; 4: projectile hitboxes; 5: reserved interactions. Bodies collide with the world. Damage uses distinct Area2D hitboxes/hurtboxes, never body name matching. Dodging grants a timed health invulnerability window.

## Combat persistence and time

Active actors tick their own state once per physics frame; PartySystem ticks only reserve states. Reserve cooldowns, energy regeneration and effects continue in game time, including damage and defeat. Menu pause freezes both. Unloaded encounter snapshots are frozen until revisited; the game does not simulate real-world/offline elapsed time.

Save version 3 stores health ratio, shield, invulnerability, energy, cooldown charge queues, global lockout, statuses with next-tick time, trigger lockouts and dodge cooldown. It also stores party mode/switching lockout and encounter boss phase/special timer. v1/v2 migrate without inventing missing combat history. Loading a defeated trainer presents defeat recovery rather than silently healing. Only explicit rest/recovery resets battle state.

Optional v3 active-companion placements use persistent IDs; trainer/companions
also retain facing. Main passes validated arrival data into GameWorld construction,
which restores the trainer before spawning companions at collision-clear saved
positions. Legacy placements fall back near the restored trainer. Reconstruction
suppresses summon triggers and swap-in events, avoiding load-created rewards.

Periodic effects snapshot source ID, faction, attack and critical chance at application (latest application owns a refreshed stack). Target defense/types remain current. Damage still uses DamageSystem, even when the source has despawned or the target is in reserve. Periodic hits do not recursively fire on-hit triggers. Expiration counts only valid intervals and a tick exactly at the duration boundary. Level-up/evolution refresh stats while preserving health ratio and timers.

Save validation rejects malformed nested combat records, nonfinite values, fractional indices and zero recharge intervals before constructing runtime state. Unknown removed ability/status IDs are skipped during restoration.

SaveLimits bounds file bytes before parsing and tree depth/count/text before duplication or serialization. SaveStore then validates scalar/item metadata and migrates missing legacy item defaults. SavedJourney performs content and ownership preflight before main replaces any live state: creature identities, active indices, required species/items/area, held versus trainer categories, trainer slots and quest flags. Missing required content rejects the whole journey instead of silently discarding records and shifting active slots. Optional removed abilities/statuses retain their earlier normalization policy.

Writes check flushed stream status/length, stage the backup separately, and only rotate a structurally/content-valid primary over the previous backup. A failed temporary write preserves both committed files. Recovery exposes a flag so HUD distinguishes backup restoration. Main routes both window close requests and the menu exit through successful save; failure retains the paused game with a visible panel notice. SaveStore.storage_path is overridable by fixtures without touching the player's journey file. See `docs/saves.md` for limits and evidence.

## Loot and combat-loop verification

StatsComponent bounds the final critical probability to [0,1] after compiling all
sources, preserving original modifier contributions for removal and equipment
previews. StatusComponent composes definition, source-stat and ability bonuses
through one duration function, capped by StatusData.MAX_DURATION (3600 seconds).
The authoring validator, combat save schema, runtime restoration and ability
description agree with that limit. The live state itself is bounded; serialization
does not silently shorten an effect or rewrite its source. Direct and periodic
critical rolls honor a guaranteed 100% chance even at the upper random endpoint,
while consuming exactly one seeded random draw in each path.

RulesData.loot_tables explicitly declares common, elite and boss loot. Weighted
entries support item, weight and optional level/rarity overrides; source chance
controls whether a drop occurs. Content validation rejects malformed tables and
references. ItemGenerator retains its seeded RNG; registry enumeration no longer
determines drop eligibility.

ItemGenerator uses a stable identity scope for each area and a separate starter
scope. It preserves the existing random draw sequence; only new instance IDs gain
the scope prefix. SavedJourney claims every owned item ID once across containers,
equipment, party and saved-area drops. Inventory transfers and session/world item
operations finish ownership changes before notifying observers, including full-pack
equipment exchanges and pickup. Details and regression evidence are in `docs/saves.md`.

GameWorld keeps a live GroundHazard registry whose registration/removal follows
the node lifecycle. Companion brains leave hostile pending circles through a
bounded safe-point search and cached physical navigation, honoring HOLD. Friendly,
dead-source, removed and activated hazards cannot cause a new escape. Failed
endpoint searches retry at most every 0.2 seconds; evasive movement uses the normal
walk cycle without teleporting.

Companion formation follows active party slots. Repath staggering derives from
spawn coordinates and faction, avoiding engine object-allocation IDs in these
tactical decisions. This does not promise deterministic full-game replays.

Navigation can connect a clear sub-cell edge strip to its grid through a bounded
collision-checked bend. It still rejects starting points inside obstacles. Save
serialization omits only redundant ready cooldown charge entries, so a played
journey has a canonical save/load representation. Scenario evidence and limits:
`docs/journey-verification.md`.

## Current limits

Content loading and authoring checks are documented in `docs/content-validation.md`.
The registry rejects invalid Resource classes and duplicate IDs before insertion;
semantic validation is repeatable and split across field, gameplay-rule, animation
and layout validators. A standalone command writes a machine-readable report and
fails on invalid content. The Content Viewer exposes the same loaded-data checks.

Area transitions are synchronous after a fade; the small scene does not need streaming. Spawn chunks are authored and seeded rather than a procedural world. No multiplayer or endgame implementation. Current progression, trait pool and economy deliberately cover only the first slice. Expanded release content follows acceptance of that slice.
