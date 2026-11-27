--!strict
-- Animal Stations server entry: builds the world, gives each player a home ranch (lowest free of
-- World.RANCHES, owners spawn at its gate), teleports players between their ranch and the hub,
-- loads saves (kit Saves), shows each ranch as its owner has built it and the eggs in its hatchery
-- (Ranch.luau), and routes every request (kit Router): buying eggs, starting one hatching and
-- opening it, ranch upgrades, the team and training. The client only names an action; prices, hatches and timings are decided here.
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Areas = require(script.Parent:WaitForChild("Areas"))
local Creatures = require(script.Parent:WaitForChild("Creatures"))
local Analytics = require(script.Parent:WaitForChild("Analytics"))
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
-- Which nest each hatching egg sits in, in the order of the hatching eggs: an egg keeps its nest until it is
-- opened, so the others never move into a nest whose egg is still cracking (SHANNON, 2026-11-25). Display only.
local nestsOf: { [number]: { number } } = {}
local function nestList(i: number, hatching: number): { number }
	local list = nestsOf[i] or {}
	nestsOf[i] = list
	while #list > hatching do -- fewer than before without an opening (a rejoin, a reset): the last ones go
		table.remove(list)
	end
	while #list < hatching do -- a new egg started: the lowest free nest
		local n = 1
		while table.find(list, n) do
			n += 1
		end
		table.insert(list, n)
	end
	return list
end
local function showEggs(i: number, eggs: { { egg: string, since: number?, due: number? } })
	local key, hatching = "", 0
	for _, e in eggs do
		key ..= e.egg .. (if e.since then `+{e.due},` else ",")
		hatching += if e.since then 1 else 0
	end
	local places = nestList(i, hatching)
	key ..= table.concat(places, ".")
	if held[i] ~= key then
		held[i] = key
		Ranch.eggs(i, eggs, places)
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
local StationGoals = require(Shared:WaitForChild("StationGoals"))
local StationIntro = require(Shared:WaitForChild("StationIntro"))
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

