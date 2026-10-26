--!strict
local T = require("./framework")
local RunRules = require("../src/shared/RunRules")

local describe, it, expect = T.describe, T.it, T.expect

type Run = RunRules.Run

local FAR = { x = 1000, y = 0, z = 0 }

local function input(t: number, cleared: boolean?, positions: { [number]: any }?): RunRules.TickInput
	return { t = t, dt = 0.1, cleared = cleared == true, hostTier = 2, seed = 777, positions = positions or {} }
end

local function kinds(events: { RunRules.Event }): string
	local list = {}
	for _, e in events do
		table.insert(list, e.kind)
	end
	return table.concat(list, ",")
end

-- A run in Wave(1) at t = 3 with the given players (first is host).
local function waveRun(ids: { number }): Run
	local run = RunRules.new()
	for _, id in ids do
		run = RunRules.play(run, id, 1, 42, 0)
	end
	return (RunRules.tick(run, input(3)))
end

local function p(run: Run, id: number): RunRules.Participant
	return RunRules.find(run, id) :: RunRules.Participant
end

-- Clears the current wave at `t` and returns the run in the following Break.
local function clear(run: Run, t: number): (Run, { RunRules.Event })
	return RunRules.tick(run, input(t, true))
end

describe("RunRules states (B)", function()
	it("goes Idle -> Countdown on PLAY with that player as host and tier", function()
		local run, ok = RunRules.play(RunRules.new(), 5, 3, 99, 10)
		expect(ok).toBe(true)
		expect(run.state).toBe("Countdown")
		expect(run.host).toBe(5)
		expect(run.tier).toBe(3)
		expect(run.seed).toBe(99)
		expect(run.endsAt).toBe(13)
		expect(p(run, 5).joinIndex).toBe(1)
	end)

	it("starts Wave(1) when the countdown ends, with n at wave start", function()
		local run = RunRules.play(RunRules.new(), 5, 1, 1, 0)
		local same, none = RunRules.tick(run, input(2.9))
		expect(same.state).toBe("Countdown")
		expect(#none).toBe(0)
		local wave, events = RunRules.tick(run, input(3, true))
		expect(wave.state).toBe("Wave")
		expect(wave.wave).toBe(1)
		expect(wave.n).toBe(1)
		expect(kinds(events)).toBe("wave") -- a stale `cleared` is not applied to the new wave
		expect(events[1].wave).toBe(1)
	end)

	it("clears into a 12 s Break, then the next wave", function()
		local run = waveRun({ 1 })
		local brk, events = clear(run, 20)
		expect(kinds(events)).toBe("cleared,break")
		expect(events[1].wave).toBe(1)
		expect(events[1].n).toBe(1)
		expect(brk.state).toBe("Break")
		expect(brk.endsAt).toBe(32)
		expect(p(brk, 1).clears).toBe(1)
		local wave2, e2 = RunRules.tick(brk, input(32))
		expect(wave2.state).toBe("Wave")
		expect(wave2.wave).toBe(2)
		expect(kinds(e2)).toBe("wave")
	end)

	it("goes to Victory after wave 10, then a new Countdown with the same players reset", function()
		local run = waveRun({ 1, 2 })
		run.wave = 10
		local win, events = clear(run, 50)
		expect(kinds(events)).toBe("cleared,victory")
		expect(win.state).toBe("Victory")
		expect(win.endsAt).toBe(58)
		local again, e2 = RunRules.tick(win, input(58))
		expect(kinds(e2)).toBe("countdown")
		expect(again.state).toBe("Countdown")
		expect(again.tier).toBe(2) -- host's tier re-read
		expect(again.seed).toBe(777)
		expect(again.wave).toBe(0)
		expect(p(again, 2).joinIndex).toBe(2)
		expect(p(again, 2).clears).toBe(0)
		expect(again.host).toBe(1)
	end)

	it("goes to Idle after Victory or Defeat when nobody is left", function()
		local run = waveRun({ 1 })
		run.wave = 10
		run = clear(run, 50)
		run = RunRules.leave(run, 1)
		expect(run.state).toBe("Victory")
		local idle, events = RunRules.tick(run, input(58))
		expect(idle.state).toBe("Idle")
		expect(kinds(events)).toBe("idle")
	end)

	it("returns to Idle when the last participant leaves in Countdown, Wave or Break", function()
		local cd = RunRules.play(RunRules.new(), 1, 1, 1, 0)
		local idle, events = RunRules.leave(cd, 1)
		expect(idle.state).toBe("Idle")
		expect(kinds(events)).toBe("idle")
		expect((RunRules.leave(waveRun({ 1 }), 1)).state).toBe("Idle")
		expect((RunRules.leave((clear(waveRun({ 1 }), 20)), 1)).state).toBe("Idle")
	end)
end)

describe("RunRules joining (B2)", function()
	it("joins Countdown at full HP with one charm, refuses duplicates and a 7th player", function()
		local run = RunRules.play(RunRules.new(), 1, 1, 1, 0)
		local _, dup = RunRules.play(run, 1, 1, 1, 0)
		expect(dup).toBe(false)
		for id = 2, 6 do
			local ok
			run, ok = RunRules.play(run, id, 5, 5, 1)
			expect(ok).toBe(true)
		end
		expect(run.tier).toBe(1) -- tier and seed only from Idle
		expect(p(run, 6).joinIndex).toBe(6)
		expect(p(run, 6).hp).toBe(100)
		expect(p(run, 6).charms).toBe(1)
		local _, full = RunRules.play(run, 7, 1, 1, 1)
		expect(full).toBe(false)
	end)

	it("gives w - 1 deterministic catch-up blessings when joining Wave(w)", function()
		local run = waveRun({ 1 })
		run.wave = 4
		expect(RunRules.catchUpCount(run)).toBe(3)
		local a = RunRules.play(run, 2, 1, 1, 5)
		local b = RunRules.play(run, 2, 1, 1, 5)
		local total = 0
		for id, count in p(a, 2).stacks do
			total += count
			expect(p(b, 2).stacks[id]).toBe(count)
		end
		expect(total).toBe(3)
		expect(p(a, 2).hp).toBe(p(a, 2).maxHp)
		expect(#p(a, 2).offer).toBe(0)
		expect(a.n).toBe(1) -- joining mid-wave does not change this wave's n
	end)

	it("gives w - 1 catch-ups and this break's offer when joining Break(w)", function()
		local run = clear(waveRun({ 1 }), 20)
		run.wave = 3
		expect(RunRules.catchUpCount(run)).toBe(2)
		local joined = RunRules.play(run, 2, 1, 1, 21)
		local total = 0
		for _, count in p(joined, 2).stacks do
			total += count
		end
		expect(total).toBe(2)
		expect(#p(joined, 2).offer).toBe(3)
		expect(p(joined, 2).picked).toBe(false)
	end)

	it("counts no catch-ups outside Wave and Break", function()
		expect(RunRules.catchUpCount(RunRules.new())).toBe(0)
		expect(RunRules.catchUpCount((RunRules.play(RunRules.new(), 1, 1, 1, 0)))).toBe(0)
	end)

	it("lets a PLAY during Victory join the next countdown", function()
		local run = waveRun({ 1 })
		run.wave = 10
		run = clear(run, 50)
		local joined, ok = RunRules.play(run, 2, 1, 1, 52)
		expect(ok).toBe(true)
		local next = RunRules.tick(joined, input(58))
		expect(next.state).toBe("Countdown")
		expect(#next.participants).toBe(2)
	end)

	it("hands host to the earliest remaining participant without changing the tier", function()
		local run = waveRun({ 1, 2, 3 })
		local left, events = RunRules.leave(run, 1)
		expect(left.host).toBe(2)
		expect(left.tier).toBe(run.tier)
		expect(kinds(events)).toBe("host")
		expect(events[1].userId).toBe(2)
		local _, none = RunRules.leave(left, 3)
		expect(#none).toBe(0)
		local same = RunRules.leave(left, 99)
		expect(same).toBe(left)
	end)
end)

describe("RunRules damage, downs and charms (G)", function()
	it("hits, downs at 0 HP and spends a charm for a revive 3 s later at 50%", function()
		local run = waveRun({ 1 })
		local hit, r1 = RunRules.damage(run, 1, 30, 4)
		expect(r1).toBe("hit")
		expect(p(hit, 1).hp).toBe(70)
		expect(p(run, 1).hp).toBe(100)
		local down, r2 = RunRules.damage(hit, 1, 500, 5)
		expect(r2).toBe("down")
		expect(p(down, 1).hp).toBe(0)
		expect(p(down, 1).charms).toBe(0)
		expect(p(down, 1).reviveAt).toBe(8)
		expect(RunRules.isAlive(down, 1)).toBe(false)
		expect(RunRules.defeated(down)).toBe(false) -- charm revive pending
		local _, r3 = RunRules.damage(down, 1, 10, 6)
		expect(r3).toBe("ignored")
		local still = RunRules.tick(down, input(7.9))
		expect(p(still, 1).downed).toBe(true)
		local up, events = RunRules.tick(down, input(8))
		expect(kinds(events)).toBe("revive")
		expect(events[1].by).toBeNil()
		expect(p(up, 1).hp).toBe(50)
		expect(p(up, 1).downed).toBe(false)
		local _, immune = RunRules.damage(up, 1, 10, 9.9)
		expect(immune).toBe("immune")
		local _, hurt = RunRules.damage(up, 1, 10, 10)
		expect(hurt).toBe("hit")
	end)

	it("ends the night when the last down has no charm", function()
		local run = waveRun({ 1 })
		run = RunRules.damage(run, 1, 500, 5)
		run = RunRules.tick(run, input(8))
		run = RunRules.damage(run, 1, 500, 20)
		expect(RunRules.defeated(run)).toBe(true)
		local lost, events = RunRules.tick(run, input(21))
		expect(kinds(events)).toBe("defeat")
		expect(lost.state).toBe("Defeat")
		expect(lost.endsAt).toBe(29)
		local again = RunRules.tick(lost, input(29))
		expect(again.state).toBe("Countdown")
		expect(p(again, 1).charms).toBe(1)
		expect(p(again, 1).hp).toBe(100)
	end)

	it("counts a dash-blocked hit as a dodge, and ignores hits outside a wave", function()
		local run = RunRules.dash(waveRun({ 1 }), 1, 10)
		local _, r = RunRules.damage(run, 1, 10, 10.34)
		expect(r).toBe("dodge")
		local _, r2 = RunRules.damage(run, 1, 10, 10.35)
		expect(r2).toBe("hit")
		local _, r3 = RunRules.damage(RunRules.play(RunRules.new(), 1, 1, 1, 0), 1, 10, 1)
		expect(r3).toBe("ignored")
		local _, r4 = RunRules.damage(run, 42, 10, 11)
		expect(r4).toBe("ignored")
	end)

	it("heals up to max HP and not while downed", function()
		local run = RunRules.damage(waveRun({ 1, 2 }), 1, 30, 4)
		expect(p(RunRules.heal(run, 1, 10), 1).hp).toBe(80)
		expect(p(RunRules.heal(run, 1, 999), 1).hp).toBe(100)
		local down = RunRules.damage(run, 2, 500, 5)
		expect(p(RunRules.heal(down, 2, 50), 2).hp).toBe(0)
	end)
end)

describe("RunRules ally revives (G)", function()
	local function downedPair(): Run
		local run = waveRun({ 1, 2 })
		run = RunRules.damage(run, 2, 500, 4)
		run = RunRules.tick(run, input(7)) -- charm revive
		return (RunRules.damage(run, 2, 500, 10)) -- no charm left
	end

	local near = { [1] = { x = 0, y = 0, z = 0 }, [2] = { x = 6, y = 3, z = 0 } }

	it("revives after 2.0 s within 6 studs at 40% max HP", function()
		local run = downedPair()
		local t = 10
		local events
		for _ = 1, 19 do
			t += 0.1
			run, events = RunRules.tick(run, input(t, false, near))
			expect(#events).toBe(0)
		end
		run, events = RunRules.tick(run, input(t + 0.1, false, near))
		expect(kinds(events)).toBe("revive")
		expect(events[1].by).toBe(1)
		expect(p(run, 2).hp).toBe(40)
		expect(p(run, 2).invulnUntil).toBe(t + 0.1 + 2)
	end)

	it("resets the timer when the helper steps away", function()
		local run = downedPair()
		local t = 10
		for _ = 1, 15 do
			t += 0.1
			run = RunRules.tick(run, input(t, false, near))
		end
		run = RunRules.tick(run, input(t + 0.1, false, { [1] = FAR, [2] = near[2] }))
		expect(p(run, 2).helpTime).toBe(0)
		local events
		for _ = 1, 19 do
			t += 0.1
			run, events = RunRules.tick(run, input(t, false, near))
		end
		expect(#events).toBe(0)
		expect(p(run, 2).downed).toBe(true)
	end)

	it("heals both to max with Spirit Link", function()
		local run = downedPair()
		run.participants[1].stacks = { link = 1 }
		run.participants[1].hp = 30
		local t, events = 10, {}
		for _ = 1, 20 do
			t += 0.1
			run, events = RunRules.tick(run, input(t, false, near))
		end
		expect(kinds(events)).toBe("revive")
		expect(p(run, 2).hp).toBe(100)
		expect(p(run, 1).hp).toBe(100)
	end)
end)

describe("RunRules breaks and blessings (E, G)", function()
	it("heals 25 and stands downed players at 50% when a break starts", function()
		local run = waveRun({ 1, 2, 3 })
		run = RunRules.damage(run, 1, 90, 4)
		run = RunRules.damage(run, 2, 30, 4)
		run = RunRules.damage(run, 3, 500, 4)
		local brk, events = clear(run, 5)
		expect(p(brk, 1).hp).toBe(35)
		expect(p(brk, 2).hp).toBe(95)
		expect(p(brk, 3).hp).toBe(50)
		expect(p(brk, 3).downed).toBe(false)
		expect(p(brk, 3).reviveAt).toBeNil()
		expect(kinds(events)).toBe("cleared,revive,break")
		expect(#p(brk, 1).offer).toBe(3)
	end)

	it("applies a pick once per break and refuses picks outside a break", function()
		local run = waveRun({ 1 })
		local _, early = RunRules.pick(run, 1, 1)
		expect(early).toBe(false)
		local brk = clear(run, 5)
		local id = p(brk, 1).offer[2]
		local _, bad = RunRules.pick(brk, 1, 4)
		expect(bad).toBe(false)
		local picked, ok = RunRules.pick(brk, 1, 2)
		expect(ok).toBe(true)
		expect(p(picked, 1).stacks[id]).toBe(1)
		expect(#p(picked, 1).offer).toBe(0)
		local _, twice = RunRules.pick(picked, 1, 1)
		expect(twice).toBe(false)
		local next = RunRules.tick(picked, input(17))
		local total = 0
		for _, count in p(next, 1).stacks do
			total += count
		end
		expect(total).toBe(1) -- no auto-pick on top of a pick
	end)

	it("auto-picks offer 1 when the break ends", function()
		local brk = clear(waveRun({ 1 }), 5)
		local first = p(brk, 1).offer[1]
		local wave = RunRules.tick(brk, input(17))
		expect(p(wave, 1).stacks[first]).toBe(1)
		expect(#p(wave, 1).offer).toBe(0)
	end)

	it("recomputes max HP with Iron Skin and adds a charm with Nine Tails", function()
		local brk = clear(RunRules.damage(waveRun({ 1 }), 1, 50, 4), 5)
		local q = brk.participants[1]
		q.offer = { "iron", "ninetails" }
		local a = RunRules.pick(brk, 1, 1)
		expect(p(a, 1).maxHp).toBe(120)
		expect(p(a, 1).hp).toBe(95) -- 75 after the break heal, +20
		local b = RunRules.pick(brk, 1, 2)
		expect(p(b, 1).charms).toBe(2)
	end)

	it("keeps offers per participant deterministic from the run seed", function()
		local a = clear(waveRun({ 1, 2 }), 5)
		local b = clear(waveRun({ 1, 2 }), 5)
		expect(table.concat(p(a, 2).offer, ",")).toBe(table.concat(p(b, 2).offer, ","))
	end)
end)

describe("RunRules rejoining the same run (QA M3, m5)", function()
	it("restores a downed leaver with no charm instead of a fresh participant", function()
		local run = waveRun({ 1, 2 })
		run = RunRules.damage(run, 2, 500, 4)
		run = RunRules.tick(run, input(7))
		run = RunRules.damage(run, 2, 500, 10)
		run = RunRules.leave(run, 2)
		local back, ok = RunRules.play(run, 2, 1, 1, 10.5)
		expect(ok).toBe(true)
		expect(p(back, 2).downed).toBe(true)
		expect(p(back, 2).hp).toBe(0)
		expect(p(back, 2).charms).toBe(0)
		expect(back.left[2]).toBeNil()
	end)

	it("keeps HP, blessings and clears, so a run counts once per player", function()
		local run = clear(waveRun({ 1, 2 }), 20)
		run = RunRules.pick(run, 2, 1)
		local stacks = p(run, 2).stacks
		run = RunRules.tick(run, input(32)) -- Wave(2)
		run = RunRules.damage(run, 2, 30, 33)
		run = RunRules.leave(run, 2)
		run = RunRules.play(run, 2, 1, 1, 34)
		expect(p(run, 2).clears).toBe(1)
		expect(p(run, 2).hp).toBe(p(run, 2).maxHp - 30)
		for id, count in stacks do
			expect(p(run, 2).stacks[id]).toBe(count)
		end
		run = clear(run, 40)
		expect(p(run, 2).clears).toBe(2) -- the server counts `runs` only when clears == 1
	end)

	it("keeps this break's pick on a rejoin in the same break, and offers anew in a later one", function()
		local run = clear(waveRun({ 1, 2 }), 20)
		run = RunRules.pick(run, 2, 1)
		local back = RunRules.play(RunRules.leave(run, 2), 2, 1, 1, 21)
		expect(p(back, 2).picked).toBe(true)
		expect((RunRules.pick(back, 2, 2))).toBe(back)
		local gone = RunRules.leave(run, 2)
		gone = RunRules.tick(gone, input(32)) -- Wave(2)
		gone = clear(gone, 40) -- Break(2)
		local later = RunRules.play(gone, 2, 1, 1, 41)
		expect(p(later, 2).picked).toBe(false)
		expect(#p(later, 2).offer).toBe(3)
	end)

	it("forgets leavers when a new run starts", function()
		local run = waveRun({ 1, 2 })
		run = RunRules.leave(RunRules.damage(run, 2, 30, 4), 2)
		run.wave = 10
		run = clear(run, 50)
		run = RunRules.tick(run, input(58)) -- next Countdown
		expect(run.left[2]).toBeNil()
		local fresh = RunRules.play(run, 2, 1, 1, 59)
		expect(p(fresh, 2).hp).toBe(100)
	end)

	it("gives a joiner after a leave a join index nobody else has", function()
		local run = waveRun({ 1, 2, 3 })
		run = RunRules.leave(run, 2)
		run = RunRules.play(run, 4, 1, 1, 5)
		expect(p(run, 4).joinIndex).toBe(4)
		run = RunRules.play(run, 2, 1, 1, 6)
		expect(p(run, 2).joinIndex).toBe(5)
	end)
end)

describe("RunRules edge cases (K)", function()
	it("drops a downed leaver from the defeat check", function()
		local run = waveRun({ 1, 2 })
		run = RunRules.damage(run, 2, 500, 4)
		run = RunRules.tick(run, input(7))
		run = RunRules.damage(run, 2, 500, 10)
		run = RunRules.leave(run, 2)
		expect(RunRules.defeated(run)).toBe(false)
		expect(#run.participants).toBe(1)
	end)

	it("keeps the run going when someone joins while everyone is downed", function()
		local run = waveRun({ 1 })
		run = RunRules.damage(run, 1, 500, 4)
		run = RunRules.tick(run, input(7))
		run = RunRules.damage(run, 1, 500, 10)
		run = RunRules.play(run, 2, 1, 1, 10)
		local next = RunRules.tick(run, input(10.1))
		expect(next.state).toBe("Wave")
	end)

	it("does not change its input", function()
		local run = waveRun({ 1 })
		RunRules.tick(run, input(10, true))
		RunRules.damage(run, 1, 10, 4)
		expect(run.state).toBe("Wave")
		expect(p(run, 1).hp).toBe(100)
	end)
end)
