--!strict
-- Animates every creature model (tag "Creature", built by stations/Creatures.luau). The server
-- sets each model's Anim ("idle", "walk", "attack", "magic", "hit", "die") and AnimAt (server time) attributes
-- and moves its Root; this script poses the Motor6Ds every frame and plays the magic attack's
-- effects. Display only: nothing here decides anything.
--
-- A pose is { joint = { pitch, yaw, roll (degrees), x, y, z (studs at scale 1) } }. Joints share
-- the Root's axes: x right, y up, -z forward. Positive pitch lifts the nose (or swings a foot
-- forward); positive yaw turns left.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FightFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FightFx"))
local TrainFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrainFx"))
local StationAssets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationAssets"))

type Pose = { [string]: { number } }
type Clip = { length: number, keys: { { any } } }

local JOINTS = { "body", "head", "leg_fl", "leg_fr", "leg_bl", "leg_br", "tail", "wing_l", "wing_r" }
local TAU = math.pi * 2
local MAGIC_IMPACT = 0.92 -- seconds into "magic" when the front feet land

-- Horn attack: crouch back with the head down, lunge and throw the horn up, settle.
local ATTACK: Clip = {
	length = 0.95,
	keys = {
		{ 0.00, {} },
		{
			0.28,
			{
				body = { -5, 0, 0, 0, -0.06, 0.45 },
				head = { -24 },
				leg_fl = { 14 },
				leg_fr = { 14 },
				leg_bl = { 9 },
				leg_br = { 9 },
				tail = { -18 },
			},
		},
		{
			0.42,
			{
				body = { 7, 0, 0, 0, 0.1, -1.0 },
				head = { 30 },
				leg_fl = { -26 },
				leg_fr = { -26 },
				leg_bl = { -22 },
				leg_br = { -22 },
				tail = { 22 },
			},
		},
		{
			0.62,
			{
				body = { 3, 0, 0, 0, 0.03, -0.6 },
				head = { 14 },
				leg_fl = { -12 },
				leg_fr = { -12 },
				leg_bl = { -9 },
				leg_br = { -9 },
			},
		},
		{ 0.95, {} },
	},
}

-- Magic attack: rear up on the hind legs, paw the air while the horn charges, slam down.
local MAGIC: Clip = {
	length = 1.6,
	keys = {
		{ 0.00, {} },
		{
			0.40,
			{
				body = { 26, 0, 0, 0, 0.42, 0.26 },
				head = { 12 },
				leg_fl = { 52 },
				leg_fr = { 42 },
				leg_bl = { -26 },
				leg_br = { -26 },
				tail = { -22 },
			},
		},
		{
			0.78,
			{
				body = { 30, 0, 0, 0, 0.5, 0.3 },
				head = { 16 },
				leg_fl = { 40 },
				leg_fr = { 58 },
				leg_bl = { -30 },
				leg_br = { -30 },
				tail = { -28 },
			},
		},
		{
			MAGIC_IMPACT,
			{
				body = { -6, 0, 0, 0, -0.14, -0.2 },
				head = { -16 },
				leg_fl = { -4 },
				leg_fr = { -4 },
				leg_bl = { 6 },
				leg_br = { 6 },
				tail = { 20 },
			},
		},
		{ 1.12, { body = { 2, 0, 0, 0, 0.05, 0 }, head = { 7 } } },
		{ 1.60, {} },
	},
}

-- Two-legged Hexbound (the knight, archer, mage and ogre have a "Biped" attribute): their front
-- "legs" are arms hung from the shoulders and their back "legs" are legs, so an arm swings forward
-- and up with a positive pitch, and 180 points it straight up. The cape or cloak is the "tail".

-- A sword or club chop (knight, ogre): the weapon arm goes up overhead, then comes down hard.
local BIPED_ATTACK: Clip = {
	length = 0.95,
	keys = {
		{ 0.00, {} },
		{
			0.30,
			{
				body = { 6, 0, 0, 0, 0.05, 0.2 },
				leg_fr = { 165 },
				leg_fl = { 25 },
				head = { -8 },
				leg_bl = { -8 },
				leg_br = { 8 },
				tail = { -10 },
			},
		},
		{
			0.46,
			{
				body = { -14, 0, 0, 0, -0.12, -0.9 },
				leg_fr = { 15 },
				leg_fl = { 50 },
				head = { 10 },
				leg_bl = { 16 },
				leg_br = { -12 },
				tail = { 14 },
			},
		},
		{ 0.70, { body = { -5, 0, 0, 0, 0, -0.4 }, leg_fr = { 20 }, leg_fl = { 30 } } },
		{ 0.95, {} },
	},
}

-- A bow shot (archer): both arms out to aim, then the drawing hand snaps back and the body recoils.
local ARCHER_ATTACK: Clip = {
	length = 0.95,
	keys = {
		{ 0.00, {} },
		{ 0.30, { leg_fl = { 90 }, leg_fr = { 72 }, body = { 0, 0, 0, 0, 0, -0.1 }, head = { -4 }, tail = { -6 } } },
		{ 0.46, { leg_fl = { 92 }, leg_fr = { 22 }, body = { 7, 0, 0, 0, 0.03, 0.4 }, head = { 4 }, tail = { 12 } } },
		{ 0.70, { leg_fl = { 60 }, leg_fr = { 18 }, body = { 2 } } },
		{ 0.95, {} },
	},
}

-- A spell cast (mage): the orb hand rises, the staff thrusts out and the body leans into it.
local MAGE_ATTACK: Clip = {
	length = 0.95,
	keys = {
		{ 0.00, {} },
		{
			0.30,
			{ leg_fl = { 112 }, leg_fr = { 50 }, body = { 8, 0, 0, 0, 0.06, 0.2 }, head = { -12 }, tail = { -8 } },
		},
		{
			0.46,
			{ leg_fl = { 82 }, leg_fr = { 20 }, body = { -8, 0, 0, 0, -0.05, -0.5 }, head = { 8 }, tail = { 14 } },
		},
		{ 0.70, { leg_fl = { 50 }, leg_fr = { 20 }, body = { -3 } } },
		{ 0.95, {} },
	},
}

-- The power attack for all of them: both arms thrown overhead while the power gathers, then a
-- stomp and slam as the ground erupts.
local BIPED_MAGIC: Clip = {
	length = 1.6,
	keys = {
		{ 0.00, {} },
		{
			0.40,
			{
				leg_fl = { 150 },
				leg_fr = { 150 },
				body = { 10, 0, 0, 0, 0.1, 0.15 },
				head = { -18 },
				leg_bl = { -6 },
				leg_br = { 6 },
				tail = { -14 },
			},
		},
		{
			0.78,
			{
				leg_fl = { 172 },
				leg_fr = { 166 },
				body = { 14, 0, 0, 0, 0.14, 0.2 },
				head = { -22 },
				leg_bl = { -8 },
				leg_br = { 8 },
				tail = { -20 },
			},
		},
		{
			MAGIC_IMPACT,
			{
				leg_fl = { 35 },
				leg_fr = { 30 },
				body = { -16, 0, 0, 0, -0.18, -0.7 },
				head = { 14 },
				leg_bl = { 14 },
				leg_br = { -8 },
				tail = { 22 },
			},
		},
		{ 1.12, { body = { -4, 0, 0, 0, 0.02, -0.2 }, head = { 6 } } },
		{ 1.60, {} },
	},
}

