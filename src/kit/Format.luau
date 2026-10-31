--!strict
-- Kit: text formatting shared by every game's UI. Pure, so the numbers a player sees are tested.

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }

-- 999 -> "999", 1234 -> "1.2K", 15300 -> "15.3K", 2500000 -> "2.5M". Negative numbers keep the
-- sign; NaN and infinities show "0" (a broken value must never print "nan" to a player).
function Format.short(n: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	local x = math.abs(n)
	if x < 1000 then
		return sign .. tostring(math.floor(x))
	end
	local i = 0
	while x >= 1000 and i < #SUFFIXES do
		x /= 1000
		i += 1
	end
	-- Truncate (never round up past what the player has): 1999 -> 1.9K.
	local tenths = math.floor(x * 10 + 1e-9) / 10
	local text = if tenths >= 100 or tenths % 1 == 0
		then tostring(math.floor(tenths))
		else string.format("%.1f", tenths)
	return sign .. text .. SUFFIXES[i]
end

-- 1234567 -> "1,234,567".
function Format.commas(n: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	local digits = tostring(math.floor(math.abs(n)))
	local out = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return sign .. out
end

-- Seconds -> "0:05", "4:20", "1:02:03". Negative and non-finite values show "0:00".
function Format.clock(seconds: number): string
	if seconds ~= seconds or seconds == math.huge or seconds < 0 then
		return "0:00"
	end
	local s = math.floor(seconds)
	local h, m = s // 3600, (s // 60) % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s % 60)
	end
	return string.format("%d:%02d", m, s % 60)
end

-- Seconds -> the largest unit: "45s", "12m", "3h", "2d".
function Format.ago(seconds: number): string
	if seconds ~= seconds or seconds < 0 or seconds == math.huge then
		return "0s"
	end
	local s = math.floor(seconds)
	if s < 60 then
		return `{s}s`
	elseif s < 3600 then
		return `{s // 60}m`
	elseif s < 86400 then
		return `{s // 3600}h`
	end
	return `{s // 86400}d`
end

-- (1, "egg") -> "1 egg", (3, "egg") -> "3 eggs", (2, "box", "boxes") -> "2 boxes".
function Format.plural(n: number, one: string, many: string?): string
	return `{Format.commas(n)} {if n == 1 then one else many or (one .. "s")}`
end

return Format
