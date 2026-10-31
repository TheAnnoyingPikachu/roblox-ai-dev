--!strict
-- Kit building blocks without Roblox: rate limits, payload validation, the request router, text
-- formatting and the build stamp. Saves are in SaveStore.spec.luau.
local T = require("./framework")
local BuildStamp = require("../src/kit/BuildStamp")
local Format = require("../src/kit/Format")
local Payload = require("../src/kit/Payload")
local RateLimit = require("../src/kit/RateLimit")
local Router = require("../src/kit/Router")

local describe, it, expect = T.describe, T.it, T.expect

describe("RateLimit", function()
	it("allows a burst, then refuses until tokens refill", function()
		local limit = RateLimit.new({ burst = 3, perSecond = 1 })
		expect(limit:take("a", 0)).toBe(true)
		expect(limit:take("a", 0)).toBe(true)
		expect(limit:take("a", 0)).toBe(true)
		expect(limit:take("a", 0)).toBe(false)
		expect(limit:take("a", 0.5)).toBe(false)
		expect(limit:take("a", 1.0)).toBe(true)
	end)

	it("keeps keys separate", function()
		local limit = RateLimit.every(1)
		expect(limit:take("a", 0)).toBe(true)
		expect(limit:take("b", 0)).toBe(true)
		expect(limit:take("a", 0)).toBe(false)
	end)

	it("refused takes do not push the refill back", function()
		local limit = RateLimit.every(0.35)
		expect(limit:take(1, 0)).toBe(true)
		for i = 1, 20 do
			limit:take(1, i * 0.01)
		end
		expect(limit:take(1, 0.35)).toBe(true)
	end)

	it("never exceeds the burst after a long idle", function()
		local limit = RateLimit.new({ burst = 2, perSecond = 10 })
		expect(limit:peek("a", 1e6)).toBe(2)
	end)

	it("refuses NaN times and negative costs, survives a clock stepping back", function()
		local limit = RateLimit.new({ burst = 1, perSecond = 1 })
		expect(limit:take("a", 0 / 0)).toBe(false)
		expect(limit:take("a", 0, -5)).toBe(false)
		expect(limit:take("a", 10)).toBe(true)
		expect(limit:take("a", 5)).toBe(false)
		expect(limit:peek("a", 5) >= 0).toBe(true)
	end)

	it("reset forgets a key", function()
		local limit = RateLimit.every(60)
		limit:take("a", 0)
		limit:reset("a")
		expect(limit:take("a", 0)).toBe(true)
	end)
end)

describe("Payload", function()
	it("string checks type, length and pattern", function()
		local id = Payload.string({ max = 6, pattern = "^%d+$" })
		expect((id("123"))).toBe(true)
		expect((id("12a"))).toBe(false)
		expect((id("1234567"))).toBe(false)
		expect((id(123))).toBe(false)
		expect((id({}))).toBe(false)
	end)

	it("int accepts whole numbers and digit strings in range, nothing else", function()
		local floor = Payload.int({ min = 1, max = 30 })
		local ok, v = floor("7")
		expect(ok).toBe(true)
		expect(v).toBe(7)
		expect((floor(30))).toBe(true)
		expect((floor(0))).toBe(false)
		expect((floor(31))).toBe(false)
		expect((floor(2.5))).toBe(false)
		expect((floor(0 / 0))).toBe(false)
		expect((floor(math.huge))).toBe(false)
		expect((floor("1e1"))).toBe(false)
		expect((floor(string.rep("9", 40)))).toBe(false)
	end)

	it("number rejects NaN and infinities", function()
		local n = Payload.number({ min = -10, max = 10 })
		expect((n(1.5))).toBe(true)
		expect((n(0 / 0))).toBe(false)
		expect((n(-math.huge))).toBe(false)
	end)

	it("enum, boolean and optional", function()
		local e = Payload.enum({ "buy", "sell" })
		expect((e("buy"))).toBe(true)
		expect((e("steal"))).toBe(false)
		expect((Payload.boolean()(false))).toBe(true)
		expect((Payload.boolean()("true"))).toBe(false)
		local o = Payload.optional(e)
		expect((o(nil))).toBe(true)
		expect((o("x"))).toBe(false)
	end)

	it("check refuses extra arguments and names the bad position", function()
		local args = { Payload.enum({ "a" }), Payload.int({ min = 0, max = 9 }) }
		local ok, values = Payload.check(args, table.pack("a", "4"))
		expect(ok).toBe(true)
		expect(values[2]).toBe(4)
		local bad, at = Payload.check(args, table.pack("a", 4, "extra"))
		expect(bad).toBe(false)
		expect(at).toBe(3)
		local bad2, at2 = Payload.check(args, table.pack("a", 99))
		expect(bad2).toBe(false)
		expect(at2).toBe(2)
	end)
end)