-- Struck: the body jerks back and the head snaps up.
local HIT: Clip = {
	length = 0.4,
	keys = {
		{ 0.00, {} },
		{ 0.10, { body = { 9, 0, 0, 0, 0, 0.5 }, head = { -16 }, leg_fl = { 12 }, leg_fr = { 12 }, tail = { 12 } } },
		{ 0.40, {} },
	},
}

-- Defeat: an animal rolls onto its side, a Hexbound biped falls on its back, a dragon slumps.
-- The y of the body is a fraction of its height off the ground (see `rest` on a rig), not studs.
local DIE_QUAD: Clip = {
	length = 1.2,
	keys = {
		{ 0.00, {} },
		{
			0.20,
			{ body = { 14, 0, 6, 0, 0.12, 0.5 }, head = { -26 }, leg_fl = { 36 }, leg_fr = { 30 }, tail = { 20 } },
		}, -- thrown back
		{ 0.50, { body = { 8, 0, 40, 0, -0.25, 0 }, head = { 20 } } },
		{
			1.20,
			{
				body = { 0, 0, 86, 0, -0.58, 0 },
				head = { 26 },
				leg_fl = { 30 },
				leg_fr = { 24 },
				leg_bl = { -20 },
				leg_br = { -24 },
				tail = { 14 },
			},
		},
	},
}
local DIE_BIPED: Clip = {
	length = 1.2,
	keys = {
		{ 0.00, {} },
		{ 0.45, { body = { 20, 0, 0, 0, -0.2, 0.3 }, head = { -20 }, leg_fl = { 40 }, leg_fr = { 30 } } },
		{
			1.20,
			{
				body = { 86, 0, 0, 0, -0.7, 0 },
				head = { -30 },
				leg_fl = { 70 },
				leg_fr = { 20 },
				leg_bl = { 12 },
				leg_br = { -10 },
				tail = { 30 },
			},
		},
	},
}

-- Per-species attacks (decision 0048). Every one is 0.95 s long (the server's Creatures.LENGTH.attack)
-- with its contact near 0.44 s, where the server lands the hit; a variant uses its species' clip.
-- The rhino keeps the horn charge above (ATTACK), which is also the fallback for a species not listed.
local function attack(keys: { { any } }): Clip
	return { length = 0.95, keys = keys }
end
local ATTACKS: { [string]: Clip } = {
	-- a lunge and a snap, then a shake of the head
	jackal = attack({
		{ 0.00, {} },
		{
			0.20,
			{ body = { -4, 0, 0, 0, -0.1, 0.3 }, head = { -22 }, leg_fl = { 12 }, leg_fr = { 12 }, tail = { -14 } },
		},
		{
			0.42,
			{ body = { 8, 0, 0, 0, 0.06, -0.9 }, head = { 30 }, leg_fl = { -22 }, leg_fr = { -22 }, tail = { 20 } },
		},
		{ 0.54, { body = { 4, 0, 0, 0, 0.03, -0.7 }, head = { 14, 24 } } },
		{ 0.66, { body = { 2, 0, 0, 0, 0, -0.5 }, head = { 14, -24 } } },
		{ 0.95, {} },
	}),
	-- rears a little and swipes down with one paw, then the other
	cheetah = attack({
		{ 0.00, {} },
		{ 0.24, { body = { 14, 0, 0, 0, 0.18, 0.2 }, head = { 8 }, leg_fr = { 75 }, leg_fl = { 20 }, tail = { -18 } } },
		{
			0.42,
			{ body = { -6, 0, 0, 0, -0.04, -0.6 }, head = { 14 }, leg_fr = { -24 }, leg_fl = { 30 }, tail = { 18 } },
		},
		{ 0.58, { body = { -2, 0, 0, 0, 0, -0.4 }, leg_fl = { -22 }, leg_fr = { 10 } } },
		{ 0.95, {} },
	}),
	-- a heavy shell-first slam: lifts the front, then drops it with the head thrust out
	tortoise = attack({
		{ 0.00, {} },
		{
			0.28,
			{ body = { 11, 0, 0, 0, 0.18, 0.1 }, head = { -14, 0, 0, 0, 0, 0.25 }, leg_fl = { 24 }, leg_fr = { 24 } },
		},
		{ 0.44, { body = { -10, 0, 0, 0, -0.06, -0.5 }, head = { 24 }, leg_fl = { -12 }, leg_fr = { -12 } } },
		{ 0.66, { body = { -3, 0, 0, 0, 0, -0.2 }, head = { 8 } } },
		{ 0.95, {} },
	}),
	-- it stands upright (decision 0055; its arms are the front legs): rocks back with both arms up, then
	-- lunges and claws down. The legs turn against the body so the feet stay flat, the tail so it stays
	-- on the ground
	meerkat = attack({
		{ 0.00, {} },
		{
			0.26,
			{
				body = { 9, 0, 0, 0, 0.03, 0.15 },
				head = { 6 },
				leg_fl = { 120 },
				leg_fr = { 108 },
				leg_bl = { -9 },
				leg_br = { -9 },
				tail = { -10 },
			},
		},
		{
			0.44,
			{
				body = { -16, 0, 0, 0, 0, -0.45 },
				head = { 10 },
				leg_fl = { 28 },
				leg_fr = { 36 },
				leg_bl = { 16 },
				leg_br = { 16 },
				tail = { 12 },
			},
		},
		{
			0.62,
			{
				body = { -6, 0, 0, 0, 0, -0.2 },
				leg_fl = { 16 },
				leg_fr = { 16 },
				leg_bl = { 6 },
				leg_br = { 6 },
				tail = { 4 },
			},
		},
		{ 0.95, {} },
	}),
	-- the neck draws back and whips forward
	flamingo = attack({
		{ 0.00, {} },
		{ 0.30, { body = { -7, 0, 0, 0, 0, 0.3 }, head = { -46, 8 }, tail = { -14 } } },
		{ 0.44, { body = { 9, 0, 0, 0, 0, -0.7 }, head = { 42, -10 }, tail = { 16 } } },
		{ 0.60, { body = { 3, 0, 0, 0, 0, -0.4 }, head = { 18, 12 } } },
		{ 0.95, {} },
	}),
	-- a crouch, then a long pounce with both front paws out. The crouch splays the front legs far
	-- forward (chest low, haunches up) so the paws stay on the ground as the body drops, and the
	-- tail is held up through the leap: the lions' long tail flame would drag on the ground
	lion = attack({
		{ 0.00, {} },
		{
			0.26,
			{
				body = { -8, 0, 0, 0, -0.22, 0.2 },
				head = { -10 },
				leg_fl = { 40 },
				leg_fr = { 40 },
				leg_bl = { -18 },
				leg_br = { -18 },
				tail = { -20 },
			},
		},
		{
			0.44,
			{
				body = { 18, 0, 0, 0, 0.34, -1.2 },
				head = { 12 },
				leg_fl = { 58 },
				leg_fr = { 52 },
				leg_bl = { -36 },
				leg_br = { -36 },
				tail = { -22 },
			},
		},
		{ 0.62, { body = { -4, 0, 0, 0, 0.02, -0.6 }, head = { 8 }, leg_fl = { 10 }, leg_fr = { 10 } } },
		{ 0.95, {} },
	}),
	-- the front legs rise, then a stomp and a trunk-first slam
	elephant = attack({
		{ 0.00, {} },
		{
			0.30,
			{ body = { 10, 0, 0, 0, 0.16, 0.2 }, head = { -20 }, leg_fl = { 42 }, leg_fr = { 36 }, tail = { -10 } },
		},
		{
			0.44,
			{ body = { -7, 0, 0, 0, -0.08, -0.5 }, head = { 30 }, leg_fl = { -12 }, leg_fr = { -10 }, tail = { 12 } },
		},
		{ 0.66, { body = { -2, 0, 0, 0, 0, -0.2 }, head = { 10 } } },
		{ 0.95, {} },
	}),
}
-- Power attacks (1.6 s, the slam at MAGIC_IMPACT where the ground erupts). Every base animal has its
-- own; a variant can add one under its asset name ("creature_lion_sun") and it wins over its species'.
local function powerClip(coil: Pose, wound: Pose, slam: Pose): Clip
	return {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{ 0.40, coil },
			{ 0.78, wound },
			{ MAGIC_IMPACT, slam },
			{ 1.12, { body = { 2 } } },
			{ 1.60, {} },
		},
	}
