--!strict
-- The admin's test wave (decision 0042): plays one wave fight in the arena canyon so it can be
-- watched. The team and the wave fight through BattleRules exactly as the rules decide (with its
-- log), and this module only replays that log: the enemies walk in, each attack plays its
-- animation and its hit lands when the log says, health bars drop, the fallen fall. Nothing here
-- decides who wins and nothing is saved: coins, XP and progress are not touched.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BattleRules = require(Shared:WaitForChild("BattleRules"))
local LevelRules = require(Shared:WaitForChild("LevelRules"))
local FightFx = require(Shared:WaitForChild("FightFx"))
local StationAssets = require(Shared:WaitForChild("StationAssets"))
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationRules = require(Shared:WaitForChild("StationRules"))
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

local GROUND = 0.45 -- the arena floor's top is at 0.4
local WALK_SPEED = 13 -- studs a second the enemies walk out of the gate at
-- archers and mages (any of their models, decision 0104) stand and shoot instead of lunging
local function ranged(asset: string): boolean
	return string.find(asset, "^foe_archer") ~= nil or string.find(asset, "^foe_mage") ~= nil
end

local counter = 0
local runs: { [Player]: number } = {} -- the token of each player's current show
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
	setup: BattleRules.Setup?,
	arrivals: { [number]: number }, -- when each foe is in the fight (BattleRules.battle, decision 0101)
	engaged: { [number]: number }, -- when each foe joined the front line
}
local shows: { [Player]: Show } = {}
local TAP_AHEAD = FightFx.TAP_AHEAD -- seconds ahead of the show a tap lands
local pending: { [Player]: () -> () } = {} -- the result report, owed once per show
local active: Player? = nil -- whose show is in the arena (it holds one at a time)

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

-- Stop the player's show and remove what it made. A result not yet reported is reported now.
function WaveShow.clear(player: Player)
	runs[player] = nil
	shows[player] = nil
	player:SetAttribute("CamFocus", nil)
	player:SetAttribute("CamRadius", nil)
	player:SetAttribute("ShieldAt", nil)
	player:SetAttribute("ShieldReady", nil)
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

-- A line of `sizes` (studs, x by z) across the arena, centred on x = 0: where each one's middle goes.
local ROW_MAX = 96 -- the pit is 104 studs wide between its walls: a wider row closes up, its creatures overlapping
local function across(sizes: { Vector3 }): ({ number }, number)
	local total = 0
	for _, s in sizes do
		total += s.X + 6
	end
	local squeeze = math.min(1, ROW_MAX / total)
	local out, x, deepest = {}, -total / 2, 0
	for _, s in sizes do
		table.insert(out, (x + (s.X + 6) / 2) * squeeze)
		x += s.X + 6
		deepest = math.max(deepest, s.Z)
	end
	return out, deepest
end

-- A pop of words over the fight for `player` (decision 0097): "PERFECT!", a combo, "BLOCKED!".
local function pop(player: Player, words: string, kind: string)
	player:SetAttribute("FxPop", words)
	player:SetAttribute("FxPopKind", kind)
	player:SetAttribute("FxPopAt", Workspace:GetServerTimeNow())
end

