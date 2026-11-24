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
local FoePowers = require(script.Parent:WaitForChild("FoePowers"))
local AnimalMoves = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimalMoves"))
local AnimalRig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimalRig"))
local Spells = require(script.Parent:WaitForChild("Spells"))

type Pose = { [string]: { number } }
type Clip = { length: number, keys: { { any } } }

-- (elbow_l bends leg_fl's forearm, elbow_r leg_fr's: only the A-pose Shadow Legion models have them; a "weapon" turns
-- in a fist, on its forearm (the Ogre Commander's great axe). The Dark
-- Drake's neck_base carries its head and jaw, its wing_l and wing_r bend at hand_l and hand_r, and its tail goes on
-- through tail_mid to tail_end: each child's turn is on top of its parent's)
local JOINTS = {
	"body",
	"head",
	"leg_fl",
	"leg_fr",
	"leg_bl",
	"leg_br",
	"tail",
	"wing_l",
	"wing_r",
	"elbow_l",
	"elbow_r",
	"arrow",
	"neck_base",
	"jaw",
	"hand_l",
	"hand_r",
	"tail_mid",
	"tail_end",
	"weapon",
}
local WING_JOINTS = { "wing_l", "wing_r", "hand_l", "hand_r" }
local TWO_HANDED = { foe_ogre_commander_forge = true } -- (both its fists hold its great axe)
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
-- with its contact near 0.44 s, where the server lands the hit; a variant uses its species' clip. The
-- animals' are SHANNON's picks in AnimalMoves; the horn charge above (ATTACK) is the fallback.
local function attack(keys: { { any } }): Clip
	return { length = 0.95, keys = keys }
end
local ATTACKS: { [string]: Clip } = {
	-- the Ancient Alpha Dragon's breath sweep (SHANNON's pick), out of its coil: rears its head back on its neck, then
	-- thrusts it forward with its jaws wide at the contact (0.44 s) and sweeps them from one side to the other (the breath
	-- itself comes with the effect pass)
	foe_dragon_alpha_forge = attack({
		{ 0.00, {} },
		{
			0.16,
			{
				body = { 8, 0, 0, 0, 0.05, 0.3 },
				neck_base = { 26 },
				head = { -20 },
				jaw = { -10 },
				leg_fl = { -10 },
				leg_fr = { -10 },
				leg_bl = { 6 },
				leg_br = { 6 },
				wing_l = { 0, -10, -8 },
				wing_r = { 0, 10, 8 },
			},
		},
		{
			0.32,
			{
				body = { 10, 0, 0, 0, 0.06, 0.35 },
				neck_base = { 30 },
				head = { -24 },
				jaw = { -16 },
				leg_fl = { -12 },
				leg_fr = { -12 },
				leg_bl = { 8 },
				leg_br = { 8 },
				wing_l = { 0, -14, -12 },
				wing_r = { 0, 14, 12 },
			},
		},
		{
			0.44,
			{
				body = { -4, 0, 0, 0, -0.04, -0.3 },
				neck_base = { -10 },
				head = { 6, -28 },
				jaw = { -28 },
				leg_fl = { 14 },
				leg_fr = { 10 },
				leg_bl = { -8 },
				leg_br = { -8 },
				wing_l = { 0, -15 },
				hand_l = { 0, -10 },
				wing_r = { 0, 15 },
				hand_r = { 0, 10 },
			},
		},
		{
			0.62,
			{
				body = { -4, 0, 0, 0, -0.04, -0.3 },
				neck_base = { -10 },
				head = { 6 },
				jaw = { -28 },
				leg_fl = { 14 },
				leg_fr = { 10 },
				leg_bl = { -8 },
				leg_br = { -8 },
				wing_l = { 0, -15 },
				hand_l = { 0, -10 },
				wing_r = { 0, 15 },
				hand_r = { 0, 10 },
			},
		},
		{
			0.80,
			{
				body = { -4, 0, 0, 0, -0.04, -0.3 },
				neck_base = { -10 },
				head = { 6, 28 },
				jaw = { -28 },
				leg_fl = { 14 },
				leg_fr = { 10 },
				leg_bl = { -8 },
				leg_br = { -8 },
				wing_l = { 0, -15 },
				hand_l = { 0, -10 },
				wing_r = { 0, 15 },
				hand_r = { 0, 10 },
			},
		},
		{ 0.95, {} },
	}),
	-- the Shadow Dragon's pounce (SHANNON's pick), out of its mantle: crouches, springs forward with its wings
	-- beating, and lands on both forefeet at the contact (0.44 s), its jaws snapping shut
	foe_dragon_forge = attack({
		{ 0.00, {} },
		{
			0.16,
			{
				body = { -8, 0, 0, 0, -0.2, 0.3 },
				neck_base = { -10 },
				head = { 8 },
				jaw = { -6 },
				leg_fl = { -10 },
				leg_fr = { -10 },
				leg_bl = { 16 },
				leg_br = { 16 },
				tail = { -6 },
				wing_l = { 0, 20, -30 },
				hand_l = { 0, 10, -14 },
				wing_r = { 0, -20, 30 },
				hand_r = { 0, -10, 14 },
			},
		},
		{
			0.30,
			{
				body = { 10, 0, 0, 0, 0.55, -0.6 },
				neck_base = { 10 },
				head = { -6 },
				jaw = { -24 },
				leg_fl = { -50 },
				leg_fr = { -45 },
				leg_bl = { -30 },
				leg_br = { -28 },
				tail = { -12 },
				wing_l = { 0, 0, -45 },
				hand_l = { 0, 0, -20 },
				wing_r = { 0, 0, 45 },
				hand_r = { 0, 0, 20 },
			},
		},
		{
			0.44,
			{
				body = { -14, 0, 0, 0, -0.12, -1.5 },
				neck_base = { -20 },
				head = { 12 },
				jaw = { 12 },
				leg_fl = { 40 },
				leg_fr = { 36 },
				leg_bl = { -24 },
				leg_br = { -22 },
				tail = { 10 },
				wing_l = { 0, -10, 32 },
				hand_l = { 0, -4, 22 },
				wing_r = { 0, 10, -32 },
				hand_r = { 0, 4, -22 },
			},
		},
		{
			0.62,
			{
				body = { -12, 0, 0, 0, -0.1, -1.4 },
				neck_base = { -16 },
				head = { 8 },
				jaw = { 6 },
				leg_fl = { 34 },
				leg_fr = { 32 },
				leg_bl = { -20 },
				leg_br = { -18 },
				tail = { 8 },
				wing_l = { 0, -6, 22 },
				hand_l = { 0, -2, 14 },
				wing_r = { 0, 6, -22 },
				hand_r = { 0, 2, -14 },
			},
		},
		{ 0.95, {} },
	}),
	-- the Siege Golem's haymaker (SHANNON's pick), out of its knuckles down: twists away with its right fist drawn
	-- back, then swings it across in a huge hook at the contact (0.44 s), its body turning into the punch
	foe_golem_forge = attack({
		{ 0.00, {} },
		{
			0.16,
			{
				body = { 4, -20, 0, 0, 0.02, 0.2 },
				head = { 0, 16 },
				leg_fl = { 30, 0, -6 },
				elbow_l = { 50 },
				leg_fr = { 50, -50 },
				elbow_r = { 70 },
				leg_bl = { 6 },
				leg_br = { -8 },
			},
		},
		{
			0.32,
			{
				body = { 6, -32, 0, 0, 0.03, 0.3 },
				head = { 0, 24 },
				leg_fl = { 34, 0, -8 },
				elbow_l = { 55 },
				leg_fr = { 60, -75 },
				elbow_r = { 80 },
				leg_bl = { 8 },
				leg_br = { -10 },
			},
		},
		{
			0.44,
			{
				body = { -10, 26, 0, 0, -0.06, -0.8 },
				head = { -6, -16 },
				leg_fl = { 10, 0, -6 },
				elbow_l = { 40 },
				leg_fr = { 80, 30 },
				elbow_r = { 20 },
				leg_bl = { -14 },
				leg_br = { 30 },
			},
		},
		{
			0.62,
			{
				body = { -8, 22, 0, 0, -0.05, -0.7 },
				head = { -4, -14 },
				leg_fl = { 12 },
				elbow_l = { 40 },
				leg_fr = { 74, 26 },
				elbow_r = { 24 },
				leg_bl = { -12 },
				leg_br = { 26 },
			},
		},
		{ 0.95, {} },
	}),
	-- the Cavalry Commander's charging slash (SHANNON's pick), out of its sword aloft: the horse gathers as the rider
	-- swings its sword up and back, then lunges forward as the sword sweeps down across its neck at the contact (0.44 s)
	foe_cavalry_commander_forge = attack({
		{ 0.00, {} },
		{
			0.16,
			{
				body = { 8, 0, 0, 0, 0.05, 0.4 },
				head = { 14 },
				leg_fl = { -25 },
				leg_fr = { -20 },
				elbow_r = { 20, 0, 20 },
				leg_bl = { 10 },
				leg_br = { 12 },
			},
		},
		{
			0.32,
			{
				body = { 10, 0, 0, 0, 0.06, 0.5 },
				head = { 16 },
				leg_fl = { -30 },
				leg_fr = { -24 },
				elbow_r = { 30, 0, 30 },
				leg_bl = { 12 },
				leg_br = { 14 },
			},
		},
		{
			0.44,
			{
				body = { -8, 0, 0, 0, -0.04, -1.6 },
				head = { -14 },
				leg_fl = { 35 },
				leg_fr = { 30 },
				elbow_r = { -80, -20, -10 },
				leg_bl = { -28 },
				leg_br = { -24 },
			},
		},
		{
			0.62,
			{
				body = { -6, 0, 0, 0, -0.03, -1.4 },
				head = { -10 },
				leg_fl = { 28 },
				leg_fr = { 24 },
				elbow_r = { -70, -15, -10 },
				leg_bl = { -22 },
				leg_br = { -20 },
			},
		},
		{ 0.95, {} },
	}),
	-- the Shieldbearer Commander's lunge thrust (SHANNON's pick), out of its sword on its shoulder: draws the sword
	-- down to its hip behind its raised shield, then lunges and drives the blade straight out along its arm at the
	-- contact (0.44 s) (the sword turns in its fist, its "weapon" joint, to point along the arm)
	foe_knight_shield_commander_forge = attack({
		{ 0.00, {} },
		{
			0.16,
			{
				body = { 4, -10, 0, 0, 0.02, 0.25 },
				leg_fl = { 45, 0, 12 },
				elbow_l = { -45 },
				leg_fr = { -30 },
				elbow_r = { 100 },
				weapon = { -70 },
				leg_bl = { 4 },
				leg_br = { -3 },
			},
		},
		{
			0.32,
			{
				body = { 6, -14, 0, 0, 0.03, 0.35 },
				leg_fl = { 45, 0, 12 },
				elbow_l = { -45 },
				leg_fr = { -40 },
				elbow_r = { 105 },
				weapon = { -65 },
				leg_bl = { 6 },
				leg_br = { -4 },
			},
		},
		{
			0.44,
			{
				body = { -12, 10, 0, 0, -0.1, -1.2 },
				head = { -4, -8 },
				leg_fl = { 30, 0, 15 },
				elbow_l = { -30 },
				leg_fr = { 85 },
				elbow_r = { 0 },
				weapon = { -85 },
				leg_bl = { -12 },
				leg_br = { 38 },
			},
		},
		{
			0.60,
			{
				body = { -10, 8, 0, 0, -0.08, -1.05 },
				head = { -3, -6 },
				leg_fl = { 30, 0, 15 },
				elbow_l = { -30 },
				leg_fr = { 80 },
				elbow_r = { 0 },
				weapon = { -80 },
				leg_bl = { -10 },
				leg_br = { 34 },
			},
		},
		{ 0.95, {} },
	}),
	-- the Dark Drake's lunge bite (SHANNON's pick), out of its prowl: coils back with its neck reared, jaws gaping and
	-- wings flared high, then lunges as the wings sweep down and forward; its jaws snap shut on the contact (0.44 s)
	-- and it shakes its prey once each way
	foe_dragon_drake_forge = attack({
		{ 0.00, {} },
		{
			0.16,
			{
				body = { 10, 0, 0, 0, 0.08, 0.45 },
				neck_base = { 22 },
				head = { -14 },
				jaw = { -10 },
				leg_fl = { -16 },
				leg_fr = { -12 },
				leg_bl = { 8 },
				leg_br = { 10 },
				tail = { -8 },
				tail_mid = { -6 },
				tail_end = { -8 },
				wing_l = { 0, 10, -26 },
				hand_l = { 0, -4, -10 },
				wing_r = { 0, -10, 26 },
				hand_r = { 0, 4, 10 },
			},
		},
		{
			0.32,
			{
				body = { 14, 0, 0, 0, 0.12, 0.6 },
				neck_base = { 30 },
				head = { -22 },
				jaw = { -24 },
				leg_fl = { -20 },
				leg_fr = { -16 },
				leg_bl = { 12 },
				leg_br = { 14 },
				tail = { -12 },
				tail_mid = { -8 },
				tail_end = { -10 },
				wing_l = { 0, 14, -38 },
				hand_l = { 0, -6, -16 },
				wing_r = { 0, -14, 38 },
				hand_r = { 0, 6, 16 },
			},
		},
		{
			0.40,
			{
				body = { -8, 0, 0, 0, -0.12, -1.2 },
				neck_base = { -10 },
				head = { 4 },
				jaw = { -26 },
				leg_fl = { 26 },
				leg_fr = { 22 },
				leg_bl = { -18 },
				leg_br = { -16 },
				tail = { -4 },
				tail_mid = { -4 },
				tail_end = { -6 },
				wing_l = { 0, -8, 14 },
				hand_l = { 0, 0, 10 },
				wing_r = { 0, 8, -14 },
				hand_r = { 0, 0, -10 },
			},
		},
		{
			0.44,
			{
				body = { -14, 0, 0, 0, -0.18, -1.7 },
				neck_base = { -22 },
				head = { 12 },
				jaw = { 12 },
				leg_fl = { 34 },
				leg_fr = { 28 },
				leg_bl = { -24 },
				leg_br = { -20 },
				tail = { 10 },
				tail_mid = { 8 },
				tail_end = { 10 },
				wing_l = { 0, -12, 30 },
				hand_l = { 0, -4, 22 },
				wing_r = { 0, 12, -30 },
				hand_r = { 0, 4, -22 },
			},
		},
		{
			0.56,
			{
				body = { -12, 4, 0, 0, -0.16, -1.55 },
				neck_base = { -20, 10 },
				head = { 10, 12, -10 },
				jaw = { 10 },
				leg_fl = { 30 },
				leg_fr = { 24 },
				leg_bl = { -20 },
				leg_br = { -18 },
				tail = { 6, -10 },
				tail_mid = { 4, -8 },
				tail_end = { 6, -10 },
				wing_l = { 0, -8, 20 },
				hand_l = { 0, 0, 16 },
				wing_r = { 0, 8, -20 },
				hand_r = { 0, 0, -16 },
			},
		},
		{
			0.68,
			{
				body = { -10, -4, 0, 0, -0.14, -1.4 },
				neck_base = { -18, -10 },
				head = { 8, -12, 10 },
				jaw = { 8 },
				leg_fl = { 26 },
				leg_fr = { 22 },
				leg_bl = { -18 },
				leg_br = { -16 },
				tail = { 4, 10 },
				tail_mid = { 2, 8 },
				tail_end = { 4, 10 },
				wing_l = { 0, -4, 14 },
				hand_l = { 0, 0, 12 },
				wing_r = { 0, 4, -14 },
				hand_r = { 0, 0, -12 },
			},
		},
		{ 0.95, {} },
	}),
	-- the Ogre Commander's two-handed overhead chop (SHANNON's pick), out of its great axe held up before it: both arms
	-- heave the axe up and back over its head, then swing it over the top and down into the ground before it at the
	-- contact (0.44 s), stooping into the blow. Both arms always turn alike (its rest holds the haft in both fists and
	-- its shoulders lie on one line), so its hands stay on the haft and nothing bends
	foe_ogre_commander_forge = attack({
		{ 0.00, {} },
		{
			0.16,
			{
				body = { 10, 0, 0, 0, 0.08, 0.3 },
				head = { 8 },
				leg_fl = { 95 },
				leg_fr = { 95 },
				leg_bl = { 4 },
				leg_br = { -4 },
			},
		},
		{
			0.32,
			{
				body = { 16, 0, 0, 0, 0.12, 0.4 },
				head = { 12 },
				leg_fl = { 125 },
				leg_fr = { 125 },
				leg_bl = { 8 },
				leg_br = { -6 },
			},
		},
		{
			0.40,
			{
				body = { -12, 0, 0, 0, -0.06, -0.6 },
				head = { -6 },
				leg_fl = { 40 },
				leg_fr = { 40 },
				leg_bl = { 24 },
				leg_br = { -10 },
			},
		},
		{
			0.44,
			{
				body = { -30, 0, 0, 0, -0.15, -1 },
				head = { -14 },
				leg_fl = { -40 },
				leg_fr = { -40 },
				leg_bl = { 38 },
				leg_br = { -14 },
			},
		},
		{
			0.60,
			{
				body = { -26, 0, 0, 0, -0.12, -0.9 },
				head = { -10 },
				leg_fl = { -36 },
				leg_fr = { -36 },
				leg_bl = { 34 },
				leg_br = { -12 },
			},
		},
		{ 0.95, {} },
	}),
	-- the Necromancer's staff drive (SHANNON's pick), out of its skull in its palm: raises the skull staff high, its
	-- clawed hand up, and drives the staff's foot into the ground before it at the contact (0.44 s), leaning in
	foe_mage_necromancer_forge = attack({
		{ 0.00, {} },
		{
			0.16,
			{
				body = { 6, -6, 0, 0, 0.05, 0.15 },
				head = { 10, -6 },
				leg_fl = { 60 },
				elbow_l = { 20 },
				leg_fr = { 45 },
				elbow_r = { -45 },
			},
		},
		{
			0.32,
			{
				body = { 10, -8, 0, 0, 0.1, 0.2 },
				head = { 14, -8 },
				leg_fl = { 90 },
				elbow_l = { 25 },
				leg_fr = { 60 },
				elbow_r = { -58 },
				leg_bl = { -4 },
				leg_br = { 4 },
			},
		},
		{
			0.44,
			{
				body = { -16, -10, 0, 0, -0.08, -0.5 },
				head = { -8, -6 },
				leg_fl = { 30, 0, -10 },
				elbow_l = { -20 },
				leg_fr = { 8 },
				elbow_r = { -6 },
				leg_bl = { 16 },
				leg_br = { -10 },
			},
		},
		{
			0.62,
			{
				body = { -14, -8, 0, 0, -0.07, -0.45 },
				head = { -6, -6 },
				leg_fl = { 28, 0, -10 },
				elbow_l = { -18 },
				leg_fr = { 8 },
				elbow_r = { -6 },
				leg_bl = { 14 },
				leg_br = { -8 },
			},
		},
		{ 0.95, {} },
	}),
	-- the Cavalry's charging thrust (SHANNON's pick), out of its lance held upright: lowers the lance into the couch
	-- as its horse gathers, lunges and drives it home at the contact (0.44 s), then raises it upright again
	foe_cavalry_forge = attack({
		{
			0.00,
			{
				head = { -4 },
				elbow_r = { 88 },
			},
		},
		{
			0.16,
			{
				body = { 8, 0, 0, 0, 0.05, 0.4 },
				head = { 14 },
				leg_fl = { -25 },
				leg_fr = { -20 },
				elbow_r = { 50, 0, 0, 0, 0, 0.3 },
				leg_bl = { 10 },
				leg_br = { 12 },
			},
		},
		{
			0.32,
			{
				body = { 10, 0, 0, 0, 0.06, 0.5 },
				head = { 16 },
				leg_fl = { -30 },
				leg_fr = { -24 },
				elbow_r = { 14, 0, 0, 0, 0, 0.4 },
				leg_bl = { 12 },
				leg_br = { 14 },
			},
		},
		{
			0.44,
			{
				body = { -8, 0, 0, 0, -0.04, -1.6 },
				head = { -14 },
				leg_fl = { 35 },
				leg_fr = { 30 },
				elbow_r = { -8, 0, 0, 0, 0, -0.6 },
				leg_bl = { -28 },
				leg_br = { -24 },
			},
		},
		{
			0.62,
			{
				body = { -6, 0, 0, 0, -0.03, -1.4 },
				head = { -10 },
				leg_fl = { 28 },
				leg_fr = { 24 },
				elbow_r = { -6, 0, 0, 0, 0, -0.5 },
				leg_bl = { -22 },
				leg_br = { -20 },
			},
		},
		{
			0.95,
			{
				head = { -4 },
				elbow_r = { 88 },
			},
		},
	}),
	-- the Berserker's wild overhead chop (SHANNON's pick), out of dragging its axe: heaves the axe up overhead in both hands
	-- and brings it crashing down before it at the contact (0.44 s), then lets it drop back to the ground
	foe_knight_berserker_forge = attack({
		{ 0.00, {} },
		{
			0.16,
			{
				body = { 10, -10, 0, 0, 0.08, 0.3 },
				head = { 10 },
				leg_fl = { 160, 0, -15 },
				elbow_l = { 40 },
				leg_fr = { 180 },
				elbow_r = { 40 },
				leg_bl = { 4 },
				leg_br = { -4 },
			},
		},
		{
			0.32,
			{
				body = { 14, -12, 0, 0, 0.12, 0.35 },
				head = { 12 },
				leg_fl = { 195, 0, -20 },
				elbow_l = { 20 },
				leg_fr = { 210, 0, 6 },
				elbow_r = { 20 },
				leg_bl = { 8 },
				leg_br = { -6 },
			},
		},
		{
			0.44,
			{
				body = { -30, 4, 0, 0, -0.15, -1.0 },
				head = { -14 },
				leg_fl = { 25, 0, -25 },
				leg_fr = { 15, 15 },
				leg_bl = { 38 },
				leg_br = { -14 },
			},
		},
		{
			0.60,
			{
				body = { -26, 4, 0, 0, -0.12, -0.9 },
				head = { -10 },
				leg_fl = { 28, 0, -24 },
				leg_fr = { 18, 15 },
				leg_bl = { 34 },
				leg_br = { -12 },
			},
		},
		{ 0.95, {} },
	}),
	-- the Crossbow Troop's raise and fire (SHANNON's pick), out of its crossbow at its hip: straightens its arm out at the
	-- target, the crossbow held pistol-like along its forearm, holds the aim, looses with a kick at the release (0.46 s),
	-- and brings it back to its hip
	foe_archer_crossbow_forge = attack({
		{
			0.00,
			{
				leg_fr = { 5 },
				elbow_r = { 85 },
			},
		},
		{
			0.14,
			{
				body = { 0, -12 },
				head = { -2, 12 },
				leg_fl = { 30, 0, 6 },
				elbow_l = { 30 },
				leg_fr = { 55, 4 },
				elbow_r = { 40 },
			},
		},
		{
			0.32,
			{
				body = { 0, -18 },
				head = { -4, 18 },
				leg_fl = { 20, 0, 6 },
				elbow_l = { 20 },
				leg_fr = { 88, 10 },
				elbow_r = { 0 },
				leg_bl = { 10 },
				leg_br = { -6 },
			},
		},
		{
			0.42,
			{
				body = { 0, -18 },
				head = { -4, 18 },
				leg_fl = { 20, 0, 6 },
				elbow_l = { 20 },
				leg_fr = { 88, 10 },
				elbow_r = { 0 },
				leg_bl = { 10 },
				leg_br = { -6 },
			},
		},
		{
			0.46,
			{
				body = { 5, -16, 0, 0, 0.02, 0.3 },
				head = { 2, 16 },
				leg_fl = { 16, 0, 6 },
				elbow_l = { 20 },
				leg_fr = { 104, 10 },
				elbow_r = { 6 },
				leg_bl = { 10 },
				leg_br = { -6 },
				tail = { 12 },
			},
		},
		{
			0.66,
			{
				body = { 2, -10 },
				head = { 0, 10 },
				leg_fl = { 24, 0, 4 },
				elbow_l = { 26 },
				leg_fr = { 50, 4 },
				elbow_r = { 40 },
			},
		},
		{
			0.95,
			{
				leg_fr = { 5 },
				elbow_r = { 85 },
			},
		},
	}),
	-- the Ogre Enforcer's haymaker sweep (SHANNON's pick), out of dragging its club: twists its forearm so the club sticks
	-- out sideways from its fist, winds back, then turns through and sweeps the club's spiked side across at the contact
	-- (0.44 s), and lets it drop back to the ground
	foe_ogre_forge = attack({
		{
			0.00,
			{
				leg_fr = { -20, 10 },
				elbow_r = { 10 },
			},
		},
		{
			0.16,
			{
				body = { 4, -45, 0, 0, 0.02, 0.15 },
				head = { 0, 35 },
				leg_fl = { 20, 0, -10 },
				leg_fr = { 10, -20, 40 },
				elbow_r = { 20, -90 },
				leg_bl = { 8 },
				leg_br = { -6 },
			},
		},
		{
			0.32,
			{
				body = { 6, -55, 0, 0, 0.03, 0.2 },
				head = { 0, 40 },
				leg_fl = { 24, 0, -12 },
				leg_fr = { 10, -30, 45 },
				elbow_r = { 20, -95 },
				leg_bl = { 10 },
				leg_br = { -8 },
			},
		},
		{
			0.44,
			{
				body = { -8, 25, 0, 0, -0.05, -0.6 },
				head = { 0, -15 },
				leg_fl = { 16, 0, -8 },
				leg_fr = { 25, 30, 40 },
				elbow_r = { 15, -90 },
				leg_bl = { 20 },
				leg_br = { -14 },
			},
		},
		{
			0.60,
			{
				body = { -8, 45, 0, 0, -0.05, -0.55 },
				head = { 0, -30 },
				leg_fl = { 14, 0, -6 },
				leg_fr = { 25, 60, 35 },
				elbow_r = { 15, -85 },
				leg_bl = { 18 },
				leg_br = { -12 },
			},
		},
		{
			0.95,
			{
				leg_fr = { -20, 10 },
				elbow_r = { 10 },
			},
		},
	}),
	-- the Darkcaster's staff thump (SHANNON's pick), out of its orb in its palm: lifts its staff upright and slams its
	-- foot into the ground before it at the contact (0.44 s), leaning in
	foe_mage_forge = attack({
		{ 0.00, {} },
		{
			0.16,
			{
				body = { 6, -6, 0, 0, 0.05, 0.15 },
				head = { 8, -6 },
				leg_fr = { 45 },
				elbow_r = { -45 },
			},
		},
		{
			0.32,
			{
				body = { 8, -8, 0, 0, 0.08, 0.2 },
				head = { 10, -8 },
				leg_fr = { 60 },
				elbow_r = { -58 },
				leg_bl = { -4 },
				leg_br = { 4 },
			},
		},
		{
			0.44,
			{
				body = { -14, -10, 0, 0, -0.06, -0.5 },
				head = { -6, -6 },
				leg_fr = { 8 },
				elbow_r = { -6 },
				leg_bl = { 16 },
				leg_br = { -10 },
			},
		},
		{
			0.62,
			{
				body = { -12, -8, 0, 0, -0.05, -0.45 },
				head = { -4, -6 },
				leg_fr = { 8 },
				elbow_r = { -6 },
				leg_bl = { 14 },
				leg_br = { -8 },
			},
		},
		{ 0.95, {} },
	}),
	-- the Shieldbearer's Bash + chop (SHANNON's pick): shoves its huge shield forward while raising the sword
	-- overhead (0.26 s), then chops down past the shield's edge at the contact (0.44 s)
	foe_knight_shield_forge = attack({
		{ 0.00, {} },
		{
			0.12,
			{
				body = { -2, -34, 0, 0, -0.03, 0.2 },
				head = { 0, 28 },
				leg_fl = { 10 },
				elbow_l = { 25, 0, 18 },
				leg_fr = { 60, 0, 8 },
				elbow_r = { 40 },
				leg_bl = { -6 },
				leg_br = { 10 },
			},
		},
		{
			0.26,
			{
				body = { -12, -30, 0, 0, -0.07, -0.9 },
				head = { -4, 26 },
				leg_fl = { 42, 0, -5 },
				elbow_l = { 5, 0, 5 },
				leg_fr = { 150, 0, 10 },
				elbow_r = { 45 },
				leg_bl = { 30 },
				leg_br = { -14 },
			},
		},
		{
			0.36,
			{
				body = { -6, -26, 0, 0, -0.04, -0.95 },
				head = { 0, 22 },
				leg_fl = { 36, 0, -2 },
				elbow_l = { 8, 0, 8 },
				leg_fr = { 165, 0, 10 },
				elbow_r = { 55 },
				leg_bl = { 30 },
				leg_br = { -14 },
			},
		},
		{
			0.44,
			{
				body = { -20, -14, 0, 0, -0.1, -1.1 },
				head = { -8, 12 },
				leg_fl = { 30 },
				elbow_l = { 10, 0, 10 },
				leg_fr = { 50, 0, 8 },
				elbow_r = { 10 },
				leg_bl = { 34 },
				leg_br = { -14 },
			},
		},
		{
			0.60,
			{
				body = { -16, -12, 0, 0, -0.08, -1.0 },
				head = { -6, 10 },
				leg_fl = { 28 },
				elbow_l = { 10, 0, 10 },
				leg_fr = { 44, 0, 8 },
				elbow_r = { 10 },
				leg_bl = { 30 },
				leg_br = { -12 },
			},
		},
		{ 0.95, {} },
	}),
	-- the Shadow Knight's Cleave (SHANNON's pick): sword swung up behind its head on a bent arm, shield
	-- forward, then a step in and a cut down at the contact (0.44 s)
	foe_knight_forge = attack({
		{ 0.00, {} },
		{
			0.16,
			{
				body = { 6, -14, 0, 0, 0.04, 0.2 },
				head = { 4, 10 },
				leg_fl = { 20 },
				elbow_l = { 25, 0, 30 },
				leg_fr = { 140, 0, 8 },
				elbow_r = { 35 },
				leg_bl = { 6 },
				leg_br = { -4 },
			},
		},
		{
			0.32,
			{
				body = { 9, -18, 0, 0, 0.06, 0.25 },
				head = { 6, 14 },
				leg_fl = { 24 },
				elbow_l = { 28, 0, 32 },
				leg_fr = { 152, 0, 8 },
				elbow_r = { 45 },
				leg_bl = { 8 },
				leg_br = { -6 },
			},
		},
		{
			0.44,
			{
				body = { -22, 12, 0, 0, -0.1, -0.85 },
				head = { -8, -8 },
				leg_fl = { 10 },
				elbow_l = { 20, 0, 20 },
				leg_fr = { 32 },
				elbow_r = { 0 },
				leg_bl = { 32 },
				leg_br = { -12 },
			},
		},
		{
			0.60,
			{
				body = { -18, 10, 0, 0, -0.08, -0.75 },
				head = { -6 },
				leg_fl = { 10 },
				elbow_l = { 20, 0, 20 },
				leg_fr = { 22 },
				leg_bl = { 28 },
				leg_br = { -10 },
			},
		},
		{ 0.95, {} },
	}),
	-- the Battle Priest's Scripture cast (SHANNON's pick): the open book drawn in to its chest, then
	-- thrust out at the enemy as its magic bolt leaves it (boltFx, FightFx.BOLTS)
	foe_mage_priest_forge = attack({
		{ 0.00, {} },
		{
			0.16,
			{
				body = { 5, 8, 0, 0, 0.02, 0.1 },
				head = { -10 },
				leg_fl = { -12 },
				elbow_l = { 18 },
				leg_fr = { 6 },
			},
		},
		{
			0.32,
			{
				body = { 7, 10, 0, 0, 0.03, 0.15 },
				head = { -12 },
				leg_fl = { -16 },
				elbow_l = { 22 },
				leg_fr = { 8 },
			},
		},
		{
			0.44,
			{
				body = { -12, -14, 0, 0, -0.03, -0.6 },
				head = { 12 },
				leg_fl = { 62, 0, -14 },
				elbow_l = { -58 },
				leg_fr = { 18 },
			},
		},
		{
			0.62,
			{
				body = { -10, -12, 0, 0, -0.02, -0.5 },
				head = { 10 },
				leg_fl = { 58, 0, -14 },
				elbow_l = { -54 },
				leg_fr = { 16 },
			},
		},
		{ 0.95, {} },
	}),
	-- the Heavy Knight's Overhead Crush (SHANNON's pick), from its hammer on its shoulder: heaves the hammer straight up
	-- off its shoulder and overhead, drives the head down into the ground at the contact (0.44 s), the arm's twist
	-- keeping the head pointing ahead, then swings the hammer back up onto its shoulder
	foe_knight_heavy_forge = attack({
		{
			0.00,
			{
				leg_fl = { 6, 0, 4 },
				elbow_l = { 24, 0, 10 },
				leg_fr = { 9, -39, -41 },
				elbow_r = { 99, -25, -78 },
			},
		},
		{
			0.16,
			{
				body = { 8, -12, 0, 0, 0.06, 0.25 },
				head = { 8 },
				leg_fl = { 35, 0, -10 },
				leg_fr = { 150 },
				elbow_r = { 70 },
				leg_bl = { 6 },
				leg_br = { -4 },
			},
		},
		{
			0.32,
			{
				body = { 12, -16, 0, 0, 0.1, 0.3 },
				head = { 10 },
				leg_fl = { 45, 0, -12 },
				leg_fr = { 210, 0, 8 },
				elbow_r = { 15 },
				leg_bl = { 10 },
				leg_br = { -6 },
			},
		},
		{
			0.44,
			{
				body = { -26, 0, 0, 0, -0.12, -0.95 },
				head = { -14 },
				leg_fl = { 10, 0, -20 },
				leg_fr = { 0, 20 },
				leg_bl = { 36 },
				leg_br = { -12 },
			},
		},
		{
			0.58,
			{
				body = { -22, 0, 0, 0, -0.1, -0.85 },
				head = { -10 },
				leg_fl = { 12, 0, -18 },
				leg_fr = { 4, 18 },
				leg_bl = { 32 },
				leg_br = { -10 },
			},
		},
		{
			0.95,
			{
				leg_fl = { 6, 0, 4 },
				elbow_l = { 24, 0, 10 },
				leg_fr = { 9, -39, -41 },
				elbow_r = { 99, -25, -78 },
			},
		},
	}),
	-- the Shadow Archer (elbows; an arrow fixed in its drawing fist, set for this draw): turns side-on and
	-- holds the bow out at the target, brings the arrow to the string, draws it back along its chest, looses
	-- at the contact (0.44 s), then turns back
	foe_archer_forge = attack({
		{ 0.00, {} },
		{
			0.14,
			{
				body = { 0, -60, 0 },
				head = { 0, 52, 0 },
				leg_fl = { -50, 1, -76 },
				leg_fr = { 62, 45, 32 },
				elbow_r = { 43, 89, 46 },
				arrow = { 0, 0, -56.3, -0.652, -0.84, -0.97 },
			},
		},
		{
			0.32,
			{
				body = { 2, -88, 0, 0, 0, 0.1 },
				head = { 0, 78, 0 },
				leg_fl = { -65, 1, -98 },
				leg_fr = { 49, 14, 58 },
				elbow_r = { 58, 89, 46 },
				leg_bl = { 0, 0, -8 },
				leg_br = { 0, 0, 8 },
				arrow = { 0, 0, -56.3, -0.33, -0.84, -0.97 },
			},
		},
		{
			0.42,
			{
				body = { 2, -88, 0, 0, 0, 0.1 },
				head = { 0, 78, 0 },
				leg_fl = { -65, 1, -98 },
				leg_fr = { 49, 14, 60 },
				elbow_r = { 58, 89, 46 },
				leg_bl = { 0, 0, -8 },
				leg_br = { 0, 0, 8 },
				arrow = { 0, 0, -56.3, -0.33, -0.84, -0.97 },
			},
		},
		{
			0.44,
			{
				body = { 3, -84, 0, 0, 0.02, 0.3 },
				head = { 0, 76, 0 },
				leg_fl = { -65, 1, -98 },
				leg_fr = { 47, 14, 70 },
				elbow_r = { 40, 89, 46 },
				leg_bl = { 0, 0, -8 },
				leg_br = { 0, 0, 8 },
				tail = { 12 },
			},
		},
		{
			0.64,
			{
				body = { 0, -40, 0 },
				head = { 0, 34, 0 },
				leg_fl = { -30, 0, -45 },
				leg_fr = { 20, 8, 25 },
				elbow_r = { 20, 40, 20 },
			},
		},
		{ 0.95, {} },
	}),
}
for species, keys in AnimalMoves.ATTACKS do
	ATTACKS[species] = attack(keys)