end
local MAGICS: { [string]: Clip } = {
	-- throws its head back in a howl (a positive pitch lifts the nose), then drives down on the target
	jackal = powerClip(
		{ body = { 14, 0, 0, 0, 0.08, 0.2 }, head = { 36 }, tail = { -20 } },
		{ body = { 20, 0, 0, 0, 0.14, 0.3 }, head = { 52 }, leg_fl = { 14 }, leg_fr = { 14 }, tail = { -26 } },
		{ body = { -8, 0, 0, 0, -0.12, -1.2 }, head = { -22 }, leg_fl = { -24 }, leg_fr = { -24 }, tail = { 22 } }
	),
	-- draws into the shell, rises, and crashes down
	tortoise = powerClip(
		{ body = { 6, 0, 0, 0, 0.08, 0.15 }, head = { -18, 0, 0, 0, 0, 0.3 } },
		{ body = { 16, 0, 0, 0, 0.32, 0.3 }, head = { -24, 0, 0, 0, 0, 0.35 }, leg_fl = { 30 }, leg_fr = { 30 } },
		{ body = { -9, 0, 0, 0, -0.12, -0.4 }, head = { 22 }, leg_fl = { -10 }, leg_fr = { -10 } }
	),
	-- upright: gathers the charge between its paws, lifts it overhead on its toes, then hurls it down
	meerkat = powerClip({
		body = { 4, 0, 0, 0, -0.05, 0.1 },
		head = { -8 },
		leg_fl = { 60 },
		leg_fr = { 60 },
		leg_bl = { -4 },
		leg_br = { -4 },
		tail = { -5 },
	}, {
		body = { 12, 0, 0, 0, 0.08, 0.2 },
		head = { 14 },
		leg_fl = { 165 },
		leg_fr = { 158 },
		leg_bl = { -12 },
		leg_br = { -12 },
		tail = { -14 },
	}, {
		body = { -22, 0, 0, 0, -0.03, -0.6 },
		head = { 8 },
		leg_fl = { 40 },
		leg_fr = { 40 },
		leg_bl = { 22 },
		leg_br = { 22 },
		tail = { 16 },
	}),
	-- coils low and bounds in. Its legs are very long: in the coil the front legs splay far forward and the
	-- body drops only a little, or the paws sink into the ground; in the bound the body rises and the long
	-- tail is held up, or the hind paws and the tail do
	cheetah = powerClip({
		body = { -9, 0, 0, 0, -0.12, 0.4 },
		head = { -8 },
		leg_fl = { 44 },
		leg_fr = { 44 },
		leg_bl = { -10 },
		leg_br = { -10 },
	}, {
		body = { -12, 0, 0, 0, -0.2, 0.5 },
		head = { -12 },
		leg_fl = { 52 },
		leg_fr = { 52 },
		leg_bl = { -17 },
		leg_br = { -17 },
		tail = { -26 },
	}, {
		body = { 14, 0, 0, 0, 0.26, -1.6 },
		head = { 16 },
		leg_fl = { 50 },
		leg_fr = { 50 },
		leg_bl = { -34 },
		leg_br = { -34 },
		tail = { -20 },
	}),
	-- the neck coils far back, then spears down; the feet stay planted
	flamingo = powerClip(
		{ body = { -6, 0, 0, 0, 0, 0.2 }, head = { -40, 10 } },
		{ body = { -9, 0, 0, 0, 0, 0.3 }, head = { -58, -12 }, tail = { -20 } },
		{ body = { 12, 0, 0, 0, 0, -0.8 }, head = { 52 }, tail = { 20 } }
	),
	-- a crouch and a roar, then a long leaping pounce
	lion = powerClip({
		body = { -8, 0, 0, 0, -0.24, 0.3 },
		head = { -6 },
		leg_fl = { 42 },
		leg_fr = { 42 },
		leg_bl = { -20 },
		leg_br = { -20 },
	}, {
		body = { -10, 0, 0, 0, -0.28, 0.4 },
		head = { 30 },
		leg_fl = { 46 },
		leg_fr = { 46 },
		leg_bl = { -22 },
		leg_br = { -22 },
		tail = { -24 },
	}, {
		body = { 20, 0, 0, 0, 0.36, -1.7 },
		head = { 14 },
		leg_fl = { 58 },
		leg_fr = { 54 },
		leg_bl = { -38 },
		leg_br = { -38 },
		tail = { -22 },
	}),
	-- backs up, paws the ground, then charges and tosses its horn
	rhino = powerClip({
		body = { -4, 0, 0, 0, -0.06, 0.6 },
		head = { -30 },
		leg_fl = { 36 },
		leg_fr = { -6 },
		leg_bl = { -14 },
		leg_br = { -14 },
	}, {
		body = { -6, 0, 0, 0, -0.1, 0.8 },
		head = { -36 },
		leg_fl = { -6 },
		leg_fr = { 40 },
		leg_bl = { -18 },
		leg_br = { -18 },
		tail = { -16 },
	}, {
		body = { 8, 0, 0, 0, 0.08, -2.0 },
		head = { 34 },
		leg_fl = { -26 },
		leg_fr = { -26 },
		leg_bl = { -22 },
		leg_br = { -22 },
		tail = { 22 },
	}),
	-- trunk raised in a trumpet and the body half reared, then a stomping slam
	elephant = powerClip(
		{ body = { 12, 0, 0, 0, 0.12, 0.2 }, head = { 30 }, leg_fl = { 36 }, leg_fr = { 30 }, tail = { -14 } },
		{ body = { 16, 0, 0, 0, 0.2, 0.3 }, head = { 40 }, leg_fl = { 52 }, leg_fr = { 46 }, tail = { -18 } },
		{ body = { -10, 0, 0, 0, -0.1, -0.7 }, head = { -20 }, leg_fl = { -16 }, leg_fr = { -14 }, tail = { 18 } }
	),
}

-- A model's species: its asset is "creature_<species>" or "creature_<species>_<variant>".
local function speciesOf(model: Model): string?
	local asset = model:GetAttribute("Asset")
	return if type(asset) == "string" then string.match(asset, "^creature_(%l+)") else nil
end

-- The clip a model plays from `set`: its asset's own (a variant's), then its species', then `fallback`.
local function pick(set: { [string]: Clip }, model: Model, fallback: Clip): Clip
	local asset = model:GetAttribute("Asset")
	if type(asset) ~= "string" then
		return fallback
	end
	return set[asset] or set[speciesOf(model) or ""] or fallback
end

local function ease(u: number): number
	return u * u * (3 - 2 * u)
end

