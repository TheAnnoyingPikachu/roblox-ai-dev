--!strict
-- Relay Rounds server (docs/game-design/relay-rounds-gdd.md). RelayRules decides every outcome;
-- this script only reads positions, builds the course and moves characters. Clients send nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local RelayRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RelayRules"))

local START_LEGS = 4
local LEG_LENGTH = 60
local ROUND_LIMIT = 90
local LOBBY_COUNTDOWN = 15
local COURSE_Y = 30
local FALL_Y = COURSE_Y - 10
local LANE_GAP = 20
local ZONE_RADIUS = 6
local TICK = 0.1

local TEAM_COLOURS = {
	BrickColor.new("Bright red"),
	BrickColor.new("Bright blue"),
	BrickColor.new("Lime green"),
	BrickColor.new("New Yeller"),
}

local status = Instance.new("StringValue")
status.Name = "RelayStatus"
status.Parent = ReplicatedStorage

local function say(text: string)
	status.Value = text
	print(`[Relay] {text}`)
end

local function rootOf(userId: number): BasePart?
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function teleport(userId: number, position: Vector3)
	local root = rootOf(userId)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
	end
end

local function laneX(teamId: number): number
	return 40 + (teamId - 1) * LANE_GAP
end

-- Leg k runs from z = legStart(k) to legStart(k + 1); handoff zone k sits at the end of leg k.
local function legStart(k: number): number
	return 50 + (k - 1) * LEG_LENGTH
end

local function zoneCentre(teamId: number, k: number): Vector3
	return Vector3.new(laneX(teamId), COURSE_Y, legStart(k + 1) - 4)
end

