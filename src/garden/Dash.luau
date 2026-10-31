--!strict
-- Splash Dash on the server (GDD T, docs/architecture/garden.md 4.3a): the one live Round, outside
-- State.live because a round outlives any one player. DashRules decides every outcome from the
-- server's own root samples; this module turns player state into entrants and carries out the
-- events. No remote supplies a position, time, hit or checkpoint. Event handling never yields, so a
-- prize is in the profile and the write queue in the same step that accepts the finish.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DashRules = require(Shared:WaitForChild("DashRules"))
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenProgress = require(Shared:WaitForChild("GardenProgress"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local DashWorld = require(script.Parent:WaitForChild("DashWorld"))
local Plots = require(script.Parent:WaitForChild("Plots"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local State = require(script.Parent:WaitForChild("State"))

type Vec3 = GardenRules.Vec3

local DASH = GardenConfig.DASH
local GROUP = "Racers"
local PRIZE = (GardenConfig.egg(DASH.prizeEgg) :: GardenConfig.Egg).name
local OUT_TEXT = "You are out of this round."
local PRIZES_OFF_TEXT = "Saving is off on this server, so prizes are off this visit."
local PASSED_OFFLINE_TEXT = `You won! Saving is off on this server, so this {PRIZE} goes to the next finisher.`
local PASSED_CAPPED_TEXT =
	`You won! You have today's {DASH.prizesPerDay} {PRIZE}s, so this one goes to the next finisher.`
local UNSAVED_TEXT = `You won a {PRIZE}, but saving is off on this server: it lasts this visit only.`

local Dash = {}

local world = DashWorld.build()
Dash.prompt = world.prompt

local round = DashRules.new()
local names: { [number]: string } = {} -- this round's display names: a leaver still shows on the card
local closed = false

if not PhysicsService:IsCollisionGroupRegistered(GROUP) then
	PhysicsService:RegisterCollisionGroup(GROUP)
end
PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)

-- shortcut: racers stay in the group after a round, so players never bump in the garden; harmless,
-- scope it to rounds only if a playtest asks (garden.md 4.3a).
function Dash.track(character: Model)
	local function join(d: Instance)
		if d:IsA("BasePart") then
			d.CollisionGroup = GROUP
		end
	end
	for _, d in character:GetDescendants() do
		join(d)
	end
	character.DescendantAdded:Connect(join)
end

-- Moves a racer and starts the settle window: the client's old position can still arrive.
local function teleport(id: number, player: Player?, at: Vec3, cp: number, t: number)
	local character = player and player.Character
	if character then
		local face = DashRules.facing(cp)
		local pos = Vector3.new(at.x, at.y, at.z)
		character:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(face.x, 0, face.z)))
	end
	round = DashRules.teleported(round, id, t, at)
end

local function sendHome(player: Player?)
	local live = player and State.live[player]
	local character = player and player.Character
	if live and character then
		character:PivotTo(Plots.gate(live.plot))
	end
end

-- The prize, before anything can yield. The ops are pure and capture the day of the finish, so a
-- re-apply on the stored record gives the same result and the leave flush writes them.
local function award(player: Player, e: DashRules.Event): number
	local today = MetaRules.dayOf(os.time())
	local profile = Profiles.get(player)
	if profile == nil then
		return 0
	end
	if e.egg then
		Profiles.apply(player, "dashPrize", function(p)
			return (GardenProgress.dashPrize(p, today))
		end)
		if not Profiles.isOnline(player) then
			Remotes.notice(player, UNSAVED_TEXT)
		end
		return 0
	end
	if e.place == 1 then
		Remotes.notice(player, if Profiles.isOnline(player) then PASSED_CAPPED_TEXT else PASSED_OFFLINE_TEXT)
	end
	local _, coins = GardenProgress.dashCoins(profile, today)
	if coins > 0 then -- at the cap nothing changes, so nothing is saved
		Profiles.apply(player, "dashCoins", function(p)
			return (GardenProgress.dashCoins(p, today))
		end)
	end
	return coins
end

local function carry(e: DashRules.Event, t: number)
	local id = e.id :: number
	local player = if e.id then Players:GetPlayerByUserId(id) else nil
	if e.kind == "start" then
		for i, racerId in e.ids or {} do
			local racer = Players:GetPlayerByUserId(racerId)
			teleport(racerId, racer, DashRules.startSpot(i), 0, t)
			if racer then
				names[racerId] = racer.DisplayName
				if not Profiles.isOnline(racer) then
					Remotes.notice(racer, PRIZES_OFF_TEXT)
				end
			end
		end
	elseif e.kind == "go" then
		world.arch.CanCollide = false
	elseif e.kind == "checkpoint" then
		if player then
			Remotes.fxTo(player, "dashCheckpoint", { cp = e.cp, total = #DASH.checkpoints })
		end
	elseif e.kind == "splash" or e.kind == "flag" then
		local cp = e.cp :: number
		teleport(id, player, DashRules.respawnPoint(cp), cp, t)
		if e.kind == "flag" then
			warn(`[Dash] {id} failed a position check`)
		end
		if player then
			Remotes.fxTo(player, "dashSplash", { cp = cp, reason = if e.kind == "flag" then "check" else "fall" })
		end
	elseif e.kind == "out" then
		warn(`[Dash] {id} struck out of the round`)
		sendHome(player)
		if player then
			Remotes.notice(player, OUT_TEXT)
		end
	elseif e.kind == "finish" then
		local coins = if player then award(player, e) else 0
		Remotes.fx("dashFinish", {
			by = id,
			name = names[id],
			place = e.place,
			time = e.time,
			egg = e.egg == true,
			coins = coins,
		})
	elseif e.kind == "over" then
		world.arch.CanCollide = true
		for _, racerId in e.ids or {} do
			sendHome(Players:GetPlayerByUserId(racerId))
		end
		Remotes.fx("dashOver", {
			winner = if e.winner then names[e.winner] else nil,
			prize = if e.prizeTo then names[e.prizeTo] else nil,
			reason = e.reason,
		})
		table.clear(names)
	end
end

local function run(t: number, nextRound: DashRules.Round, events: { DashRules.Event })
	round = nextRound
	for _, e in events do
		carry(e, t)
	end
end

function Dash.isRacing(player: Player): boolean
	return DashRules.isRacer(round, player.UserId)
end

-- The dashReady action and the pad prompt. No range check: READY in the panel works from anywhere
-- (GDD T3), and being ready gives nothing a client could not ask for.
function Dash.toggle(player: Player): boolean
	if closed then
		return false
	end
	local id = player.UserId
	local changed
	round, changed = DashRules.setReady(round, id, not DashRules.isReady(round, id), Workspace:GetServerTimeNow())
	return changed
end

-- PlayerRemoving, and the home action for a racer. Grants nothing: anything already won stays in the queue.
function Dash.leave(player: Player)
	if closed then
		return
	end
	local t = Workspace:GetServerTimeNow()
	run(t, DashRules.leave(round, player.UserId, t))
end

-- CharacterAdded: a racer's new character goes to the last checkpoint, not the plot.
function Dash.place(player: Player): boolean
	if closed or not Dash.isRacing(player) then
		return false
	end
	local id = player.UserId
	local cp = DashRules.respawnCp(round, id)
	teleport(id, player, DashRules.respawnPoint(cp), cp, Workspace:GetServerTimeNow())
	return true
end

-- 5 Hz, last in fastTick. `roots` is the tick's snapshot; `round.racers` is replaced, never changed,
-- so the loop below keeps walking the racers it started with.
function Dash.step(roots: { [Player]: Vec3 }, today: number)
	if closed then
		return
	end
	local t = Workspace:GetServerTimeNow()
	if round.phase == "countdown" and t >= round.at then
		local entrants: { DashRules.Entrant } = {}
		for _, id in round.ready do
			local player = Players:GetPlayerByUserId(id)
			local profile = player and Profiles.get(player)
			if player and profile and State.live[player] and roots[player] then
				local eligible = Profiles.isOnline(player) and GardenProgress.dashEligible(profile, today)
				table.insert(entrants, { id = id, eligible = eligible })
			end
		end
		run(t, DashRules.start(round, t, entrants))
	end
	run(t, DashRules.step(round, t))
	for id in round.racers do
		local player = Players:GetPlayerByUserId(id)
		local root = player and roots[player]
		if root then
			run(t, DashRules.sample(round, id, root, t))
		end
	end
end

-- GardenStatus.dash, 1 Hz; the pad's label follows it.
function Dash.status(): { [string]: any }
	local status = DashRules.status(round)
	world.label(status)
	return status
end

-- BindToClose: no prize and no teleports. Prizes already applied save with finishAll.
function Dash.close()
	closed = true
	round = DashRules.new()
end

return Dash