-- The clip's pose at time t: the two keys around t blended with a smooth ease.
local function sample(clip: Clip, t: number): Pose
	local keys = clip.keys
	if t >= clip.length then
		return keys[#keys][2]
	end
	for i = 1, #keys - 1 do
		local t0, t1 = keys[i][1], keys[i + 1][1]
		if t >= t0 and t <= t1 then
			local u = ease((t - t0) / (t1 - t0))
			local a, b = keys[i][2] :: Pose, keys[i + 1][2] :: Pose
			local out: Pose = {}
			for _, joint in JOINTS do
				local ja, jb = a[joint], b[joint]
				if ja or jb then
					local v = table.create(6, 0)
					for k = 1, 6 do
						local x, y = if ja then ja[k] or 0 else 0, if jb then jb[k] or 0 else 0
						v[k] = x + (y - x) * u
					end
					out[joint] = v
				end
			end
			return out
		end
	end
	return {}
end

-- Every value of a pose stretched by `f`: a harder hit throws the body further.
local function scaled(pose: Pose, f: number): Pose
	local out: Pose = {}
	for joint, v in pose do
		local w = table.create(6, 0)
		for k = 1, 6 do
			w[k] = (v[k] or 0) * f
		end
		out[joint] = w
	end
	return out
end

local function idle(t: number): Pose
	return {
		body = { 0, 0, 0, 0, 0.03 * math.sin(t * TAU / 3.2), 0 },
		head = { 2 * math.sin(t * TAU / 3.2 + 0.8), 5 * math.sin(t * TAU / 5.6), 0 },
		tail = { 0, 12 * math.sin(t * TAU / 1.9), 0 },
	}
end

-- A trot: diagonal legs swing together, the body bobs twice a stride, head and tail follow.
local function walk(t: number, rate: number): Pose
	local phase = t * rate * TAU
	local a, b = 27 * math.sin(phase), 27 * math.sin(phase + math.pi)
	return {
		leg_fl = { a },
		leg_br = { a },
		leg_fr = { b },
		leg_bl = { b },
		body = { 1.5 * math.sin(2 * phase), 0, 2 * math.sin(phase), 0, 0.07 * math.abs(math.sin(phase)), 0 },
		head = { 3 * math.sin(2 * phase + 0.6), 3 * math.sin(phase), 0 },
		tail = { 0, 16 * math.sin(phase), 0 },
	}
end

-- A Hexbound biped stands heavier and walks with its arms swinging against its legs.
local function idleBiped(t: number): Pose
	return {
		body = { 0, 0, 0, 0, 0.02 * math.sin(t * TAU / 3.4), 0 },
		head = { 2 * math.sin(t * TAU / 3.4 + 0.8), 4 * math.sin(t * TAU / 6), 0 },
		leg_fl = { 3 * math.sin(t * TAU / 3.4) },
		leg_fr = { -3 * math.sin(t * TAU / 3.4) },
		tail = { 5 * math.sin(t * TAU / 2.6), 0, 0 },
	}
end

-- An upright animal (a meerkat) has long feet: it takes short steps, or their ends dig in.
local function walkBiped(t: number, rate: number, animal: boolean): Pose
	local phase = t * rate * TAU
	local a = (if animal then 13 else 26) * math.sin(phase)
	return {
		leg_bl = { a },
		leg_br = { -a },
		leg_fl = { -a * 0.7 },
		leg_fr = { a * 0.7 },
		body = { -3, 3 * math.sin(phase), 2 * math.sin(phase), 0, 0.09 * math.abs(math.sin(phase)), 0 },
		head = { 2 * math.sin(2 * phase + 0.6), -3 * math.sin(phase), 0 },
		tail = { 10 * math.sin(phase + 1), 0, 0 },
	}
end

-- Training (decision 0066): what an animal does at its station, on a loop, as (time, strides a second,
-- upright or not, its model). The server sets the clip's name as Anim and, for the two that travel, moves
-- the animal. A head's first number is its pitch: up is positive.
-- The lift and the blow are timed by TrainFx, which the kit they are done with is moved by too.
local pulse = TrainFx.pulse

-- Asleep: lids over its eyes (where its manifest says they are, in its brow's colour) and a "Zzz" over
-- it, both gone with the model. The label is in the player's gui: a BillboardGui in the model did not show.
local asleep: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function fallAsleep(model: Model)
	local asset = model:GetAttribute("Asset") :: string?
	local entry = asset and StationAssets[asset]
	local head = asset and model:FindFirstChild(`{asset}_head`) :: BasePart?
	local root = model.PrimaryPart
	local bodyJoint = root and root:FindFirstChild("body") :: Motor6D?
	local headJoint = bodyJoint and bodyJoint.Part1 and bodyJoint.Part1:FindFirstChild("head") :: Motor6D?
	if entry and entry.eyes and head and root and bodyJoint and headJoint then
		-- the eye at rest: manifest space is the Root turned about (Creatures.build), the head at rest is where
		-- its joints put it with no pose; the lid keeps that place on the head as it moves
		local frame = root.CFrame * CFrame.Angles(0, math.pi, 0)
		local headRest = root.CFrame * bodyJoint.C0 * bodyJoint.C1:Inverse() * headJoint.C0 * headJoint.C1:Inverse()
		local shade = entry.lid or { 90, 90, 100 }
		for _, e in entry.eyes do
			local lid = Instance.new("Part")
			lid.Shape, lid.Size = Enum.PartType.Ball, Vector3.one * e[4] * 1.15
			lid.Color, lid.Material = Color3.fromRGB(shade[1], shade[2], shade[3]), Enum.Material.SmoothPlastic
			lid.CanCollide, lid.CanQuery, lid.CanTouch, lid.Massless, lid.CastShadow = false, false, false, true, false
			lid.CFrame = head.CFrame * headRest:ToObjectSpace(frame * CFrame.new(e[1], e[2], e[3]))
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1, weld.Parent = head, lid, lid
			lid.Name, lid.Parent = "Lid", model
		end
	end
	if model.PrimaryPart then
		local tag = Instance.new("BillboardGui")
		tag.Name, tag.Size = "Zzz", UDim2.fromOffset(90, 50)
		local tall = if entry then entry.size[2] else model:GetExtentsSize().Y -- standing: it is lying by now
		tag.StudsOffsetWorldSpace = Vector3.new(0, tall * 0.8, 0)
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency, label.Text = UDim2.fromScale(1, 1), 1, "z Z z"
		label.TextScaled, label.Font, label.TextColor3 = true, Enum.Font.FredokaOne, Color3.fromRGB(220, 230, 255)
		label.TextStrokeTransparency = 0.4
		label.Parent = tag
		tag.Adornee = model.PrimaryPart
		tag.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		model.Destroying:Connect(function()
			tag:Destroy()
		end)
	end
end

local TRAIN: { [string]: (number, number, boolean, Model) -> Pose } = {
	-- the track: a gallop, the front pair and the hind pair swinging against each other
	run = function(t, rate, biped)
		if biped then
			return walkBiped(t, rate * 1.9, true)
		end
		local phase = t * rate * 1.7 * TAU
		return {
			leg_fl = { 36 * math.sin(phase) },
			leg_fr = { 36 * math.sin(phase - 0.6) },
			leg_bl = { 36 * math.sin(phase + 2.8) },
			leg_br = { 36 * math.sin(phase + 2.2) },
			body = { 4 * math.sin(phase + 0.8), 0, 0, 0, 0.14 * math.abs(math.sin(phase)), 0 },
			head = { -4 * math.sin(phase + 0.8), 0, 0 },
			tail = { 0, 9 * math.sin(phase), 0 },
		}
	end,
	-- the pool: paddling, the body rolling a little, the head held up
	swim = function(t, _, biped)
		local phase = t * 1.3 * TAU
		local a, slow = 22 * math.sin(phase), math.sin(phase / 2)
		return {
			leg_fl = { if biped then 2 * a else a },
			leg_fr = { if biped then -2 * a else -a },
			leg_bl = { if biped then -a / 2 else -a },
			leg_br = { if biped then a / 2 else a },
			body = { 0, 3 * slow, 3 * math.sin(phase), 0, 0.05 * slow, 0 },
			head = { 9, -3 * slow, 0 },
			tail = { 0, 16 * slow, 0 },
		}
	end,
	-- the gym: sinks under the weight, shakes, drives up, stands a moment
	heave = function(t, _, biped)
		local down, u = TrainFx.heave(t)
		local shake = if u > 0.3 and u < 0.42 then 0.7 * math.sin(t * 55) else 0
		if biped then -- arms up under the bar as it straightens
			local arms = -150 * (1 - down) * (if u < 0.9 then 1 else 0.6)
			return {
				leg_fl = { arms },
				leg_fr = { arms },
				body = { 4 * down + shake, 0, 0, 0, -0.1 * down, 0 },
				head = { -6 * down, 0, 0 },
			}
		end
		-- the legs fold far and the body is dropped further than any legs let it: it comes to rest
		-- on its feet (the body is lifted to them), low for thin legs, less so for thick ones
		return {
			leg_fl = { 52 * down },
			leg_fr = { 52 * down },
			leg_bl = { -52 * down },
			leg_br = { -52 * down },
			body = { 3 * down + shake, 0, 0, 0, -0.62 * down, 0 },
			head = { 10 - 16 * down, 0, 0 },
			tail = { 0, 6 * math.sin(t * TAU / 2.8), 0 },
		}
	end,
	-- the library: its eyes on the book (the server says how far up or down that is from its head, as
	-- Gaze), reading along the lines, now and then a paw to the page
	study = function(t, _, biped, model)
		local line = math.sin(t * TAU / 5)
		local gaze = (model:GetAttribute("Gaze") :: number?) or -10
		local pose: Pose = {
			body = { 0, 1.5 * line, 0, 0, 0.02 * math.sin(t * TAU / 3.4), 0 },
			head = { gaze + 3 * math.sin(t * TAU / 2.5), 8 * line, 0 },
			tail = { 0, 9 * math.sin(t * TAU / 2.8), 0 },
		}
		local paw = pulse((t % 6.5) / 6.5, 0.08, 0.2)
		if paw > 0 then
			pose.leg_fl = { (if biped then -70 else -34) * paw }
		end
		return pose
	end,
	-- the spring: lying low in the water, legs folded, breathing slowly
	soak = function(t, _, biped, model)
		local breath = math.sin(t * TAU / 4.5)
		if model:GetAttribute("Species") == "flamingo" then -- it stands in it and dips its head to bathe
			local dip = pulse((t % 6) / 6, 0.2, 0.5)
			return {
				body = { -3 * dip, 0, 2 * breath, 0, 0.02 * breath, 0 },
				head = { -8 - 34 * dip + 3 * breath, 10 * math.sin(t * TAU / 9) * (1 - dip), 0 },
				leg_bl = { 0, 0, 10 * dip }, -- its wings lift a little as it does
				leg_br = { 0, 0, -10 * dip },
				tail = { 0, 6 * math.sin(t * TAU / 3.5), 0 },
			}
		elseif biped then -- sitting back in it
			return {
				leg_bl = { -70 },
				leg_br = { -70 },
				leg_fl = { -12 + 3 * breath },
				leg_fr = { -12 - 3 * breath },
				body = { -6, 0, 1.5 * breath, 0, -0.4 + 0.02 * breath, 0 },
				head = { 4 + 3 * breath, 6 * math.sin(t * TAU / 7), 0 },
			}
		end
		return {
			leg_fl = { 62 },
			leg_fr = { 62 },
			leg_bl = { -62 },
			leg_br = { -62 },
			body = { 0, 0, 1.5 * breath, 0, -0.5 + 0.02 * breath, 0 },
			head = { 6 + 3 * breath, 5 * math.sin(t * TAU / 7), 0 },
			tail = { 0, 8 * math.sin(t * TAU / 3.5), 0 },
		}
	end,
	-- asleep (the Titan in its den): lying flat, legs out, its head on the ground, eyes shut, breathing
	-- slowly, with a "Zzz" over it
	sleep = function(t, _, biped, model)
		if not asleep[model] then
			asleep[model] = true
			fallAsleep(model)
		end
		local breath = math.sin(t * TAU / 6)
		if biped then
			return {
				leg_bl = { -80 },
				leg_br = { -80 },
				leg_fl = { -20 },
				leg_fr = { -20 },
				body = { 20, 0, 2 * breath, 0, -0.5 + 0.02 * breath, 0 },
				head = { 30 + 2 * breath, 0, 0 },
			}
		end
		return {
			leg_fl = { 84 },
			leg_fr = { 84 },
			leg_bl = { -84 },
			leg_br = { -84 },
			body = { 0, 0, 0, 0, -0.68 + 0.015 * breath, 0 },
			head = { -14 + 1.5 * breath, 0, 6 },
			tail = { 0, 0, 0 },
		}
	end,
	-- the guard yard: set low against the blow, thrown back as it lands, set again
	brace = function(t, _, biped)
		local hit = TrainFx.brace(t)
		if biped then
			return {
				leg_fl = { -60 + 30 * hit },
				leg_fr = { -60 + 30 * hit },
				body = { 6 - 10 * hit, 0, 0, 0, -0.04, 0.2 * hit },
				head = { 6 - 10 * hit, 0, 0 },
			}
		end
		return {
			leg_fl = { -16 + 10 * hit },
			leg_fr = { -16 + 10 * hit },
			leg_bl = { 14 },
			leg_br = { 14 },
			body = { 5 - 9 * hit, 0, 0, 0, -0.07, 0.3 * hit },
			head = { 8 - 14 * hit, 0, 0 },
			tail = { 0, 6 * math.sin(t * TAU / 2), 0 },
		}
	end,
}

-- Victory (the survivors, at the end): an animal rears and pumps its front paws and wags its tail,
-- a biped throws both arms up and bounces. Time is since the pose began.
local function win(t: number, biped: boolean): Pose
	local u = ease(math.min(1, t / 0.5))
	if biped then
		return {
			leg_fl = { 170 * u + 8 * math.sin(t * 8) * u },
			leg_fr = { 170 * u - 8 * math.sin(t * 8) * u },
			body = { 0, 0, 0, 0, 0.12 * math.abs(math.sin(t * 5)) * u, 0 },
			head = { -10 * u },
			tail = { 8 * math.sin(t * 4) * u, 0, 0 },
		}
	end
	local pump = 12 * math.sin(t * 7) * u
	return {
		body = { 24 * u, 0, 0, 0, (0.34 + 0.06 * math.abs(math.sin(t * 5))) * u, 0.2 * u },
		head = { 14 * u },
		leg_fl = { 50 * u + pump },
		leg_fr = { 50 * u - pump },
		leg_bl = { -26 * u },
		leg_br = { -26 * u },
		tail = { 0, 20 * math.sin(t * 6) * u, 0 },
	}
end

-- A flamingo's victory keeps both feet planted: the neck sways and bobs, the tail wags.
local function winFlamingo(t: number): Pose
	local u = ease(math.min(1, t / 0.5))
	return {
		body = { -5 * u, 0, 0, 0, 0, 0 },
		head = { (-12 + 8 * math.sin(t * 6)) * u, 22 * math.sin(t * 3) * u },
		tail = { 0, 24 * math.sin(t * 6) * u, 0 },
	}
end
-- A lion, a jackal or a cheetah rears like the others but holds its tail up: their long tails would lie
-- on the ground.
local function winTailUp(t: number): Pose
	local pose = win(t, false)
	pose.tail = { -24 * ease(math.min(1, t / 0.5)), pose.tail[2], 0 }
	return pose
end
local WINS: { [string]: (number) -> Pose } =
	{ flamingo = winFlamingo, lion = winTailUp, jackal = winTailUp, cheetah = winTailUp, tortoise = winTailUp }
local PLANTED = { flamingo = true } -- species whose feet never leave the ground, not even when hit

-- A dragon's wings (the "wing_l" joint is on its left, so it lifts with a negative roll): a slow
-- beat at rest, a wider one when it moves, a hard one when it attacks, still when it is down.
local function wings(time: number, anim: string?): Pose
	local amp, rate = 10, 0.5
	if anim == "walk" then
		amp, rate = 16, 0.9
	elseif anim == "attack" or anim == "magic" then
		amp, rate = 38, 1.8
	elseif anim == "win" then
		amp, rate = 30, 1.2
	elseif anim == "die" then
		amp = 0
	end
	local f = amp * math.sin(time * rate * TAU) + (if anim == "die" then 28 else 0)
	return { wing_l = { 0, 0, -f }, wing_r = { 0, 0, f } }
end

-- Magic attack effects ---------------------------------------------------------------------------

local function fxPart(size: Vector3, cframe: CFrame, colour: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.CFrame, p.Color, p.Material = size, cframe, colour, material
	p.Parent = Workspace
	return p
end

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService
		:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		:Play()
end

-- The horn gathers light while the creature rears up.
local function charge(model: Model, colour: Color3, seconds: number)
	local asset = model:GetAttribute("Asset")
	local head = (model:FindFirstChild(`{asset}_head_glow`) or model:FindFirstChild(`{asset}_head`)) :: BasePart?
	if head == nil then
		return
	end
	local tip = CFrame.new(0, 0.46 * head.Size.Y, -0.22 * head.Size.Z) -- the top front of the head: the horn's tip
	local s = ((model:GetAttribute("Scale") :: number?) or 1)
	local orb = fxPart(Vector3.one * 0.2 * s, head.CFrame, colour, Enum.Material.Neon)
	orb.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = colour, 4, 0.5, false
	light.Parent = orb
	tween(orb, seconds, { Size = Vector3.one * 1.1 * s, Transparency = 0.25 }, Enum.EasingStyle.Sine)
	tween(light, seconds, { Range = 10 * s, Brightness = 3 }, Enum.EasingStyle.Sine)
	local started = os.clock()
	local follow
	follow = RunService.RenderStepped:Connect(function()
		if os.clock() - started > seconds or head.Parent == nil then
			follow:Disconnect()
			orb:Destroy()
			return
		end
		orb.CFrame = head.CFrame * tip
	end)
end

-- A sharp four-sided spike standing on `stem` (the middle of its base): four corner wedges with
-- their tall corners together, welded to the stem so moving the stem moves the spike.
local function pyramid(stem: Part, width: number, height: number, colour: Color3, material: Enum.Material)
	for k = 0, 3 do
		local w = Instance.new("CornerWedgePart")
		w.CanCollide, w.CanQuery, w.CanTouch, w.CastShadow, w.Massless = false, false, false, false, true
		w.Size, w.Color, w.Material = Vector3.new(width / 2, height, width / 2), colour, material
		-- a corner wedge's tall corner is at +x, -z
		w.CFrame = stem.CFrame * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(-width / 4, height / 2, width / 4)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = stem, w
		weld.Parent = w
		w.Parent = stem
	end
end

-- The slam: a ring of light on the ground, then spikes burst up in a line ahead of the creature.
local function impact(model: Model, colour: Color3, molten: boolean)
	local root = model.PrimaryPart
	if root == nil then
		return
	end
	local s = ((model:GetAttribute("Scale") :: number?) or 1)
	local ground = root.CFrame * CFrame.new(0, 0.1, -1.4 * s) -- where the front feet land
	local ring = fxPart(Vector3.new(0.3, 2, 2), ground * CFrame.Angles(0, 0, math.pi / 2), colour, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.2
	tween(ring, 0.5, { Size = Vector3.new(0.3, 9 * s, 9 * s), Transparency = 1 })
	Debris:AddItem(ring, 0.6)
	local rock = if molten then Color3.fromRGB(40, 34, 38) else Color3.fromRGB(150, 140, 128)
	for i = 1, 6 do
		task.delay(0.055 * i, function()
			local height = (1.3 + 0.3 * i) * s
			local width = (0.5 + 0.07 * i) * s
			local lean = CFrame.Angles(
				math.rad(math.random(-14, 14)),
				math.rad(math.random(0, 360)),
				math.rad(math.random(-14, 14))
			)
			local base = ground * CFrame.new(math.random(-10, 10) / 10 * s, 0, -(1.6 + 1.3 * i) * s) -- from past the nose on
			local low, high =
				base * CFrame.new(0, -height * 1.15, 0) * lean, base * CFrame.new(0, -height * 0.12, 0) * lean
			-- a rock spike with a thinner, taller glowing core: only its tip shows
			local spike = fxPart(Vector3.one * 0.2, low, rock, Enum.Material.Slate)
			spike.Transparency = 1
			pyramid(spike, width, height, rock, Enum.Material.Slate)
			pyramid(spike, width * 0.5, height * 1.12, colour, Enum.Material.Neon)
			tween(spike, 0.16, { CFrame = high }, Enum.EasingStyle.Back)
			task.delay(0.75, function()
				tween(spike, 0.35, { CFrame = low })
			end)
			Debris:AddItem(spike, 1.15)
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness, light.Shadows = colour, 5 * s, 2, false
			light.Parent = spike
			local burst = Instance.new("ParticleEmitter")
			burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			burst.Color = ColorSequence.new(colour)
			burst.LightEmission = if molten then 1 else 0.4
			burst.Size =
				NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3 * s), NumberSequenceKeypoint.new(1, 0) })
			burst.Lifetime = NumberRange.new(0.4, 0.9)
			burst.Speed = NumberRange.new(4 * s, 8 * s)
			burst.SpreadAngle = Vector2.new(50, 50)
			burst.Acceleration = Vector3.new(0, -24, 0)
			burst.Rate = 0
			burst.Parent = spike
			task.delay(0.14, burst.Emit, burst, 14) -- once the spike is out of the ground
		end)
	end
end

local function magicColour(model: Model): (Color3, boolean)
	for _, d in model:GetChildren() do -- a glowing variant casts in its own colour
		if d:IsA("MeshPart") and d.Material == Enum.Material.Neon then
			return d.Color, true
		end
	end
	return Color3.fromRGB(255, 226, 150), false
end

-- Rigs ---------------------------------------------------------------------------------------------

-- Where a rig's legs are, for keeping its feet on the ground: the body joint's frame on the root, and
-- for each leg its joint's frame on the body and the corners of its box seen from that joint.
type Feet = { base: CFrame, legs: { { joint: string, frame: CFrame, points: { Vector3 } } }, ground: number }

type Rig = {
	model: Model,
	joints: { [string]: Motor6D },
	feet: Feet?, -- nil until its body and four legs have arrived
	now: { [string]: { number } }, -- the pose on screen, eased towards the target each frame
	magicAt: number, -- the AnimAt of the magic attack whose effects have started
	impactAt: number, -- and of the one whose slam has played
	rest: number, -- the body's height above the ground, studs; 0 until a fall needs it
	stopUntil: number, -- os.clock() until which the clip is held still (a hit-stop)
	held: number, -- seconds the clip `heldFor` has been held so far
	heldFor: number, -- the AnimAt of that clip
	flinch: number, -- how far the next "hit" clip is stretched
	spark: ParticleEmitter?, -- the hit sparks, made on the first hit
}

local rigs: { [Model]: Rig } = {}
local player = Players.LocalPlayer

local LEGS = { "leg_fl", "leg_fr", "leg_bl", "leg_br" }

-- A rig's `Feet`, once its body and legs are there. `ground` is how low its legs reach standing still.
local function feetOf(joints: { [string]: Motor6D }): Feet?
	local body = joints.body
	if body == nil then
		return nil
	end
	local legs, ground = {}, math.huge
	for _, name in LEGS do
		local motor = joints[name]
		local part = motor and motor.Part1
		if motor == nil or part == nil then
			return nil
		end
		local half, back = part.Size / 2, motor.C1:Inverse()
		local frame = body.C1:Inverse() * motor.C0
		local points = {}
		for i = 0, 7 do
			local corner = Vector3.new(
				if i % 2 == 0 then half.X else -half.X,
				if i // 2 % 2 == 0 then half.Y else -half.Y,
				if i // 4 == 0 then half.Z else -half.Z
			)
			local p = back * corner
			table.insert(points, p)
			ground = math.min(ground, (body.C0 * frame * p).Y)
		end
		table.insert(legs, { joint = name, frame = frame, points = points })
	end
	return { base = body.C0, legs = legs, ground = ground }
end

local function turned(v: { number }, scale: number): CFrame
	return CFrame.new(v[4] * scale, v[5] * scale, v[6] * scale)
		* CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3]))
