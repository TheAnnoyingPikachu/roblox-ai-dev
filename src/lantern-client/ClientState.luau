--!strict
-- Lantern Express client state (architecture lantern 6): the Lantern theme for the shared UiKit
-- (art bible 7), readers for the server's LanternRun and player attributes (decision 0018 section
-- 3), `request` with the refusal texts, sounds from registered ids only, rarity colours (GDD C7),
-- models from LanternAssets with part fallbacks, and the train and stop frames rebuilt from the
-- replicated distance. Display only: nothing here decides an outcome.

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanternConfig = require(Shared:WaitForChild("LanternConfig"))
local LanternProgress = require(Shared:WaitForChild("LanternProgress"))
local TrackRules = require(Shared:WaitForChild("TrackRules"))
local UiKit = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("UiKit"))

local ClientState = {}
local player = Players.LocalPlayer

-- Optional generated modules (LANTERN-011): nil ids until uploaded, so code never waits for art.
local function optional(name: string): any
	local m = Shared:FindFirstChild(name)
	return if m then require(m :: ModuleScript) else {}
end
local LanternAssets = optional("LanternAssets")
local LanternIcons = optional("LanternIcons")

-- Theme (art bible 7: Garden token names, Lantern values) ---------------------------------------

local UI = {
	CREAM = Color3.fromRGB(255, 243, 222),
	PANEL = Color3.fromRGB(250, 234, 206),
	CARD = Color3.fromRGB(255, 250, 240),
	INK = Color3.fromRGB(52, 40, 78),
	INK_SOFT = Color3.fromRGB(100, 86, 120),
	MUTED = Color3.fromRGB(128, 112, 140),
	GOLD = Color3.fromRGB(255, 176, 64),
	RING = Color3.fromRGB(255, 226, 150),
	CORAL = Color3.fromRGB(196, 52, 62),
	BADGE = Color3.fromRGB(196, 52, 62),
	AQUA = Color3.fromRGB(62, 128, 140),
	MINT = Color3.fromRGB(120, 170, 110),
	LEAF = Color3.fromRGB(84, 140, 96),
	SKY = Color3.fromRGB(90, 160, 230),
	LILAC = Color3.fromRGB(170, 120, 230),
	PINK = Color3.fromRGB(255, 150, 170),
	GREY = Color3.fromRGB(200, 192, 205),
	WHITE = Color3.new(1, 1, 1),
	SHADOW = Color3.fromRGB(30, 22, 48),
	GLASS = 0.35,
	CHIP = Color3.fromRGB(52, 40, 78), -- dark glass HUD chips with cream text
	CHIP_TEXT = Color3.fromRGB(255, 243, 222),
	CHIP_LINE = Color3.fromRGB(255, 226, 150),
	RING_FILL = Color3.fromRGB(255, 176, 64),
	ROW_LINE = Color3.fromRGB(236, 214, 180),
	BAR_BACK = Color3.fromRGB(236, 222, 200),
	SILHOUETTE = Color3.fromRGB(52, 40, 78),
	FOG = Color3.fromRGB(190, 180, 210), -- Fog Lilac
	DUSK = Color3.fromRGB(58, 44, 110), -- Dusk Violet
}
ClientState.UI = UI
ClientState.ACCENT = {
	Album = UI.MINT,
	Locker = UI.LILAC,
	Rewards = UI.CORAL,
	Board = UI.AQUA,
	Settings = UI.INK_SOFT,
	Depot = UI.GOLD,
} :: { [string]: Color3 }

-- Settings (client only) ---------------------------------------------------------------------------

ClientState.settings = { music = 0.6, sfx = 0.8, calm = false }
local settingsChanged = Instance.new("BindableEvent")
ClientState.SettingsChanged = settingsChanged.Event

function ClientState.set(key: string, value: any)
	(ClientState.settings :: any)[key] = value
	settingsChanged:Fire(key)
end

function ClientState.still(): boolean
	return GuiService.ReducedMotionEnabled
end

-- Sounds: only registered licensed ids (docs/assets/register.md). nil plays nothing; LANTERN-011
-- registers the whistle, chuff, bell, music and the rest of GDD M.
ClientState.SFX = {
	tick = "rbxassetid://9117060347", -- ProSoundEffects beep, pitched up (UI)
	chime = "rbxassetid://9125585534", -- ProSoundEffects gong: rescue chimes, rising with rarity
	whoosh = "rbxassetid://9114373663", -- ProSoundEffects pass-by whoosh: the fog front
	puff = "rbxassetid://9125442175", -- ProSoundEffects cloth whoosh: a wisp puffs
	whistle = nil :: string?,
	bell = nil :: string?,
	chuff = nil :: string?,
	glug = nil :: string?,
	music = nil :: string?,
} :: { [string]: string? }

