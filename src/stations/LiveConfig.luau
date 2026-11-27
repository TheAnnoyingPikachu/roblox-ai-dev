--!strict
-- Live tuning on the server (decision 0131): reads LiveTuning's keys from ConfigService (the Creator Hub's Configs
-- page), applies them inside their approved ranges, and hands them to every client as ReplicatedStorage attributes
-- ("Live_<key>"), which the HUD applies too. A key that is missing, or a ConfigService that cannot be reached, means
-- the key's default. New values are applied as soon as Roblox makes them available (up to 5 minutes after publish).

local ConfigService = game:GetService("ConfigService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveTuning = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveTuning"))

local LiveConfig = {}

local function publish(snapshot: ConfigSnapshot?)
	local raw = {}
	for key in LiveTuning.KEYS do
		if snapshot then
			local ok, value = pcall(snapshot.GetValue, snapshot, key)
			raw[key] = if ok then value else nil
		end
	end
	local used = LiveTuning.apply(raw)
	for key, value in used do
		ReplicatedStorage:SetAttribute(`Live_{key}`, value)
	end
end

-- The defaults at once, then the live values when ConfigService answers (it can wait a long time, or for ever in
-- an unpublished place), so nothing at start waits on it.
function LiveConfig.start()
	publish(nil)
	task.spawn(function()
		local ok, snapshot = pcall(function()
			return ConfigService:GetConfigAsync()
		end)
		if not ok then
			warn(`[LiveConfig] configs unavailable, using defaults: {snapshot}`)
			return
		end
		publish(snapshot)
		snapshot.UpdateAvailable:Connect(function()
			pcall(snapshot.Refresh, snapshot)
			publish(snapshot)
		end)
	end)
end

return LiveConfig
