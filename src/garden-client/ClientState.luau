--!strict
-- Egg Garden client-only state (docs/architecture/garden.md section 6): settings that never reach
-- the server, signals between the client scripts (reveal hiding, toasts, menu open), read-only
-- parsers for GardenStatus and Profile attributes, one-shot sounds and the shared pastel UI kit.

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenProgress = require(Shared:WaitForChild("GardenProgress"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local LoginRules = require(Shared:WaitForChild("LoginRules"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))

local ClientState = {}

export type Settings = {
	music: boolean,
	sfx: boolean,
	fastHatch: boolean,
	announcements: boolean,
	followers: boolean,
	trades: boolean,
}
export type EventStatus = { weather: string, startsAt: number, endsAt: number, active: boolean }
export type DashStatus = {
	phase: string, -- idle | countdown | starting | racing
	ready: { number },
	need: number,
	at: number, -- countdown end, GO or time limit by phase, server time
	goAt: number,
	racers: { number },
}
export type Status = {
	weather: string,
	weatherLeft: number,
	forecast: { string },
	stockLeft: number,
	stockWindow: number,
	dash: DashStatus,
	event: EventStatus,
}

ClientState.settings = {
	music = true,
	sfx = true,
	fastHatch = false,
	announcements = true,
	followers = true,
	trades = true,
} :: Settings

local settingsChanged = Instance.new("BindableEvent")
ClientState.SettingsChanged = settingsChanged.Event
local revealing = Instance.new("BindableEvent")
ClientState.Revealing = revealing.Event -- (key: string, hidden: boolean) from HatchFx to CreatureFx
local toasted = Instance.new("BindableEvent")
ClientState.Toasted = toasted.Event -- (text: string, colour: Color3?, icon: string?) rendered by Menu (UiKit.toast)
local menuChanged = Instance.new("BindableEvent")
ClientState.MenuChanged = menuChanged.Event -- (open: boolean)
local openRequested = Instance.new("BindableEvent")
ClientState.OpenRequested = openRequested.Event -- (panel: string) HUD buttons ask Menu to open a panel
local racingChanged = Instance.new("BindableEvent")
ClientState.RacingChanged = racingChanged.Event -- (racing: boolean) from DashFx to Hud and Menu
local tradeChanged = Instance.new("BindableEvent")
ClientState.TradeChanged = tradeChanged.Event -- (payload: table?) the last `trade` Fx, from TradeFx to Hud
-- The last `trade` payload while a trade is live (nil after done or cancelled closes the panel).
ClientState.tradeState = nil :: any
-- Highlights on screen across CreatureFx, BedFx and the reveal; Roblox draws about 31 at once.
ClientState.HIGHLIGHT_BUDGET = 26
ClientState.highlights = 0
-- Owners with a hatch reveal running (FollowerFx hides their follower meanwhile).
ClientState.revealing = {} :: { [number]: number }

ClientState.menuOpen = true
ClientState.racing = false -- this client is in a running Splash Dash round
-- The egg the ODDS card shows (nil: every egg and weather).
ClientState.oddsEgg = nil :: string?
-- Creatures whose model stays hidden until their reveal ends (read by CreatureFx on spawn), keyed
-- "<owner UserId>:<creature id>": ids are per profile, so every garden has a creature 1.
ClientState.hidden = {} :: { [string]: boolean }

function ClientState.set(key: string, value: boolean)
	(ClientState.settings :: any)[key] = value
	settingsChanged:Fire(key)
end

function ClientState.reveal(owner: any, id: number, hidden: boolean)
	local key = `{owner}:{id}`
	ClientState.hidden[key] = if hidden then true else nil
	local n = tonumber(owner) or 0
	ClientState.revealing[n] = math.max(0, (ClientState.revealing[n] or 0) + (if hidden then 1 else -1))
	revealing:Fire(key, hidden)
end

function ClientState.setTrade(payload: any)
	ClientState.tradeState = payload
	tradeChanged:Fire(payload)
end

function ClientState.toast(message: string, colour: Color3?, icon: string?)
	toasted:Fire(message, colour, icon)
end

function ClientState.setMenu(open: boolean)
	ClientState.menuOpen = open
	menuChanged:Fire(open)
end

function ClientState.open(panel: string)
	openRequested:Fire(panel)
end

function ClientState.setRacing(racing: boolean)
	ClientState.racing = racing
	racingChanged:Fire(racing)
end

function ClientState.json(value: any): any
	if type(value) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value)
	return if ok then decoded else nil
end

-- GardenStatus ----------------------------------------------------------------------------------

local statusValue = ReplicatedStorage:WaitForChild("GardenStatus") :: StringValue
ClientState.statusValue = statusValue
local cachedRaw: string? = nil
local function dashOf(d: any): DashStatus
	local dash = if type(d) == "table" then d else {}
	return {
		phase = if type(dash.phase) == "string" then dash.phase else "idle",
		ready = if type(dash.ready) == "table" then dash.ready else {},
		need = tonumber(dash.need) or GardenConfig.DASH.minPlayers,
		at = tonumber(dash.at) or 0,
		goAt = tonumber(dash.goAt) or 0,
		racers = if type(dash.racers) == "table" then dash.racers else {},
	}
end
local function eventOf(e: any): EventStatus
	local ev = if type(e) == "table" then e else {}
	return {
		weather = if type(ev.weather) == "string" then ev.weather else "clear",
		startsAt = tonumber(ev.startsAt) or 0,
		endsAt = tonumber(ev.endsAt) or 0,
		active = ev.active == true,
	}
end
local cached: Status = {
	weather = "clear",
	weatherLeft = 0,
	forecast = {},
	stockLeft = 0,
	stockWindow = 0,
	dash = dashOf(nil),
	event = eventOf(nil),
}
local cachedAt = os.clock()

function ClientState.status(): Status
	local raw = statusValue.Value
	if raw ~= cachedRaw then
		cachedRaw = raw
		cachedAt = os.clock()
		local d = ClientState.json(raw)
		if type(d) == "table" then
			cached = {
				weather = if type(d.weather) == "string" then d.weather else "clear",
				weatherLeft = tonumber(d.weatherLeft) or 0,
				forecast = if type(d.forecast) == "table" then d.forecast else {},
				stockLeft = tonumber(d.stockLeft) or 0,
				stockWindow = tonumber(d.stockWindow) or 0,
				dash = dashOf(d.dash),
				event = eventOf(d.event),
			}
		end
	end
	return cached
end

-- Seconds left on a GardenStatus countdown, ticked down locally between the 1 Hz writes.
function ClientState.left(seconds: number): number
	return math.max(0, math.ceil(seconds - (os.clock() - cachedAt)))
end

-- Profiles ----------------------------------------------------------------------------------------

local profiles: { [Player]: { raw: string, profile: any } } = {}

-- Any player's sanitised profile from their `Profile` attribute (nil until the server sets it).
function ClientState.profileOf(p: Player?): any
	if not p then
		return nil
	end
	local raw = p:GetAttribute("Profile")
	if type(raw) ~= "string" then
		return nil
	end
	local entry = profiles[p]
	if entry and entry.raw == raw then
		return entry.profile
	end
	local decoded = ClientState.json(raw)
	if decoded == nil then
		return if entry then entry.profile else nil
	end
	local profile = GardenProgress.sanitize(decoded)
	profiles[p] = { raw = raw, profile = profile }
	return profile
end
Players.PlayerRemoving:Connect(function(p)
	profiles[p] = nil
end)

function ClientState.profile(): any
	local profile = ClientState.profileOf(Players.LocalPlayer) or GardenProgress.defaults(0)
	-- Banking updates only `Coins`; the full profile follows later (QA N1).
	local coins = tonumber(Players.LocalPlayer:GetAttribute("Coins"))
	if coins then
		profile.coins = coins
	end
	return profile
end

function ClientState.now(): number
	return Workspace:GetServerTimeNow()
end

-- Plots -------------------------------------------------------------------------------------------

-- Plot n frame (section 4.4): local -Z faces the plaza, the gate is at local z = -30.
function ClientState.plotFrame(n: number): CFrame
	local theta = math.rad((n - 1) * 60)
	local centre = Vector3.new(100 * math.sin(theta), 0, -100 * math.cos(theta))
	return CFrame.lookAt(centre, Vector3.zero)
end

function ClientState.plotAt(pos: Vector3): number?
	for n = 1, 6 do
		local l = ClientState.plotFrame(n):PointToObjectSpace(pos)
		if math.abs(l.X) <= 30 and math.abs(l.Z) <= 30 then
			return n
		end
	end
	return nil
end

function ClientState.plotModel(n: number): Model?
	local plots = Workspace:FindFirstChild("Garden") and (Workspace :: any).Garden:FindFirstChild("Plots")
	return plots and plots:FindFirstChild(`Plot{n}`)
end

-- The camera pose at the end of the PLAY fly; mirrors Plots.gateLook (architecture 4.7): 12 studs
-- outside the gate along the plot's facing, 6 up, looking at the plot centre at eye height.
function ClientState.gateLook(n: number): CFrame
	local frame = ClientState.plotFrame(n)
	return CFrame.lookAt(frame:PointToWorldSpace(Vector3.new(0, 6, -42)), frame:PointToWorldSpace(Vector3.new(0, 5, 0)))
end

function ClientState.ownerOf(n: number): Player?
	local model = ClientState.plotModel(n)
	local owner = model and model:GetAttribute("Owner")
	return if type(owner) == "number" and owner > 0 then Players:GetPlayerByUserId(owner) else nil
end

ClientState.CART = Vector3.new(0, 0, 30)
ClientState.MEADOW_GATE = Vector3.new(-30, 0, 15)

-- Formatting --------------------------------------------------------------------------------------

function ClientState.commas(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""):gsub("^%-,", "-"))
end

