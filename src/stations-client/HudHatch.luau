--!strict
-- Hatching: the nests in the world, the egg that cracks open and the animal that steps out.
-- One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Style = require(script.Parent:WaitForChild("Style"))
local remotes = ReplicatedStorage:WaitForChild("StationsRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local player = game:GetService("Players").LocalPlayer
local App: any = require(script.Parent:WaitForChild("HudApp"))
local S = App.S
local C = App.C
local RARITY_COLOUR = App.RARITY_COLOUR
local REFUSED = App.REFUSED
local screen = App.screen
local send = App.send
local nameOf = App.nameOf
local sheets = App.sheets
local redraw = App.redraw
local show = App.show
local admin = App.admin
local adminToggle = App.adminToggle
local darker = App.darker

-- Hatching -------------------------------------------------------------------------------------------

-- The egg `eggId` standing at `at` rocks harder and harder, then bursts: a flash, sparks and bits of
-- shell in its two colours. Takes HATCH seconds; the server brings the animal out of the nest after
-- it. The egg is its own model (the still copy the portraits use), or a plain shell without one.
local HATCH = 1.4
local function hatchEffect(nest: CFrame, eggId: string, body: Color3, spot: Color3)
	local h = 3
	local at = nest.Position
	local portraits = ReplicatedStorage:FindFirstChild("Portraits")
	local source = portraits and portraits:FindFirstChild(`egg_{eggId}`)
	local shell: Instance
	local place: (CFrame) -> ()
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = spot, 10, 0.5, false
	if source and source:IsA("Model") and source.PrimaryPart then
		local model = source:Clone()
		light.Parent = model.PrimaryPart
		shell, place = model, function(foot: CFrame)
			model:PivotTo(foot)
		end
	else
		local plain = Instance.new("Part")
		plain.Anchored, plain.CanCollide, plain.CanQuery = true, false, false
		plain.Size, plain.Color, plain.Material = Vector3.new(h * 0.75, h, h * 0.75), body, Enum.Material.SmoothPlastic
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = plain
		light.Parent = plain
		shell, place = plain, function(foot: CFrame)
			plain.CFrame = foot * CFrame.new(0, h / 2, 0)
		end
	end
	place(nest)
	shell.Parent = Workspace
	local started = os.clock()
	while os.clock() - started < HATCH do -- rock about the foot, faster and wider
		local t = (os.clock() - started) / HATCH
		local lean = math.sin(t * t * 60) * math.rad(4 + 22 * t)
		place(nest * CFrame.Angles(0, 0, lean) * CFrame.new(0, math.abs(lean) * 0.6, 0))
		light.Brightness = 0.5 + 4 * t
		RunService.RenderStepped:Wait()
	end
	shell:Destroy()
	local mid = at + Vector3.new(0, h / 2, 0)
	local flash = Instance.new("Part")
	flash.Shape, flash.Anchored, flash.CanCollide, flash.CanQuery = Enum.PartType.Ball, true, false, false
	flash.Size, flash.Position, flash.Color, flash.Material =
		Vector3.one * h, mid, Color3.new(1, 1, 0.9), Enum.Material.Neon
	flash.Parent = Workspace
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(spot, body)
	sparks.LightEmission = 0.8
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(10, 22)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Rate = 0
	sparks.Parent = flash
	sparks:Emit(50)
	local out = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(flash, out, { Size = Vector3.one * h * 3.2, Transparency = 1 }):Play()
	for k = 1, 12 do -- bits of shell fly out and fall
		local bit = Instance.new("WedgePart")
		bit.Anchored, bit.CanCollide, bit.CanQuery = true, false, false
		bit.Size = Vector3.new(0.2, 0.7, 0.9)
		bit.Color, bit.Material = if k % 3 == 0 then spot else body, Enum.Material.SmoothPlastic
		bit.CFrame = CFrame.new(mid) * CFrame.Angles(k, k * 2, k * 3)
		bit.Parent = Workspace
		local a = k / 12 * math.pi * 2
		local land = at + Vector3.new(math.cos(a) * 6, 0.2, math.sin(a) * 6)
		TweenService:Create(bit, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(land) * CFrame.Angles(k * 3, k, k * 2),
			Transparency = 1,
		}):Play()
		Debris:AddItem(bit, 0.8)
	end
	Debris:AddItem(flash, 1.3)
end

-- Admin menu (decisions 0038, 0049): only for players the server marks as admin (the game's owner, or
-- anyone in Studio). Its first tab lists every animal and variant: a tap adds it to your own ranch. Its
-- second spawns animals in front of you and plays their animations, its third the same for the
-- Hexbound enemies; nothing there is saved.
local adminTab = "add"
local adminTabs: { [string]: Frame } = {} -- the Spawn ("tests") and Enemies ("foes") tabs, made once
for _, key in { "tests", "foes" } do
	local tab = Instance.new("Frame")
	tab.BackgroundTransparency = 1
	tab.Size, tab.AutomaticSize = UDim2.new(1, -12, 0, 0), Enum.AutomaticSize.Y
	Style.list(tab, 10)
	tab.Visible = false
	tab.Parent = admin.body
	adminTabs[key] = tab
