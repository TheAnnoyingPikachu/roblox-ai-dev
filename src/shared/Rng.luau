--!strict
-- Small seeded generator (xorshift32) so every random choice in the night is reproducible under
-- Lune and the same on every server. No Roblox APIs (`math.random` and `Random` are not seedable
-- per call site).

local Rng = {}

export type State = number -- integer in [1, 2^32 - 1]

local TWO32 = 2 ^ 32
local ZERO = 0x9E3779B9

-- 32-bit multiply without losing float precision: split `a` into 16-bit halves.
local function mul32(a: number, b: number): number
	local hi = bit32.rshift(a, 16)
	local lo = bit32.band(a, 0xFFFF)
	return ((hi * b) % 65536 * 65536 + lo * b) % TWO32
end

local function step(x: number): number
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	return bit32.bxor(x, bit32.lshift(x, 5))
end

-- FNV-1a over the three words, then a few xorshift steps to spread nearby inputs.
function Rng.seed(a: number, b: number?, c: number?): State
	local h = 0x811C9DC5
	for _, v in { a, b or 0, c or 0 } do
		h = mul32(bit32.bxor(h, math.floor(v) % TWO32), 0x01000193)
	end
	if h == 0 then
		h = ZERO
	end
	for _ = 1, 4 do
		h = step(h)
	end
	return h
end

function Rng.next(state: State): (number, State)
	local s = step(if state == 0 then ZERO else state)
	return s / TWO32, s
end

function Rng.int(state: State, lo: number, hi: number): (number, State)
	local value, s = Rng.next(state)
	return lo + math.floor(value * (hi - lo + 1)), s
end

return Rng
