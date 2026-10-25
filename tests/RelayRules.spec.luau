--!strict
local T = require("./framework")
local RelayRules = require("../src/shared/RelayRules")

local describe, it, expect = T.describe, T.it, T.expect

local function players(n: number): { number }
	local list = {}
	for i = 1, n do
		list[i] = 100 + i
	end
	return list
end

local function zone(...: number): { [number]: boolean }
	local set = {}
	for _, id in { ... } do
		set[id] = true
	end
	return set
end

local function team(id: number, finishedAt: number?, legsDone: number, distanceLeft: number): RelayRules.Team
	return {
		id = id,
		members = { id },
		ran = {},
		legsDone = legsDone,
		distanceLeft = distanceLeft,
		finishedAt = finishedAt,
	}
end

describe("RelayRules.assignTeams", function()
	it("keeps team sizes within 1 for 2 to 16 players", function()
		for n = 2, 16 do
			local teams = RelayRules.assignTeams(players(n))
			local smallest, largest, total = math.huge, 0, 0
			for _, t in teams do
				smallest = math.min(smallest, #t.members)
				largest = math.max(largest, #t.members)
				total += #t.members
			end
			expect(largest - smallest <= 1).toBe(true)
			expect(largest <= RelayRules.MAX_TEAM_SIZE).toBe(true)
			expect(#teams >= 2 and #teams <= RelayRules.MAX_TEAMS).toBe(true)
			expect(total).toBe(n)
		end
	end)
end)

describe("RelayRules.legsForRound", function()
	it("drops one leg per round and never goes below 2", function()
		expect(RelayRules.legsForRound(1, 4)).toBe(4)
		expect(RelayRules.legsForRound(2, 4)).toBe(3)
		expect(RelayRules.legsForRound(3, 4)).toBe(2)
		expect(RelayRules.legsForRound(9, 4)).toBe(2)
	end)
end)

describe("RelayRules baton", function()
	local function freshTeam(): RelayRules.Team
		local match = RelayRules.newMatch({ 1, 2, 3, 4, 5, 6 })
		RelayRules.startRound(match, 60)
		return match.teams[1] -- members 1, 3, 5; runner 1
	end

	it("passes only to a teammate in the zone who has not run", function()
		local t = freshTeam()
		expect(RelayRules.completeLeg(t, zone(2), 3, 60, 10)).toBe(false) -- 2 is on another team
		expect(RelayRules.completeLeg(t, zone(), 3, 60, 10)).toBe(false)
		expect(RelayRules.completeLeg(t, zone(5), 3, 60, 10)).toBe(true)
		expect(t.runner).toBe(5)
		expect(t.legsDone).toBe(1)
	end)

	it("never passes back to someone who already ran", function()
		local t = freshTeam()
		RelayRules.completeLeg(t, zone(3), 4, 60, 10)
		expect(RelayRules.completeLeg(t, zone(1), 4, 60, 20)).toBe(false)
	end)

	it("lets the runner keep the baton once everyone has run", function()
		local match = RelayRules.newMatch({ 1, 2, 3, 4 })
		RelayRules.startRound(match, 60)
		local t = match.teams[1] -- members 1, 3
		RelayRules.completeLeg(t, zone(3), 4, 60, 10)
		expect(RelayRules.completeLeg(t, zone(), 4, 60, 20)).toBe(true)
		expect(t.runner).toBe(3)
		expect(t.legsDone).toBe(2)
	end)

	it("finishes on the last leg and records the time", function()
		local t = freshTeam()
		RelayRules.completeLeg(t, zone(3), 2, 60, 10)
		expect(RelayRules.completeLeg(t, zone(), 2, 60, 25)).toBe(true)
		expect(t.finishedAt).toBe(25)
		expect(RelayRules.completeLeg(t, zone(5), 2, 60, 30)).toBe(false)
	end)
end)

describe("RelayRules.rank", function()
	it("puts finished teams first, earliest finish first", function()
		local ranked = RelayRules.rank({ team(1, nil, 3, 5), team(2, 50, 4, 0), team(3, 40, 4, 0) })
		expect(ranked[1].id).toBe(3)
		expect(ranked[2].id).toBe(2)
		expect(ranked[3].id).toBe(1)
	end)

	it("orders unfinished teams by legs done, then distance left", function()
		local ranked = RelayRules.rank({ team(1, nil, 1, 10), team(2, nil, 2, 50), team(3, nil, 1, 5) })
		expect(ranked[1].id).toBe(2)
		expect(ranked[2].id).toBe(3)
		expect(ranked[3].id).toBe(1)
	end)

	it("breaks exact ties by join order", function()
		local ranked = RelayRules.rank({ team(2, nil, 1, 10), team(1, nil, 1, 10) })
		expect(ranked[1].id).toBe(1)
		local finished = RelayRules.rank({ team(4, 30, 3, 0), team(3, 30, 3, 0) })
		expect(finished[2].id).toBe(4)
	end)
end)

describe("RelayRules rounds", function()
	it("ends a round when one team is left running or time is up", function()
		local match = RelayRules.newMatch(players(6))
		RelayRules.startRound(match, 60)
		expect(RelayRules.roundOver(match, 10, 90)).toBe(false)
		match.teams[1].finishedAt = 30
		expect(RelayRules.roundOver(match, 30, 90)).toBe(true)
		match.teams[1].finishedAt = nil
		expect(RelayRules.roundOver(match, 90, 90)).toBe(true)
	end)

	it("eliminates the last team and names a winner when one is left", function()
		local match = RelayRules.newMatch(players(4))
		RelayRules.startRound(match, 60)
		match.teams[1].finishedAt = 30
		expect(RelayRules.eliminateLast(match)).toBe(2)
		expect(match.over).toBe(true)
		expect(match.winner).toBe(1)
	end)
end)

describe("RelayRules.removePlayer", function()
	it("moves the baton to a teammate who has not run when the runner leaves", function()
		local match = RelayRules.newMatch({ 1, 2, 3, 4, 5, 6 })
		RelayRules.startRound(match, 60)
		expect(RelayRules.removePlayer(match, 1)).toBe(3)
		expect(match.teams[1].runner).toBe(3)
	end)

	it("gives the baton to any teammate when everyone has run", function()
		local match = RelayRules.newMatch({ 1, 2, 3, 4 })
		RelayRules.startRound(match, 60)
		local t = match.teams[1]
		RelayRules.completeLeg(t, zone(3), 4, 60, 10)
		expect(RelayRules.removePlayer(match, 3)).toBe(1)
	end)

	it("changes nothing when a waiting teammate leaves", function()
		local match = RelayRules.newMatch({ 1, 2, 3, 4, 5, 6 })
		RelayRules.startRound(match, 60)
		expect(RelayRules.removePlayer(match, 5)).toBeNil()
		expect(match.teams[1].runner).toBe(1)
		expect(#match.teams[1].members).toBe(2)
	end)

	it("eliminates a team that empties and ends the match at one team", function()
		local match = RelayRules.newMatch({ 1, 2, 3, 4 })
		RelayRules.startRound(match, 60)
		RelayRules.removePlayer(match, 2)
		expect(match.over).toBe(false)
		RelayRules.removePlayer(match, 4)
		expect(#match.teams).toBe(1)
		expect(match.over).toBe(true)
		expect(match.winner).toBe(1)
	end)

	it("ignores a player who is not in the match", function()
		local match = RelayRules.newMatch(players(4))
		expect(RelayRules.removePlayer(match, 999)).toBeNil()
		expect(#match.teams).toBe(2)
	end)
end)
