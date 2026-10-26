--!strict
-- Neon Spire client-only state (docs/architecture/spire.md section 5): settings that never reach
-- the server, the quality tier, the own profile cache, SpireStatus, the build-mode state, the
-- Request wrapper with refusal toasts (section 6.2), lot helpers and the cyberpunk UI kit (art
-- bible section 6). Read by every SpireClient script, including the SPIRE-007 ones.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local SpireConfig = require(Shared:WaitForChild("SpireConfig"))
local SpireEconomy = require(Shared:WaitForChild("SpireEconomy"))
local SpireProgress = require(Shared:WaitForChild("SpireProgress"))
local TowerRules = require(Shared:WaitForChild("TowerRules"))

local remotes = ReplicatedStorage:WaitForChild("SpireRemotes")
local requestRemote = remotes:WaitForChild("Request") :: RemoteFunction

local player = Players.LocalPlayer
local ClientState = {}

ClientState.fx = remotes:WaitForChild("Fx") :: RemoteEvent

-- Settings and quality --------------------------------------------------------------------------

export type Settings = {
	music: boolean,
	sfx: boolean,
	reduceFlashing: boolean,
	rain: string,
	shake: boolean,
	announcements: boolean,
}

local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
ClientState.touch = touch

ClientState.settings = {
	music = true,
	sfx = true,
	reduceFlashing = false,
	rain = if touch then "low" else "med",
	shake = true,
	announcements = true,
} :: Settings

local settingsChanged = Instance.new("BindableEvent")
ClientState.SettingsChanged = settingsChanged.Event

function ClientState.set(key: string, value: any)
	(ClientState.settings :: any)[key] = value
	settingsChanged:Fire()
end

ClientState.quality = if touch then "low" else "high"
local qualityChanged = Instance.new("BindableEvent")
ClientState.QualityChanged = qualityChanged.Event

-- Drops one tier when the 5 s average frame time is over 33 ms (never raises it again).
do
	local total, frames = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		total += dt
		frames += 1
		if total >= 5 then
			local slow = total / frames > 0.033
			total, frames = 0, 0
			if slow and ClientState.quality ~= "low" then
				ClientState.quality = if ClientState.quality == "high" then "med" else "low"
				qualityChanged:Fire()
			end
		end
	end)
end

-- Signals between the client scripts ---------------------------------------------------------------

local toastEvent = Instance.new("BindableEvent")
ClientState.Toast = toastEvent.Event -- (text: string, colour: Color3?) rendered by Menu

function ClientState.toast(text: string, colour: Color3?)
	toastEvent:Fire(text, colour)
end

local menuChanged = Instance.new("BindableEvent")
ClientState.MenuChanged = menuChanged.Event -- (open: boolean)
ClientState.menuOpen = true

function ClientState.setMenu(open: boolean)
	ClientState.menuOpen = open
	menuChanged:Fire(open)
end

local openRequested = Instance.new("BindableEvent")
ClientState.OpenRequested = openRequested.Event -- (panel: string) asks Menu to open a panel

function ClientState.open(panel: string)
	openRequested:Fire(panel)
end

local liftRequested = Instance.new("BindableEvent")
ClientState.LiftRequested = liftRequested.Event -- (target: string?) nil opens the lift panel

function ClientState.lift(target: string?)
	liftRequested:Fire(target)
end

-- Build mode: "play" | "tower" | "plaza"; focusFloor is the floor highlighted in tower view (floor
-- 2 when build mode opens: the guided first rack of K5).
ClientState.mode = "play"
ClientState.focusFloor = nil :: number?
local modeChanged = Instance.new("BindableEvent")
ClientState.ModeChanged = modeChanged.Event

function ClientState.setMode(mode: string, focus: number?)
	ClientState.mode = mode
	ClientState.focusFloor = if mode == "play" then nil else focus or ClientState.focusFloor or 2
	modeChanged:Fire()
end

function ClientState.json(value: any): any
	if type(value) ~= "string" or value == "" then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value)
	return if ok then decoded else nil
end

function ClientState.now(): number
	return Workspace:GetServerTimeNow()
end

-- Build stamp (section 9) ---------------------------------------------------------------------------

