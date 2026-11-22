--!strict
-- Animal Stations server entry: builds the world, gives each player a home ranch (lowest free of
-- World.RANCHES, owners spawn at its gate), teleports players between their ranch and the hub,
-- loads saves (kit Saves), shows each ranch as its owner has built it and the eggs in its hatchery
-- (Ranch.luau), and routes every request (kit Router): buying eggs, starting one hatching and
-- opening it, ranch upgrades, the team and training. The client only names an action; prices, hatches and timings are decided here.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Areas = require(script.Parent:WaitForChild("Areas"))
local Creatures = require(script.Parent:WaitForChild("Creatures"))
local Ranch = require(script.Parent:WaitForChild("Ranch"))
local World = require(script.Parent:WaitForChild("World"))

World.build()
Creatures.publishPortraits()

-- What stands on each ranch follows its owner's upgrades (a free ranch shows a new one).
local shown: { [number]: string } = {}
local function show(i: number, upgrades: { [string]: number })
	local ids = {}
	for id in upgrades do
		table.insert(ids, id)
	end
	table.sort(ids)
	local key = ""
	for _, id in ids do
		key ..= `{id}{upgrades[id]},`
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
local hatchedAt: { [number]: CFrame } = {} -- animal id -> the nest it has just hatched in
local syncHerd: (i: number, animals: { any }, grounds: number, titan: number?, team: { number }) -> ()
-- `eggs`: the profile's list, each hatching one with `due`, when it can be opened (the Brooder shortens it)
local function showEggs(i: number, eggs: { { egg: string, since: number?, due: number? } })
	local key = ""
	for _, e in eggs do
		key ..= e.egg .. (if e.since then `+{e.due},` else ",")
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
-- The admin menu is SHANNON's only, in every server and in Studio (decision 0084): not the experience's
-- owner, which would be a group if it is ever published under one.
local ADMINS: { [number]: boolean } = { [96807256] = true }
local function isAdmin(player: Player): boolean
	return ADMINS[player.UserId] == true
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

-- Saves, eggs, team and training (decision 0025) ---------------------------------------------------

