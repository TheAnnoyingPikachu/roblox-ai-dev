# 0010: Neon Spire asset approach

Date: 2026-10-26
Status: Proposed for SHANNON's approval (per-game asset approval; CLAUDE.md rule 9). Options in `docs/game-design/game5-art-bible.md` section 9.

## Options

- **A. Primitives and procedural:** code-built parts with built-in materials (SmoothPlastic, Glass, Neon, ForceField, Metal), particles, beams and SurfaceGuis. No uploads.
- **B. Roblox AI mesh generation:** hero props generated in Studio on SHANNON's account, as Relay, Night and Garden did. Each gets a register row before use.
- **C. Blender:** a custom modular kit with PBR textures, made by a human in Blender or by headless Blender scripts and uploaded through an Open Cloud Assets key.
- **D. Creator Store free models:** third-party models.

## Proposed decision (revised 2026-10-27)

- Use **A** for the tower shell, lobby, plaza grid, streets, city backdrop, UI and effects. These are built on each client from replicated state with level of detail (`docs/architecture/spire.md` section 5), so they stay procedural.
- Use **C** for at most 14 hero props (art bible section 10) and the 7 module models with their level variants (GDD C4), in `tools/blender/spire/`, reusing the Night kit, build runner, export conventions (1 unit = 1 stud, origin at base centre, one baked 1024 PNG), tris budgets and `upload-assets.yml` (generalised to take a game folder).
- Use **B** only as a fallback for a prop the Blender scripts cannot make readable after review, and A as the last fallback.
- Allow at most two other uploaded 2D assets (a tileable window texture for the backdrop and a UI icon sheet), registered.
- **No D**, except Roblox-owned engine content and Roblox-licensed audio from the Creator Store, as before.

## Why

Cyberpunk architecture is mostly boxes, glass and glowing strips, which primitives do well, and the tower must be rebuilt live from state. Props and machines are where the look needs real shapes. The first draft (2026-10-26) recommended AI mesh generation and deferred Blender because no Blender pipeline existed. NIGHT-007 and NIGHT-008 (merged 2026-10-27) built one: scripted, headless, reviewable, with an upload workflow behind a human-set environment. That removes the cost that made Blender the deferred option, and gives one consistent style across props.

## Consequences

- SPIRE-007 cannot start hero props until SHANNON approves this record.
- Uploads run only through the human-set `assets` environment (CLAUDE.md rules 6 and 7); the creator account must own the Spire experience, because models load with InsertService.
- Every mesh, texture, track and sound has a `docs/assets/register.md` row before use.
- Part and performance budgets in art bible section 12 apply to everything built under A.