end

-- How far (studs) the pose `now` pushes a leg under the ground it stands on: the body is lifted by as
-- much, so no clip has to be fitted to every animal's legs. A leg's box stands in for its mesh.
local function sunk(feet: Feet, now: { [string]: { number } }, scale: number): number
	local body = feet.base * turned(now.body, scale)
	local low = math.huge
	for _, leg in feet.legs do
		local at = body * leg.frame * turned(now[leg.joint], scale)
		for _, p in leg.points do
			low = math.min(low, (at * p).Y)
		end
	end
	return math.max(0, feet.ground - low)
end

-- A hit lands (the server sets HitPower, HitDmg and then HitAt on the target): sparks, a shock disc,
-- a harder flinch, a short hold and a camera punch. A burst and one short-lived part: no lights.
local slowAt = -math.huge -- when the fight's killing blow landed (clips play slowly for a moment)

local function strike(rig: Rig)
	local model = rig.model
	local hit = model:FindFirstChild("Hit") :: BasePart?
	if hit == nil then
		return
	end
	local power = (model:GetAttribute("HitPower") :: number?) or 0
	local dmg = (model:GetAttribute("HitDmg") :: number?) or 0
	local s = ((model:GetAttribute("Scale") :: number?) or 1)
	local final = model:GetAttribute("HitFinal") == 1
	local hot = power > 0 or final
	local colour = if hot then Color3.fromRGB(255, 120, 70) else Color3.fromRGB(255, 220, 160)
	rig.flinch = FightFx.flinch(power, dmg / math.max(1, (model:GetAttribute("MaxHp") :: number?) or 1))
	rig.stopUntil = os.clock() + FightFx.hitStop(power, final)
	local spark = rig.spark
	if spark == nil then
		spark = Instance.new("ParticleEmitter")
		local e = spark :: ParticleEmitter
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.LightEmission, e.Rate, e.Lifetime = 1, 0, NumberRange.new(0.25, 0.5)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * s), NumberSequenceKeypoint.new(1, 0) })
		e.Speed, e.SpreadAngle, e.Acceleration =
			NumberRange.new(14 * s, 26 * s), Vector2.new(180, 180), Vector3.new(0, -30, 0)
		e.Parent = hit
		rig.spark = e
	end
	local e = spark :: ParticleEmitter
	e.Color = ColorSequence.new(colour)
	e:Emit(if final then 44 elseif hot then 28 else 10)
	local camera = Workspace.CurrentCamera
	local face = if camera then camera.CFrame.Position else hit.Position + Vector3.new(0, 0, 10)
	if (face - hit.Position).Magnitude > 0.1 then
		local disc = fxPart(
			Vector3.new(0.2, 1, 1) * s,
			CFrame.lookAt(hit.Position, face) * CFrame.Angles(0, math.pi / 2, 0), -- a cylinder's axis is x: face the camera
			colour,
			Enum.Material.Neon
		)
		disc.Shape, disc.Transparency = Enum.PartType.Cylinder, 0.25
		local r = (if final then 14 elseif hot then 9 else 5) * s
		tween(disc, 0.35, { Size = Vector3.new(0.2, r, r), Transparency = 1 })
		Debris:AddItem(disc, 0.45)
	end
	player:SetAttribute("CamPunch", FightFx.punchStrength(power)) -- local only: ArenaCamera reads it
	player:SetAttribute("CamPunchAt", os.clock())
	if final then
		slowAt = os.clock()
	end
	-- only the killing blow cuts the camera in on its target (ArenaCamera reads these)
	if final then
		player:SetAttribute("CamCut", hit.Position)
		player:SetAttribute("CamCutAt", os.clock())
	end