function ClientState.stamp(): string
	local info = ReplicatedStorage:FindFirstChild("BuildInfo")
	local value = if info and info:IsA("StringValue") then info.Value else ""
	return string.match(value, "%S+") or "dev"
end

-- SpireStatus ---------------------------------------------------------------------------------------

export type Status = { event: string, eventLeft: number, forecast: { string }, window: number }

local statusValue = ReplicatedStorage:WaitForChild("SpireStatus") :: StringValue
ClientState.statusValue = statusValue
local cachedRaw: string? = nil
local cached: Status = { event = "normal", eventLeft = 0, forecast = {}, window = 0 }
local cachedAt = os.clock()

function ClientState.status(): Status
	local raw = statusValue.Value
	if raw ~= cachedRaw then
		cachedRaw = raw
		cachedAt = os.clock()
		local d = ClientState.json(raw)
		if type(d) == "table" then
			cached = {
				event = if type(d.event) == "string" then d.event else "normal",
				eventLeft = tonumber(d.eventLeft) or 0,
				forecast = if type(d.forecast) == "table" then d.forecast else {},
				window = tonumber(d.window) or 0,
			}
		end
	end
	return cached
end

-- Seconds left on a SpireStatus countdown, ticked down locally between the 1 Hz writes.
function ClientState.left(seconds: number): number
	return math.max(0, math.ceil(seconds - (os.clock() - cachedAt)))
end

function ClientState.event(): string
	return ClientState.status().event
end

function ClientState.eventName(id: string): string
	for _, e in SpireConfig.EVENTS do
		if e.id == id then
			return e.name
		end
	end
	return "Normal"
end

-- Own profile ---------------------------------------------------------------------------------------

local profileChanged = Instance.new("BindableEvent")
ClientState.ProfileChanged = profileChanged.Event -- () Profile, Credits or a local prediction changed

local rawSeen: string? = nil
local decoded: any = nil
-- After an accepted request the server publishes the profile at up to 1 Hz; until it does, the
-- same pure apply the server ran stands in, so a second tap never previews a stale tower.
local predicted: { raw: string?, profile: any, credits: any }? = nil

function ClientState.profile(): any
	local raw = player:GetAttribute("Profile")
	if type(raw) ~= "string" then
		return nil
	end
	if raw ~= rawSeen then
		local d = ClientState.json(raw)
		if d ~= nil then
			rawSeen = raw
			decoded = SpireProgress.sanitize(d, math.floor(ClientState.now()))
		end
	end
	if decoded == nil then
		return nil
	end
	local credits = player:GetAttribute("Credits")
	local p = decoded
	if predicted and predicted.raw == rawSeen then
		p = predicted.profile
		if credits == predicted.credits then
			return p
		end
	else
		predicted = nil
	end
	if type(credits) == "number" then
		p.coins = credits
	end
	return p
end

-- Profile or a fresh default, for screens that draw before the first publish.
function ClientState.me(): any
	return ClientState.profile() or SpireProgress.defaults(math.floor(ClientState.now()))
end

player:GetAttributeChangedSignal("Profile"):Connect(function()
	profileChanged:Fire()
end)
player:GetAttributeChangedSignal("Credits"):Connect(function()
	profileChanged:Fire()
end)

-- The same call the server makes (SpireProgress.apply on a copy), with the server-time `now` and
-- the SpireStatus event. Returns (new profile, ok, code).
function ClientState.preview(action: string, arg: string?): (any, boolean, string?)
	local p = ClientState.me()
	return SpireProgress.apply(TowerRules.copy(p), action, arg, math.floor(ClientState.now()), ClientState.event())
end

-- Refusals (section 6.2) ----------------------------------------------------------------------------

