--!strict
-- Egg Garden server (docs/game-design/game4-gdd.md, docs/architecture/garden.md 4).
-- Server-authoritative: GardenRules, HatchRules, GardenProgress and WorldRules decide every outcome
-- against the server's own profile and the server's view of each root. This script assigns plots,
-- routes the Request remote with the common checks of decision 0008, handles the bed prompts, runs
-- the 5 Hz pad and 1 Hz status loop (garden.md 4.3), announces hatches and saves on leave/shutdown.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenProgress = require(Shared:WaitForChild("GardenProgress"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local HatchRules = require(Shared:WaitForChild("HatchRules"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local Rng = require(Shared:WaitForChild("Rng"))
local WorldRules = require(Shared:WaitForChild("WorldRules"))
local Models = require(script.Parent:WaitForChild("Models"))
local Plots = require(script.Parent:WaitForChild("Plots"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local State = require(script.Parent:WaitForChild("State"))
local World = require(script.Parent:WaitForChild("World"))

type Vec3 = GardenRules.Vec3

local FAST = 0.2 -- pad loop (5 Hz)
local REQUEST_COOLDOWN = 0.35
local MAX_ARG = 32
local GATE_GRACE = 1.0
local BOARD_REFRESH = 60
local FULL_TEXT = "Your garden is full: release or store a creature"
local WAIT_TEXT = "Every garden here is taken. You will get the next one that frees up."
local WAIT_REPEAT = 10 -- seconds between reminders while waiting for a plot

-- Request actions (decision 0008): true takes a string argument, false takes none.
local REQUEST_ARGS: { [string]: boolean } = {
	buyEgg = true,
	plantPrize = true,
	dashReady = false,
	buyBed = false,
	buyPenSlot = false,
	place = true,
	store = true,
	release = true,
	favourite = true,
	like = true,
	setGate = true,
	home = false,
	claimDaily = false,
	claimWeekly = false,
	claimQuest = true,
	buyCosmetic = true,
	equipCosmetic = true,
	adminGrant = true,
}
-- Actions whose argument is a creature id or UserId (must match ^%d+$).
local ID_ARGS: { [string]: boolean } = { place = true, store = true, release = true, favourite = true, like = true }

Models.preloadGarden()
local world = World.build()
local Dash = require(script.Parent:WaitForChild("Dash")) -- builds the island under Workspace.Garden

-- Every Dash call from a gardening path goes through this, so a Dash fault never stops the pads, a
-- teleport home or a save.
local function guarded(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(`[GardenServer] {name} failed: {tostring(err)}`)
	end
end

local function vec(v: Vector3): Vec3
	return { x = v.X, y = v.Y, z = v.Z }
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function rootPos(player: Player): Vec3?
	local root = rootOf(player)
	return if root then vec(root.Position) else nil
end

local function toGate(player: Player, plot: number)
	local character = player.Character
	if character and rootOf(player) then
		character:PivotTo(Plots.gate(plot))
	end
end

-- Friend status of `viewer` with the plot owner, cached per pair per session. `wait` false never
-- yields: an unknown pair is looked up in the background and treated as allowed until known.
local function isFriend(viewer: Player, owner: Player, wait: boolean): boolean
	local live = State.live[viewer]
	if live == nil then
		return false
	end
	local cached = live.friends[owner.UserId]
	if cached ~= nil then
		return cached
	end
	local function lookup(): boolean
		local ok, result = pcall(viewer.IsFriendsWith, viewer, owner.UserId)
		local friend = ok and result == true
		if State.live[viewer] == live then
			live.friends[owner.UserId] = friend
		end
		return friend
	end
	if wait then
		return lookup()
	end
	task.spawn(lookup)
	return true
end

-- Whether the owner's gate lets `viewer` water, like or stay inside (owners are always allowed).
local function gateAllows(viewer: Player, owner: Player, ownerProfile: GardenConfig.Profile, wait: boolean): boolean
	if viewer == owner then
		return true
	end
	local gate = ownerProfile.gate
	return GardenProgress.gateAllows(gate, gate == "friends" and isFriend(viewer, owner, wait))
end

-- Shared session and rate-limit check for requests and prompts. Refusals inside the cooldown do
-- not reset it.
local function admit(player: Player): (State.Live?, GardenConfig.Profile?)
	local live = State.live[player]
	local profile = Profiles.get(player)
	if live == nil or profile == nil then
		return nil, nil
	end
	local t = os.clock()
	if t - live.lastRequest < REQUEST_COOLDOWN then
		return nil, nil
	end
	live.lastRequest = t
	return live, profile
end

-- Request remote (decision 0008) ------------------------------------------------------------

local function like(player: Player, arg: string): boolean
	local target = Players:GetPlayerByUserId(tonumber(arg) or 0)
	local targetProfile = target and Profiles.get(target)
	if target == nil or targetProfile == nil or State.live[target] == nil or target == player then
		return false
	end
	if not gateAllows(player, target, targetProfile, true) then
		return false
	end
	-- The friend lookup may have yielded: decide on the liker's current profile (as water does).
	local profile = Profiles.get(player)
	local now = os.time()
	local today = MetaRules.dayOf(now)
	local targetId = target.UserId
	if profile == nil or not select(2, GardenProgress.like(profile, targetId, player.UserId, today)) then
		return false
	end
	Profiles.apply(player, "like", function(p)
		return (GardenProgress.like(p, targetId, player.UserId, today))
	end)
	Profiles.apply(target, "liked", GardenProgress.receiveLike)
	Remotes.fx("like", { owner = targetId, by = player.UserId })
	return true
end

local function onRequest(player: Player, action: any, arg: any): boolean
	if State.live[player] == nil or Profiles.get(player) == nil then
		return false
	end
	if type(action) ~= "string" or (arg ~= nil and (type(arg) ~= "string" or #arg > MAX_ARG)) then
		return false
	end
	local live, profile = admit(player)
	if live == nil or profile == nil then
		return false
	end
	local takesArg = REQUEST_ARGS[action]
	if takesArg == nil or takesArg ~= (arg ~= nil) then
		return false
	end
	if ID_ARGS[action] and string.match(arg, "^%d+$") == nil then
		return false
	end
	if action == "adminGrant" and not GardenConfig.ADMINS[player.UserId] then
		return false
	end
	if action == "buyEgg" then
		local root = rootPos(player)
		if root == nil or not GardenRules.within(root, world.cart, GardenConfig.RANGE.cart) then
			return false
		end
	elseif action == "like" then
		return like(player, arg)
	elseif action == "dashReady" then
		return Dash.toggle(player)
	elseif action == "home" then
		-- A racer leaves the round, in the start hold too. Ready stays: GDD T3 lets a player ready up
		-- and keep gardening; NOT READY is the way out of the queue.
		if Dash.isRacing(player) then
			guarded("dash leave", function()
				Dash.leave(player)
			end)
		end
		if rootOf(player) == nil then
			return false
		end
		toGate(player, live.plot)
		return true
	elseif action == "release" then
		-- The run-off Fx goes out before the model is removed (garden.md 5).
		local id = tonumber(arg) :: number
		local _, ok = GardenProgress.release(profile, id, MetaRules.dayOf(os.time()))
		if not ok then
			return false
		end
		Remotes.fx("release", { owner = player.UserId, id = id })
	end
	return Profiles.request(player, action, arg)
end
Remotes.Request.OnServerInvoke = onRequest

-- Bed prompts (decision 0008) -----------------------------------------------------------------

local function hatch(player: Player, profile: GardenConfig.Profile, bed: number)
	local now = os.time()
	local today = MetaRules.dayOf(now)
	local weather = WorldRules.weatherAt(now)
	local o = HatchRules.roll(profile, bed, now, weather, Rng.seed(Random.new():NextInteger(1, 2 ^ 31 - 1)))
	if o == nil then
		if GardenRules.isFull(profile) then
			Remotes.notice(player, FULL_TEXT)
		end
		return
	end
	local outcome = o :: HatchRules.Outcome
	local _, ok = GardenProgress.hatch(profile, bed, outcome, now, today)
	if not ok then
		return
	end
	-- Fired before the model appears so the client can hide it until its reveal ends.
	Remotes.fx(
		"hatch",
		{ owner = player.UserId, bed = bed, id = profile.nextId, s = outcome.s, m = outcome.m, z = outcome.z }
	)
	Profiles.apply(player, "hatch", function(p)
		return (GardenProgress.hatch(p, bed, outcome, now, today))
	end)
	if HatchRules.announce(outcome) then
		Remotes.fx("announce", { name = player.DisplayName, s = outcome.s, m = outcome.m, z = outcome.z })
	end
end

local function water(player: Player, owner: Player, ownerProfile: GardenConfig.Profile, bed: number)
	local now = os.time()
	local today = MetaRules.dayOf(now)
	if player == owner then
		local _, ok = GardenProgress.ownWater(ownerProfile, bed, now, today)
		if not ok then
			return
		end
		Profiles.apply(owner, "water", function(p)
			return (GardenProgress.ownWater(p, bed, now, today))
		end)
	else
		if not gateAllows(player, owner, ownerProfile, true) then
			return
		end
		-- The friend lookup may have yielded: re-check on the owner's current profile.
		local current = Profiles.get(owner)
		if current == nil or not GardenRules.canWater(current, bed, now, true) then
			return
		end
		Profiles.apply(owner, "help", function(p)
			return (GardenRules.water(p, bed, now, true))
		end)
		Profiles.apply(player, "helper", function(p)
			return (GardenProgress.helperWater(p, today))
		end)
	end
	Remotes.fx("water", { owner = owner.UserId, bed = bed, by = player.UserId })
end

Plots.prompts:Connect(function(player: Player, plot: number, bed: number, kind: string)
	local live, profile = admit(player)
	if live == nil or profile == nil then
		return
	end
	local owner = Plots.owner(plot)
	local ownerProfile = owner and Profiles.get(owner)
	local root = rootPos(player)
	if owner == nil or ownerProfile == nil or State.live[owner] == nil or root == nil then
		return
	end
	if not GardenRules.within(root, Plots.bed(plot, bed), GardenConfig.RANGE.bed) then
		return
	end
	if kind == "Hatch" then
		if player == owner then
			hatch(player, profile, bed)
		end
	elseif kind == "Water" then
		water(player, owner, ownerProfile, bed)
	end
end)

Dash.prompt.Triggered:Connect(function(player: Player)
	if admit(player) then
		Dash.toggle(player)
	end
end)

-- Loop (garden.md 4.3) --------------------------------------------------------------------------

-- Banks every pad of `player` the root stands on (or every pad when `root` is nil, on leave).
-- A pad counts once per visit for collect50: the first bank of >= 1 coin since the root stepped on.
local function bankPads(player: Player, live: State.Live, root: Vec3?, today: number)
	local sum, count = 0, 0
	local centres = Plots.pads(live.plot)
	for i, centre in centres do
		if root == nil or GardenRules.onPad(root, centre) then
			local coins
			live.pads, coins = GardenRules.bankPad(live.pads, i)
			if coins >= 1 then
				sum += coins
				if not live.visits[i] then
					live.visits[i] = true
					count += 1
				end
				if root then
					Remotes.fx("collect", { owner = player.UserId, pad = i, amount = coins })
				end
			end
		else
			live.visits[i] = nil
		end
	end
	if sum > 0 then
		Profiles.bank(player, sum, count, today)
	end
end

local function fastTick()
	local now = os.time()
	local today = MetaRules.dayOf(now)
	local roots: { [Player]: Vec3 } = {}
	for player in State.live do
		roots[player] = rootPos(player)
	end
	for player, live in State.live do
		local profile = Profiles.get(player)
		if profile == nil then
			continue
		end
		live.pads = GardenRules.accrue(profile, live.pads, FAST)
		local root = roots[player]
		if root then
			bankPads(player, live, root, today)
		end
		-- Gate guard: move a disallowed visitor out after 1 s inside this plot.
		for visitor, visitorLive in State.live do
			local at = roots[visitor]
			if visitor == player or at == nil then
				continue
			end
			if Plots.contains(live.plot, at) and not gateAllows(visitor, player, profile, false) then
				local inside = (visitorLive.inside[live.plot] or 0) + FAST
				if inside > GATE_GRACE then
					inside = 0
					toGate(visitor, live.plot)
				end
				visitorLive.inside[live.plot] = inside
			else
				visitorLive.inside[live.plot] = nil
			end
		end
	end
	guarded("dash tick", function()
		Dash.step(roots, today)
	end)
end

local lastStatus = ""
local boardAt = -math.huge

local function slowTick()
	local now = os.time()
	for player, live in State.live do
		local profile = Profiles.get(player)
		if profile then
			for i = 1, GardenConfig.PEN.max do
				Plots.setPending(live.plot, i, live.pads[i] or 0)
			end
			Plots.refresh(live.plot, profile) -- eggs ripen with time, not only on changes
		end
	end
	local forecast = WorldRules.forecast(now, 3)
	local window = WorldRules.stockWindow(now)
	local status: { [string]: any } = {
		weather = WorldRules.weatherAt(now),
		weatherLeft = WorldRules.weatherLeft(now),
		forecast = { forecast[2] and forecast[2].kind, forecast[3] and forecast[3].kind },
		stockLeft = WorldRules.restockLeft(now),
		stockWindow = window,
		stock = WorldRules.stockFor(window),
	}
	guarded("dash status", function()
		status.dash = Dash.status()
	end)
	local json = HttpService:JSONEncode(status)
	if json ~= lastStatus then
		lastStatus = json
		Remotes.Status.Value = json
	end
	world.forecast(status)
	Profiles.step(now)
	if os.clock() - boardAt >= BOARD_REFRESH then
		boardAt = os.clock()
		task.spawn(function()
			world.board(Profiles.topIncome())
		end)
	end
end

local fastAcc, slowAcc = 0, 0
RunService.Heartbeat:Connect(function(dt: number)
	fastAcc += dt
	slowAcc += dt
	if fastAcc >= FAST then
		fastAcc = math.min(fastAcc - FAST, FAST) -- drop a backlog instead of bursting ticks
		guarded("pad tick", fastTick)
	end
	if slowAcc >= 1 then
		slowAcc = math.min(slowAcc - 1, 1)
		guarded("status tick", slowTick)
	end
end)

-- Players -------------------------------------------------------------------------------------

local function onPlayer(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local income = Instance.new("StringValue")
	income.Name = "Income"
	income.Value = "0"
	income.Parent = leaderstats
	local index = Instance.new("IntValue")
	index.Name = "Index"
	index.Parent = leaderstats
	leaderstats.Parent = player
	local plot = Plots.assign(player)
	local waited = 0
	-- Every plot taken (Max Players above Plots.COUNT, or a leaver's plot not free yet): tell the
	-- player and retry each second until one frees up.
	while plot == nil and player.Parent ~= nil do
		if waited % WAIT_REPEAT == 0 then
			warn(`[GardenServer] no free plot for {player.UserId}, waiting`)
			Remotes.notice(player, WAIT_TEXT)
		end
		task.wait(1)
		waited += 1
		plot = Plots.assign(player)
	end
	if plot == nil then
		return
	end
	-- Live exists before the load so login's publish can refresh the plot; the loop and the router
	-- skip it until Profiles.get returns a profile.
	State.live[player] = {
		plot = plot,
		pads = {},
		lastRequest = 0,
		inside = {},
		visits = {},
		friends = {},
		boardIncome = -1,
		boardAt = 0,
	}
	player:SetAttribute("Plot", plot)
	player.CharacterAdded:Connect(function(character)
		guarded("dash track", function()
			Dash.track(character)
		end)
		character:WaitForChild("HumanoidRootPart", 10)
		local live = State.live[player]
		if live then
			local ok, placed = pcall(Dash.place, player)
			if not (ok and placed) then
				toGate(player, live.plot)
			end
		end
	end)
	if player.Character then -- spawned while waiting for a plot
		guarded("dash track", function()
			Dash.track(player.Character :: Model)
		end)
	end
	Profiles.load(player)
	local profile = Profiles.get(player)
	if profile and State.live[player] then
		Plots.refresh(plot, profile)
		toGate(player, plot)
	end
end

-- Leave (GDD L): bank every pad, free the plot (a waiting player can take it during the final
-- write, which needs no plot), then the final write.
local function onLeave(player: Player)
	guarded("dash leave", function()
		Dash.leave(player)
	end)
	local live = State.live[player]
	State.live[player] = nil -- the loop, router and prompts stop serving this plot at once
	if live then
		if Profiles.get(player) then
			bankPads(player, live, nil, MetaRules.dayOf(os.time()))
		end
		Plots.free(live.plot)
	end
	Profiles.finish(player, os.time())
end

Profiles.Changed:Connect(function(player: Player, profile: GardenConfig.Profile)
	local live = State.live[player]
	if live then
		Plots.refresh(live.plot, profile)
	end
end)

if Players.MaxPlayers > Plots.COUNT then
	-- Set Max Players to 6 in the place settings (docs/architecture/garden.md 7); extra players wait.
	warn(`[GardenServer] Max Players {Players.MaxPlayers} is above the {Plots.COUNT} plots`)
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(onLeave)

game:BindToClose(function()
	guarded("dash close", Dash.close)
	local now = os.time()
	for player, live in State.live do
		State.live[player] = nil
		if Profiles.get(player) then
			bankPads(player, live, nil, MetaRules.dayOf(now))
		end
	end
	Profiles.finishAll(now)
end)
