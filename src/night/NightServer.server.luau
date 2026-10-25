--!strict
-- Hundred Demon Night server (docs/game-design/game3-gdd.md, docs/architecture/night.md 4).
-- Server-authoritative: RunRules, CombatRules, WaveRules, BossRules and NightProgress decide every
-- outcome. This script owns the 10 Hz tick (night.md 4.3), routes the Request remote with the
-- common checks of decision 0007, handles run events and publishes NightStatus and attributes.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatRules = require(Shared:WaitForChild("CombatRules"))
local NightProgress = require(Shared:WaitForChild("NightProgress"))
local Rng = require(Shared:WaitForChild("Rng"))
local RunRules = require(Shared:WaitForChild("RunRules"))
local StyleRules = require(Shared:WaitForChild("StyleRules"))
local Arena = require(script.Parent:WaitForChild("Arena"))
local Combat = require(script.Parent:WaitForChild("Combat"))
local Enemies = require(script.Parent:WaitForChild("Enemies"))
local Gear = require(script.Parent:WaitForChild("Gear"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local State = require(script.Parent:WaitForChild("State"))

local TICK = 0.1
local REQUEST_COOLDOWN = 0.35
local MAX_ARG = 32
local BOARD_REFRESH = 60
local BASE_HEALTH = 100
local LIVE = { Countdown = true, Wave = true, Break = true }
local TIMED = { Countdown = true, Break = true, Victory = true, Defeat = true }
local BOSS_WAVES = { [5] = true, [10] = true }

-- Request actions (decision 0007): true takes a string argument, false takes none.
local REQUEST_ARGS: { [string]: boolean } = {
	play = false,
	leaveRun = false,
	pickBlessing = true,
	setTier = true,
	equipWeapon = true,
	claimDaily = false,
	claimWeekly = false,
	claimQuest = true,
	buyCosmetic = true,
	equipCosmetic = true,
}
local PICKS: { [string]: number } = { ["1"] = 1, ["2"] = 2, ["3"] = 3 }

local lastRequest: { [Player]: number } = {}
local published: { [Player]: { [string]: any } } = {}

local function freshSeed(): number
	return Random.new():NextInteger(1, 2 ^ 31 - 1)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function at(userId: number): Vector3?
	local pos = State.positions[userId]
	return if pos then Vector3.new(pos.x, pos.y, pos.z) else nil
end

-- Writes an attribute only when its value changed (night.md 4.3 step 6).
local function setAttr(player: Player, name: string, value: any)
	local cache = published[player]
	if cache == nil then
		cache = {}
		published[player] = cache
	end
	if cache[name] ~= value then
		cache[name] = value
		player:SetAttribute(name, value)
	end
end

-- Participants line up at the shrine entrance, facing the stage.
local function placeAtSpawn(player: Player, index: number)
	local root = rootOf(player)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = Arena.SPAWN * CFrame.new((index - 3.5) * 4, 4, 0)
	end
end

local function enter(player: Player, index: number)
	Gear.give(player)
	Combat.join(player)
	placeAtSpawn(player, index)
end

local function clearRunAttributes(player: Player)
	for name, value in
		{
			Gauge = 0,
			StyleRank = 1,
			StylePoints = 0,
			Charms = 0,
			Trigger = false,
			Blessings = "{}",
			Offers = "[]",
		} :: { [string]: any }
	do
		setAttr(player, name, value)
	end
	setAttr(player, "HP", nil)
	setAttr(player, "MaxHP", nil)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = BASE_HEALTH
		humanoid.Health = BASE_HEALTH
	end
end

-- Run events (night.md 4.3 step 5) ----------------------------------------------------------

local function handleEvents(events: { RunRules.Event }, t: number)
	local run = State.run
	for _, event in events do
		local kind = event.kind
		if kind == "countdown" then
			for _, p in run.participants do
				local player = Players:GetPlayerByUserId(p.userId)
				if player then
					enter(player, p.joinIndex)
				end
			end
		elseif kind == "wave" then
			local w = event.wave or run.wave
			Enemies.startWave(w, event.n or run.n, run.tier, Rng.seed(run.seed, 0, w), t)
		elseif kind == "cleared" then
			local w = event.wave or run.wave
			for _, p in run.participants do
				local player = Players:GetPlayerByUserId(p.userId)
				local tally = Combat.takeTally(p.userId)
				if player then
					Profiles.recordWave(player, {
						wave = w,
						tier = run.tier,
						n = event.n or #run.participants,
						first = p.clears == 1,
						tally = tally,
					})
				end
			end
			Enemies.clear()
		elseif kind == "victory" then
			for _, p in run.participants do
				local player = Players:GetPlayerByUserId(p.userId)
				if player then
					Profiles.recordVictory(player, run.tier)
				end
			end
			Arena.celebrate()
		elseif kind == "defeat" or kind == "idle" then
			Enemies.clear()
		elseif kind == "revive" and event.userId then
			Remotes.fx("revive", { u = event.userId, by = event.by, p = at(event.userId) })
		elseif kind == "down" and event.userId then
			Remotes.fx("down", { u = event.userId, p = at(event.userId) })
		end
	end
end

-- Leaving (leaveRun, opening the menu, disconnecting): GDD B2, K.
local function leave(player: Player): boolean
	if RunRules.find(State.run, player.UserId) == nil then
		return false
	end
	local events
	State.run, events = RunRules.leave(State.run, player.UserId)
	Combat.remove(player)
	Gear.strip(player)
	clearRunAttributes(player)
	handleEvents(events, os.clock())
	return true
end

-- Request remote (decision 0007) ------------------------------------------------------------

local function onRequest(player: Player, action: any, arg: any): boolean
	local profile = Profiles.get(player)
	if profile == nil or type(action) ~= "string" or (arg ~= nil and (type(arg) ~= "string" or #arg > MAX_ARG)) then
		return false
	end
	local now = os.clock()
	-- Refused requests inside the cooldown do not reset it.
	if now - (lastRequest[player] or -math.huge) < REQUEST_COOLDOWN then
		return false
	end
	lastRequest[player] = now
	local takesArg = REQUEST_ARGS[action]
	if takesArg == nil or takesArg ~= (arg ~= nil) then
		return false
	end
	local userId = player.UserId
	if action == "play" then
		local ok
		State.run, ok = RunRules.play(State.run, userId, NightProgress.tierFor(profile), freshSeed(), now)
		-- From Idle the accepted play is the countdown (RunRules.play emits no events); in Victory
		-- or Defeat the next "countdown" event brings the player in.
		local p = RunRules.find(State.run, userId)
		if ok and p and LIVE[State.run.state] then
			enter(player, p.joinIndex)
		end
		return ok
	elseif action == "leaveRun" then
		return leave(player)
	elseif action == "pickBlessing" then
		local choice = PICKS[arg]
		if choice == nil then
			return false
		end
		local ok
		State.run, ok = RunRules.pick(State.run, userId, choice)
		return ok
	elseif action == "equipWeapon" and RunRules.find(State.run, userId) then
		return false -- weapons are fixed for the run (C1)
	end
	return Profiles.request(player, action, arg)
end
Remotes.Request.OnServerInvoke = onRequest

-- Publishing (night.md 4.3 step 6) ----------------------------------------------------------

local lastStatus = ""
local lastState = ""

local function publish(t: number)
	local run = State.run
	local ids = {}
	for _, p in run.participants do
		table.insert(ids, p.userId)
		local player = Players:GetPlayerByUserId(p.userId)
		if player then
			setAttr(player, "HP", p.hp)
			setAttr(player, "MaxHP", p.maxHp)
			setAttr(player, "Charms", p.charms)
			setAttr(player, "Blessings", HttpService:JSONEncode(p.stacks))
			setAttr(player, "Offers", HttpService:JSONEncode(p.offer))
			local entry = Combat.get(p.userId)
			if entry then
				setAttr(player, "Gauge", math.floor(entry.fighter.gauge))
				setAttr(player, "StyleRank", StyleRules.rank(entry.style.points))
				setAttr(player, "StylePoints", math.floor(entry.style.points))
				setAttr(player, "Trigger", CombatRules.triggerActive(entry.fighter, t))
			end
			-- The Humanoid stays alive: health mirrors HP but never reaches 0 (C8).
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local health = math.max(1, p.hp)
				if humanoid.MaxHealth ~= p.maxHp then
					humanoid.MaxHealth = p.maxHp
				end
				if humanoid.Health ~= health then
					humanoid.Health = health
				end
			end
		end
	end
	local status = {
		state = run.state,
		wave = run.wave,
		tier = run.tier,
		left = if TIMED[run.state] then math.max(0, math.ceil(run.endsAt - t - 1e-6)) else 0,
		ids = ids,
		host = run.host,
		boss = if run.state == "Wave" and BOSS_WAVES[run.wave] then Enemies.bossFraction() else nil,
	}
	local json = HttpService:JSONEncode(status)
	if json ~= lastStatus then
		lastStatus = json
		Remotes.Status.Value = json
	end
	if run.state ~= lastState then
		lastState = run.state
		Arena.idle(run.state == "Idle")
	end
end

-- The 10 Hz tick (night.md 4.3) -------------------------------------------------------------

local function tick()
	local t = os.clock()
	Combat.sample(t)
	for _, hurt in Enemies.step(t, TICK) do
		local result
		State.run, result = RunRules.damage(State.run, hurt.userId, hurt.amount, t)
		local p = at(hurt.userId)
		if result == "dodge" then
			Combat.dodged(hurt.userId)
			Remotes.fx("dodge", { u = hurt.userId, p = p })
		elseif result == "hit" or result == "down" then
			Combat.resetStyle(hurt.userId)
			Remotes.fx("hurt", { u = hurt.userId, a = hurt.amount, p = p })
			if result == "down" then
				Remotes.fx("down", { u = hurt.userId, p = p })
			end
		end
	end
	Combat.step(t, TICK)
	local host = State.run.host and Players:GetPlayerByUserId(State.run.host)
	local hostProfile = host and Profiles.get(host)
	local events
	State.run, events = RunRules.tick(State.run, {
		t = t,
		dt = TICK,
		cleared = Enemies.cleared(),
		hostTier = if hostProfile then NightProgress.tierFor(hostProfile) else 1,
		seed = freshSeed(),
		positions = State.positions,
	})
	handleEvents(events, t)
	publish(t)
end

local accumulated = 0
local busy = false
RunService.Heartbeat:Connect(function(dt: number)
	accumulated += dt
	if busy or accumulated < TICK then
		return
	end
	accumulated = math.min(accumulated - TICK, TICK) -- drop a backlog instead of bursting ticks
	busy = true
	local ok, err = pcall(tick)
	busy = false
	if not ok then
		warn(`[NightServer] tick failed: {tostring(err)}`)
	end
end)

-- Players -----------------------------------------------------------------------------------

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid == nil then
		return
	end
	humanoid.BreakJointsOnDeath = false
	-- HP is the server's own number; the default regeneration script would fight the mirror.
	local regen = character:WaitForChild("Health", 2)
	if regen and regen:IsA("Script") then
		regen:Destroy()
	end
	character:WaitForChild("HumanoidRootPart", 10)
	if RunRules.find(State.run, player.UserId) then
		Gear.give(player)
	end
end

local function onPlayer(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in { "Level", "Nights" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = leaderstats
	end
	leaderstats.Parent = player
	clearRunAttributes(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	Profiles.load(player)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	leave(player)
	Profiles.release(player)
	lastRequest[player] = nil
	published[player] = nil
end)

-- A new blade or mask equipped mid-run shows at once (Gear.give is a no-op when unchanged).
Profiles.Changed:Connect(function(player: Player)
	if RunRules.find(State.run, player.UserId) then
		Gear.give(player)
	end
end)

Arena.build()
task.spawn(function()
	while true do
		Arena.update(Profiles.topWins())
		task.wait(BOARD_REFRESH)
	end
end)