function ClientState.sound(name: string, volume: number, at: Vector3?, pitch: number?): Sound?
	local id = ClientState.SFX[name]
	if id == nil or ClientState.settings.sfx <= 0 then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume * ClientState.settings.sfx
	s.PlaybackSpeed = pitch or 1
	local holder: Instance = SoundService
	if at then
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = Workspace.Terrain
		holder = a
	end
	s.Parent = holder
	s.Ended:Once(function()
		(if holder == SoundService then s else holder):Destroy()
	end)
	s:Play()
	return s
end

-- Remotes (decision 0018 section 3) ----------------------------------------------------------------

local remotes = ReplicatedStorage:WaitForChild("LanternRemotes")
ClientState.Fx = remotes:WaitForChild("Fx") :: RemoteEvent
local requestFn = remotes:WaitForChild("Request") :: RemoteFunction

-- Refusal codes to text (the client never decides; it only explains the server's answer).
ClientState.CODES = {
	loading = "Still loading your save...",
	rate = "One moment...",
	phase = "Not right now",
	seat = "No free seat of that kind",
	far = "Too far away",
	full = "No room for that",
	coal = "Not enough coal",
	oil = "No oil cans left",
	parts = "Not enough Parts",
	max = "Already at the top level",
	cooldown = "Just a moment...",
	owned = "Already yours",
	locked = "Not unlocked yet",
	tickets = "Not enough Tickets",
	refused = "Not right now",
} :: { [string]: string }

-- Signals between the client scripts.
ClientState.menuOpen = true
ClientState.wheelOpen = false -- the ping wheel is up (PingWheel)
local menuChanged = Instance.new("BindableEvent")
ClientState.MenuChanged = menuChanged.Event -- (open: boolean) the start menu is up
function ClientState.setMenu(open: boolean)
	ClientState.menuOpen = open
	menuChanged:Fire(open)
end
local pinged = Instance.new("BindableEvent")
ClientState.Pinged = pinged.Event -- (userId, ping id) for the crew list
ClientState.ping = function(userId: number, id: string)
	pinged:Fire(userId, id)
end

local toasted = Instance.new("BindableEvent")
ClientState.Toasted = toasted.Event -- (text, icon?, colour?) drawn by Hud
function ClientState.toast(text: string, icon: string?, colour: Color3?)
	toasted:Fire(text, icon, colour)
end

-- Sends one request; a refusal shows its text. Returns the server's answer.
function ClientState.request(action: string, arg: string?): (boolean, string?)
	local ok, result, code = pcall(requestFn.InvokeServer, requestFn, action, arg)
	if not ok then
		ClientState.toast("Could not reach the server", "notice", UI.CORAL)
		return false, "error"
	end
	if result ~= true and type(code) == "string" and ClientState.CODES[code] then
		ClientState.toast(ClientState.CODES[code], "notice", UI.CORAL)
	end
	return result == true, code
end

function ClientState.json(value: any): any
	if type(value) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value)
	return if ok then decoded else nil
end

function ClientState.now(): number
	return Workspace:GetServerTimeNow()
end

-- The run (ReplicatedStorage.LanternRun attributes) ---------------------------------------------------

local runFolder = ReplicatedStorage:WaitForChild("LanternRun")
local runChanged = Instance.new("BindableEvent")
ClientState.RunChanged = runChanged.Event -- (attribute name)
runFolder.AttributeChanged:Connect(function(name)
	runChanged:Fire(name)
end)

export type Run = { [string]: any }
function ClientState.run(): Run
	local r = runFolder:GetAttributes()
	r.Crew = ClientState.json(r.Crew) or {}
	r.Votes = ClientState.json(r.Votes) or {}
	r.Phase = r.Phase or "hub"
	return r
end

function ClientState.inCrew(): boolean
	for _, m in ClientState.run().Crew do
		if m.userId == player.UserId then
			return true
		end
	end
	return false
end

-- The player's own save (the server-written Profile attribute), sanitised so every field exists.
function ClientState.profileOf(p: Player): LanternProgress.Profile
	return LanternProgress.sanitize(ClientState.json(p:GetAttribute("Profile")) or {}, ClientState.now())
