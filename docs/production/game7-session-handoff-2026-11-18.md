# Animal Stations (game 7): handoff, 2026-11-18

Written at the end of a long session for the next one. Read this, then `CLAUDE.md`,
`src/stations/CLAUDE.md` and the task you pick up. **Fact** = checked; **Assumption** = not checked.

## 1. Where the repo is

- **Fact.** Worktree `C:\Users\pikachud\rad-game7`, branch `game7/foundation`, last commit `2afd908`
  (STATION-093), pushed; CI passed on it. PR #25 is open; its title and body still describe only
  STATION-001 to 084 (see section 4).
- **Fact.** Checks: `lune run tests/run` 721/721, selene 0 warnings, 173 task files valid, scope check
  passes, `rojo build` + `check-place` match.
- **Fact.** Studio place `stations.rbxl`, studio id `b530253d-6a9d-4d0d-bf9b-ad13bc283839`, is stopped
  and synced with the repo for Valley, World, Ranch and ValleyMap. Its Output warns that the Assistant
  plugin version changed and Studio should be restarted: if MCP calls time out, ask SHANNON to restart it.
  The sync server on port 8765 is stopped.
- **Fact.** Next free numbers: task `STATION-095` (094 is this handoff), decision `0088`.

## 2. What this session did (STATION-085 to 093)

| Task | What |
|---|---|
| 085 | Polish plan (`docs/game-design/game7-polish-plan.md`) |
| 086 | `stations-staging` target in `.github/workflows/publish.yml` (not used yet) |
| 087 | Player trading (decision 0084, `src/shared/StationTrade.luau`); the admin menu is SHANNON's account only (UserId 96807256) |
| 088, 089 | Visual overhaul (decision 0085): lighting, terrain colours, grass blades (set on the place in `stations.project.json`), six faceted `scenery_*` tree/pine/bush models (uploaded), path edges, waterfall foam, rock clusters |
| 090, 091 | Training grounds' look (decision 0086): frayed floors, a border round each, woods up the slopes, no blades through the track. Also fixed `calm` in `World.luau`, which threw "Region cannot be empty" and stopped the world build after ranch 1's valley (a bug from 089) |
| 092, 093 | Ledges and grassy tops on the rock round the grounds (decision 0087); flower clumps cut from the border; the whole homestead is LeafyGrass (no blades through floors); tufts along homestead paths cut to one in seven |

Earlier in the same session (before 085): the giraffe and diamond-ore giraffe, the team pen and the
sleeping Titan (decisions 0076 to 0083).

## 3. Waiting on SHANNON

- **The private test place.** SHANNON must create the experience (private, Max Players 3), make an Open
  Cloud key (universe-places:write, luau-execution-sessions:write) and set it themselves as
  `ROBLOX_API_KEY` in the GitHub environment `stations-staging`, then send the experience and place IDs.
  Then: set the environment's variables and dispatch `publish.yml` with environment `stations-staging`.
  Never ask for the key in chat.
- Nothing else is pending a decision: 0084 to 0087 are accepted and built.

## 4. Open items (none started)

1. **PR #25's title and body**: update for STATION-085 to 093.
2. **Phone and frame rate.** Not measured since the overhaul. **Fact:** the world counted 23,221 parts
   in Studio with ranch 1's areas at level 5 (about 9,300 before 089). Ranked cuts if phones are slow:
   ledges (`rocky` chance in `Valley.dress`), the woods' 260 tries a ground, the border.
3. **Trading's two save writes** are not one transaction (decision 0084): copy Egg Garden's ledger
   (`src/garden/Trades.luau`, read only, do not edit Garden files) before any public release.
4. **Known looks:** path-edge tufts are small blocks up close; the hub's far round mountains have no
   detail; levels 0 to 4 of the training areas and the arena were not looked at after the overhaul.

## 5. How the work was checked in Studio (works well)

1. Serve `src` (`python -m http.server 8765` in `src`), stop Play, and in Edit
   `HttpService:GetAsync` each changed file and `ScriptEditorService:UpdateSourceAsync` it into its
   script (`ServerScriptService.Stations.<Name>`, `ReplicatedStorage.Shared.<Name>`).
2. Start Play. To see all of an area's kit, on the server: destroy ranch 1's six area folders under
   `workspace.Hub.Ranches.Ranch1.Built` and call `Areas.build(built, 1, 5)`.
3. Camera: on the client, bind a RenderStep that sets the camera from a `DbgCam` CFrame attribute on
   workspace (a plain set is undone when the character respawns). The concept cameras look at an area
   from 120 studs towards the homestead, 50 to the side, 75 up. Ranch 1's middle is (0, 22, 900); area
   frames come from `World.areaFrame(1, k)`.
4. Concepts: apply the "after" live from the server, take the same cameras again, stop Play (nothing
   is kept), compose the card with Python PIL (run without `-I`, which hides PIL).
5. Afterwards stop Play and kill port 8765.

## 6. Standing rules worth repeating

Every change belongs to a task in `studio/tasks/` (task_type is one of research, design, architecture,
implementation, test, asset, release, infrastructure; `tests` are bare spec file names). Uploads only
through `.github/workflows/upload-assets.yml`. Each new set of looks gets a concept and SHANNON's go
first. Never publish, spend money or touch credentials without SHANNON. Big pushes:
`git -c http.version=HTTP/1.1 push`. Don't touch Egg Garden files. SHANNON uses they/them.
