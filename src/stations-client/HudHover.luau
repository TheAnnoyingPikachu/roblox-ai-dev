--!strict
-- The card under the cursor: point at an animal in the world to see whose it is and how strong.
-- One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BattleRules = require(Shared:WaitForChild("BattleRules"))
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local Format = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Format"))
local Ui = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("Ui"))
local App: any = require(script.Parent:WaitForChild("HudApp"))
local C = App.C
local RARITY_COLOUR = App.RARITY_COLOUR
local ROLE_NAME = App.ROLE_NAME
local GROUP_NAME = App.GROUP_NAME
local STAT_SHORT = App.STAT_SHORT
local screen = App.screen

-- The card under the cursor ----------------------------------------------------------------------

-- Pointing at an animal shows a small card that follows the cursor: its name, its rarity in the
-- rarity's colour, role and group, the six stats and a health bar. Every model carries what the
-- card needs as attributes (the server's `describe`); the cursor finds a model by its unseen
-- "CreatureHit" box.
local card = Ui.panel(screen, { size = UDim2.fromOffset(236, 152), name = "AnimalCard" })
card.Visible = false
card.ZIndex = 20
local cardEdge = Instance.new("UIStroke")
cardEdge.Thickness = 3
cardEdge.Parent = card
local cardName = Ui.label(card, "", { size = 20 })
local cardPower = Ui.label(card, "", { size = 16 }) -- its power score (decision 0096)
local cardKind = Ui.label(card, "", { size = 14 })
local cardStats = Ui.label(card, "", { size = 14, muted = true })
local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 16)
bar.BackgroundColor3 = Color3.new(1, 1, 1)
bar.BorderSizePixel = 0
bar.Parent = card
local fill = Instance.new("Frame")
fill.BackgroundColor3 = C.good
fill.BorderSizePixel = 0
fill.Parent = bar
local barText = Instance.new("TextLabel")
barText.Size = UDim2.fromScale(1, 1)
barText.BackgroundTransparency = 1
barText.Font = Enum.Font.FredokaOne
barText.TextSize = 13
barText.TextColor3 = Color3.new(1, 1, 1)
barText.Parent = bar

local HEXFIRE = Color3.fromRGB(150, 255, 70)

local function showCard(model: Model?)
	local s = model and model:GetAttribute("Species")
	local sp = if type(s) == "string" then StationConfig.species(s) else nil
	local f = model and model:GetAttribute("FoeId")
	local foe = if type(f) == "string" then StationConfig.foe(f) else nil
	if model == nil or (sp == nil and foe == nil) then
		card.Visible = false
		return
	end
	if foe then -- an enemy: the Hexbound have no rarity, only their kind
		cardName.Text = foe.name
		cardName.TextColor3 = HEXFIRE
		cardEdge.Color = HEXFIRE
		cardKind.Text =
			`HEXBOUND {string.upper(foe.kind)}  -  {ROLE_NAME[foe.role] or "?"}  -  {GROUP_NAME[foe.group] or "?"}`
		cardKind.TextColor3 = HEXFIRE
	else
		local animal = sp :: StationConfig.Species
		local v = model:GetAttribute("Variant")
		local va = if type(v) == "string" then StationConfig.variant(animal.id, v) else nil
		local rarity = if va then va.tier else animal.rarity
		local colour = RARITY_COLOUR[rarity] or Color3.new(1, 1, 1)
		cardName.Text = (if model:GetAttribute("Rainbow") then "Rainbow " else "")
			.. (if va then va.name else animal.name)
		cardName.TextColor3 = colour
		cardEdge.Color = colour
		cardKind.Text =
			`{string.upper(rarity)}  -  {ROLE_NAME[animal.role] or "?"}  -  {GROUP_NAME[animal.group] or "?"}`
		cardKind.TextColor3 = colour
	end
	local parts = {}
	for k, stat in StationConfig.STATS do
		table.insert(parts, `{STAT_SHORT[stat]} {model:GetAttribute(stat) or "?"}{if k == 3 then "\n" else "   "}`)
	end
	cardStats.Text = table.concat(parts)
	-- the attributes are its stats as they stand (levels, coat, the Den), so its power works out from them
	local stats = {}
	for _, stat in StationConfig.STATS do
		local x = model:GetAttribute(stat)
		stats[stat] = if type(x) == "number" then x else 0
	end
	local who = { s = if foe then foe.id else (sp :: StationConfig.Species).id, stats = stats :: any }
	cardPower.Text = `⚡ {Format.short(BattleRules.powerOf(who, if foe then 2 else 1))} power`
	cardPower.TextColor3 = if foe then HEXFIRE else C.gold
	local health = model:GetAttribute("health")
	local max = BattleRules.HP_BASE
		+ math.floor((if type(health) == "number" then health else 0) * BattleRules.HP_PER_HEALTH)
	local fightMax = model:GetAttribute("MaxHp") -- in a fight: with the team's bonuses
	if type(fightMax) == "number" then
		max = fightMax
	end
	local hp = model:GetAttribute("Hp") -- set while a fight is on; full otherwise
	local now = if type(hp) == "number" then math.clamp(hp, 0, max) else max
	fill.Size = UDim2.fromScale(now / math.max(1, max), 1)
	barText.Text = `{now} / {max} HP`
	card.Visible = true
end

RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if camera == nil or not UserInputService.MouseEnabled then
		return
	end
	local at = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(at.X, at.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = CollectionService:GetTagged("CreatureHit")
	local found = Workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	showCard(if found then found.Instance.Parent :: Model else nil)
	if card.Visible then
		local inset = if screen.IgnoreGuiInset then Vector2.zero else GuiService:GetGuiInset()
		card.Position = UDim2.fromOffset(at.X - inset.X + 18, at.Y - inset.Y + 14)
	end
end)

return nil