end

local function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
		end
	end
	local now = {}
	for _, joint in JOINTS do
		now[joint] = table.create(6, 0)
	end
	local rig: Rig = {
		model = model,
		joints = joints,
		now = now,
		magicAt = 0,
		impactAt = 0,
		rest = 0,
		stopUntil = 0,
		held = 0,
		heldFor = 0,
		flinch = 1,
		spark = nil,
	}
	rigs[model] = rig
	-- the server sets StopAt on a melee attacker and HitAt on whoever is struck; both arrive after
	-- their power, damage and duration, but read those tolerantly: attributes come in any order
	model:GetAttributeChangedSignal("StopAt"):Connect(function()
		rig.stopUntil = os.clock() + ((model:GetAttribute("StopFor") :: number?) or FightFx.hitStop(0))
	end)
	model:GetAttributeChangedSignal("HitAt"):Connect(function()
		strike(rig)
	end)
	model.DescendantAdded:Connect(function(d) -- pieces can arrive after the model
		if d:IsA("Motor6D") and rigs[model] then
			rigs[model].joints[d.Name] = d
		end
	end)
end

-- Fights (decision 0042): a creature with a "MaxHp" attribute shows a health bar over it, and every
-- change in its "Hp" floats a number: red for damage, green for healing. The server sets both.
local function floatNumber(model: Model, change: number)
	local hit = model:FindFirstChild("Hit") :: BasePart?
	if hit == nil then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.Adornee = hit
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	local x = (math.random() - 0.5) * hit.Size.X * 0.5
	gui.StudsOffset = Vector3.new(x, hit.Size.Y / 2 + 1, 0)
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = if change < 0 then tostring(change) else `+{change}`
	text.TextColor3 = if change < 0 then Color3.fromRGB(255, 90, 80) else Color3.fromRGB(110, 255, 140)
	text.TextStrokeTransparency = 0
	text.Parent = gui
	gui.Parent = hit
	TweenService:Create(gui, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = gui.StudsOffset + Vector3.new(0, 4, 0),
	}):Play()
	TweenService:Create(text, TweenInfo.new(1.0), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(gui, 1.1)
end

local function watchHealth(model: Model)
	local hit = model:FindFirstChild("Hit") :: BasePart?
	local maxHp = model:GetAttribute("MaxHp")
	if hit == nil or type(maxHp) ~= "number" or hit:FindFirstChild("HealthBar") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.fromOffset(110, 12)
	gui.Adornee = hit
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.StudsOffset = Vector3.new(0, hit.Size.Y / 2 + 1.2, 0)
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 26, 36)
	back.BorderSizePixel = 0
	back.Parent = gui
	local edge = Instance.new("UIStroke")
	edge.Thickness = 2
	edge.Color = if model:GetAttribute("Side") == 2 then Color3.fromRGB(150, 255, 70) else Color3.fromRGB(255, 200, 70)
	edge.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = if model:GetAttribute("Side") == 2
		then Color3.fromRGB(220, 70, 70)
		else Color3.fromRGB(90, 210, 110)
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = hit
	local last = model:GetAttribute("Hp")
	local function update()
		local hp, full = model:GetAttribute("Hp"), model:GetAttribute("MaxHp")
		if type(hp) ~= "number" or type(full) ~= "number" then
			return
		end
		if type(last) == "number" and hp ~= last then
			floatNumber(model, hp - last)
		end
		last = hp
		TweenService
			:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(math.clamp(hp / math.max(1, full), 0, 1), 1) })
			:Play()
		gui.Enabled = hp > 0
	end
	model:GetAttributeChangedSignal("Hp"):Connect(update)
	update()