ClientState.REFUSALS = {
	busy = "Still loading. Try again in a moment.",
	type = "That did not work.",
	action = "That did not work.",
	arg = "That did not work.",
	rate = "Slow down a little.",
	zone = "Step onto a lift pad first.",
	target = "That company is not here.",
	gate = "This tower is closed to visitors.",
	credits = "Not enough credits.",
	power = "Not enough power: build or upgrade a Fusion Core.",
	locked = "Not unlocked yet.",
	floor = "Pick one of your floors.",
	occupied = "That spot is taken.",
	empty = "That slot is empty.",
	max = "Already at the limit.",
	full = "Your plaza is full.",
	bounds = "That does not fit on the plaza.",
	walkway = "Keep the walkway clear.",
	modules = "Sell this floor's modules first.",
	needed = "Your tower needs that power.",
	same = "Nothing to change.",
	unknown = "That does not exist.",
	claimed = "Nothing to claim yet.",
	owned = "You already own that.",
	done = "Already endorsed today.",
	ipo = "Reach floor 20 and earn more first.",
} :: { [string]: string }

function ClientState.refusal(code: string?): string
	return ClientState.REFUSALS[code or "type"] or ClientState.REFUSALS.type
end

-- InvokeServer; a refusal plays the buzz and toasts its text. Accepted profile actions are
-- predicted locally until the server's next publish.
function ClientState.request(action: string, arg: string?): (boolean, string?)
	local before = ClientState.profile()
	local ok, accepted, code = pcall(requestRemote.InvokeServer, requestRemote, action, arg)
	if not ok then
		accepted, code = false, "type"
	end
	if accepted == true then
		local spec = SpireConfig.ACTIONS[action]
		if spec and spec.profile and before then
			local now, event = math.floor(ClientState.now()), ClientState.event()
			local p, applied = SpireProgress.apply(TowerRules.copy(before), action, arg, now, event)
			if applied then
				predicted = { raw = rawSeen, profile = p, credits = player:GetAttribute("Credits") }
				profileChanged:Fire()
			end
		end
		return true, nil
	end
	local c = if type(code) == "string" then code else "type"
	ClientState.sound(ClientState.SFX.buzz, 0.25, nil, 0.7)
	ClientState.toast(ClientState.refusal(c), ClientState.UI.MAGENTA)
	return false, c
end

-- Lots ----------------------------------------------------------------------------------------------

function ClientState.lotModel(n: number): Model?
	local spire = Workspace:FindFirstChild("Spire")
	local lots = spire and spire:FindFirstChild("Lots")
	local m = lots and lots:FindFirstChild(`Lot{n}`)
	return if m and m:IsA("Model") then m else nil
end

function ClientState.myLot(): number?
	local lot = player:GetAttribute("Lot")
	return if type(lot) == "number" and lot >= 1 then lot else nil
end

-- Lot frame (section 3.0): clients use the server's pivot and never recompute it.
function ClientState.lotFrame(n: number): CFrame?
	local m = ClientState.lotModel(n)
	return if m then m:GetPivot() else nil
end

function ClientState.toWorld(n: number, v: { x: number, y: number, z: number }): Vector3?
	local f = ClientState.lotFrame(n)
	return if f then f:PointToWorldSpace(Vector3.new(v.x, v.y, v.z)) else nil
end

function ClientState.ownerOf(n: number): Player?
	local m = ClientState.lotModel(n)
	local owner = m and m:GetAttribute("Owner")
	return if type(owner) == "number" and owner > 0 then Players:GetPlayerByUserId(owner) else nil
end

local states: { [number]: { raw: string, state: any } } = {}
-- The lot's public TowerState (nil when free or unreadable), cached per raw JSON.
function ClientState.lotState(n: number): any
	local m = ClientState.lotModel(n)
	local raw = m and m:GetAttribute("State")
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local entry = states[n]
	if entry and entry.raw == raw then
		return entry.state
	end
	local s = ClientState.json(raw)
	if type(s) ~= "table" or type(s.floors) ~= "table" or type(s.items) ~= "table" then
		return if entry then entry.state else nil
	end
	states[n] = { raw = raw, state = s }
	return s
end

function ClientState.root(): BasePart?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

-- The lot whose 64 x 92 footprint holds a world point, and the point in that lot's space.
function ClientState.lotAt(pos: Vector3): (number?, Vector3?)
	for n = 1, 6 do
		local f = ClientState.lotFrame(n)
		local l = f and f:PointToObjectSpace(pos)
		if l and math.abs(l.X) <= 32 and math.abs(l.Z) <= 46 then
			return n, l
		end
	end
	return nil, nil
end

