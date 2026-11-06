--!strict
-- Lantern Express nights on the server (docs/architecture/lantern.md 4.5, decision 0018 section 3):
-- the `Aim` intake (a direction only, checked, rate limited and clamped), the fresh beams for the
-- 10 Hz tick, the turret heads, and the Fx of wisp events. The hit test runs inside the pure
-- WispRules.step on the server's own wisp positions; the client never sends a hit, a position or a
-- time. Clients draw wisps from the spawn records with WispRules.pos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Kit = ReplicatedStorage:WaitForChild("Kit")
local DepotRules = require(Shared:WaitForChild("DepotRules"))
local LanternConfig = require(Shared:WaitForChild("LanternConfig"))
local RateLimit = require(Kit:WaitForChild("RateLimit"))
local TrainRules = require(Shared:WaitForChild("TrainRules"))
local WispRules = require(Shared:WaitForChild("WispRules"))
local Train = require(script.Parent:WaitForChild("Train"))

local Night = {}

type Vec3 = LanternConfig.Vec3
type Aim = { dir: Vec3, at: number, userId: number }

local BATCH = 40 -- wisp records per Fx message (architecture 5)
local limiter = RateLimit.new({ burst = 4, perSecond = 12 })
local aims: { [string]: Aim } = {} -- by turret seat id
local lastAim: { [number]: number } = {} -- UserId -> os.clock() of the last aim that turned (activity)
local turnedTo: { [number]: Vec3 } = {} -- UserId -> the aim that last counted as activity
local fxAll: (string, any) -> () = function(_kind: string, _payload: any) end

local function finite(x: number): boolean
	return x == x and math.abs(x) ~= math.huge
end

-- The Aim checks of decision 0018 in order; anything else is dropped silently.
local function onAim(player: Player, dir: any)
	if typeof(dir) ~= "Vector3" then
		return
	end
	local m = dir.Magnitude
	if not (finite(dir.X) and finite(dir.Y) and finite(dir.Z)) or m < 0.5 or m > 1.5 then
		return
	end
	local seat = Train.seatOf(player)
	if seat == nil or seat:GetAttribute("Kind") ~= "turret" then
		return
	end
	if not limiter:take(player.UserId, os.clock()) then
		return
	end
	local clamped = WispRules.clampAim({ x = dir.X, y = dir.Y, z = dir.Z })
	if clamped then
		aims[seat.Name] = { dir = clamped, at = os.clock(), userId = player.UserId } -- keeps the beam fresh
		-- QA M3: only a real turn is activity; the client re-sends a still aim every 0.3 s for the beam.
		if WispRules.turned(turnedTo[player.UserId], clamped) then
			turnedTo[player.UserId] = clamped
			lastAim[player.UserId] = os.clock()
		end
	end
end

-- Creates the `Aim` UnreliableRemoteEvent in the remotes folder.
function Night.start(folder: Instance, fx: (string, any) -> ())
	fxAll = fx
	local remote = Instance.new("UnreliableRemoteEvent")
	remote.Name = "Aim"
	remote.OnServerEvent:Connect(onAim)
	remote.Parent = folder
end

-- The tick's beams (train frame), one per turret whose occupant aimed within BEAM.stale, and the
-- UserId behind each beam (puff credit).
function Night.beams(): ({ WispRules.Beam }, { number })
	local beams, owners = {}, {}
	local t = os.clock()
	for _, turret in Train.turrets() do
		local aim = aims[turret.seat.Name]
		local occupant = turret.seat.Occupant
		local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		if aim and player and player.UserId == aim.userId and t - aim.at <= LanternConfig.BEAM.stale then
			table.insert(beams, { origin = turret.origin, dir = aim.dir })
			table.insert(owners, aim.userId)
		end
	end
	return beams, owners
end

-- The last aim (train frame) stored for a turret seat, if any.
function Night.aim(seatId: string): Vec3?
	local aim = aims[seatId]
	return if aim then aim.dir else nil
end

-- True when `userId` turned their aim within `seconds` (activity, GDD I3).
function Night.aimedWithin(userId: number, seconds: number): boolean
	return os.clock() - (lastAim[userId] or -math.huge) <= seconds
end

-- Turns every turret head to its last aim (10 Hz; heads replicate, clients follow them).
function Night.heads()
	for seatId, aim in aims do
		Train.aimHead(seatId, aim.dir)
	end
end

function Night.forget(userId: number)
	limiter:reset(userId)
	lastAim[userId], turnedTo[userId] = nil, nil
	for seatId, aim in aims do
		if aim.userId == userId then
			aims[seatId] = nil
		end
	end
end

-- Sends the Fx for one WispRules event (from TrainRules' "wisp" event) and returns the puff credit
-- by UserId: every player whose beam lit a puffed wisp in this tick (architecture 11.4). `before`
-- is the night before the tick (puffed wisps are gone from the new one).
function Night.fx(
	e: WispRules.Event,
	run: TrainRules.Run,
	before: WispRules.Night?,
	beams: { WispRules.Beam },
	owners: { number },
	now: number
): { [number]: number }
	local credit: { [number]: number } = {}
	if e.kind == "spawn" then
		local list = {}
		for _, w in e.wisps or {} do
			table.insert(
				list,
				{ id = w.id, born = w.born, from = w.from, target = w.target, speed = w.speed, phase = w.phase }
			)
			if #list == BATCH then
				fxAll("wisps", { list = list })
				list = {}
			end
		end
		if #list > 0 then
			fxAll("wisps", { list = list })
		end
	elseif e.kind == "puff" then
		fxAll("puff", { ids = e.ids })
		local range = DepotRules.range(run.levels)
		for _, id in e.ids or {} do
			local w = before and before.wisps[id]
			if w then
				local p = WispRules.pos(w, now)
				for i, beam in beams do
					if WispRules.lit(beam, p, range) then
						credit[owners[i]] = (credit[owners[i]] or 0) + 1
					end
				end
			end
		end
	elseif e.kind == "dim" then
		fxAll("dim", { id = if e.ids then e.ids[1] else nil, lantern = run.lantern })
	elseif e.kind == "lampeater" then
		local l = run.night and run.night.lampeater
		fxAll("lampeater", { born = if l then l.born else now, seed = run.seed })
	elseif e.kind == "dive" then
		local l = run.night and run.night.lampeater
		fxAll("dive", { at = if l and l.dive then l.dive.at else now, target = e.target })
	elseif e.kind == "shoo" then
		fxAll("shoo", { target = e.target }) -- not in 0018's list; the LANTERN-007 client plays it
	end
	-- "fed" goes out as the run's own event.
	return credit
end

return Night
