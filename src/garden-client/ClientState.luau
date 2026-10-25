--!strict
-- Egg Garden client-only state (docs/architecture/garden.md section 6): settings that never reach
-- the server, signals between the client scripts (reveal hiding, toasts, menu open), read-only
-- parsers for GardenStatus and Profile attributes, one-shot sounds and the shared pastel UI kit.

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
local MetaRules = require(Shared:WaitForChild("MetaRules"))

local ClientState = {}

export type Settings = { music: boolean, sfx: boolean, fastHatch: boolean, announcements: boolean }
export type Status = {
	weather: string,
	weatherLeft: number,
	forecast: { string },
	stockLeft: number,
	stockWindow: number,
}

ClientState.settings = { music = true, sfx = true, fastHatch = false, announcements = true } :: Settings

local settingsChanged = Instance.new("BindableEvent")
ClientState.SettingsChanged = settingsChanged.Event
local revealing = Instance.new("BindableEvent")
ClientState.Revealing = revealing.Event -- (id: number, hidden: boolean) from HatchFx to CreatureFx
local toasted = Instance.new("BindableEvent")
ClientState.Toasted = toasted.Event -- (text: string, colour: Color3?) rendered by Menu
local menuChanged = Instance.new("BindableEvent")
ClientState.MenuChanged = menuChanged.Event -- (open: boolean)
local openRequested = Instance.new("BindableEvent")
ClientState.OpenRequested = openRequested.Event -- (panel: string) HUD buttons ask Menu to open a panel

ClientState.menuOpen = true
-- The egg the ODDS card shows (nil: every egg and weather).
ClientState.oddsEgg = nil :: string?
-- Creature ids whose model stays hidden until their reveal ends (read by CreatureFx on spawn).
ClientState.hidden = {} :: { [number]: boolean }

function ClientState.set(key: string, value: boolean)
	(ClientState.settings :: any)[key] = value
	settingsChanged:Fire(key)
end

function ClientState.reveal(id: number, hidden: boolean)
	ClientState.hidden[id] = if hidden then true else nil
	revealing:Fire(id, hidden)
end

function ClientState.toast(message: string, colour: Color3?)
	toasted:Fire(message, colour)
end

function ClientState.setMenu(open: boolean)
	ClientState.menuOpen = open
	menuChanged:Fire(open)
end

function ClientState.open(panel: string)
	openRequested:Fire(panel)
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
local cached: Status = { weather = "clear", weatherLeft = 0, forecast = {}, stockLeft = 0, stockWindow = 0 }
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
	return ClientState.profileOf(Players.LocalPlayer) or GardenProgress.defaults(0)
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

-- "Big Golden Berry Cat" (Normal size and mutation are left out).
function ClientState.creatureName(s: string, m: string, z: string): string
	local sp, mu, sz = GardenConfig.species(s), GardenConfig.mutation(m), GardenConfig.size(z)
	local parts = {}
	if sz and z ~= "normal" then
		table.insert(parts, sz.name)
	end
	if mu and m ~= "normal" then
		table.insert(parts, mu.name)
	end
	table.insert(parts, if sp then sp.name else s)
	return table.concat(parts, " ")
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
} :: { [string]: { Color3 } }

-- True when a daily, weekly or quest reward can be claimed now (the gold dot).
function ClientState.rewardsReady(p: any): boolean
	local day = MetaRules.dayOf(ClientState.now())
	if MetaRules.nextDaily(p, day) ~= nil or MetaRules.canClaimWeekly(GardenProgress.CONFIG, p, day) then
		return true
	end
	if p.quests.day ~= day then
		return false
	end
	for _, q in GardenProgress.questsFor(day) do
		if not p.quests.claimed[q.id] and (p.quests.progress[q.stat] or 0) >= q.goal then
			return true
		end
	end
	return false
end

ClientState.WEATHER_COLOURS = {
	clear = Color3.fromRGB(120, 200, 255),
	sunbeam = Color3.fromRGB(255, 205, 90),
	moonfall = Color3.fromRGB(130, 120, 230),
	shower = Color3.fromRGB(255, 130, 200),
} :: { [string]: Color3 }

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

-- Registered licensed SFX (docs/assets/register.md), pitched for a soft garden feel. No slot sounds.
ClientState.SFX = {
	tick = "rbxassetid://9117060347", -- beep: coin pickups (pitched up), timers
	chime = "rbxassetid://9125585534", -- gong: reveal chimes, rising in pitch with rarity
	fanfare = "rbxassetid://9114630316", -- resonant gong: Legendary and Mythic reveals, stingers
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
	GREY = Color3.fromRGB(205, 198, 200),
	WHITE = Color3.new(1, 1, 1),
}
local UI = ClientState.UI

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

-- Chunky rounded button with a soft press bounce; works with mouse, touch and gamepad selection.
function ClientState.button(props: { [string]: any }, onClick: () -> ()): TextButton
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or UI.WHITE
	props.TextScaled = true
	props.AutoButtonColor = true
	props.BackgroundColor3 = props.BackgroundColor3 or UI.PINK
	local b = new("TextButton", props, {
		ClientState.corner(12),
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
		ClientState.stroke(UI.WHITE, 2),
	})
	b.Activated:Connect(function()
		ClientState.sound(ClientState.SFX.tick, 0.15, nil, 2.2)
		onClick()
	end)
	return b
end

-- Small bounce on a GuiObject (coin counter pulse, new toast).
function ClientState.pop(target: GuiObject)
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