-- Show wave `wave` between `team` (side 1) and its enemies (side 2) for `player`, and report the
-- result. `setup` is a wave run's carried HP and boons (decision 0098). Returns false and a code when
-- it cannot start.
function WaveShow.run(
	player: Player,
	wave: number,
	team: { Owned },
	report: ({ [string]: any }) -> (),
	setup: BattleRules.Setup?
): (boolean, string?)
	local stand = CollectionService:GetTagged("WaveStand")[1] :: BasePart?
	local gatePart = CollectionService:GetTagged("ArenaGate")[1] :: BasePart?
	if stand == nil then
		return false, "arena"
	end
	if active ~= nil and active ~= player then
		return false, "busy"
	end
	WaveShow.clear(player)
	active = player
	counter += 1
	local token = counter
	runs[player] = token
	local function live(): boolean
		return runs[player] == token
	end

	local foes = LevelRules.enemies(wave)
	local log: { BattleRules.Hit } = {}
	local taps: { BattleRules.Tap } = {}
	local arrivals, engaged = {}, {}
	local won, actions, seconds, ends = BattleRules.battle(team, foes, log, taps, setup, arrivals, engaged)
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
		setup = setup,
		arrivals = arrivals,
		engaged = engaged,
	}
	shows[player] = show
	local lineups = { BattleRules.lineup(team, 1, setup), BattleRules.lineup(foes, 2) }
	local folder = folderOf(player)

	-- where everyone stands: our team across the middle of the canyon, the enemies a gap away
	local ourSizes, theirSizes = {}, {}
	for _, a in team do
		local size = StationAssets[Creatures.asset(a.s, a.v)].size
		table.insert(ourSizes, Vector3.new(size[1], size[2], size[3]))
	end
	for _, e in foes do
		table.insert(theirSizes, Creatures.foeSize(e.s))
	end
	local ourX, ourDeep = across(ourSizes)
	-- the foes stand in rows of the front line's size (decision 0101), the first row nearest the team
	local theirX, rowOf, theirDeep = {}, {}, 0
	for first = 1, #theirSizes, BattleRules.FRONT do
		local row = {}
		for i = first, math.min(#theirSizes, first + BattleRules.FRONT - 1) do
			table.insert(row, theirSizes[i])
		end
		local xs, deep = across(row)
		for k, x in xs do
			theirX[first + k - 1] = x
			rowOf[first + k - 1] = (first - 1) // BattleRules.FRONT
		end
		theirDeep = math.max(theirDeep, deep)
	end
	local gap = ourDeep / 2 + theirDeep / 2 + 14
	local rowStep = theirDeep + 5
	local z0 = stand.Position.Z

	local slots: { { Slot } } = { {}, {} }
	local function place(side: number, i: number, model: Model?, x: number, z: number, face: number)
		if model == nil then
			return
		end
		local fighter = lineups[side][i]
		local home = CFrame.lookAt(Vector3.new(x, GROUND, z), Vector3.new(x, GROUND, z + face))
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
		local model = Creatures.spawn(Creatures.asset(a.s, a.v), CFrame.new(0, 500, 0), folder, nil, a.rainbow)
		if model then
			Creatures.describe(model, a.s, a.v, a)
		end
		place(1, i, model, ourX[i], z0, -1)
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
		place(2, i, model, theirX[i], z0 - gap - (rowOf[i] or 0) * rowStep, 1)
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

	-- the player watches from beside the dais; the camera is theirs to frame (stations-client/
	-- ArenaCamera) from the focus and radius set here; the enemies walk out of the gate
	if player.Character then
		local spot = Vector3.new(stand.Position.X - 40, 4, z0 + 16)
		player.Character:PivotTo(CFrame.lookAt(spot, Vector3.new(0, 4, z0 - gap / 2)))
	end
	local lo, hi, tall = Vector3.new(math.huge, 0, math.huge), Vector3.new(-math.huge, 0, -math.huge), 0
	for side = 1, 2 do
		for i, slot in slots[side] do
			local size = (if side == 1 then ourSizes else theirSizes)[i]
			local at = slot.home.Position
			lo = Vector3.new(math.min(lo.X, at.X - size.X / 2), 0, math.min(lo.Z, at.Z - size.Z / 2))
			hi = Vector3.new(math.max(hi.X, at.X + size.X / 2), 0, math.max(hi.Z, at.Z + size.Z / 2))
			tall = math.max(tall, size.Y)
		end
	end
	local reach = math.clamp(gap * 0.3, 6, 20) -- attackers step this far forward
	local span = hi - lo + Vector3.new(0, tall, reach)
	player:SetAttribute("CamFocus", (lo + hi) / 2 + Vector3.new(0, tall * 0.4, 0))
	player:SetAttribute("CamRadius", math.max(16, span.Magnitude / 2))
	local gateZ = if gatePart then gatePart.Position.Z + 6 else z0 - gap - 50
	local walkFor = 2
	for i, slot in slots[2] do
		local root = slot.model.PrimaryPart :: BasePart
		local from = math.min(gateZ, slot.home.Z - 20)
		if (show.arrivals[i] or 0) > 0 then -- a later rush: it waits behind the gate until it is called
			root.CFrame = slot.home + Vector3.new(0, 0, gateZ - 30 - slot.home.Z)
			continue
		end
		slot.shown = true
		walkFor = math.max(walkFor, (slot.home.Z - from) / WALK_SPEED)
		if slot.model:GetAttribute("Boss") then -- a dragon drops out of the sky instead (decision 0097)
			root.CFrame = slot.home + Vector3.new(0, 90, 0)
			Creatures.play(slot.model, "idle")
		else
			root.CFrame = slot.home + Vector3.new(0, 0, from - slot.home.Z)
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
	local freeSpots: { CFrame } = {}
	local function rushIn(slot: Slot)
		slot.shown = true
		local root = slot.model.PrimaryPart :: BasePart
		local boss = slot.model:GetAttribute("Boss") == true
		if boss then
			root.CFrame = slot.home + Vector3.new(0, 90, 0)
			Creatures.play(slot.model, "idle")
			slot.model:SetAttribute("LandAt", Workspace:GetServerTimeNow() + BattleRules.RUSH_WALK)
		else
			root.CFrame = slot.home + Vector3.new(0, 0, gateZ - slot.home.Z)
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
	local function stepUp(slot: Slot)
		slot.stepped = true
		local spot = table.remove(freeSpots, 1)
		if spot == nil or slot.front then
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
			Creatures.play(actor.model, if e.power then "magic" else "attack")
			local root = actor.model.PrimaryPart :: BasePart
			local lunges = not e.power and not ranged(kind)
			if lunges then
				local dir = if e.side == 1 then -1 else 1
				TweenService:Create(root, TweenInfo.new(lead * 0.9, Enum.EasingStyle.Quad), {
					CFrame = actor.home + Vector3.new(0, 0, dir * reach),
				}):Play()
			end
			if flight and from and to then -- let go at the clip's release; it lands at e.t whatever the clock did
				task.wait(math.max(0, start + e.t - flight - os.clock()))
				if not live() then
					return
				end
				shoot(folder, kind, from.Position, to.Position, math.max(0.05, start + e.t - os.clock()))
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
				actor.model:SetAttribute("Power", e.energy)
			end
			local ko = e.hp <= 0
			if not ranged(kind) then -- a melee attacker freezes with its target; a shooter has nothing to hit
				actor.model:SetAttribute("StopFor", FightFx.hitStop(if e.power then 1 else 0, final, ko))
				actor.model:SetAttribute("StopAt", now)
			end
			local crit = e.perfect == true or (e.combo or 1) > 1
			target.model:SetAttribute("HitPower", if e.power then 1 else 0)
			target.model:SetAttribute("HitDmg", e.dmg)
			target.model:SetAttribute("HitFinal", if final then 1 else 0)
			target.model:SetAttribute("HitCrit", if crit then 1 else 0)
			target.model:SetAttribute("HitKo", if ko then 1 else 0)
			target.model:SetAttribute("HitAt", now)
			if e.side == 1 and crit then
				local words = {}
				if e.perfect then
					table.insert(words, "PERFECT!")
				end
				if (e.combo or 1) > 1 then
					table.insert(words, `COMBO x{e.combo}`)
				end
				pop(player, table.concat(words, "  "), if (e.combo or 1) >= 3 then "big" else "perfect")
			elseif e.shielded then
				pop(player, "BLOCKED!", "shield")
			end
			target.hp, target.version = e.hp, target.version + 1
			target.model:SetAttribute("Hp", math.max(0, e.hp))
			local function down(who: Slot)
				fall(who.model)
				if who.side == 2 and who.front then -- its place in the front line is free
					table.insert(freeSpots, who.home)
				end
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
						local back = other.home + Vector3.new(0, 0, -6)
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
			if e.revive then -- a fallen ally raised by the Necromancer's power attack
				local back = slots[e.side][e.revive.slot]
				if back then
					back.hp, back.version = e.revive.hp, back.version + 1
					back.model:SetAttribute("Hp", e.revive.hp)
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
		-- stars (decision 0097) and the MVP: the team's animal that dealt the most damage
		local down, dealt = false, {}
		for _, e in show.log do
			down = down or (e.tside == 1 and e.hp <= 0)
			if e.side == 1 then
				dealt[e.slot] = (dealt[e.slot] or 0) + e.dmg
				for _, x in e.also or {} do
					dealt[e.slot] += x.dmg
				end
			end
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
		report({
			wave = wave,
			won = show.won,
			seconds = show.seconds,
			attacks = show.actions,
			foes = table.concat(names, ", "),
			stars = LevelRules.stars(show.won, down, LevelRules.missed(show.log)),
			missed = LevelRules.missed(show.log),
			ends = show.ends,
			mvp = if va then va.name elseif sp then sp.name else nil,
			mvpDmg = dealt[mvp] or 0,
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
					stepUp(slot)
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
-- is not full then, the fight is over, or the tap would lose a fight the team was winning.
function WaveShow.power(player: Player, slot: number): (boolean, string?)
	local show = shows[player]
	if show == nil or runs[player] ~= show.token then
		return false, "no_fight"
	end
	local t = os.clock() - show.start + TAP_AHEAD
	if t < 0 or t >= show.seconds then
		return false, "power"
	end
	local taps = table.clone(show.taps)
	table.insert(taps, { slot = slot, t = t })
	local log: { BattleRules.Hit } = {}
	local arrivals, engaged = {}, {}
	local won, actions, seconds, ends =
		BattleRules.battle(show.team, show.foes, log, taps, show.setup, arrivals, engaged)
	local fired = false
	for _, e in log do
		fired = fired or (e.tap == true and e.side == 1 and e.slot == slot and e.t == t)
	end
	if not fired or (show.won and not won) then
		return false, "power"
	end
	show.taps, show.log, show.won, show.actions, show.seconds, show.ends = taps, log, won, actions, seconds, ends
	show.arrivals, show.engaged = arrivals, engaged
	if show.ours[slot] then -- the meter empties at once; the strike lands TAP_AHEAD from now
		show.ours[slot]:SetAttribute("Power", 0)
	end
	return true, nil
end

-- The player raises the team's shield (decision 0097): a tap on slot 0, replayed like a power tap.
-- Refused while the last shield is cooling down (BattleRules.shields) or when the fight is over.
function WaveShow.shield(player: Player): (boolean, string?)
	local show = shows[player]
	if show == nil or runs[player] ~= show.token then
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
	local arrivals, engaged = {}, {}
	local won, actions, seconds, ends =
		BattleRules.battle(show.team, show.foes, log, taps, show.setup, arrivals, engaged)
	if show.won and not won then
		return false, "shield"
	end
	show.taps, show.log, show.won, show.actions, show.seconds, show.ends = taps, log, won, actions, seconds, ends
	show.arrivals, show.engaged = arrivals, engaged
	local now = Workspace:GetServerTimeNow()
	player:SetAttribute("ShieldAt", now + TAP_AHEAD) -- when it rises in the show
	player:SetAttribute("ShieldReady", now + BattleRules.SHIELD_COOLDOWN)
	return true, nil
end

return WaveShow
