--!strict
-- Lantern Express server (docs/architecture/lantern.md 4, decision 0018). One crew of up to 6 and
-- one train per server. The run is a TrainRules.Run held here: the 10 Hz loop samples the world
-- (seats, stop depths, load boxes, fresh beams, lantern points) into TrainRules.tick, keeps the run
-- it returns and carries out its events; requests and prompts replace the run in the same frame (no
-- yield between reading and writing it). Every reward is one saves.apply on one player's own save
-- (Rewards). Heartbeat moves the anchored train between ticks.

local HttpService = game:GetService("HttpService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Kit = ReplicatedStorage:WaitForChild("Kit")
local KitRoblox = ReplicatedStorage:WaitForChild("KitRoblox")
local CarryRules = require(Shared:WaitForChild("CarryRules"))
local LanternConfig = require(Shared:WaitForChild("LanternConfig"))
local LanternProgress = require(Shared:WaitForChild("LanternProgress"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local Rng = require(Shared:WaitForChild("Rng"))
local TrainRules = require(Shared:WaitForChild("TrainRules"))
local Payload = require(Kit:WaitForChild("Payload"))
local Router = require(Kit:WaitForChild("Router"))
local Remotes = require(KitRoblox:WaitForChild("Remotes"))
local Saves = require(KitRoblox:WaitForChild("Saves"))
local Models = require(script.Parent:WaitForChild("Models"))
local World = require(script.Parent:WaitForChild("World"))
local Train = require(script.Parent:WaitForChild("Train"))
local Carry = require(script.Parent:WaitForChild("Carry"))
local Stops = require(script.Parent:WaitForChild("Stops"))
local Night = require(script.Parent:WaitForChild("Night"))
local Rewards = require(script.Parent:WaitForChild("Rewards"))

type Run = TrainRules.Run

local TICK = 0.1 -- the run loop (10 Hz)
local SLOW = 60 -- weekly boards
local SIT_REACH = 40
local PING_RANGE = 60
local PING_GAP = 2
local REACH_SLACK = 2 -- prompts: server distance may lag the client's by a frame or two
local RECLAIM = 15 -- s between tries to claim a save this session could not claim (QA M4)
local CREW_GROUP = "LanternPlayers" -- characters never collide with each other (QA m10)
local PLACEMENT = { hub = "seat", ride = "seat", night = "seat", stop = "platform", depot = "depot", ended = "hub" }
local PING_IDS: { [string]: boolean } = {}
for _, p in LanternConfig.PINGS do
	PING_IDS[p.id] = true
end
local REFUSALS = { -- prompt refusals have no reply channel: a notice with words
	gone = "Someone got there first",
	taken = "Someone is already carrying that",
	hands = "Hands full: drop or load first",
	full = "You can carry three small things",
	big = "Load or drop your small things first",
	far = "Get a little closer",
	phase = "Not now",
	refused = "Not now",
}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function today(): number
	return MetaRules.dayOf(os.time())
end

-- A fault in one part of the loop never stops the train, the saves or the other parts.
local function guarded<T>(name: string, fn: () -> T): T?
	local ok, result = pcall(fn)
	if not ok then
		warn(`[LanternServer] {name} failed: {tostring(result)}`)
		return nil
	end
	return result
end

-- Saves ---------------------------------------------------------------------------------------

local function publish(player: Player, profile: LanternProgress.Profile)
	player:SetAttribute("Profile", HttpService:JSONEncode(profile))
	player:SetAttribute("Tickets", profile.coins)
	player:SetAttribute("XP", profile.xp)
	player:SetAttribute("Level", MetaRules.levelFor(profile.xp))
	player:SetAttribute("Badge", profile.badge)
	player:SetAttribute("Follower", profile.follower)
	player:SetAttribute("Lamp", profile.lamp)
end

-- QA M4: a session that could not claim its save (a crashed server's lock, a DataStore outage, a lost
-- lock) plays on and keeps every change; the reclaim loop below claims the save later and stores
-- them. The player is told at once; the client shows "Saving paused" while ProfileOnline is false.
-- QA r5: while paused the HUD and menus keep the save as it was read and no reward is shown; after
-- the claim one toast shows what the session added to the real save (Rewards.reveal).
local PAUSED = {
	busy = "Your save is still closing on another server. Saving is paused: everything you earn now is kept and shows up in a minute or two.",
	offline = "Saving is paused: Roblox saves are not answering. Everything you earn now is kept and shows up when they are back.",
	lost = "Saving is paused: another server has your save open. Everything you earn now is kept and shows up when it lets go.",
}
local OFF = "Saving is off on this server: progress here lasts this session only."
local savingPaused: (Player, string) -> () -- set once the remotes exist (below)

-- A record from a later build is never rewritten as v1 (decision 0018 section 4): the kit's `newer`
-- option loads it read-only.
local saves = Saves.start({
	name = "LanternProfile",
	defaults = LanternProgress.defaults,
	sanitize = LanternProgress.sanitize,
	snapshot = LanternProgress.snapshot,
	newer = LanternProgress.isNewer,
	onChanged = function(player: Player, profile: LanternProgress.Profile)
		if not Rewards.paused(player) then -- QA r5: frozen while paused
			publish(player, profile)
		end
	end,
	onStatus = function(player: Player, status: string)
		savingPaused(player, status)
	end,
})

-- World and run -------------------------------------------------------------------------------

Models.preloadLantern()
local folder = World.build()
Train.build(folder)

-- Templates the client draws itself (ClientState.model): nil-safe, empty until LANTERN-011 has ids.
local clientModels = Instance.new("Folder")
clientModels.Name = "LanternModels"
clientModels.Parent = ReplicatedStorage
local CLIENT_MODELS = { "shadow_wisp", "lampeater_body", "lampeater_wing_l", "lampeater_wing_r" }
for _, c in LanternConfig.CRITTERS do
	table.insert(CLIENT_MODELS, `critter_{c.id}`)
end
for _, name in CLIENT_MODELS do
	task.spawn(Models.night, name, clientModels, Vector3.zero)
end

local function hash(s: string): number
	local h = 0
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 2147483647
	end
	return h
end

local run: Run = TrainRules.new(Rng.seed(os.time(), hash(game.JobId)), now())
local lastTick = now()
local remotes: Remotes.Handle
local pingAt: { [number]: number } = {}
local anchors: { [number]: Vector3 } = {} -- activity: where each standing member last counted as moving
-- (cleared when the server moves or seats a character: a server move is never activity, QA M3)
local painted = ""

local runFolder = Instance.new("Folder")
runFolder.Name = "LanternRun"
runFolder.Parent = ReplicatedStorage

local function fxAll(kind: string, payload: any)
	remotes.fxAll(kind, payload)
end

local function notice(player: Player, text: string)
	remotes.fx(player, "notice", { text = text })
end

local function rootOf(player: Player?): BasePart?
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function rootById(userId: number): BasePart?
	return rootOf(Players:GetPlayerByUserId(userId))
end

local function sync()
	Stops.sync(run.loot, run.carries, rootById)
end

local function commit(out: Run)
	run = out
	sync()
end

-- The side of the track a player stands up on now (+1 right of the train).
local function side(): number
	return if run.phase == "depot" or run.phase == "hub" then World.HUB_SIDE else LanternConfig.OUTER[run.line]
end

local function place(player: Player, placement: string)
	local character = player.Character
	if character == nil or rootOf(player) == nil then
		return
	end
	local n = table.find(run.order, player.UserId) or 1
	anchors[player.UserId] = nil
	if placement == "seat" then
		local m = run.crew[player.UserId]
		Train.seat(player, m and m.seat)
	elseif placement == "platform" then
		character:PivotTo(Stops.platform(n) or Train.door(side()))
	else
		character:PivotTo(World.hubSpot(n))
	end
end

-- Caught by the fog: hidden under the stop and anchored until "back" seats them.
local function hide(player: Player)
	local root = rootOf(player)
	anchors[player.UserId] = nil
	if root then
		root.Anchored = true
		local p = root.Position;
		(player.Character :: Model):PivotTo(CFrame.new(p.X, World.GROUND_Y - 12, p.Z))
	end
end

local function toHub()
	Stops.clear()
	Rewards.reset()
	Train.drive(run.track, run.d)
	for i, userId in run.order do
		local player = Players:GetPlayerByUserId(userId)
		local root = rootOf(player)
		if player and root then
			root.Anchored = false
			Carry.forget(userId)
			anchors[userId] = nil
			if Train.seatOf(player) then
				Train.stand(player, World.HUB_SIDE, World.hubSpot(i))
			else
				(player.Character :: Model):PivotTo(World.hubSpot(i))
			end
		end
	end
end

local function onPrompt(player: Player, itemId: number, action: string)
	guarded("prompt", function()
		local userId = player.UserId
		if run.crew[userId] == nil then
			notice(player, "Press PLAY to join the crew")
			return
		end
		local root, at = rootOf(player), Stops.itemPos(itemId)
		if root == nil or at == nil or (root.Position - at).Magnitude > LanternConfig.REACH + REACH_SLACK then
			notice(player, REFUSALS.far)
			return
		end
		local out, ok, code = (if action == "help" then TrainRules.help else TrainRules.pick)(run, userId, itemId)
		if not ok then
			notice(player, REFUSALS[code or "refused"] or REFUSALS.refused)
			return
		end
		if action == "pick" then
			Carry.start(userId, root.Position, now()) -- G4 checks the carry from here (QA M2)
		end
		commit(TrainRules.touch(out, userId, now()))
	end)
end

-- Carries out one event of a tick (architecture 4.2). `before` is the run before the tick.
local function handle(e: TrainRules.Event, before: Run, beams: { any }, owners: { number }, t: number)
	local player = if e.userId then Players:GetPlayerByUserId(e.userId) else nil
	local kind = e.kind
	if kind == "seat" then
		if player then
			Train.seat(player, e.payload)
		end
	elseif kind == "unseat" then
		if player then
			Train.stand(player, side())
		end
	elseif kind == "approach" then
		Stops.build(run.loot :: any, World.site(run.line, run.stop), folder, onPrompt)
	elseif kind == "arrive" then
		fxAll("arrive", {
			phase = "stop",
			leg = run.leg,
			stop = run.stop,
			tile = run.loot and run.loot.tile or "",
			line = run.line,
		})
	elseif kind == "bell" then
		fxAll("bell", { at = run.bellAt })
	elseif kind == "caught" then
		if player then
			hide(player)
			Carry.forget(player.UserId)
			Rewards.count(player, "caught", 1)
		end
		fxAll("caught", { userId = e.userId })
	elseif kind == "back" then
		if player then
			Train.seat(player, e.payload)
		end
		fxAll("back", { userId = e.userId })
	elseif kind == "load" then
		Rewards.load(run, e, t)
	elseif kind == "stopLeft" then
		if player then
			Rewards.award(player, "stop")
		end
	elseif kind == "depart" then
		Stops.clear()
		fxAll("depart", {})
	elseif kind == "wisp" then
		for userId, count in Night.fx(e.payload, run, before.night, beams, owners, t) do
			local shooter = Players:GetPlayerByUserId(userId)
			if shooter then
				Rewards.count(shooter, "puffs", count)
			end
			run = TrainRules.touch(run, userId, t) -- a puff is activity (QA M3)
		end
	elseif kind == "fed" then
		fxAll("fed", {})
	elseif kind == "depot" then
		Rewards.awardAll(run, "depot")
		fxAll("arrive", { phase = "depot", leg = run.leg, stop = 0, tile = "", line = run.line })
	elseif kind == "dawn" then
		Rewards.awardAll(run, "dawn")
		if e.payload and e.payload.fed then
			Rewards.awardAll(run, "fed")
		end
	elseif kind == "end" then
		Rewards.runEnd(run, e)
	elseif kind == "hub" then
		toHub()
	end
	-- "night" and "coalLow" need nothing here: the HUD reads Phase, Coal and CoalNeed.
end

-- Each event on its own guard (QA m1): a fault in one handler never drops a later "load" or "end".
local function dispatch(events: { TrainRules.Event }, before: Run, beams: { any }, owners: { number }, t: number)
	for _, e in events do
		guarded(e.kind, function()
			handle(e, before, beams, owners, t)
		end)
	end
end

-- The 10 Hz loop --------------------------------------------------------------------------------

local function activity(t: number)
	for _, userId in run.order do
		local player = Players:GetPlayerByUserId(userId)
		local root = rootOf(player)
		if player and root then
			local anchor = anchors[userId]
			if Train.seatOf(player) then
				anchors[userId] = nil -- standing up is a server move: anchor where they first stand
			elseif anchor == nil then
				anchors[userId] = root.Position
			elseif (root.Position - anchor).Magnitude >= LanternConfig.CREW.activeMove then
				anchors[userId] = root.Position
				run = TrainRules.touch(run, userId, t)
			end
		end
		if Night.aimedWithin(userId, 1) then
			run = TrainRules.touch(run, userId, t)
		end
	end
end

-- `ready`: the carriers whose G4 check passed this tick (only they may load, QA M2).
local function sample(t: number, dt: number, ready: { [number]: boolean }): (TrainRules.Input, { number })
	local seats = Train.seats()
	local depth, loadBox = {}, {}
	for _, userId in run.order do
		local root = rootById(userId)
		if root and not root.Anchored then
			if run.phase == "stop" and seats[userId] == nil then
				depth[userId] = Stops.depth(root.Position)
			end
			if run.carries[userId] then
				loadBox[userId] = ready[userId] == true and Carry.inLoadBox(root.Position)
			end
		end
	end
	local beams, owners = Night.beams()
	local crewSeats = {}
	for userId in run.crew do
		crewSeats[userId] = seats[userId]
	end
	return {
		now = t,
		dt = dt,
		seats = crewSeats,
		depth = depth,
		loadBox = loadBox,
		beams = beams,
		lanterns = Train.lanternPoints(),
	},
		owners
end

-- Help-carry break (14 studs, or the helper sat down) and the G4 speed check, before the tick's loads
-- (QA M2). Returns the carriers that passed and may load this tick.
local function carryChecks(t: number): { [number]: boolean }
	local ready = {}
	for _, userId in run.order do
		if run.carries[userId] == nil then
			Carry.forget(userId) -- a new carry starts its speed samples where it is picked up
		end
	end
	local loot = run.loot
	if run.phase ~= "stop" or loot == nil then
		return ready
	end
	for _, item in loot.items do
		if item.state == "carried" and item.helper then
			local a, b = rootById(item.by :: number), rootById(item.helper)
			local helper = Players:GetPlayerByUserId(item.helper)
			local sat = helper ~= nil and Train.seatOf(helper) ~= nil
			if a == nil or b == nil or sat or (a.Position - b.Position).Magnitude > LanternConfig.HELP_BREAK then
				run = TrainRules.letGo(run, item.helper)
			end
		end
	end
	for userId in run.carries do
		local player = Players:GetPlayerByUserId(userId)
		local root = rootOf(player)
		if player and root and not root.Anchored then
			local speed = CarryRules.speed(run.loot :: any, run.carries, userId)
			local passed, valid, canLoad = Carry.check(userId, root.Position, speed, t)
			ready[userId] = passed and canLoad
			local at = if passed then nil else Stops.toStop(valid)
			if at then
				local out, ok = TrainRules.drop(run, userId, at)
				if ok then
					run = out
					Carry.forget(userId)
					notice(player, "Too fast: your load slipped")
				end
			end
		end
	end
	return ready
end

local lastStatus: { [string]: any } = {}
local dAt = -math.huge

local function writeStatus(t: number)
	local s = TrainRules.status(run, t)
	for _, c in s.Crew do
		local player = Players:GetPlayerByUserId(c.userId)
		local profile = player and saves.get(player)
		c.badge = if profile then profile.badge else ""
	end
	s.Crew = HttpService:JSONEncode(s.Crew)
	s.Votes = HttpService:JSONEncode(s.Votes)
	for key, value in s do
		if type(value) == "number" and (value ~= value or math.abs(value) == math.huge) then
			value = 0
		end
		if lastStatus[key] ~= value and (key ~= "D" or t - dAt >= 0.5) then
			runFolder:SetAttribute(key, value)
			lastStatus[key] = value
			if key == "D" then
				dAt = t
			end
		end
	end
end

local function playerAttributes()
	local loot = run.loot
	for _, player in Players:GetPlayers() do
		local seat = Train.seatOf(player)
		local kind = if seat then seat:GetAttribute("Kind") else ""
		if player:GetAttribute("Seat") ~= kind then
			player:SetAttribute("Seat", kind)
		end
		local c = run.carries[player.UserId]
		local carry: { [string]: any } = { small = {} } -- always a JSON object
		if loot then
			if c then
				for _, id in c.small do
					table.insert(carry.small, loot.items[id].kind)
				end
				carry.big = if c.big then loot.items[c.big].kind else nil
			end
			for id, item in loot.items do
				if item.state == "carried" and item.helper == player.UserId then
					carry.help = id
				end
			end
		end
		local json = HttpService:JSONEncode(carry)
		if player:GetAttribute("Carry") ~= json then
			player:SetAttribute("Carry", json)
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and run.crew[player.UserId] then
			humanoid.WalkSpeed = if loot
				then CarryRules.speed(loot, run.carries, player.UserId)
				else LanternConfig.MOVE.walk
		end
	end
end

-- The livery of the conductor (GDD H6).
local function paint()
	local conductor = run.order[1]
	local player = if conductor then Players:GetPlayerByUserId(conductor) else nil
	local profile = player and saves.get(player)
	local livery = if profile then profile.livery else LanternConfig.SLOTS.livery
	if livery ~= painted then
		painted = livery
		local c = LanternConfig.cosmetic(livery)
		Train.paint(if c then c.colours else {})
	end
end

-- A reward text (toast and LastReward); never "saved" while saving is off (QA M4), never shown while
-- paused: the claim's toast shows what it paid on the real save (QA r5).
local function tell(player: Player, text: string)
	if text == "" or Rewards.paused(player) then
		return
	end
	if not saves.isOnline(player) then
		text = (string.gsub(text, "saved for you", "kept for you"))
	end
	player:SetAttribute("LastReward", text)
	notice(player, text)
end

-- UTC day rollover while online (architecture 11.12): quests and login slots earned yesterday are
-- paid with the "(saved for you)" toast, on the first tick of the day before any other reward.
local lastDay = today()
local function rollover()
	local day = today()
	if day == lastDay then
		return
	end
	lastDay = day
	for _, player in Players:GetPlayers() do
		local profile = saves.get(player)
		if profile then
			local _, text = LanternProgress.join(profile, day)
			saves.apply(player, function(p)
				return (LanternProgress.join(p, day))
			end)
			tell(player, text)
		end
	end
end

local function tick()
	local t = now()
	local dt = math.clamp(t - lastTick, 0, 1)
	guarded("rollover", rollover) -- before any reward of a new day (QA m4)
	activity(t)
	local ready = carryChecks(t) -- G4 before the tick's loads (QA M2)
	local input, owners = sample(t, dt, ready)
	local before = run
	local events
	run, events = TrainRules.tick(run, input)
	lastTick = t
	dispatch(events, before, input.beams, owners, t)
	sync()
	Night.heads()
	writeStatus(t)
	playerAttributes()
	paint()
end

local function drive()
	local d = run.d
	if run.phase == "ride" or run.phase == "night" then
		d = math.min(run.target, d + run.speed * math.max(0, now() - lastTick))
	end
	Train.drive(run.track, d)
end

-- Requests (decision 0018 section 3) -------------------------------------------------------------

local function moving(): boolean
	return run.phase == "ride" or run.phase == "night"
end

local function inFog(player: Player): boolean
	local m = run.crew[player.UserId]
	local root = rootOf(player)
	return (m ~= nil and (m.limboUntil or 0) > now()) or (root ~= nil and root.Anchored)
end

-- Runs a TrainRules request; keeps the run and marks the player active when it is accepted.
local function runRequest(player: Player, out: Run, ok: boolean, code: string?): (boolean, string?)
	if not ok then
		return false, code
	end
	commit(TrainRules.touch(out, player.UserId, now()))
	return true, nil
end

-- A profile change from a pure LanternProgress function: tried on the live profile first, then
-- applied with its captured inputs. `code` names the refusal.
local function profileRequest(
	player: Player,
	fn: (LanternProgress.Profile) -> (LanternProgress.Profile, boolean),
	code: string
): (boolean, string?)
	local profile = saves.get(player)
	if profile == nil then
		return false, "loading"
	elseif Rewards.paused(player) then
		return false, "paused" -- QA r5: claims, buys and picks wait for the real save
	end
	local _, ok = fn(profile)
	if not ok then
		return false, code
	end
	saves.apply(player, function(p)
		return (fn(p))
	end)
	if run.crew[player.UserId] then
		run = TrainRules.touch(run, player.UserId, now())
	end
	return true, nil
end

local ID = Payload.string({ max = 32, pattern = "^%w+$" })

local function pingArg(value: any): (boolean, any)
	if type(value) ~= "string" or #value > 32 then
		return false
	end
	local id = string.match(value, "^(%a+):%d+$") or string.match(value, "^(%a+)$")
	return id ~= nil and PING_IDS[id] == true, value
end

local actions: { [string]: Router.Action } = {
	play = {
		args = {},
		handler = function(player: Player)
			if run.crew[player.UserId] then
				return false, "refused"
			end
			local out, placement = TrainRules.join(run, player.UserId, now())
			if out.crew[player.UserId] == nil then
				return false, "full"
			end
			commit(out)
			place(player, placement)
			return true
		end,
	},
	sit = {
		args = { Payload.enum({ "any", "turret", "stoker", "mender", "passenger" }) },
		handler = function(player: Player, kind: string)
			local root = rootOf(player)
			local free, code = TrainRules.canSit(run, player.UserId) -- a carrier walks it home (QA M1)
			if not free then
				return false, code
			elseif root == nil or inFog(player) then
				return false, "refused"
			elseif not moving() and Train.distance(root.Position) > SIT_REACH then
				return false, "far"
			end
			local want = if kind == "any" then nil else kind
			local got = Train.seat(player, want, true)
			if got == nil or (want ~= nil and got ~= want) then
				return false, "seat"
			end
			return runRequest(player, run, true)
		end,
	},
	stand = {
		args = {},
		handler = function(player: Player)
			if Train.seatOf(player) == nil then
				return false, "seat"
			elseif moving() then
				return false, "phase"
			end
			Train.stand(player, side())
			return runRequest(player, run, true)
		end,
	},
	drop = {
		args = {},
		handler = function(player: Player)
			local root = rootOf(player)
			local at = root and Stops.toStop(root.Position)
			if at == nil then
				return false, "phase"
			end
			return runRequest(player, TrainRules.drop(run, player.UserId, at))
		end,
	},
	stoke = {
		args = {},
		handler = function(player: Player)
			local out, ok, code = TrainRules.stoke(run, player.UserId, now())
			if ok then
				Rewards.count(player, "stokes", 1)
			end
			return runRequest(player, out, ok, code)
		end,
	},
	mend = {
		args = {},
		handler = function(player: Player)
			local out, ok, code = TrainRules.mend(run, player.UserId, now())
			if ok then
				Rewards.count(player, "mends", 1)
			end
			return runRequest(player, out, ok, code)
		end,
	},
	buy = {
		args = { Payload.enum({ "boiler", "bunker", "lamps", "coal", "oil" }) },
		handler = function(player: Player, id: string)
			local out, ok, code = TrainRules.buy(run, player.UserId, id)
			if ok then
				fxAll("buy", { userId = player.UserId, id = id, level = (out.levels :: any)[id] })
			end
			return runRequest(player, out, ok, code)
		end,
	},
	vote = {
		args = { Payload.enum({ "forest", "lake", "free", "weekly" }) },
		handler = function(player: Player, choice: string)
			return runRequest(player, TrainRules.vote(run, player.UserId, choice))
		end,
	},
	ping = {
		args = { pingArg },
		cost = 2,
		handler = function(player: Player, arg: string)
			local userId, t = player.UserId, now()
			local root = rootOf(player)
			if run.crew[userId] == nil or root == nil then
				return false, "refused"
			elseif t - (pingAt[userId] or -math.huge) < PING_GAP then
				return false, "cooldown"
			end
			local id, item = string.match(arg, "^(%a+):?(%d*)$")
			local pos = root.Position + Vector3.new(0, 3, 0)
			local itemPos = if item and item ~= "" then Stops.itemPos(tonumber(item) :: number) else nil
			local seat = Train.seatOf(player)
			local aim = seat and Night.aim(seat.Name)
			if itemPos and (itemPos - root.Position).Magnitude <= PING_RANGE then
				pos = itemPos + Vector3.new(0, 2, 0) -- architecture 11.10: else at the player
			elseif id == "back" then
				pos = Train.door(side()).Position
			elseif id == "wisps" and seat and aim then
				pos = seat.Position + Train.frame():VectorToWorldSpace(Vector3.new(aim.x, aim.y, aim.z)) * 40
			elseif id == "thanks" then
				pos = root.Position + Vector3.new(0, 5, 0)
			end
			pingAt[userId] = t
			fxAll("ping", { userId = userId, id = id, pos = pos })
			return runRequest(player, run, true)
		end,
	},
	claimQuest = {
		args = { ID },
		handler = function(player: Player, id: string)
			local day = today()
			return profileRequest(player, function(p)
				local out, ok = LanternProgress.claimQuest(p, day, id)
				return out, ok
			end, "refused")
		end,
	},
	claimLogin = {
		args = { Payload.enum({ "week", "month" }) },
		handler = function(player: Player, track: string)
			local profile = saves.get(player)
			if profile == nil then
				return false, "loading"
			end
			local day = today()
			local slot = (profile.login :: any)[`{track}Claimed`] + 1 -- the slot this request saw
			local _, ok, text = LanternProgress.claimLogin(profile, track, day, slot)
			local accepted, code = profileRequest(player, function(p)
				local out, paid = LanternProgress.claimLogin(p, track, day, slot)
				return out, paid
			end, "locked")
			if accepted and ok then
				tell(player, text)
			end
			return accepted, code
		end,
	},
	buyCosmetic = {
		args = { ID },
		handler = function(player: Player, id: string)
			local profile = saves.get(player)
			local cosmetic = LanternConfig.cosmetic(id)
			local code = if profile and profile.owned[id]
				then "owned"
				elseif profile and cosmetic and cosmetic.price and profile.coins < cosmetic.price then "tickets"
				else "locked"
			return profileRequest(player, function(p)
				return LanternProgress.buy(p, id)
			end, code)
		end,
	},
	equip = {
		args = { ID },
		handler = function(player: Player, id: string)
			return profileRequest(player, function(p)
				return LanternProgress.equip(p, id)
			end, "locked")
		end,
	},
	badge = {
		args = { Payload.enum({ "stoker", "lamplighter", "scout", "mender", "none" }) },
		handler = function(player: Player, role: string)
			return profileRequest(player, function(p)
				return LanternProgress.setBadge(p, role)
			end, "locked")
		end,
	},
	follower = {
		args = { ID },
		handler = function(player: Player, species: string)
			return profileRequest(player, function(p)
				return LanternProgress.setFollower(p, species)
			end, "locked")
		end,
	},
}

local router = Router.new({
	actions = actions,
	ready = function(player)
		return saves.isLoaded(player)
	end,
	onError = function(action, err)
		warn(`[LanternServer] request {tostring(action)} failed: {tostring(err)}`)
	end,
})
remotes = Remotes.create("LanternRemotes", router)
Night.start(remotes.folder, remotes.fxAll)
Rewards.start(saves, remotes)

local function saveKey(player: Player): string
	return `player_{player.UserId}` -- the kit Saves key
end

savingPaused = function(player: Player, status: string)
	if status == "online" then
		return
	end
	player:SetAttribute("ProfileOnline", false)
	local session = saves.store:session(saveKey(player))
	if session then
		publish(player, session.profile) -- the save as read (defaults after a failed load); then frozen
	end
	notice(player, if session and session.retry then PAUSED[status] or PAUSED.offline else OFF)
end

-- QA M4: every RECLAIM seconds, each paused session tries to claim its save; on success the stored
-- save plus every change of this session is written and becomes the profile.
task.spawn(function()
	while true do
		task.wait(RECLAIM)
		for _, player in Players:GetPlayers() do
			local session = saves.store:session(saveKey(player))
			if session and session.retry then
				task.spawn(function()
					local claimed, before = saves.store:reclaim(saveKey(player), os.time())
					if claimed and player.Parent then
						player:SetAttribute("ProfileOnline", true)
						publish(player, saves.get(player))
						notice(player, "Saving is back on: everything from this session is saved.")
						Rewards.reveal(player, before)
					end
				end)
			end
		end
	end
end)

PhysicsService:RegisterCollisionGroup(CREW_GROUP)
PhysicsService:CollisionGroupSetCollidable(CREW_GROUP, CREW_GROUP, false)
local function noShove(character: Model)
	local function set(d: Instance)
		if d:IsA("BasePart") then
			d.CollisionGroup = CREW_GROUP
		end
	end
	for _, d in character:GetDescendants() do
		set(d)
	end
	character.DescendantAdded:Connect(set)
end

-- A player who is not in the crew (the start menu) never rides: stood up at once (0018 2.3).
Train.onOccupant(function(seat: Seat)
	local occupant = seat.Occupant
	local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
	if occupant and (player == nil or run.crew[player.UserId] == nil) then
		task.defer(Train.clearSeat, seat, side())
	end
end)

-- Players ------------------------------------------------------------------------------------

local function onCharacter(player: Player, character: Model)
	noShove(character)
	task.defer(function()
		if character:WaitForChild("HumanoidRootPart", 5) and run.crew[player.UserId] then
			place(player, PLACEMENT[run.phase])
		end
	end)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then -- spawned while the server was still booting
		onCharacter(player, player.Character)
	end
	saves.load(player)
	if player.Parent == nil then
		return
	end
	local profile = saves.get(player)
	if profile then
		local day = today()
		local _, text = LanternProgress.join(profile, day)
		saves.apply(player, function(p)
			return (LanternProgress.join(p, day))
		end)
		tell(player, text)
	end
end

-- Leaving drops what the player carries (nothing they earned: loads were paid when they landed).
local function onLeave(player: Player)
	guarded("leave", function()
		local userId = player.UserId
		local root = rootOf(player)
		local at = if root then Stops.toStop(root.Position) else nil
		local out, events = TrainRules.leave(run, userId, at)
		run = out
		dispatch(events, run, {}, {}, now())
		Night.forget(userId)
		Carry.forget(userId)
		pingAt[userId], anchors[userId] = nil, nil
		sync()
	end)
end

if Players.MaxPlayers > LanternConfig.CREW.max then
	-- Max Players is set by hand in Creator Hub (decision 0018 section 1); extra players cannot join the crew.
	warn(`[LanternServer] Max Players {Players.MaxPlayers} is above the crew of {LanternConfig.CREW.max}`)
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(onLeave)

local acc, slowAt = 0, -math.huge
RunService.Heartbeat:Connect(function(dt: number)
	guarded("drive", drive)
	guarded("carry", Carry.step)
	acc += dt
	if acc >= TICK then
		acc = math.min(acc - TICK, TICK) -- drop a backlog instead of bursting ticks
		guarded("tick", tick)
	end
	if os.clock() - slowAt >= SLOW then
		slowAt = os.clock()
		task.spawn(function()
			guarded("boards", Rewards.refreshBoards)
		end)
	end
end)

print(`[LanternServer] ready: {#LanternConfig.CARS} cars, tracks {World.paths.forest.length // 1} studs`)
