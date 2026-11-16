--!strict
-- The six training areas of a ranch (decision 0065): each stands in a clearing of its own beyond the
-- ranch's mountains (World.areaFrame), at the end of a pass. An area is made of the Blender models
-- `area_<station>_<first>_<last>` (tools/blender/stations/assets/areas.py): each holds what stands
-- from Training Grounds level `first` to level `last`, so a level's look is every model whose stretch
-- holds it. The models take no collisions: `SOLID` lists the unseen blocks an area needs to be walked
-- on, read off tools/blender/stations/scenes/training.py in its own numbers (x east and y north of the
-- yard's middle, z up, before the yard is grown K times): change the two together.
-- Display only: no game rules live here.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Props = require(script.Parent:WaitForChild("Props"))
local World = require(script.Parent:WaitForChild("World"))
local Creatures = require(script.Parent:WaitForChild("Creatures"))
local StationAssets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationAssets"))
local StationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationConfig"))

local Areas = {}

local K = 2.5 -- how many times an area is grown from the yard it is written as (training.py's K)
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(45, 40, 55)
local YARD = { 1, 5, -33.5, 33.5, -25.5, 25.5, 0.25 } -- every area's floor, from level 1

Areas.COLOUR = {
	speed = Color3.fromRGB(60, 150, 255),
	strength = Color3.fromRGB(235, 70, 70),
	stamina = Color3.fromRGB(170, 90, 245),
	mana = Color3.fromRGB(60, 215, 225),
	health = Color3.fromRGB(70, 205, 120),
	defence = Color3.fromRGB(255, 165, 50),
} :: { [string]: Color3 }

-- Unseen blocks from the ground up: { first level, last level, x0, x1, y0, y1, top }, or round ones:
-- { first level, last level, x, y, radius, top }.
local SOLID: { [string]: { { number } } } = {
	track = {
		YARD,
		{ 4, 5, -15, 7, 15.9, 18.1, 1.35 }, -- the stand's four rows
		{ 4, 5, -15, 7, 18.1, 20.3, 2.45 },
		{ 4, 5, -15, 7, 20.3, 22.5, 3.55 },
		{ 4, 5, -15, 7, 22.5, 24.7, 4.65 },
	},
	gym = { YARD, { 2, 5, -28, -6, 5.5, 18.5, 0.95 } }, -- the lifting deck
	pool = {
		YARD,
		{ 1, 5, -30.8, 28.6, -15.4, -8.2, 1.75 }, -- the deck, round the water
		{ 1, 5, -30.8, 28.6, 10.2, 15.4, 1.75 },
		{ 1, 5, -30.8, -24.2, -8.2, 10.2, 1.75 },
		{ 1, 5, 16.2, 28.6, -8.2, 10.2, 1.75 },
		{ 1, 5, -24.2, 16.2, -8.2, 10.2, 1.4 }, -- the water: it is stood on
		{ 1, 5, -6, 6, -16.4, -15.4, 1.75 }, -- the steps up from the gate
		{ 1, 5, -6, 6, -17.4, -16.4, 1.375 },
		{ 1, 5, -6, 6, -18.4, -17.4, 1 },
		{ 1, 5, -6, 6, -19.4, -18.4, 0.625 },
	},
	library = { YARD, { 1, 5, 0, 2, 16.6, 0.55 } }, -- the slate floor
	spring = {
		YARD,
		{ 1, 5, 0, 1, 22.6, 0.45 }, -- the terrace
		{ 1, 5, 0, 1, 6.05, 1.2 }, -- the source's basin
		{ 1, 5, -6.8, -10.78, 5.25, 1.2 }, -- the baths, two more at each of the next levels
		{ 1, 5, 6.8, -10.78, 5.25, 1.2 },
		{ 2, 5, 13.6, 1, 5.25, 1.2 },
		{ 2, 5, -13.6, 1, 5.25, 1.2 },
		{ 3, 5, 6.8, 12.78, 5.25, 1.2 },
		{ 3, 5, -6.8, 12.78, 5.25, 1.2 },
	},
	guard = {
		YARD,
		{ 1, 5, -25, 25, -19.5, 15.5, 0.37 }, -- the court
		{ 3, 5, -20, 20, 17.8, 20.2, 7.75 }, -- the wall
		{ 4, 5, -23.5, 19, 4.2, 13.35 }, -- its towers
		{ 4, 5, 23.5, 19, 4.2, 13.35 },
	},
}

-- the models of each station, with the levels each stands at
local pieces: { [string]: { { name: string, first: number, last: number } } } = {}
for name in StationAssets do
	local station, first, last = string.match(name, "^area_(%a+)_(%d)_(%d)$")
	if station then
		pieces[station] = pieces[station] or {}
		table.insert(
			pieces[station],
			{ name = name, first = tonumber(first) :: number, last = tonumber(last) :: number }
		)
	end
end

-- Stands ranch `i`'s six areas as they are at Training Grounds `level`, in `parent`: the models, the
-- unseen blocks, a pad tagged "TrainPad" (Ranch, Station) at each area's middle, and each area's
-- name over its path where that leaves the ranch.
function Areas.build(parent: Instance, i: number, level: number)
	local ranch = World.ranchFrame(i)
	for k, st in StationConfig.STATIONS do
		local cf = World.areaFrame(i, k)
		local f = Instance.new("Folder")
		f.Name = st.id
		f.Parent = parent
		for _, piece in pieces[st.id] or {} do
			if piece.first <= level and level <= piece.last then
				task.spawn(Creatures.still, piece.name, cf * CFrame.Angles(0, math.pi, 0), 1, f) -- each has to load
			end
		end
		for _, s in SOLID[st.id] do
			if s[1] <= level and level <= s[2] then
				local block: Part
				if #s == 6 then
					block =
						Props.pillar(f, (cf * CFrame.new(s[3] * K, 0, -s[4] * K)).Position, s[6] * K, s[5] * K, WHITE)
				else
					local size = Vector3.new((s[4] - s[3]) * K, s[7] * K, (s[6] - s[5]) * K)
					local middle = CFrame.new((s[3] + s[4]) / 2 * K, s[7] * K / 2, -(s[5] + s[6]) / 2 * K)
					block = Props.part(f, size, cf * middle, WHITE)
				end
				block.Transparency, block.CastShadow, block.Name = 1, false, "Solid"
			end
		end
		local pad = Props.part(f, Vector3.new(4, 0.2, 4), cf * CFrame.new(0, 0.1, 0), WHITE)
		pad.Name, pad.Transparency, pad.CanCollide = st.id, 1, false
		pad:SetAttribute("Ranch", i)
		pad:SetAttribute("Station", st.id)
		CollectionService:AddTag(pad, "TrainPad")
		-- the sign stands over the path, a little way out of the plot's fence
		local from = (ranch * CFrame.new(World.AREA_GATE[k])).Position
		local along = ((cf.Position - cf.LookVector * 62 - from) * Vector3.new(1, 0, 1)).Unit
		local colour = Areas.COLOUR[st.stat]:Lerp(INK, 0.25)
		World.kit.signboard(f, CFrame.lookAt(from + along * 24, from), 18, st.name, colour, 9)
	end
end

return Areas