local function part(parent: Instance, size: Vector3, position: Vector3, colour: BrickColor, neon: boolean?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.BrickColor = colour
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- Primitive parts only (GDD F): each leg is three platforms with two jumps, then a handoff pad.
local function buildCourse(match: RelayRules.Match, legs: number): Folder
	local folder = Instance.new("Folder")
	folder.Name = "RelayCourse"
	for _, team in match.teams do
		local x = laneX(team.id)
		local colour = TEAM_COLOURS[team.id]
		for k = 1, legs do
			local z = legStart(k)
			for _, span in { { 0, 22 }, { 26, 40 }, { 44, LEG_LENGTH } } do
				local length = span[2] - span[1]
				part(
					folder,
					Vector3.new(10, 1, length),
					Vector3.new(x, COURSE_Y - 0.5, z + span[1] + length / 2),
					BrickColor.new("Medium stone grey")
				)
			end
			part(folder, Vector3.new(10, 0.2, 8), zoneCentre(team.id, k) + Vector3.new(0, 0.1, 0), colour, true)
		end
	end
	folder.Parent = Workspace
	return folder
end

local function inZone(userId: number, centre: Vector3): boolean
	local root = rootOf(userId)
	if root == nil then
		return false
	end
	local offset = root.Position - centre
	return math.abs(offset.X) <= ZONE_RADIUS and math.abs(offset.Z) <= ZONE_RADIUS and root.Position.Y > FALL_Y
end

local batons: { [number]: BasePart } = {}

local function giveBaton(team: RelayRules.Team)
	local baton = batons[team.id]
	if baton == nil then
		baton = Instance.new("Part")
		baton.Name = "Baton"
		baton.Size = Vector3.new(0.6, 3, 0.6)
		baton.BrickColor = TEAM_COLOURS[team.id]
		baton.Material = Enum.Material.Neon
		baton.CanCollide = false
		baton.Massless = true
		batons[team.id] = baton
	end
	local root = team.runner and rootOf(team.runner)
	if root == nil then
		return
	end
	baton:ClearAllChildren()
	baton.CFrame = root.CFrame * CFrame.new(1.5, 0, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = baton
	weld.Part1 = root
	weld.Parent = baton
	baton.Parent = root.Parent
end

-- Fresh teammates wait at the end of the runner's current leg.
local function placeWaiting(team: RelayRules.Team)
	for _, member in team.members do
		if not team.ran[member] then
			teleport(member, zoneCentre(team.id, team.legsDone + 1))
		end
	end
end

local function sendToLobby(userIds: { number })
	for _, userId in userIds do
		teleport(userId, Vector3.new(0, 0, 0))
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player.Team = nil
		end
	end
end

local match: RelayRules.Match? = nil

Players.PlayerRemoving:Connect(function(player)
	local current = match
	if current == nil then
		return
	end
	local newRunner = RelayRules.removePlayer(current, player.UserId)
	if newRunner ~= nil then
		for _, team in current.teams do
			if team.runner == newRunner then
				teleport(newRunner, Vector3.new(laneX(team.id), COURSE_Y, legStart(team.legsDone + 1) + 3))
				giveBaton(team)
			end
		end
	end
end)

local function playRound(current: RelayRules.Match)
	local legs = RelayRules.legsForRound(current.round + 1, START_LEGS)
	RelayRules.startRound(current, LEG_LENGTH)
	local course = buildCourse(current, legs)
	for _, team in current.teams do
		if team.runner then
			teleport(team.runner, Vector3.new(laneX(team.id), COURSE_Y, legStart(1) + 3))
			giveBaton(team)
		end
		placeWaiting(team)
	end
	say(`Round {current.round}: {legs} legs. Go!`)

	local started = os.clock()
	while not current.over and not RelayRules.roundOver(current, os.clock() - started, ROUND_LIMIT) do
		task.wait(TICK)
		for _, team in current.teams do
			local runner = team.runner
			if team.finishedAt == nil and runner ~= nil then
				local root = rootOf(runner)
				local leg = team.legsDone + 1
				local goal = zoneCentre(team.id, leg)
				if root and root.Position.Y < FALL_Y then
					teleport(runner, Vector3.new(laneX(team.id), COURSE_Y, legStart(leg) + 3))
				elseif inZone(runner, goal) then
					local waiting: { [number]: boolean } = {}
					for _, member in team.members do
						waiting[member] = member ~= runner and inZone(member, goal)
					end
					if RelayRules.completeLeg(team, waiting, legs, LEG_LENGTH, os.clock() - started) then
						giveBaton(team)
						placeWaiting(team)
					end
				elseif root then
					team.distanceLeft = math.max(0, goal.Z - root.Position.Z)
				end
			end
		end
	end

	if not current.over then
		local loserId = RelayRules.eliminateLast(current)
		local loserPlayers = {}
		for _, player in Players:GetPlayers() do
			if player.Team and player.Team.Name == `Team {loserId}` then
				table.insert(loserPlayers, player.UserId)
			end
		end
		sendToLobby(loserPlayers)
		say(`Team {loserId} is out!`)
	end
	course:Destroy()
	task.wait(3)
end

local function playMatch(userIds: { number })
	local current = RelayRules.newMatch(userIds)
	match = current
	Teams:ClearAllChildren()
	for _, team in current.teams do
		local robloxTeam = Instance.new("Team")
		robloxTeam.Name = `Team {team.id}`
		robloxTeam.TeamColor = TEAM_COLOURS[team.id]
		robloxTeam.AutoAssignable = false
		robloxTeam.Parent = Teams
		for _, userId in team.members do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				player.Team = robloxTeam
			end
		end
	end

	while not current.over do
		playRound(current)
	end
	say(if current.winner then `Team {current.winner} wins!` else "Match ended.")
	match = nil
	for _, baton in batons do
		baton:Destroy()
	end
	table.clear(batons)
	local everyone = {}
	for _, player in Players:GetPlayers() do
		table.insert(everyone, player.UserId)
	end
	sendToLobby(everyone)
	Teams:ClearAllChildren()
	task.wait(5)
end

while true do
	local count = #Players:GetPlayers()
	if count < RelayRules.MIN_PLAYERS then
		say(`Waiting for players ({count}/{RelayRules.MIN_PLAYERS})`)
		task.wait(1)
	else
		for remaining = LOBBY_COUNTDOWN, 1, -1 do
			say(`Match starts in {remaining}`)
			task.wait(1)
		end
		local userIds = {}
		for _, player in Players:GetPlayers() do
			table.insert(userIds, player.UserId)
		end
		if #userIds >= RelayRules.MIN_PLAYERS then
			playMatch(userIds)
		end
	end
end