function ClientState.short(n: number): string
	return GardenRules.short(math.floor(n))
end

function ClientState.clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	if s >= 3600 then
		return string.format("%d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

function ClientState.colour(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

function ClientState.rarityColour(species: string): Color3
	local r = GardenConfig.RARITIES[GardenConfig.rarityIndex(species)]
	return if r then ClientState.colour(r.colour) else Color3.fromRGB(200, 200, 200)
end

function ClientState.rarityName(species: string): string
	local r = GardenConfig.RARITIES[GardenConfig.rarityIndex(species)]
	return if r then r.name else ""
end

-- "Frosted Big Golden Berry Cat" (Normal size, mutation and no charm are left out), or
-- "Sprinkles the Berry Cat" when the creature has a pet name (GDD V5).
function ClientState.creatureName(s: string, m: string, z: string, c: string?, n: string?): string
	local sp, mu, sz = GardenConfig.species(s), GardenConfig.mutation(m), GardenConfig.size(z)
	if n and n ~= "" then
		return `{n} the {if sp then sp.name else s}`
	end
	local parts = {}
	local ch = if c then GardenConfig.charm(c) else nil
	if ch then
		table.insert(parts, ch.name)
	end
	if sz and z ~= "normal" then
		table.insert(parts, sz.name)
	end
	if mu and m ~= "normal" then
		table.insert(parts, mu.name)
	end
	table.insert(parts, if sp then sp.name else s)
	return table.concat(parts, " ")
end

function ClientState.charmName(id: string?): string
	local c = if id then GardenConfig.charm(id) else nil
	return if c then c.name else ""
end

ClientState.CHARM_COLOURS = {
	frosted = Color3.fromRGB(170, 220, 255),
	blooming = Color3.fromRGB(255, 150, 190),
	stormy = Color3.fromRGB(110, 100, 160),
} :: { [string]: Color3 }

-- The player's milestone title (GDD V4), nil for none.
function ClientState.title(p: any): string?
	return if p then GardenProgress.title(p) else nil
end

function ClientState.weatherName(id: string): string
	for _, w in GardenConfig.WEATHERS do
		if w.id == id then
			return w.name
		end
	end
	return "Clear"
end

-- Display egg colours (GDD I2): top and bottom of each shell.
ClientState.EGG_COLOURS = {
	starter = { Color3.fromRGB(255, 240, 210), Color3.fromRGB(255, 190, 200) },
	meadow = { Color3.fromRGB(200, 245, 190), Color3.fromRGB(150, 220, 150) },
	forest = { Color3.fromRGB(120, 170, 90), Color3.fromRGB(110, 85, 60) },
	sunset = { Color3.fromRGB(255, 170, 80), Color3.fromRGB(255, 120, 170) },
	moon = { Color3.fromRGB(60, 70, 140), Color3.fromRGB(30, 30, 80) },
	star = { Color3.fromRGB(255, 252, 235), Color3.fromRGB(255, 205, 90) },
	celestial = { Color3.fromRGB(255, 246, 205), Color3.fromRGB(170, 150, 255) },
	aurora = { Color3.fromRGB(60, 130, 150), Color3.fromRGB(80, 50, 140) },
	weekly = { Color3.fromRGB(255, 225, 236), Color3.fromRGB(255, 150, 190) }, -- blossom pink (GDD X3.3)
	monthly = { Color3.fromRGB(70, 175, 175), Color3.fromRGB(25, 90, 110) }, -- deep teal
} :: { [string]: { Color3 } }

-- The pale white-gold of everything Celestial (GDD S5).
ClientState.CELESTIAL = Color3.fromRGB(255, 236, 170)

-- Prize eggs held at or under the player's level (the DASH badge, GDD T8 and X1.4).
function ClientState.prizeCount(p: any): number
	local n = 0
	local level = GardenRules.level(p)
	for id, count in p.prizeEggs do
		local egg = GardenConfig.egg(id)
		if egg and egg.level <= level then
			n += count
		end
	end
	return n
end

-- Login slots claimable now plus finished, unclaimed quests (the REWARDS badge, X1.4, X3.5).
function ClientState.rewardsCount(p: any): number
	local day = MetaRules.dayOf(ClientState.now())
	local n = LoginRules.claimable(p, day)
	if p.quests.day ~= day then
		return n
	end
	for _, q in GardenProgress.questsFor(day) do
		if not p.quests.claimed[q.id] and (p.quests.progress[q.stat] or 0) >= q.goal then
			n += 1
		end
	end
	return n
end

ClientState.WEATHER_COLOURS = {
	clear = Color3.fromRGB(120, 200, 255),
	sunbeam = Color3.fromRGB(255, 205, 90),
	moonfall = Color3.fromRGB(130, 120, 230),
	shower = Color3.fromRGB(255, 130, 200),
	snowfall = Color3.fromRGB(190, 225, 255),
	petals = Color3.fromRGB(255, 170, 205),
	thunder = Color3.fromRGB(110, 100, 160),
} :: { [string]: Color3 }

-- Followers (GDD V3) --------------------------------------------------------------------------------

export type FollowerState = {
	pos: Vector3,
	yaw: number,
	scale: number,
	half: number, -- half the follower's footprint: the gaps are measured from its edge
	hopFrom: Vector3?,
	hopTo: Vector3?,
	hopAt: number,
}
-- Beside the owner, not behind: trailing on the walk line put a Big or Huge one between the
-- camera and the character (QA M3). Hops of up to far * 1.5 per `hop` s outrun a 16 studs/s walk.
ClientState.FOLLOWER = { behind = 1, side = 4, far = 6, snap = 60, hop = 0.35, cryGap = 6 }

-- Where the follower stands: `side` studs beside and `behind` studs behind the owner's root,
-- counted from the follower's edge so a Huge one stands clear of the camera line.
function ClientState.followerOffset(half: number): Vector3
	local F = ClientState.FOLLOWER
	return Vector3.new(F.side + half, -2.5, F.behind + half)
end

-- One frame of follower pacing: the target sits behind and beside the owner's root; farther than
-- `far` it hops there (parabola, chained while far), nearer it idles with a bob, past `snap` it
-- teleports. Returns the CFrame to draw and true on the frame a hop starts.
function ClientState.followerStep(f: FollowerState, ownerRoot: CFrame, t: number): (CFrame, boolean)
	local F = ClientState.FOLLOWER
	local target = ownerRoot:PointToWorldSpace(ClientState.followerOffset(f.half))
	local started = false
	if (target - f.pos).Magnitude > F.snap then
		f.pos, f.hopFrom, f.hopTo = target, nil, nil
	end
	if f.hopTo then
		local k = math.clamp((t - f.hopAt) / F.hop, 0, 1)
		local flat = (f.hopFrom :: Vector3):Lerp(f.hopTo :: Vector3, k)
		local pos = flat + Vector3.new(0, math.sin(k * math.pi) * 1.5 * f.scale, 0)
		if k >= 1 then
			f.pos, f.hopFrom, f.hopTo = f.hopTo :: Vector3, nil, nil
		else
			return CFrame.new(pos) * CFrame.Angles(0, f.yaw, 0), false
		end
	end
	local gap = target - f.pos
	if gap.Magnitude > F.far then
		local step = gap.Unit * math.min(gap.Magnitude, F.far * 1.5)
		f.hopFrom, f.hopTo, f.hopAt = f.pos, f.pos + step, t
		f.yaw = math.atan2(-step.X, -step.Z)
		started = true
	end
	local bob = math.sin(t * 2 + f.pos.X) * 0.12
	return CFrame.new(f.pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, f.yaw, 0), started
end

-- Sounds ------------------------------------------------------------------------------------------

-- One-shot sound, 2D or at a world position; silent when sound effects are off.
function ClientState.sound(id: string, volume: number, at: Vector3?, pitch: number?)
	if not ClientState.settings.sfx then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = pitch or 1
	local holder: Instance = SoundService
	if at then
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = Workspace.Terrain
		holder = a
		s.RollOffMinDistance = 20
		s.RollOffMaxDistance = 200
	end
	s.Parent = holder
	local function done()
		if s.Parent then
			(if holder == SoundService then s else holder):Destroy()
		end
	end
	s.Ended:Once(done)
	s:Play()
	task.delay(8, done)
end

-- A species' cry (GDD U7, architecture 6.1): the only caller of its registered clip. Silent when the
-- species has no cry; `at` nil plays 2D.
function ClientState.cry(species: string, volume: number, at: Vector3?)
	local sp = GardenConfig.species(species)
	local cry = sp and sp.cry
	if cry then
		ClientState.sound(`rbxassetid://{cry.id}`, volume, at, cry.pitch)
	end
end

-- An idle or hop cry (6.1, V3): at most one per 2 s across the garden; false when it stayed quiet.
local lastIdleCry = -math.huge
function ClientState.idleCry(species: string, at: Vector3): boolean
	local now = os.clock()
	if now - lastIdleCry < 2 then
		return false
	end
	lastIdleCry = now
	ClientState.cry(species, 0.2, at)
	return true
end

-- One-shot particle burst at a point (default sparkle texture).
function ClientState.burst(at: Vector3, colour: Color3, count: number, speed: number, size: number?)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = Workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(colour, Color3.new(1, 1, 1))
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size or 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new(0, 0.4)
	e.Lifetime = NumberRange.new(0.5, 1.1)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -12, 0)
	e.LightEmission = 0.7
	e.Rate = 0
	e.Parent = a
	e:Emit(count)
	task.delay(1.5, a.Destroy, a)
end

-- Registered licensed SFX (docs/assets/register.md), pitched for a soft garden feel. No slot sounds.
ClientState.SFX = {
	tick = "rbxassetid://9117060347", -- beep: coin pickups (pitched up), timers
	chime = "rbxassetid://9125585534", -- gong: reveal chimes, rising in pitch with rarity
	fanfare = "rbxassetid://1848287237", -- APM acoustic tag: Legendary and Mythic reveals, level up
	sting = "rbxassetid://9048769919", -- APM mallet hit: Sunbeam, Moonfall and Rainbow Shower start
	whoosh = "rbxassetid://9114373663", -- wobble, pop, run-off
	puff = "rbxassetid://9125442175", -- shell crack, splash
	thud = "rbxasset://sounds/action_jump_land.mp3",
}

-- UI kit ------------------------------------------------------------------------------------------

-- Pastel garden palette (distinct from Night's dark red).
ClientState.UI = {
	CREAM = Color3.fromRGB(255, 249, 236),
	PANEL = Color3.fromRGB(255, 244, 228),
	CARD = Color3.fromRGB(255, 255, 255),
	INK = Color3.fromRGB(74, 58, 72),
	MUTED = Color3.fromRGB(140, 122, 132),
	MINT = Color3.fromRGB(122, 214, 160),
	LEAF = Color3.fromRGB(70, 170, 110),
	PINK = Color3.fromRGB(255, 150, 185),
	SKY = Color3.fromRGB(130, 200, 255),
	LILAC = Color3.fromRGB(190, 160, 240),
	GOLD = Color3.fromRGB(255, 196, 64),
	CORAL = Color3.fromRGB(255, 120, 110),
	AQUA = Color3.fromRGB(70, 190, 205),
	GREY = Color3.fromRGB(205, 198, 200),
	WHITE = Color3.new(1, 1, 1),
	-- v0.5 (GDD X1.1)
	SHADOW = Color3.fromRGB(60, 45, 70), -- drawn at transparency 0.78
	INK_SOFT = Color3.fromRGB(120, 100, 120),
	BADGE = Color3.fromRGB(255, 120, 110), -- = CORAL
	RING = Color3.fromRGB(255, 236, 170),
	GLASS = 0.35, -- white at this transparency: HUD chips over the world
}
local UI = ClientState.UI

-- The 3D bottom edge of a button: the colour darkened 25% toward INK (X1.1).
function ClientState.edge(colour: Color3): Color3
	return colour:Lerp(UI.INK, 0.25)
end

-- Header ribbon and strip colour per panel (X1.1).
ClientState.ACCENT = {
	Eggs = UI.GOLD,
	Creatures = UI.SKY,
	Index = UI.LEAF,
	Locker = UI.LILAC,
	Rewards = UI.CORAL,
	Stats = UI.SKY,
	Dash = UI.AQUA,
	Settings = UI.LILAC,
	Trade = UI.PINK,
	Admin = UI.CORAL,
	Patch = UI.PINK,
} :: { [string]: Color3 }

function ClientState.new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local new = ClientState.new

function ClientState.corner(radius: number): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function ClientState.stroke(colour: Color3, thickness: number): UIStroke
	return new("UIStroke", { Color = colour, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function ClientState.text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or UI.INK
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	return new("TextLabel", props)
end

-- A UiKit 3D button for the files not yet on the kit (architecture 6.4); required lazily because
-- UiKit requires this module.
function ClientState.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local UiKit = require(script.Parent:WaitForChild("UiKit")) :: any
	local b = UiKit.button(nil, props.Text or "", props.BackgroundColor3 or UI.PINK, "medium", 160, onClick)
	for _, key in { "AnchorPoint", "Position", "Size", "LayoutOrder", "Visible", "Name" } do
		if props[key] ~= nil then
			b[key] = props[key]
		end
	end
	b.Parent = props.Parent
	return b
end

-- Small bounce on a GuiObject (coin counter pulse, new toast); none with the Reduce Motion setting.
function ClientState.pop(target: GuiObject)
	if GuiService.ReducedMotionEnabled then
		return
	end
	local scale = target:FindFirstChild("Pop") :: UIScale?
	if not scale then
		scale = new("UIScale", { Name = "Pop", Parent = target })
	end
	local s = scale :: UIScale
	s.Scale = 1.18
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- UI scale for phones: layouts are drawn for a 1100 x 620 screen and scaled to fit.
function ClientState.autoScale(target: GuiObject)
	local scale = Instance.new("UIScale")
	local function fit()
		local view = Workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(view.X / 1100, view.Y / 620), 0.6, 1.25)
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	scale.Parent = target
end

return ClientState