-- Goals (decision 0115): whatever goal the save now shows as reached is paid, one after another, each
-- with a note to the player. Called after every change of a save (onChanged).
local payingGoals: { [Player]: boolean } = {}
local function payGoals(player: Player)
	if payingGoals[player] then
		return
	end
	payingGoals[player] = true
	for _ = 1, #StationGoals.LIST + #StationGoals.LEVELS do
		local p = saves.get(player)
		local q = if p then StationProgress.sanitize(p, os.time()) else nil
		local goal = if q then StationGoals.due(q) or StationGoals.levelDue(q) else nil
		if q == nil or goal == nil then
			break
		end
		local items = StationGoals.items(q, goal)
		local animals, now = rollEggs(items), os.time()
		Analytics.because(player, "goal")
		local ok = apply(player, function(r)
			return StationGoals.finish(r, goal.id, items, animals, now)
		end)
		if not ok then
			break
		end
		remotes.fx(player, "goal", { text = goal.text, items = items })
	end
	payingGoals[player] = nil
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
--
-- Shared fights (decision 0108): a fight is a party's, of one to World.RANCHES players. Everyone standing
-- in the wave portal's ring when a wave starts joins it, at a run's first wave and at every one after. The
-- party shares the run (its wave, its boons, each animal's carried HP); every member is paid what they
-- would be alone, by their own save, and keeps their own pot. After a win they vote for the boon.
type Pot = { coins: number, samples: number }
type Party = {
	members: { Player }, -- in the order they joined: a member's place is their team's `owner` in the fight
	run: WaveRuns.Run,
	hp: { [Player]: { number } }, -- each member's carried HP, by their own animals in order
	pots: { [Player]: Pot },
	wins: { [Player]: number }, -- the waves each member has won in this run
	votes: { [Player]: string },
	round: number, -- counts the votes, so an old vote's timer does nothing
	readyAt: number, -- os.clock() when the party may start another fight
	holdTo: number, -- os.clock() until when the field is kept for it while it picks a boon
}
local partyOf: { [Player]: Party } = {}
-- The Ranger's loan each player has taken for their next wave (decision 0119): legend `k` of StationIntro.TEAM
-- in place of their animal `replaces`. Kept here, not in the save: the save only records a loan once it is used.
local loans: { [Player]: { k: number, replaces: number } } = {}
local VOTE_SECONDS = 7 -- a party's boon vote is this long from the offer (SHANNON, 2026-11-24); alone, no limit
local HOLD_SECONDS = 30 -- how long the field waits for a party to pick its boon (SHANNON, 2026-11-24: was 60)
local fieldOf: Party? = nil -- the party that last fought on the field
local settle: (party: Party) -> ()

-- Whether a party other than `mine` holds the field: its fight is on, or it is picking its boon.
local function fieldHeld(mine: Party?): boolean
	local p = fieldOf
	if p == nil or p == mine or #p.members == 0 then
		return false
	end
	local host = WaveShow.active()
	return (host ~= nil and partyOf[host] == p and os.clock() < p.readyAt)
		or (p.run.offer ~= nil and os.clock() < p.holdTo)
end

-- Whether every member of `party` has voted for a boon on offer.
local function allVoted(party: Party): boolean
	if party.run.offer == nil or #party.members == 0 then
		return false
	end
	for _, m in party.members do
		if party.votes[m] == nil then
			return false
		end
	end
	return true
end

-- `player` leaves their party, if any, and their pot is paid: all of it, or WaveRuns.LOSS_KEEP % after a
-- loss. The party goes on without them.
local function bankRun(player: Player, lost: boolean)
	local party = partyOf[player]
	partyOf[player] = nil
	if party == nil then
		return
	end
	local k = table.find(party.members, player)
	if k then
		table.remove(party.members, k)
	end
	local pot = party.pots[player] or { coins = 0, samples = 0 }
	local coins, samples = WaveRuns.bank({ pot = pot, boons = party.run.boons } :: any, lost) -- Golden Hour
	local waves = party.wins[player] or 0
	party.pots[player], party.hp[player], party.votes[player], party.wins[player] = nil, nil, nil, nil
	if coins > 0 or samples > 0 then
		Analytics.because(player, "run_pot")
		saves.apply(player, function(q)
			return StationProgress.earn(q, coins, samples)
		end)
	end
	local egg = nil
	if not lost and WaveRuns.count(party.run, "jackpot") > 0 then -- Jackpot Egg (decision 0120): the best unlocked
		local p = saves.get(player)
		if p then
			egg = StationRewards.bestEgg(StationProgress.sanitize(p, os.time()))
			local items: StationRewards.Items = { coins = 0, samples = 0, eggs = { egg }, seconds = 0, jackpot = false }
			local animals, now = rollEggs(items), os.time()
			saves.apply(player, function(q) -- a full cellar keeps it waiting in the rewards (StationRewards.grant)
				return StationRewards.grant(q, items, animals, nil, now)
			end)
		end
	end
	remotes.fx(player, "banked", { coins = coins, samples = samples, lost = lost, waves = waves, egg = egg })
	if allVoted(party) then -- the others were only waiting for this player's vote
		settle(party)
	end
end

-- Whether `p` has a team to fight with now.
local function hasTeam(p: Player): boolean
	local save = saves.get(p)
	return save ~= nil and #StationProgress.fighters(StationProgress.sanitize(save, os.time())) > 0
end

-- Everyone who fights `party`'s next wave: its members who still have a team, and anyone else standing in
-- the wave portal's ring with one (they leave the run they were in). World.RANCHES at most.
local function muster(party: Party)
	for _, m in table.clone(party.members) do
		if not hasTeam(m) then
			bankRun(m, false)
		end
	end
	for _, p in Players:GetPlayers() do
		if #party.members >= World.RANCHES then
			break
		end
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if partyOf[p] ~= party and root and root:IsA("BasePart") and World.inPortal(root.Position) and hasTeam(p) then
			bankRun(p, false)
			partyOf[p] = party
			table.insert(party.members, p)
		end
	end
end

local function waveFight(player: Player, level: number, continuing: boolean?): (boolean, string?)
	local p = saves.get(player)
	if p == nil then
		return false, "loading"
	end
	local party = partyOf[player]
	if party and os.clock() < party.readyAt then
		return false, "busy"
	end
	if not continuing then -- a new run: the old one (if any) is banked
		if fieldHeld(party) then
			return false, "field" -- another party is fighting: wait in the portal to join its next wave
		end
		local ok, code = StationProgress.canFight(StationProgress.sanitize(p, os.time()), level)
		if not ok then
			return false, code
		end
		bankRun(player, false)
		local seed
		seed, rng = Rng.int(rng, 1, 2 ^ 30)
		party = {
			members = { player },
			run = WaveRuns.new(level, 0, seed),
			hp = {},
			pots = {},
			wins = {},
			votes = {},
			round = 0,
			readyAt = 0,
			holdTo = 0,
		}
		partyOf[player] = party
	end
	if party == nil or party.run.wave ~= level then
		return false, "wave"
	end
	muster(party)
	if #party.members == 0 then
		return false, "no_team"
	end
	-- the fight's team: every member's animals, marked with the member's place, at the HP the run carries
	local members = table.clone(party.members)
	local team, ownerOf, hp = {}, {}, {}
	local lent: { [Player]: { k: number, replaces: number } } = {}
	local pay: { [Player]: { coins: number, xp: number, samples: number, first: boolean } } = {}
	for k, m in members do
		local copy = StationProgress.sanitize(saves.get(m) :: any, os.time())
		local carried = party.hp[m]
		local loan = loans[m]
		if loan and not StationIntro.canLend(copy, loan.k, loan.replaces, level, os.time()) then
			loan = nil -- not for this wave (the boss's loan waits for wave 10)
		end
		for j, a in StationProgress.fighters(copy) do
			local mine = table.clone(a) :: any
			local fresh = false
			if loan and a.id == loan.replaces then -- the Ranger's legend stands in for this wave (decision 0119)
				mine, fresh = StationIntro.lent(loan.k) :: any, true
				lent[m] = loan
			end
			mine.owner = k
			table.insert(team, mine)
			table.insert(ownerOf, k)
			table.insert(hp, if carried and carried[j] and not fresh then carried[j] else 1)
		end
		local coins, xp, samples = StationProgress.payout(copy, level)
		pay[m] = { coins = coins, xp = xp, samples = samples, first = level > copy.best }
		party.pots[m] = party.pots[m] or { coins = 0, samples = 0 }
		party.wins[m] = party.wins[m] or 0
	end
	local run = table.clone(party.run)
	run.hp = hp
	party.run = run
	local onField = WaveShow.active() -- a finished fight's result still on the field makes way
	if onField and not table.find(members, onField) then
		WaveShow.clear(onField)
	end
	local setup = WaveRuns.setup(run)
	local won, _, seconds = LevelRules.fight(team :: any, level, {}, setup)
	local began = os.clock()
	party.readyAt = began + math.min(seconds, BattleRules.MAX_SECONDS) + 4 -- the walk-in too
	local started, why = WaveShow.run(members, level, team :: any, function(result)
		-- clicks shorten a fight (decision 0106): the next may start once this one's own time is up
		party.readyAt = math.min(party.readyAt, began + math.min(result.seconds, BattleRules.MAX_SECONDS) + 4)
		local after: WaveRuns.Run? = nil
		if party.run == run and result.won then
			after = WaveRuns.won(run, result.ends, 0, 0)
			for _, m in members do
				party.hp[m] = {}
			end
			for i, k in ownerOf do
				table.insert(party.hp[members[k]], (after :: WaveRuns.Run).hp[i])
			end
			party.run, party.votes = after :: WaveRuns.Run, {}
			party.round += 1
			party.holdTo = os.clock() + HOLD_SECONDS
			if #party.members > 1 and level < LevelRules.LAST then -- a short vote: settled when time is up
				local round = party.round
				task.delay(VOTE_SECONDS, function()
					if party.round == round then
						settle(party)
					end
				end)
			end
		end
		local last = result.won and level >= LevelRules.LAST -- the last wave (decision 0107): the run is over
		for k, m in members do
			if partyOf[m] ~= party then -- left meanwhile: paid for what was settled at the start, no more
				continue
			end
			local mine = pay[m]
			Analytics.because(m, "wave_pay")
			if not result.won and level <= 3 then -- an early loss: the funnel's leak (decision 0113)
				Analytics.event(m, "WaveLost", 1, `wave {level}`)
			end
			if result.won and not won then -- the taps won it
				saves.apply(m, function(q)
					return (StationProgress.clear(q, level, true))
				end)
			end
			saves.apply(m, function(q)
				return StationProgress.setStars(q, level, result.stars[k])
			end)
			if #members > 1 then -- fought beside a teammate's animals: they are met (decision 0118)
				saves.apply(m, function(q)
					for _, a in team do
						q = StationProgress.meet(q, a.s, a.v)
					end
					return q
				end)
			end
			local out = table.clone(result)
			out.stars, out.missed, out.party = result.stars[k], result.missed[k], #members
			out.coins, out.xp, out.samples =
				if result.won then mine.coins else 0,
				if result.won then mine.xp else 0,
				if result.won then mine.samples else 0
			out.first = mine.first
			out.boons, out.wins, out.twice = party.run.boons, party.wins[m], WaveRuns.twice(party.run) -- for the boon cards' stacks and the run's end
			if after then
				local coins, samples = WaveRuns.bonus(run, mine.coins, mine.samples)
				local pot = party.pots[m]
				pot.coins += coins
				pot.samples += samples
				party.wins[m] += 1
				if last then
					out.last = true
				else
					out.offer, out.streak, out.pot = after.offer, after.streak, pot
				end
				if level % LevelRules.BOSS_EVERY == 0 then -- the boss chest, one each
					local q = saves.get(m)
					local items = if q
						then StationRewards.resolve(
							StationProgress.sanitize(q, os.time()),
							StationRewards.bossChest(level)
						)
						else nil
					if items then
						local animals, now = rollEggs(items), os.time()
						local given = apply(m, function(r)
							return StationRewards.grant(r, items, animals, nil, now)
						end)
						out.chest = if given then items else nil
					end
				end
			end
			if last or not result.won then -- the run is over: the pot in full after the last wave, a part after a loss
				bankRun(m, not result.won)
			end
			remotes.fx(m, "wavedone", out)
		end
	end, setup)
	if not started then
		party.readyAt = 0
		if not continuing then -- the run never began: nothing to bank
			for _, m in table.clone(party.members) do
				partyOf[m] = nil
			end
		end
		return false, why
	end
	fieldOf = party
	for m, loan in lent do -- the wave is on: the loan is used (decision 0119)
		loans[m] = nil
		local now = os.time()
		apply(m, function(q)
			return StationIntro.useLoan(q, loan.k, loan.replaces, level, now)
		end)
	end
	for _, m in members do
		if continuing or m ~= player then -- whoever did not ask for this wave is told it is on
			remotes.fx(m, "began", { wave = level, party = #members })
		end
		Analytics.step(m, 6)
		if won then
			Analytics.because(m, "wave_pay")
			saves.apply(m, function(q)
				return (StationProgress.clear(q, level, true))
			end)
		end
	end
	return true, nil
end

-- The votes are in (or their time is up): the party's boon is picked (WaveRuns.tally) and its next wave starts.
function settle(party: Party)
	local run = party.run
	if run.offer == nil or #party.members == 0 then
		return
	end
	local votes = {}
	for _, m in party.members do
		if party.votes[m] then
			table.insert(votes, party.votes[m])
		end
	end
	local id = WaveRuns.tally(run, votes)
	local picked, ok = WaveRuns.pick(run, id or "")
	if not ok then
		return
	end
	party.run, party.votes = picked, {}
	party.round += 1
	for _, m in party.members do -- everyone's HUD adds it to the run's stack; a party's also says which won the vote
		remotes.fx(m, "boon", { id = id, again = if picked.offer then picked.offer else nil })
	end
	if picked.offer then -- Twin Picks: the rest of the offer for a second pick (a party votes again)
		party.holdTo = os.clock() + HOLD_SECONDS
		if #party.members > 1 then
			local round = party.round
			task.delay(VOTE_SECONDS, function()
				if party.round == round then
					settle(party)
				end
			end)
		end
		return
	end
	if not waveFight(party.members[1], picked.wave, true) then
		-- they took too long and the field is another party's now: the run ends here, its pots paid
		for _, m in table.clone(party.members) do
			WaveShow.clear(m)
			bankRun(m, false)
			remotes.fx(m, "over", {})
			if m.Character then
				m.Character:PivotTo(World.arenaGate())
			end
		end
	end
end

-- Vote for boon `id` from the run's offer (decision 0098). One player's vote picks it; a party's boon is
-- the one most of them vote for (decision 0108), once all have voted or VOTE_SECONDS after it was offered.
-- The next wave then starts.
local function pickBoon(player: Player, id: string): (boolean, string?)
	local party = partyOf[player]
	local offer = if party then party.run.offer else nil
	if party == nil or offer == nil or not table.find(offer, id) then
		return false, "boon"
	elseif os.clock() < party.readyAt then
		return false, "busy"
	elseif saves.get(player) == nil then
		return false, "loading"
	end
	party.votes[player] = id
	party.holdTo = math.max(party.holdTo, os.clock() + VOTE_SECONDS + 2)
	if allVoted(party) then
		settle(party)
		return true, nil
	end
	local voted, picks = 0, {}
	for _, m in party.members do
		voted += if party.votes[m] then 1 else 0
		if party.votes[m] then -- who voted for which (the avatar dots on the boon cards, STATION-160)
			table.insert(picks, { user = m.UserId, id = party.votes[m] })
		end
	end
	for _, m in party.members do
		remotes.fx(m, "votes", { voted = voted, of = #party.members, seconds = VOTE_SECONDS, picks = picks })
	end
	return true, nil
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
				table.insert(theirs, {
					id = a.id,
					s = a.s,
					v = a.v,
					rainbow = a.rainbow,
					coat = a.coat,
					stats = a.stats,
					trained = a.trained,
				})
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
				if not StationTrade.ON then
					return false, "trade_closed"
				elseif target == nil or target == player or mine == nil or theirs == nil then
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
		-- music and effects volume, and mute (decision 0122)
		sound = {
			args = { Payload.int({ min = 0, max = 10 }), Payload.int({ min = 0, max = 10 }), Payload.boolean() },
			handler = function(player, music: number, effects: number, mute: boolean)
				return apply(player, function(p)
					return StationProgress.setSound(p, music, effects, mute)
				end)
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
		-- release an animal for a few coins, or fuse four of one into the next coat tier (decision 0112)
		release = {
			args = { Payload.int({ min = 1, max = 1e12 }) },
			handler = function(player, id: number)
				return apply(player, function(p)
					return StationProgress.release(p, id)
				end)
			end,
		},
		fuse = {
			args = {
				Payload.int({ min = 1, max = 1e12 }),
				Payload.int({ min = 1, max = 1e12 }),
				Payload.int({ min = 1, max = 1e12 }),
				Payload.int({ min = 1, max = 1e12 }),
			},
			handler = function(player, a: number, b: number, c: number, d: number)
				local save, first = saves.get(player), nil
				if save then
					_, first = StationProgress.find(save, a)
				end
				if first == nil then
					return false, "animal"
				end
				local next = StationProgress.COAT_TIERS[StationProgress.coatTier(first) + 1]
				if next == nil then
					return false, "fuse_top"
				end
				local coat = next[math.random(1, #next)] -- the server picks which coat of the tier
				return apply(player, function(p)
					return StationProgress.fuse(p, { a, b, c, d }, coat)
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
				local nth, hatching = 0, 0 -- its place among the hatching eggs, and how many hatch
				for j, e in p.eggs do
					hatching += if e.since then 1 else 0
					nth += if j <= k and e.since then 1 else 0
				end
				local eggId = p.eggs[k].egg -- read now: the profile is changed in place below
				local i, look = ranchOf(player), Ranch.look(eggId)
				local at = nil
				if i then -- its own nest, which is free from now on (the others keep theirs)
					local places = nestList(i, hatching)
					at = Ranch.nest(i, places[nth])
					table.remove(places, nth)
				end
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
					coat = born.coat,
					at = at,
					egg = eggId,
					body = look.body,
					spot = look.spot,
				})
				-- an epic or rarer hatch, or any coat, is announced to the server (SHANNON, 2026-11-24)
				local rank = table.find(StationConfig.RARITIES, StationRules.rarity(born :: any)) or 0
				if rank >= (table.find(StationConfig.RARITIES, "epic") or 99) or born.coat then
					local what = `a {StationRules.rarity(born :: any)} {StationTrade.nameOf(born :: any)}`
					for _, other in Players:GetPlayers() do
						if other ~= player then
							remotes.fx(other, "announce", { who = player.DisplayName, what = what })
						end
					end
				end
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
		-- fight wave `n` with the player's own team, and everyone's in the wave portal (decision 0108);
		-- `wave_done` leaves the fight
		wave = {
			args = { Payload.int({ min = 1, max = 1e6 }) },
			handler = waveFight,
		},
		-- fire the power attack of the animal in team slot `n` (decision 0092), with a mash's presses (0106)
		power = {
			-- presses -1 (BattleRules.FAILED): the press was messed up, the power spent on a plain hit
			args = { Payload.int({ min = 1, max = 4 }), Payload.optional(Payload.int({ min = -1, max = 30 })) },
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
			args = { Payload.enum(ids(WaveRuns.BOONS)) }, -- every boon (decision 0120)
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
		-- the intro (decision 0116): "fight" starts the borrowed fight, which cannot be lost and ends the intro;
		-- "skip" ends it at once. Either way the starter eggs are given, once.
		intro = {
			args = { Payload.enum({ "fight", "skip" }) },
			handler = function(player, what: string)
				local p = saves.get(player)
				if p == nil then
					return false, "loading"
				elseif StationProgress.sanitize(p, os.time()).intro then
					return false, "intro_done"
				end
				local function finish(): (boolean, string?)
					local now = os.time()
					Analytics.because(player, "intro")
					return apply(player, function(q)
						return StationIntro.finish(q, now)
					end)
				end
				if what == "skip" then
					Analytics.event(player, "IntroSkipped", 1)
					return finish()
				end
				return WaveShow.run({ player }, StationIntro.WAVE, StationIntro.team() :: any, function(result)
					finish()
					saves.apply(player, function(q) -- the borrowed legends are met (decision 0118)
						for _, a in StationIntro.team() do
							q = StationProgress.meet(q, a.s, a.v)
						end
						return q
					end)
					remotes.fx(player, "intro", { seconds = result.seconds })
				end, StationIntro.SETUP)
			end,
		},
		-- the Ranger's loan (decision 0119): legend `k` (1 to 4, StationIntro.TEAM) stands in for the player's animal
		-- `replaces` in their next wave it may be taken for; k = 0 takes it back. Used (and saved) when that wave starts.
		loan = {
			args = { Payload.int({ min = 0, max = #StationIntro.TEAM }), Payload.int({ min = 0, max = 1e12 }) },
			handler = function(player, k: number, replaces: number)
				local p = saves.get(player)
				if p == nil then
					return false, "loading"
				elseif k == 0 then
					loans[player] = nil
					return true, nil
				end
				local copy, now = StationProgress.sanitize(p, os.time()), os.time()
				local wave = if copy.loan.boss then 1 else StationIntro.LOAN_WAVE -- any wave once the boss's is used
				local ok, code = StationIntro.canLend(copy, k, replaces, wave, now)
				if ok then
					loans[player] = { k = k, replaces = replaces }
				end
				return ok, code
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
				return WaveShow.run({ player }, wave, team :: any, function(result)
					result.stars, result.missed = result.stars[1], result.missed[1]
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
		-- The owner collects what the ranch animals earned, from the Ranch menu (decision 0124).
		collect_herd = {
			args = {},
			handler = function(player)
				local p = saves.get(player)
				local now = os.time()
				local coins = if p then StationProgress.herdHeld(StationProgress.sanitize(p, now), now) else 0
				local ok, code = apply(player, function(q)
					return StationProgress.collectHerd(q, now)
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
-- every request but clicks and presses names what changes the save next, and a refusal is counted (decision 0113)
for name, action in router.options.actions do
	if name == "strike" or name == "power" then
		continue
	end
	local handler = action.handler
	action.handler = function(player, ...)
		Analytics.because(player, name)
		local ok, code = handler(player, ...)
		if not ok and code then
			Analytics.event(player, "Refused", 1, name, tostring(code))
		end
		return ok, code
	end
end
remotes = Remotes.create("StationsRemotes", router)

-- The Hall of Fame at the hub (decision 0095): the best animals in this server, at most two of any one
-- player's, rarest first and rainbow coats before plain ones. Worked out again a moment after any change.
local RANK = {
	common = 1,
	uncommon = 2,
	rare = 3,
	epic = 4,
	legendary = 5,
	mythic = 6,
	divine = 7,
	celestial = 8,
	secret = 9,
	eternal = 10,
}
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
					local score = (RANK[StationRules.rarity(a :: any)] or 0) * 2
						+ (if StationRules.coatOf(a :: any) then 1 else 0)
					table.insert(mine, {
						s = a.s,
						v = a.v,
						rainbow = a.rainbow,
						coat = a.coat,
						owner = player.DisplayName,
						score = score,
					})
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
	-- never a blank profile (beta blocker 5, SHANNON's pick A): a save another server still holds is waited for up
	-- to two minutes behind the loading cover, and a session that cannot save sends the player to rejoin
	waitBusy = 120,
	-- an old server never loads a save newer content wrote (beta blocker 6): the player goes to a newer one
	tooNew = function(record)
		return type(record) == "table" and type(record.version) == "number" and record.version > StationProgress.VERSION
	end,
	onStatus = function(player, status)
		if status ~= "online" then
			Analytics.event(player, "SaveTrouble", 1, status)
		end
		if status == "newer" then
			player:Kick("A new update is out. Please rejoin to play it.")
		elseif status ~= "online" and not RunService:IsStudio() then
			player:Kick(
				if status == "lost"
					then "Your ranch was opened on another server. Please rejoin."
					else "Your ranch couldn't load. Please rejoin in a minute."
			)
		end
	end,
	-- a run's pot is banked while the save can still take it (beta blocker 7)
	beforeFinish = function(player)
		bankRun(player, false)
	end,
	defaults = StationProgress.defaults,
	sanitize = StationProgress.sanitize,
	snapshot = StationProgress.snapshot,
	onChanged = function(player, profile)
		player:SetAttribute("Coins", profile.coins)
		player:SetAttribute("Level", StationProgress.playerLevel(profile)) -- on others' cards under the cursor
		Analytics.changed(player, profile)
		-- the first session's funnel (decision 0113): each step logs once, whenever the save first shows it
		local hatching = #profile.animals > 0
		for _, e in profile.eggs do
			hatching = hatching or e.since ~= nil
		end
		for k, reached in
			{
				[2] = #profile.eggs > 0 or #profile.animals > 0,
				[3] = hatching,
				[4] = #profile.animals > 0,
				[5] = #profile.team > 0,
				[7] = profile.best >= 1,
				[8] = profile.best >= 3,
				[9] = profile.best >= 10,
				[10] = StationProgress.playerLevel(profile) >= 5,
			}
		do
			if reached then
				Analytics.step(player, k)
			end
		end
		remotes.fx(player, "profile", StationProgress.public(profile))
		if StationGoals.due(profile) or StationGoals.levelDue(profile) then
			task.defer(payGoals, player)
		end
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

-- Robux and the beta (decision 0117) ---------------------------------------------------------------------------
-- A granted animal's coat, rolled like a hatch from no egg (no signature coat), from `seed`.
local function shopCoat(seed: string): string?
	local n = 0
	for k = 1, #seed do
		n = (n * 31 + string.byte(seed, k)) % 2147483647
	end
	return StationRules.pickCoat({} :: any, Random.new(n):NextInteger(1, StationRules.PPM))
end

-- Give `player` the beta reward once (StationConfig.BETA_GIFT), and show it.
local function betaGift(player: Player)
	local p = saves.get(player)
	if StationConfig.BETA_GIFT == nil or p == nil or p.beta or not saves.isOnline(player) then
		return
	end
	local coat = shopCoat(`beta{player.UserId}`)
	local given: any = nil
	saves.apply(player, function(q)
		local r, _, _, animal = StationProgress.betaGift(q, coat)
		given = given or animal
		return r
	end)
	if given then
		remotes.fx(player, "granted", { animal = given, why = "beta" })
	end
end

-- A Robux purchase (developer products, StationConfig.PRODUCTS): granted once per receipt into the save, and
-- reported granted to Roblox only once the save is written. Anything else is "not processed yet": Roblox sends
-- the receipt again (when the player is next in a server), and the grant is idempotent by its PurchaseId.
MarketplaceService.ProcessReceipt = function(info)
	local item = StationConfig.product(info.ProductId)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if item == nil or player == nil or not saves.isOnline(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = `r{info.PurchaseId}`
	local coat = shopCoat(key)
	local given: any, why: string? = nil, nil
	saves.apply(player, function(q)
		local r, _, code, animal = StationProgress.grant(q, item.s, item.v, key, coat)
		given, why = given or animal, why or code
		return r
	end)
	if why == "full" then
		remotes.fx(player, "full_purchase", item.v)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local p = saves.get(player)
	if p == nil or table.find(p.receipts, key) == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	for _ = 1, 3 do
		if saves.flush(player) then
			if given then
				remotes.fx(player, "granted", { animal = given, why = "robux" })
				Analytics.event(player, "RobuxAnimal", 1, item.id)
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		task.wait(2)
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function load(player: Player)
	Analytics.step(player, 1)
	saves.load(player)
	healTrades(player) -- a trade a crash cut short (decision 0099)
	betaGift(player)
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
	payingGoals[player] = nil
	task.defer(updateFame) -- after the player has gone
	task.defer(Analytics.forget, player)
	local t = trades[player]
	if t then
		closeTrade(t, "left")
	end
	invites[player] = nil
	asked[player], blocked[player] = nil, nil
	loans[player] = nil
	looks(player):Destroy()
	WaveShow.clear(player)
	bankRun(player, false)
	local i = ranchOf(player)
	if i then
		owners[i] = nil
		World.setRanchOwner(i, nil)
		show(i, {})
		nestsOf[i] = nil
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
				local model = Creatures.spawn(name, start, plot, nil, a.coat or a.rainbow)
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
				local model = Creatures.spawn(Creatures.asset(a.s, a.v), at, plot, nil, a.coat or a.rainbow)
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
