--!strict
-- Analytics (beta blocker 13, SHANNON's pick A; decision 0113): the onboarding funnel, every coin and sample change
-- as an economy event, and a few custom events (early losses, refusals, save and model trouble). Server only;
-- every call is guarded, so analytics can never break a request. Clicks and power presses are never logged: they
-- would spend the place's rate limit (120 + 20 per player a minute).

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

-- What is changing a player's save right now (the request's action, or a payout's name): the economy events'
-- transaction type.
local reason: { [Player]: string } = {}
local last: { [Player]: { coins: number, samples: number } } = {}

-- Each request or payout, and the transaction type the dashboard groups it under.
local KIND: { [string]: string } = {
	buy = "Shop",
	upgrade = "Shop",
	release = "Shop",
	collect = "TimedReward",
	rewards = "TimedReward",
	claim = "TimedReward",
	wave_pay = "Gameplay",
	run_pot = "Gameplay",
	goal = "Gameplay",
}

local function guard(f: (...any) -> (), ...: any)
	local ok, err = pcall(f, ...)
	if not ok then
		warn(`[Analytics] {err}`)
	end
end

-- `player`'s next save changes come from `why` (an action name, "wave_pay", "run_pot").
function Analytics.because(player: Player, why: string)
	reason[player] = why
end

-- The save changed (kit Saves' onChanged): log the coins and samples it gained or spent.
function Analytics.changed(player: Player, profile: any)
	local before = last[player]
	last[player] = { coins = profile.coins, samples = profile.samples }
	if before == nil then -- the first sight of this save: nothing to compare yet
		return
	end
	local why = reason[player] or "other"
	for _, currency in { "coins", "samples" } do
		local delta = profile[currency] - (before :: any)[currency]
		if delta ~= 0 then
			guard(
				AnalyticsService.LogEconomyEvent,
				AnalyticsService,
				player,
				if delta > 0 then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
				if currency == "coins" then "Coins" else "Samples",
				math.abs(delta),
				profile[currency],
				KIND[why] or Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
				why
			)
		end
	end
end

-- The first-session funnel, step by step; a step logged twice counts once.
Analytics.STEPS = {
	"Joined",
	"Bought an egg",
	"Started a hatch",
	"First animal",
	"Has a team",
	"Started a wave",
	"Won a wave",
	"Cleared wave 3",
	"Beat the wave 10 boss",
	"Player level 5",
}
local stepped: { [Player]: { [number]: boolean } } = {}
function Analytics.step(player: Player, k: number)
	local done = stepped[player] or {}
	stepped[player] = done
	if done[k] then -- once a session: every save change asks again
		return
	end
	done[k] = true
	guard(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, k, Analytics.STEPS[k])
end

-- A custom event: `name` (one of a short fixed list), with up to three string fields.
function Analytics.event(player: Player, name: string, value: number?, a: string?, b: string?)
	local fields = {}
	if a then
		fields[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = a
	end
	if b then
		fields[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = b
	end
	guard(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value or 1, fields)
end

function Analytics.forget(player: Player)
	reason[player], last[player], stepped[player] = nil, nil, nil
end

return Analytics
