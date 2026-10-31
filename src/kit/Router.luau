--!strict
-- Kit: the server-side request router every game remote goes through. Pure: Roblox wiring lives in
-- src/kit-roblox/Remotes.luau, which calls `handle` from OnServerInvoke with os.clock().
--
-- Order of checks (cheapest first, every refusal is a short code the client maps to text):
--   1. "loading"  the player's session is not ready (profile still loading)
--   2. "rate"     the player's token bucket is empty (spam, including malformed spam, costs tokens)
--   3. "unknown"  action is not a string naming a registered action
--   4. "payload"  the arguments fail the action's validators (kit/Payload)
--   5. handler    returns (ok, code?); a thrown error becomes "error" and is reported to onError
--
-- The client only ever names an action and its arguments. Amounts, prices and outcomes are decided
-- by the handler on the server (CLAUDE.md rule 4).

local Payload = require("./Payload")
local RateLimit = require("./RateLimit")

local Router = {}
Router.__index = Router

export type Handler = (player: any, ...any) -> (boolean, string?)
export type Action = {
	args: { Payload.Validator },
	handler: Handler,
	cost: number?, -- tokens this action spends (default 1)
}
export type Options = {
	actions: { [string]: Action },
	limiter: RateLimit.Limiter?, -- default: burst 6, 4 per second
	ready: ((player: any) -> boolean)?, -- default: always ready
	keyOf: ((player: any) -> any)?, -- rate-limit key, default the player itself
	onError: ((action: string, err: any) -> ())?,
}
export type Router = typeof(setmetatable({} :: { options: Options, limiter: RateLimit.Limiter }, Router))

function Router.new(options: Options): Router
	for name, action in options.actions do
		assert(type(name) == "string" and #name <= 32, "Router: action names are strings of at most 32 bytes")
		assert(type(action.handler) == "function", `Router: action {name} needs a handler`)
		assert(type(action.args) == "table", "Router: action " .. name .. " needs an args list (use {} for none)")
	end
	local limiter = options.limiter or RateLimit.new({ burst = 6, perSecond = 4 })
	return setmetatable({ options = options, limiter = limiter }, Router)
end

function Router.handle(self: Router, player: any, now: number, action: any, ...: any): (boolean, string?)
	local o = self.options
	if o.ready and not o.ready(player) then
		return false, "loading"
	end
	local entry = if type(action) == "string" then o.actions[action] else nil
	local key = if o.keyOf then o.keyOf(player) else player
	if not self.limiter:take(key, now, if entry then entry.cost else 1) then
		return false, "rate"
	end
	if entry == nil then
		return false, "unknown"
	end
	local ok, values = Payload.check(entry.args, table.pack(...))
	if not ok then
		return false, "payload"
	end
	local called, accepted, code = pcall(entry.handler, player, table.unpack(values, 1, values.n))
	if not called then
		if o.onError then
			o.onError(action, accepted)
		end
		return false, "error"
	end
	if accepted == true then
		return true, nil
	end
	return false, if type(code) == "string" then code else "refused"
end

-- Call on PlayerRemoving.
function Router.forget(self: Router, player: any)
	local o = self.options
	self.limiter:reset(if o.keyOf then o.keyOf(player) else player)
end

return Router
