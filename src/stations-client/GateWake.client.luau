--!strict
-- The Hexbound's gate wakes up as a stage goes on (decision 0106). While this player's fight is on
-- (WaveShow sets their `FightWave`), the wave's place in its stage (`LevelRules.stage`) wakes the gate in
-- this player's view only: 1 to 3 its eyes are shut; 4 to 6 the eyes in its columns open; 7 to 9 the
-- braziers turn violet, a pair more each wave, from the gate towards the team; 10 the big eye opens and
-- the portal burns red. With no fight on, everything is as Arena.luau built it (tags `GateEye`,
-- `GateBigEye`, `Brazier` with `D`, `ArenaGate`). Display only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LevelRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LevelRules"))

local player = Players.LocalPlayer

local SHUT = Color3.fromRGB(34, 28, 44)
local AWAKE = Color3.fromRGB(255, 60, 140)
local VIOLET_HOT, VIOLET_COLD = Color3.fromRGB(170, 90, 255), Color3.fromRGB(80, 30, 160)
local RED, RED_DEEP = Color3.fromRGB(255, 50, 90), Color3.fromRGB(70, 10, 24)
local BUILT_VIOLET = 110 -- Arena.luau's braziers this far in (D) burn violet as built
local STEP = 32 -- the braziers' spacing: one more pair turns violet each wave from the 7th

-- Each part's look as built, read the first time it is seen.
type Look = { colour: Color3, material: Enum.Material, light: Color3?, bright: number?, fire: ColorSequence? }
local built: { [BasePart]: Look } = {}
local function look(p: BasePart): Look
	local l = built[p]
	if l == nil then
		local light = p:FindFirstChildOfClass("PointLight")
		local fire = p:FindFirstChildOfClass("ParticleEmitter")
		l = {
			colour = p.Color,
			material = p.Material,
			light = if light then light.Color else nil,
			bright = if light then light.Brightness else nil,
			fire = if fire then fire.Color else nil,
		}
		built[p] = l
		p.Destroying:Once(function()
			built[p] = nil
		end)
	end
	return l :: Look
end

local function paint(p: BasePart, colour: Color3, material: Enum.Material, light: Color3?, bright: number?)
	p.Material = material
	TweenService:Create(p, TweenInfo.new(0.6), { Color = colour }):Play()
	local l = p:FindFirstChildOfClass("PointLight")
	if l and light then
		TweenService:Create(l, TweenInfo.new(0.6), { Color = light, Brightness = bright or l.Brightness }):Play()
	end
end

local function fire(p: BasePart, colours: ColorSequence?, light: Color3?)
	for _, c in p:GetChildren() do
		if c:IsA("ParticleEmitter") and colours then
			c.Color = colours
		elseif c:IsA("PointLight") and light then
			c.Color = light
		end
	end
end

local function wake()
	local wave = player:GetAttribute("FightWave")
	local place = if type(wave) == "number" then wave - LevelRules.stage(wave).first + 1 else nil
	for _, inst in CollectionService:GetTagged("GateEye") do
		if inst:IsA("BasePart") then
			local l = look(inst)
			if place == nil or place >= 4 then
				paint(inst, l.colour, l.material)
			else
				paint(inst, SHUT, Enum.Material.Slate)
			end
		end
	end
	for _, inst in CollectionService:GetTagged("GateBigEye") do
		if inst:IsA("BasePart") then
			local l = look(inst)
			if place == nil then
				paint(inst, l.colour, l.material, l.light, l.bright)
			elseif place >= LevelRules.STAGE then
				paint(inst, AWAKE, Enum.Material.Neon, AWAKE, (l.bright or 2) * 2)
			else
				paint(inst, SHUT, Enum.Material.Slate, l.light, 0)
			end
		end
	end
	local from = if place and place >= 7 then BUILT_VIOLET - STEP * (place - 6) else BUILT_VIOLET
	for _, inst in CollectionService:GetTagged("Brazier") do
		if inst:IsA("BasePart") then
			local l = look(inst)
			local d = inst:GetAttribute("D")
			if place and type(d) == "number" and d >= from then
				fire(inst, ColorSequence.new(VIOLET_HOT, VIOLET_COLD), VIOLET_HOT)
			else
				fire(inst, l.fire, l.light)
			end
		end
	end
	for _, inst in CollectionService:GetTagged("ArenaGate") do
		if inst:IsA("BasePart") then
			local l = look(inst)
			if place and place >= LevelRules.STAGE then
				paint(inst, RED, l.material, RED, l.bright)
				fire(inst, ColorSequence.new(RED, RED_DEEP), nil)
			else
				paint(inst, l.colour, l.material, l.light, l.bright)
				fire(inst, l.fire, nil)
			end
		end
	end
end

player:GetAttributeChangedSignal("FightWave"):Connect(wake)
for _, tag in { "GateEye", "GateBigEye", "Brazier", "ArenaGate" } do -- parts that stream in late
	CollectionService:GetInstanceAddedSignal(tag):Connect(function()
		task.defer(wake)
	end)
end
wake()
