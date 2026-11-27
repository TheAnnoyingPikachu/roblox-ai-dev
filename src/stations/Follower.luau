--!strict
-- One animal follows its owner around (decision 0128, Round 2 build 5 D): the first animal of the team, at pet
-- size (no taller than PET_HEIGHT), walking a few studs behind the player at its own walking speed. It waits
-- out a fight (the player's FightWave attribute) and jumps to the player when far behind (a teleport). Display
-- only: it never touches a save.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local StationAssets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationAssets"))
local Creatures = require(script.Parent:WaitForChild("Creatures"))

local Follower = {}

Follower.PET_HEIGHT, Follower.BEHIND, Follower.SIDE = 4, 5, 3 -- studs
Follower.NEAR, Follower.FAR, Follower.TICK = 2.5, 60, 0.4

local folder = Instance.new("Folder")
folder.Name = "Followers"
folder.Parent = Workspace

type Pet = { key: string, model: Model?, running: boolean }
local pets: { [Player]: Pet } = {}

local function ground(at: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, ignore
	local hit = Workspace:Raycast(at + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else at
end

local function follow(player: Player, pet: Pet)
	while pets[player] == pet and pet.model and pet.model.Parent do
		local model = pet.model :: Model
		local root = model.PrimaryPart :: BasePart
		local character = player.Character
		local hrp = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if hrp == nil or player:GetAttribute("FightWave") then -- no character, or in a fight: wait out of sight
			root.CFrame = CFrame.new(0, -500, 0)
			Creatures.play(model, "idle")
		else
			local back = hrp.CFrame * CFrame.new(Follower.SIDE, 0, Follower.BEHIND)
			local to = ground(back.Position, { folder, character :: Model })
			local from = root.Position
			local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
			if flat.Magnitude > Follower.FAR then -- far behind (a teleport, or just spawned): there at once
				root.CFrame = CFrame.lookAt(to, to + hrp.CFrame.LookVector * Vector3.new(1, 0, 1))
				Creatures.play(model, "idle")
			elseif flat.Magnitude > Follower.NEAR then
				if model:GetAttribute("Anim") ~= "walk" then
					Creatures.play(model, "walk")
				end
				local seconds = math.clamp(flat.Magnitude / Creatures.speed(model), 0.15, Follower.TICK * 2)
				local goal = CFrame.lookAt(to, to + flat.Unit)
				TweenService:Create(root, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { CFrame = goal }):Play()
			elseif model:GetAttribute("Anim") ~= "idle" then
				Creatures.play(model, "idle")
			end
		end
		task.wait(Follower.TICK)
	end
end

-- Keep `player`'s pet as `first` (the team's first animal, from the save), or none.
function Follower.sync(player: Player, first: any?)
	local key = if first then `{first.s}/{first.v or ""}/{first.coat or tostring(first.rainbow)}` else ""
	local pet = pets[player]
	if pet and pet.key == key then
		return
	end
	if pet and pet.model then
		pet.model:Destroy()
	end
	pets[player] = nil
	if first == nil then
		return
	end
	local mine: Pet = { key = key, model = nil, running = false }
	pets[player] = mine
	task.spawn(function()
		local asset = Creatures.asset(first.s, first.v)
		local size = StationAssets[asset] and StationAssets[asset].size or { 4, 4, 4 }
		local fit = math.min(1, Follower.PET_HEIGHT / math.max(size[2], 0.1))
		local model = Creatures.spawn(
			asset,
			CFrame.new(0, -500, 0),
			folder,
			{ model = asset, size = fit },
			first.coat or first.rainbow
		)
		if model == nil or pets[player] ~= mine then
			if model then
				model:Destroy()
			end
			return
		end
		Creatures.describe(model, first.s, first.v, first)
		model.Name = `{player.Name}_pet`
		mine.model = model
		follow(player, mine)
	end)
end

function Follower.remove(player: Player)
	Follower.sync(player, nil)
end

return Follower