-- Client-only visuals live here (section 4.6).
function ClientState.folder(name: string): Folder
	local root = Workspace:FindFirstChild("SpireClient")
	if not root then
		root = Instance.new("Folder")
		root.Name = "SpireClient"
		root.Parent = Workspace
	end
	local f = (root :: Instance):FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
	end
	return f :: Folder
end

-- Formatting ----------------------------------------------------------------------------------------

function ClientState.short(n: number): string
	return SpireEconomy.short(math.floor(n))
end

function ClientState.commas(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""):gsub("^%-,", "-"))
end

function ClientState.clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	if s >= 3600 then
		return string.format("%d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

function ClientState.rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function ClientState.brand(index: number): Color3
	local c = SpireConfig.COLOURS[index]
	return if c then ClientState.rgb(c) else Color3.fromRGB(0, 240, 255)
end

function ClientState.level(p: any): number
	return SpireProgress.levelFor(p.xp)
end

-- True when a daily, weekly or quest reward can be claimed now (the gold dot).
function ClientState.rewardsReady(p: any): boolean
	local day = MetaRules.dayOf(ClientState.now())
	if MetaRules.nextDaily(p, day) ~= nil or MetaRules.canClaimWeekly(SpireProgress.CONFIG, p, day) then
		return true
	end
	if p.quests.day ~= day then
		return false
	end
	for _, q in SpireProgress.questsFor(day) do
		if not p.quests.claimed[q.id] and (p.quests.progress[q.stat] or 0) >= q.goal then
			return true
		end
	end
	return false
end

-- Sounds --------------------------------------------------------------------------------------------

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
		s.RollOffMaxDistance = 300
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

-- Registered SFX already in docs/assets/register.md (Egg Garden), pitched for a synth feel until
-- the Spire shortlist is registered (GDD M).
ClientState.SFX = {
	click = "rbxassetid://9117060347",
	chime = "rbxassetid://9125585534",
	buzz = "rbxassetid://9114373663",
	whoosh = "rbxassetid://9114373663",
	thud = "rbxasset://sounds/action_jump_land.mp3",
}

-- UI kit (art bible section 6) ----------------------------------------------------------------------

ClientState.UI = {
	ASPHALT = Color3.fromHex("0B0F1A"),
	STEEL = Color3.fromHex("1C2333"),
	SMOG = Color3.fromHex("2A1B3D"),
	CYAN = Color3.fromHex("00F0FF"),
	MAGENTA = Color3.fromHex("FF2A6D"),
	VIOLET = Color3.fromHex("7B2FFF"),
	AMBER = Color3.fromHex("FFB800"),
	LIME = Color3.fromHex("B6FF3B"),
	WHITE = Color3.fromHex("E8F6FF"),
	CORAL = Color3.fromHex("FF6B4A"),
	ICE = Color3.fromHex("9FD8FF"),
	MUTED = Color3.fromRGB(140, 150, 175),
	GREY = Color3.fromRGB(60, 66, 82),
}
local UI = ClientState.UI

ClientState.DEPT_COLOURS = {
	lobby = UI.WHITE,
	data = UI.CYAN,
	fusion = UI.AMBER,
	ad = UI.MAGENTA,
	synth = UI.LIME,
	drone = UI.CORAL,
	quantum = UI.VIOLET,
	orbital = UI.WHITE,
} :: { [string]: Color3 }

ClientState.EVENT_COLOURS = {
	normal = UI.CYAN,
	boom = UI.LIME,
	neon = UI.MAGENTA,
	sale = UI.AMBER,
} :: { [string]: Color3 }

-- Built-in fonts (art bible 6): Sarpanch display, Titillium body, Roboto Mono numbers.
ClientState.FONT = {
	display = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Bold),
	body = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.SemiBold),
	mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium),
}
local FONT = ClientState.FONT

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

function ClientState.stroke(colour: Color3, thickness: number, transparency: number?): UIStroke
	return new("UIStroke", {
		Color = colour,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Panel: Night Asphalt at 12% transparency, 6 px corners, cyan 1.5 px stroke at 40%, a 2 px top
-- accent bar and faint scanlines.
function ClientState.panel(props: { [string]: any }, accent: Color3?): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or UI.ASPHALT
	props.BackgroundTransparency = props.BackgroundTransparency or 0.12
	local f = new("Frame", props, {
		ClientState.corner(6),
		ClientState.stroke(UI.CYAN, 1.5, 0.4),
		new("Frame", {
			Name = "Accent",
			Size = UDim2.new(1, -12, 0, 2),
			Position = UDim2.fromOffset(6, 0),
			BackgroundColor3 = accent or UI.CYAN,
			BorderSizePixel = 0,
		}),
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.5, 0.08),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}),
	})
	return f
