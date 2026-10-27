# Neon Spire: production plan (v0.1)

Status: draft for SHANNON (SPIRE-001). Companion to `game5-gdd.md`, `game5-art-bible.md`, `docs/architecture/spire.md`, decisions 0009 and 0010. Task files: `studio/tasks/SPIRE-*.json`.

## 1. How this plan is built

- **Trust the pipeline first.** Bake Rush published successfully and still showed a baseplate. Nothing about Neon Spire is published until a published build provably matches its commit (M0).
- **Fun before pretty.** The build loop is proven in a greybox (primitives, no art pass) before any art spend (M1 gate).
- **Polish is planned, not hoped for.** The look has its own milestone and screenshot gate (M2); every juice item in GDD K6 is an acceptance check.
- **Evidence, not "went well".** Every gate needs written notes, the build stamp the tester saw, and CI links (CLAUDE.md rule 3). Four earlier games are still `in_review` because their Studio playtests never ran; this plan schedules SHANNON's playtest time explicitly (section 4).
- **No self-approval.** Implementation tasks are verified by the QA role (A15); design and architecture by the director (A01) and SHANNON.

## 2. Milestones

| # | Milestone | Goal | Tasks | Exit gate |
|---|---|---|---|---|
| M0 | Pipeline trust | A staging publish provably runs the commit it was built from | SPIRE-002 | G0: SHANNON joins staging and reads the build stamp matching the commit; the cause of the Bake Rush baseplate is written down |
| M1 | Greybox playable | The build loop is fun with grey boxes: floors, modules, power, ad stacking, plaza grid, income, Hot Data, saves | SPIRE-003, SPIRE-004, SPIRE-005, SPIRE-006 | G1: feel gate (section 4) |
| M2 | Look target | One tower and one plaza at final visual quality, plus the city, rain and UI kit | SPIRE-007 (first half) | G2: screenshot gate (art bible 11) and phone performance |
| M3 | Content complete v0.1 | All 6 lots, all 7 departments, events, meta, social, audio, every juice item | SPIRE-007 (rest), SPIRE-008 | G3: QA review closed; staging playtests on PC, phone and controller; two-client test; rejoin test; MicroProfiler |
| M4 | IPO and longevity | Prestige, Shares, skins and crowns; second-run pacing | SPIRE-009 | G4: second-run playtest |
| M5 | Launch prep | Store page, icon and thumbnails, content questionnaire, production universe check, production publish | SPIRE-010 | G5: SHANNON approves the production run (studio gate 5) |
| M6 | Optional cosmetic monetisation | Only after live data from M5, and only cosmetic | SPIRE-011 | G6: decision record, Roblox policy review, SHANNON's approval for every paid product |

