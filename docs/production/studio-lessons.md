# Studio lessons (Director, 2026-11-06)

What four games (Relay Rounds, Hundred Demon Night, Egg Garden v0.1 to v0.5, Neon Spire) taught the studio. Every thread on a new game reads this before its brief. Each lesson names where it came from.

## Product

- **The owner judges by look and feel first.** "Not good enough" (Relay Rounds) and "make the models better" (Egg Garden HD pass) both came after the systems were solid. Budget art quality from day one: a style test of three hero assets before any feature work.
- **Child safety is a design input, not a review step.** The owner's rules: no stealing or taking mechanics, trading limited so children cannot be scammed or made sad, no paid randomness, filtered text, no countdown pressure. Write them into the GDD's first page.
- **Never let a player lose something they earned.** Unclaimed login rewards expiring at rollover was a QA major (GARDEN-056 M1); the fix pays earned rewards automatically. Apply the same test to every timer.
- **Meta that worked:** collection with an Index and milestone rewards, weekly and monthly login tracks with exclusive items at the end, weather or event modifiers, a solo mini-game and a 3-to-6 player mini-game, followers that show a favourite off in the world, pet names. Players see rarity, so tiers must look and sound different.

## Engineering

- **Pure rules in `src/shared`, Lune-tested; servers thin.** Every economy and safety bug QA found was either in a pure module with a missing test or in server glue around a yield.
- **Anything that writes two players' saves needs a ledger, idempotent ids and a heal at load,** and QA must attack crash and race paths (Egg Garden trading: B1 void-copy duplicate, M1 ledger read failure, M2 undo race). Prefer designs that never write two saves at once.
- **Every yield in a request path is a race.** Lock what the request is about to change before yielding; re-check after.
- **Text from players:** TextService filtering, fail closed, never shown unfiltered, never in announcements.
- **One UI kit (UiKit.luau) from the start;** retrofitting it in v0.5 meant rewriting Menu and Hud. Size text with a minimum (12 px effective on an 844 x 390 phone), tags with a cap.
- **Schema:** one version bump per release, sanitize keeps every older save field for field, a newer-version save loads read-only.

## Art pipeline

- **Blender headless works; quality comes from the standard, not the tool.** Full RGB textures (never a 256-colour palette), 192-sample blurred AO baked into the texture, smooth fused bodies (no prisms), one shared cute face (glossy eyes with two catchlights, blush), 6,000 tris per creature, one Blender process at a time. See `tools/blender/garden/README.md` "Creature standard (HD pass)".
- **Prove the standard on two assets, then parallelise artists by file.** Review every contact sheet before upload.
- **Uploads:** the upload workflow runs per game with an asset list; the decal image id rarely resolves from CI and the game resolves it at runtime; 26 assets fit in one run only with a short poll. Every asset gets a `docs/assets/register.md` row before use.
- **No skeletal animation yet:** creatures bob, hop and turn through code. Design games that look alive without rigs, or budget an animation pipeline as its own task.

## Process

- **The owner merges every PR by hand and auto mode blocks Claude from merging and from publishing:** batch work into as few PRs as possible and one checkpoint per release.
- **Independent QA catches real bugs every time** (v0.2: impossible jumps; v0.4: trade duplication; v0.5: lost rewards). Keep QA separate from the fixer and re-review the fixes.
- **Integration in Studio after every merge of server and client branches:** both sides tested alone missed the follower blocking the camera and the tag overlap.
- **Machine limits:** about 15 GB RAM; Roblox Studio windows from finished agents hang on save prompts and must be closed (Stop-Process); background shells get killed under memory pressure.
- **Usage limits stop agents mid-task:** their work is saved; resume them with a message instead of starting new ones.
