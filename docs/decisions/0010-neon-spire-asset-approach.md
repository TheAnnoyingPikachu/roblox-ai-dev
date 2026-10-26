# 0010: Neon Spire asset approach

Date: 2026-10-26
Status: Accepted (2026-10-26: SHANNON said "begin making the cyberpunk tycoon"; the recommended answers in the production plan, section 9, are adopted) for SHANNON's approval (per-game asset approval; CLAUDE.md rule 9). Options in `docs/game-design/game5-art-bible.md` section 9.

## Options

- **A. Primitives and procedural:** code-built parts with built-in materials (SmoothPlastic, Glass, Neon, ForceField, Metal), particles, beams and SurfaceGuis. No uploads.
- **B. Roblox AI mesh generation:** hero props generated in Studio on SHANNON's account, as Relay, Night and Garden did. Each gets a register row before use.
- **C. Blender:** a custom modular kit with PBR textures, made by a human in Blender or by headless Blender scripts and uploaded through an Open Cloud Assets key.
- **D. Creator Store free models:** third-party models.

## Proposed decision

- Use **A** for all architecture (towers, lobby, plaza grid, streets, backdrop), UI and effects.
- Use **B** for at most 14 hero props (art bible section 10), each with a primitive fallback after three failed tries.
- Allow at most **two uploaded 2D assets** made for this game (a tileable window texture for the backdrop and a UI icon sheet), uploaded by SHANNON in Studio and registered.
- **Defer C.** Revisit only if the M2 screenshot gate fails on prop or facade quality. Adopting it later needs an amendment, and an Assets upload key is a credential change (rule 7).
- **No D**, except Roblox-owned engine content and Roblox-licensed audio from the Creator Store, as before.

## Why

Cyberpunk architecture is mostly boxes, glass and glowing strips, which primitives do well and which agents can build, diff and review in Git. AI mesh generation has a working flow in this studio and covers the organic and vehicle shapes primitives cannot. Blender adds the highest ceiling but also a human-in-the-loop step, binary files that are hard to review, and a new credential; it is not needed to pass the first-screenshot test.

## Consequences

- SPIRE-007 cannot start hero props until SHANNON approves this record.
- Every mesh, texture, track and sound has a `docs/assets/register.md` row before use.
- Part and performance budgets in art bible section 12 apply to everything built under A.
