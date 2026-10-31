--!nocheck
-- Checks a place's instance tree against expectations from tools/place-check/expectations.mjs.
-- Runs in two places, so it uses only Instance methods that exist in both:
--   * Lune, on the built .rbxl before upload (tools/place-check/check.luau)
--   * Roblox, on the published version through Open Cloud Luau execution (tools/verify-publish.mjs)
-- Returns { ok, problems, stamp, scripts, checked }. `sha` may be nil (no stamp comparison).
return function(game, spec, sha)
	local problems = {}
	local stamp = nil
	local scripts = 0
	local SCRIPT = { Script = true, LocalScript = true, ModuleScript = true }

	local function find(path)
		local node = game
		for i, name in path do
			local nextNode = nil
			if i == 1 then
				local ok, service = pcall(function()
					return game:GetService(name)
				end)
				nextNode = if ok then service else nil
			end
			nextNode = nextNode or node:FindFirstChild(name)
			if nextNode == nil then
				return nil
			end
			node = nextNode
		end
		return node
	end

	for _, entry in spec.expect do
		local name = table.concat(entry.path, ".")
		local inst = find(entry.path)
		if inst == nil then
			table.insert(problems, `missing {name}`)
		else
			if entry.scripts then
				local n = if SCRIPT[inst.ClassName] then 1 else 0
				for _, d in inst:GetDescendants() do
					if SCRIPT[d.ClassName] then
						n += 1
					end
				end
				scripts += n
				if n < entry.scripts then
					table.insert(problems, `{name} has {n} scripts, expected at least {entry.scripts}`)
				end
			end
			if entry.stamp then
				if inst.ClassName ~= "StringValue" then
					table.insert(problems, `{name} is a {inst.ClassName}, expected StringValue`)
				else
					stamp = inst.Value
				end
			end
		end
	end

	if sha ~= nil then
		local got = if stamp then string.match(stamp, "sha=(%x+)") else nil
		if got == nil then
			table.insert(problems, `build stamp has no sha (got {tostring(stamp)})`)
		elseif string.lower(got) ~= string.lower(sha) then
			table.insert(problems, `build stamp is {got}, expected {sha}`)
		end
	end

	return { ok = #problems == 0, problems = problems, stamp = stamp, scripts = scripts, checked = #spec.expect }
end
