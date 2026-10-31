--!strict
-- Kit: validators for remote arguments. A client can send any value (tables, Instances, NaN,
-- huge strings), so every remote checks its arguments against a list of validators before any
-- game code sees them. Pure: no Roblox API.
--
--   local args = { Payload.enum({ "buy", "sell" }), Payload.int({ min = 1, max = 30 }) }
--   local ok, values = Payload.check(args, table.pack(...))
--
-- Validators return (true, cleaned) or (false). `check` also refuses extra arguments.

local Payload = {}

export type Validator = (any) -> (boolean, any)

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

-- A string of at most `max` bytes (default 64), optionally matching a Lua pattern that should be
-- anchored (for example "^%d+$").
function Payload.string(options: { max: number?, min: number?, pattern: string? }?): Validator
	local o = options or {}
	local max, min, pattern = o.max or 64, o.min or 0, o.pattern
	return function(value)
		if type(value) ~= "string" or #value > max or #value < min then
			return false
		end
		if pattern and string.match(value, pattern) == nil then
			return false
		end
		return true, value
	end
end

-- A whole number in [min, max]. Accepts a number or a digit string (ids sent as text).
function Payload.int(options: { min: number, max: number }): Validator
	return function(value)
		local n = value
		if type(n) == "string" and #n <= 16 and string.match(n, "^%-?%d+$") then
			n = tonumber(n)
		end
		if not finite(n) or n % 1 ~= 0 or n < options.min or n > options.max then
			return false
		end
		return true, n
	end
end

-- A finite number in [min, max].
function Payload.number(options: { min: number, max: number }): Validator
	return function(value)
		if not finite(value) or value < options.min or value > options.max then
			return false
		end
		return true, value
	end
end

function Payload.boolean(): Validator
	return function(value)
		if type(value) ~= "boolean" then
			return false
		end
		return true, value
	end
end

-- One of a fixed list of strings.
function Payload.enum(values: { string }): Validator
	local set = {}
	for _, v in values do
		set[v] = true
	end
	return function(value)
		if type(value) ~= "string" or not set[value] then
			return false
		end
		return true, value
	end
end

-- nil, or a value the inner validator accepts.
function Payload.optional(inner: Validator): Validator
	return function(value)
		if value == nil then
			return true, nil
		end
		return inner(value)
	end
end

-- Checks a packed argument list (`table.pack(...)`) against `validators`, one per position.
-- Returns (true, cleaned values as an array with n set) or (false, index of the bad argument).
function Payload.check(validators: { Validator }, args: { n: number, [number]: any }): (boolean, any)
	local count = args.n or #args
	if count > #validators then
		return false, #validators + 1
	end
	local out: { [number]: any, n: number } = { n = #validators }
	for i, validate in validators do
		local ok, value = validate(args[i])
		if not ok then
			return false, i
		end
		out[i] = value
	end
	return true, out
end

return Payload