end
function ClientState.profile(): LanternProgress.Profile
	return ClientState.profileOf(player)
end

-- Rarity and names (GDD C7, H4) ---------------------------------------------------------------------

function ClientState.colour(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

function ClientState.rarityOf(species: string): string
	local c = LanternConfig.critter(species)
	return if c then c.rarity else "common"
end

function ClientState.rarityColour(species: string): Color3
	local rarity = if (LanternConfig.RARITY_COLOURS :: any)[species] then species else ClientState.rarityOf(species)
	local rgb = (LanternConfig.RARITY_COLOURS :: any)[rarity]
	return if rgb then ClientState.colour(rgb) else UI.GOLD -- the exclusive Ember Kit: amber
end

function ClientState.rarityName(species: string): string
	local r = if (LanternConfig.RARITY_COLOURS :: any)[species] then species else ClientState.rarityOf(species)
	return string.upper(string.sub(r, 1, 1)) .. string.sub(r, 2)
end

function ClientState.critterName(species: string): string
	local c = LanternConfig.critter(species)
	return if c then c.name else species
end

function ClientState.short(n: number): string
	n = math.floor(n)
	if n >= 1e6 then
		return (string.format("%.1fM", n / 1e6):gsub("%.0M", "M"))
	elseif n >= 1e4 then
		return (string.format("%.1fK", n / 1e3):gsub("%.0K", "K"))
	end
	local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end

-- Models: the uploaded asset when the server has shared it, else parts named like the asset list
-- (architecture 9). The server shares templates in ReplicatedStorage.LanternModels.
function ClientState.model(name: string): Model?
	if LanternAssets[name] == nil or LanternAssets[name].model == nil then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild("LanternModels") or ReplicatedStorage:FindFirstChild("NightModels")
	local template = folder and folder:FindFirstChild(name)
	return if template then template:Clone() :: Model else nil
end

local function ball(model: Model, name: string, size: Vector3, colour: Color3, at: Vector3, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = size
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.CFrame = CFrame.new(at)
	p.Parent = model
	return p
end
ClientState.ball = ball

-- critter_<id> fallback: two balls, two ears and the rarity colour (architecture 9).
function ClientState.critterModel(species: string): Model
	local m = ClientState.model("critter_" .. species)
	if m then
		return m
	end
	local model = Instance.new("Model")
	model.Name = "critter_" .. species
	local colour = ClientState.rarityColour(species)
	ball(model, "Body", Vector3.new(2.2, 2, 2.2), colour:Lerp(UI.CREAM, 0.35), Vector3.new(0, 1, 0))
	ball(model, "Head", Vector3.new(1.7, 1.6, 1.7), colour:Lerp(UI.CREAM, 0.5), Vector3.new(0, 2.4, -0.4))
	ball(model, "EarL", Vector3.new(0.5, 0.9, 0.4), colour, Vector3.new(-0.55, 3.3, -0.4))
	ball(model, "EarR", Vector3.new(0.5, 0.9, 0.4), colour, Vector3.new(0.55, 3.3, -0.4))
	ball(model, "EyeL", Vector3.new(0.3, 0.35, 0.2), UI.INK, Vector3.new(-0.35, 2.5, -1.2))
	ball(model, "EyeR", Vector3.new(0.3, 0.35, 0.2), UI.INK, Vector3.new(0.35, 2.5, -1.2))
	model.PrimaryPart = model:FindFirstChild("Body") :: BasePart
	return model
end

-- Album previews: a client-side folder of one model per species, for UiKit.viewport.
local previews = Instance.new("Folder")
previews.Name = "LanternPreviews"
for _, c in LanternConfig.CRITTERS do
	local m = ClientState.critterModel(c.id)
	m.Name = c.id
	m.Parent = previews
end
previews.Parent = ReplicatedStorage

-- Frames (architecture 2): the train frame from the replicated D and Speed, the stop frame ------------

local paths: { [string]: TrackRules.Path } = {}
function ClientState.trackName(r: Run): string
	local line = if r.Line == "lake" then "lake" else "forest"
	return if (r.Leg or 1) >= 3 then line .. "Dawn" else line
end
local function path(name: string): TrackRules.Path
	if not paths[name] then
		local t = LanternConfig.TRACKS[name]
		paths[name] = TrackRules.build(t.points, t.closed)
	end
	return paths[name]
end

local function v3(p: LanternConfig.Vec3): Vector3
	return Vector3.new(p.x, p.y, p.z)
end
ClientState.v3 = v3
function ClientState.vec(p: any): LanternConfig.Vec3
	if typeof(p) == "Vector3" then
		return { x = p.X, y = p.Y, z = p.Z }
	end
	return { x = tonumber(p and p.x) or 0, y = tonumber(p and p.y) or 0, z = tonumber(p and p.z) or 0 }
end

-- D arrives at 2 Hz: integrate Speed between updates and ease onto each new value.
local smoothD, lastAt = 0, os.clock()
local function step()
	local r = runFolder:GetAttributes()
	local t = os.clock()
	local dt = math.min(t - lastAt, 0.1)
	lastAt = t
	smoothD += (r.Speed or 0) * dt
	local target = r.D or 0
	smoothD = if math.abs(target - smoothD) > 30 then target else smoothD + (target - smoothD) * math.min(1, dt * 3)
end
game:GetService("RunService").RenderStepped:Connect(step)

-- Origin and forward of the train frame now (Vec3s, world).
function ClientState.trainFrame(): (LanternConfig.Vec3, LanternConfig.Vec3)
	return TrackRules.at(path(ClientState.trackName(ClientState.run())), smoothD)
end
function ClientState.toWorld(p: LanternConfig.Vec3): Vector3
	local o, f = ClientState.trainFrame()
	return v3(TrackRules.fromFrame(o, f, p))
end
function ClientState.toTrain(p: Vector3): LanternConfig.Vec3
	local o, f = ClientState.trainFrame()
	return TrackRules.toFrame(o, f, ClientState.vec(p))
end
function ClientState.dirToWorld(d: LanternConfig.Vec3): Vector3
	local _, f = ClientState.trainFrame()
	return v3(TrackRules.fromFrame({ x = 0, y = 0, z = 0 }, f, d))
end

-- shortcut: the platform edge is assumed 14 studs out from the track centre (half the 8-stud train
-- plus the 10-deep platform); replace with the server's stop-site CFrame once LANTERN-006 shares it.
ClientState.STOP_EDGE = 14
-- The stop frame of the current stop as a CFrame whose +Z is the depth into the stop (x along it).
function ClientState.stopFrame(): CFrame?
	local r = ClientState.run()
	local t = LanternConfig.TRACKS[ClientState.trackName(r)]
	local d = t and t.stops[r.Stop or 0]
	if d == nil then
		return nil
	end
	local p, f = TrackRules.at(path(ClientState.trackName(r)), d)
	local out = v3(TrackRules.right(f)) * (LanternConfig.OUTER[r.Line] or -1)
	local origin = v3(p) + out * ClientState.STOP_EDGE
	return CFrame.lookAt(origin, origin - out)
end

-- The UiKit theme ----------------------------------------------------------------------------------

UiKit.configure({
	tokens = UI,
	fonts = { body = Enum.Font.FredokaOne, title = Enum.Font.LuckiestGuy },
	icons = LanternIcons,
	sound = function(name: string, volume: number, pitch: number?)
		ClientState.sound(name, volume, nil, pitch)
	end,
	short = ClientState.short,
	rarity = { colour = ClientState.rarityColour, name = ClientState.rarityName },
	species = ClientState.critterName,
	previews = "LanternPreviews",
	accent = ClientState.ACCENT,
	menu = {
		words = { "LANTERN", "EXPRESS" },
		tagline = "Bring them home before the fog.",
		haze = { UI.DUSK, Color3.fromRGB(40, 30, 80) },
		face = UI.CREAM,
		faceLine = UI.GOLD,
		shade = UI.INK,
		play = UI.GOLD,
		decorate = function(first: Frame)
			-- the small lantern by the logo (art bible 7): an amber glow in a brass ring
			local glow = UiKit.new("Frame", {
				Name = "Lantern",
				Position = UDim2.fromOffset(-58, 30),
				Size = UDim2.fromOffset(40, 52),
				BackgroundColor3 = UI.GOLD,
				ZIndex = 3,
				Parent = first,
			}, {
				UiKit.new("UICorner", { CornerRadius = UDim.new(0.45, 0) }),
				UiKit.new("UIStroke", { Color = UI.CREAM, Thickness = 4 }),
				UiKit.new("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new(Color3.fromRGB(255, 236, 170), UI.GOLD),
				}),
			})
			glow.Rotation = 8
		end,
	},
})
ClientState.UiKit = UiKit

return ClientState
