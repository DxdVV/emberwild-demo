# Player interface localization

The language selector is the first setting. Russian and English apply immediately
and persist in `user://settings.cfg`. Only Window.title changes; the application
name and user-data directory stay stable, so changing language does not move saves.

Authored content strings are registered in `tools/build_content.py`; mechanic
inspection strings in `tools/inspection_strings.py`; menus, HUD, notifications and
save errors in `tools/ui_strings.py`. All feed `resources/strings.csv` and Godot's
native translation importer. Do not edit generated CSV alone. Regenerate with
`python tools/build_content.py`, then let Godot import. The generator rejects
duplicate keys, empty translations and differing format placeholders. Translate
whole formatted sentences instead of concatenating translated word fragments.

Settings validates locale IDs before changing TranslationServer. HUD defers the
translation refresh, rebuilds the current panel from its Callable and refreshes
area/party/ability text. It does not reload the world or advance paused combat.
Transient old-language notices are dismissed; new notices use the selected locale.
If writing settings fails, the new language remains active for the session and an
error appears inside settings rather than behind the modal.

ModalFocus reads current visible enabled controls when Tab is pressed, including
expanded or rebuilt rows. Shift+Tab reverses the cycle, closing is last, and
ScrollContainer follows focus. Input capture receives Tab unchanged; an open
PopupMenu retains its own keyboard handler. Initial focus waits for layout, with
a generation check to reject obsolete requests from replaced menus.

The status inspector includes a focusable heading for every current effect and
shield, sorted in live badge order and marked with the same pixel glyph. A live
badge click supplies a weak preferred focus after layout; missing/expired entries
fall back to the owner picker. Language rebuilds preserve the selected effect.
The same weak-state description provider serves native mouse hover and contextual
keyboard focus. UI inspection never advances combat; Escape returns to gameplay.
The clicked strip's state identity resolves its owner, even when a party swap
preceded the next 10 Hz HUD refresh.

`tests/status_keyboard_runtime.tscn` passes 28 headless and native checks with real
key/mouse events: pause-menu access, all eight current effect/shield entries,
forward/backward focus, scrolling, descriptions, owner-popup selection, exact
clicked-effect focus, Russian/English rebuild, same-frame party swap, replacement
menus, expiry fallback and resumed movement. Evidence is in
`build/status-keyboard-{headless,native}.log`, with inspected
`build/status-keyboard-{burn,wet,companion,english}.png` images. Delayed descriptions
wait process time, not a fixed callback count. `tools/test.ps1` includes this fixture.

Evidence: eighteen checks in `tests/localization_checks.gd`, included in the main
test runner, cover persistence, invalid IDs, write failure, translated visible
text, window title, HUD refresh, paused state continuity, Tab traversal, expansion,
binding capture and Enter activation. `tests/render_localization.tscn` additionally
uses real InputEventKey events through the window input path to open/select the
language dropdown. It renders nine player screens, the world and lower binding
rows, checking screen bounds and focused-control visibility. Run it natively:

```powershell
& 'tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path . --quit-after 900 tests/render_localization.tscn
```

Screenshots are `build/localization-*.png`; the completion marker must say
`LOCALIZATION COMPLETE verified=true`. Headless tests alone do not verify layout.
The fixture uses a separate settings path and restores the active locale.

Scope: player menus, HUD, content, combat notices and save errors. Developer console
commands/output and editor tools retain technical text. Contextual focus tooltips
cover current party/item/ability/status inspection. Screen-reader behavior,
gamepad support, arbitrary future-content text lengths and linguistic review
remain separate acceptance work.
