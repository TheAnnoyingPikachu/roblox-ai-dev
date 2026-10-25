# Relay Rounds: game design spec (v0.1)

Status: v0.2 (launch polish). Concept C in `concepts.md`.

## A. Product

- **Pitch:** teams of 1–4 race a relay course, passing a baton. The slowest team each round is out. Last team standing wins.
- **Audience:** players under 18. Roblox's built-in filtered text chat stays on. No custom chat, no personal data, no saves.
- **Platforms:** PC, mobile, console. Movement only: no buttons beyond walk and jump.
- **Pillars:** short rounds; always know what to do next; a disconnect never ruins the match.
- **Non-goals:** saved progress (wins are per session), unlockable themes, parties or friends-only teams, paid items, custom chat.
- **Presentation:** an on-screen status bar (lobby countdown, round timer, finishes, eliminations, winner), team-coloured batons with sparkles, and Roblox's built-in sounds for countdown, legs, eliminations and the win.

## B. Match flow

1. **Lobby:** players wait on the lobby pad and can run the practice lane, which has every obstacle layout once. A match starts 15 s after at least 2 players are present; the countdown cancels if players drop below 2. (v0.1 needed 4, which would leave most visitors of a new game waiting alone.)
2. **Teams:** the server splits players into 2–4 teams of up to 4, as even as possible, by join order. Teams have a colour; the player's character is painted in it for the match.
3. **Round (about 90 s, after a 3 s get-ready countdown):** each team runs the course as a relay. Runner 1 carries the baton through leg 1, then passes it in the handoff zone to the next runner, who runs leg 2, and so on until the last leg crosses the finish.
4. **Elimination:** when all but one team have finished, or the 90 s limit runs out, the team ranked last is eliminated (ranking in section D). Its players are moved to the raised stands beside the course to watch.
5. **Next round:** the course loses one leg (minimum 2 legs) and each leg gets a new obstacle layout, the same for every lane. Repeat until one team is left. That team wins (each member gets +1 Wins on the session leaderboard); everyone respawns in the lobby with their own look.

Target: a full match in about 8 minutes (hypothesis, to check in playtest).

## C. Baton rules

- Only the current runner holds the baton. The server attaches it to their character.
- **Pass:** the server passes the baton when the runner is inside the handoff zone at the end of their leg and a teammate who has not run yet this round is also inside it. Nobody presses anything.
- If every teammate has already run, the same runner keeps the baton for the next leg (small teams run more legs).
- Falling off the course respawns the runner at the start of their current leg, still holding the baton.
- Clients send nothing. Position checks, passes and finishes are all decided on the server.

## D. Ranking

Teams are ranked by, in order:

1. Finished before not finished.
2. Among finished teams: earlier finish time.
3. Among unfinished teams: more legs completed, then less distance left on the current leg.
4. Still tied: the team that has been in the match longest is safe (join order), so the result is deterministic.

## E. Disconnects

- **Runner leaves:** the baton moves to the next teammate who has not run; if none, to any teammate. That teammate respawns at the start of the current leg.
- **Teammate leaves (not running):** nothing changes; the team has fewer runners.
- **Whole team leaves:** that team is eliminated at once. If this leaves one team, it wins.
- **Below 2 teams at any time:** the match ends; remaining players return to the lobby.
- **Mid-match joiners** wait in the lobby for the next match.

## F. Course

- Built from primitive parts only (rule 9). Each leg is a 60-stud run using one of four layouts: gaps, balance beam, rising steps, narrow gaps. Round 1 always opens with the easiest (gaps). Lanes are separate per team, so teams never block each other.
- Course parts are created by the server at match start, not stored in the place.

## G. Acceptance criteria (v0.1)

- [ ] Teams are balanced: sizes differ by at most 1 for every player count from 2 to 16 (unit test).
- [ ] Ranking follows section D, including ties (unit test).
- [ ] A pass happens only inside the handoff zone to a teammate who has not run (unit test).
- [ ] Every disconnect case in section E leaves a valid match state (unit tests).
- [ ] A course never has fewer than 2 legs (unit test).
- [ ] A multiplayer staging playtest completes a match with a winner (skipped at SHANNON's request, 2026-10-25).
- [ ] No Robux prompts, no paid items, no saves.

## H. Kill criteria

- Fewer than 30% of players start a second match in playtest (from `concepts.md`).
- Matches regularly take over 12 minutes.

## I. Facts, assumptions, hypotheses

- **Fact:** Roblox's default chat is filtered for under-13s; the game adds no chat of its own.
- **Assumption:** players accept random teams without voice or chat (the concept's riskiest assumption).
- **Assumption:** 2 players is enough to start a match worth playing.
- **Hypothesis:** 90 s rounds and an 8-minute match keep younger players engaged.
- No live trend data was checked.

## J. Open questions

- Repo layout: resolved. Relay Rounds builds from `relay.project.json` and publishes through the `relay-staging` environment.