end

CollectionService:GetInstanceAddedSignal("Creature"):Connect(add)
CollectionService:GetInstanceAddedSignal("Creature"):Connect(function(model)
	task.defer(function() -- its attributes and parts arrive just after the tag
		for _ = 1, 20 do
			if model:FindFirstChild("Hit") and model:GetAttribute("MaxHp") ~= nil then
				watchHealth(model :: Model)
				return
			end
			task.wait(0.1)
		end
	end)
end)
CollectionService:GetInstanceRemovedSignal("Creature"):Connect(function(model)
	rigs[model :: Model] = nil
end)
for _, model in CollectionService:GetTagged("Creature") do
	add(model)
end

-- Motor6D.Transform is applied in the simulation step, so set it just before.
RunService.PreSimulation:Connect(function(dt: number)
	local time = Workspace:GetServerTimeNow()
	for model, rig in rigs do
		if model:GetAttribute("Rainbow") then -- a rainbow animal's Neon pieces turn through the colours
			for i, d in model:GetChildren() do
				if d:IsA("MeshPart") and d.Material == Enum.Material.Neon then
					d.Color = Color3.fromHSV((time * 0.3 + i * 0.21) % 1, 0.8, 1)
				end
			end
		end
		local anim = model:GetAttribute("Anim") :: string?
		local at = (model:GetAttribute("AnimAt") :: number?) or time
		local clock = os.clock()
		-- a hit-stop freezes this clip, the killing blow's slow motion slows them all; the server's
		-- timing does neither: a clip only reads a later time than the server's
		local speed = if clock < rig.stopUntil then 0 else FightFx.slow(clock - slowAt)
		if speed < 1 then
			if rig.heldFor ~= at then
				rig.heldFor, rig.held = at, 0
			end
			rig.held += dt * (1 - speed)
		end
		local t = math.max(0, time - at - (if rig.heldFor == at then rig.held else 0))
		local biped = model:GetAttribute("Biped") == true
		local target: Pose
		if anim == "die" then -- holds its last pose
			target = sample(if biped then DIE_BIPED else DIE_QUAD, t)
			local body = target.body
			if body then
				if rig.rest == 0 then
					local asset = model:GetAttribute("Asset")
					local mesh = model:FindFirstChild(`{asset}_body`) :: BasePart?
					local root = model.PrimaryPart
					rig.rest = if mesh and root then math.max(1, mesh.Position.Y - root.Position.Y) else 1
				end
				local fall = table.clone(body) -- the clip's y is a share of the body's height
				fall[5] = body[5] * rig.rest / ((model:GetAttribute("Scale") :: number?) or 1)
				target = table.clone(target)
				target.body = fall
			end
		elseif anim == "hit" and t < HIT.length then
			target = sample(HIT, t)
			if rig.flinch ~= 1 then
				target = scaled(target, rig.flinch)
			end
			if PLANTED[speciesOf(model) or ""] then
				target = table.clone(target)
				for _, leg in { "leg_fl", "leg_fr", "leg_bl", "leg_br" } do
					target[leg] = nil
				end
			end
		elseif anim == "win" then
			local own = WINS[speciesOf(model) or ""]
			target = if own and not biped then own(t) else win(t, biped)
		elseif anim == "walk" then
			local rate = (model:GetAttribute("Stride") :: number?) or 1.5
			target = if biped then walkBiped(time, rate, model:GetAttribute("Hexbound") ~= true) else walk(time, rate)
		elseif anim and TRAIN[anim] then
			target = TRAIN[anim](time, (model:GetAttribute("Stride") :: number?) or 1.5, biped, model)
		elseif anim == "attack" and t < ATTACK.length then
			local kind = model:GetAttribute("Asset")
			local clip = if not biped
				then pick(ATTACKS, model, ATTACK)
				elseif kind == "foe_archer" then ARCHER_ATTACK
				elseif kind == "foe_mage" then MAGE_ATTACK
				else pick(ATTACKS, model, BIPED_ATTACK) -- an upright animal has its own
			target = sample(clip, t)
		elseif anim == "magic" and t < MAGIC.length then
			target = sample(pick(MAGICS, model, if biped then BIPED_MAGIC else MAGIC), t)
			if rig.magicAt ~= at then
				rig.magicAt = at
				charge(model, (magicColour(model)), math.max(0.1, MAGIC_IMPACT - t))
			end
			if t >= MAGIC_IMPACT and rig.impactAt ~= at then
				rig.impactAt = at
				impact(model, magicColour(model))
			end
		else
			target = if biped then idleBiped(time) else idle(time)
		end
		if model:GetAttribute("Winged") == true then
			target = table.clone(target)
			for joint, v in wings(time, anim) do
				target[joint] = v
			end
		end
		if biped and model:GetAttribute("Hexbound") ~= true then
			-- an upright animal's tail lies on the ground behind it: it never swings below where it rests,
			-- and lifts by as much as the body leans back
			local tail, body = target.tail, target.body
			target = table.clone(target)
			target.tail = {
				math.min(if tail then tail[1] or 0 else 0, 0) - math.max(if body then body[1] or 0 else 0, 0),
				if tail then tail[2] or 0 else 0,
				if tail then tail[3] or 0 else 0,
			}
		end
		local scale = ((model:GetAttribute("Scale") :: number?) or 1)
		local blend = math.min(1, dt * 22)
		for _, joint in JOINTS do
			local goal, v = target[joint], rig.now[joint]
			for k = 1, 6 do
				v[k] += ((if goal then goal[k] or 0 else 0) - v[k]) * blend
			end
		end
		local lift = Vector3.zero -- feet stay on the ground, except in a fall
		if anim ~= "die" then
			rig.feet = rig.feet or feetOf(rig.joints)
			local feet = rig.feet
			if feet then
				lift = feet.base:VectorToObjectSpace(Vector3.new(0, sunk(feet, rig.now, scale), 0))
			end
		end
		for _, joint in JOINTS do
			local motor = rig.joints[joint]
			if motor then
				local pose = turned(rig.now[joint], scale)
				motor.Transform = if joint == "body" then CFrame.new(lift) * pose else pose
			end
		end
	end
end)
