--!strict
-- Petal Catch on the server (garden-wheel.md W6, architecture garden-wheel.md 3.1): one round per
-- player, kept in a module table outside State.live. WheelRules decides every catch, the tier and the
-- prize from the server's own 5 Hz root samples; no remote carries a catch, position, score, time or
-- wedge. Event handling never yields, so a prize is in the profile and the write queue in the same
-- step that ends the round. Leaving grants nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local Rng = require(Shared:WaitForChild("Rng"))
local WheelRules = require(Shared:WaitForChild("WheelRules"))
local Dash = require(script.Parent:WaitForChild("Dash"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local State = require(script.Parent:WaitForChild("State"))
local WheelWorld = require(script.Parent:WaitForChild("WheelWorld"))

type Vec3 = GardenRules.Vec3
type Entry = { round: WheelRules.Round, drops: { WheelRules.Drop } }

local WHEEL = GardenConfig.WHEEL
local SPINS_OFF_TEXT = "Saving is off on this server, so this is a practice round."
local UNSAVED_TEXT = "You won a prize, but saving is off on this server: it lasts this visit only."

local Wheel = {}

local world = WheelWorld.build()
Wheel.prompt = world.prompt

local rounds: { [Player]: Entry } = {}
local counter = 0
local closed = false

local function rootPos(player: Player): Vec3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart")
		then { x = root.Position.X, y = root.Position.Y, z = root.Position.Z }
		else nil
end

function Wheel.isPlaying(player: Player): boolean
	return rounds[player] ~= nil
end

-- The wheelStart action and the stand prompt. Eligibility is fixed here for the whole round.
function Wheel.start(player: Player): boolean
	local profile = Profiles.get(player)
	if closed or State.live[player] == nil or profile == nil or rounds[player] or Dash.isRacing(player) then
		return false
	end
	local root = rootPos(player)
	if root == nil or not GardenRules.within(root, WHEEL.stand, WHEEL.promptRange) then
		return false
	end
	local t = Workspace:GetServerTimeNow()
	local today = MetaRules.dayOf(os.time())
	counter += 1
	local seed = Rng.seed(math.floor(t * 1000) % 2 ^ 32, player.UserId, counter)
	if RunService:IsStudio() then
		seed = tonumber(world.folder:GetAttribute("Seed")) or seed -- W11 seeded rounds, Studio only
	end
	local eligible = Profiles.isOnline(player) and WheelRules.canSpin(profile, today)
	rounds[player] = {
		round = WheelRules.new(player.UserId, seed, t, eligible, WheelRules.spinsToday(profile, today) + 1),
		drops = WheelRules.schedule(seed, t),
	}
	Remotes.fxTo(player, "wheelStart", {
		seed = seed,
		startAt = t,
		endAt = t + WHEEL.round,
		practice = not eligible,
		spinsLeft = WheelRules.spinsLeft(profile, today),
	})
	if not Profiles.isOnline(player) then
		Remotes.notice(player, SPINS_OFF_TEXT)
	end
	return true
end

-- home, PlayerRemoving: drops the round, grants nothing.
function Wheel.leave(player: Player)
	rounds[player] = nil
end

-- The round's end: the prize is rolled and applied before anything can yield. `today` is the day of
-- the finish; eligibility stays as fixed at the start. The roll's seed never derives from the petal seed.
local function finish(player: Player, tier: WheelRules.Tier, score: number, today: number)
	rounds[player] = nil
	local function left(): number
		local p = Profiles.get(player)
		return if p then WheelRules.spinsLeft(p, today) else 0
	end
	if tier == "none" then
		Remotes.fxTo(player, "wheelOver", { score = score, tier = tier, spinsLeft = left() })
		return
	end
	-- The spin is numbered on the finish day: after 00:00 UTC it is spin 1 of the new day (W9, QA m5).
	local profile = Profiles.get(player)
	local n, lucky = (if profile then WheelRules.spinsToday(profile, today) else 0) + 1, tier == "lucky"
	local jitter = math.floor((os.clock() % 1) * 2 ^ 20)
	local wedge = WheelRules.roll(Rng.seed(os.time(), player.UserId, WheelRules.spinId(today, n) + jitter), lucky)
	local applied, coins = false, 0
	Profiles.apply(player, "wheelSpin", function(p)
		local out, ok, paid = WheelRules.award(p, today, n, wedge)
		applied, coins = ok, paid -- read right after the first (in-memory) application
		return out
	end)
	-- A spin that did not apply is never announced as saved: the end card shows no wheel.
	Remotes.fxTo(player, "wheelOver", { score = score, tier = if applied then tier else "none", spinsLeft = left() })
	if not applied then
		return
	end
	Remotes.fxTo(player, "wheelSpin", {
		wedge = wedge,
		lucky = lucky,
		spinId = WheelRules.spinId(today, n),
		coins = coins,
		spinsLeft = left(),
	})
	if not Profiles.isOnline(player) then
		Remotes.notice(player, UNSAVED_TEXT)
	end
end

-- 5 Hz, after Dash.step in fastTick. `roots` is the tick's snapshot; `today` the tick's day.
function Wheel.step(roots: { [Player]: Vec3 }, today: number)
	if closed then
		return
	end
	local t = Workspace:GetServerTimeNow()
	for player, entry in rounds do
		if player.Parent == nil or State.live[player] == nil then
			rounds[player] = nil
			continue
		end
		local _, overs = WheelRules.finish(entry.round, t)
		local over = overs[1]
		if over then
			finish(player, over.tier :: WheelRules.Tier, over.score :: number, today)
			continue
		end
		local root = roots[player]
		if root then
			local round, events = WheelRules.sample(entry.round, entry.drops, root, t)
			entry.round = round
			for _, e in events do
				Remotes.fxTo(player, "wheelCatch", { i = e.i, kind = e.drop, score = e.score })
			end
		end
	end
end

-- BindToClose: every round is dropped with no spin. Applied spins save with finishAll.
function Wheel.close()
	closed = true
	table.clear(rounds)
end

return Wheel
