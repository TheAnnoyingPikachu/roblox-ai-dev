--!strict
-- Baked clips (decision 0133): an animal made by the rig pipeline (tools/blender/stations/rigs) has knees, a spine, a
-- neck and a tail of several bones, and its clips are keyed in Blender with its feet held on the ground, then baked
-- bone by bone into a module here named after its asset (written by export_game.py; never by hand). Creatures.client
-- asks `Clips.pose` for every model each frame: an asset with a module is posed from it, any other as before.
--
-- A module: `bones` (parents before children), `moved` (the first so many bones also move: the root and the body),
-- `height` (studs, as built) and `clips` by the game's names (idle, walk, attack, magic, hit, die, win), each its
-- `length` in seconds, `loop`, a walk's `stride` (studs of ground one cycle covers) and `data`, one string a frame.
-- A frame holds, for each bone in order, its turn as a quaternion's x, y, z (w is positive) and, for a moved bone,
-- where it has moved to: three characters a number. Both are in the Root's axes (x right, y up, -z forward), on top
-- of the parent's, so a bone's own axes do not matter: its rest frame, measured here, turns them into its own.

local Clips = {}

local STEP = 2.63 -- studs a stride covers at Scale 1: the server moves a walking animal by it (Creatures.luau)
local FADE = 0.12 -- seconds one clip takes to give way to the next
local REACH = 32 -- studs a moved bone can be from its rest place (export_game.py's)
local TOP = 64 ^ 3 - 1
local A64 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
local VALUE: { [number]: number } = {}
for i = 1, #A64 do
	VALUE[string.byte(A64, i)] = i - 1
end

type Clip = {
	length: number,
	loop: boolean,
	stride: number?,
	data: { string },
	frames: { { CFrame } }?, -- `data` read, the first time the clip plays
}
type Data = { height: number, moved: number, bones: { string }, clips: { [string]: Clip } }
type Named = { [string]: { bone: Bone, turn: CFrame } }
type Bound = {
	data: Data,
	bones: { Bone },
	turn: { CFrame }, -- each bone's rest frame in the Root's axes
	back: { CFrame }, -- and its inverse
	named: Named, -- the same by name: what Creatures.client's effects and the spells take
	clip: string?, -- the clip on screen
	since: number, -- os.clock() when it took over
	from: { CFrame }, -- the pose it took over from
	now: { CFrame }, -- the pose on screen
}

local loaded: { [string]: Data | false } = {}
local bound: { [Model]: Bound } = setmetatable({}, { __mode = "k" }) :: any
local waiting: { [Model]: { since: number, tried: number, warned: boolean } } = setmetatable({}, { __mode = "k" }) :: any

local function dataOf(asset: string): Data?
	local data = loaded[asset]
	if data == nil then
		local module = script:FindFirstChild(asset)
		data = if module and module:IsA("ModuleScript") then (require :: any)(module) else false
		loaded[asset] = data
	end
	return data or nil
end

local function num(s: string, i: number, lo: number, hi: number): number
	local a, b, c = string.byte(s, i, i + 2)
	return lo + (VALUE[a] * 4096 + VALUE[b] * 64 + VALUE[c]) / TOP * (hi - lo)
end

local function framesOf(data: Data, clip: Clip): { { CFrame } }
	local frames = clip.frames
	if frames == nil then
		frames = table.create(#clip.data)
		for f, s in clip.data do
			local row, i = table.create(#data.bones), 1
			for b = 1, #data.bones do
				local x, y, z = num(s, i, -1, 1), num(s, i + 3, -1, 1), num(s, i + 6, -1, 1)
				local w = math.sqrt(math.max(0, 1 - x * x - y * y - z * z))
				local px, py, pz = 0, 0, 0
				i += 9
				if b <= data.moved then
					px, py, pz = num(s, i, -REACH, REACH), num(s, i + 3, -REACH, REACH), num(s, i + 6, -REACH, REACH)
					i += 9
				end
				row[b] = CFrame.new(px, py, pz, x, y, z, w)
			end
			frames[f] = row
		end
		clip.frames = frames
	end
	return frames :: { { CFrame } }
end

-- A model's bones as its module lists them; nil until its mesh and every bone have reached this client.
local function bind(model: Model, data: Data): Bound?
	local root = model.PrimaryPart
	local mesh = model:FindFirstChild(`{model:GetAttribute("Asset")}_body`)
	if root == nil or mesh == nil or not mesh:IsA("BasePart") then
		return nil
	end
	local found: { [string]: Bone } = {}
	for _, d in mesh:GetDescendants() do
		if d:IsA("Bone") then
			found[d.Name] = d
		end
	end
	local b: Bound =
		{ data = data, bones = {}, turn = {}, back = {}, named = {}, clip = nil, since = 0, from = {}, now = {} }
	local base = root.CFrame:Inverse() * mesh.CFrame
	for i, name in data.bones do
		local bone = found[name]
		if bone == nil then
			return nil
		end
		-- its rest frame from its own and its parents' rest CFrames: its WorldCFrame would hold their poses too
		local rest = bone.CFrame
		local up = bone.Parent
		while up and up:IsA("Bone") do
			rest = up.CFrame * rest
			up = up.Parent
		end
		local turn = (base * rest).Rotation
		b.bones[i], b.turn[i], b.back[i] = bone, turn, turn:Inverse()
		b.named[name] = { bone = bone, turn = turn }
	end
	return b
end

-- Which clip shows the animation `anim`, `t` seconds in, and where in it (seconds).
local function chosen(model: Model, data: Data, anim: string?, t: number, time: number, size: number): (string, number)
	local clips = data.clips
	if anim == "die" then
		return "die", t -- (held at its end)
	elseif anim == "walk" or anim == "run" then
		local speed = STEP
			* ((model:GetAttribute("Scale") :: number?) or 1)
			* ((model:GetAttribute("Stride") :: number?) or 1.5)
		-- a cycle for every stride of ground the server moves it, so its planted feet do not slide
		return "walk", (time * speed / ((clips.walk.stride or 1) * size)) % 1 * clips.walk.length
	elseif (anim == "attack" or anim == "magic" or anim == "hit" or anim == "win") and t < clips[anim].length then
		-- (a win is played once, then it stands easy: its last pose is not its first)
		return anim :: string, t
	end
	-- shortcut: the training clips (heave, swim, study, soak, brace) and the Titan's sleep show the idle; give the
	-- pipeline's animals their own when one of them is seen training
	return "idle", time % clips.idle.length
end

-- Poses `model` for `anim`, `t` seconds in (`time` is the clock its loops run on). False when its asset has no baked
-- clips: the caller poses it. With them, the second result is its bones by name once they have all arrived.
function Clips.pose(model: Model, anim: string?, t: number, time: number): (boolean, Named?)
	local asset = model:GetAttribute("Asset")
	local data = if type(asset) == "string" then dataOf(asset) else nil
	if data == nil then
		return false, nil
	end
	local b = bound[model]
	if b == nil then
		-- its mesh and bones reach this client a little after its tag: look again twice a second, and say so once if a
		-- bone its clips list never comes (the model and its clips are out of step)
		local w = waiting[model] or { since = os.clock(), tried = 0, warned = false }
		waiting[model] = w
		if os.clock() - w.tried < 0.5 then
			return true, nil
		end
		w.tried = os.clock()
		b = bind(model, data)
		if b == nil then
			if not w.warned and os.clock() - w.since > 10 then
				w.warned = true
				warn(`[Clips] {asset}: its mesh or one of its {#data.bones} bones is missing; it is not animated`)
			end
			return true, nil
		end
		waiting[model] = nil
		bound[model] = b
	end
	local it = b :: Bound
	local hit = model:FindFirstChild("Hit")
	local size = if hit and hit:IsA("BasePart") then hit.Size.Y / data.height else 1 -- (a model stood larger or smaller)
	local name, at = chosen(model, data, anim, t, time, size)
	local clip = data.clips[name]
	local frames = framesOf(data, clip)
	local clock = os.clock()
	if it.clip ~= name then
		it.clip, it.since = name, if it.clip == nil then -FADE else clock
		it.from = table.clone(it.now)
	end
	local last = if clip.loop then #frames else #frames - 1
	local u = math.clamp(at / clip.length, 0, 1) * last
	local i = math.min(math.floor(u), #frames - 1)
	local a, b0 = frames[i + 1], frames[if clip.loop then (i + 1) % #frames + 1 else math.min(i + 2, #frames)]
	local k = math.min(1, (clock - it.since) / FADE)
	k = k * k * (3 - 2 * k)
	for j, bone in it.bones do
		local goal = a[j]:Lerp(b0[j], u - i)
		if k < 1 and it.from[j] then
			goal = it.from[j]:Lerp(goal, k)
		end
		it.now[j] = goal
		if j <= data.moved and size ~= 1 then
			goal = goal.Rotation + goal.Position * size
		end
		bone.Transform = it.back[j] * goal * it.turn[j]
	end
	return true, it.named
end

return Clips