end
-- Power attacks (1.6 s, the impact at MAGIC_IMPACT): each animal's spell (SHANNON's picks in AnimalMoves) by
-- species, and by asset for a variant whose spell moves differently ("creature_lion_shadow_forge"); Spells draws
-- the magic.
local MAGICS: { [string]: Clip } = {
	-- the Heavy Knight's Leaping Slam (SHANNON's pick), from its hammer on its shoulder: crouches with the hammer
	-- still shouldered, raises it overhead as it leaps, slams on landing at the impact (0.92 s), shoulders it again
	foe_knight_heavy_forge = {
		length = 1.6,
		keys = {
			{
				0.00,
				{
					leg_fl = { 6, 0, 4 },
					elbow_l = { 24, 0, 10 },
					leg_fr = { 9, -39, -41 },
					elbow_r = { 99, -25, -78 },
				},
			},
			{
				0.30,
				{
					body = { -12, 0, 0, 0, -0.1, 0.1 },
					head = { -6 },
					leg_fl = { -20, 0, -15 },
					leg_fr = { 9, -39, -41 },
					elbow_r = { 99, -25, -78 },
					leg_bl = { 24 },
					leg_br = { 24 },
				},
			},
			{
				0.55,
				{
					body = { 10, 0, 0, 0, 1.2, -0.4 },
					head = { 10 },
					leg_fl = { 150, 0, -10 },
					leg_fr = { 190, 0, 10 },
					elbow_r = { 30 },
					leg_bl = { 30 },
					leg_br = { -20 },
				},
			},
			{
				0.78,
				{
					body = { 14, 0, 0, 0, 1.5, -0.8 },
					head = { 8 },
					leg_fl = { 165, 0, -8 },
					leg_fr = { 215, 0, 8 },
					elbow_r = { 10 },
					leg_bl = { 45 },
					leg_br = { 40 },
				},
			},
			{
				MAGIC_IMPACT,
				{
					body = { -28, 0, 0, 0, -0.1, -1.4 },
					head = { -16 },
					leg_fl = { 40, 0, -30 },
					leg_fr = { 0, 20 },
					leg_bl = { 38 },
					leg_br = { -18 },
				},
			},
			{
				1.12,
				{
					body = { -24, 0, 0, 0, -0.08, -1.3 },
					head = { -12 },
					leg_fl = { 38, 0, -28 },
					leg_fr = { 4, 18 },
					leg_bl = { 34 },
					leg_br = { -16 },
				},
			},
			{
				1.36,
				{
					body = { -4, 0, 0, 0, 0.35, -0.6 },
					leg_fl = { 14, 0, -10 },
					leg_fr = { 30, -20, -20 },
					elbow_r = { 99, -12, -40 },
					leg_bl = { 12 },
					leg_br = { 8 },
				},
			},
			{
				1.60,
				{
					leg_fl = { 6, 0, 4 },
					elbow_l = { 24, 0, 10 },
					leg_fr = { 9, -39, -41 },
					elbow_r = { 99, -25, -78 },
				},
			},
		},
	},
	-- the Shadow Legion's power moves, from SHANNON's concepts (FoePowers draws their effects)
	-- Marked Shot: aimed the whole wind-up (a red line and rings), then one fast bolt (decision 0105)
	foe_archer_crossbow_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.2,
				{
					head = { -2, 12 },
					body = { 0, -12 },
					leg_fl = { 30, 0, 6 },
					elbow_l = { 30 },
					leg_fr = { 55, 4 },
					elbow_r = { 40 },
				},
			},
			{
				0.35,
				{
					head = { -4, 18 },
					body = { 0, -18 },
					leg_fl = { 20, 0, 6 },
					elbow_l = { 20 },
					leg_fr = { 88, 10 },
					elbow_r = {},
					leg_bl = { 10 },
					leg_br = { -6 },
				},
			},
			{
				0.86,
				{
					head = { -4, 18 },
					body = { 0, -18 },
					leg_fl = { 20, 0, 6 },
					elbow_l = { 20 },
					leg_fr = { 88, 10 },
					elbow_r = {},
					leg_bl = { 10 },
					leg_br = { -6 },
				},
			},
			{
				MAGIC_IMPACT,
				{
					head = { 2, 16 },
					body = { 5, -16, 0, 0, 0.02, 0.3 },
					leg_fl = { 16, 0, 6 },
					elbow_l = { 20 },
					leg_fr = { 104, 10 },
					elbow_r = { 6 },
					leg_bl = { 10 },
					leg_br = { -6 },
					tail = { 12 },
				},
			},
			{
				1.2,
				{
					head = { 0, 10 },
					body = { 2, -10 },
					leg_fl = { 24, 0, 4 },
					elbow_l = { 26 },
					leg_fr = { 50, 4 },
					elbow_r = { 40 },
				},
			},
			{ 1.6, {} },
		},
	},
	-- Shadow Volley: one arrow loosed at the sky (0.55 s) splits into five that rain on its target (decision 0105)
	foe_archer_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.25,
				{
					head = { 0, 78 },
					body = { 0, -88, -30 },
					leg_fl = { -65, 1, -98 },
					leg_fr = { 56, 38, 40 },
					elbow_r = { 49, 89, 46 },
					arrow = { 0, 0, -56.3, -0.568, -0.84, -0.97 },
				},
			},
			{
				0.45,
				{
					head = { 0, 78 },
					body = { 0, -88, -38, 0, 0.04, 0.1 },
					leg_fl = { -65, 1, -98 },
					leg_fr = { 49, 14, 58 },
					elbow_r = { 58, 89, 46 },
					arrow = { 0, 0, -56.3, -0.33, -0.84, -0.97 },
				},
			},
			{
				0.52,
				{
					head = { 0, 78 },
					body = { 0, -88, -38, 0, 0.04, 0.1 },
					leg_fl = { -65, 1, -98 },
					leg_fr = { 49, 14, 60 },
					elbow_r = { 58, 89, 46 },
					arrow = { 0, 0, -56.3, -0.33, -0.84, -0.97 },
				},
			},
			{
				0.55,
				{
					head = { 0, 76 },
					body = { 0, -86, -34, 0, 0, 0.3 },
					leg_fl = { -65, 1, -98 },
					leg_fr = { 47, 14, 70 },
					elbow_r = { 40, 89, 46 },
					tail = { 12 },
				},
			},
			{ 0.8, { head = { 0, 52 }, body = { 0, -60, -10 }, leg_fl = { -50, 1, -76 }, leg_fr = { 30, 10, 40 } } },
			{ 1.6, {} },
		},
	},
	-- Royal Charge: three ghost riders charge its target (decision 0105)
	foe_cavalry_commander_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.3,
				{
					head = { 16.1 },
					body = { 9.2, 0, 0, 0, 0.057, 0.46 },
					leg_fl = { -28.75 },
					leg_fr = { -23 },
					elbow_r = { 23, 0, 23 },
					leg_bl = { 11.5 },
					leg_br = { 13.8 },
				},
			},
			{
				0.55,
				{
					head = { 18.4 },
					body = { 11.5, 0, 0, 0, 0.069, 0.575 },
					leg_fl = { -34.5 },
					leg_fr = { -27.6 },
					elbow_r = { 34.5, 0, 34.5 },
					leg_bl = { 13.8 },
					leg_br = { 16.1 },
				},
			},
			{
				0.6,
				{
					head = { 18.4 },
					body = { 11.5, 0, 0, 0, 0.069, 0.575 },
					leg_fl = { -34.5 },
					leg_fr = { -27.6 },
					elbow_r = { 34.5, 0, 34.5 },
					leg_bl = { 13.8 },
					leg_br = { 16.1 },
				},
			},
			{
				0.7,
				{
					head = { -16.1 },
					body = { -9.2, 0, 0, 0, -0.046, -1.84 },
					leg_fl = { 40.25 },
					leg_fr = { 34.5 },
					elbow_r = { -92, -23, -11.5 },
					leg_bl = { -32.2 },
					leg_br = { -27.6 },
				},
			},
			{
				0.95,
				{
					head = { -11.5 },
					body = { -6.9, 0, 0, 0, -0.034, -1.61 },
					leg_fl = { 32.2 },
					leg_fr = { 27.6 },
					elbow_r = { -80.5, -17.25, -11.5 },
					leg_bl = { -25.3 },
					leg_br = { -23 },
				},
			},
			{ 1.6, {} },
		},
	},
	-- Lance Charge: its thrust sends a lance of light (decision 0105)
	foe_cavalry_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.3,
				{
					head = { 16.1 },
					body = { 9.2, 0, 0, 0, 0.057, 0.46 },
					leg_fl = { -28.75 },
					leg_fr = { -23 },
					elbow_r = { 57.5, 0, 0, 0, 0, 0.345 },
					leg_bl = { 11.5 },
					leg_br = { 13.8 },
				},
			},
			{
				0.55,
				{
					head = { 18.4 },
					body = { 11.5, 0, 0, 0, 0.069, 0.575 },
					leg_fl = { -34.5 },
					leg_fr = { -27.6 },
					elbow_r = { 16.1, 0, 0, 0, 0, 0.46 },
					leg_bl = { 13.8 },
					leg_br = { 16.1 },
				},
			},
			{
				0.6,
				{
					head = { 18.4 },
					body = { 11.5, 0, 0, 0, 0.069, 0.575 },
					leg_fl = { -34.5 },
					leg_fr = { -27.6 },
					elbow_r = { 16.1, 0, 0, 0, 0, 0.46 },
					leg_bl = { 13.8 },
					leg_br = { 16.1 },
				},
			},
			{
				0.7,
				{
					head = { -16.1 },
					body = { -9.2, 0, 0, 0, -0.046, -1.84 },
					leg_fl = { 40.25 },
					leg_fr = { 34.5 },
					elbow_r = { -9.2, 0, 0, 0, 0, -0.69 },
					leg_bl = { -32.2 },
					leg_br = { -27.6 },
				},
			},
			{
				0.95,
				{
					head = { -11.5 },
					body = { -6.9, 0, 0, 0, -0.034, -1.61 },
					leg_fl = { 32.2 },
					leg_fr = { 27.6 },
					elbow_r = { -6.9, 0, 0, 0, 0, -0.575 },
					leg_bl = { -25.3 },
					leg_br = { -23 },
				},
			},
			{ 1.6, {} },
		},
	},
	-- Ancient Flame: a flame torrent swept across the team (decision 0105)
	foe_dragon_alpha_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.3,
				{
					head = { -24 },
					neck_base = { 31.2 },
					body = { 9.6, 0, 0, 0, 0.06, 0.36 },
					jaw = { -12 },
					leg_fl = { -12 },
					leg_fr = { -12 },
					leg_bl = { 7.2 },
					leg_br = { 7.2 },
					wing_l = { 0, -12, -9.6 },
					wing_r = { 0, 12, 9.6 },
				},
			},
			{
				0.62,
				{
					head = { -31.2 },
					neck_base = { 39 },
					body = { 13, 0, 0, 0, 0.078, 0.455 },
					jaw = { -20.8 },
					leg_fl = { -15.6 },
					leg_fr = { -15.6 },
					leg_bl = { 10.4 },
					leg_br = { 10.4 },
					wing_l = { 0, -18.2, -15.6 },
					wing_r = { 0, 18.2, 15.6 },
				},
			},
			{
				0.78,
				{
					head = { 6, 28 },
					neck_base = { -10, 15 },
					body = { -4, 0, 0, 0, -0.04, -0.3 },
					jaw = { -32 },
					leg_fl = { 14 },
					leg_fr = { 10 },
					leg_bl = { -8 },
					leg_br = { -8 },
					wing_l = { 0, -15 },
					hand_l = { 0, -10 },
					wing_r = { 0, 15 },
					hand_r = { 0, 10 },
				},
			},
			{
				1.06,
				{
					head = { 6, -28 },
					neck_base = { -10, -15 },
					body = { -4, 0, 0, 0, -0.04, -0.3 },
					jaw = { -32 },
					leg_fl = { 14 },
					leg_fr = { 10 },
					leg_bl = { -8 },
					leg_br = { -8 },
					wing_l = { 0, -15 },
					hand_l = { 0, -10 },
					wing_r = { 0, 15 },
					hand_r = { 0, 10 },
				},
			},
			{
				1.2,
				{
					head = { 6 },
					neck_base = { -10 },
					body = { -4, 0, 0, 0, -0.04, -0.3 },
					jaw = { -28 },
					leg_fl = { 14 },
					leg_fr = { 10 },
					leg_bl = { -8 },
					leg_br = { -8 },
					wing_l = { 0, -15 },
					hand_l = { 0, -10 },
					wing_r = { 0, 15 },
					hand_r = { 0, 10 },
				},
			},
			{ 1.6, {} },
		},
	},
	-- Shadow Volley: a fireball spat at each animal (re-timed in game so all land by the hit) (decision 0105)
	foe_dragon_drake_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.25,
				{
					head = { -15.4 },
					neck_base = { 24.2 },
					body = { 11, 0, 0, 0, 0.088, 0.495 },
					jaw = { -11 },
					leg_fl = { -17.6 },
					leg_fr = { -13.2 },
					leg_bl = { 8.8 },
					leg_br = { 11 },
					tail = { -8.8 },
					tail_mid = { -6.6 },
					tail_end = { -8.8 },
					wing_l = { 0, 11, -28.6 },
					hand_l = { 0, -4.4, -11 },
					wing_r = { 0, -11, 28.6 },
					hand_r = { 0, 4.4, 11 },
				},
			},
			{
				0.42,
				{
					head = { -26.4 },
					neck_base = { 36 },
					body = { 16.8, 0, 0, 0, 0.144, 0.72 },
					jaw = { -28.8 },
					leg_fl = { -24 },
					leg_fr = { -19.2 },
					leg_bl = { 14.4 },
					leg_br = { 16.8 },
					tail = { -14.4 },
					tail_mid = { -9.6 },
					tail_end = { -12 },
					wing_l = { 0, 16.8, -45.6 },
					hand_l = { 0, -7.2, -19.2 },
					wing_r = { 0, -16.8, 45.6 },
					hand_r = { 0, 7.2, 19.2 },
				},
			},
			{
				0.5,
				{
					head = { 2, 18 },
					neck_base = { -8, 10 },
					body = { -6, 0, 0, 0, -0.06, -0.4 },
					jaw = { -26 },
					leg_fl = { 16 },
					leg_fr = { 12 },
					leg_bl = { -10 },
					leg_br = { -8 },
					wing_l = { 0, 10, -30 },
					hand_l = { 0, 0, -10 },
					wing_r = { 0, -10, 30 },
					hand_r = { 0, 0, 10 },
				},
			},
			{
				0.56,
				{
					head = { 2, 6 },
					neck_base = { -8, 3 },
					body = { -6, 0, 0, 0, -0.06, -0.4 },
					jaw = { -26 },
					leg_fl = { 16 },
					leg_fr = { 12 },
					leg_bl = { -10 },
					leg_br = { -8 },
					wing_l = { 0, 10, -30 },
					hand_l = { 0, 0, -10 },
					wing_r = { 0, -10, 30 },
					hand_r = { 0, 0, 10 },
				},
			},
			{
				0.62,
				{
					head = { 2, -6 },
					neck_base = { -8, -3 },
					body = { -6, 0, 0, 0, -0.06, -0.4 },
					jaw = { -26 },
					leg_fl = { 16 },
					leg_fr = { 12 },
					leg_bl = { -10 },
					leg_br = { -8 },
					wing_l = { 0, 10, -30 },
					hand_l = { 0, 0, -10 },
					wing_r = { 0, -10, 30 },
					hand_r = { 0, 0, 10 },
				},
			},
			{
				0.68,
				{
					head = { 2, -18 },
					neck_base = { -8, -10 },
					body = { -6, 0, 0, 0, -0.06, -0.4 },
					jaw = { -26 },
					leg_fl = { 16 },
					leg_fr = { 12 },
					leg_bl = { -10 },
					leg_br = { -8 },
					wing_l = { 0, 10, -30 },
					hand_l = { 0, 0, -10 },
					wing_r = { 0, -10, 30 },
					hand_r = { 0, 0, 10 },
				},
			},
			{
				1,
				{
					head = { 7.2 },
					neck_base = { -13.2 },
					body = { -8.4, 0, 0, 0, -0.108, -1.02 },
					jaw = { 7.2 },
					leg_fl = { 20.4 },
					leg_fr = { 16.8 },
					leg_bl = { -14.4 },
					leg_br = { -12 },
					tail = { 6 },
					tail_mid = { 4.8 },
					tail_end = { 6 },
					wing_l = { 0, -7.2, 18 },
					hand_l = { 0, -2.4, 13.2 },
					wing_r = { 0, 7.2, -18 },
					hand_r = { 0, 2.4, -13.2 },
				},
			},
			{ 1.6, {} },
		},
	},
	-- Eclipse Pounce: in a dark mantle, a shockwave from its landing reaches every animal (decision 0105)
	foe_dragon_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.35,
				{
					head = { 9.6 },
					neck_base = { -12 },
					body = { -9.6, 0, 0, 0, -0.24, 0.36 },
					jaw = { -7.2 },
					leg_fl = { -12 },
					leg_fr = { -12 },
					leg_bl = { 19.2 },
					leg_br = { 19.2 },
					tail = { -7.2 },
					wing_l = { 0, 24, -36 },
					hand_l = { 0, 12, -16.8 },
					wing_r = { 0, -24, 36 },
					hand_r = { 0, -12, 16.8 },
				},
			},
			{
				0.6,
				{
					head = { -7.2 },
					neck_base = { 12 },
					body = { 12, 0, 0, 0, 0.66, -0.72 },
					jaw = { -28.8 },
					leg_fl = { -60 },
					leg_fr = { -54 },
					leg_bl = { -36 },
					leg_br = { -33.6 },
					tail = { -14.4 },
					wing_l = { 0, 0, -54 },
					hand_l = { 0, 0, -24 },
					wing_r = { 0, 0, 54 },
					hand_r = { 0, 0, 24 },
				},
			},
			{
				0.8,
				{
					head = { 13.2 },
					neck_base = { -22 },
					body = { -15.4, 0, 0, 0, -0.132, -1.65 },
					jaw = { 13.2 },
					leg_fl = { 44 },
					leg_fr = { 39.6 },
					leg_bl = { -26.4 },
					leg_br = { -24.2 },
					tail = { 11 },
					wing_l = { 0, -11, 35.2 },
					hand_l = { 0, -4.4, 24.2 },
					wing_r = { 0, 11, -35.2 },
					hand_r = { 0, 4.4, -24.2 },
				},
			},
			{
				1.05,
				{
					head = { 8 },
					neck_base = { -16 },
					body = { -12, 0, 0, 0, -0.1, -1.4 },
					jaw = { 6 },
					leg_fl = { 34 },
					leg_fr = { 32 },
					leg_bl = { -20 },
					leg_br = { -18 },
					tail = { 8 },
					wing_l = { 0, -6, 22 },
					hand_l = { 0, -2, 14 },
					wing_r = { 0, 6, -22 },
					hand_r = { 0, 2, -14 },
				},
			},
			{ 1.6, {} },
		},
	},
	-- Siege Barrage: boulders from its castle land on every animal as its fists pound (decision 0105)
	foe_golem_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.3,
				{
					head = { 6 },
					body = { 6, 0, 0, 0, 0.04, 0.2 },
					leg_fl = { 90, 0, 10 },
					elbow_l = { 40 },
					leg_fr = { 90, 0, -10 },
					elbow_r = { 40 },
					leg_bl = { 6 },
					leg_br = { 6 },
				},
			},
			{
				0.62,
				{
					head = { 10 },
					body = { 10, 0, 0, 0, 0.08, 0.3 },
					leg_fl = { 140, 0, 12 },
					elbow_l = { 30 },
					leg_fr = { 140, 0, -12 },
					elbow_r = { 30 },
					leg_bl = { 10 },
					leg_br = { 10 },
				},
			},
			{
				MAGIC_IMPACT,
				{
					head = { -10 },
					body = { -26, 0, 0, 0, -0.16, -0.6 },
					leg_fl = { 20, 0, 6 },
					elbow_l = {},
					leg_fr = { 20, 0, -6 },
					elbow_r = {},
					leg_bl = { 30 },
					leg_br = { 30 },
				},
			},
			{
				1.12,
				{
					head = { -10 },
					body = { -22, 0, 0, 0, -0.14, -0.55 },
					leg_fl = { 20, 0, 6 },
					elbow_l = {},
					leg_fr = { 20, 0, -6 },
					elbow_r = {},
					leg_bl = { 30 },
					leg_br = { 30 },
				},
			},
			{ 1.6, {} },
		},
	},
	-- Frenzy: three slashes thrown, the last two blades together (decision 0105)
	foe_knight_berserker_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.25,
				{
					head = { 10 },
					body = { 10, -10, 0, 0, 0.08, 0.3 },
					leg_fl = { 170, 0, -15 },
					elbow_l = { 30 },
					leg_fr = { 190 },
					elbow_r = { 30 },
					leg_bl = { 4 },
					leg_br = { -4 },
				},
			},
			{
				0.42,
				{
					head = { -8 },
					body = { -18, 14, 0, 0, -0.08, -0.5 },
					leg_fl = { 30, 0, -25 },
					elbow_l = { 10 },
					leg_fr = { 190 },
					elbow_r = { 30 },
					leg_bl = { 30 },
					leg_br = { -10 },
				},
			},
			{
				0.56,
				{
					head = { -8 },
					body = { -18, -14, 0, 0, -0.08, -0.6 },
					leg_fl = { 150, 0, -15 },
					elbow_l = { 30 },
					leg_fr = { 20, 15 },
					elbow_r = {},
					leg_bl = { -10 },
					leg_br = { 30 },
				},
			},
			{
				0.7,
				{
					head = { -14 },
					body = { -30, 4, 0, 0, -0.15, -1 },
					leg_fl = { 25, 0, -25 },
					elbow_l = {},
					leg_fr = { 15, 15 },
					elbow_r = {},
					leg_bl = { 38 },
					leg_br = { -14 },
				},
			},
			{
				0.95,
				{
					head = { -10 },
					body = { -26, 4, 0, 0, -0.12, -0.9 },
					leg_fl = { 28, 0, -24 },
					leg_fr = { 18, 15 },
					leg_bl = { 34 },
					leg_br = { -12 },
				},
			},
			{ 1.6, {} },
		},
	},
	-- Dark Cleave: its swing, slower, sends a violet crescent at its target (decision 0105)
	foe_knight_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.3,
				{
					head = { 4.6, 11.5 },
					body = { 6.9, -16.1, 0, 0, 0.046, 0.23 },
					leg_fl = { 23 },
					elbow_l = { 28.75, 0, 34.5 },
					leg_fr = { 161, 0, 9.2 },
					elbow_r = { 40.25 },
					leg_bl = { 6.9 },
					leg_br = { -4.6 },
				},
			},
			{
				0.55,
				{
					head = { 6.9, 16.1 },
					body = { 10.35, -20.7, 0, 0, 0.069, 0.287 },
					leg_fl = { 27.6 },
					elbow_l = { 32.2, 0, 36.8 },
					leg_fr = { 174.8, 0, 9.2 },
					elbow_r = { 51.75 },
					leg_bl = { 9.2 },
					leg_br = { -6.9 },
				},
			},
			{
				0.6,
				{
					head = { 6.9, 16.1 },
					body = { 10.35, -20.7, 0, 0, 0.069, 0.287 },
					leg_fl = { 27.6 },
					elbow_l = { 32.2, 0, 36.8 },
					leg_fr = { 174.8, 0, 9.2 },
					elbow_r = { 51.75 },
					leg_bl = { 9.2 },
					leg_br = { -6.9 },
				},
			},
			{
				0.7,
				{
					head = { -9.2, -9.2 },
					body = { -25.3, 13.8, 0, 0, -0.115, -0.977 },
					leg_fl = { 11.5 },
					elbow_l = { 23, 0, 23 },
					leg_fr = { 36.8 },
					elbow_r = {},
					leg_bl = { 36.8 },
					leg_br = { -13.8 },
				},
			},
			{
				0.95,
				{
					head = { -6.9 },
					body = { -20.7, 11.5, 0, 0, -0.092, -0.862 },
					leg_fl = { 11.5 },
					elbow_l = { 23, 0, 23 },
					leg_fr = { 25.3 },
					leg_bl = { 32.2 },
					leg_br = { -11.5 },
				},
			},
			{ 1.6, {} },
		},
	},
	-- Lance of Light: its sword thrust sends a beam (decision 0105)
	foe_knight_shield_commander_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.3,
				{
					body = { 4, -10, 0, 0, 0.02, 0.25 },
					leg_fl = { 45, 0, 12 },
					elbow_l = { -45 },
					leg_fr = { -30 },
					elbow_r = { 100 },
					leg_bl = { 4 },
					leg_br = { -3 },
					weapon = { -70 },
				},
			},
			{
				0.55,
				{
					body = { 6, -14, 0, 0, 0.03, 0.35 },
					leg_fl = { 45, 0, 12 },
					elbow_l = { -45 },
					leg_fr = { -40 },
					elbow_r = { 105 },
					leg_bl = { 6 },
					leg_br = { -4 },
					weapon = { -65 },
				},
			},
			{
				0.6,
				{
					body = { 6, -14, 0, 0, 0.03, 0.35 },
					leg_fl = { 45, 0, 12 },
					elbow_l = { -45 },
					leg_fr = { -40 },
					elbow_r = { 105 },
					leg_bl = { 6 },
					leg_br = { -4 },
					weapon = { -65 },
				},
			},
			{
				0.7,
				{
					head = { -4, -8 },
					body = { -12, 10, 0, 0, -0.1, -1.2 },
					leg_fl = { 30, 0, 15 },
					elbow_l = { -30 },
					leg_fr = { 85 },
					elbow_r = {},
					leg_bl = { -12 },
					leg_br = { 38 },
					weapon = { -85 },
				},
			},
			{
				0.95,
				{
					head = { -3, -6 },
					body = { -10, 8, 0, 0, -0.08, -1.05 },
					leg_fl = { 30, 0, 15 },
					elbow_l = { -30 },
					leg_fr = { 80 },
					elbow_r = {},
					leg_bl = { -10 },
					leg_br = { 34 },
					weapon = { -80 },
				},
			},
			{ 1.6, {} },
		},
	},
	-- Shield Slam: its shield punched out sends a ring of force (decision 0105)
	foe_knight_shield_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.3,
				{
					head = { 2, 34 },
					body = { -4, -40, 0, 0, -0.06, 0.3 },
					leg_fl = { 30, 0, -6 },
					elbow_l = { 40, 0, 10 },
					leg_fr = { -20, 0, 8 },
					elbow_r = { 40 },
					leg_bl = { -8 },
					leg_br = { 14 },
				},
			},
			{
				0.58,
				{
					head = { 2, 34 },
					body = { -2, -46, 0, 0, -0.08, 0.4 },
					leg_fl = { 30, 0, -6 },
					elbow_l = { 40, 0, 10 },
					leg_fr = { -20, 0, 8 },
					elbow_r = { 40 },
					leg_bl = { -8 },
					leg_br = { 14 },
				},
			},
			{
				0.7,
				{
					head = { -6, 16 },
					body = { -16, -20, 0, 0, -0.1, -1.3 },
					leg_fl = { 85, 0, -10 },
					elbow_l = { 0, 0, 6 },
					leg_fr = { -30, 0, 10 },
					elbow_r = { 30 },
					leg_bl = { 36 },
					leg_br = { -14 },
				},
			},
			{
				0.95,
				{
					head = { -6, 16 },
					body = { -12, -22, 0, 0, -0.08, -1.1 },
					leg_fl = { 85, 0, -10 },
					elbow_l = { 0, 0, 6 },
					leg_fr = { -30, 0, 10 },
					elbow_r = { 30 },
					leg_bl = { 36 },
					leg_br = { -14 },
				},
			},
			{ 1.6, {} },
		},
	},
	-- Hex Bolt: a bolt from its staff's head that implodes on its target (decision 0105)
	foe_mage_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.3,
				{
					head = { 8, -8 },
					body = { 4, -10, 0, 0, 0.04, 0.2 },
					leg_fl = { 45, 0, -14 },
					elbow_l = { -50 },
					leg_fr = { 75, 0, 14 },
					elbow_r = { -70 },
					leg_bl = { -4 },
					leg_br = { 4 },
				},
			},
			{
				0.6,
				{
					head = { 8, -8 },
					body = { 6, -14, 0, 0, 0.06, 0.3 },
					leg_fl = { 45, 0, -14 },
					elbow_l = { -50 },
					leg_fr = { 75, 0, 14 },
					elbow_r = { -80 },
					leg_bl = { -4 },
					leg_br = { 4 },
				},
			},
			{
				0.72,
				{
					head = { -6, -4 },
					body = { -14, -6, 0, 0, -0.06, -0.6 },
					leg_fl = { 70, 0, -6 },
					elbow_l = { -10 },
					leg_fr = { 95, 0, 6 },
					elbow_r = {},
					leg_bl = { 16 },
					leg_br = { -10 },
				},
			},
			{
				0.95,
				{
					head = { -6, -4 },
					body = { -14, -6, 0, 0, -0.06, -0.6 },
					leg_fl = { 70, 0, -6 },
					elbow_l = { -10 },
					leg_fr = { 95, 0, 6 },
					elbow_r = {},
					leg_bl = { 16 },
					leg_br = { -10 },
				},
			},
			{ 1.6, {} },
		},
	},
	-- Raise Dead: runes open under the fallen it raises; a bolt at its target (decision 0105)
	foe_mage_necromancer_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.3,
				{
					head = { 10, -6 },
					body = { 6, -6, 0, 0, 0.05, 0.15 },
					leg_fl = { 140, 0, -6 },
					elbow_l = { 10 },
					leg_fr = { 40 },
					elbow_r = { -30 },
				},
			},
			{
				0.62,
				{
					head = { 14, -8 },
					body = { 10, -8, 0, 0, 0.1, 0.2 },
					leg_fl = { 170, 0, -4 },
					elbow_l = {},
					leg_fr = { 50 },
					elbow_r = { -40 },
					leg_bl = { -4 },
					leg_br = { 4 },
				},
			},
			{
				0.72,
				{
					head = { -8, -6 },
					body = { -16, -10, 0, 0, -0.08, -0.5 },
					leg_fl = { 40, 0, -10 },
					elbow_l = { -20 },
					leg_fr = { 10 },
					elbow_r = { -6 },
					leg_bl = { 16 },
					leg_br = { -10 },
				},
			},
			{
				0.95,
				{
					head = { -8, -6 },
					body = { -16, -10, 0, 0, -0.08, -0.5 },
					leg_fl = { 40, 0, -10 },
					elbow_l = { -20 },
					leg_fr = { 10 },
					elbow_r = { -6 },
					leg_bl = { 16 },
					leg_br = { -10 },
				},
			},
			{ 1.6, {} },
		},
	},
	-- Benediction: its staff raised, light comes down on every ally it heals; a bolt at its target (decision 0105)
	foe_mage_priest_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.3,
				{
					head = { 10 },
					body = { 6, 8, 0, 0, 0.04, 0.1 },
					leg_fl = { 150, 0, -6 },
					elbow_l = { 10 },
					leg_fr = { 30, 0, 10 },
				},
			},
			{
				0.62,
				{
					head = { 16 },
					body = { 10, 8, 0, 0, 0.08, 0.15 },
					leg_fl = { 175, 0, -4 },
					elbow_l = {},
					leg_fr = { 40, 0, 20 },
					leg_bl = { -4 },
					leg_br = { 4 },
				},
			},
			{
				0.8,
				{
					head = {},
					body = { -8, -6, 0, 0, -0.04, -0.3 },
					leg_fl = { 80, 0, -10 },
					elbow_l = { -20 },
					leg_fr = { 20 },
					leg_bl = { 12 },
					leg_br = { -8 },
				},
			},
			{
				1,
				{
					head = {},
					body = { -8, -6, 0, 0, -0.04, -0.3 },
					leg_fl = { 80, 0, -10 },
					elbow_l = { -20 },
					leg_fr = { 20 },
					leg_bl = { 12 },
					leg_br = { -8 },
				},
			},
			{ 1.6, {} },
		},
	},
	-- Earthsplitter: its axe splits the ground to its target, which erupts (decision 0105)
	foe_ogre_commander_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.3,
				{
					head = { 8 },
					body = { 10, 0, 0, 0, 0.08, 0.3 },
					leg_fl = { 95 },
					leg_fr = { 95 },
					leg_bl = { 4 },
					leg_br = { -4 },
				},
			},
			{
				0.55,
				{
					head = { 12 },
					body = { 16, 0, 0, 0, 0.12, 0.4 },
					leg_fl = { 125 },
					leg_fr = { 125 },
					leg_bl = { 8 },
					leg_br = { -6 },
				},
			},
			{
				0.6,
				{
					head = { 12 },
					body = { 16, 0, 0, 0, 0.12, 0.4 },
					leg_fl = { 125 },
					leg_fr = { 125 },
					leg_bl = { 8 },
					leg_br = { -6 },
				},
			},
			{
				0.66,
				{
					head = { -6 },
					body = { -12, 0, 0, 0, -0.06, -0.6 },
					leg_fl = { 40 },
					leg_fr = { 40 },
					leg_bl = { 24 },
					leg_br = { -10 },
				},
			},
			{
				0.7,
				{
					head = { -14 },
					body = { -30, 0, 0, 0, -0.15, -1 },
					leg_fl = { -40 },
					leg_fr = { -40 },
					leg_bl = { 38 },
					leg_br = { -14 },
				},
			},
			{
				0.95,
				{
					head = { -10 },
					body = { -26, 0, 0, 0, -0.12, -0.9 },
					leg_fl = { -36 },
					leg_fr = { -36 },
					leg_bl = { 34 },
					leg_br = { -12 },
				},
			},
			{ 1.6, {} },
		},
	},
	-- Ground Pound: its club slams the ground and a crack runs to its target, which rock bursts up under (decision 0105)
	foe_ogre_forge = {
		length = 1.6,
		keys = {
			{ 0.00, {} },
			{
				0.3,
				{
					head = { 8 },
					body = { 8, 0, 0, 0, 0.06, 0.2 },
					leg_fl = { 30, 0, -10 },
					leg_fr = { 150, 0, 10 },
					elbow_r = { 40 },
					leg_bl = { 6 },
					leg_br = { -6 },
				},
			},
			{
				0.55,
				{
					head = { 12 },
					body = { 14, 0, 0, 0, 0.12, 0.3 },
					leg_fl = { 40, 0, -14 },
					leg_fr = { 185, 0, 8 },
					elbow_r = { 30 },
					leg_bl = { 10 },
					leg_br = { -8 },
				},
			},
			{
				0.6,
				{
					head = { 12 },
					body = { 14, 0, 0, 0, 0.12, 0.3 },
					leg_fl = { 40, 0, -14 },
					leg_fr = { 185, 0, 8 },
					elbow_r = { 30 },
					leg_bl = { 10 },
					leg_br = { -8 },
				},
			},
			{
				0.7,
				{
					head = { -12 },
					body = { -26, 0, 0, 0, -0.14, -0.8 },
					leg_fl = { 20, 0, -20 },
					leg_fr = { 20, 0, 6 },
					elbow_r = {},
					leg_bl = { 36 },
					leg_br = { -14 },
				},
			},
			{
				0.95,
				{
					head = { -12 },
					body = { -22, 0, 0, 0, -0.12, -0.75 },
					leg_fl = { 20, 0, -20 },
					leg_fr = { 20, 0, 6 },
					elbow_r = {},
					leg_bl = { 36 },
					leg_br = { -14 },
				},
			},
			{ 1.6, {} },
		},
	},
}
for kind, keys in AnimalMoves.POWERS do
	MAGICS[kind] = { length = 1.6, keys = keys }
