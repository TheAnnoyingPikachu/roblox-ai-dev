# 0122: Animal Stations: music and effects volume, and mute

Status: accepted (SHANNON, 2026-11-26, decision 0121 answer 21: "Music and sound volume, plus mute"). The
layout is Claude's. Task STATION-179. Date: 2026-11-26.

## Context

- Fact: the game had no settings at all, not even volume. Music plays in fights; effects are the UI sounds,
  hits and the fight's stings.

## What

- Two sound groups in SoundService, made by the HUD (`Style.group`): `Music` (the fight and boss tracks) and
  `Effects` (everything else). A player's volumes set the groups' Volume, so every sound follows them.
- A **Sound** button on the Go to… panel (a phone's More opens that panel) opens a small panel: Music and
  Effects, each with − and + in steps of 10%, and Mute all.
- Data schema: the save gains `sound = { music, effects, mute }`, music and effects whole steps from 0 to
  `StationProgress.SOUND_STEPS` (10), full by default. `sanitize` clamps them; anything else is the default.
  An older server drops the field and the player is back at full volume (no VERSION change: nothing of value
  is lost).
- Remote contract: a new request `sound(music: int 0..10, effects: int 0..10, mute: boolean)`, which only sets
  those three values (`StationProgress.setSound`). The HUD changes the volume straight away and the save keeps it.

## Not changed

Every sound's own volume; which sounds exist (decision 0121 answers 22 to 24 add music and sounds in their own
tasks).
