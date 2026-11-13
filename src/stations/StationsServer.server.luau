--!strict
-- Animal Stations server entry: builds the world, gives each player a home ranch (lowest free of
-- World.RANCHES, owners spawn at its gate), teleports players between their ranch and the hub,
-- loads saves (kit Saves), sells eggs at the hub's stalls, and routes team and training requests
-- (kit Router). The client only names an action; prices, hatches and timings are decided here.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Creatures = require(script.Parent:WaitForChild("Creatures"))
local World = require(script.Parent:WaitForChild("World"))

World.build()

-- Max Players is a place setting a place file cannot carry: set it to 3 when publishing.
if Players.MaxPlayers > World.RANCHES then
	warn(`[StationsServer] Max Players {Players.MaxPlayers} is above the {World.RANCHES} ranches`)
end

local owners: { [number]: Player } = {}

local function ranchOf(player: Player): number?
	for i, p in owners do
		if p == player then
			return i
		end
	end
	return nil
end

local function toRanch(player: Player)
	local i = ranchOf(player)
	if i and player.Character then
		player.Character:PivotTo(World.ranchSpawn(i))
	end
end

local function join(player: Player)
	for i = 1, World.RANCHES do
		if owners[i] == nil then
			owners[i] = player
			player:SetAttribute("Ranch", i)
			World.setRanchOwner(i, player)
			break
		end
	end
	-- no free ranch (only when Max Players is above 3): the player stays at the hub spawn
	local function spawned(character: Model)
		character:WaitForChild("HumanoidRootPart")
		task.wait() -- the SpawnLocation places the character after CharacterAdded; move it after that
		toRanch(player)
	end
	player.CharacterAdded:Connect(spawned)
	if player.Character then
		task.spawn(spawned, player.Character)
	end
end

-- Teleport pads: the hub pad sends a player to their own ranch, a ranch pad to the hub. The
-- ranches are far away, so the area is asked for first; the move still happens if that fails.
for _, prompt in CollectionService:GetTagged("Teleport") do
	(prompt :: ProximityPrompt).Triggered:Connect(function(player)
		local i = ranchOf(player)
		local to = if prompt:GetAttribute("To") == "hub" then World.hubSpawn() elseif i then World.ranchSpawn(i) else nil
		local character = player.Character
		if to and character then
			pcall(player.RequestStreamAroundAsync, player, to.Position)
			character:PivotTo(to)
		end
	end)
end

-- Saves, eggs, team and training (decision 0025) ---------------------------------------------------

local RS = game:GetService("ReplicatedStorage")
local Shared, Kit, KitRoblox = RS:WaitForChild("Shared"), RS:WaitForChild("Kit"), RS:WaitForChild("KitRoblox")
local Payload = require(Kit:WaitForChild("Payload"))
local Router = require(Kit:WaitForChild("Router"))
local Remotes = require(KitRoblox:WaitForChild("Remotes"))
local Saves = require(KitRoblox:WaitForChild("Saves"))
local Rng = require(Shared:WaitForChild("Rng"))
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationProgress = require(Shared:WaitForChild("StationProgress"))
local StationRules = require(Shared:WaitForChild("StationRules"))

local rng = Rng.seed(os.time(), Random.new():NextInteger(1, 2 ^ 30))
local saves
local remotes: Remotes.Handle

local function ids(list: { { id: string } }): { string }
	local out = {}
	for _, x in list do
		table.insert(out, x.id)
	end
	return out
end

-- Every accepted change goes through here; the client sees the new profile via onChanged.
local function apply(
	player: Player,
	change: (StationProgress.Profile) -> (StationProgress.Profile, boolean, string?)
): (boolean, string?)
	local p = saves.get(player)
	if p == nil then
		return false, "loading"
	end
	local _, ok, code = change(StationProgress.sanitize(p, os.time())) -- dry run on a copy for the code
	if not ok then
		return false, code
	end
	saves.apply(player, function(q)
		return (change(q))
	end)
	return true, nil
end

local function buy(player: Player, eggId: string): (boolean, string?)
	local p = saves.get(player)
	if p == nil then
		return false, "loading"
	end
	local ok, code = StationProgress.canBuy(p, eggId)
	if not ok then
		return false, code
	end
	local animal
	animal, rng = StationRules.hatch(eggId, rng)
	local hatched = animal :: StationRules.Owned
	saves.apply(player, function(q)
		return (StationProgress.buy(q, eggId, hatched))
	end)
	remotes.fx(player, "hatched", { s = hatched.s, v = hatched.v, stats = hatched.stats, trained = hatched.trained })
	return true, nil
end