local RS = game:GetService("ReplicatedStorage")
local Shared, Kit, KitRoblox = RS:WaitForChild("Shared"), RS:WaitForChild("Kit"), RS:WaitForChild("KitRoblox")
local Payload = require(Kit:WaitForChild("Payload"))
local Router = require(Kit:WaitForChild("Router"))
local Remotes = require(KitRoblox:WaitForChild("Remotes"))
local Saves = require(KitRoblox:WaitForChild("Saves"))
local BattleRules = require(Shared:WaitForChild("BattleRules"))
local LevelRules = require(Shared:WaitForChild("LevelRules"))
local Rng = require(Shared:WaitForChild("Rng"))
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationProgress = require(Shared:WaitForChild("StationProgress"))
local StationTrade = require(Shared:WaitForChild("StationTrade"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local StationRewards = require(Shared:WaitForChild("StationRewards"))
local WaveRuns = require(Shared:WaitForChild("WaveRuns"))

local rng = Rng.seed(os.time(), Random.new():NextInteger(1, 2 ^ 30))
local saves

-- A profile's eggs as Ranch.eggs shows them: each hatching one with the time it can be opened.
local function eggsOf(p: StationProgress.Profile): { { egg: string, since: number?, due: number? } }
	local out = {}
	for k, e in p.eggs do
		local egg = StationConfig.egg(e.egg)
		out[k] = {
			egg = e.egg,
			since = e.since,
			due = if e.since and egg then StationProgress.dueAt(p, e) else nil,
		}
	end
	return out
end

-- The Titan that stands in its den: the profile's, once the Titan's Den is built.
local function denTitan(p: StationProgress.Profile): number?
	return if (p.upgrades.den or 0) > 0 then p.titan else nil
end
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

-- The planners and the daily wheel (decision 0094). What a reward gives is worked out on a copy of the
-- save with today counted; the animals inside won eggs (and a jackpot's mythic) are rolled here, then the
-- save is changed with them, so a change that runs twice gives the same.
local function today(player: Player): StationProgress.Profile?
	local p = saves.get(player)
	if p == nil then
		return nil
	end
	return StationRewards.visit(StationProgress.sanitize(p, os.time()), os.time())
end

local function rollEggs(items: StationRewards.Items): { StationRules.Owned }
	local animals = {}
	for _, id in items.eggs do
		local a
		a, rng = StationRules.hatch(id, rng)
		table.insert(animals, a :: StationRules.Owned)
	end
	return animals
end

local function rewardWeek(player: Player): (boolean, string?)
	local p = today(player)
	if p == nil then
		return false, "loading"
	end
	local spec, code = StationRewards.nextWeek(p)
	if spec == nil then
		return false, code
	end
	local items = StationRewards.resolve(p, spec)
	local animals, now = rollEggs(items), os.time()
	local ok, why = apply(player, function(q)
		StationRewards.visit(q, now)
		return StationRewards.claimWeek(q, items, animals, now)
	end)
	if ok then
		remotes.fx(player, "reward", { items = items })
	end
	return ok, why
end

local function rewardMonth(player: Player, d: number): (boolean, string?)
	local p = today(player)
	if p == nil then
		return false, "loading"
	end
	local can, code = StationRewards.canMonth(p, d)
	if not can then
		return false, code
	end
	local items = StationRewards.resolve(p, StationRewards.MONTH[d])
	local animals, now = rollEggs(items), os.time()
	local ok, why = apply(player, function(q)
		StationRewards.visit(q, now)
		return StationRewards.claimMonth(q, d, items, animals, now)
	end)
	if ok then
		remotes.fx(player, "reward", { items = items })
	end
	return ok, why
end

local function spinWheel(player: Player): (boolean, string?)
	local p = today(player)
	if p == nil then
		return false, "loading"
	end
	local now = os.time()
	if not StationRewards.canSpin(p, now) then
		return false, "spun"
	end
	local roll
	roll, rng = Rng.int(rng, 0, 999999)
	local prize = StationRewards.prizeOf(p, roll)
	local items = StationRewards.resolve(p, StationRewards.WHEEL[prize].prize)
	local animals = rollEggs(items)
	local mythic = nil
	if items.jackpot then
		local all = StationRewards.mythics()
		local k
		k, rng = Rng.int(rng, 1, #all)
		mythic = all[k]
	end
	local ok, why = apply(player, function(q)
		StationRewards.visit(q, now)
		return StationRewards.spin(q, prize, items, animals, mythic, now)
	end)
	if ok then
		remotes.fx(player, "spun", { prize = prize, items = items, mythic = mythic })
	end
	return ok, why
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

-- Admin menu: stand any animal's or Hexbound foe's model in front of the admin to look at it, and
-- play a test wave in the arena. Display only: nothing is added to a profile. LOOKS lists every
-- animal, then its variant, then every foe, in the order the client's menu shows them.
local StationAssets = require(Shared:WaitForChild("StationAssets"))
local WaveShow = require(script.Parent:WaitForChild("WaveShow"))
local TradeLedger = require(script.Parent:WaitForChild("TradeLedger"))
type Look = { s: string?, v: string?, foe: string?, asset: string }
local LOOKS: { Look } = {}
for _, sp in StationConfig.SPECIES do
	table.insert(LOOKS, { s = sp.id, asset = Creatures.asset(sp.id) })
	for _, va in sp.variants do
		table.insert(LOOKS, { s = sp.id, v = va.id, asset = Creatures.asset(sp.id, va.id) })
	end
end
for _, f in StationConfig.FOES do
	table.insert(LOOKS, { foe = f.id, asset = f.model })
end

local function lookSize(look: Look): Vector3
	if look.foe then
		return Creatures.foeSize(look.foe)
	end
	local size = StationAssets[look.asset].size
	return Vector3.new(size[1], size[2], size[3])
end

local lookRuns: { [Player]: number } = {} -- the admin's latest animation button press, so a looping move knows to stop

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

-- Stand `list` in a row in front of `player`, side by side, facing back at them.
local function standBefore(player: Player, list: { Look })
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	local flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	flat = if flat.Magnitude < 0.01 then Vector3.new(0, 0, -1) else flat.Unit
	local feet = root.Position - Vector3.new(0, 3, 0)
	local facing = CFrame.lookAt(feet, feet + flat)
	local total, deepest = 0, 0
	for _, look in list do
		local size = lookSize(look)
		total += size.X + 5
		deepest = math.max(deepest, size.Z)
	end
	local x = -total / 2
	local folder = looks(player)
	for _, look in list do
		local size = lookSize(look)
		local spot = facing * Vector3.new(x + (size.X + 5) / 2, 0, -(12 + deepest / 2))
		x += size.X + 5
		task.spawn(function()
			local at = CFrame.lookAt(spot, spot - flat)
			if look.foe then
				local model = Creatures.spawnFoe(look.foe, at, folder)
				if model then
					Creatures.describeFoe(model, look.foe, (StationConfig.foe(look.foe) :: StationConfig.Foe).stats)
				end
			else
				local model = Creatures.spawn(look.asset, at, folder)
				if model then
					Creatures.describe(model, look.s :: string, look.v, nil)
				end
			end
		end)
	end
end

-- Wave fights (decision 0043). The server picks the team and decides the fight with the pure rules,
-- pays at once and then replays the fight in the arena (WaveShow), one player at a time. A player
-- who leaves mid-replay keeps what the fight paid, but the next fight waits until this one's
-- fight time is up, so skipping the replay does not make farming faster. The player's taps fire
-- their power attacks during the replay (decision 0092): a fight nobody taps in decides the pay at
-- once, and a fight the taps turn into a win pays when it ends (a tap never loses a won fight).
-- Every fight is part of a wave run (decision 0098): HP carries over, a win offers three boons (picking
-- one starts the next wave), and the run's pot is banked when the player leaves (half after a loss).
-- Stars (decision 0097) are kept per wave.
local readyAt: { [Player]: number } = {} -- os.clock() when the player may start another fight
local waveRuns: { [Player]: WaveRuns.Run } = {}

-- End the player's run, if any, and pay its pot: all of it, or WaveRuns.LOSS_KEEP % after a loss.
local function bankRun(player: Player, lost: boolean)
	local run = waveRuns[player]
	waveRuns[player] = nil
	if run == nil then
		return
	end
	local coins, samples = WaveRuns.bank(run, lost)
	if coins > 0 or samples > 0 then
		saves.apply(player, function(q)
			return StationProgress.earn(q, coins, samples)
		end)
	end
	remotes.fx(player, "banked", { coins = coins, samples = samples, lost = lost, waves = run.streak })
end

local function waveFight(player: Player, level: number, continuing: boolean?): (boolean, string?)
	local p = saves.get(player)
	if p == nil then
		return false, "loading"
	elseif os.clock() < (readyAt[player] or 0) then
		return false, "busy"
	end
	local copy = StationProgress.sanitize(p, os.time())
	local ok, code = StationProgress.canFight(copy, level)
	if not ok then
		return false, code
	end
	local team = StationProgress.fighters(copy)
	if not continuing then -- a new run: the old one (if any) is banked
		bankRun(player, false)
		local seed
		seed, rng = Rng.int(rng, 1, 2 ^ 30)
		waveRuns[player] = WaveRuns.new(level, #team, seed)
	end
	local run = waveRuns[player]
	if run == nil or run.wave ~= level then
		return false, "wave"
	end
	local setup = WaveRuns.setup(run)
	local won, _, seconds = LevelRules.fight(team :: any, level, {}, setup)
	local began = os.clock()
	readyAt[player] = began + math.min(seconds, BattleRules.MAX_SECONDS) + 4 -- the walk-in too
	local coins, xp, samples = StationProgress.payout(copy, level)
	local first = level > copy.best
	local started, why = WaveShow.run(player, level, team :: any, function(result)
		-- clicks shorten a fight (decision 0106): the next may start once this one's own time is up
		readyAt[player] = math.min(readyAt[player] or 0, began + math.min(result.seconds, BattleRules.MAX_SECONDS) + 4)
		if result.won and not won then -- the taps won it
			saves.apply(player, function(q)
				return (StationProgress.clear(q, level))
			end)
		end
		saves.apply(player, function(q)
			return StationProgress.setStars(q, level, result.stars)
		end)
		result.coins, result.xp, result.samples =
			if result.won then coins else 0, if result.won then xp else 0, if result.won then samples else 0
		result.first = first
		if waveRuns[player] == run then
			if result.won then
				local after = WaveRuns.won(run, result.ends, coins, samples)
				waveRuns[player] = after
				result.offer, result.streak, result.pot = after.offer, after.streak, after.pot
				if level % LevelRules.BOSS_EVERY == 0 then -- the boss chest
					local q = saves.get(player)
					local items = if q
						then StationRewards.resolve(
							StationProgress.sanitize(q, os.time()),
							StationRewards.bossChest(level)
						)
						else nil
					if items then
						local animals, now = rollEggs(items), os.time()
						local given = apply(player, function(r)
							return StationRewards.grant(r, items, animals, nil, now)
						end)
						result.chest = if given then items else nil
					end
				end
			else
				bankRun(player, true)
			end
		end
		remotes.fx(player, "wavedone", result)
	end, setup)
	if not started then
		readyAt[player] = nil
		if not continuing then
			waveRuns[player] = nil
		end
	elseif won then
		saves.apply(player, function(q)
			return (StationProgress.clear(q, level))
		end)
	end
	return started, why
end

-- Pick boon `id` from the run's offer and fight the run's next wave (decision 0098).
local function pickBoon(player: Player, id: string): (boolean, string?)
	local run = waveRuns[player]
	if run == nil or run.offer == nil then
		return false, "boon"
	elseif os.clock() < (readyAt[player] or 0) then
		return false, "busy"
	end
	local p = saves.get(player)
	if p == nil then
		return false, "loading"
	end
	local can, code = StationProgress.canFight(StationProgress.sanitize(p, os.time()), run.wave)
	if not can then
		return false, code
	end
	local picked, ok, why = WaveRuns.pick(run, id)
	if not ok then
		return false, why
	end
	waveRuns[player] = picked
	return waveFight(player, picked.wave, true)
end

-- Open the next star chest (decision 0097).
local function openChest(player: Player): (boolean, string?)
	local p = today(player)
	if p == nil then
		return false, "loading"
	end
	local spec, code = StationRewards.nextChest(p)
	if spec == nil then
		return false, code
	end
	local items = StationRewards.resolve(p, spec)
	local animals, now = rollEggs(items), os.time()
	local ok, why = apply(player, function(q)
		return StationRewards.claimChest(q, items, animals, now)
	end)
	if ok then
		remotes.fx(player, "reward", { items = items })
	end
	return ok, why
end

-- Trading (decisions 0084, 0099): two players in this server swap animals. A trade lives here, not in the
-- saves. Each side puts in up to StationTrade.MAX of its own animals (not training, not locked). Any change
-- makes both unready, flashes the changed slot and holds Ready for StationTrade.READY_DELAY seconds. When
-- both are ready the window locks and both Confirm after StationTrade.CONFIRM_SECONDS. Then the server
-- checks both saves again, writes both sides to the ledger (TradeLedger), checks once more and applies both
-- with no yield between them. Trading opens at player level StationTrade.MIN_LEVEL, with at most
-- StationTrade.PER_DAY trades a day; a player can turn requests off or block someone for the session.
type Trade = {
	a: Player,
	b: Player,
	offer: { [Player]: { number } },
	ready: { [Player]: boolean },
	stage: string, -- "build" | "confirm"
	changedAt: number, -- os.clock() of the last change
	confirmAt: number, -- os.clock() from which Confirm is allowed
	confirmed: { [Player]: boolean },
	flash: { by: Player, id: number, at: number }?,
	committing: boolean,
}
local trades: { [Player]: Trade } = {}
local invites: { [Player]: { from: Player, at: number } } = {} -- by the player who was asked
local asked: { [Player]: { [Player]: number } } = {} -- when each player last asked each other one
local blocked: { [Player]: { [number]: boolean } } = {} -- UserIds each player has blocked this session
local INVITE_SECONDS = 30

local function partner(t: Trade, player: Player): Player
	return if t.a == player then t.b else t.a
end

local function pushTrade(t: Trade)
	local now = os.clock()
	for _, me in { t.a, t.b } do
		local them = partner(t, me)
		local theirs = {}
		local pt = saves.get(them)
		if pt then
			for _, a in StationTrade.copies(pt, t.offer[them]) do
				table.insert(
					theirs,
					{ id = a.id, s = a.s, v = a.v, rainbow = a.rainbow, stats = a.stats, trained = a.trained }
				)
			end
		end
		local flash = t.flash
		local mine = saves.get(me)
		remotes.fx(me, "trade", {
			with = them.DisplayName,
			level = if pt then StationProgress.playerLevel(pt) else 0,
			traded = if pt then pt.trades.total else 0,
			mine = t.offer[me],
			theirs = theirs,
			ready = t.ready[me] == true,
			theyReady = t.ready[them] == true,
			stage = t.stage,
			readyIn = math.max(0, t.changedAt + StationTrade.READY_DELAY - now),
			confirmIn = math.max(0, t.confirmAt - now),
			confirmed = t.confirmed[me] == true,
			theyConfirmed = t.confirmed[them] == true,
			flash = if flash and now - flash.at < 5
				then { mine = flash.by == me, id = flash.id, left = 5 - (now - flash.at) }
				else nil,
			left = if mine then StationTrade.left(mine, os.time()) else 0,
		})
	end
end

local function closeTrade(t: Trade, why: string)
	trades[t.a], trades[t.b] = nil, nil
	for _, who in { t.a, t.b } do
		if who.Parent then
			remotes.fx(who, "trade", { closed = why })
		end
	end
end

-- Back to building: both unready, and Ready held a moment (after any change, or a failed confirm).
local function changed(t: Trade)
	t.ready[t.a], t.ready[t.b] = false, false
	t.stage, t.confirmed = "build", {}
	t.changedAt = os.clock()
end

local function names(list: { StationRules.Owned }): { string }
	local out = {}
	for _, a in list do
		table.insert(out, StationTrade.nameOf(a))
	end
	return out
end

local function finishTrade(t: Trade): (boolean, string?)
	local pa, pb = saves.get(t.a), saves.get(t.b)
	if pa == nil or pb == nil then
		closeTrade(t, "failed")
		return false, "loading"
	end
	local giveA, giveB = table.clone(t.offer[t.a]), table.clone(t.offer[t.b])
	local getA, getB = StationTrade.copies(pb, giveB), StationTrade.copies(pa, giveA)
	local id = HttpService:GenerateGUID(false)
	local now = os.time()
	local sideA: StationTrade.Side =
		{ id = id, with = t.b.DisplayName, give = giveA, get = getA, gave = names(getB), got = names(getA) }
	local sideB: StationTrade.Side =
		{ id = id, with = t.a.DisplayName, give = giveB, get = getB, gave = names(getA), got = names(getB) }
	-- every check on copies first: neither save changes unless both can
	local function check(): string?
		local qa, qb = saves.get(t.a), saves.get(t.b)
		if qa == nil or qb == nil or trades[t.a] ~= t then
			return "trade_none"
		end
		for _, q in { qa, qb } do
			local can, code = StationTrade.canTrade(StationProgress.sanitize(q, now), now)
			if not can then
				return code
			end
		end
		local _, okA, codeA = StationTrade.commit(StationProgress.sanitize(qa, now), sideA, now)
		local _, okB, codeB = StationTrade.commit(StationProgress.sanitize(qb, now), sideB, now)
		return if okA and okB then nil else (codeA or codeB)
	end
	local code = check()
	if code then
		changed(t)
		pushTrade(t)
		return false, code
	end
	-- the ledger, so a crash between the two saves is finished at the next login (decision 0099). With
	-- both saves offline (Studio) nothing persists, so there is nothing to protect; a mix is refused.
	local onlineA, onlineB = saves.isOnline(t.a), saves.isOnline(t.b)
	if onlineA ~= onlineB then
		changed(t)
		pushTrade(t)
		return false, "trade_saving"
	end
	t.committing = true
	if onlineA then
		local wroteA = TradeLedger.write(t.a.UserId, sideA, now)
		local wroteB = wroteA and TradeLedger.write(t.b.UserId, sideB, now)
		code = if wroteA and wroteB then check() else "trade_store"
		if code then
			t.committing = false
			if wroteA then -- best effort: a side left in the ledger is never applied once cancelled
				task.spawn(TradeLedger.cancel, t.a.UserId, id)
			end
			if wroteB then
				task.spawn(TradeLedger.cancel, t.b.UserId, id)
			end
			if trades[t.a] == t then
				changed(t)
				pushTrade(t)
			end
			return false, code
		end
	end
	-- both applies, with no yield between them
	saves.apply(t.a, function(q)
		return (StationTrade.commit(q, sideA, now))
	end)
	saves.apply(t.b, function(q)
		return (StationTrade.commit(q, sideB, now))
	end)
	closeTrade(t, "done")
	remotes.fx(t.a, "trade_done", { got = sideA.got, gave = sideA.gave, with = sideA.with })
	remotes.fx(t.b, "trade_done", { got = sideB.got, gave = sideB.gave, with = sideB.with })
	return true, nil
end

-- At login: finish any trade the ledger has for the player that their save never got (decision 0099).
local function healTrades(player: Player)
	if not saves.isOnline(player) then
		return
	end
	local list = TradeLedger.read(player.UserId)
	local now = os.time()
	for _, e in list or {} do
		local at = if type(e) == "table" and type(e.at) == "number" then e.at else 0
		local p = saves.get(player)
		if p == nil then
			return
		end
		if
			type(e.id) == "string"
			and not e.cancelled
			and now - at < StationTrade.HEAL_SECONDS
			and not StationTrade.has(p, e.id)
		then
			local side: StationTrade.Side = {
				id = e.id,
				with = tostring(e.with or "?"),
				give = if type(e.give) == "table" then e.give else {},
				get = if type(e.get) == "table" then e.get else {},
				gave = if type(e.gave) == "table" then e.gave else {},
				got = if type(e.got) == "table" then e.got else {},
			}
			local _, ok, code = StationTrade.commit(StationProgress.sanitize(p, now), side, at)
			if ok then
				saves.apply(player, function(q)
					return (StationTrade.commit(q, side, at))
				end)
				print(`[TradeLedger] finished trade {e.id} for {player.UserId}`)
			else
				warn(`[TradeLedger] trade {e.id} for {player.UserId} cannot be finished ({code}); check it by hand`)
			end
		end
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
		-- the planners and the daily wheel (decision 0094): count today, claim, spin
		rewards = {
			args = {},
			handler = function(player)
				local now = os.time()
				return apply(player, function(q)
					return StationRewards.visit(q, now), true, nil
				end)
			end,
		},
		claim_week = { args = {}, handler = rewardWeek },
		claim_month = { args = { Payload.int({ min = 1, max = 31 }) }, handler = rewardMonth },
		spin = { args = {}, handler = spinWheel },
		trade_ask = {
			args = { Payload.int({ min = 1, max = 1e12 }) },
			handler = function(player, userId: number)
				local target = Players:GetPlayerByUserId(userId)
				local mine, theirs = saves.get(player), if target then saves.get(target) else nil
				if target == nil or target == player or mine == nil or theirs == nil then
					return false, "trade_nobody"
				end
				local can, code = StationTrade.canTrade(mine, os.time())
				if not can then
					return false, code
				elseif not (StationTrade.canTrade(theirs, os.time())) then
					return false, "trade_their_level"
				elseif theirs.trades.off or (blocked[target] and blocked[target][player.UserId]) then
					return false, "trade_off"
				elseif trades[player] or trades[target] then
					return false, "trade_busy"
				end
				asked[player] = asked[player] or {}
				local last = asked[player][target]
				if last and os.clock() - last < StationTrade.ASK_GAP then
					return false, "trade_ask_wait"
				end
				asked[player][target] = os.clock()
				invites[target] = { from = player, at = os.clock() }
				remotes.fx(target, "trade_invite", { from = player.UserId, name = player.DisplayName })
				return true, nil
			end,
		},
		trade_answer = {
			args = { Payload.int({ min = 1, max = 1e12 }), Payload.boolean() },
			handler = function(player, userId: number, yes: boolean)
				local invite = invites[player]
				if
					invite == nil
					or invite.from.UserId ~= userId
					or invite.from.Parent == nil
					or os.clock() - invite.at > INVITE_SECONDS
				then
					return false, "trade_expired"
				end
				invites[player] = nil
				if not yes then
					remotes.fx(invite.from, "trade", { closed = "declined" })
					return true, nil
				elseif trades[player] or trades[invite.from] then
					return false, "trade_busy"
				end
				local mine = saves.get(player)
				local can, code = if mine then StationTrade.canTrade(mine, os.time()) else false, "loading"
				if not can then
					return false, code
				end
				local t: Trade = {
					a = invite.from,
					b = player,
					offer = { [invite.from] = {}, [player] = {} },
					ready = {},
					stage = "build",
					changedAt = os.clock(),
					confirmAt = 0,
					confirmed = {},
					flash = nil,
					committing = false,
				}
				trades[t.a], trades[t.b] = t, t
				pushTrade(t)
				return true, nil
			end,
		},
		trade_put = {
			args = { Payload.int({ min = 1, max = 1e12 }) },
			handler = function(player, id: number)
				local t, p = trades[player], saves.get(player)
				if t == nil or p == nil then
					return false, "trade_none"
				elseif t.stage ~= "build" or t.committing then
					return false, "trade_confirming"
				end
				local offer, ok, code = StationTrade.toggle(p, t.offer[player], id)
				if not ok then
					return false, code
				end
				t.offer[player] = offer
				t.flash = { by = player, id = id, at = os.clock() }
				changed(t) -- any change: both look again
				pushTrade(t)
				return true, nil
			end,
		},
		trade_ready = {
			args = {},
			handler = function(player)
				local t = trades[player]
				if t == nil then
					return false, "trade_none"
				elseif t.stage ~= "build" or t.committing then
					return false, "trade_confirming"
				elseif #t.offer[t.a] + #t.offer[t.b] == 0 then
					return false, "trade_empty"
				elseif not t.ready[player] and os.clock() < t.changedAt + StationTrade.READY_DELAY then
					return false, "trade_wait"
				end
				t.ready[player] = not t.ready[player]
				if t.ready[t.a] and t.ready[t.b] then -- the window locks: both look at the summary first
					t.stage, t.confirmAt, t.confirmed = "confirm", os.clock() + StationTrade.CONFIRM_SECONDS, {}
				end
				pushTrade(t)
				return true, nil
			end,
		},
		trade_confirm = {
			args = {},
			handler = function(player)
				local t = trades[player]
				if t == nil then
					return false, "trade_none"
				elseif t.stage ~= "confirm" or t.committing then
					return false, "trade_none"
				elseif os.clock() < t.confirmAt then
					return false, "trade_wait"
				end
				t.confirmed[player] = true
				if t.confirmed[t.a] and t.confirmed[t.b] then
					return finishTrade(t)
				end
				pushTrade(t)
				return true, nil
			end,
		},
		trade_cancel = {
			args = {},
			handler = function(player)
				local t = trades[player]
				if t and not t.committing then
					closeTrade(t, "cancelled")
				end
				return true, nil
			end,
		},
		-- requests off or on (saved), and blocking a player for this session (decision 0099)
		trade_off = {
			args = { Payload.boolean() },
			handler = function(player, off: boolean)
				return apply(player, function(p)
					return StationTrade.setOff(p, off)
				end)
			end,
		},
		trade_block = {
			args = { Payload.int({ min = 1, max = 1e12 }) },
			handler = function(player, userId: number)
				blocked[player] = blocked[player] or {}
				blocked[player][userId] = true
				local invite = invites[player]
				if invite and invite.from.UserId == userId then
					invites[player] = nil
				end
				return true, nil
			end,
		},
		-- lock an animal so it can never go in a trade, or unlock it
		lock = {
			args = { Payload.int({ min = 1, max = 1e12 }) },
			handler = function(player, id: number)
				return apply(player, function(p)
					return StationTrade.lock(p, id)
				end)
			end,
		},
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
				local eggId = p.eggs[k].egg -- read now: the profile is changed in place below
				local i, look = ranchOf(player), Ranch.look(eggId)
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
					rainbow = born.rainbow,
					at = at,
					egg = eggId,
					body = look.body,
					spot = look.spot,
				})
				return true, nil
			end,
		},
		-- the admin menu: `look` stands the k-th animal or foe (0 = all of them) before the admin
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
		-- the admin menu (decision 0049): add the k-th animal of `LOOKS` (never a foe) to the admin's own
		-- ranch with every stat at `level`, in a rainbow coat when `rainbow` is true (decision 0058)
		admin_add = {
			args = {
				Payload.int({ min = 1, max = 100 }),
				Payload.int({ min = 1, max = StationConfig.MAX_LEVEL }),
				Payload.boolean(),
			},
			handler = function(player, k: number, level: number, rainbow: boolean)
				local look = LOOKS[k]
				if not isAdmin(player) or look == nil or look.s == nil then
					return false, "admin"
				end
				return apply(player, function(p)
					local q, ok, code = StationProgress.give(p, look.s :: string, look.v, level, rainbow)
					return q, ok, code
				end)
			end,
		},
		look_anim = {
			args = { Payload.enum({ "idle", "walk", "attack", "magic", "hit", "die" }) },
			handler = function(player, anim: string)
				if not isAdmin(player) then
					return false, "admin"
				end
				-- an attack or power move replays until another button is pressed, to watch it again and again
				local run = (lookRuns[player] or 0) + 1
				lookRuns[player] = run
				local function playAll()
					for _, model in looks(player):GetChildren() do
						Creatures.play(model :: Model, anim)
					end
				end
				playAll()
				if anim == "attack" or anim == "magic" then
					task.spawn(function()
						while true do
							task.wait(Creatures.LENGTH[anim] + 0.4)
							if player.Parent == nil then
								lookRuns[player] = nil
								return
							elseif lookRuns[player] ~= run then
								return
							end
							playAll()
						end
					end)
				end
				return true, nil
			end,
		},
		look_clear = {
			args = {},
			handler = function(player)
				if not isAdmin(player) then
					return false, "admin"
				end
				lookRuns[player] = (lookRuns[player] or 0) + 1 -- stops a looping move
				looks(player):ClearAllChildren()
				WaveShow.clear(player)
				return true, nil
			end,
		},
		-- fight wave `n` with the player's own team; `wave_done` leaves the arena
		wave = {
			args = { Payload.int({ min = 1, max = 1e6 }) },
			handler = waveFight,
		},
		-- fire the power attack of the animal in team slot `n` (decision 0092), with a mash's presses (0106)
		power = {
			args = { Payload.int({ min = 1, max = 4 }), Payload.optional(Payload.int({ min = 0, max = 30 })) },
			handler = WaveShow.power,
		},
		-- the clicks since the client last sent: each a strike (decision 0106); half a token, so clicking
		-- never starves power and shield
		strike = {
			args = { Payload.int({ min = 1, max = 20 }) },
			cost = 0.5,
			handler = WaveShow.strike,
		},
		-- raise the team's shield (decision 0097)
		shield = { args = {}, handler = WaveShow.shield },
		-- pick a boon after a won wave in a run; it starts the next wave (decision 0098)
		boon = {
			args = { Payload.enum({ "claws", "hide", "quick", "charged", "mend", "revive", "lucky", "gold" }) },
			handler = pickBoon,
		},
		claim_chest = { args = {}, handler = openChest },
		wave_done = {
			args = {},
			handler = function(player)
				WaveShow.clear(player) -- reports a fight still on, then the run is banked
				bankRun(player, false)
				if player.Character then
					player.Character:PivotTo(World.arenaGate())
				end
				return true, nil
			end,
		},
		-- teleport the player to their own ranch (leaving a fight, if they are in one)
		home = {
			args = {},
			handler = function(player)
				local i = ranchOf(player)
				if i == nil or player.Character == nil then
					return false, "ranch"
				end
				WaveShow.clear(player)
				bankRun(player, false)
				local to = World.ranchSpawn(i)
				pcall(player.RequestStreamAroundAsync, player, to.Position)
				player.Character:PivotTo(to)
				return true, nil
			end,
		},
		-- travel from anywhere (decision 0093): to the hub or the wave arena's gate (leaving a fight, if
		-- in one); `home` above goes to the player's own ranch. Places far away are streamed in first.
		travel = {
			args = { Payload.enum({ "hub", "arena" }) },
			handler = function(player, where: string)
				if player.Character == nil then
					return false, "loading"
				end
				WaveShow.clear(player)
				bankRun(player, false)
				local to = if where == "hub" then World.hubSpawn() else World.arenaGate()
				pcall(player.RequestStreamAroundAsync, player, to.Position)
				player.Character:PivotTo(to)
				return true, nil
			end,
		},
		-- a test wave in the arena: `team` is "mine" (the admin's own team), "starters" or "mythics"
		testwave = {
			args = { Payload.int({ min = 1, max = 200 }), Payload.enum({ "mine", "starters", "mythics" }) },
			handler = function(player, wave: number, which: string)
				if not isAdmin(player) then
					return false, "admin"
				end
				local team = {}
				if which == "mine" then
					local p = saves.get(player)
					for _, a in if p then StationProgress.fighters(StationProgress.sanitize(p, os.time())) else {} do
						table.insert(team, a)
					end
				end
				if #team == 0 then
					team = WaveShow.team(if which == "mythics" then "mythics" else "starters")
				end
				return WaveShow.run(player, wave, team :: any, function(result)
					remotes.fx(player, "waveshow", result)
				end)
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
		-- The owner empties their Windmill at the mill (decision 0073).
		collect = {
			args = {},
			handler = function(player)
				local p = saves.get(player)
				local now = os.time()
				local coins = if p then StationProgress.held(StationProgress.sanitize(p, now), now) else 0
				local ok, code = apply(player, function(q)
					return StationProgress.collect(q, now)
				end)
				if ok then
					remotes.fx(player, "collected", coins)
				end
				return ok, code
			end,
		},
		-- Studio only: a test funds button in the ranch menu to try the upgrades without
		-- fighting for them. The action does not exist on a live server.
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

-- The Hall of Fame at the hub (decision 0095): the best animals in this server, at most two of any one
-- player's, rarest first and rainbow coats before plain ones. Worked out again a moment after any change.
local RANK = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, mythic = 6 }
local fameQueued = false
local function updateFame()
	if fameQueued then
		return
	end
	fameQueued = true
	task.delay(2, function()
		fameQueued = false
		local all = {}
		for _, player in Players:GetPlayers() do
			local p = saves and saves.get(player)
			if p then
				local mine = {}
				for _, a in p.animals do
					local score = (RANK[StationRules.rarity(a :: any)] or 0) * 2 + (if a.rainbow then 1 else 0)
					table.insert(
						mine,
						{ s = a.s, v = a.v, rainbow = a.rainbow, owner = player.DisplayName, score = score }
					)
				end
				table.sort(mine, function(x, y)
					return x.score > y.score
				end)
				for k = 1, math.min(2, #mine) do
					table.insert(all, mine[k])
				end
			end
		end
		table.sort(all, function(x, y)
			return x.score > y.score
		end)
		World.setFame(all)
	end)
end

saves = Saves.start({
	name = "StationsProfile",
	defaults = StationProgress.defaults,
	sanitize = StationProgress.sanitize,
	snapshot = StationProgress.snapshot,
	onChanged = function(player, profile)
		player:SetAttribute("Coins", profile.coins)
		remotes.fx(player, "profile", StationProgress.public(profile))
		updateFame()
		local i = ranchOf(player)
		if i then
			show(i, profile.upgrades)
			showEggs(i, eggsOf(profile))
			if syncHerd then -- not yet while this script is still starting
				syncHerd(i, profile.animals, profile.upgrades.grounds or 0, denTitan(profile), profile.team)
			end
		end
	end,
})

local function load(player: Player)
	saves.load(player)
	healTrades(player) -- a trade a crash cut short (decision 0099)
end
Players.PlayerAdded:Connect(function(player)
	join(player)
	load(player)
end)
for _, p in Players:GetPlayers() do
	join(p)
	task.spawn(load, p)
end

Players.PlayerRemoving:Connect(function(player)
	task.defer(updateFame) -- after the player has gone
	local t = trades[player]
	if t then
		closeTrade(t, "left")
	end
	invites[player] = nil
	asked[player], blocked[player] = nil, nil
	looks(player):Destroy()
	WaveShow.clear(player)
	bankRun(player, false)
	readyAt[player] = nil
	local i = ranchOf(player)
	if i then
		owners[i] = nil
		World.setRanchOwner(i, nil)
		show(i, {})
		showEggs(i, {})
		syncHerd(i, {}, 0, nil, {})
	end
end)

-- The herd (decisions 0037, 0080): a ranch owner's team walks the pen in the meadow; the rest are off
-- the ranch unless they train (then they are in their training area). Each wanders on its own: it
-- walks to a spot, stands a while, and now and then shows an attack. One that has just hatched steps
-- out of its nest first.
-- shortcut: the server tweens each Root, which replicates at network rate, move them on the
-- client if it looks rough online.
local herds: { [number]: { [number]: Model | boolean } } = {} -- false while its model loads
local dice = Random.new()

local places: { [number]: { [number]: boolean } } = {} -- true for one that stands in the Titan's Den

local function somewhere(i: number): Vector3 -- a spot in the meadow (Ranch.luau's layout)
	return Ranch.somewhere(i, dice)
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

-- Training (decision 0066): the animal that trains at a station is seen in that station's area, at
-- its work: `Areas.act` says where and how. One that goes a round (the track's lap, the pool's
-- length) is moved along it here, like the herd; the others stand and play their clip.
local trainers: { [number]: { [string]: { id: number, level: number, model: Model | boolean } } } = {}

-- What an animal at work kicks up: dust behind a runner, splashes round a swimmer (at the water's top).
local function spray(model: Model, act: Areas.Act)
	local root = model.PrimaryPart :: BasePart
	local at = Instance.new("Attachment")
	at.Position = Vector3.new(0, act.splash or 0.3, 0)
	at.Parent = root
	local puff = Instance.new("ParticleEmitter")
	local swims = act.anim == "swim"
	puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
	puff.Color = ColorSequence.new(if swims then Color3.fromRGB(225, 245, 255) else Color3.fromRGB(214, 184, 142))
	puff.Transparency = NumberSequence.new(0.45, 1)
	puff.Size = NumberSequence.new(if swims then 1.2 else 0.8, if swims then 3.2 else 2.6)
	puff.Lifetime, puff.Rate = NumberRange.new(0.6, 1.1), if swims then 14 else 9
	puff.Speed, puff.SpreadAngle = NumberRange.new(2, 5), Vector2.new(60, 60)
	puff.Acceleration = Vector3.new(0, if swims then -9 else 2, 0)
	puff.EmissionDirection = Enum.NormalId.Top
	puff.Parent = at
end

-- Tells the station's kit what its animal works at and which animal that is
-- (stations-client/Kit.client.luau moves the kit by these), or with no model that nothing does.
local function mark(i: number, station: string, model: Model?, act: Areas.Act?)
	local plot = World.root():FindFirstChild(`Ranch{i}`, true)
	local built = plot and plot:FindFirstChild("Built")
	local folder = built and built:FindFirstChild(station)
	if folder then
		folder:SetAttribute("Work", if model and act then act.kit else nil)
		local worker = folder:FindFirstChild("Worker") or Instance.new("ObjectValue")
		worker.Name, (worker :: ObjectValue).Value = "Worker", model
		worker.Parent = folder
		-- and its kit is fitted to the animal's size
		local size = if model then StationAssets[model.Name].size else nil
		Areas.fit(folder, if model and act then act.kit else nil, size, if model then model:GetPivot() else nil)
	end
end

local function work(model: Model, act: Areas.Act)
	model:SetAttribute("Gaze", act.gaze)
	model:SetAttribute("Work", act.kit)
	if act.anim == "run" or act.anim == "swim" then
		spray(model, act)
	end
	Creatures.play(model, act.anim)
	local round = act.round
	if round == nil then
		return
	end
	local root = model.PrimaryPart :: BasePart
	local speed = Creatures.speed(model) * (if act.anim == "run" then 2.4 else 0.9)
	local k = 1
	while model.Parent do
		local from, to = round[k], round[k % #round + 1]
		local facing = CFrame.lookAt(from, Vector3.new(to.X, from.Y, to.Z))
		if root.CFrame.LookVector:Dot(facing.LookVector) < 0 then -- the end of a length: turn round first
			local turn = TweenService:Create(root, TweenInfo.new(1.2), { CFrame = facing.Rotation + from })
			turn:Play()
			turn.Completed:Wait()
		end
		local seconds = (to - from).Magnitude / speed
		local go = TweenService:Create(
			root,
			TweenInfo.new(seconds, Enum.EasingStyle.Linear),
			{ CFrame = facing.Rotation + to }
		)
		go:Play()
		go.Completed:Wait()
		k = k % #round + 1
	end
end

local function syncTrainers(i: number, animals: { StationProgress.Animal }, level: number)
	local at = trainers[i] or {}
	trainers[i] = at
	local wanted: { [string]: StationProgress.Animal } = {}
	for _, a in animals do
		if a.at and wanted[a.at] == nil then
			wanted[a.at] = a
		end
	end
	for station, t in at do
		local a = wanted[station]
		if a == nil or a.id ~= t.id or t.level ~= level then -- stopped, replaced, or its area has changed
			if typeof(t.model) == "Instance" then
				t.model:Destroy()
			end
			at[station] = nil
			mark(i, station, nil, nil)
		elseif typeof(t.model) == "Instance" then
			Creatures.describe(t.model, a.s, a.v, a :: any) -- training moves its stats
			-- the ranch may have been built again since (another upgrade): its kit must hear again
			mark(i, station, t.model, { anim = "", kit = t.model:GetAttribute("Work") :: string? })
		end
	end
	local plot = World.root():FindFirstChild(`Ranch{i}`, true) :: Instance
	for station, a in wanted do
		if at[station] == nil then
			local t = { id = a.id, level = level, model = false :: Model | boolean }
			at[station] = t
			task.spawn(function()
				local name = Creatures.asset(a.s, a.v)
				local act = Areas.act(i, station, level, StationAssets[name].size)
				local start = act.at or CFrame.lookAt((act.round :: { Vector3 })[1], (act.round :: { Vector3 })[2])
				local model = Creatures.spawn(name, start, plot, nil, a.rainbow)
				if model and at[station] == t then
					t.model = model
					Creatures.describe(model, a.s, a.v, a :: any)
					mark(i, station, model, act)
					work(model, act)
				elseif model then
					model:Destroy() -- stopped while it loaded
				end
			end)
		end
	end
end

-- `titan`: the id of the Titan that stands in its den (decision 0072) and does not roam.
-- `team`: the ids of the team, the only ones in the pen.
function syncHerd(i: number, animals: { StationProgress.Animal }, grounds: number, titan: number?, team: { number })
	syncTrainers(i, animals, grounds)
	local herd = herds[i] or {}
	herds[i] = herd
	local placed = places[i] or {}
	places[i] = placed
	local den = if titan then Ranch.den(i) else nil
	local wanted: { [number]: StationProgress.Animal } = {}
	for _, a in animals do -- one that trains is in its training area, not here
		if a.at == nil and ((den and a.id == titan) or table.find(team, a.id)) then
			wanted[a.id] = a
		end
	end
	for id, model in herd do
		if wanted[id] == nil or placed[id] ~= (den ~= nil and id == titan) then -- gone, or its place changed
			if typeof(model) == "Instance" then
				model:Destroy()
			end
			herd[id], placed[id] = nil, nil
		end
	end
	local plot = World.root():FindFirstChild(`Ranch{i}`, true) :: Instance
	for id, a in wanted do
		local standing = herd[id]
		if typeof(standing) == "Instance" then
			Creatures.describe(standing, a.s, a.v, a :: any) -- training may have moved its stats
		end
		if herd[id] == nil then
			herd[id] = false
			local home = if id == titan then den else nil
			placed[id] = home ~= nil
			task.spawn(function()
				local nest = hatchedAt[id]
				hatchedAt[id] = nil
				if nest then
					task.wait(1.4) -- the hatching animation plays first
				end
				local at = home or nest or CFrame.new(somewhere(i))
				local model = Creatures.spawn(Creatures.asset(a.s, a.v), at, plot, nil, a.rainbow)
				if model and herd[id] == false then
					herd[id] = model
					Creatures.describe(model, a.s, a.v, a :: any)
					if home then
						Creatures.play(model, "sleep") -- the Titan sleeps in its den (Creatures.client's TRAIN)
					else
						wander(model, i)
					end
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
		syncHerd(i, p.animals, p.upgrades.grounds or 0, denTitan(p), p.team)
	end
end
