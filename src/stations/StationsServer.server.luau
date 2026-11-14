--!strict
-- Animal Stations server entry: builds the world, gives each player a home ranch (lowest free of
-- World.RANCHES, owners spawn at its gate), teleports players between their ranch and the hub,
-- loads saves (kit Saves), shows each ranch as its owner has built it and the eggs in its hatchery
-- (Ranch.luau), and routes every request (kit Router): buying eggs, starting one hatching and
-- opening it, ranch upgrades, the team and training. The client only names an action; prices, hatches and timings are decided here.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Creatures = require(script.Parent:WaitForChild("Creatures"))
local Ranch = require(script.Parent:WaitForChild("Ranch"))
local World = require(script.Parent:WaitForChild("World"))

World.build()

-- What stands on each ranch follows its owner's upgrades (a free ranch shows a new one).
local shown: { [number]: string } = {}
local function show(i: number, upgrades: { [string]: number })
	local key = ""
	for _, track in { "house", "barn", "grounds" } do
		key ..= `{upgrades[track] or 0},`
	end
	if shown[i] ~= key then
		shown[i] = key
		Ranch.render(i, upgrades)
	end
end
for i = 1, World.RANCHES do
	show(i, {})
end
-- and the eggs waiting in its hatchery
local held: { [number]: string } = {}
local hatchedAt: { [number]: Vector3 } = {} -- animal id -> the nest it has just hatched in
local syncHerd: (i: number, animals: { any }) -> ()
local function showEggs(i: number, eggs: { { egg: string, since: number? } })
	local key = ""
	for _, e in eggs do
		key ..= e.egg .. (if e.since then "+," else ",")
	end
	if held[i] ~= key then
		held[i] = key
		Ranch.eggs(i, eggs)
	end
end

-- Max Players is a place setting a place file cannot carry: set it to 3 when publishing.
if Players.MaxPlayers > World.RANCHES then
	warn(`[StationsServer] Max Players {Players.MaxPlayers} is above the {World.RANCHES} ranches`)
end

local owners: { [number]: Player } = {}

-- The admin menu (decision 0038) is for the game's owner, and for anyone running it in Studio.
local function isAdmin(player: Player): boolean
	return RunService:IsStudio() or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
end

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
	player:SetAttribute("Admin", isAdmin(player))
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
	remotes.fx(player, "bought", eggId) -- it waits in the egg storage until the player hatches it
	return true, nil
end

-- Admin menu: stand any animal's model in front of the admin to look at it. Display only:
-- nothing is added to a profile. LOOKS lists every animal and then its variant, in the order the
-- client's menu shows them.
local StationAssets = require(Shared:WaitForChild("StationAssets"))
local LOOKS: { string } = {}
local LOOK_OF: { [string]: { s: string, v: string? } } = {}
for _, sp in StationConfig.SPECIES do
	table.insert(LOOKS, Creatures.asset(sp.id))
	LOOK_OF[Creatures.asset(sp.id)] = { s = sp.id }
	for _, va in sp.variants do
		table.insert(LOOKS, Creatures.asset(sp.id, va.id))
		LOOK_OF[Creatures.asset(sp.id, va.id)] = { s = sp.id, v = va.id }
	end
end

-- What a model tells the client for the card shown under the cursor: its species, its variant
-- and its six stats (an owned animal's own, with its training; otherwise the version's).
local function describe(model: Model, s: string, v: string?, animal: StationProgress.Animal?)
	model:SetAttribute("Species", s)
	model:SetAttribute("Variant", v)
	local plain = StationRules.versionStats(s, v) :: StationConfig.Stats
	for _, stat in StationConfig.STATS do
		model:SetAttribute(stat, if animal then StationRules.stat(animal :: any, stat) else (plain :: any)[stat])
	end
end

local function looks(player: Player): Instance
	local name = `AdminShow{player.UserId}`
	local f = workspace:FindFirstChild(name)
	if f == nil then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f :: Instance
end

