--!strict
-- Relay Rounds server (docs/game-design/relay-rounds-gdd.md). RelayRules decides every outcome;
-- this script only reads positions, builds the course and moves characters. The only client request
-- is the profile Request remote in Profiles (decision 0006); nothing a client sends affects a race.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local RelayRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RelayRules"))
local Course = require(script.Parent:WaitForChild("Course"))
local Scenery = require(script.Parent:WaitForChild("Scenery"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local ProgressRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressRules"))

local START_LEGS = 4
local ROUND_LIMIT = 90
local LOBBY_COUNTDOWN = 15
local GO_COUNTDOWN = 3
local TICK = 0.1

local status = Instance.new("StringValue")
status.Name = "RelayStatus"
status.Parent = ReplicatedStorage

local function say(text: string)
	status.Value = text
end

-- Licensed Pro Sound Effects (docs/assets/register.md) plus one Roblox built-in sound.
local function sound(id: string, volume: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = SoundService
	return s
end
local sounds = {
	tick = sound("rbxassetid://9117060347", 0.7),
	go = sound("rbxassetid://9125585534", 0.6),
	leg = sound("rbxassetid://9114373663", 0.8),
	out = sound("rbxasset://sounds/ouch.ogg", 0.8),
	win = sound("rbxassetid://9114630316", 0.7),
}

local function rootOf(userId: number): BasePart?
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function teleport(userId: number, target: Vector3 | CFrame)
	local root = rootOf(userId)
	if root then
		local cf = if typeof(target) == "CFrame" then target else CFrame.new(target)
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = cf + Vector3.new(0, 4, 0)
	end
end

-- The leg count of the round in progress; the course geometry depends on it.
local currentLegs = START_LEGS

-- Paints a character in the team colour (GDD B.2). Respawning restores the player's own look.
local function paint(userId: number, colour: BrickColor)
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	if character == nil then
		return
	end
	for _, item in character:GetChildren() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and item.Name ~= "Baton" then
			item.BrickColor = colour
		elseif item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
			item:Destroy()
		end
	end
end

-- The equipped trail (decision 0006), or the team colour for "team" (white in the lobby).
local function trailColours(player: Player): ColorSequence
	local profile = Profiles.get(player)
	local t = profile and ProgressRules.trail(profile.trail)
	if t and #t.colours > 0 then
		local keypoints = {}
		for i, rgb in t.colours do
			local at = if #t.colours == 1 then 0 else (i - 1) / (#t.colours - 1)
			table.insert(keypoints, ColorSequenceKeypoint.new(at, Color3.fromRGB(rgb[1], rgb[2], rgb[3])))
		end
		if #keypoints == 1 then
			table.insert(keypoints, ColorSequenceKeypoint.new(1, keypoints[1].Value))
		end
		return ColorSequence.new(keypoints)
	end
	return ColorSequence.new(if player.Team then player.Team.TeamColor.Color else Color3.new(1, 1, 1))
end

-- A streak behind every player, recoloured whenever their team or equipped trail changes.
local function trail(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	local root = rootOf(userId)
	if player == nil or root == nil then
		return
	end
	local existing = root:FindFirstChild("RelayTrail") :: Trail?
	if existing then
		existing.Color = trailColours(player)
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = root
	local t = Instance.new("Trail")
	t.Name = "RelayTrail"
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = trailColours(player)
	t.LightEmission = 0.7
	t.Lifetime = 0.4
	t.Transparency = NumberSequence.new(0.15, 1)
	t.Parent = root
end

local hazardParams = OverlapParams.new()
hazardParams.FilterType = Enum.RaycastFilterType.Include

-- True if the player's body overlaps a live hazard (laser gate or sweeper) on the course.
local function hitHazard(userId: number): boolean
	local root = rootOf(userId)
	if root == nil then
		return false
	end
	for _, hit in Workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(3, 5, 2), hazardParams) do
		if hit:GetAttribute("Active") ~= false then
			return true
		end
	end
	return false
end

local function inZone(userId: number, centre: Vector3): boolean
	local root = rootOf(userId)
	if root == nil then
		return false
	end
	local offset = root.Position - centre
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Course.ZONE_RADIUS and math.abs(offset.Y) < 8
end

local batons: { [number]: BasePart } = {}

-- A fresh baton each time: the old one is destroyed with the character when the runner respawns.
local function giveBaton(team: RelayRules.Team)
	local root = team.runner and rootOf(team.runner)
	if root == nil then
		return
	end
	if batons[team.id] then
		batons[team.id]:Destroy()
	end
	local baton = Instance.new("Part")
	baton.Name = "Baton"
	baton.Size = Vector3.new(0.6, 3, 0.6)
	baton.BrickColor = Course.TEAM_COLOURS[team.id]
	baton.Material = Enum.Material.Neon
	baton.CanCollide = false
	baton.Massless = true
	batons[team.id] = baton
	baton.CFrame = root.CFrame * CFrame.new(1.5, 0, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = baton
	weld.Part1 = root
	weld.Parent = baton
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = baton.Color
	sparkle.Parent = baton
	baton.Parent = root.Parent
end

local function clearBatons()
	for _, baton in batons do
		baton:Destroy()
	end
	table.clear(batons)
end

-- Fresh teammates wait at the end of the runner's current leg.
local function placeWaiting(team: RelayRules.Team)
	for _, member in team.members do
		if not team.ran[member] then
			teleport(member, Course.zoneCentre(team.id, team.legsDone + 1, currentLegs))
		end
	end
end

-- Back to the lobby with their own look: respawning resets colours and drops any baton.
local function sendToLobby(userIds: { number })
	for _, userId in userIds do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player.Team = nil
			player:LoadCharacter()
		end
	end
end

-- Racers pass through each other, as in most Roblox racing games, so nobody can body-block a lane.
PhysicsService:RegisterCollisionGroup("Racers")
PhysicsService:CollisionGroupSetCollidable("Racers", "Racers", false)
local function ghost(character: Model)
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") then
			item.CollisionGroup = "Racers"
		end
	end
	character.DescendantAdded:Connect(function(item)
		if item:IsA("BasePart") then
			item.CollisionGroup = "Racers"
		end
	end)
end

local function onCharacter(player: Player, character: Model)
	ghost(character)
	character:WaitForChild("HumanoidRootPart", 10)
	trail(player.UserId)
end

Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in { "Level", "Wins" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = leaderstats
	end
	leaderstats.Parent = player
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	Profiles.load(player)
end)

Profiles.Changed:Connect(function(player: Player)
	trail(player.UserId)
end)

local match: RelayRules.Match? = nil

-- Per-player numbers for this match, for XP and quests (server-counted only).
type Stats = { legs: number, rounds: number }
local matchStats: { [number]: Stats } = {}

Players.PlayerRemoving:Connect(function(player)
	Profiles.release(player)
	local current = match
	if current == nil then
		return
	end
	local newRunner = RelayRules.removePlayer(current, player.UserId)
	if newRunner ~= nil then
		for _, team in current.teams do
			if team.runner == newRunner then
				teleport(newRunner, Course.spawnFrame(team.id, team.legsDone + 1, currentLegs))
				giveBaton(team)
			end
		end
	end
end)

local function teamIds(current: RelayRules.Match): { number }
	local ids = {}
	for _, team in current.teams do
		table.insert(ids, team.id)
	end
	return ids
end

local function playRound(current: RelayRules.Match)
	local legs = RelayRules.legsForRound(current.round + 1, START_LEGS)
	currentLegs = legs
	RelayRules.startRound(current, Course.sectorLength(legs))
	local course = Course.build(teamIds(current), legs, current.round)
	local hazards = {}
	for _, d in course:GetDescendants() do
		if d:GetAttribute("Hazard") then
			table.insert(hazards, d)
		end
	end
	hazardParams.FilterDescendantsInstances = hazards
	for _, team in current.teams do
		if team.runner then
			teleport(team.runner, Course.spawnFrame(team.id, 1, legs))
			paint(team.runner, Course.TEAM_COLOURS[team.id])
			giveBaton(team)
		end
		for _, member in team.members do
			paint(member, Course.TEAM_COLOURS[team.id])
			trail(member)
		end
		placeWaiting(team)
	end
	for remaining = GO_COUNTDOWN, 1, -1 do
		say(`Round {current.round}: {legs} legs. Get ready… {remaining}`)
		sounds.tick:Play()
		task.wait(1)
	end
	sounds.go:Play()

	local started = os.clock()
	local shownLeft = -1
	while not current.over and not RelayRules.roundOver(current, os.clock() - started, ROUND_LIMIT) do
		task.wait(TICK)
		local left = math.ceil(ROUND_LIMIT - (os.clock() - started))
		if left ~= shownLeft then
			shownLeft = left
			say(`Round {current.round}: {legs} legs, {left}s left`)
		end
		for _, team in current.teams do
			local runner = team.runner
			if team.finishedAt == nil and runner ~= nil then
				local root = rootOf(runner)
				local leg = team.legsDone + 1
				local goal = Course.zoneCentre(team.id, leg, legs)
				-- Teammates still to run who fell or respawned go back to their handoff pad.
				for _, member in team.members do
					local memberRoot = rootOf(member)
					if
						member ~= runner
						and not team.ran[member]
						and memberRoot
						and memberRoot.Position.Y < Course.FALL_Y
					then
						teleport(member, goal)
						paint(member, Course.TEAM_COLOURS[team.id])
					end
				end
				if root and (root.Position.Y < Course.FALL_Y or hitHazard(runner)) then
					if root.Position.Y >= Course.FALL_Y then
						sounds.out:Play()
					end
					teleport(runner, Course.spawnFrame(team.id, leg, legs))
					paint(runner, Course.TEAM_COLOURS[team.id])
					giveBaton(team)
				elseif root and root.Parent and root.Parent:FindFirstChild("Baton") == nil then
					giveBaton(team)
				elseif inZone(runner, goal) then
					local waiting: { [number]: boolean } = {}
					for _, member in team.members do
						waiting[member] = member ~= runner and inZone(member, goal)
					end
					if RelayRules.completeLeg(team, waiting, legs, Course.sectorLength(legs), os.clock() - started) then
						local stats = matchStats[runner]
						if stats then
							stats.legs += 1
						end
						sounds.leg:Play()
						if team.finishedAt ~= nil then
							say(`Team {team.id} finished!`)
						end
						giveBaton(team)
						placeWaiting(team)
					end
				elseif root then
					team.distanceLeft = Course.distanceLeft(root.Position, leg, legs)
				end
			end
		end
	end

	if not current.over then
		local ranked = RelayRules.rank(current.teams)
		local loser = ranked[#ranked]
		local loserIds = table.clone(loser.members)
		RelayRules.eliminateLast(current)
		if batons[loser.id] then
			batons[loser.id]:Destroy()
			batons[loser.id] = nil
		end
		for _, userId in loserIds do
			teleport(userId, Course.STANDS)
		end
		sounds.out:Play()
		say(`Team {loser.id} is out!`)
	end
	for _, team in current.teams do
		for _, userId in team.members do
			local stats = matchStats[userId]
			if stats then
				stats.rounds += 1
			end
		end
	end
	course:Destroy()
	task.wait(3)
end

local function playMatch(userIds: { number })
	local current = RelayRules.newMatch(userIds)
	match = current
	table.clear(matchStats)
	for _, userId in userIds do
		matchStats[userId] = { legs = 0, rounds = 0 }
	end
	Teams:ClearAllChildren()
	for _, team in current.teams do
		local robloxTeam = Instance.new("Team")
		robloxTeam.Name = `Team {team.id}`
		robloxTeam.TeamColor = Course.TEAM_COLOURS[team.id]
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
	local winners: { number } = if current.winner and current.teams[1]
		then table.clone(current.teams[1].members)
		else {}
	match = nil
	clearBatons()
	for userId, stats in matchStats do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			Profiles.recordMatch(player, {
				legs = stats.legs,
				roundsSurvived = stats.rounds,
				won = table.find(winners, userId) ~= nil,
			})
		end
	end
	if current.winner then
		sounds.win:Play()
		say(`Team {current.winner} wins!`)
		-- Winners take the podium in the lobby for the celebration.
		for i, userId in winners do
			teleport(userId, Course.podiumSpot(i))
		end
		Course.celebrate()
		task.wait(6)
	else
		say("Match ended.")
		task.wait(4)
	end
	local everyone = {}
	for _, player in Players:GetPlayers() do
		table.insert(everyone, player.UserId)
	end
	sendToLobby(everyone)
	Teams:ClearAllChildren()
end

Scenery.lighting()
Scenery.world()
Course.buildTrack()
Course.buildLobby()
task.spawn(function()
	while true do
		Course.updateBoard(Profiles.topWins())
		task.wait(60)
	end
end)

while true do
	local count = #Players:GetPlayers()
	if count < RelayRules.MIN_PLAYERS then
		say(`Waiting for players ({count}/{RelayRules.MIN_PLAYERS}). Run the circuit while you wait!`)
		task.wait(1)
	else
		local cancelled = false
		for remaining = LOBBY_COUNTDOWN, 1, -1 do
			if #Players:GetPlayers() < RelayRules.MIN_PLAYERS then
				cancelled = true
				break
			end
			say(`Match starts in {remaining}`)
			if remaining <= 3 then
				sounds.tick:Play()
			end
			task.wait(1)
		end
		local userIds = {}
		for _, player in Players:GetPlayers() do
			table.insert(userIds, player.UserId)
		end
		if not cancelled and #userIds >= RelayRules.MIN_PLAYERS then
			playMatch(userIds)
		end
	end
end
