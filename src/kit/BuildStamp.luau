--!strict
-- Kit: the build stamp (SPIRE-002). CI writes build-info/BuildInfo.txt before `rojo build`
-- (tools/write-build-info.mjs); every project maps it to ReplicatedStorage.BuildInfo (a StringValue).
-- A local build carries the committed text "dev".
--
-- Format, one line: "sha=<40 hex>;time=<UTC ISO>;ref=<git ref>;run=<run id>". Unknown keys are
-- kept, missing keys are empty. Pure, so the server log line, the menu label and the post-publish
-- check (tools/verify-publish.mjs) all read the stamp the same way.

local BuildStamp = {}

export type Stamp = {
	dev: boolean,
	sha: string,
	short: string,
	time: string,
	ref: string,
	run: string,
	fields: { [string]: string },
}

function BuildStamp.parse(text: any): Stamp
	local fields: { [string]: string } = {}
	if type(text) == "string" then
		for pair in string.gmatch(text, "[^;\r\n]+") do
			local k, v = string.match(pair, "^%s*([%w_]+)%s*=%s*(.-)%s*$")
			if k and v then
				fields[k] = v
			end
		end
	end
	local sha = fields.sha or ""
	if string.match(sha, "^%x+$") == nil or #sha < 7 then
		sha = ""
	end
	return {
		dev = sha == "",
		sha = string.lower(sha),
		short = string.lower(string.sub(sha, 1, 7)),
		time = fields.time or "",
		ref = fields.ref or "",
		run = fields.run or "",
		fields = fields,
	}
end

-- The line the server prints at start. The post-publish check and playtest notes match on
-- "[Build] <short>".
function BuildStamp.line(text: any, place: string): string
	local s = BuildStamp.parse(text)
	if s.dev then
		return `[Build] dev ({place}): local build, no CI stamp`
	end
	return `[Build] {s.short} ({place}) built {s.time} from {s.ref} run {s.run}`
end

-- The corner label in the menu.
function BuildStamp.label(text: any): string
	local s = BuildStamp.parse(text)
	return if s.dev then "dev" else s.short
end

-- True when the stamp was built from `sha` (full or abbreviated, at least 7 characters).
function BuildStamp.matches(text: any, sha: string): boolean
	local s = BuildStamp.parse(text)
	local want = string.lower(sha)
	if s.dev or #want < 7 or string.match(want, "^%x+$") == nil then
		return false
	end
	return string.sub(s.sha, 1, #want) == want or string.sub(want, 1, #s.sha) == s.sha
end

return BuildStamp
