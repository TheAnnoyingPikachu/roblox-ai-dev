--!strict
-- The Ranch window (the RanchGifts board): every building on one page, each with its picture.
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

-- A building's card (the RanchGifts board): its picture, its level as squares, what it gives now and next
-- in one line, the cost and one button, yellow only when it can be paid for.
function Hud.upgradeCard(u: StationConfig.Upgrade, order: number)
	local level = S.profile.upgrades[u.id] or 0
	local cost = u.levels[level + 1]
	local can = canBuy(u)
	local card = Style.card(ranch.body, UDim2.fromOffset(418, 132))
	card.LayoutOrder = order
	local pics = PICTURES[u.id]
	local built = u.id == "grounds" or level >= (if PLOT[u.id] then 1 else 0)
	if pics then
		local view = picture(card, pics[Hud.pictureOf(u, level)], UDim2.fromOffset(112, 112))
		view.Position = UDim2.fromOffset(10, 10)
		Style.stroke(view, C.ink, 2)
		if not built then
			view.ImageTransparency = 0.45
		end
	end
	local title = Style.text(card, u.name, 19, C.text, UDim2.new(1, -230, 0, 24))
	title.Position, title.TextTruncate = UDim2.fromOffset(134, 10), Enum.TextTruncate.AtEnd
	local pips = Instance.new("Frame")
	pips.BackgroundTransparency = 1
	pips.AnchorPoint, pips.Position, pips.Size = Vector2.new(1, 0), UDim2.new(1, -12, 0, 16), UDim2.fromOffset(0, 14)
	pips.AutomaticSize = Enum.AutomaticSize.X
	Style.list(pips, 3, true)
	pips.Parent = card
	for i = 1, #u.levels do
		local pip = Style.frame(pips, UDim2.fromOffset(12, 12), if i <= level then C.good else Color3.new(1, 1, 1))
		Style.round(pip, 3)
		Style.stroke(pip, C.ink, 2)
		pip.LayoutOrder = i
	end
	local now = StationProgress.value(S.profile, u.id)
	-- "2 animals training at once. Next: 3." or, for a share, "Training speed 100%. Next: 115%."
	local share = string.sub(u.gives, 1, 2) == "% "
	local what = if share then string.upper(string.sub(u.gives, 3, 3)) .. string.sub(u.gives, 4) else u.gives
	local function said(v: number): string
		return if share then `{v}%` else tostring(v)
	end
	local words = if share then `{what} {said(now)}.` else `{now} {what}.`
	if not built then
		local first = if cost then cost.value else now
		words = if share then `Not built yet. Then: {what} {said(first)}.` else `Not built yet. Then: {first} {what}.`
	elseif cost then
		words ..= ` Next: {said(cost.value)}.`
	end
	local gives = Style.small(card, words, 14, C.muted, UDim2.new(1, -146, 0, 38))
	gives.Position, gives.TextWrapped = UDim2.fromOffset(134, 38), true
	if cost == nil then
		local done = Style.chip(card, "TOP LEVEL", C.good, Color3.new(1, 1, 1))
		done.Position = UDim2.fromOffset(134, 90)
		return
	end
	local price = Instance.new("Frame")
	price.BackgroundTransparency = 1
	price.Position, price.Size = UDim2.fromOffset(134, 92), UDim2.fromOffset(150, 26)
	Style.list(price, 10, true)
	price.Parent = card
	Style.amount(price, "coins", Format.short(cost.coins))
	if cost.samples > 0 then
		Style.amount(price, "samples", tostring(cost.samples))
	end
	local b = Style.button(card, if can then "Upgrade" else "Not yet", function()
		send("upgrade", u.id)
	end, if can then "primary" else "off", UDim2.fromOffset(112, 40))
	b.AnchorPoint, b.Position, b.TextSize = Vector2.new(1, 1), UDim2.new(1, -12, 1, -10), 16
end

redraw.ranch = function()
	Style.clear(ranch.body)
	Style.clear(ranch.chips)
	Style.clear(ranch.count)
	local afford, order = 0, 0
	for _, g in GROUPS do
		for _, id in g.upgrades do
			local u = StationConfig.upgrade(id) :: StationConfig.Upgrade
			order += 1
			Hud.upgradeCard(u, order)
			afford += if canBuy(u) then 1 else 0
		end
	end
	Style.amount(ranch.chips, "coins", Format.commas(S.profile.coins))
	Style.amount(ranch.chips, "samples", Format.commas(S.profile.samples))
	if afford > 0 then
		Style.chip(ranch.count, `{afford} you can afford`, C.good, Color3.new(1, 1, 1))
	end
	if RunService:IsStudio() then -- a way to try the upgrades without fighting for them
		Style.button(ranch.count, "Test funds", function()
			send("funds")
		end, "ghost", UDim2.fromOffset(120, 36)).TextSize =
			14
	end
end

return nil