Rough effort (hypothesis, thread-days of build work plus SHANNON's sessions): M0 1 day + one 15-minute SHANNON session; M1 4 to 5 days + one 30-minute session; M2 3 to 4 days + one 20-minute review; M3 5 to 7 days + two 45-minute sessions; M4 2 days + one 30-minute session; M5 1 to 2 days.

## 3. Task map

| Task | Type | Owner → verifier | Depends on | Risk | Output |
|---|---|---|---|---|---|
| SPIRE-001 | design | A06 → A01 | – | low | GDD, art bible, production plan, architecture plan, decisions 0009 and 0010 (proposed), pacing sim |
| SPIRE-002 | infrastructure | A14 → A04 | – | medium | baseplate root cause, build stamp, post-publish check, publish checklist |
| SPIRE-003 | architecture | A09 → A01 | SPIRE-001 | medium | exact signatures, decision 0009 final, `spire.project.json`, CI build, `spire-staging` publish target |
| SPIRE-004 | implementation | A10 → A15 | SPIRE-003 | medium | pure modules, unit, property and balance specs |
| SPIRE-005 | implementation | A11 → A15 | SPIRE-003 | high | server, profiles, lots, loop, prompts, boards |
| SPIRE-006 | implementation | A10 → A15 | SPIRE-003 | medium | menu, HUD, build mode, lift, first-session script (greybox visuals) |
| SPIRE-007 | asset | A10 + A12 → A15 | SPIRE-006, SPIRE-002 | medium | tower kit, plaza items, city, atmosphere, crowd, traffic, Blender hero props and module models, audio, juice |
| SPIRE-008 | test | A15 → A01 | SPIRE-004, SPIRE-005, SPIRE-006, SPIRE-007 | medium | QA and security review, playtest evidence |
| SPIRE-009 | implementation | A10 → A15 | SPIRE-008 | medium | IPO, Shares, skins, crowns |
| SPIRE-010 | release | A14 → A01 | SPIRE-008, SPIRE-009 | high | production universe check, store assets, production publish after SHANNON's approval |
| SPIRE-011 | research | A06 → A01 | SPIRE-010 | medium | cosmetic monetisation proposal and policy review (no paid products created) |

SPIRE-004, SPIRE-005 and SPIRE-006 write disjoint files (architecture section 1) and can run in parallel against the SPIRE-003 signatures.

## 4. Playtest gates

Each gate maps to `studio/gates.md`: G0 is a check on gate 3 (staging), G1 to G4 are gate 4 (playtest), G5 is gate 5 (production).

| Gate | Who | Where | Steps | Passes when |
|---|---|---|---|---|
| G0 Stamp | SHANNON, 15 min | staging, PC | Join; read the build stamp in the menu corner; open F9 and copy the server log line `[Spire] build …`; screenshot the Explorer `ServerScriptService` | Stamp equals the commit; no errors in the log |
| G1 Feel | SHANNON, 30 min | staging greybox, phone and PC | Fresh profile; play 15 minutes; note the GDD K5 timings; rate fun 1 to 5; answer "what did you want to do next?" | Rating ≥ 4 and the K5 timings within 50% of target. Failing twice triggers the GDD T rethink. |
| G2 Look | SHANNON, 20 min | staging, PC and phone | Review the five frames (art bible 11); note fps in the Grid Plaza on the phone | Each frame ≥ 4 or a fix list; phone ≥ 30 fps |
| G3 Content | SHANNON + one tester, 2 × 45 min | staging, PC, phone, controller | GDD S list; two clients (visit, Sky Deck, gate, endorse); leave and rejoin after 10 minutes; play through floor 10 | Every GDD S item has evidence; QA review has no open blocker or major |
| G4 IPO | SHANNON, 30 min | staging, profile seeded to floor 20 by a staging-only test command (never in production builds) | IPO, then play 20 minutes of the second run | IPO screen clear; second run feels faster; rating ≥ 4 |
| G5 Release | SHANNON | GitHub environment approval | Approve the production run for a `v*` tag | Approval recorded; production universe check passes |

Every note records: date, device, build stamp, profile state, per-step pass or fail, console warnings, and a rating where asked.

## 5. Risks

| # | Risk | Likelihood | Impact | Mitigation | Owner |
|---|---|---|---|---|---|
| R1 | **Staging shows a baseplate** (Bake Rush, unresolved): publishes cannot be trusted | Known | High: every playtest note could be about the wrong build | M0 first; section 6 investigation; build stamp and post-publish check | A14 |
| R2 | Ambition outruns the studio: "super detailed and polished" vs four games still awaiting playtests | High | High | Greybox gate before art; cut order (GDD Q); M2 is one tower, not six | A01 |
| R3 | Phone performance with tall towers, rain, crowds and traffic | Medium | High | Client-built LOD (architecture 5.1), quality tiers, budgets (art bible 12), measured at G2, not at the end | A10 |
| R4 | Build mode is fiddly on touch | Medium | High | Card-based building, no 3D dragging; G1 tested on a phone | A10 |
| R5 | Economy runaway or a dead zone mid-game | Medium | Medium | Balance spec in CI; G1 and G3 timings; tune only through `SpireConfig` with a 0009 amendment | A06 |
| R6 | Idle boredom (tycoon players leave once everything is bought) | Medium | Medium | Hot Data, events, contracts, IPO in M4; kill criteria (GDD T) | A06 |
| R7 | Blender props off-style, too heavy for phones, or blocked on the upload environment | Medium | Low | Tris budgets per prop (as the Night plan); contact-sheet review before upload; AI-mesh and primitive fallbacks; the tower and city stay procedural | A12 |
| R8 | Save bugs across servers | Low (pattern exists) | High | Copy the reviewed Garden Profiles with its lock; no unbanked pool; QA traces races | A11 |
| R9 | Photosensitivity complaints (neon flicker) | Low | High | ≤ 3 Hz rule, Reduce Flashing setting, QA check | A15 |
| R10 | Trademark confusion ("Cyberpunk") | Low | Medium | Title and logo avoid the word; descriptions use it as a genre only | A06 |
| R11 | Content maturity rating higher than intended | Low | Medium | No violence or crime themes; fill the questionnaire honestly in M5 | A06 |
| R12 | DataStore budget at 6 players | Low | Medium | 7 s coalescing, board every 120 s; re-check limits in SPIRE-003 | A09 |
| R13 | SHANNON's time for playtests is the bottleneck | High | Medium | Six short sessions scheduled up front (section 4); every session has a script | A01 |

## 6. Baseplate investigation (SPIRE-002, before any Spire publish)

Facts (handoff 2026-10-24): the publish run for Bake Rush returned version 5 for universe 10772778901, place 94875527634079; a local build of the same commit contains the scripts; SHANNON joined and saw only a baseplate.

Suspects in the order to check, cheapest first:

1. **An old server was still running.** Publishing a new version does not move players already in, and joining can land in a server started before the publish. Check: Creator Hub → the experience → Servers → restart or shut down all, then rejoin. The build stamp makes this visible next time.
2. **A different place or experience was joined.** Check that place 94875527634079 is the start place of universe 10772778901 and that the link SHANNON used opens that experience (Creator Hub → Places). If the experience has a second place, the publish may have gone to a non-start place.
3. **The server script errored on start.** Check the F9 server log on the published place for errors, especially infinite-yield warnings from `WaitForChild`.
4. **The uploaded file is not the built place.** Compare the manifest's artifact SHA-256 with a fresh `rojo build` of the same commit; confirm the publish step uploads `build/place.rbxl` (it does in `publish.yml`).
5. (Unrelated to the baseplate, but blocks Studio tests) "Enable Studio Access to API Services" must be on in the staging experience.

Then: add the build stamp (architecture 9), a publish checklist line "restart servers after publish", and, if SHANNON approves the key scope, the Luau Execution post-publish check. Record the root cause in PILOT-004's notes and SPIRE-002's evidence.

## 7. Monetisation (M6, cosmetic only)

Not built in v0.1 (decision 0002). After M5 has live data, SPIRE-011 may propose, for SHANNON's approval:

- Cosmetic passes: facade skin packs, crown styles, plaza decor packs, footstep trails, lobby styles.
- Never: income multipliers, "2× cash", auto-collect, skips, extra floors, extra power, paid Shares, random paid items, timed offers.
- Steps: decision record; check Roblox's current monetisation and paid-random-item policies and `PolicyService` restrictions for the player's region; SHANNON creates each product (rule 7: paid products are always human-approved).

## 8. Approvals needed from SHANNON

| What | When | Why |
|---|---|---|
| This plan (GDD, art bible, production plan, architecture) | now | SPIRE-001 verification |
| Asset approach (decision 0010) | before SPIRE-007 | per-game asset approval; rule 9 |
| Decision 0009 (economy, saves, remotes) | before SPIRE-004 | rule 8 |
| `spire-staging` experience, its GitHub environment and API key | before the first Spire publish | rule 7 (credentials) |
| Luau Execution key scope for the post-publish check (optional) | SPIRE-002 | rule 7 |
| Music picks | SPIRE-007 | taste; register rows |
| Production publish | M5 | rule 7, studio gate 5 |
| Any paid product | M6 | rule 7 |

## 9. Questions for SHANNON (with recommendations)

1. **Assets:** approve option A + C (procedural tower, plaza and city; Blender props and module models through the Night pipeline; AI meshes only as a fallback)? *Recommended: yes.*
2. **Title:** keep "Neon Spire", or another name? *Recommended: Neon Spire (no trademark risk, says what it is).*
3. **Pipeline first:** can you spend 15 minutes on the Bake Rush staging place (restart servers, rejoin, F9 log) so SPIRE-002 can close the baseplate question before Spire publishes? *Recommended: yes, it unblocks every game.*
4. **Audience:** keep the under-18 rules used by the other games? *Recommended: yes.*
5. **IPO timing:** build IPO after the core passes (M4, as planned) or in v0.1? *Recommended: after.*
6. **Playtest time:** can you commit to the six sessions in section 4 (about 3 hours over the build), on a phone and a PC? Do you have a controller?
7. **Staging experience:** will you create a new `spire-staging` experience (separate DataStores) and its GitHub environment when M1 is close?
