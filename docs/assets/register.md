# Asset provenance register

Every shipped asset needs a row before it is used. Registered by Claude on 2026-10-25 under SHANNON's instruction to register assets for Relay Rounds. Each audio ID was checked to load in the Relay staging experience; IDs that did not load there were not used.

| Asset ID | Source | Creator / supplier | Licence / permission | Attribution | Restrictions | Format | Used in | Status |
|----------|--------|--------------------|----------------------|-------------|--------------|--------|---------|--------|
| 116124333528107 (mesh), 100523147264116 (texture) | Roblox AI mesh generation in Studio | Generated for SHANNON's account (prompt: oni demon statue) | Owned by the experience creator | None needed | Load by ID only in experiences of the same owner | Mesh + texture | `src/relay/Models.luau` (oni) | In use |
| 122277590516586 (mesh), 79997104777585 (texture); model 138479189499679 | Roblox AI mesh generation | Generated for SHANNON's account (prompt: five-tier pagoda) | Owned by the experience creator | None needed | As above | Mesh + texture | `Models.luau` (pagoda) | In use |
| 105076361309216 (mesh), 86149062997023 (texture); model 131474217997930 | Roblox AI mesh generation | Generated for SHANNON's account (prompt: winged trophy) | Owned by the experience creator | None needed | As above | Mesh + texture | `Models.luau` (trophy) | In use |
| 130213651134294 (mesh), 73994868840361 (texture); model 75148849377480 | Roblox AI mesh generation | Generated for SHANNON's account (prompt: komainu statue) | Owned by the experience creator | None needed | As above | Mesh + texture | `Models.luau` (komainu) | In use |
| 87416512611152 | Creator Store audio | DistrokidOfficial ("Serenity Through Shadows") | Roblox-licensed music partner, free for use in experiences | None required | Roblox audio terms | Audio, 77 s | Lobby music (`Menu.client.luau`) | In use |
| 9040647656 | Creator Store audio | APMOfficial ("We're Taking Over Tonight") | Roblox licence with APM Music | "Courtesy of APM Music" in store listing | Roblox audio terms | Audio, 60 s | Race music | In use |
| 1845705763 | Creator Store audio | APMOfficial ("Killshot C") | Roblox licence with APM Music | As above | Roblox audio terms | Audio, 60 s | Race music | In use |
| 1848171351 | Creator Store audio | APMOfficial ("Boom Bang C") | Roblox licence with APM Music | As above | Roblox audio terms | Audio, 115 s | Race music | In use |
| 9117060347 | Creator Store audio | ProSoundEffects ("Nasa Transmission Beep 1") | Roblox licence with Pro Sound Effects | "Courtesy of Pro Sound Effects" in store listing | Roblox audio terms | SFX | Countdown tick | In use |
| 9125585534 | Creator Store audio | ProSoundEffects (Chinese gong, single hit) | As above | As above | Roblox audio terms | SFX | Round start | In use |
| 9114630316 | Creator Store audio | ProSoundEffects (gong hit, resonant trail) | As above | As above | Roblox audio terms | SFX | Match win | In use |
| 9114373663 | Creator Store audio | ProSoundEffects (fast pass-by whoosh) | As above | As above | Roblox audio terms | SFX | Handoffs, double jump, boosts | In use |
| 9125920594 | Creator Store audio | ProSoundEffects (searing whoosh) | As above | As above | Roblox audio terms | SFX | Air dash | In use |
| 656118852, 656121766, 656117878, 656115606, 656117400, 656114359 | Roblox catalog (Ninja Animation Package) | Roblox | Roblox-created animations, usable in any experience | None needed | R15 only | Animation | Run, walk, jump, fall, idle, climb (`Movement.client.luau`) | In use |
| rbxasset://sounds/ouch.ogg | Bundled with the Roblox client | Roblox | Built-in engine content | None needed | None | SFX | Elimination | In use |
