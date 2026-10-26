--!strict
-- Neon Spire server (docs/game-design/game5-gdd.md, docs/architecture/spire.md 4).
-- Server-authoritative: the pure Spire modules decide every outcome against the server's own profile
-- and the server's view of each root. This script assigns lots, routes the Request remote with the
-- common checks of decision 0009, handles the Grab and SkyDeck prompts, runs the 1 Hz income, Hot
-- Data and Market loop (spire.md 4.5), the ticker, and saves on leave and shutdown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Build stamp first (spire.md 9), before anything that can wait or fail.
local buildInfo = ReplicatedStorage:FindFirstChild("BuildInfo") :: StringValue?
print(`[Spire] build {buildInfo and string.match(buildInfo.Value, "%S+") or "dev"}`)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MarketRules = require(Shared:WaitForChild("MarketRules"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local SpireConfig = require(Shared:WaitForChild("SpireConfig"))
local SpireEconomy = require(Shared:WaitForChild("SpireEconomy"))
local SpireProgress = require(Shared:WaitForChild("SpireProgress"))
local TowerRules = require(Shared:WaitForChild("TowerRules"))
local City = require(script.Parent:WaitForChild("City"))
local Lots = require(script.Parent:WaitForChild("Lots"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local State = require(script.Parent:WaitForChild("State"))

type Profile = SpireConfig.Profile
type Vec3 = TowerRules.Vec3

local FLUSH = 0.25 -- Lots.flush (4 Hz)
local BOARD_REFRESH = 60
local SKYDECK_RANGE = 12 -- the LiftPad prompt's MaxActivationDistance
local WAIT_TEXT = "Every lot here is taken. You will get the next one that frees up."
local WAIT_REPEAT = 10 -- seconds between reminders while waiting for a lot
local CLOSED_TEXT = "This tower is closed to visitors."
local CLOSED_MOVE_TEXT = "This tower closed to visitors, so you are back on the Grid Plaza."
-- Accepted actions that send Fx("built") (spire.md 6.3).
local BUILD: { [string]: boolean } = {
	buyFloor = true,
	refitFloor = true,
	buyModule = true,
	upgradeModule = true,
	sellModule = true,
	placeItem = true,
	moveItem = true,
	sellItem = true,
}

local rng = Random.new()
local city = City.build()

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Puts the character at lot-space `v` facing the Grid Plaza.
local function teleport(player: Player, lot: number, v: Vec3)
	local character = player.Character
	if character and rootOf(player) then
		local at = Lots.toWorld(lot, v)
		local ahead = Lots.toWorld(lot, { x = v.x, y = v.y, z = v.z - 1 })
		character:PivotTo(CFrame.lookAt(at, ahead))
	end
end

-- Friend status of `viewer` with `owner`, cached per pair per session; the first lookup yields.
local function isFriend(viewer: Player, owner: Player): boolean
	local live = State.live[viewer]
	if live == nil then
		return false
	end
	local cached = live.friends[owner.UserId]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(viewer.IsFriendsWith, viewer, owner.UserId)
	local friend = ok and result == true
	if State.live[viewer] == live then
		live.friends[owner.UserId] = friend
	end
	return friend
end

-- Whether the owner's gate lets `viewer` in, decided on the owner's profile current after the one
-- friend lookup that may yield. False when the owner is gone.
local function gateOpen(viewer: Player, owner: Player): boolean
	local p = Profiles.get(owner)
	if p and p.gate == "friends" and viewer ~= owner then
		isFriend(viewer, owner) -- warms the cache (may yield once)
	end
	p = Profiles.get(owner)
	if p == nil or State.live[owner] == nil then
		return false
	end
	return viewer == owner or SpireProgress.gateAllows(p.gate, p.gate == "friends" and isFriend(viewer, owner))
end

-- The spark's slot is still a filled non-fusion slot.
local function hotValid(p: Profile, hot: { floor: number, slot: number }): boolean
	local f = p.floors[hot.floor]
	return f ~= nil and f.d ~= "fusion" and (f.m[hot.slot] or 0) > 0
end

local function clearHot(live: State.Live, now: number)
	live.hot = nil
	Lots.setHot(live.lot, nil)
	live.nextHot = now + rng:NextInteger(SpireConfig.HOT.minGap, SpireConfig.HOT.maxGap)
end

-- Token bucket shared by Request and prompts (decision 0009): every call past the type check takes a
-- token whatever its outcome; an empty bucket refuses without taking one.
local function take(live: State.Live): boolean
	local bucket, ok = SpireProgress.take(live.bucket, os.clock())
	live.bucket = bucket
	return ok
end

-- Request remote (spire.md 4.3) ---------------------------------------------------------------

local function endorse(player: Player, arg: string): (boolean, string?)
	local target: Player? = nil
	for _, other in Players:GetPlayers() do
		if tostring(other.UserId) == arg then
			target = other
		end
	end
	if target == nil or target == player or State.live[target] == nil or Profiles.get(target) == nil then
		return false, "target"
	end
	local open = gateOpen(player, target) -- may yield
	local targetLive = State.live[target]
	if targetLive == nil or State.live[player] == nil then
		return false, "target"
	end
	if not open then
		return false, "gate"
	end
	local ok, code = Profiles.request(player, "endorse", arg, MarketRules.eventAt(os.time()))
	if not ok then
		return false, code
	end
	Profiles.apply(target, "endorsed", SpireProgress.receiveEndorse)
	Remotes.fx("endorse", { lot = targetLive.lot })
	return true
end

-- What changed after an accepted action: build Fx, ticker, a spark on an emptied slot, visitors on a
-- tower whose gate closed to them.
local function accepted(player: Player, live: State.Live, action: string, arg: string?)
	local p = Profiles.get(player)
	if p == nil then
		return
	end
	local now = os.time()
	local caps = SpireProgress.parse(action, arg) or {}
	if BUILD[action] then
		local data: { [string]: any } = { lot = live.lot, kind = action }
		if action == "buyFloor" then
			data.floor = #p.floors
		elseif action == "placeItem" then
			data.uid = p.plaza.nextUid - 1
		elseif action == "moveItem" or action == "sellItem" then
			data.uid = caps[1]
		elseif action == "refitFloor" then
			data.floor = caps[1]
		else -- buyModule, upgradeModule, sellModule: the slot's level after the change
			local f = p.floors[caps[1]]
			data.floor, data.slot = caps[1], caps[2]
			data.level = f and f.m[caps[2]]
		end
		Remotes.fx("built", data)
	end
	if action == "buyFloor" and table.find(SpireConfig.MILESTONES, #p.floors) then
		Remotes.fx("ticker", { company = SpireConfig.companyName(p.company), text = `reached floor {#p.floors}!` })
	elseif action == "ipo" then
		Remotes.fx("ipo", { lot = live.lot })
		Remotes.fx("ticker", { company = SpireConfig.companyName(p.company), text = "went public!" })
	end
	if live.hot and not hotValid(p, live.hot) then
		clearHot(live, now)
	end
	if action == "setGate" then
		task.spawn(Lots.evict, live.lot, CLOSED_MOVE_TEXT, function(visitor: Player)
			return gateOpen(visitor, player)
		end)
	end
end

local function onRequest(player: Player, action: any, arg: any): (boolean, string?)
	local live = State.live[player]
	local p = Profiles.get(player)
	if live == nil or p == nil then
		return false, "busy"
	end
	if type(action) ~= "string" or (arg ~= nil and (type(arg) ~= "string" or #arg > SpireConfig.MAX_ARG)) then
		return false, "type"
	end
	if not take(live) then
		return false, "rate"
	end
	local code = SpireProgress.check(action, arg)
	if code then
		return false, code
	end
	if action == "lift" then
		local root = rootOf(player)
		local here = root and TowerRules.liftAt(p, Lots.toLot(live.lot, root.Position))
		if here == nil then
			return false, "zone"
		end
		local target = TowerRules.liftTarget(p, arg)
		if target == nil or target == here then
			return false, "arg"
		end
		teleport(player, live.lot, TowerRules.standAt(target))
		return true
	elseif action == "home" then
		if rootOf(player) == nil then
			return false, "zone"
		end
		teleport(player, live.lot, TowerRules.standAt(1))
		return true
	elseif action == "endorse" then
		return endorse(player, arg)
	end
	local ok, refused = Profiles.request(player, action, arg, MarketRules.eventAt(os.time()))
	if not ok then
		return false, refused
	end
	accepted(player, live, action, arg)
	return true
end
Remotes.Request.OnServerInvoke = onRequest

-- Prompts (spire.md 4.4) ----------------------------------------------------------------------

local function grab(player: Player, live: State.Live, p: Profile, lot: number)
	local hot = live.hot
	local root = rootOf(player)
	if lot ~= live.lot or hot == nil or root == nil or os.time() >= hot.ends or not hotValid(p, hot) then
		return
	end
	local slot = Lots.toWorld(lot, TowerRules.slotPos(hot.floor, hot.slot))
	if (root.Position - slot).Magnitude > SpireConfig.HOT.range then
		return
	end
	local now = os.time()
	local today = MetaRules.dayOf(now)
	local amount = SpireEconomy.hotBonus(p, MarketRules.eventAt(now)) -- fixed once, re-applied as is
	Profiles.apply(player, "hot", function(q)
		return SpireProgress.grabHot(q, amount, today)
	end)
	clearHot(live, now)
	Remotes.fx("grabbed", { lot = lot, amount = amount })
end

local function skyDeck(player: Player, lot: number)
	local owner = Lots.owner(lot)
	local root = rootOf(player)
	if owner == nil or root == nil or State.live[owner] == nil then
		return
	end
	local pad = Lots.toWorld(lot, (TowerRules.liftZone(1)))
	if (root.Position - pad).Magnitude > SKYDECK_RANGE then
		return
	end
	if not gateOpen(player, owner) then
		Remotes.notice(player, CLOSED_TEXT)
		return
	end
	local ownerProfile = Profiles.get(owner) -- current after any yield in gateOpen
	if ownerProfile and Lots.owner(lot) == owner then
		teleport(player, lot, TowerRules.standAt(#ownerProfile.floors + 1))
	end
end

Lots.prompts:Connect(function(player: Player, lot: number, kind: string)
	local live = State.live[player]
	local p = Profiles.get(player)
	if live == nil or p == nil or not take(live) then
		return
	end
	if kind == "grab" then
		grab(player, live, p, lot)
	elseif kind == "skydeck" then
		skyDeck(player, lot)
	end
end)

-- Loop (spire.md 4.5) ---------------------------------------------------------------------------

local lastStatus = ""
local boardAt = -math.huge

local function secondTick()
	local now = os.time()
	local today = MetaRules.dayOf(now)
	local event = MarketRules.eventAt(now)
	local snapshot: { [Player]: State.Live } = table.clone(State.live)
	for player, live in snapshot do
		local p = Profiles.get(player)
		if p == nil or State.live[player] ~= live then
			continue
		end
		local inc = SpireEconomy.income(p, event)
		local whole
		whole, live.carry = SpireEconomy.tick(inc, live.carry, 1)
		if inc > 0 then
			Profiles.earn(player, whole, 1, today)
		end
		if player:GetAttribute("Income") ~= inc then
			player:SetAttribute("Income", inc)
			local stats = player:FindFirstChild("leaderstats")
			local value = stats and stats:FindFirstChild("Income") :: StringValue?
			if value then
				value.Value = SpireEconomy.short(math.floor(inc))
			end
		end
		local hot = live.hot
		if hot and (now >= hot.ends or not hotValid(p, hot)) then
			clearHot(live, now)
		elseif hot == nil and now >= live.nextHot then
			local slots = TowerRules.hotSlots(p)
			if #slots > 0 then
				local pick = slots[rng:NextInteger(1, #slots)]
				local spark = { floor = pick.floor, slot = pick.slot, ends = now + SpireConfig.HOT.life }
				live.hot = spark
				Lots.setHot(live.lot, spark)
				Remotes.fx("hot", { lot = live.lot, floor = spark.floor, slot = spark.slot, ends = spark.ends })
			end
		end
	end
	local forecast = MarketRules.forecast(now, 3)
	local status = {
		event = event,
		eventLeft = MarketRules.eventLeft(now),
		forecast = { forecast[2].kind, forecast[3].kind },
		window = forecast[1].window,
	}
	local json = HttpService:JSONEncode(status)
	if json ~= lastStatus then
		lastStatus = json
		Remotes.Status.Value = json
		city.market(status)
	end
	Profiles.step(now)
	if os.clock() - boardAt >= BOARD_REFRESH then
		boardAt = os.clock()
		task.spawn(function()
			city.board(Profiles.topEarned())
		end)
	end
end

local function guarded(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(`[SpireServer] {name} failed: {tostring(err)}`)
	end
end

local flushAcc, secondAcc = 0, 0
RunService.Heartbeat:Connect(function(dt: number)
	flushAcc += dt
	secondAcc += dt
	if flushAcc >= FLUSH then
		flushAcc = math.min(flushAcc - FLUSH, FLUSH) -- drop a backlog instead of bursting ticks
		guarded("lot flush", Lots.flush)
	end
	if secondAcc >= 1 then
		secondAcc = math.min(secondAcc - 1, 1)
		guarded("second tick", secondTick)
	end
end)

-- Players -------------------------------------------------------------------------------------

local function onPlayer(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local floors = Instance.new("IntValue")
	floors.Name = "Floors"
	floors.Parent = leaderstats
	local income = Instance.new("StringValue")
	income.Name = "Income"
	income.Value = "0"
	income.Parent = leaderstats
	leaderstats.Parent = player
	local lot = Lots.assign(player)
	local waited = 0
	-- Every lot taken (Max Players above Lots.COUNT): tell the player and retry each second.
	while lot == nil and player.Parent ~= nil do
		if waited % WAIT_REPEAT == 0 then
			warn(`[SpireServer] no free lot for {player.UserId}, waiting`)
			Remotes.notice(player, WAIT_TEXT)
		end
		task.wait(1)
		waited += 1
		lot = Lots.assign(player)
	end
	if lot == nil then
		return
	end
	if player.Parent == nil then
		Lots.free(lot) -- left in the second between the last retry and the assign
		return
	end
	local now = os.time()
	-- Live exists before the load so login's publish can set Lot and the lot's State; the loop and
	-- the router skip it until Profiles.get returns a profile.
	State.live[player] = {
		lot = lot,
		carry = 0,
		bucket = { tokens = SpireConfig.BUCKET.size, at = os.clock() },
		hot = nil,
		nextHot = now + rng:NextInteger(SpireConfig.HOT.minGap, SpireConfig.HOT.maxGap),
		friends = {},
		boardEarned = -1,
		boardAt = 0,
	}
	player:SetAttribute("Lot", lot)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		local live = State.live[player]
		if live then
			teleport(player, live.lot, TowerRules.standAt(1))
		end
	end)
	Profiles.load(player)
	if State.live[player] then
		teleport(player, lot, TowerRules.standAt(1))
	end
end

-- Leave (GDD P): free the lot first (visitors moved off, a waiting player can take it during the
-- final write, which needs no lot), then the final write.
local function onLeave(player: Player)
	local live = State.live[player]
	State.live[player] = nil -- the loop, router and prompts stop serving this lot at once
	if live then
		Lots.free(live.lot)
	end
	Profiles.finish(player, os.time())
end

Profiles.Changed:Connect(function(player: Player, profile: Profile)
	local live = State.live[player]
	if live then
		Lots.setState(live.lot, SpireProgress.publicState(profile))
	end
end)

if Players.MaxPlayers > Lots.COUNT then
	-- Set Max Players to 6 in the place settings (spire.md 9 publish checklist); extra players wait.
	warn(`[SpireServer] Max Players {Players.MaxPlayers} is above the {Lots.COUNT} lots`)
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(onLeave)

game:BindToClose(function()
	table.clear(State.live)
	Profiles.finishAll(os.time())
end)