end
local adminAdd = { body = Instance.new("Frame") } -- the Add animals tab's rows
adminAdd.body.BackgroundTransparency = 1
adminAdd.body.Size, adminAdd.body.AutomaticSize = UDim2.new(1, -12, 0, 0), Enum.AutomaticSize.Y
Style.list(adminAdd.body, 8)
adminAdd.body.Parent = admin.body
for _, tab in adminTabs do
	-- the animations play on whatever is spawned
	local anims = Instance.new("Frame")
	anims.BackgroundTransparency = 1
	anims.Size, anims.AutomaticSize, anims.LayoutOrder = UDim2.fromScale(1, 0), Enum.AutomaticSize.Y, 0
	Style.list(anims, 6, true, true)
	anims.Parent = tab
	local CLIPS = {
		{ "idle", "Idle" },
		{ "walk", "Walk" },
		{ "attack", "Attack" },
		{ "magic", "Power" },
		{ "hit", "Hit" },
		{ "die", "Fall" },
	}
	for i, clip in CLIPS do
		Style.button(anims, clip[2], function()
			send("look_anim", clip[1])
		end, "ghost", UDim2.fromOffset(86, 44)).LayoutOrder =
			i
	end
	Style.button(anims, "Clear", function()
		send("look_clear")
	end, "ghost", UDim2.fromOffset(86, 44)).LayoutOrder = #CLIPS
		+ 1
end
do
	-- the server lists them in this order too (LOOKS: a species, then its variants; the foes after them all)
	local k = 0
	local function spawnButton(tab: Frame, name: string)
		k += 1
		local index = k
		Style.button(tab, `Spawn {name}`, function()
			send("look", index)
		end, "ghost", UDim2.new(1, 0, 0, 44)).LayoutOrder =
			index
	end
	for _, sp in StationConfig.SPECIES do
		spawnButton(adminTabs.tests, sp.name)
		for _, va in sp.variants do
			spawnButton(adminTabs.tests, `{va.name} ({va.tier})`)
		end
	end
	for _, f in StationConfig.FOES do
		spawnButton(adminTabs.foes, f.name)
	end
end

-- The Add animals tab (decisions 0049, 0058): one row per species and variant; a tap adds it to your own
-- ranch, every stat at level 1. The server checks the admin.
do
	local list: { { s: string, v: string? } } = {} -- in the server's order (LOOKS: a species, then its variants)
	for _, sp in StationConfig.SPECIES do
		table.insert(list, { s = sp.id })
		for _, va in sp.variants do
			table.insert(list, { s = sp.id, v = va.id })
		end
	end
	local function draw()
		Style.clear(adminAdd.body)
		for k, a in list do
			local colour = RARITY_COLOUR[StationRules.rarity(a :: any)] or C.text
			local name = nameOf(a)
			local va = if a.v then StationConfig.variant(a.s, a.v) else nil
			local row = Style.button(adminAdd.body, "", function()
				local ok, code = request:InvokeServer("admin_add", k, 1, false)
				Style.toast(
					screen,
					if ok then `Added a {name} to your ranch` else REFUSED[code] or `Can't do that ({code})`,
					2
				)
			end, "ghost", UDim2.new(1, 0, 0, 64))
			row.Name, row.LayoutOrder = name, k
			Style.stroke(row, colour, 2)
			local view = Portrait.new(
				row,
				StationRules.assetOf(a.s, a.v),
				{ size = UDim2.fromOffset(52, 52), background = darker(colour) }
			)
			view.Position = UDim2.fromOffset(6, 6)
			local label =
				Style.text(row, if va then `{name} ({va.tier})` else name, 18, colour, UDim2.new(1, -220, 1, 0))
			label.Position = UDim2.fromOffset(70, 0)
			local hint = Style.text(row, "Add to my ranch", 14, C.muted, UDim2.fromOffset(140, 64))
			hint.AnchorPoint, hint.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 0)
			hint.TextXAlignment = Enum.TextXAlignment.Right
		end
	end
	local drawn = false
	redraw.admin = function() -- the rows are drawn once, when first opened: a new profile must not scroll it back up
		Style.clear(admin.tabs)
		for _, t in { { "add", "Add animals" }, { "tests", "Spawn" }, { "foes", "Enemies" } } do
			Style.tab(admin, t[2], adminTab == t[1], function()
				adminTab = t[1]
				redraw.admin()
			end)
		end
		adminTabs.tests.Visible, adminTabs.foes.Visible = adminTab == "tests", adminTab == "foes"
		adminAdd.body.Visible = adminTab == "add"
		if adminTab == "add" and not drawn then
			drawn = true
			draw()
		end
	end
end
local function showAdmin()
	adminToggle.Visible = player:GetAttribute("Admin") == true
	if not adminToggle.Visible and S.openName == "admin" then
		show(nil)
	end
end
player:GetAttributeChangedSignal("Admin"):Connect(showAdmin)
showAdmin()

-- A way to open a sheet by name, for looking at the layout without walking to its prompt: set the
-- player's "UiOpen" attribute to a sheet's name ("" closes).
player:GetAttributeChangedSignal("UiOpen"):Connect(function()
	local name = player:GetAttribute("UiOpen")
	show(if type(name) == "string" and sheets[name] then name else nil)
end)

App.hatchEffect = hatchEffect

return nil
