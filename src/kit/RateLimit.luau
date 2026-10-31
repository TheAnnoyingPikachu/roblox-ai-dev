--!strict
-- Kit: per-key token buckets for remotes and prompts. Pure: the caller passes `now` (seconds).
--
-- A bucket holds up to `burst` tokens and refills at `perSecond`. `take` spends `cost` tokens
-- (default 1) when it can; a refused take spends nothing and never pushes the refill back, so a
-- spamming client cannot lock itself out for longer than the bucket needs to refill.
--
--   local limit = RateLimit.new({ burst = 4, perSecond = 2 })
--   if not limit:take(player.UserId, os.clock()) then return false, "rate" end

local RateLimit = {}
RateLimit.__index = RateLimit

export type Options = { burst: number, perSecond: number }
type Bucket = { tokens: number, at: number }
export type Limiter = typeof(setmetatable(
	{} :: { burst: number, perSecond: number, buckets: { [any]: Bucket } },
	RateLimit
))

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

function RateLimit.new(options: Options): Limiter
	assert(finite(options.burst) and options.burst >= 1, "RateLimit: burst must be >= 1")
	assert(finite(options.perSecond) and options.perSecond > 0, "RateLimit: perSecond must be > 0")
	return setmetatable({ burst = options.burst, perSecond = options.perSecond, buckets = {} }, RateLimit)
end

-- A limiter that allows one action per `seconds` (burst 1).
function RateLimit.every(seconds: number): Limiter
	assert(finite(seconds) and seconds > 0, "RateLimit.every: seconds must be > 0")
	return RateLimit.new({ burst = 1, perSecond = 1 / seconds })
end

local function refill(self: Limiter, key: any, now: number): Bucket
	local bucket = self.buckets[key]
	if bucket == nil then
		bucket = { tokens = self.burst, at = now }
		self.buckets[key] = bucket
		return bucket
	end
	-- A clock that steps backwards (os.time adjustments) refills nothing rather than going negative.
	local dt = math.max(0, now - bucket.at)
	bucket.tokens = math.min(self.burst, bucket.tokens + dt * self.perSecond)
	bucket.at = math.max(bucket.at, now)
	return bucket
end

function RateLimit.take(self: Limiter, key: any, now: number, cost: number?): boolean
	local spend = cost or 1
	if not finite(now) or not finite(spend) or spend < 0 then
		return false
	end
	local bucket = refill(self, key, now)
	-- 1e-9 absorbs float error from fractional refill rates (0.35 s cooldowns).
	if bucket.tokens + 1e-9 < spend then
		return false
	end
	bucket.tokens = math.max(0, bucket.tokens - spend)
	return true
end

-- Tokens available at `now`, without spending any.
function RateLimit.peek(self: Limiter, key: any, now: number): number
	return refill(self, key, now).tokens
end

-- Forget a key (call on PlayerRemoving so the table does not grow forever).
function RateLimit.reset(self: Limiter, key: any)
	self.buckets[key] = nil
end

return RateLimit
