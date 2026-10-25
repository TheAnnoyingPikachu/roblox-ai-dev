--!strict
-- Relay Rounds server (docs/game-design/relay-rounds-gdd.md). RelayRules decides every outcome;
-- this script only reads positions, builds the course and moves characters. Clients send nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Teams = game:GetService("Teams")

local RelayRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RelayRules"))
local Course = require(script.Parent:WaitForChild("Course"))

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

-- Roblox's built-in sounds only (rbxasset://), so no asset register entry is needed.
local function sound(file: string, volume: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = `rbxasset://sounds/{file}`
	s.Volume = volume
	s.Parent = SoundService
	return s
end
local sounds = {
	tick = sound("volume_slider.ogg", 0.6),
	go = sound("action_jump_land.mp3", 1),
	out = sound("ouch.ogg", 0.8),
	win = sound("impact_explosion_03.mp3", 0.5),
}

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

local function inZone(userId: number, centre: Vector3): boolean
	local root = rootOf(userId)
	if root == nil then
		return false
	end
	local offset = root.Position - centre
	return math.abs(offset.X) <= Course.ZONE_RADIUS
		and math.abs(offset.Z) <= Course.ZONE_RADIUS
		and root.Position.Y > Course.FALL_Y
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
			teleport(member, Course.zoneCentre(team.id, team.legsDone + 1))
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

local function addWin(userIds: { number })
	for _, userId in userIds do
		local player = Players:GetPlayerByUserId(userId)
		local wins = player and player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Wins")
		if wins then
			(wins :: IntValue).Value += 1
		end
	end
end

-- shortcut: wins last for the session only; saving them needs a data schema decision record.
Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = leaderstats
	leaderstats.Parent = player
end)

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
				teleport(newRunner, Course.legSpawn(team.id, team.legsDone + 1))
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
	RelayRules.startRound(current, Course.LEG_LENGTH)
	local course = Course.build(teamIds(current), legs, current.round)
	for _, team in current.teams do
		if team.runner then
			teleport(team.runner, Course.legSpawn(team.id, 1))
			paint(team.runner, Course.TEAM_COLOURS[team.id])
			giveBaton(team)
		end
		for _, member in team.members do
			paint(member, Course.TEAM_COLOURS[team.id])
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
				local goal = Course.zoneCentre(team.id, leg)
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
				if root and root.Position.Y < Course.FALL_Y then
					teleport(runner, Course.legSpawn(team.id, leg))
					paint(runner, Course.TEAM_COLOURS[team.id])
					giveBaton(team)
				elseif root and root.Parent and root.Parent:FindFirstChild("Baton") == nil then
					giveBaton(team)
				elseif inZone(runner, goal) then
					local waiting: { [number]: boolean } = {}
					for _, member in team.members do
						waiting[member] = member ~= runner and inZone(member, goal)
					end
					if RelayRules.completeLeg(team, waiting, legs, Course.LEG_LENGTH, os.clock() - started) then
						sounds.go:Play()
						if team.finishedAt ~= nil then
							say(`Team {team.id} finished!`)
						end
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
	if current.winner then
		addWin(current.teams[1].members)
		sounds.win:Play()
		say(`Team {current.winner} wins!`)
	else
		say("Match ended.")
	end
	match = nil
	clearBatons()
	task.wait(4)
	local everyone = {}
	for _, player in Players:GetPlayers() do
		table.insert(everyone, player.UserId)
	end
	sendToLobby(everyone)
	Teams:ClearAllChildren()
end

Course.buildLobby()

while true do
	local count = #Players:GetPlayers()
	if count < RelayRules.MIN_PLAYERS then
		say(`Waiting for players ({count}/{RelayRules.MIN_PLAYERS}). Try the practice lane!`)
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