local router = Router.new({
	ready = function(player)
		return saves ~= nil and saves.isLoaded(player)
	end,
	actions = {
		profile = {
			args = {},
			handler = function(player)
				remotes.fx(player, "profile", saves.get(player))
				return true
			end,
		},
		buy = { args = { Payload.enum(ids(StationConfig.EGGS)) }, handler = buy },
		team = {
			args = { Payload.int({ min = 1, max = 1e12 }) },
			handler = function(player, id: number)
				return apply(player, function(p)
					return StationProgress.toggleTeam(p, id)
				end)
			end,
		},
		train = {
			args = { Payload.int({ min = 1, max = 1e12 }), Payload.enum(ids(StationConfig.STATIONS)) },
			handler = function(player, id: number, stationId: string)
				local now = os.time()
				return apply(player, function(p)
					return StationProgress.train(p, id, stationId, now)
				end)
			end,
		},
		stop = {
			args = { Payload.int({ min = 1, max = 1e12 }) },
			handler = function(player, id: number)
				local now = os.time()
				return apply(player, function(p)
					return StationProgress.stop(p, id, now)
				end)
			end,
		},
	},
	onError = function(action, err)
		warn(`[StationsServer] {action}: {err}`)
	end,
})
remotes = Remotes.create("StationsRemotes", router)

saves = Saves.start({
	name = "StationsProfile",
	defaults = StationProgress.defaults,
	sanitize = StationProgress.sanitize,
	snapshot = StationProgress.snapshot,
	onChanged = function(player, profile)
		player:SetAttribute("Coins", profile.coins)
		remotes.fx(player, "profile", profile)
	end,
})

-- Egg stalls: a prompt on each counter buys that egg (the server decides price and result).
local market = World.root():FindFirstChild("EggMarket", true)
for _, egg in StationConfig.EGGS do
	local stand = market and market:FindFirstChild(egg.id)
	local counter = stand and stand:FindFirstChildWhichIsA("BasePart")
	if counter == nil then
		warn(`[StationsServer] no stall for {egg.id}`)
		continue
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `Buy {egg.name}`
	prompt.ObjectText = if egg.unlock then `Level {egg.unlock}+  -  {egg.price} coins` else `{egg.price} coins`
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	prompt.Triggered:Connect(function(player)
		local ok, code = buy(player, egg.id)
		if not ok then
			remotes.fx(player, "refused", code)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	join(player)
	saves.load(player)
end)
for _, p in Players:GetPlayers() do
	join(p)
	task.spawn(saves.load, p)
end

Players.PlayerRemoving:Connect(function(player)
	local i = ranchOf(player)
	if i then
		owners[i] = nil
		World.setRanchOwner(i, nil)
	end
end)

-- Creature showcase (STATION-016): until owned animals stand at the ranch, each paddock shows the
-- Rhino and the Lava Rhino pacing a lane: walk up, turn, magic attack back down the lane, walk
-- back, turn, horn attack.
-- shortcut: the server tweens the Root, which replicates at network rate, move creatures on the
-- client when wave fights place them.
local QUARTER = CFrame.Angles(0, math.pi / 2, 0)

local function pace(model: Model, a: CFrame, b: CFrame)
	local root = model.PrimaryPart :: BasePart
	local function go(to: CFrame, seconds: number)
		Creatures.play(model, "walk")
		local tween = TweenService:Create(root, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { CFrame = to })
		tween:Play()
		tween.Completed:Wait()
	end
	local function turn(from: CFrame) -- two quarter turns: a half turn in one tween has no fixed axis
		go(from * QUARTER, 1)
		go(from * QUARTER * QUARTER, 1)
	end
	local function act(anim: string)
		Creatures.play(model, anim)
		task.wait(Creatures.LENGTH[anim] + 1.2)
	end
	local seconds = (b.Position - a.Position).Magnitude / Creatures.speed(model)
	while model.Parent do
		go(b, seconds)
		turn(b)
		act("magic")
		go(a * QUARTER * QUARTER, seconds)
		turn(a * QUARTER * QUARTER)
		act("attack")
	end
end

for i = 1, World.RANCHES do
	local parent = World.root():FindFirstChild(`Ranch{i}`, true) :: Instance
	local cf = World.ranchFrame(i)
	-- lanes down the paddock, far enough apart to turn; its grass is 0.5 above the ranch frame
	for name, x in { creature_rhino = -25, creature_rhino_lava = -10 } do
		task.spawn(function()
			local from, to = cf * Vector3.new(x, 0.5, -38), cf * Vector3.new(x, 0.5, 2)
			local a = CFrame.lookAt(from, to)
			local model = Creatures.spawn(name, a, parent)
			if model then
				pace(model, a, a.Rotation + to)
			end
		end)
	end
end