-- Stand `names` in a row in front of `player`, side by side, facing back at them.
local function standBefore(player: Player, names: { string })
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	local flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	flat = if flat.Magnitude < 0.01 then Vector3.new(0, 0, -1) else flat.Unit
	local feet = root.Position - Vector3.new(0, 3, 0)
	local facing = CFrame.lookAt(feet, feet + flat)
	local total, deepest = 0, 0
	for _, name in names do
		total += StationAssets[name].size[1] + 5
		deepest = math.max(deepest, StationAssets[name].size[3])
	end
	local x = -total / 2
	local folder = looks(player)
	for _, name in names do
		local wide = StationAssets[name].size[1] + 5
		local spot = facing * Vector3.new(x + wide / 2, 0, -(12 + deepest / 2))
		x += wide
		task.spawn(function()
			local model = Creatures.spawn(name, CFrame.lookAt(spot, spot - flat), folder)
			if model then
				describe(model, LOOK_OF[name].s, LOOK_OF[name].v, nil)
			end
		end)
	end
end

local router = Router.new({
	ready = function(player)
		return saves ~= nil and saves.isLoaded(player)
	end,
	actions = {
		profile = {
			args = {},
			handler = function(player)
				local p = saves.get(player)
				remotes.fx(player, "profile", if p then StationProgress.public(p) else nil)
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
		-- start hatching the egg at this place in the player's list, or open it when it is done
		hatch = {
			args = { Payload.int({ min = 1, max = 100 }) },
			handler = function(player, k: number)
				local now = os.time()
				return apply(player, function(p)
					return StationProgress.start(p, k, now)
				end)
			end,
		},
		open = {
			args = { Payload.int({ min = 1, max = 100 }) },
			handler = function(player, k: number)
				local p = saves.get(player)
				if p == nil then
					return false, "loading"
				end
				local now = os.time()
				local _, ok, code, born = StationProgress.crack(StationProgress.sanitize(p, now), k, now) -- on a copy
				if not ok or born == nil then
					return false, code
				end
				local nth = 0 -- which nest it sat in
				for j = 1, k do
					nth += if p.eggs[j].since then 1 else 0
				end
				local i, look = ranchOf(player), Ranch.look(p.eggs[k].egg)
				local at = if i then Ranch.nest(i, nth) else nil
				hatchedAt[born.id] = at
				saves.apply(player, function(q)
					return (StationProgress.crack(q, k, now))
				end)
				remotes.fx(player, "hatched", {
					s = born.s,
					v = born.v,
					stats = born.stats,
					trained = born.trained,
					at = at,
					body = look.body,
					spot = look.spot,
				})
				return true, nil
			end,
		},
		-- the admin menu: `look` stands the k-th animal (0 = all of them) before the admin
		look = {
			args = { Payload.int({ min = 0, max = 100 }) },
			handler = function(player, k: number)
				if not isAdmin(player) or (k ~= 0 and LOOKS[k] == nil) then
					return false, "admin"
				end
				standBefore(player, if k == 0 then LOOKS else { LOOKS[k] })
				return true, nil
			end,
		},
		look_anim = {
			args = { Payload.enum({ "idle", "walk", "attack", "magic" }) },
			handler = function(player, anim: string)
				if not isAdmin(player) then
					return false, "admin"
				end
				for _, model in looks(player):GetChildren() do
					Creatures.play(model :: Model, anim)
				end
				return true, nil
			end,
		},
		look_clear = {
			args = {},
			handler = function(player)
				looks(player):ClearAllChildren()
				return true, nil
			end,
		},
		upgrade = {
			args = { Payload.enum(ids(StationConfig.UPGRADES)) },
			handler = function(player, id: string)
				local now = os.time()
				local ok, code = apply(player, function(p)
					return StationProgress.upgrade(p, id, now)
				end)
				if ok then
					remotes.fx(player, "upgraded", id)
				end
				return ok, code
			end,
		},
		-- Studio only: coins and samples cannot be earned until wave fights are built, so the
		-- ranch menu has a test funds button. The action does not exist on a live server.
		funds = if RunService:IsStudio()
			then {
				args = {},
				handler = function(player)
					saves.apply(player, function(q)
						q.coins = math.min(q.coins + 1e6, StationProgress.MAX_COINS)
						q.samples = math.min(q.samples + 500, StationProgress.MAX_SAMPLES)
						return q
					end)
					return true
				end,
			}
			else nil,
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
		remotes.fx(player, "profile", StationProgress.public(profile))
		local i = ranchOf(player)
		if i then
			show(i, profile.upgrades)
			showEggs(i, profile.eggs)
			if syncHerd then -- not yet while this script is still starting
				syncHerd(i, profile.animals)
			end
		end
	end,
})

Players.PlayerAdded:Connect(function(player)
	join(player)
	saves.load(player)
end)
for _, p in Players:GetPlayers() do
	join(p)
	task.spawn(saves.load, p)
end

Players.PlayerRemoving:Connect(function(player)
	looks(player):Destroy()
	local i = ranchOf(player)
	if i then
		owners[i] = nil
		World.setRanchOwner(i, nil)
		show(i, {})
		showEggs(i, {})
		syncHerd(i, {})
	end
end)

-- The herd (decision 0037): a ranch owner's animals walk its roaming area, the first HERD_MAX of
-- them. Each wanders on its own: it walks to a spot, stands a while, and now and then shows an
-- attack. One that has just hatched steps out of its nest first.
-- shortcut: the server tweens each Root, which replicates at network rate, move them on the
-- client if it looks rough online.
local HERD_MAX = 8
local herds: { [number]: { [number]: Model | boolean } } = {} -- false while its model loads
local dice = Random.new()

local function somewhere(i: number): Vector3 -- a spot in the roaming area (Ranch.luau's layout)
	local g = World.RANCH_HALF / 60
	return World.ranchFrame(i) * Vector3.new(dice:NextNumber(-50, -14) * g, 0.5, dice:NextNumber(-48, -1) * g)
end

local function wander(model: Model, i: number)
	local root = model.PrimaryPart :: BasePart
	while model.Parent do
		local from, to = root.Position, somewhere(i)
		local facing = CFrame.lookAt(from, Vector3.new(to.X, from.Y, to.Z))
		Creatures.play(model, "walk")
		local turn = TweenService:Create(root, TweenInfo.new(0.6), { CFrame = facing })
		turn:Play()
		turn.Completed:Wait()
		local seconds = (to - from).Magnitude / Creatures.speed(model)
		local walk = TweenService:Create(
			root,
			TweenInfo.new(seconds, Enum.EasingStyle.Linear),
			{ CFrame = facing.Rotation + to }
		)
		walk:Play()
		walk.Completed:Wait()
		local roll = dice:NextNumber()
		local anim = if roll < 0.2 then "magic" elseif roll < 0.45 then "attack" else "idle"
		Creatures.play(model, anim)
		task.wait((Creatures.LENGTH[anim] or 0) + dice:NextNumber(2, 6))
	end
end

function syncHerd(i: number, animals: { StationProgress.Animal })
	local herd = herds[i] or {}
	herds[i] = herd
	local wanted: { [number]: StationProgress.Animal } = {}
	for k, a in animals do
		if k <= HERD_MAX then
			wanted[a.id] = a
		end
	end
	for id, model in herd do
		if wanted[id] == nil then
			if typeof(model) == "Instance" then
				model:Destroy()
			end
			herd[id] = nil
		end
	end
	local plot = World.root():FindFirstChild(`Ranch{i}`, true) :: Instance
	for id, a in wanted do
		local standing = herd[id]
		if typeof(standing) == "Instance" then
			describe(standing, a.s, a.v, a) -- training may have moved its stats
		end
		if herd[id] == nil then
			herd[id] = false
			task.spawn(function()
				local nest = hatchedAt[id]
				hatchedAt[id] = nil
				if nest then
					task.wait(1.4) -- the hatching animation plays first
				end
				local at = if nest then CFrame.new(nest) else CFrame.new(somewhere(i))
				local model = Creatures.spawn(Creatures.asset(a.s, a.v), at, plot)
				if model and herd[id] == false then
					herd[id] = model
					describe(model, a.s, a.v, a)
					wander(model, i)
				elseif model then
					model:Destroy() -- sold or gone while it loaded
				end
			end)
		end
	end
end

for i, owner in owners do -- anyone whose profile loaded before this point
	local p = saves.get(owner)
	if p then
		syncHerd(i, p.animals)
	end
end