end

function ClientState.text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.FontFace = props.FontFace or FONT.body
	props.TextColor3 = props.TextColor3 or UI.WHITE
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	return new("TextLabel", props)
end

-- Hover +4% and stroke to opaque, press 96% (art bible 6); works with mouse, touch and gamepad
-- selection. Secondary buttons are outlines (fill nil).
function ClientState.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local fill = props.BackgroundColor3 or UI.CYAN
	local outline = props.Outline == true
	props.Outline = nil
	props.FontFace = props.FontFace or FONT.display
	props.TextColor3 = props.TextColor3 or (if outline then fill else UI.ASPHALT)
	props.TextScaled = true
	props.AutoButtonColor = false
	props.BackgroundColor3 = if outline then UI.ASPHALT else fill
	props.BackgroundTransparency = if outline then 0.2 else 0
	local line = ClientState.stroke(fill, 1.5, 0.4)
	local scale = new("UIScale", {})
	local b = new("TextButton", props, {
		ClientState.corner(6),
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
		}),
		line,
		scale,
	})
	local function to(s: number, t: number)
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = s }):Play()
		line.Transparency = t
	end
	b.MouseEnter:Connect(function()
		to(1.04, 0)
	end)
	b.MouseLeave:Connect(function()
		to(1, 0.4)
	end)
	b.SelectionGained:Connect(function()
		to(1.04, 0)
	end)
	b.SelectionLost:Connect(function()
		to(1, 0.4)
	end)
	b.MouseButton1Down:Connect(function()
		to(0.96, 0)
	end)
	b.MouseButton1Up:Connect(function()
		to(1, 0.4)
	end)
	b.Activated:Connect(function()
		ClientState.sound(ClientState.SFX.click, 0.15, nil, 2.4)
		onClick()
	end)
	return b
end

-- Greys out a button (40% opacity) without hiding it; the caller shows the reason beside it.
function ClientState.enable(b: TextButton, on: boolean)
	b.Active = on
	b.BackgroundTransparency = if on then (if b.BackgroundColor3 == UI.ASPHALT then 0.2 else 0) else 0.6
	b.TextTransparency = if on then 0 else 0.4
end

function ClientState.pop(target: GuiObject)
	local scale = target:FindFirstChild("Pop") :: UIScale?
	if not scale then
		scale = new("UIScale", { Name = "Pop", Parent = target })
	end
	local s = scale :: UIScale
	s.Scale = 1.12
	TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Scale = 1 }):Play()
end

-- Layouts are drawn for a 1100 x 620 screen and scaled to fit (Egg Garden's range).
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

-- HUD-style guis keep clear of the Roblox top bar; full-screen ones (menu, lift doors) only of
-- notches and rounded corners.
function ClientState.gui(name: string, order: number, fullScreen: boolean?): ScreenGui
	return new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ScreenInsets = if fullScreen then Enum.ScreenInsets.DeviceSafeInsets else Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = order,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
end

function ClientState.gamepad(): boolean
	return UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil
end

-- Company glyphs (GDD G): 12 shapes from one frame: 3 corner styles x 2 rotations x filled/hollow.
function ClientState.glyph(parent: Instance, index: number, colour: Color3, size: number): Frame
	local i = math.clamp(index, 1, 12) - 1
	local hollow = i % 2 == 1
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.7, size * 0.7),
		Rotation = if (i // 2) % 2 == 1 then 45 else 0,
		BackgroundColor3 = colour,
		BackgroundTransparency = if hollow then 1 else 0,
		Parent = parent,
	}, {
		new("UICorner", { CornerRadius = UDim.new(({ 0, 0.2, 0.5 })[i // 4 + 1], 0) }),
		ClientState.stroke(colour, 3),
	})
	return f
end

return ClientState
