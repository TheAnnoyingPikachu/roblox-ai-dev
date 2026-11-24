--!strict
-- The Ranch sheet: the upgrades of the ranch in three groups, each with a picture of its building.
-- One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationProgress = require(Shared:WaitForChild("StationProgress"))
local Format = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Format"))
local Style = require(script.Parent:WaitForChild("Style"))
local App: any = require(script.Parent:WaitForChild("HudApp"))
local S = App.S
local C = App.C
local Hud = App.Hud
local send = App.send
local redraw = App.redraw
local ranch = App.ranch

-- Ranch: upgrades in three groups, each with a picture of its building (decision 0091) -----------------

local GROUPS = {
	{ id = "animals", name = "Animals", upgrades = { "house", "barn", "grounds" } },
	{ id = "eggs", name = "Eggs", upgrades = { "hatchery", "cellar", "brooder" } },
	{ id = "earnings", name = "Earnings", upgrades = { "windmill", "lodge", "den" } },
}

-- Pictures of the buildings as they stand in game (decision 0091): each building's three looks, and
-- the Training Grounds (the Speed Track) at each level. Screenshots from Studio, uploaded as images.
local PICTURES: { [string]: { string } } = {
	house = { "123119223827948", "75503797264752", "107798905588688" },
	barn = { "101892180349204", "121151105188828", "115965219734238" },
	hatchery = { "133902304920898", "124045791914974", "123100005333170" },
	cellar = { "90053421861862", "72531267730211", "133921641057596" },
	brooder = { "88844343986979", "128424168474378", "125930939253883" },
	windmill = { "95016315403212", "71885186151925", "130764990300282" },
	lodge = { "89855001205054", "104259688695882", "92288867347305" },
	den = { "86742890917401", "83910433232346", "101343125013182" },
	grounds = {
		"98297919965705",
		"106959352530071",
		"131970264474678",
		"137939197697617",
		"120047660590642",
		"100438873746948",
	},
}
local PLOT = { brooder = true, windmill = true, lodge = true, den = true } -- as Ranch.luau: not built at level 0

-- Which picture shows upgrade `u` at `level`: the look Ranch.luau builds (1 to 3; the first look for a
-- building not bought yet), or the Training Grounds' level itself (0 to 5).
function Hud.pictureOf(u: StationConfig.Upgrade, level: number): number
	if u.id == "grounds" then
		return math.clamp(level + 1, 1, #PICTURES.grounds)
	end
	local first = if PLOT[u.id] then 1 else 0
	if level < first then
		return 1
	end
	return 1 + math.min(2, (level - first) * 3 // (#u.levels - first + 1))
end

local function picture(parent: Instance, id: string, size: UDim2): ImageLabel
	local img = Instance.new("ImageLabel")
	img.Size = size
	img.BackgroundColor3 = Color3.fromRGB(191, 230, 247)
	img.BorderSizePixel = 0
	img.Image = `rbxassetid://{id}`
	img.ScaleType = Enum.ScaleType.Crop
	Style.round(img, 11)
	img.Parent = parent
	return img
end

local function canBuy(u: StationConfig.Upgrade): boolean
	local cost = u.levels[(S.profile.upgrades[u.id] or 0) + 1]
	return cost ~= nil and S.profile.coins >= cost.coins and S.profile.samples >= cost.samples
end

function Hud.upgradeCard(u: StationConfig.Upgrade, order: number)
	local level = S.profile.upgrades[u.id] or 0
	local cost = u.levels[level + 1]
	local card = Style.card(ranch.body, UDim2.fromOffset(204, 330))
	card.LayoutOrder = order
	local pics = PICTURES[u.id]
	if pics then
		local now = Hud.pictureOf(u, level)
		local view = picture(card, pics[now], UDim2.fromOffset(198, 112))
		view.Position = UDim2.fromOffset(3, 3)
		local built = u.id == "grounds" or level >= (if PLOT[u.id] then 1 else 0)
		if not built then
			view.ImageTransparency = 0.45
			local tag = Style.chip(view, "Not built yet", C.ink, Color3.new(1, 1, 1))
			tag.Position, tag.TextSize = UDim2.fromOffset(8, 8), 13
		end
	end
	local title = Style.text(card, u.name, 21, C.text, UDim2.new(1, -24, 0, 26))
	title.Position = UDim2.fromOffset(12, 122)
	local pips = Instance.new("Frame")
	pips.BackgroundTransparency = 1
	pips.Position, pips.Size = UDim2.fromOffset(12, 152), UDim2.new(1, -24, 0, 14)
	Style.list(pips, 4, true)
	pips.Parent = card
	for i = 1, #u.levels do
		local pip = Style.frame(pips, UDim2.fromOffset(22, 12), if i <= level then C.good else Color3.new(1, 1, 1))
		Style.round(pip, 4)
		Style.stroke(pip, C.ink, 2)
		pip.LayoutOrder = i
	end
	local now = StationProgress.value(S.profile, u.id)
	local words = if cost then `Now {now} → next {cost.value}\n{u.gives}` else `{now} {u.gives}`
	local gives = Style.text(card, words, 14, C.muted, UDim2.new(1, -24, 0, 54))
	gives.Position = UDim2.fromOffset(12, 174)
	if cost == nil then
		local done = Style.chip(card, "TOP LEVEL", C.accent)
		done.Position = UDim2.fromOffset(12, 238)
		return
	end
	local price = Instance.new("Frame")
	price.BackgroundTransparency = 1
	price.Position, price.Size = UDim2.fromOffset(12, 232), UDim2.new(1, -24, 0, 26)
	Style.list(price, 10, true)
	price.Parent = card
	Style.amount(price, "coins", Format.commas(cost.coins))
	if cost.samples > 0 then
		Style.amount(price, "samples", tostring(cost.samples))
	end
	local b = Style.button(card, "Upgrade", function()
		send("upgrade", u.id)
	end, if canBuy(u) then "good" else "off")
	b.Position, b.Size = UDim2.fromOffset(12, 270), UDim2.new(1, -24, 0, 44)
end

redraw.ranch = function()
	Style.clear(ranch.body)
	Style.clear(ranch.chips)
	Style.clear(ranch.tabs)
	for _, g in GROUPS do
		local any = false
		for _, id in g.upgrades do
			any = any or canBuy(StationConfig.upgrade(id) :: StationConfig.Upgrade)
		end
		Style.tab(ranch, g.name, S.ranchTab == g.id, function()
			S.ranchTab = g.id
			redraw.ranch()
		end, if any then "!" else nil)
		if S.ranchTab == g.id then
			for i, id in g.upgrades do
				Hud.upgradeCard(StationConfig.upgrade(id) :: StationConfig.Upgrade, i)
			end
		end
	end
	Style.amount(ranch.chips, "coins", Format.commas(S.profile.coins))
	Style.amount(ranch.chips, "samples", `{Format.commas(S.profile.samples)} samples`)
	if RunService:IsStudio() then -- a way to try the upgrades without fighting for them
		local funds = Style.button(ranch.chips, "Test funds (Studio)", function()
			send("funds")
		end, "ghost", UDim2.fromOffset(196, 44))
		funds.LayoutOrder = -1
	end
end

return nil
