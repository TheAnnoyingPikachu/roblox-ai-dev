--!strict
-- What the parts of the HUD share (STATION-135). Hud.client.luau and the Hud* modules beside it are one
-- script cut into files: a part puts what later parts need on this table once (`App.name = name`) and they
-- take it as a local at their top. A name that is assigned again after that lives on `S` instead, and is
-- read and written as `S.name` everywhere, so no part can hold a stale copy.
local App = { S = {} }

return setmetatable(App, {
	__index = function(_, name) -- a part asked for something no earlier part has made
		error(`Hud: "{name}" is not shared yet: check the order of the parts in Hud.client.luau`, 2)
	end,
})
