--!strict
-- The egg vendor's sheet: every egg with its picture, price, odds and the level that unlocks it.
-- One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationProgress = require(Shared:WaitForChild("StationProgress"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local Format = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Format"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Style = require(script.Parent:WaitForChild("Style"))
local App: any = require(script.Parent:WaitForChild("HudApp"))
local S = App.S
local C = App.C
local RARITY_COLOUR = App.RARITY_COLOUR
local screen = App.screen
local send = App.send
local redraw = App.redraw
local shop = App.shop
local darker = App.darker
local eggArt = App.eggArt

-- Egg vendor --------------------------------------------------------------------------------------------

-- An egg's card (decision 0078): the egg, its price and time; the animals it hatches, each named under its
-- picture; its rare finds in one row, each edged in its tier's colour. How rare a find is shows when it
-- hatches, not here.
local function animalCell(parent: Instance, order: number, asset: string, label: string?, colour: Color3, side: number)
	local cell = Instance.new("Frame")
	cell.BackgroundTransparency = 1
	cell.Size = UDim2.fromOffset(side, side + (if label then 16 else 0))
	cell.LayoutOrder = order
	cell.Parent = parent
	local view = Portrait.new(cell, asset, { size = UDim2.fromOffset(side, side), background = darker(colour) })
	Style.round(view, 10)
	Style.stroke(view, colour, 3)
	if label then
		local t = Style.text(cell, label, 12, C.muted, UDim2.fromOffset(side + 6, 14))
		t.Position = UDim2.fromOffset(-3, side + 2)
		t.TextXAlignment = Enum.TextXAlignment.Center
		t.TextTruncate = Enum.TextTruncate.AtEnd
	end
end

local shopEgg = 1 -- the egg the vendor shows
redraw.shop = function()
	Style.clear(shop.body)
	Style.clear(shop.chips)
	Style.clear(shop.tabs)
	for k, d in StationConfig.EGGS do
		local closed = d.wave ~= nil and S.profile.best < d.wave
		local tab = Style.tab(shop, d.name, shopEgg == k, function()
			shopEgg = k
			redraw.shop()
		end)
		tab.Text = `{d.name}\n{if closed then `Wave {d.wave}` else Format.short(d.price)}`
		tab.TextSize, tab.TextYAlignment, tab.Size = 17, Enum.TextYAlignment.Center, UDim2.fromOffset(196, 56)
		if closed then
			Style.kind(tab, "off")
		end
	end
	Style.amount(shop.chips, "coins", Format.commas(S.profile.coins))
	Style.chip(shop.chips, `Level {StationProgress.playerLevel(S.profile)} · best wave {S.profile.best}`)

	local def = StationConfig.EGGS[shopEgg]
	local locked = def.level ~= nil and StationProgress.playerLevel(S.profile) < def.level
	local head = Instance.new("Frame")
	head.BackgroundTransparency = 1
	head.Size, head.LayoutOrder = UDim2.new(1, -8, 0, 110), 1
	head.Parent = shop.body
	eggArt(head, def.id, 104)
	local name = Style.text(head, def.name, 34, C.text, UDim2.new(1, -124, 0, 40))
	name.Position = UDim2.fromOffset(120, 8)
	local price = Instance.new("Frame")
	price.BackgroundTransparency = 1
	price.Position, price.Size = UDim2.fromOffset(120, 54), UDim2.new(1, -124, 0, 28)
	Style.list(price, 10, true)
	price.Parent = head
	Style.amount(price, "coins", Format.commas(def.price))
	Style.chip(price, `Hatches in {Format.ago(StationProgress.hatchSeconds(S.profile, def))}`)
	if locked then
		Style.chip(price, `Reach level {def.level} to unlock`, C.bad, Color3.new(1, 1, 1))
	end
	local hatches = Style.text(
		shop.body,
		if def.only then "VARIANTS ONLY: EVERY HATCH IS ONE OF THESE" else "HATCHES",
		14,
		C.muted,
		UDim2.new(1, -8, 0, 18)
	)
	hatches.LayoutOrder = 2
	local basics = Instance.new("Frame")
	basics.BackgroundTransparency = 1
	basics.Size, basics.LayoutOrder, basics.Visible = UDim2.new(1, -8, 0, 92), 3, not def.only
	Style.list(basics, 8, true)
	basics.Parent = shop.body
	for i, o in def.odds do
		local sp = StationConfig.species(o.id) :: StationConfig.Species
		animalCell(basics, i, StationRules.assetOf(o.id, nil), sp.name, RARITY_COLOUR[sp.rarity] or C.text, 72)
	end
	local finds = Style.text(shop.body, if def.only then "" else "RARE FINDS", 14, C.muted, UDim2.new(1, -8, 0, 18))
	finds.LayoutOrder = 4
	local rare = Instance.new("Frame")
	rare.BackgroundTransparency = 1
	rare.Size, rare.LayoutOrder = UDim2.new(1, -8, 0, 64), 5
	Style.list(rare, 8, true)
	rare.Parent = shop.body
	local side = math.min(58, (600 - 8 * (#def.rare - 1)) // math.max(1, #def.rare)) -- one row, however many
	for i, drop in def.rare do
		local tier = (StationConfig.variant(drop.s, drop.v) :: StationConfig.Variant).tier
		animalCell(rare, i, StationRules.assetOf(drop.s, drop.v), nil, RARITY_COLOUR[tier] or C.text, side)
	end
	local can = not locked and S.profile.coins >= def.price
	local b = Style.button(shop.body, `Buy for {Format.commas(def.price)}`, function()
		if locked then
			Style.toast(screen, `Reach level {def.level} to unlock the {def.name}`, nil, "bad")
			return
		end
		send("buy", def.id)
	end, if can then "primary" else "off", UDim2.new(1, -12, 0, 56))
	b.LayoutOrder, b.TextSize = 6, 24
end

return nil
