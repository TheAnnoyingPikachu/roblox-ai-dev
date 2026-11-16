--!strict
-- Animal Stations training kit (decision 0067): moves the kit of the training areas on this client.
-- The server stands every piece and tags what moves "Kit", with a `Kit` attribute that says how; the
-- station's folder says what its animal is working at (`Work`) and how big it is (`WorkHeight`,
-- `WorkScale`). The timings are TrainFx's, the same the animal's own clip is drawn from, so the two
-- stay together. Display only: nothing here decides or delays any training.
--   bar      the gym's barbell: comes down onto the animal's back and sinks and rises with it
--   ram      a guard yard ram: hangs at the height of the animal's head and swings at it
--   boulder  the gym's boulder: shoved along as the animal drives, and rolls back
--   dummies  the guard yard's straw men: lurch at the animal as the blow lands
--   crystal  the library's great crystal: turns and bobs, faster while an animal reads
--   spin     a Neon piece that turns about its own middle (the library's rings of light)
--   pulse    a Neon piece that glows and dims (runes, channels, lanterns, arrows)
--   flicker  the same, quick and uneven (flames, candles)
--   lob      a thrower: lobs a ball at the shield it faces

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TrainFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrainFx"))

type Piece = { kind: string, rest: CFrame, folder: Instance?, ease: number, ball: Part? }
local pieces: { [Instance]: Piece } = {}

-- The station's folder: the nearest ancestor that is a Folder (a piece is in it, or in a model in it).
local function stationOf(inst: Instance): Instance?
	local up = inst.Parent
	while up and not up:IsA("Folder") do
		up = up.Parent
	end
	return up
end

local function add(inst: Instance)
	local kind = inst:GetAttribute("Kit")
	if type(kind) ~= "string" or not (inst:IsA("Model") or inst:IsA("BasePart")) then
		return
	end
	local rest = if inst:IsA("Model") then inst:GetPivot() else (inst :: BasePart).CFrame
	pieces[inst] = { kind = kind, rest = rest, folder = stationOf(inst), ease = 0 }
end

local function remove(inst: Instance)
	local piece = pieces[inst]
	if piece and piece.ball then
		piece.ball:Destroy()
	end
	pieces[inst] = nil
end

CollectionService:GetInstanceAddedSignal("Kit"):Connect(add)
CollectionService:GetInstanceRemovedSignal("Kit"):Connect(remove)
for _, inst in CollectionService:GetTagged("Kit") do
	add(inst)
end

local function number(inst: Instance?, name: string, fallback: number): number
	local v = inst and inst:GetAttribute(name)
	return if type(v) == "number" then v else fallback
end

RunService.PreRender:Connect(function(dt: number)
	local time = Workspace:GetServerTimeNow()
	for inst, piece in pieces do
		local kind, rest, folder = piece.kind, piece.rest, piece.folder
		-- how much this piece is at work: eased, so it settles onto an animal and back to rest
		local busy = folder ~= nil and folder:GetAttribute("Work") == kind
		piece.ease += ((if busy then 1 else 0) - piece.ease) * math.min(1, dt * 5)
		local on = piece.ease
		if kind == "bar" then
			-- its axis comes down to the animal's back (never so low that its discs meet the deck)
			local high, least = number(inst, "High", 12), number(inst, "Least", 6.8)
			local back = math.max(number(folder, "WorkHeight", high) * 0.95, least)
			local down = (TrainFx.heave(time))
			local y = (back - high - 0.2 * number(folder, "WorkScale", 1) * down) * on;
			(inst :: Model):PivotTo(rest + Vector3.new(0, y, 0))
		elseif kind == "ram" then
			-- lowered on its ropes to the animal's head, it swings back from the blow and in again
			local high, least = number(inst, "High", 8.1), number(inst, "Least", 3.7)
			local drop = high - math.clamp(number(folder, "WorkHeight", high / 0.75) * 0.75, least, high)
			local rope = number(inst, "Rope", 12.5) + drop
			local angle = math.rad(TrainFx.SWING) * TrainFx.swing(time)
			local back = inst:GetAttribute("Back") :: Vector3
			local move = back * rope * math.sin(angle) + Vector3.new(0, rope * (1 - math.cos(angle)) - drop, 0);
			(inst :: Model):PivotTo(rest + move * on)
		elseif kind == "boulder" then
			local along = inst:GetAttribute("Along") :: Vector3
			(inst :: Model):PivotTo(rest + along * 2.2 * TrainFx.push(time) * on)
		elseif kind == "dummies" then
			-- they lurch about the line their posts stand on
			local foot, axis = inst:GetAttribute("Foot") :: Vector3, inst:GetAttribute("Along") :: Vector3
			local lean = CFrame.fromAxisAngle(axis, math.rad(9) * TrainFx.brace(time) * on);
			(inst :: Model):PivotTo(CFrame.new(foot) * lean * CFrame.new(-foot) * rest)
		elseif kind == "crystal" then
			local axis = inst:GetAttribute("Foot") :: Vector3
			local turn = CFrame.Angles(0, time * (0.35 + 0.5 * on), 0)
			local bob = Vector3.new(0, 0.5 * math.sin(time * 1.3), 0);
			(inst :: Model):PivotTo(CFrame.new(axis + bob) * turn * CFrame.new(-axis) * rest)
		elseif kind == "spin" then
			(inst :: BasePart).CFrame = CFrame.new(rest.Position) * CFrame.Angles(0, time * 0.7, 0) * rest.Rotation
		elseif kind == "pulse" then
			(inst :: BasePart).Transparency = 0.3 + 0.3 * math.sin(time * 2.2)
		elseif kind == "flicker" then
			(inst :: BasePart).Transparency = 0.12 + 0.12 * math.sin(time * 13) + 0.1 * math.sin(time * 7.3)
		elseif kind == "lob" then
			-- a ball leaves the thrower every few seconds and arcs to the shield
			local ball = piece.ball
			if ball == nil then
				ball = Instance.new("Part")
				ball.Shape, ball.Size = Enum.PartType.Ball, Vector3.new(2.6, 2.6, 2.6)
				ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
				ball.Color, ball.Material = (inst :: BasePart).Color, Enum.Material.SmoothPlastic
				ball.Parent = inst
				piece.ball = ball
			end
			local u = ((time + number(inst, "Phase", 0)) % 3.2) / 1.1
			local from, to = rest.Position, inst:GetAttribute("To") :: Vector3
			(ball :: Part).Transparency = if u < 1 then 0 else 1
			if u < 1 then
				(ball :: Part).Position = from:Lerp(to, u) + Vector3.new(0, 9 * u * (1 - u), 0)
			end
		end
	end
end)