end

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

-- Idle poses, by asset (SHANNON's picks, decision 0104): a held stance with a slow breath on top, in place
-- of the shared sway. An attack, a power move and a flinch start from it and settle back into it.
local STANCES: { [string]: Pose } = {
	-- the Ancient Alpha Dragon coiled (SHANNON's pick): low, its neck snaking forward and its jaws in a snarl, its
	-- wings folded down its flanks (on top of the wings it rests with raised and swept back)
	foe_dragon_alpha_forge = {
		body = { -6, 0, 0, 0, -0.05 },
		neck_base = { -18 },
		head = { 12, -10 },
		jaw = { -12 },
		leg_fl = { 8 },
		leg_fr = { -4 },
		tail = { 0, 20 },
		tail_mid = { 0, 20 },
		tail_end = { 0, 25 },
		wing_l = { 22, 27.2, 38.8 },
		hand_l = { 42.6, 19, -6.7 },
		wing_r = { 22, -27.2, -38.8 },
		hand_r = { 42.6, -19, 6.7 },
	},
	-- the Shadow Dragon mantling (SHANNON's pick): wings raised high over its back, head lowered at its prey
	foe_dragon_forge = {
		body = { -4 },
		neck_base = { -14 },
		head = { 6 },
		jaw = { -8 },
		leg_fl = { 6 },
		leg_fr = { -4 },
		tail = { 4, 14 },
		tail_mid = { 0, 12 },
		tail_end = { 0, 16 },
		wing_l = { 0, 15, -30 },
		hand_l = { 0, 10, -10 },
		wing_r = { 0, -15, 30 },
		hand_r = { 0, -10, 10 },
	},
	-- the Siege Golem with its knuckles down (SHANNON's pick): stooped forward, its great fists low
	foe_golem_forge = {
		body = { -16, 0, 0, 0, -0.12 },
		head = { 10 },
		leg_fl = { 24, 0, 4 },
		elbow_l = { -10 },
		leg_fr = { 24, 0, -4 },
		elbow_r = { -10 },
		leg_bl = { 16 },
		leg_br = { 16 },
	},
	-- the Cavalry Commander with its sword aloft (SHANNON's pick): the rider holds its cavalry sword high, the horse
	-- standing proud
	foe_cavalry_commander_forge = {
		body = { 4 },
		head = { 16 },
		leg_fl = { 8 },
		elbow_r = { 0, 0, 55 },
	},
	-- the Shieldbearer Commander with its sword on its shoulder (SHANNON's pick): the blade resting back over its right
	-- shoulder, its tower shield at its side
	foe_knight_shield_commander_forge = {
		body = { 2, 8 },
		head = { 4, -10 },
		leg_fl = { 8 },
		elbow_l = { 10 },
		leg_fr = { 25 },
		elbow_r = { 115 },
		weapon = { 20 },
		leg_bl = { -4 },
		leg_br = { 6 },
	},
	-- the Dark Drake prowling (SHANNON's pick): neck low and forward, jaws just apart, wings folded back along its
	-- flanks, tail swept to one side
	foe_dragon_drake_forge = {
		body = { -4 },
		neck_base = { -18 },
		head = { 14, 6 },
		jaw = { -6 },
		leg_fl = { 8 },
		leg_fr = { -4 },
		leg_bl = { -4 },
		leg_br = { 4 },
		tail = { 4, 10 },
		tail_mid = { 0, 12 },
		tail_end = { 0, 16 },
		wing_l = { 0, 45, 12 },
		hand_l = { 0, 60, 8 },
		wing_r = { 0, -45, -12 },
		hand_r = { 0, -60, -8 },
	},
	-- the Ogre Commander holding its great axe up before it in both hands (SHANNON's pick: the arms are as it rests)
	foe_ogre_commander_forge = {
		body = { -4, 0, 0, 0, -0.02 },
		head = { -4, 8 },
	},
	-- the Necromancer with a skull floating over its palm (SHANNON's pick): its arms rest bent, the staff in its fist;
	-- its head tilts toward the skull
	foe_mage_necromancer_forge = {
		body = { 0, 4 },
		head = { -10, 14 },
	},
	-- the Cavalry with its lance held upright (SHANNON's pick)
	foe_cavalry_forge = {
		head = { -4 },
		elbow_r = { 88 },
	},
	-- the Berserker dragging its axe (SHANNON's pick): hunched, the axe's head on the ground ahead
	foe_knight_berserker_forge = {
		body = { -8, -6, 0, 0, -0.03 },
		head = { 12, 6 },
		leg_fl = { 10, 0, 6 },
		elbow_l = { 30 },
		leg_fr = { -15, 10 },
		elbow_r = { 10 },
		leg_bl = { 10 },
		leg_br = { -6 },
	},
	-- the Crossbow Troop with its crossbow at its hip (SHANNON's pick): its forearm level, the crossbow pointing ahead
	foe_archer_crossbow_forge = {
		body = { 0, -6 },
		head = { 0, 10 },
		leg_fl = { 20, 0, 4 },
		elbow_l = { 30 },
		leg_fr = { 5 },
		elbow_r = { 85 },
		leg_bl = { 6 },
		leg_br = { -4 },
	},
	-- the Ogre Enforcer dragging its club (SHANNON's pick): hunched, the club held at the end of its handle, its head on
	-- the ground ahead
	foe_ogre_forge = {
		body = { -8, -6, 0, 0, -0.03 },
		head = { 12, 6 },
		leg_fl = { 10, 0, 6 },
		elbow_l = { 30 },
		leg_fr = { -20, 10 },
		elbow_r = { 10 },
		leg_bl = { 10 },
		leg_br = { -6 },
	},
	-- the Darkcaster with its orb in its palm (SHANNON's pick): its arms rest bent, the staff in its fist and the orb
	-- floating over its upturned palm; its head tilts toward the orb
	foe_mage_forge = {
		body = { 0, 4 },
		head = { -10, 14 },
	},
	-- at ease: weight on one leg, the sword's point lowered, the shield hanging easy, head turned
	foe_knight_forge = {
		body = { 0, 6, 2 },
		head = { 0, -22, 0 },
		leg_fl = { 4 },
		elbow_l = { 18, 0, 8 },
		leg_fr = { -28, 0, 4 },
		leg_bl = { -4 },
		leg_br = { 6 },
	},
	-- at ease: the bow low before it, head turned to watch (its arrow is in its quiver)
	foe_archer_forge = {
		body = { 0, -10, 0 },
		head = { -2, 28, 0 },
		leg_fl = { 12, 0, 4 },
		elbow_l = { 20 },
		leg_bl = { 6 },
		leg_br = { -5 },
	},
	-- the hammer on its shoulder (SHANNON's pick): gripped a third of the way up its shaft, the fist before its chest,
	-- the handle across its shoulder plate and the head at its shoulder; its shield arm hangs easy
	foe_knight_heavy_forge = {
		body = { 2, 6 },
		head = { 4, -8 },
		leg_fl = { 6, 0, 4 },
		elbow_l = { 24, 0, 10 },
		leg_fr = { 9, -39, -41 },
		elbow_r = { 99, -25, -78 },
		leg_bl = { 0, 0, -6 },
		leg_br = { 0, 0, 6 },
	},
	-- shield wall: turned behind its huge shield, held before it, the sword raised at its side, one foot forward
	foe_knight_shield_forge = {
		body = { -4, -22, 0 },
		head = { 2, 20, 0 },
		leg_fl = { 6 },
		elbow_l = { 8, 0, 10 },
		leg_fr = { -10, 0, 8 },
		elbow_r = { 50 },
		leg_bl = { 12 },
		leg_br = { -8 },
	},
	-- reading: its arms rest bent (the staff planted, the book open before it), head bowed to the pages
	foe_mage_priest_forge = { head = { -18, 8, 0 } }, -- (bowed lower: its book is held low on its palm)
}

local function stanceAt(stance: Pose, t: number): Pose
	local out = table.clone(stance)
	local b, h = stance.body or {}, stance.head or {}
	local breath = math.sin(t * TAU / 3.4)
	out.body = { (b[1] or 0) + breath, b[2] or 0, b[3] or 0, b[4] or 0, (b[5] or 0) + 0.02 * breath, b[6] or 0 }
	out.head = { (h[1] or 0) + 1.5 * math.sin(t * TAU / 3.4 + 0.8), (h[2] or 0) + 2 * math.sin(t * TAU / 6), h[3] or 0 }
	return out
end

-- `a` and `b` mixed joint by joint: all `a` at w = 0, all `b` at 1 (and past 1 `b` laid over `a` whole: w = 2)
local function mixed(a: Pose, b: Pose, w: number): Pose
	local out: Pose = {}
	for _, joint in JOINTS do
		local x, y = a[joint], b[joint]
		if x or y then
			local v = table.create(6, 0)
			for k = 1, 6 do
				local p, q = if x then x[k] or 0 else 0, if y then y[k] or 0 else 0
				v[k] = if w > 1 then p + q else p + (q - p) * w
			end
			out[joint] = v
		end
	end
	return out
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
		-- a Titan lies down like a loaf (SHANNON: "better resting positions"): its front legs out along the
		-- ground, its hind legs tucked under its belly, its belly down near the floor (the body down 0.75 of
		-- the front legs' height: Scale is that height / 1.45), its head up a little so its trunk and tusks
		-- lie forward on the floor, not through it; it breathes slowly, sighs now and then (the head and
		-- body lift a little and settle) and flicks its tail
		local sigh = math.max(0, math.sin(t % 13 / 13 * TAU)) ^ 3
		local flick = math.max(0, math.sin(t * TAU / 5)) ^ 6
		return {
			leg_fl = { 80 },
			leg_fr = { 80 },
			leg_bl = { 72 },
			leg_br = { 72 },
			body = { -1 + 1.5 * sigh, 0, 0, 0, -1.09 + 0.02 * breath + 0.04 * sigh, 0 },
			head = { 30 + 1.5 * breath + 6 * sigh, 4 * math.sin(t * TAU / 9), 0 },
			tail = { 0, 25 * flick, 0 },
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

-- Weapon effects, by asset (SHANNON's picks for the Heavy Knight). A model built with "tip" and "neck"
-- bones in its weapon's far end (skin_forge `tips`) gets a trail between them as it swings; its attack
-- lands a small shockwave where the weapon strikes, its power move charges the weapon with light and
-- lands a big shockwave with crystal spikes erupting round it. Each replaces the shared power effects.
local ATTACK_CONTACT = 0.44 -- seconds into "attack" when the blow lands (as the server times it)
type WeaponFx = { attack: string, power: string, colour: Color3 }
local WEAPON_FX: { [string]: WeaponFx } = {
	foe_knight_heavy_forge = { attack = "shockwave", power = "eruption", colour = Color3.fromRGB(170, 70, 255) },
}
local weaponDone: { [Model]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any

local function weaponBones(model: Model): (Attachment?, Attachment?)
	return model:FindFirstChild("tip", true) :: Attachment?, model:FindFirstChild("neck", true) :: Attachment?
end

local function trailOf(model: Model, colour: Color3): Trail?
	local tip, neck = weaponBones(model)
	if tip == nil or neck == nil then
		return nil
	end
	local trail = tip:FindFirstChild("WeaponTrail") :: Trail?
	if trail == nil then
		local t = Instance.new("Trail")
		t.Name = "WeaponTrail"
		t.Attachment0, t.Attachment1 = tip, neck
		t.Color = ColorSequence.new(colour)
		t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		t.LightEmission, t.Lifetime, t.Enabled = 0.8, 0.16, false
		t.Parent = tip
		trail = t
	end
	return trail
end

-- Where the weapon strikes: the ground under its tip (creatures left out of the ray).
local function strikePoint(model: Model): CFrame?
	local tip = weaponBones(model)
	local root = model.PrimaryPart
	if tip == nil or root == nil then
		return nil
	end
	local p = tip.WorldPosition
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged("Creature")
	local hit = Workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -16, 0), params)
	local y = if hit then hit.Position.Y else p.Y
	return CFrame.new(p.X, y + 0.08, p.Z) * root.CFrame.Rotation
end

-- A flash, a ring of light rolling out across the ground and cracks; `glowing` cracks shine.
local function shockwave(ground: CFrame, colour: Color3, radius: number, glowing: boolean)
	local flash = fxPart(Vector3.one * radius * 0.25, ground, Color3.fromRGB(235, 210, 255), Enum.Material.Neon)
	flash.Shape = Enum.PartType.Ball
	flash.Transparency = 0.1
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = colour, radius * 1.5, 3, false
	light.Parent = flash
	tween(flash, 0.16, { Size = Vector3.one * radius * 0.8, Transparency = 1 })
	tween(light, 0.3, { Brightness = 0 })
	Debris:AddItem(flash, 0.35)
	local ring = fxPart(Vector3.new(0.25, 1, 1), ground * CFrame.Angles(0, 0, math.pi / 2), colour, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.15
	tween(ring, 0.45, { Size = Vector3.new(0.25, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(ring, 0.5)
	for k = 1, 9 do
		local length = radius * (0.22 + 0.24 * math.random())
		local angle = k / 9 * math.pi * 2 + (math.random() - 0.5) * 0.5
		local crack = fxPart(
			Vector3.new(length, 0.06, radius * 0.05),
			ground * CFrame.Angles(0, angle, 0) * CFrame.new(length / 2, 0, 0),
			if glowing then colour else Color3.fromRGB(18, 14, 24),
			if glowing then Enum.Material.Neon else Enum.Material.SmoothPlastic
		)
		task.delay(0.9, tween, crack, 0.6, { Transparency = 1 })
		Debris:AddItem(crack, 1.6)
	end
end

-- The big blow: a shockwave with glowing cracks, and a ring of crystal spikes thrust up round the
-- impact that sink again.
local function eruption(ground: CFrame, colour: Color3, radius: number)
	shockwave(ground, colour, radius, true)
	for k = 1, 8 do
		local angle = k / 8 * math.pi * 2 + (math.random() - 0.5) * 0.4
		local height = radius * (0.28 + 0.12 * math.random())
		local width = radius * 0.11
		local lean = CFrame.Angles(0, 0, -math.rad(18)) -- tipped outwards
		local base = ground * CFrame.Angles(0, angle, 0) * CFrame.new(radius * 0.32, 0, 0)
		local low, high = base * CFrame.new(0, -height * 1.1, 0) * lean, base * CFrame.new(0, -height * 0.1, 0) * lean
		local spike = fxPart(Vector3.one * 0.2, low, colour, Enum.Material.Neon)
		spike.Transparency = 1
		pyramid(spike, width, height, colour, Enum.Material.Neon)
		tween(spike, 0.14, { CFrame = high }, Enum.EasingStyle.Back)
		task.delay(0.6, tween, spike, 0.3, { CFrame = low })
		Debris:AddItem(spike, 1)
	end
end

-- The weapon gathers light until the blow.
local function chargeWeapon(model: Model, colour: Color3, seconds: number, size: number)
	local tip = weaponBones(model)
	if tip == nil then
		return
	end
	local orb = fxPart(Vector3.one * 0.3 * size, CFrame.new(tip.WorldPosition), colour, Enum.Material.Neon)
	orb.Shape = Enum.PartType.Ball
	orb.Transparency = 0.4
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = colour, 4, 0.5, false
	light.Parent = orb
	tween(orb, seconds, { Size = Vector3.one * 1.4 * size }, Enum.EasingStyle.Sine)
	tween(light, seconds, { Range = 10 * size, Brightness = 3 }, Enum.EasingStyle.Sine)
	local started = os.clock()
	local follow
	follow = RunService.RenderStepped:Connect(function()
		if os.clock() - started > seconds or tip.Parent == nil then
			follow:Disconnect()
			orb:Destroy()
			return
		end
		orb.CFrame = CFrame.new(tip.WorldPosition)
	end)
end

-- Plays a model's weapon effects for the clip it is in (`at` tells one playing of a clip from the next).
local function weaponFx(model: Model, fx: WeaponFx, anim: string?, at: number, t: number)
	local done = weaponDone[model] or {}
	weaponDone[model] = done
	local s = (model:GetAttribute("Scale") :: number?) or 1
	local trail = trailOf(model, fx.colour)
	if trail then
		trail.Enabled = (anim == "attack" and t > 0.28 and t < ATTACK_CONTACT + 0.05)
			or (anim == "magic" and t > 0.8 and t < MAGIC_IMPACT + 0.05)
	end
	if anim == "attack" and t >= ATTACK_CONTACT and done.attack ~= at then
		done.attack = at
		local ground = strikePoint(model)
		if ground then
			shockwave(ground, fx.colour, 3.3 * s, false)
		end
	elseif anim == "magic" then
		if done.charge ~= at and t < MAGIC_IMPACT then
			done.charge = at
			chargeWeapon(model, fx.colour, MAGIC_IMPACT - t, s)
		end
		if t >= MAGIC_IMPACT and done.power ~= at then
			done.power = at
			local ground = strikePoint(model)
			if ground then
				eruption(ground, fx.colour, 5.9 * s)
			end
		end
	end
end

-- A mage's magic bolt (FightFx.BOLTS; the Battle Priest's first, then every mage's): a flash where it is
-- cast, a glowing orb with a white core, sparkles and a trail flying on a low arc, and a burst where it lands.
local function bolt(from: Vector3, to: Vector3, seconds: number, colour: Color3, size: number)
	local flash = fxPart(Vector3.one * 0.6 * size, CFrame.new(from), Color3.fromRGB(255, 240, 255), Enum.Material.Neon)
	flash.Shape = Enum.PartType.Ball
	tween(flash, 0.15, { Size = Vector3.one * 2.2 * size, Transparency = 1 })
	Debris:AddItem(flash, 0.2)
	local orb = fxPart(Vector3.one * 1.1 * size, CFrame.new(from), colour, Enum.Material.Neon)
	orb.Shape, orb.Transparency = Enum.PartType.Ball, 0.35
	local core = fxPart(Vector3.one * 0.5 * size, CFrame.new(from), Color3.new(1, 1, 1), Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.4 * size, 0), Vector3.new(0, -0.4 * size, 0)
	a0.Parent, a1.Parent = orb, orb
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1, trail.Lifetime = a0, a1, 0.25
	trail.Color, trail.LightEmission = ColorSequence.new(colour), 1
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = orb
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = colour, 8 * size, 2, false
	light.Parent = orb
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color, sparks.LightEmission, sparks.Rate = ColorSequence.new(colour), 1, 40
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * size), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime, sparks.Speed = NumberRange.new(0.2, 0.4), NumberRange.new(1, 3)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = orb
	local arc = math.min(3, (to - from).Magnitude * 0.08)
	local started = os.clock()
	local fly
	fly = RunService.RenderStepped:Connect(function()
		local u = math.min(1, (os.clock() - started) / seconds)
		local at = from:Lerp(to, u) + Vector3.yAxis * arc * math.sin(u * math.pi)
		orb.CFrame, core.CFrame = CFrame.new(at), CFrame.new(at)
		if u < 1 then
			return
		end
		fly:Disconnect()
		orb:Destroy()
		core:Destroy()
		local burst = fxPart(Vector3.one * 0.8 * size, CFrame.new(to), colour, Enum.Material.Neon)
		burst.Shape, burst.Transparency = Enum.PartType.Ball, 0.1
		tween(burst, 0.25, { Size = Vector3.one * 4 * size, Transparency = 1 })
		Debris:AddItem(burst, 0.3)
		local bits = sparks:Clone()
		bits.Rate, bits.Speed = 0, NumberRange.new(6 * size, 12 * size)
		bits.Lifetime = NumberRange.new(0.3, 0.6)
		bits.Parent = burst
		bits:Emit(24)
	end)
	Debris:AddItem(orb, seconds + 1) -- a bolt whose model went away must not stay
	Debris:AddItem(core, seconds + 1)
end

-- Casts a mage's bolt at its attack's release: at where the server aims it (BoltTo, BoltFor, set before the
-- attack plays), or straight ahead when nothing is (the admin's look at it).
local function boltFx(model: Model, rgb: { number }, anim: string?, at: number, t: number)
	local done = weaponDone[model] or {}
	weaponDone[model] = done
	if anim ~= "attack" or t < FightFx.RELEASE or done.bolt == at then
		return
	end
	done.bolt = at
	local tip = model:FindFirstChild("tip", true) :: Attachment?
	local from = if tip then tip.WorldPosition else model:GetPivot().Position + Vector3.new(0, 3, 0)
	local to = model:GetAttribute("BoltTo") :: Vector3?
	local seconds = (model:GetAttribute("BoltFor") :: number?) or FightFx.flightTime(30)
	if to == nil then
		to = from + model:GetPivot().LookVector * 30
	end
	local s = (model:GetAttribute("Scale") :: number?) or 1
	bolt(from, to :: Vector3, seconds, Color3.fromRGB(rgb[1], rgb[2], rgb[3]), math.clamp(s * 0.5, 0.6, 1.6))
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
	-- a skinned model's bones by joint (decision 0102), and each bone's axes in the Root's: a pose is
	-- written in the Root's axes, so it is turned into the bone's
	bones: { [string]: { bone: Bone, turn: CFrame } },
	boneScan: number, -- os.clock() when its descendants were last searched for bones
	thud: Sound?, -- the sound of a hit and of a power hit or knockout, made on the first of each
	boom: Sound?,
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

-- The same for a skinned animal (decision 0102: bones, no leg boxes): its feet are the points AnimalRig measured on
-- its model, from its body bone's rest head, carried by the pose of the body and of the leg each is on.
type SkinFeet = { ground: number, legs: { { joint: string, at: Vector3, points: { Vector3 } } } }
local skinFeet: { [string]: SkinFeet | false } = {}
local function skinSunk(model: Model, now: { [string]: { number } }, scale: number): number
	local asset = (model:GetAttribute("Asset") :: string?) or ""
	local feet = skinFeet[asset]
	if feet == nil then
		local data = AnimalRig.MODELS[asset]
		feet = false
		if data then
			local legs, ground = {}, math.huge
			for joint, points in data.feet do
				local j, pts = data.joints[joint], {}
				for _, p in points do
					table.insert(pts, Vector3.new(p[1], p[2], p[3]))
					ground = math.min(ground, p[2])
				end
				table.insert(legs, { joint = joint, at = Vector3.new(j[1], j[2], j[3]), points = pts })
			end
			feet = { ground = ground, legs = legs }
		end
		skinFeet[asset] = feet
	end
	if not feet then
		return 0
	end
	local size = model:GetScale() -- (its measures are at its built size)
	local body = turned(now.body, scale)
	local low = math.huge
	for _, leg in feet.legs do
		local at = leg.at * size
		local frame = body * CFrame.new(at) * turned(now[leg.joint], scale) * CFrame.new(-at)
		for _, p in leg.points do
			low = math.min(low, (frame * (p * size)).Y)
		end
	end
	return math.max(0, feet.ground * size - low)
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
	local click = not final and model:GetAttribute("HitClick") == 1 -- a click's strike: light, many a second (0106)
	local hot = power > 0 or final
	local colour = if hot then Color3.fromRGB(255, 120, 70) else Color3.fromRGB(255, 220, 160)
	rig.flinch = FightFx.flinch(power, dmg / math.max(1, (model:GetAttribute("MaxHp") :: number?) or 1))
	if not click then
		rig.stopUntil = os.clock() + FightFx.hitStop(power, final, model:GetAttribute("HitKo") == 1)
	end
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
	e:Emit(if final then 44 elseif hot then 28 elseif click then 5 else 10)
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
		local r = (if final then 14 elseif hot then 9 elseif click then 3 else 5) * s
		tween(disc, 0.35, { Size = Vector3.new(0.2, r, r), Transparency = 1 })
		Debris:AddItem(disc, 0.45)
	end
	if power > 0 then -- only a power hit nudges the camera (SHANNON: "way less camera zooming")
		player:SetAttribute("CamPunch", FightFx.punchStrength(power)) -- local only: ArenaCamera reads it
		player:SetAttribute("CamPunchAt", os.clock())
	end
	if final then
		slowAt = os.clock() -- the finish is the slow motion alone (decision 0097)
	end
	-- and every hit is heard: a thud, a slam for a power hit or a knockout
	local ko = model:GetAttribute("HitKo") == 1
	local sound = if hot or ko then rig.boom else rig.thud
	if sound == nil then
		sound = Instance.new("Sound")
		local made = sound :: Sound
		made.SoundId = if hot or ko
			then "rbxasset://sounds/impact_explosion_03.mp3"
			else "rbxasset://sounds/action_jump_land.mp3"
		made.RollOffMaxDistance, made.RollOffMinDistance = 300, 30
		made.Parent = hit
		if hot or ko then
			rig.boom = made
		else
			rig.thud = made
		end
	end
	local s2 = sound :: Sound
	s2.Volume = if final then 0.9 elseif hot or ko then 0.55 elseif click then 0.18 else 0.4
	s2.PlaybackSpeed = (if ko then 0.8 else 1) * (0.92 + math.random() * 0.16)
	s2:Play()
end

local function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local joints = {}
	local bones = {}
	local root = model.PrimaryPart or model:FindFirstChild("Root") :: BasePart?
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
		elseif d:IsA("Bone") and table.find(JOINTS, d.Name) and root then
			bones[d.Name] = { bone = d, turn = (root :: BasePart).CFrame.Rotation:Inverse() * d.WorldCFrame.Rotation }
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
		bones = bones,
		boneScan = 0,
		thud = nil,
		boom = nil,
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
		local base = model.PrimaryPart
		if d:IsA("Bone") and rigs[model] and table.find(JOINTS, d.Name) and base then
			rigs[model].bones[d.Name] = { bone = d, turn = base.CFrame.Rotation:Inverse() * d.WorldCFrame.Rotation }
		end
		if d:IsA("Motor6D") and rigs[model] then
			rigs[model].joints[d.Name] = d
		end
	end)
end

-- Fights (decision 0042): a creature with a "MaxHp" attribute shows a health bar over it, and every
-- change in its "Hp" floats a number: red for damage, green for healing. The server sets both.
-- In a crowd (decision 0101) small hits on the same foe merge into one growing number, and at most
-- MAX_NUMBERS float at once (a power hit always shows).
local MAX_NUMBERS, MERGE_SECONDS = 12, 0.5
local floating = 0
local recent: { [Model]: { text: TextLabel, at: number, total: number } } = setmetatable({}, { __mode = "k" }) :: any
local function floatNumber(model: Model, change: number)
	local hit = model:FindFirstChild("Hit") :: BasePart?
	if hit == nil then
		return
	end
	local small = change < 0 and model:GetAttribute("HitPower") ~= 1
	local last = recent[model]
	if small and last and os.clock() - last.at < MERGE_SECONDS and last.text.Parent then
		last.total += change
		last.at = os.clock()
		last.text.Text = tostring(last.total)
		return
	elseif small and floating >= MAX_NUMBERS then
		return
	end
	floating += 1
	task.delay(1.1, function()
		floating -= 1
	end)
	-- a power hit's number is gold and bigger, a Perfect's or a combo's bigger still (decision 0097)
	local power = change < 0 and model:GetAttribute("HitPower") == 1
	local crit = power and model:GetAttribute("HitCrit") == 1
	local scale = if crit then 2.1 elseif power then 1.6 else 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120 * scale, 40 * scale)
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
	text.Text = if change >= 0 then `+{change}` elseif crit then `{change}!` else tostring(change)
	text.TextColor3 = if change >= 0
		then Color3.fromRGB(110, 255, 140)
		elseif power then Color3.fromRGB(255, 200, 60)
		else Color3.fromRGB(255, 90, 80)
	text.TextStrokeTransparency = 0
	text.Parent = gui
	gui.Parent = hit
	if small then
		recent[model] = { text = text, at = os.clock(), total = change }
	end
	if power then -- it pops in big and settles
		local size = Instance.new("UIScale")
		size.Scale = 1.6
		size.Parent = text
		TweenService:Create(size, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
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
	-- an enemy's bar is sized in studs, so the crowd's bars shrink with distance and stay small (SHANNON,
	-- 2026-11-24: "the enemy healthbars are quite big"); the team's stays a fixed, readable size
	local foe = model:GetAttribute("Side") == 2
	gui.Size = if foe then UDim2.fromScale(math.clamp(hit.Size.X * 0.8, 2.5, 9), 0.35) else UDim2.fromOffset(90, 10)
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
	edge.Thickness = if foe then 1 else 2
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
	FoePowers.stop(model :: Model)
	Spells.stop(model :: Model)
end)
for _, model in CollectionService:GetTagged("Creature") do
	add(model)
end

-- Motor6D.Transform is applied in the simulation step, so set it just before.
RunService.PreSimulation:Connect(function(dt: number)
	local time = Workspace:GetServerTimeNow()
	for model, rig in rigs do
		-- a skinned model's bones can reach this client before its Root does: take them once both are here
		local base = model.PrimaryPart
		if next(rig.bones) == nil and next(rig.joints) == nil and base and os.clock() - rig.boneScan > 0.5 then
			rig.boneScan = os.clock() -- a model with no joints at all is looked at twice a second, no more
			for _, d in model:GetDescendants() do
				if d:IsA("Bone") and table.find(JOINTS, d.Name) then
					rig.bones[d.Name] = { bone = d, turn = base.CFrame.Rotation:Inverse() * d.WorldCFrame.Rotation }
				end
			end
		end
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
			if TWO_HANDED[(model:GetAttribute("Asset") :: string?) or ""] then
				target = table.clone(target)
				target.leg_fl = target.leg_fr -- its arms hold one weapon: they swing together
			end
		elseif anim and TRAIN[anim] then
			target = TRAIN[anim](time, (model:GetAttribute("Stride") :: number?) or 1.5, biped, model)
		elseif anim == "attack" and t < ATTACK.length then
			local kind = (model:GetAttribute("Asset") :: string?) or ""
			local clip = if not biped
				then pick(ATTACKS, model, ATTACK)
				elseif string.find(kind, "^foe_archer") then pick(ATTACKS, model, ARCHER_ATTACK)
				elseif string.find(kind, "^foe_mage") then pick(ATTACKS, model, MAGE_ATTACK)
				else pick(ATTACKS, model, BIPED_ATTACK) -- an upright animal has its own
			target = sample(clip, t)
			Spells.step(model, rig.bones, at, t, true) -- its regular attack's own effects, if it has any
		elseif anim == "magic" and t < MAGIC.length then
			target = sample(pick(MAGICS, model, if biped then BIPED_MAGIC else MAGIC), t)
			local own = WEAPON_FX[(model:GetAttribute("Asset") :: string?) or ""]
			if (own and own.power) or FoePowers.has(model) or Spells.step(model, rig.bones, at, t) then
				-- its own effects (weaponFx or FoePowers below, or its spell) in place of the shared ones
				rig.magicAt, rig.impactAt = at, at
			end
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
		if not ((anim == "magic" and t < MAGIC.length) or (anim == "attack" and t < ATTACK.length)) then
			Spells.stop(model)
		end
		-- a held stance (a Shadow Legion enemy's) or an animal's own idle (AnimalMoves): its moves start from it and
		-- settle back into it
		local stance = STANCES[(model:GetAttribute("Asset") :: string?) or ""]
		local idleOf = AnimalMoves.IDLES[(model:GetAttribute("Asset") :: string?) or ""]
			or AnimalMoves.IDLES[speciesOf(model) or ""] -- its own (the Sahara pair), or its species'
		local rest = if stance then stanceAt(stance, time) elseif idleOf then idleOf(time) else nil
		if rest then
			local length = if anim == "attack" then ATTACK.length elseif anim == "magic" then MAGIC.length else 0
			if anim == "hit" and t < HIT.length then
				target = mixed(rest, target, 2) -- a flinch on top of it
			elseif t < length then
				-- out of it into the move, and back into it at the end
				target = mixed(rest, target, math.clamp(math.min(t / 0.12, (length - t) / 0.2), 0, 1))
			elseif anim == nil or anim == "idle" or anim == "attack" or anim == "magic" or anim == "hit" then
				target = rest
			end
		end
		local own = WEAPON_FX[(model:GetAttribute("Asset") :: string?) or ""]
		if own then
			weaponFx(model, own, anim, at, t)
		end
		local boltRgb = FightFx.BOLTS[(model:GetAttribute("Asset") :: string?) or ""]
		if boltRgb then
			boltFx(model, boltRgb, anim, at, t)
		end
		FoePowers.step(model, rig.bones, anim, at, t)
		if model:GetAttribute("Winged") == true then
			target = table.clone(target)
			if stance and (anim ~= "magic" or MAGICS[(model:GetAttribute("Asset") :: string?) or ""]) then
				-- a dragon with a stance of its own poses its wings itself: as its move sets them, else as it stands
				-- (folded, when it walks, falls or wins)
				for _, joint in WING_JOINTS do
					target[joint] = target[joint] or stance[joint]
				end
			else
				for joint, v in wings(time, anim) do
					target[joint] = v
				end
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
		local stiff = AnimalMoves.STIFF[(model:GetAttribute("Asset") :: string?) or ""]
		if stiff then -- its legs turn only so far in any clip (AnimalMoves.STIFF): past it they come apart
			target = table.clone(target)
			for _, leg in { "leg_fl", "leg_fr", "leg_bl", "leg_br" } do
				local v = target[leg]
				if v then
					local w = table.clone(v)
					for k = 1, 3 do
						w[k] = math.clamp(v[k] or 0, -stiff, stiff)
					end
					target[leg] = w
				end
			end
		end
		local scale = ((model:GetAttribute("Scale") :: number?) or 1)
		local blend = math.min(1, dt * 22)
		for _, joint in JOINTS do
			local goal, v = target[joint], rig.now[joint]
			for k = 1, 6 do
				-- (an arrow is in the quiver or on the string, never seen between: it does not ease)
				v[k] += ((if goal then goal[k] or 0 else 0) - v[k]) * (if joint == "arrow" then 1 else blend)
			end
		end
		local lift = Vector3.zero -- feet stay on the ground, except in a fall
		-- (a skinned animal's, from AnimalRig's foot points: only in the moves fitted for it, so the training clips and
		-- the Titan's sleep keep the look they were approved with)
		local raise = 0
		if anim ~= "die" then
			rig.feet = rig.feet or feetOf(rig.joints)
			local feet = rig.feet
			if feet then
				lift = feet.base:VectorToObjectSpace(Vector3.new(0, sunk(feet, rig.now, scale), 0))
			elseif
				next(rig.bones) ~= nil
				and (anim == nil or anim == "idle" or anim == "attack" or anim == "magic" or anim == "hit")
			then
				raise = skinSunk(model, rig.now, scale)
			end
		end
		for _, joint in JOINTS do
			local motor = rig.joints[joint]
			local bone = rig.bones[joint]
			if motor then
				local pose = turned(rig.now[joint], scale)
				motor.Transform = if joint == "body" then CFrame.new(lift) * pose else pose
			elseif bone then
				local pose = turned(rig.now[joint], scale)
				if joint == "body" and raise > 0 then
					pose = CFrame.new(0, raise, 0) * pose
				end
				bone.bone.Transform = bone.turn:Inverse() * pose * bone.turn
			end
		end
	end
end)
