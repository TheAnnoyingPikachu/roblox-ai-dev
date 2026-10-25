--!strict
-- Pure Relay Rounds rules (docs/game-design/relay-rounds-gdd.md). No Roblox APIs, so Lune
-- can unit-test them headlessly. Players are identified by UserId; the server decides everything.

local RelayRules = {}

export type Team = {
	id: number,
	members: { number },
	ran: { [number]: boolean },
	runner: number?,
	legsDone: number,
	distanceLeft: number,
	finishedAt: number?,
}

export type Match = {
	teams: { Team },
	round: number,
	over: boolean,
	winner: number?,
}

RelayRules.MIN_PLAYERS = 4
RelayRules.MAX_TEAMS = 4
RelayRules.MAX_TEAM_SIZE = 4
RelayRules.MIN_LEGS = 2

local function newTeam(id: number): Team
	return { id = id, members = {}, ran = {}, runner = nil, legsDone = 0, distanceLeft = 0, finishedAt = nil }
end

-- Splits players (in join order) into 2-4 teams whose sizes differ by at most 1 (GDD B.2).
function RelayRules.assignTeams(players: { number }): { Team }
	local count = math.clamp(math.ceil(#players / RelayRules.MAX_TEAM_SIZE), 2, RelayRules.MAX_TEAMS)
	local teams = {}
	for id = 1, count do
		teams[id] = newTeam(id)
	end
	for i, player in players do
		table.insert(teams[(i - 1) % count + 1].members, player)
	end
	return teams
end

function RelayRules.newMatch(players: { number }): Match
	return { teams = RelayRules.assignTeams(players), round = 0, over = false, winner = nil }
end

-- The course loses one leg per round but never drops below MIN_LEGS (GDD B.5).
function RelayRules.legsForRound(round: number, startLegs: number): number
	return math.max(RelayRules.MIN_LEGS, startLegs - (round - 1))
end

-- Resets every team for a new round; the first member runs leg 1.
function RelayRules.startRound(match: Match, legLength: number)
	match.round += 1
	for _, team in match.teams do
		team.ran = {}
		team.runner = team.members[1]
		if team.runner ~= nil then
			team.ran[team.runner] = true
		end
		team.legsDone = 0
		team.distanceLeft = legLength
		team.finishedAt = nil
	end
end

-- Who holds the baton for the next leg, given the teammates standing in the handoff zone.
-- Only a teammate who hasn't run this round can take it; if everyone has run, the runner keeps it (GDD C).
function RelayRules.nextRunner(team: Team, inZone: { [number]: boolean }): number?
	local fresh = false
	for _, member in team.members do
		if not team.ran[member] then
			fresh = true
			if inZone[member] then
				return member
			end
		end
	end
	if fresh then
		return nil -- someone still has to run: wait for them in the zone
	end
	return team.runner
end

-- Called when the runner reaches the end of their leg inside the handoff zone.
-- Returns true if the leg counted (baton passed, kept or team finished).
function RelayRules.completeLeg(
	team: Team,
	inZone: { [number]: boolean },
	legs: number,
	legLength: number,
	now: number
): boolean
	if team.finishedAt ~= nil or team.runner == nil then
		return false
	end
	if team.legsDone + 1 >= legs then
		team.legsDone = legs
		team.distanceLeft = 0
		team.finishedAt = now
		return true
	end
	local nextUp = RelayRules.nextRunner(team, inZone)
	if nextUp == nil then
		return false
	end
	team.legsDone += 1
	team.distanceLeft = legLength
	team.runner = nextUp
	team.ran[nextUp] = true
	return true
end

-- True when a team ranks below another (GDD D). Lower team id = in the match longer, so it is safe.
local function ranksBelow(a: Team, b: Team): boolean
	if (a.finishedAt ~= nil) ~= (b.finishedAt ~= nil) then
		return a.finishedAt == nil
	end
	if a.finishedAt ~= nil and b.finishedAt ~= nil and a.finishedAt ~= b.finishedAt then
		return a.finishedAt > b.finishedAt
	end
	if a.finishedAt == nil then
		if a.legsDone ~= b.legsDone then
			return a.legsDone < b.legsDone
		end
		if a.distanceLeft ~= b.distanceLeft then
			return a.distanceLeft > b.distanceLeft
		end
	end
	return a.id > b.id
end

-- Teams best first.
function RelayRules.rank(teams: { Team }): { Team }
	local sorted = table.clone(teams)
	table.sort(sorted, function(a, b)
		return ranksBelow(b, a)
	end)
	return sorted
end

-- The round ends when at most one team is still running or time is up (GDD B.4).
function RelayRules.roundOver(match: Match, elapsed: number, limit: number): boolean
	if elapsed >= limit then
		return true
	end
	local running = 0
	for _, team in match.teams do
		if team.finishedAt == nil then
			running += 1
		end
	end
	return running <= 1
end

local function settle(match: Match)
	if #match.teams <= 1 then
		match.over = true
		match.winner = if match.teams[1] then match.teams[1].id else nil
	end
end

-- Removes the last-ranked team. Returns its id.
function RelayRules.eliminateLast(match: Match): number
	local ranked = RelayRules.rank(match.teams)
	local loser = ranked[#ranked]
	table.remove(match.teams, table.find(match.teams, loser))
	settle(match)
	return loser.id
end

-- Handles a player leaving mid-match (GDD E). Returns the new runner if the baton moved, so the
-- server can respawn them at the start of the current leg.
function RelayRules.removePlayer(match: Match, player: number): number?
	for index, team in match.teams do
		local slot = table.find(team.members, player)
		if slot ~= nil then
			table.remove(team.members, slot)
			team.ran[player] = nil
			if #team.members == 0 then
				table.remove(match.teams, index)
				settle(match)
				return nil
			end
			if team.runner == player then
				local nextUp = team.members[1]
				for _, member in team.members do
					if not team.ran[member] then
						nextUp = member
						break
					end
				end
				team.runner = nextUp
				team.ran[nextUp] = true
				return nextUp
			end
			return nil
		end
	end
	return nil
end

return RelayRules
