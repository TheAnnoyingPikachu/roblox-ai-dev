--!strict
-- The wave fight's show (decisions 0042, 0108): plays one wave fight on the battlefield so it can be
-- watched. The team and the wave fight through BattleRules exactly as the rules decide (with its
-- log), and this module only replays that log: the enemies walk in, each attack plays its
-- animation and its hit lands when the log says, health bars drop, the fallen fall. Nothing here
-- decides who wins and nothing is saved: coins, XP and progress are not touched.
--
-- A show may be several players' (a shared fight, decision 0108): its first member hosts it (the show is
-- kept under that player, and its models stand in that player's folder), every member's team stands at
-- its own seat (Battlefield.seat) and every member's taps and clicks go into the one fight.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BattleRules = require(Shared:WaitForChild("BattleRules"))
local LevelRules = require(Shared:WaitForChild("LevelRules"))
local FightFx = require(Shared:WaitForChild("FightFx"))
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local Battlefield = require(script.Parent:WaitForChild("Battlefield"))
local Creatures = require(script.Parent:WaitForChild("Creatures"))

type Owned = StationRules.Owned
type Slot = {
	model: Model,
	home: CFrame,
	hp: number,
	maxHp: number,
	version: number, -- counts every change to hp, so a late heal can tell it is stale
	side: number,
	front: boolean, -- side 2: stands in the front row (decision 0101)
	shown: boolean, -- side 2: has walked into the arena
	stepped: boolean, -- side 2: has stepped up into the front line
}

local WaveShow = {}

local GROUND = 0.05 -- how far above the land a creature's feet are set
local WALK_SPEED = 18 -- studs a second the enemies walk out of the gate at
-- archers and mages (any of their models, decision 0104) stand and shoot instead of lunging
local function ranged(asset: string): boolean
	return string.find(asset, "^foe_archer") ~= nil or string.find(asset, "^foe_mage") ~= nil
end

local counter = 0
local runs: { [Player]: number } = {} -- the token of each host's current show
local hostOf: { [Player]: Player } = {} -- whose show each player is in (a host is in their own)
-- A show's fight as it stands (decision 0092): the player's taps so far and the fight they give.
-- `start` is os.clock() at the fight's time 0 (math.huge during the walk-in).
type Show = {
	token: number,
	team: { Owned },
	foes: { Owned },
	taps: { BattleRules.Tap },
	log: { BattleRules.Hit },
	won: boolean,
	actions: number,
	seconds: number,
	ends: { number }, -- the team's HP at the end, shares by slot (a run carries it, decision 0098)
	start: number,
	ours: { Model }, -- the team's models by slot
	members: { Player }, -- the players in the fight: a team's `owner` is its player's place here
	seats: { [Player]: { number } }, -- each member's own animals: their slots in the fight
	strikeTo: { [number]: number }, -- the fight time of each member's last click strike laid (decision 0106)
	setup: BattleRules.Setup?,
	arrivals: { [number]: number }, -- when each foe is in the fight (BattleRules.battle, decision 0101)
	engaged: { [number]: number }, -- when each foe joined the front line
	places: { [number]: number }, -- and its place along it (decision 0108)
}
local shows: { [Player]: Show } = {}
local TAP_AHEAD = FightFx.TAP_AHEAD -- seconds ahead of the show a tap lands
local pending: { [Player]: () -> () } = {} -- the result report, owed once per show
local active: Player? = nil -- whose show is on the field (it holds one at a time): its host

-- A team to try the waves with: the three starters, or the strongest team there is, all stats
-- trained to 70 (the best a player can reach), so waves up to the 60s are fair.
function WaveShow.team(which: string): { Owned }
	local ids: { { string | boolean } } = if which == "mythics"
		then {
			{ "lion", "sun_lion" },
			{ "rhino", "lava_rhino" },
			{ "flamingo", "phoenix_flamingo" },
			{ "elephant", "frost_elephant" },
		}
		else { { "jackal", false }, { "tortoise", false }, { "meerkat", false } }
	local out = {}
	for _, id in ids do
		local v = if id[2] then id[2] :: string else nil
		local a: Owned =
			{ s = id[1] :: string, v = v, stats = StationRules.versionStats(id[1] :: string, v) :: StationConfig.Stats }
		if which == "mythics" then
			for _, st in StationConfig.STATIONS do
				a = StationRules.train(a, st.id, 1e12)
			end
		end
		table.insert(out, a)
	end
	return out
end

local function folderOf(player: Player): Folder
	local name = `WaveShow{player.UserId}`
	local f = Workspace:FindFirstChild(name) :: Folder?
	if f == nil then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = Workspace
	end
	return f :: Folder
end

-- Whose show is in the arena now, if any.
function WaveShow.active(): Player?
	return active
end

-- The fight lets go of `player`'s view and HUD.
local function release(player: Player)
	hostOf[player] = nil
	for _, name in { "CamFocus", "CamFrom", "CamScale", "ShieldAt", "ShieldReady", "FightWave", "FightFolder" } do
		player:SetAttribute(name, nil)
	end
end

-- The members of `show` still in it.
local function present(show: Show): { Player }
	local out = {}
	for _, m in show.members do
		if hostOf[m] == show.members[1] then
			table.insert(out, m)
		end
	end
	return out
end

