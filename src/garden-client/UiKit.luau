--!strict
-- Egg Garden's UI kit: the shared studio kit (src/kit-roblox/modules/UiKit.luau, moved there in
-- LANTERN-005) configured with the Garden theme, plus `eggDisc`, which only Garden draws. Menu,
-- Hud, TradeFx, DashFx and the panels require this module as before (architecture garden 6.4).

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenIcons = require(Shared:WaitForChild("GardenIcons"))
local Kit = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("UiKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local UI = ClientState.UI

export type Panel = Kit.Panel
export type Button = Kit.Button
export type Card = Kit.Card
export type Toast = Kit.Toast
export type StripItem = Kit.StripItem

-- An egg disc in the egg's two shell colours.
local function eggDisc(parent: Instance, egg: string, size: number, props: { [string]: any }?): Frame
	local colours = ClientState.EGG_COLOURS[egg] or ClientState.EGG_COLOURS.starter
	local p = props or {}
	p.Name = "EggDisc"
	p.Size = UDim2.fromOffset(math.floor(size * 0.8), size)
	p.BackgroundColor3 = UI.WHITE
	p.Parent = parent
	return Kit.new("Frame", p, {
		Kit.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Kit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(colours[1], colours[2]) }),
		Kit.new("UIStroke", { Color = UI.WHITE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
end

Kit.configure({
	tokens = UI,
	fonts = { body = Enum.Font.FredokaOne, title = Enum.Font.FredokaOne },
	icons = GardenIcons :: any,
	sound = function(name: string, volume: number, pitch: number?)
		ClientState.sound((ClientState.SFX :: any)[name], volume, nil, pitch)
	end,
	short = ClientState.short,
	rarity = { colour = ClientState.rarityColour, name = ClientState.rarityName },
	species = function(id: string): string
		local sp = GardenConfig.species(id)
		return if sp then sp.name else id
	end,
	previews = "GardenSpecies",
	accent = ClientState.ACCENT,
	menu = {
		words = { "EGG", "GARDEN" },
		tagline = "Hatch it. Grow it. Collect them all.",
		haze = { Color3.fromRGB(255, 225, 238), Color3.fromRGB(255, 240, 225) },
		face = UI.PINK,
		faceLine = UI.WHITE,
		shade = UI.INK_SOFT,
		play = UI.LEAF,
		decorate = function(first: Frame)
			eggDisc(first, "meadow", 64, { Position = UDim2.fromOffset(-30, 22), Rotation = -14, ZIndex = 0 })
		end,
	},
})

-- The egg models for the egg cards (QA m4): a ViewportFrame shows them grey until loaded.
task.spawn(function()
	local eggs = ReplicatedStorage:WaitForChild("GardenEggs", 120)
	if eggs then
		pcall(ContentProvider.PreloadAsync, ContentProvider, eggs:GetChildren())
	end
end)

local UiKit = table.clone(Kit) :: any
UiKit.eggDisc = eggDisc
return UiKit :: typeof(Kit) & { eggDisc: typeof(eggDisc) }
