# 0128: Animal Stations: seeing each other

Status: accepted (SHANNON, 2026-11-27, Round 2 build 5: "A B and D", then "yes seeing each other" and "do
everything you can without credits for now"). Tasks STATION-188 (best wave and visiting), and the top-100 board and
the follower animal in their own tasks. Date: 2026-11-27.

## What (STATION-188)

- **Best wave in the player list:** every player gets `leaderstats` with an IntValue "Best wave", set from the save's
  `best` whenever the save changes. Roblox shows it in the player list.
- **Visit a ranch:** a **Visit** button beside Sound on the Go to… panel lists the other players' ranches in the
  server ("Lena's ranch"), or "No one else is here yet. Invite a friend!". Choosing one stands the player at that
  ranch's spawn. The ranch's prompts stay its owner's (the HUD checks the ranch is the player's own), so a visitor
  can look but not use them.
- Remote contract: a new request `visit(userId: int)`. It leaves any fight (banking the run, as `travel` does) and is
  refused as `visit` when that player is not in the server, has no ranch, or is the visitor.
- The Go to… panel is 236 wide (was 196) to fit Visit and Sound beside its title.

## Later in this decision

- B: a top-100 best-wave board at the hub, read from an OrderedDataStore.
- D: one animal that follows its owner around.