-- Stop the player's show and remove what it made. A result not yet reported is reported now. A player in
-- another player's show only leaves it: that fight goes on for the others, this player's animals in it.
function WaveShow.clear(player: Player)
	local host = hostOf[player]
	if host and host ~= player then
		release(player)
		return
	end
	local show = shows[player]
	runs[player] = nil
	shows[player] = nil
	for _, m in if show then present(show) else {} do
		release(m)
	end
	release(player)
	if active == player then
		active = nil
	end
	local owed = pending[player]
	if owed then
		pending[player] = nil
		owed()
	end
	local f = Workspace:FindFirstChild(`WaveShow{player.UserId}`)
	if f then
		f:ClearAllChildren()
	end
end

local function busy(model: Model): boolean -- is an attack or a spell still playing?
	local anim, at = model:GetAttribute("Anim"), model:GetAttribute("AnimAt")
	local length = if type(anim) == "string" then Creatures.LENGTH[anim] else nil
	return length ~= nil and anim ~= "hit" and type(at) == "number" and Workspace:GetServerTimeNow() - at < length
end

-- The fallen stop glowing and sink out of sight a moment later (unless raised again first).
local function fall(model: Model)
	Creatures.play(model, "die")
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d.Enabled = false
		end
	end
	task.delay(2.2, function()
		if model.Parent == nil or model:GetAttribute("Anim") ~= "die" then
			return
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				d:SetAttribute("Shown", d.Transparency)
				TweenService:Create(d, TweenInfo.new(1.2), { Transparency = 1 }):Play()
			end
		end
	end)
end

-- A fallen foe the Necromancer raises (decision 0104): seen again, glowing, standing.
local function rise(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d.Enabled = true
		elseif d:IsA("BasePart") and d:GetAttribute("Shown") ~= nil then
			d.Transparency = d:GetAttribute("Shown") :: number
		end
	end
	Creatures.play(model, "idle")
end

-- An arrow (archer) or a spell bolt (mage) that flies from `from` to `to` in `seconds`. Show only:
-- the rules have no range. It lives in the player's show folder, so `clear` removes it too.
local function shoot(folder: Folder, kind: string, from: Vector3, to: Vector3, seconds: number)
	local arrow = string.find(kind, "^foe_archer") ~= nil
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	if arrow then
		p.Size, p.Color = Vector3.new(0.2, 0.2, 3), Color3.fromRGB(230, 200, 150)
	else
		p.Shape, p.Size, p.Color = Enum.PartType.Ball, Vector3.one * 1.4, Color3.fromRGB(170, 90, 255)
	end
	p.CFrame = CFrame.lookAt(from, to)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.5 * p.Size.Y, 0), Vector3.new(0, -0.5 * p.Size.Y, 0)
	a0.Parent, a1.Parent = p, p
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1, trail.Lifetime, trail.Color = a0, a1, 0.2, ColorSequence.new(p.Color)
	trail.Transparency, trail.LightEmission = NumberSequence.new(0.2, 1), 1
	trail.Parent = p
	p.Parent = folder
	local tween = TweenService:Create(
		p,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.lookAt(to, to + (to - from)) }
	)
	tween.Completed:Once(function()
		p:Destroy()
	end)
	tween:Play()
	Debris:AddItem(p, seconds + 1) -- a tween that never completes must not leave it behind
end

-- A pop of words over the fight for `player` (decision 0097): "PERFECT!", a combo, "BLOCKED!".
local function pop(player: Player, words: string, kind: string)
	player:SetAttribute("FxPop", words)
	player:SetAttribute("FxPopKind", kind)
	player:SetAttribute("FxPopAt", Workspace:GetServerTimeNow())
end