describe("Router", function()
	local function make(ready: boolean?)
		local calls = {}
		local errors = {}
		local router = Router.new({
			limiter = RateLimit.new({ burst = 2, perSecond = 1 }),
			ready = function()
				return ready ~= false
			end,
			onError = function(action, _err)
				table.insert(errors, action)
			end,
			actions = {
				buy = {
					args = { Payload.int({ min = 1, max = 5 }) },
					handler = function(_player, n)
						table.insert(calls, n)
						if n == 5 then
							return false, "credits"
						end
						return true
					end,
				},
				boom = {
					args = {},
					handler = function()
						error("handler bug")
					end,
				},
			},
		})
		return router, calls, errors
	end

	it("runs a valid request with cleaned arguments", function()
		local router, calls = make()
		local ok, code = router:handle("p", 0, "buy", "3")
		expect(ok).toBe(true)
		expect(code).toBeNil()
		expect(calls[1]).toBe(3)
	end)

	it("refuses while loading without spending tokens or calling the handler", function()
		local router, calls = make(false)
		local ok, code = router:handle("p", 0, "buy", 1)
		expect(ok).toBe(false)
		expect(code).toBe("loading")
		expect(#calls).toBe(0)
	end)

	it("refuses unknown actions, non-string actions and bad payloads", function()
		local router, calls = make()
		expect(select(2, router:handle("p", 0, "steal"))).toBe("unknown")
		expect(select(2, router:handle("p", 10, { "buy" }))).toBe("unknown")
		expect(select(2, router:handle("p", 20, "buy", 99))).toBe("payload")
		expect(select(2, router:handle("p", 30, "buy", 1, 2))).toBe("payload")
		expect(#calls).toBe(0)
	end)

	it("malformed spam spends tokens, so it is rate limited too", function()
		local router = make()
		router:handle("p", 0, "nope")
		router:handle("p", 0, "nope")
		expect(select(2, router:handle("p", 0, "buy", 1))).toBe("rate")
	end)

	it("passes the handler's refusal code through", function()
		local router = make()
		local ok, code = router:handle("p", 0, "buy", 5)
		expect(ok).toBe(false)
		expect(code).toBe("credits")
	end)

	it("turns a handler error into 'error' and reports it", function()
		local router, _, errors = make()
		local ok, code = router:handle("p", 0, "boom")
		expect(ok).toBe(false)
		expect(code).toBe("error")
		expect(errors[1]).toBe("boom")
	end)

	it("forget clears the player's bucket", function()
		local router = make()
		router:handle("p", 0, "buy", 1)
		router:handle("p", 0, "buy", 1)
		router:forget("p")
		expect((router:handle("p", 0, "buy", 1))).toBe(true)
	end)
end)

describe("Format", function()
	it("short truncates to one decimal with a suffix", function()
		expect(Format.short(0)).toBe("0")
		expect(Format.short(999)).toBe("999")
		expect(Format.short(1000)).toBe("1K")
		expect(Format.short(1234)).toBe("1.2K")
		expect(Format.short(1999)).toBe("1.9K")
		expect(Format.short(15300)).toBe("15.3K")
		expect(Format.short(999999)).toBe("999K")
		expect(Format.short(2500000)).toBe("2.5M")
		expect(Format.short(-1500)).toBe("-1.5K")
		expect(Format.short(0 / 0)).toBe("0")
		expect(Format.short(math.huge)).toBe("0")
	end)

	it("commas, clock, ago and plural", function()
		expect(Format.commas(1234567)).toBe("1,234,567")
		expect(Format.commas(123)).toBe("123")
		expect(Format.commas(-1000)).toBe("-1,000")
		expect(Format.clock(5)).toBe("0:05")
		expect(Format.clock(260)).toBe("4:20")
		expect(Format.clock(3723)).toBe("1:02:03")
		expect(Format.clock(-1)).toBe("0:00")
		expect(Format.ago(45)).toBe("45s")
		expect(Format.ago(720)).toBe("12m")
		expect(Format.ago(3 * 3600)).toBe("3h")
		expect(Format.ago(2 * 86400)).toBe("2d")
		expect(Format.plural(1, "egg")).toBe("1 egg")
		expect(Format.plural(3, "egg")).toBe("3 eggs")
		expect(Format.plural(2, "box", "boxes")).toBe("2 boxes")
	end)
end)

describe("BuildStamp", function()
	local SHA = "0123456789abcdef0123456789abcdef01234567"
	local TEXT = `sha={SHA};time=2026-10-31T17:00:00Z;ref=refs/heads/main;run=123.1`

	it("parses a CI stamp", function()
		local s = BuildStamp.parse(TEXT)
		expect(s.dev).toBe(false)
		expect(s.sha).toBe(SHA)
		expect(s.short).toBe("0123456")
		expect(s.ref).toBe("refs/heads/main")
		expect(s.run).toBe("123.1")
	end)

	it("treats the committed placeholder and junk as dev", function()
		expect(BuildStamp.parse("dev\n").dev).toBe(true)
		expect(BuildStamp.parse(nil).dev).toBe(true)
		expect(BuildStamp.parse("sha=xyz").dev).toBe(true)
		expect(BuildStamp.label("dev")).toBe("dev")
	end)

	it("log line and label carry the short sha", function()
		expect(BuildStamp.label(TEXT)).toBe("0123456")
		local line = BuildStamp.line(TEXT, "garden")
		expect(string.find(line, "[Build] 0123456 (garden)", 1, true) ~= nil).toBe(true)
		expect(string.find(BuildStamp.line("dev", "night"), "[Build] dev", 1, true) ~= nil).toBe(true)
	end)

	it("matches full and abbreviated shas, case-insensitive, and nothing else", function()
		expect(BuildStamp.matches(TEXT, SHA)).toBe(true)
		expect(BuildStamp.matches(TEXT, "0123456")).toBe(true)
		expect(BuildStamp.matches(TEXT, "0123456789ABCDEF")).toBe(true)
		expect(BuildStamp.matches(TEXT, "fffffff")).toBe(false)
		expect(BuildStamp.matches(TEXT, "0123")).toBe(false)
		expect(BuildStamp.matches("dev", SHA)).toBe(false)
	end)
end)
