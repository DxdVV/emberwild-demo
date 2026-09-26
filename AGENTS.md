# Emberwild

Read `docs/technical-spec.md` and `docs/game-design.md` before changing architecture.
Godot 4, GDScript, native scenes and Resources. Game state must not depend on presentation.
Stable IDs in saves; seeded RNG per system; no species-specific combat branches.
Keep systems small and composable. Validate content and run headless tests after changes.
Current implementation and outstanding acceptance work are tracked in `docs/progress.md`.
The playable demo checkpoint and remaining work are described in `docs/demo-milestone.md`.
Do not add third-party reference images to the repository or release archive without confirmed rights.
The three cartridge-style reference images and generated-art prompt histories were excluded from the public repository. Do not restore them from private archives into public commits.
For another history cleanup, build an audited root commit and publish it to a new repository. Deleting files in a later commit or force-pushing does not ensure old GitHub objects disappear. On Windows, moving a hidden `.git` directory into an existing destination can nest it unexpectedly; an orphan branch avoided that local migration failure.