-- Show wave `wave` between `team` (side 1) and its enemies (side 2) for `members`, and report the
-- result. `team` is every member's animals, each marked with its player's place in `members` (`owner`;
-- one member's need none). `setup` is a wave run's carried HP and boons (decision 0098). Returns false
-- and a code when it cannot start. The result's `stars` and `missed` are by member.
function WaveShow.run(
	members: { Player },
	wave: number,
	team: { Owned },
	report: ({ [string]: any }) -> (),
	setup: BattleRules.Setup?
): (boolean, string?)
	local player = members[1] -- the host
	local stand = CollectionService:GetTagged("FieldStand")[1] :: BasePart?
	local gatePart = CollectionService:GetTagged("FieldGate")[1] :: BasePart?
	if stand == nil then
		return false, "arena"
	end
	if active ~= nil and not table.find(members, active) then
		return false, "busy"
	end
	for _, m in members do -- each leaves the show they were in (a run's last wave)
		WaveShow.clear(m)
	end
	active = player
	counter += 1
	local token = counter
	runs[player] = token
	local function live(): boolean
		return runs[player] == token
	end
	local folder = folderOf(player)
	local players = BattleRules.players(team)
	local seats: { [Player]: { number } } = {}
	for k, m in members do
		hostOf[m] = player
		seats[m] = {}
		m:SetAttribute("FightWave", wave) -- the HUD's stage reads it (decision 0106)
		m:SetAttribute("FightFrom", math.huge) -- the walk-in: no clicks count until FightFrom (server time)
		m:SetAttribute("FightFolder", folder.Name) -- where the fight's models are, for the HUD and the camera
		for i, a in team do
			if ((a :: any).owner or 1) == k then
				table.insert(seats[m], i)
			end
		end
	end

	local foes = LevelRules.enemies(wave, players)
	local log: { BattleRules.Hit } = {}
	local taps: { BattleRules.Tap } = {}
	local arrivals, engaged, places = {}, {}, {}
	local won, actions, seconds, ends = BattleRules.battle(team, foes, log, taps, setup, arrivals, engaged, places)
	local show: Show = {
		token = token,
		team = team,
		foes = foes,
		taps = taps,
		log = log,
		won = won,
		actions = actions,
		seconds = seconds,
		ends = ends,
		start = math.huge,
		ours = {},
		members = members,
		seats = seats,
		strikeTo = {},
		setup = setup,
		arrivals = arrivals,
		engaged = engaged,
		places = places,
	}
	shows[player] = show
	local lineups = { BattleRules.lineup(team, 1, setup), BattleRules.lineup(foes, 2) }

	-- where everyone stands (decision 0108): each member's team at its seat on the field, its animals in a
	-- line and its Titan behind them; the crowd in files before them, turned to the team each file faces
	local frame = CFrame.new(stand.Position)
	local land = if stand.Parent then stand.Parent:FindFirstChild("Ground") else nil
	local onLand = RaycastParams.new()
	onLand.FilterType = Enum.RaycastFilterType.Include
	onLand.FilterDescendantsInstances = { land or stand }
	local function grounded(cf: CFrame): CFrame -- `cf` with its feet on the land under it
		local hit = Workspace:Raycast(cf.Position + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), onLand)
		local y = (if hit then hit.Position.Y else stand.Position.Y) + GROUND
		return cf.Rotation + Vector3.new(cf.X, y, cf.Z)
	end
	local seatAt: { CFrame } = {}
	for k = 1, players do
		seatAt[k] = Battlefield.seat(frame, players, k)
	end
	local ourHome: { CFrame } = {}
	for k = 1, players do
		local line, titans = {}, {}
		for i, a in team do
			if ((a :: any).owner or 1) == k then
				table.insert(if StationRules.role(a) == "titan" then titans else line, i)
			end
		end
		if #line == 0 then -- a Titan with no team before it holds the line itself
			line, titans = titans, {}
		end
		for j, i in line do
			ourHome[i] = grounded(seatAt[k] * CFrame.new((j - (#line + 1) / 2) * Battlefield.LINE, 0, 0))
		end
		for j, i in titans do
			local x = (j - (#titans + 1) / 2) * Battlefield.LINE
			ourHome[i] = grounded(seatAt[k] * CFrame.new(x, 0, Battlefield.TITAN_BACK))
		end
	end
	-- the foes stand in rows of the front line's length (decision 0101), the first row nearest the teams
	local front = BattleRules.front(players)
	local wide = 0
	for _, e in foes do
		local foe = StationConfig.foe(e.s)
		if not (foe and foe.kind == "dragon") then
			wide = math.max(wide, Creatures.foeSize(e.s).X)
		end
	end
	local file = math.clamp(wide + 4, Battlefield.FILE, Battlefield.FILE + 5)
	local function fileAt(col: number, row: number): CFrame -- file `col` of row `row`, turned to the team before it
		local at = (
			frame * CFrame.new((col - (front + 1) / 2) * file, 0, -Battlefield.CROWD_AT - row * Battlefield.ROW)
		).Position
		local to = seatAt[math.clamp(math.ceil(col * players / front), 1, players)].Position
		return grounded(CFrame.lookAt(at, Vector3.new(to.X, at.Y, to.Z)))
	end
	local frontHome: { CFrame } = {} -- the front line's places (BattleRules' `spot`)
	for spot = 1, front do
		frontHome[spot] = fileAt(spot, 0)
	end
	local theirHome: { CFrame }, rowOf = {}, {}
	for i, e in foes do
		local row, col = (i - 1) // front, (i - 1) % front + 1
		rowOf[i] = row
		theirHome[i] = if row == 0 then frontHome[col] else fileAt(col, row)
		local foe = StationConfig.foe(e.s)
		if foe and foe.kind == "dragon" and gatePart then -- a boss lands on the summoning circle
			local on = gatePart.Position + Vector3.new(0, 1.4, -22)
			theirHome[i] = CFrame.lookAt(on, Vector3.new(frame.X, on.Y, frame.Z))
		end
	end
	local gateZ = if gatePart then gatePart.Position.Z + 6 else frame.Z - 98
	-- where a foe comes on from: the summoning circle's near edge, drawn in towards its middle
	local function atGate(home: CFrame): CFrame
		return home.Rotation + Vector3.new(frame.X + (home.X - frame.X) * 0.35, home.Y, math.min(gateZ, home.Z - 20))
	end

	local slots: { { Slot } } = { {}, {} }
	local function place(side: number, i: number, model: Model?, home: CFrame)
		if model == nil then
			return
		end
		local fighter = lineups[side][i]
		model:PivotTo(home)
		model:SetAttribute("Side", side)
		model:SetAttribute("Slot", i) -- the client's power plates tap by slot (decision 0092)
		model:SetAttribute("MaxHp", fighter.maxHp)
		model:SetAttribute("Hp", fighter.hp)
		slots[side][i] = {
			model = model,
			home = home,
			hp = fighter.hp,
			maxHp = fighter.maxHp,
			version = 0,
			side = side,
			front = side == 2 and (rowOf[i] or 0) == 0,
			shown = side == 1,
			stepped = false,
		}
	end
	for i, a in team do
		local model =
			Creatures.spawn(Creatures.asset(a.s, a.v), CFrame.new(0, 500, 0), folder, nil, a.coat or a.rainbow)
		if model then
			Creatures.describe(model, a.s, a.v, a)
		end
		if model then -- whose it is and which of theirs: the HUD's plates are the player's own (decision 0108)
			local owner = members[(a :: any).owner or 1] or player
			model:SetAttribute("Owner", owner.UserId)
			model:SetAttribute("Seat", table.find(seats[owner], i))
		end
		place(1, i, model, ourHome[i])
	end
	for i, e in foes do
		local model = Creatures.spawnFoe(e.s, CFrame.new(0, 500, 0), folder)
		if model then
			Creatures.describeFoe(model, e.s, e.stats)
			local foe = StationConfig.foe(e.s)
			model:SetAttribute("Boss", foe ~= nil and foe.kind == "dragon") -- the HUD's bar across the top
			model:SetAttribute("FoeName", if foe then foe.name else "?")
			if e.elite then -- an elite glows gold (decision 0101)
				model:SetAttribute("Elite", true)
				local aura = Instance.new("Highlight")
				aura.FillColor, aura.FillTransparency = Color3.fromRGB(255, 200, 60), 0.75
				aura.OutlineColor, aura.OutlineTransparency = Color3.fromRGB(255, 220, 90), 0
				aura.Parent = model
			end
		end
		place(2, i, model, theirHome[i])
	end
	for side = 1, 2 do
		for i = 1, #lineups[side] do
			if slots[side][i] == nil then -- a model that is not uploaded: nothing to show
				WaveShow.clear(player)
				return false, "models"
			end
		end
	end
	if not live() then
		return false, "cancelled"
	end

	-- each player stands behind their own team; the camera is theirs to frame (stations-client/
	-- ArenaCamera) from where their team stands (CamFrom) the way it looks (CamFocus, a point ahead of it)
	for k, m in members do
		local seat = seatAt[math.min(k, players)]
		if m.Character then
			m.Character:PivotTo(seat * CFrame.new(-14, 4, Battlefield.TITAN_BACK + 24))
		end
		local tall = 0 -- a team of small animals is watched from nearer
		for _, i in seats[m] do
			tall = math.max(tall, slots[1][i].model:GetExtentsSize().Y)
		end
		m:SetAttribute("CamScale", math.clamp(tall / 17, 0.55, 1))
		m:SetAttribute("CamFrom", seat.Position)
		m:SetAttribute("CamFocus", (seat * CFrame.new(0, 6, -Battlefield.CROWD_AT - Battlefield.ROW - 4)).Position)
	end
	local reach = 12 -- attackers step this far forward
	local walkFor = 2
	for i, slot in slots[2] do
		local root = slot.model.PrimaryPart :: BasePart
		local from = atGate(slot.home)
		if (show.arrivals[i] or 0) > 0 then -- a later rush: it waits out of sight until it is called
			root.CFrame = slot.home - Vector3.new(0, 400, 0)
			continue
		end
		slot.shown = true
		walkFor = math.max(walkFor, (slot.home.Position - from.Position).Magnitude / WALK_SPEED)
		if slot.model:GetAttribute("Boss") then -- a dragon drops out of the sky instead (decision 0097)
			root.CFrame = slot.home + Vector3.new(0, 90, 0)
			Creatures.play(slot.model, "idle")
		else
			root.CFrame = from
			Creatures.play(slot.model, "walk")
		end
	end
	for _, slot in slots[2] do
		if not slot.shown then
			continue
		end
		local root = slot.model.PrimaryPart :: BasePart
		local boss = slot.model:GetAttribute("Boss") == true
		local info = if boss
			then TweenInfo.new(walkFor, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			else TweenInfo.new(walkFor, Enum.EasingStyle.Linear)
		TweenService:Create(root, info, { CFrame = slot.home }):Play()
		if boss then
			slot.model:SetAttribute("LandAt", Workspace:GetServerTimeNow() + walkFor)
		end
	end
	for _, slot in slots[1] do -- one already knocked out in a run's earlier wave lies down
		if slot.hp <= 0 then
			fall(slot.model)
		end
	end
	task.wait(walkFor)
	if not live() then
		return true, nil
	end
	for _, slot in slots[2] do
		if slot.shown then
			Creatures.play(slot.model, "idle")
		end
	end
	-- a later rush runs in from the gate when it is called; a foe that joins the front line steps up into
	-- a fallen foe's place (decision 0101)
	local function rushIn(slot: Slot)
		slot.shown = true
		local root = slot.model.PrimaryPart :: BasePart
		local boss = slot.model:GetAttribute("Boss") == true
		if boss then
			root.CFrame = slot.home + Vector3.new(0, 90, 0)
			Creatures.play(slot.model, "idle")
			slot.model:SetAttribute("LandAt", Workspace:GetServerTimeNow() + BattleRules.RUSH_WALK)
		else
			root.CFrame = atGate(slot.home)
			Creatures.play(slot.model, "walk")
		end
		local info = TweenInfo.new(
			BattleRules.RUSH_WALK,
			if boss then Enum.EasingStyle.Quad else Enum.EasingStyle.Linear,
			Enum.EasingDirection.In
		)
		local walk = TweenService:Create(root, info, { CFrame = slot.home })
		walk.Completed:Once(function()
			if live() and slot.hp > 0 then
				Creatures.play(slot.model, "idle")
			end
		end)
		walk:Play()
	end
	local function stepUp(i: number, slot: Slot)
		slot.stepped = true
		local spot = frontHome[show.places[i]]
		if spot == nil or spot == slot.home then
			return
		end
		slot.home, slot.front = spot, true
		local root = slot.model.PrimaryPart :: BasePart
		TweenService:Create(root, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { CFrame = spot }):Play()
	end

	-- replay the log: each attack starts its animation `lead` seconds before it lands. A tap
	-- (WaveShow.power) can swap in a new log at any time; it is the same up to TAP_AHEAD from now.
	local start = os.clock() + 0.4
	show.start = start
	for _, m in show.members do
		m:SetAttribute("FightFrom", Workspace:GetServerTimeNow() + 0.4)
	end
	for i, slot in slots[1] do
		slot.model:SetAttribute("Power", 0)
		show.ours[i] = slot.model
	end
	local function play(e: BattleRules.Hit)
		task.spawn(function()
			local actor, target = slots[e.side][e.slot], slots[e.tside][e.tslot]
			local kind = actor.model:GetAttribute("Asset") :: string
			local from, to =
				actor.model:FindFirstChild("Hit") :: BasePart?, target.model:FindFirstChild("Hit") :: BasePart?
			local flight = if not e.power
					and ranged(kind)
					and from
					and to
				then FightFx.flightTime((to.Position - from.Position).Magnitude)
				else nil
			local lead = FightFx.lead(e.power, flight)
			task.wait(math.max(0, start + e.t - lead - os.clock()))
			if not live() or actor.hp <= 0 then
				return
			end
			if flight and to and FightFx.BOLTS[kind] then -- the client casts its bolt from its hand to here
				actor.model:SetAttribute("BoltTo", to.Position)
				actor.model:SetAttribute("BoltFor", flight)
			end
			if e.power and to then -- where its spell lands: the ground under its target, and how tall that is
				actor.model:SetAttribute("AimAt", to.Position - Vector3.new(0, to.Size.Y / 2, 0))
				actor.model:SetAttribute("AimHeight", to.Size.Y)
			end
			if not e.click then -- a click's strike is quick: no clip, no lunge (decision 0106)
				Creatures.play(actor.model, if e.power then "magic" else "attack")
			end
			local root = actor.model.PrimaryPart :: BasePart
			local lunges = not e.power and not e.click and not ranged(kind)
			if e.power then -- who it reaches, for its power move's effects (FoePowers): slots on the other side, its own
				local aim, allies = { e.tslot }, {}
				for _, x in e.also or {} do
					table.insert(aim, x.slot)
				end
				for _, x in e.revives or e.heals or {} do
					table.insert(allies, x.slot)
				end
				actor.model:SetAttribute("PowerAim", table.concat(aim, ","))
				actor.model:SetAttribute("PowerAllies", table.concat(allies, ","))
			end
			if lunges then -- a step the way it looks
				TweenService:Create(root, TweenInfo.new(lead * 0.9, Enum.EasingStyle.Quad), {
					CFrame = actor.home * CFrame.new(0, 0, -reach),
				}):Play()
			end
			if flight and from and to then -- let go at the clip's release; it lands at e.t whatever the clock did
				task.wait(math.max(0, start + e.t - flight - os.clock()))
				if not live() then
					return
				end
				if not FightFx.BOLTS[kind] then
					shoot(folder, kind, from.Position, to.Position, math.max(0.05, start + e.t - os.clock()))
				end
			end
			task.wait(math.max(0, start + e.t - os.clock()))
			if not live() then
				return
			end
			-- what the client needs to dress the hit: set before Hp and HitAt, they arrive in any order
			local now = Workspace:GetServerTimeNow()
			local last = show.log[#show.log]
			local final = e.hp <= 0 and e.t == last.t and e.side == last.side and e.slot == last.slot -- the blow that ends the fight
			if e.side == 1 then
				local spent = false -- its power tap is laid but not landed yet: its meter stays empty, no second card
				for _, tap in show.taps do
					spent = spent or (tap.slot == e.slot and tap.t > e.t)
				end
				actor.model:SetAttribute("Power", if spent then 0 else e.energy)
			end
			local ko = e.hp <= 0
			if not ranged(kind) and not e.click then -- a melee attacker freezes with its target; a shooter has nothing to hit
				actor.model:SetAttribute("StopFor", FightFx.hitStop(if e.power then 1 else 0, final, ko))
				actor.model:SetAttribute("StopAt", now)
			end
			local crit = e.perfect == true or (e.combo or 1) > 1
			target.model:SetAttribute("HitPower", if e.power then 1 else 0)
			target.model:SetAttribute("HitDmg", e.dmg)
			target.model:SetAttribute("HitFinal", if final then 1 else 0)
			target.model:SetAttribute("HitCrit", if crit then 1 else 0)
			target.model:SetAttribute("HitKo", if ko then 1 else 0)
			target.model:SetAttribute("HitClick", if e.click then 1 else 0) -- the client draws a click's hit lighter
			target.model:SetAttribute("HitAt", now)
			if e.side == 1 and crit then
				local words = {}
				if e.perfect then
					table.insert(words, "PERFECT!")
				end
				if (e.combo or 1) > 1 then
					table.insert(words, `COMBO x{e.combo}`)
				end
				local whose = members[(show.team[e.slot] :: any).owner or 1]
				if whose and hostOf[whose] == player then
					pop(whose, table.concat(words, "  "), if (e.combo or 1) >= 3 then "big" else "perfect")
				end
			elseif e.shielded then
				for _, m in present(show) do
					pop(m, "BLOCKED!", "shield")
				end
			elseif e.fail and e.side == 1 then
				local whose = members[(show.team[e.slot] :: any).owner or 1]
				if whose and hostOf[whose] == player then
					pop(whose, "MISSED!", "shield")
				end
			end
			target.hp, target.version = e.hp, target.version + 1
			target.model:SetAttribute("Hp", math.max(0, e.hp))
			local function down(who: Slot)
				fall(who.model)
			end
			if e.hp <= 0 then
				down(target)
			elseif not busy(target.model) then
				Creatures.play(target.model, "hit")
			end
			for _, x in e.also or {} do -- splash and a crowd power attack (decision 0101)
				local other = slots[e.tside][x.slot]
				if other and other.hp > 0 then
					other.model:SetAttribute("HitPower", if e.power then 1 else 0)
					other.model:SetAttribute("HitDmg", x.dmg)
					other.model:SetAttribute("HitFinal", 0)
					other.model:SetAttribute("HitCrit", 0)
					other.model:SetAttribute("HitKo", if x.hp <= 0 then 1 else 0)
					other.model:SetAttribute("HitClick", if e.click then 1 else 0)
					other.model:SetAttribute("HitAt", now)
					other.hp, other.version = x.hp, other.version + 1
					other.model:SetAttribute("Hp", math.max(0, x.hp))
					if x.hp <= 0 then
						down(other)
					elseif not busy(other.model) then
						Creatures.play(other.model, "hit")
					end
				end
			end
			if e.power and e.side == 1 and StationRules.role(show.team[e.slot]) == "defense" then
				local struck = { e.tslot }
				for _, x in e.also or {} do
					table.insert(struck, x.slot)
				end
				for _, k in struck do -- knocked back a step, then they come again
					local other = slots[e.tside][k]
					if other and other.hp > 0 then
						local r = other.model.PrimaryPart :: BasePart
						local back = other.home * CFrame.new(0, 0, 6)
						local push =
							TweenService:Create(r, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { CFrame = back })
						push.Completed:Once(function()
							if live() and other.hp > 0 then
								TweenService:Create(r, TweenInfo.new(0.7), { CFrame = other.home }):Play()
							end
						end)
						push:Play()
					end
				end
			end
			for _, x in e.revives or {} do -- the fallen allies raised by the Necromancer's power attack
				local back = slots[e.side][x.slot]
				if back then
					back.hp, back.version = x.hp, back.version + 1
					back.model:SetAttribute("Hp", x.hp)
					rise(back.model)
				end
			end
			for _, x in e.heals or {} do -- a team heal
				local healed = slots[e.side][x.slot]
				if healed and healed.hp > 0 then
					healed.hp, healed.version = x.hp, healed.version + 1
					healed.model:SetAttribute("Hp", x.hp)
				end
			end
			if lunges and actor.hp > 0 then
				TweenService:Create(root, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { CFrame = actor.home }):Play()
			end
			if e.heal then -- shown a beat later, unless something has already moved that HP on
				local healed = slots[e.side][e.heal.slot]
				local seen = healed.version
				task.wait(0.15)
				if live() and healed.version == seen and healed.hp > 0 then
					healed.hp, healed.version = e.heal.hp, healed.version + 1
					healed.model:SetAttribute("Hp", e.heal.hp)
				end
			end
		end)
	end

	local names = {}
	for _, e in foes do
		table.insert(names, (StationConfig.foe(e.s) :: StationConfig.Foe).name)
	end
	pending[player] = function()
		-- stars (decision 0097), each member's own: nobody of theirs knocked out, every power attack of theirs
		-- fired by a tap; and the MVP: the animal that dealt the most damage
		local down: { [number]: boolean }, missed: { [number]: number }, dealt = {}, {}, {}
		local function ownerOf(slot: number): number
			return (team[slot] :: any).owner or 1
		end
		for _, e in show.log do
			if e.tside == 1 and e.hp <= 0 then
				down[ownerOf(e.tslot)] = true
			end
			if e.side == 1 then
				for _, x in e.also or {} do
					dealt[e.slot] = (dealt[e.slot] or 0) + x.dmg
				end
				dealt[e.slot] = (dealt[e.slot] or 0) + e.dmg
				if e.power and not e.tap then
					missed[ownerOf(e.slot)] = (missed[ownerOf(e.slot)] or 0) + 1
				end
			else
				for _, x in e.also or {} do -- a sweep knocks out more than its target
					if x.hp <= 0 then
						down[ownerOf(x.slot)] = true
					end
				end
			end
		end
		-- how close it was (decision 0123): the share of the Legion's health still standing at the end
		local foeHp: { [number]: number } = {}
		for _, e in show.log do
			if e.tside == 2 then
				foeHp[e.tslot] = e.hp
			end
			if e.side == 1 then
				for _, x in e.also or {} do
					foeHp[x.slot] = x.hp
				end
			elseif e.heal then -- a foe healer's heal
				foeHp[e.heal.slot] = e.heal.hp
			end
		end
		local hpLeft, hpAll = 0, 0
		for i, f in BattleRules.lineup(foes, 2) do
			hpAll += f.maxHp
			hpLeft += math.clamp(foeHp[i] or f.maxHp, 0, f.maxHp)
		end
		local mvp = 0
		for slot, d in dealt do
			if mvp == 0 or d > dealt[mvp] then
				mvp = slot
			end
		end
		local best = team[mvp]
		local va = if best and best.v then StationConfig.variant(best.s, best.v) else nil
		local sp = if best then StationConfig.species(best.s) else nil
		local stars = {}
		for k in members do
			missed[k] = missed[k] or 0
			stars[k] = LevelRules.stars(show.won, down[k] == true, missed[k])
		end
		report({
			wave = wave,
			won = show.won,
			seconds = show.seconds,
			attacks = show.actions,
			foes = table.concat(names, ", "),
			stars = stars,
			missed = missed,
			ends = show.ends,
			mvp = if va then va.name elseif sp then sp.name else nil,
			mvpDmg = dealt[mvp] or 0,
			foeLeft = if hpAll > 0 then hpLeft / hpAll else 0, -- 0 to 1: display only
		})
	end
	task.spawn(function()
		local nextHit, cheered = 1, false
		local told: { [string]: boolean } = {}
		while live() do
			local now = os.clock()
			while show.log[nextHit] and start + show.log[nextHit].t - TAP_AHEAD <= now do
				play(show.log[nextHit])
				nextHit += 1
			end
			-- a rush is called: it runs in; a foe joins the front line: it steps up (decision 0101)
			for i, slot in slots[2] do
				local at = show.arrivals[i]
				if not slot.shown and at and at < math.huge and start + at - BattleRules.RUSH_WALK <= now then
					rushIn(slot)
				end
				local joined = show.engaged[i]
				if not slot.stepped and joined and joined > 0 and start + joined <= now and slot.hp > 0 then
					stepUp(i, slot)
				end
			end
			-- an enemy power attack is coming: warn under the attacker (decision 0097)
			for _, e in show.log do
				local key = `{e.slot}:{e.t}`
				local at = start + e.t
				if e.side == 2 and e.power and not told[key] and at - FightFx.TELL <= now and at > now then
					told[key] = true
					local foe = slots[2][e.slot]
					if foe.hp > 0 then
						foe.model:SetAttribute("TellAt", Workspace:GetServerTimeNow() + (at - now))
					end
				end
			end
			-- the survivors of the winning side celebrate a beat after the last hit, until the show is cleared
			if not cheered and now >= start + show.seconds + 1.0 then
				cheered = true
				for _, slot in slots[if show.won then 1 else 2] do
					if slot.hp > 0 then
						Creatures.play(slot.model, "win")
					end
				end
			end
			if now >= start + show.seconds + 1.6 then
				for _, slot in slots[1] do -- the fight is over: nothing left to fire
					slot.model:SetAttribute("Power", 0)
				end
				break
			end
			task.wait()
		end
		if not live() then
			return
		end
		local owed = pending[player]
		if owed then
			pending[player] = nil
			owed()
		end
		task.wait(60) -- the result stays up until the player leaves; an idle show frees the arena
		if live() then
			WaveShow.clear(player)
		end
	end)
	return true, nil
end

-- The player taps their animal in team slot `slot` to fire its power attack (decision 0092). The
-- fight is replayed from the start with the tap TAP_AHEAD seconds from now; refused when its meter
-- is not full then, the fight is over, or the tap would lose a fight the team was winning. `presses` is
-- a mash's count (decision 0106): no more are believed than BattleRules.MASH_RATE a second since the
-- meter filled in the show, on the server's clock.
function WaveShow.power(player: Player, seat: number, presses: number?): (boolean, string?)
	local host = hostOf[player]
	local show = if host then shows[host] else nil
	if host == nil or show == nil or runs[host] ~= show.token then
		return false, "no_fight"
	end
	local slot = show.seats[player][seat] -- the player's own animal in that seat
	if slot == nil then
		return false, "power"
	end
	local seen = os.clock() - show.start
	local t = seen + TAP_AHEAD
	if t < 0 or t >= show.seconds then
		return false, "power"
	end
	local count: number? = nil
	if presses == BattleRules.FAILED then -- messed up (the client's word: it only costs the player)
		count = BattleRules.FAILED
	elseif presses and presses > 0 then
		local filled: number? = nil -- when the meter last filled, as far as the show has played
		for _, e in show.log do
			if e.t > seen then
				break
			elseif e.side == 1 and e.slot == slot then
				if e.power then
					filled = nil
				elseif e.energy >= 1 and filled == nil then
					filled = e.t
				end
			end
		end
		-- believed only as far as the server's own clock allows since the meter filled: MASH_RATE presses a
		-- second for a mash, ten tenths a second for a ring's hold (decision 0109)
		local rate = if BattleRules.pressOf(show.team[slot] :: any) == "ring" then 10 else BattleRules.MASH_RATE
		count = if filled then math.min(presses, math.floor(rate * (seen - filled)) + 1) else 0
	end
	local taps = table.clone(show.taps)
	table.insert(taps, { slot = slot, t = t, presses = count })
	local log: { BattleRules.Hit } = {}
	local arrivals, engaged, places = {}, {}, {}
	local won, actions, seconds, ends =
		BattleRules.battle(show.team, show.foes, log, taps, show.setup, arrivals, engaged, places)
	local fired = false
	for _, e in log do
		fired = fired or (e.tap == true and e.side == 1 and e.slot == slot and e.t == t)
	end
	if not fired or (show.won and not won) then
		return false, "power"
	end
	show.taps, show.log, show.won, show.actions, show.seconds, show.ends = taps, log, won, actions, seconds, ends
	show.arrivals, show.engaged, show.places = arrivals, engaged, places
	if show.ours[slot] then -- the meter empties at once; the strike lands TAP_AHEAD from now
		show.ours[slot]:SetAttribute("Power", 0)
	end
	return true, nil
end

-- The player clicks (decision 0106): `n` clicks since the client last sent (it sends at most every
-- STRIKE_SEND seconds). Each is a strike (a tap on BattleRules.STRIKE) laid from TAP_AHEAD ahead of the
-- show, after the last one laid and no further ahead than STRIKE_SEND, spread over that time (BattleRules
-- ignores any closer than STRIKE_GAP). Refused when clicks do not strike in this fight, the fight is over,
-- no strike lands (nobody in the front line yet) or they would lose a fight the team was winning.
local STRIKE_SEND = 0.25
function WaveShow.strike(player: Player, n: number): (boolean, string?)
	local host = hostOf[player]
	local show = if host then shows[host] else nil
	if host == nil or show == nil or runs[host] ~= show.token then
		return false, "no_fight"
	end
	local who = table.find(show.members, player) :: number -- the clicks are this player's (decision 0108)
	local t = os.clock() - show.start + TAP_AHEAD
	if t < 0 or t >= show.seconds or not (show.setup and show.setup.clicks) then
		return false, "strike"
	end
	local from = math.max(t, (show.strikeTo[who] or -math.huge) + BattleRules.STRIKE_GAP)
	local room = math.floor((t + STRIKE_SEND - from) / BattleRules.STRIKE_GAP) + 1
	local count = math.min(n, room)
	if count < 1 then
		return false, "strike"
	end
	local gap = math.max(BattleRules.STRIKE_GAP, STRIKE_SEND / count)
	local taps = table.clone(show.taps)
	for k = 0, count - 1 do
		table.insert(taps, { slot = BattleRules.STRIKE, t = from + k * gap, owner = who })
	end
	local log: { BattleRules.Hit } = {}
	local arrivals, engaged, places = {}, {}, {}
	local won, actions, seconds, ends =
		BattleRules.battle(show.team, show.foes, log, taps, show.setup, arrivals, engaged, places)
	local landed = false
	for _, e in log do
		landed = landed or (e.click == true and e.t >= from)
	end
	if not landed or (show.won and not won) then
		return false, "strike"
	end
	show.taps, show.log, show.won, show.actions, show.seconds, show.ends = taps, log, won, actions, seconds, ends
	show.arrivals, show.engaged, show.places = arrivals, engaged, places
	show.strikeTo[who] = from + (count - 1) * gap
	return true, nil
end

-- The player raises the team's shield (decision 0097): a tap on slot 0, replayed like a power tap.
-- Refused while the last shield is cooling down (BattleRules.shields) or when the fight is over.
function WaveShow.shield(player: Player): (boolean, string?)
	local host = hostOf[player]
	local show = if host then shows[host] else nil
	if host == nil or show == nil or runs[host] ~= show.token then
		return false, "no_fight"
	end
	local t = os.clock() - show.start + TAP_AHEAD
	if t < 0 or t >= show.seconds then
		return false, "shield"
	end
	local taps = table.clone(show.taps)
	table.insert(taps, { slot = 0, t = t })
	if not table.find(BattleRules.shields(taps), t) then
		return false, "shield_wait"
	end
	local log: { BattleRules.Hit } = {}
	local arrivals, engaged, places = {}, {}, {}
	local won, actions, seconds, ends =
		BattleRules.battle(show.team, show.foes, log, taps, show.setup, arrivals, engaged, places)
	if show.won and not won then
		return false, "shield"
	end
	show.taps, show.log, show.won, show.actions, show.seconds, show.ends = taps, log, won, actions, seconds, ends
	show.arrivals, show.engaged, show.places = arrivals, engaged, places
	local now = Workspace:GetServerTimeNow()
	for _, m in present(show) do -- one shield for everyone in the fight
		m:SetAttribute("ShieldAt", now + TAP_AHEAD) -- when it rises in the show
		m:SetAttribute("ShieldReady", now + BattleRules.SHIELD_COOLDOWN)
	end
	return true, nil
end

return WaveShow
