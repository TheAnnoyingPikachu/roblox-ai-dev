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
}

local WaveShow = {}

local GROUND = 0.45 -- the arena floor's top is at 0.4
local WALK_SPEED = 13 -- studs a second the enemies walk out of the gate at
local RANGED = { foe_archer = true, foe_mage = true } -- these stand and shoot instead of lunging

local counter = 0
local runs: { [Player]: number } = {} -- the token of each player's current show
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
	player:SetAttribute("CamFocus", nil)
	player:SetAttribute("CamRadius", nil)
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

-- The fallen stop glowing and sink out of sight a moment later.
local function fall(model: Model)
	Creatures.play(model, "die")
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d.Enabled = false
		end
	end
	task.delay(2.2, function()
		if model.Parent == nil then
			return
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				TweenService:Create(d, TweenInfo.new(1.2), { Transparency = 1 }):Play()
			end
		end
	end)
end

-- An arrow (archer) or a spell bolt (mage) that flies from `from` to `to` in `seconds`. Show only:
-- the rules have no range. It lives in the player's show folder, so `clear` removes it too.
local function shoot(folder: Folder, kind: string, from: Vector3, to: Vector3, seconds: number)
	local arrow = kind == "foe_archer"
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
local function across(sizes: { Vector3 }): ({ number }, number)
	local total = 0
	for _, s in sizes do
		total += s.X + 6
	end
	local out, x, deepest = {}, -total / 2, 0
	for _, s in sizes do
		table.insert(out, x + (s.X + 6) / 2)
		x += s.X + 6
		deepest = math.max(deepest, s.Z)
	end
	return out, deepest
end

-- Show wave `wave` between `team` (side 1) and its enemies (side 2) for `player`, and report the
-- result. Returns false and a code when it cannot start.
function WaveShow.run(
	player: Player,
	wave: number,
	team: { Owned },
	report: ({ [string]: any }) -> ()
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
	local won, actions, seconds = BattleRules.battle(team, foes, log)
	local lineups = { BattleRules.lineup(team, 1), BattleRules.lineup(foes, 2) }
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
	local theirX, theirDeep = across(theirSizes)
	local gap = ourDeep / 2 + theirDeep / 2 + 14
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
		model:SetAttribute("MaxHp", fighter.maxHp)
		model:SetAttribute("Hp", fighter.maxHp)
		slots[side][i] =
			{ model = model, home = home, hp = fighter.maxHp, maxHp = fighter.maxHp, version = 0, side = side }
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
		end
		place(2, i, model, theirX[i], z0 - gap, 1)
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
	for _, slot in slots[2] do
		local root = slot.model.PrimaryPart :: BasePart
		local from = math.min(gateZ, slot.home.Z - 20)
		walkFor = math.max(walkFor, (slot.home.Z - from) / WALK_SPEED)
		root.CFrame = slot.home + Vector3.new(0, 0, from - slot.home.Z)
		Creatures.play(slot.model, "walk")
	end
	for _, slot in slots[2] do
		local root = slot.model.PrimaryPart :: BasePart
		TweenService:Create(root, TweenInfo.new(walkFor, Enum.EasingStyle.Linear), { CFrame = slot.home }):Play()
	end
	task.wait(walkFor)
	if not live() then
		return true, nil
	end
	for _, slot in slots[2] do
		Creatures.play(slot.model, "idle")
	end

	-- replay the log: each attack starts its animation `lead` seconds before it lands
	local start = os.clock() + 0.4
	for _, e in log do
		task.spawn(function()
			local actor, target = slots[e.side][e.slot], slots[e.tside][e.tslot]
			local kind = actor.model:GetAttribute("Asset") :: string
			local from, to =
				actor.model:FindFirstChild("Hit") :: BasePart?, target.model:FindFirstChild("Hit") :: BasePart?
			local flight = if not e.power
					and RANGED[kind]
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
			local lunges = not e.power and not RANGED[kind]
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
			local final = e == log[#log] and e.hp <= 0 -- the blow that ends the fight
			if not RANGED[kind] then -- a melee attacker freezes with its target; a shooter has nothing to hit
				actor.model:SetAttribute("StopFor", FightFx.hitStop(if e.power then 1 else 0, final))
				actor.model:SetAttribute("StopAt", now)
			end
			target.model:SetAttribute("HitPower", if e.power then 1 else 0)
			target.model:SetAttribute("HitDmg", e.dmg)
			target.model:SetAttribute("HitFinal", if final then 1 else 0)
			target.model:SetAttribute("HitAt", now)
			target.hp, target.version = e.hp, target.version + 1
			target.model:SetAttribute("Hp", math.max(0, e.hp))
			if e.hp <= 0 then
				fall(target.model)
			elseif not busy(target.model) then
				Creatures.play(target.model, "hit")
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

	-- the survivors of the winning side celebrate a beat after the last hit, until the show is cleared
	task.delay(0.4 + seconds + 1.0, function()
		if not live() then
			return
		end
		for _, slot in slots[if won then 1 else 2] do
			if slot.hp > 0 then
				Creatures.play(slot.model, "win")
			end
		end
	end)

	local names = {}
	for _, e in foes do
		table.insert(names, (StationConfig.foe(e.s) :: StationConfig.Foe).name)
	end
	pending[player] = function()
		report({ wave = wave, won = won, seconds = seconds, attacks = actions, foes = table.concat(names, ", ") })
	end
	task.delay(seconds + 0.4 + 1.6, function()
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

return WaveShow
