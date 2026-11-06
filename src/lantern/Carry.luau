--!strict
-- The look of carrying (docs/architecture/lantern.md 4.1): small items welded to the back in three
-- slots, the supply crate welded in front, the critter crate held by server-owned AlignPosition and
-- AlignOrientation in front of its carrier or at the two carriers' midpoint. Also each carrier's G4
-- samples (CarryRules.pace decides) and the load box test. CarryRules decides who carries what; this
-- file only shows it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CarryRules"))
local Train = require(script.Parent:WaitForChild("Train"))

local Carry = {}

local SLOTS = { CFrame.new(0, 0.2, 1.1), CFrame.new(0, 1.5, 1.1), CFrame.new(0, -1.1, 1.1) } -- on the back
local FRONT = CFrame.new(0, 0, -2.4)

type Hold = { body: BasePart, by: BasePart, helper: BasePart?, align: AlignPosition, orient: AlignOrientation }
local holds: { [BasePart]: Hold } = {}
local paces: { [number]: CarryRules.Pace } = {}

-- Undoes any carry on `body` and anchors it where it is.
function Carry.release(body: BasePart)
	holds[body] = nil
	for _, child in body:GetChildren() do
		if child.Name == "CarryWeld" or child:IsA("AlignPosition") or child:IsA("AlignOrientation") then
			child:Destroy()
		end
	end
	body.Anchored = true
end

-- Shows `body` carried: `slot` 1 to 3 for a small item, else in front; a critter crate floats
-- between `by` and `helper` (roots).
function Carry.hold(body: BasePart, kind: string, slot: number, by: BasePart, helper: BasePart?)
	Carry.release(body)
	if kind == "critter" then
		local attachment = (body:FindFirstChild("Hold") :: Attachment?) or Instance.new("Attachment")
		attachment.Name = "Hold"
		attachment.Parent = body
		local align = Instance.new("AlignPosition")
		align.Mode = Enum.PositionAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.RigidityEnabled = true
		align.Parent = body
		local orient = Instance.new("AlignOrientation")
		orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
		orient.Attachment0 = attachment
		orient.RigidityEnabled = true
		orient.Parent = body
		holds[body] = { body = body, by = by, helper = helper, align = align, orient = orient }
		Carry.step() -- places the still-anchored crate on its target
		body.Anchored = false
		body:SetNetworkOwner(nil)
		return
	end
	body.CFrame = by.CFrame * (if kind == "supply" then FRONT else SLOTS[math.clamp(slot, 1, 3)])
	body.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0, weld.Part1 = by, body
	weld.Parent = body
end

-- Moves every held critter crate (Heartbeat).
function Carry.step()
	for body, h in holds do
		if h.by.Parent == nil or (h.helper and h.helper.Parent == nil) then
			continue
		end
		local target
		if h.helper then
			local a, b = h.by.Position, h.helper.Position
			local along = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local mid = (a + b) / 2
			target = if along.Magnitude > 0.1 then CFrame.lookAt(mid, mid + along) else CFrame.new(mid)
		else
			target = h.by.CFrame * FRONT
		end
		h.align.Position = target.Position + Vector3.new(0, 0.3, 0)
		h.orient.CFrame = target.Rotation
		if body.Anchored then
			body.CFrame = target
		end
	end
end

local function vec(p: Vector3): { x: number, y: number, z: number }
	return { x = p.X, y = p.Y, z = p.Z }
end

-- A fresh G4 sample where an item is picked up (QA M2), at every pick even with full hands (QA r2:
-- a teleport to a far item and back is checked from the pick spot), and after the server's own
-- stand move (QA r3).
function Carry.start(userId: number, pos: Vector3, now: number)
	paces[userId] = (CarryRules.pace(nil, vec(pos), 0, now))
end

-- G4 (QA M2), every tick before the tick's loads: whether `userId` (carrying at `speed`) moved
-- within the limit, the last position that passed (drop the load there) and whether they may load
-- this tick (never on their first sample).
function Carry.check(userId: number, pos: Vector3, speed: number, now: number): (boolean, Vector3, boolean)
	local pace, ok, ready = CarryRules.pace(paces[userId], vec(pos), speed, now)
	paces[userId] = pace
	return ok, Vector3.new(pace.valid.x, pace.valid.y, pace.valid.z), ready
end

-- Forget a carrier's samples (not carrying, left, caught).
function Carry.forget(userId: number)
	paces[userId] = nil
end

function Carry.inLoadBox(pos: Vector3): boolean
	return Train.inLoadBox(pos)
end

return Carry
