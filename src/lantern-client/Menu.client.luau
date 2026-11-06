--!strict
-- Lantern Express start menu and panels (GDD H2, H4 to H8; architecture lantern 6): the logo, PLAY
-- and the critter showcase over a slow orbit of Lamplight Depot; ALBUM (GRID, WHERE with
-- LootRules.odds, FOLLOWER), LOCKER (LIVERY, LAMP, BADGE), REWARDS (WEEKLY, MONTHLY, QUESTS), BOARD
-- and SETTINGS (music and sound volumes, Calm night, how to play). Requests only; the server decides.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanternConfig = require(Shared:WaitForChild("LanternConfig"))
local LanternProgress = require(Shared:WaitForChild("LanternProgress"))
local LoginRules = require(Shared:WaitForChild("LoginRules"))
local LootRules = require(Shared:WaitForChild("LootRules"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local TrackRules = require(Shared:WaitForChild("TrackRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState")) -- configures the kit first
local UiKit = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("UiKit"))

local UI = ClientState.UI
local ACCENT = ClientState.ACCENT
local new = UiKit.new
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local gui = new("ScreenGui", {
	Name = "LanternMenu",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
	Parent = player:WaitForChild("PlayerGui"),
})
UiKit.scaleRoot(gui)

local function today(): number
	return MetaRules.dayOf(math.floor(ClientState.now()))
end

local function clear(body: Instance)
	for _, c in body:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function line(body: Instance, s: string, size: number, colour: Color3?, order: number): TextLabel
	return UiKit.text(body, s, size, colour or UI.INK, {
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, size + 10),
	})
end

local function pct(bp: number): string
	return string.format("%.2f%%", bp / 100)
end

-- A row with a title, a smaller line and an optional button on the right.
local function itemRow(
	body: Instance,
	order: number,
	title: string,
	sub: string,
	button: string?,
	colour: Color3?,
	onClick: (() -> ())?,
	enabled: boolean?
): Frame
	local row = UiKit.row(body, 76, order)
	UiKit.text(row, title, 24, UI.INK, {
		Position = UDim2.fromOffset(20, 6),
		Size = UDim2.new(1, -250, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	UiKit.text(row, sub, 17, UI.INK_SOFT, {
		Position = UDim2.fromOffset(20, 40),
		Size = UDim2.new(1, -250, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	if button then
		local b = UiKit.button(row, button, colour or UI.GOLD, "small", 190, onClick or function() end)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -20, 0.5, -3)
		UiKit.setEnabled(b, enabled ~= false and onClick ~= nil)
	end
	return row
end

-- ALBUM ---------------------------------------------------------------------------------------------------

local where = { line = "forest", leg = 1, tile = "village" }

local function albumGrid(body: ScrollingFrame)
	local p = ClientState.profile()
	line(body, `Hollowmere Album: {#p.index} / {#LanternConfig.CRITTERS} found`, 26, nil, 1)
	local miles = {}
	for _, m in LanternConfig.MILESTONES do
		local got = p.milestones[tostring(m.count)] == true
		table.insert(
			miles,
			`{m.count}: {if m.cosmetic then (LanternConfig.cosmetic(m.cosmetic) :: any).name else ""}{if m.cosmetic
					and m.tickets
				then " + "
				else ""}{if m.tickets then `{m.tickets} Tickets` else ""}{if got then " (got it)" else ""}`
		)
	end
	line(body, "Milestones · " .. table.concat(miles, " · "), 17, UI.INK_SOFT, 2)
	local holder =
		new("Frame", { Size = UDim2.fromScale(1, 0), BackgroundTransparency = 1, LayoutOrder = 3, Parent = body })
	UiKit.grid(holder, 160, 180)
	for i, c in LanternConfig.CRITTERS do
		local count = p.rescues[c.id] or 0
		local card = UiKit.card(holder, "creature", if count > 0 then ClientState.rarityColour(c.id) else UI.GREY)
		card.frame.LayoutOrder = i
		UiKit.viewport(card.icon, c.id, count == 0)
		card.name.Text = if count > 0 then c.name else "???"
		if count > 0 then
			UiKit.setPill(card, `x{count}`, ClientState.rarityColour(c.id))
		elseif c.rarity == "exclusive" then
			UiKit.setPill(card, "Login", UI.GREY)
		else
			UiKit.setPill(card, ClientState.rarityName(c.id), UI.GREY)
		end
	end
end

-- WHERE: the exact species odds per crate band for one tile (GDD H4), each band summing to 100%.
local function albumWhere(body: ScrollingFrame, redraw: () -> ())
	local r = ClientState.run()
	line(body, "Odds per critter crate. Near crates are under 70 studs from the platform.", 18, UI.INK_SOFT, 1)
	local function pickRow(order: number, options: { { id: any, label: string } }, current: any, set: (any) -> ())
		local row = new(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = order, Parent = body },
			{
				new(
					"UIListLayout",
					{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Wraps = true }
				),
			}
		)
		for _, o in options do
			local b = UiKit.button(row, o.label, if o.id == current then UI.GOLD else UI.GREY, "small", 120, function()
				set(o.id)
				redraw()
			end)
			b.LayoutOrder = 0
		end
		row.AutomaticSize = Enum.AutomaticSize.Y
	end
	pickRow(2, { { id = "forest", label = "FOREST" }, { id = "lake", label = "LAKE" } }, where.line, function(v)
		where.line = v
		if not table.find(LanternConfig.LINE_TILES[v], where.tile) then
			where.tile = LanternConfig.LINE_TILES[v][1]
		end
	end)
	pickRow(
		3,
		{ { id = 1, label = "LEG 1" }, { id = 2, label = "LEG 2" }, { id = 3, label = "LEG 3" } },
		where.leg,
		function(v)
			where.leg = v
		end
	)
	local tiles = {}
	for _, id in LanternConfig.LINE_TILES[where.line] do
		table.insert(tiles, { id = id, label = string.upper((LanternConfig.tile(id) :: any).name) })
	end
	pickRow(4, tiles, where.tile, function(v)
		where.tile = v
	end)
	if r.Phase == "stop" and r.Tile == where.tile then
		line(body, "This is the stop the train is at now.", 18, UI.LEAF, 5)
	end
	local order = 6
	for _, band in { { far = false, title = "Near crates" }, { far = true, title = "Far crates" } } do
		local odds = LootRules.odds(where.line :: any, where.leg, where.tile, band.far)
		local ids, total = {}, 0
		for id, bp in odds do
			table.insert(ids, id)
			total += bp
		end
		table.sort(ids, function(a, b)
			return if odds[a] == odds[b] then a < b else odds[a] > odds[b]
		end)
		order += 1
		line(body, `{band.title} · total {pct(total)}`, 24, nil, order)
		for _, id in ids do
			order += 1
			local row = UiKit.row(body, 44, order)
			UiKit.text(
				row,
				`{ClientState.critterName(id)} ({ClientState.rarityName(id)})`,
				20,
				ClientState.rarityColour(id):Lerp(UI.INK, 0.45),
				{
					Position = UDim2.fromOffset(18, 6),
					Size = UDim2.new(1, -160, 0, 32),
					TextXAlignment = Enum.TextXAlignment.Left,
				}
			)
			UiKit.text(row, pct(odds[id]), 20, UI.INK, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -18, 0, 6),
				Size = UDim2.fromOffset(130, 32),
				TextXAlignment = Enum.TextXAlignment.Right,
			})
		end
	end
end

local function albumFollower(body: ScrollingFrame)
	local p = ClientState.profile()
	line(body, "Your follower hops behind you at the Depot and rides with you.", 18, UI.INK_SOFT, 1)
	itemRow(body, 2, "No follower", "", if p.follower == "" then "CHOSEN" else "CHOOSE", UI.AQUA, function()
		ClientState.request("follower", "none")
	end, p.follower ~= "")
	for i, id in p.index do
		itemRow(
			body,
			2 + i,
			ClientState.critterName(id),
			`{ClientState.rarityName(id)} · rescued {p.rescues[id] or 0}`,
			if p.follower == id then "FOLLOWING" else "FOLLOW",
			UI.MINT,
			function()
				ClientState.request("follower", id)
			end,
			p.follower ~= id
		)
	end
	if #p.index == 0 then
		line(body, "Rescue a critter to choose a follower.", 20, nil, 3)
	end
end

-- LOCKER -------------------------------------------------------------------------------------------------

local ROLE = {
	stoker = { name = "Stoker", what = "stokes" },
	lamplighter = { name = "Lamplighter", what = "wisps puffed" },
	scout = { name = "Scout", what = "items loaded" },
	mender = { name = "Mender", what = "cans poured" },
}
local TIER = { "Bronze", "Silver", "Gold" }

local function lockerSlot(body: ScrollingFrame, slot: string)
	local p = ClientState.profile()
	local level = MetaRules.levelFor(p.xp)
	line(
		body,
		if slot == "livery"
			then "Your livery paints the train when you are the conductor."
			else "Your lamp colour is your own beam; everyone sees it.",
		18,
		UI.INK_SOFT,
		0
	)
	local order = 0
	for _, c in LanternConfig.COSMETICS do
		if c.slot ~= slot then
			continue
		end
		order += 1
		local equipped = (p :: any)[slot] == c.id
		local unlocked = MetaRules.isUnlocked(LanternProgress.config, p, c.id)
		local sub, label, colour, action = "", "", UI.GOLD, nil :: (() -> ())?
		if equipped then
			sub, label = "Equipped", "EQUIPPED"
		elseif unlocked then
			sub, label, action = "Yours", "EQUIP", function()
				ClientState.request("equip", c.id)
			end
		elseif c.price then
			sub, label = `{ClientState.short(c.price)} Tickets`, `BUY {ClientState.short(c.price)}`
			if p.coins >= c.price then
				action = function()
					ClientState.request("buyCosmetic", c.id)
				end
			end
		elseif c.grant == "album" then
			sub, label = "An album milestone", "ALBUM"
		elseif c.grant == "login" then
			sub, label = "A login track reward", "LOGIN"
		else
			sub, label = `Reach level {c.level} (you are {level})`, `LEVEL {c.level}`
		end
		local row = itemRow(body, order, c.name, sub, label, colour, action)
		local sw = new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -230, 0.5, 0),
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = ClientState.colour(c.colours[1]),
			Parent = row,
		}, {
			new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			new("UIStroke", { Color = UI.INK_SOFT, Thickness = 2 }),
		})
		if c.colours[2] then
			new("UIGradient", {
				Color = ColorSequence.new(ClientState.colour(c.colours[1]), ClientState.colour(c.colours[2])),
				Parent = sw,
			})
		end
	end
end

local function lockerBadge(body: ScrollingFrame)
	local p = ClientState.profile()
	line(body, "Badges show what you usually do. They never limit where you sit.", 18, UI.INK_SOFT, 0)
	itemRow(body, 1, "No badge", "", if p.badge == "" then "WORN" else "WEAR", UI.AQUA, function()
		ClientState.request("badge", "none")
	end, p.badge ~= "")
	for i, r in LanternConfig.ROLES do
		local tier = LanternProgress.tier(p, r.id)
		local n = p.stats[r.stat] or 0
		local nextNeed = r.tiers[tier + 1]
		local sub = `{TIER[tier] or "Not yet"} · {ClientState.short(n)}{if nextNeed
			then ` / {ClientState.short(nextNeed)}`
			else ""} {ROLE[r.id].what}`
		itemRow(body, 1 + i, ROLE[r.id].name, sub, if p.badge == r.id then "WORN" else "WEAR", UI.LILAC, function()
			ClientState.request("badge", r.id)
		end, tier >= 1 and p.badge ~= r.id)
	end
end

-- REWARDS -------------------------------------------------------------------------------------------------

local function slotText(s: LanternConfig.LoginSlot): string
	if s.critter then
		return ClientState.critterName(s.critter)
	elseif s.cosmetic then
		local c = LanternConfig.cosmetic(s.cosmetic)
		return (if c then c.name else s.cosmetic) .. (if s.tickets then ` +{s.tickets}` else "")
	end
	return `{s.tickets or 0} Tickets`
end

local function loginTrack(body: ScrollingFrame, track: string)
	local p = ClientState.profile()
	local l = p.login :: any
	local day = today()
	local days = if l[track] == LoginRules.periodOf(track, day) then l[track .. "Days"] else 0
	line(
		body,
		`Signed in on {days} day{if days == 1 then "" else "s"} this {track}. Earned rewards are never lost: unclaimed ones are paid at the end of the {track}.`,
		18,
		UI.INK_SOFT,
		1
	)
	local holder =
		new("Frame", { Size = UDim2.fromScale(1, 0), BackgroundTransparency = 1, LayoutOrder = 2, Parent = body })
	UiKit.grid(holder, 96, 176)
	local claimed = l[track .. "Claimed"] or 0
	local canClaim = LanternProgress.canClaimLogin(p, track, day)
	for i, s in LanternConfig.LOGIN[track] do
		local card = UiKit.card(holder, "reward", if s.cosmetic or s.critter then UI.GOLD else UI.CREAM)
		card.frame.LayoutOrder = i
		card.name.Text = `Day {s.count}`
		UiKit.text(card.icon, slotText(s), 16, UI.INK, { Size = UDim2.fromScale(1, 1), TextWrapped = true })
		if i <= claimed then
			UiKit.setPill(card, "DONE", UI.GREY)
		elseif i == claimed + 1 and canClaim then
			UiKit.setPill(card, "CLAIM", UI.LEAF)
			card.frame.Activated:Connect(function()
				ClientState.request("claimLogin", track)
			end)
		else
			UiKit.setPill(card, `{math.max(0, s.count - days)} more`, UI.GREY)
		end
	end
end

local function quests(body: ScrollingFrame)
	local p = ClientState.profile()
	local day = today()
	line(body, "Three quests a day. A finished quest you forget to claim is paid at the day's end.", 18, UI.INK_SOFT, 0)
	for i, q in MetaRules.questsFor(LanternConfig.QUESTS, day) do
		local progress = if p.quests.day == day then p.quests.progress[q.stat] or 0 else 0
		local done = p.quests.day == day and p.quests.claimed[q.id] == true
		local row = itemRow(
			body,
			i,
			q.label,
			`{math.min(progress, q.goal)} / {q.goal} · {q.reward} Tickets`,
			if done then "DONE" else "CLAIM",
			UI.LEAF,
			function()
				ClientState.request("claimQuest", q.id)
			end,
			not done and progress >= q.goal
		)
		UiKit.bar(
			row,
			{ Position = UDim2.new(0, 20, 1, -8), Size = UDim2.new(1, -260, 0, 6) },
			progress / q.goal,
			UI.GOLD
		)
	end
end

-- BOARD and SETTINGS ----------------------------------------------------------------------------------------

local function board(body: ScrollingFrame)
	local value = ReplicatedStorage:FindFirstChild("LanternBoards") :: StringValue?
	local data = (value and ClientState.json(value.Value)) or {}
	line(body, "Line of the Week: global top 10. Free runs never count.", 18, UI.INK_SOFT, 0)
	local order = 0
	for _, b in
		{
			{ key = "critters", title = "Most critters in one run", unit = "" },
			{ key = "dist", title = "Farthest", unit = " studs" },
		}
	do
		order += 1
		line(body, b.title, 26, nil, order)
		local list = data[b.key] or {}
		for i, e in list do
			order += 1
			itemRow(
				body,
				order,
				`{i}. {tostring(e.name or e[1] or "?")}`,
				`{ClientState.short(tonumber(e.value or e[2]) or 0)}{b.unit}`
			)
		end
		if #list == 0 then
			order += 1
			line(body, "No runs on the Line of the Week yet.", 20, UI.INK_SOFT, order)
		end
	end
end

local function settings(body: ScrollingFrame, redraw: () -> ())
	local s = ClientState.settings :: any
	local order = 0
	for _, key in { "music", "sfx" } do
		order += 1
		local row = itemRow(
			body,
			order,
			if key == "music" then "Music" else "Sound effects",
			`{math.floor(s[key] * 100 + 0.5)}%`
		)
		local function step(delta: number)
			ClientState.set(key, math.clamp(math.floor((s[key] + delta) * 10 + 0.5) / 10, 0, 1))
			redraw()
		end
		local minus = UiKit.button(row, "-", UI.INK_SOFT, "small", 64, function()
			step(-0.1)
		end)
		minus.AnchorPoint = Vector2.new(1, 0.5)
		minus.Position = UDim2.new(1, -110, 0.5, -3)
		local plus = UiKit.button(row, "+", UI.GOLD, "small", 64, function()
			step(0.1)
		end)
		plus.AnchorPoint = Vector2.new(1, 0.5)
		plus.Position = UDim2.new(1, -24, 0.5, -3)
		UiKit.bar(row, { Position = UDim2.new(0, 20, 1, -10), Size = UDim2.new(1, -260, 0, 6) }, s[key], UI.GOLD)
	end
	order += 1
	itemRow(
		body,
		order,
		"Calm night",
		"Softer music, a lighter vignette and bloom",
		if s.calm then "ON" else "OFF",
		if s.calm then UI.LEAF else UI.GREY,
		function()
			ClientState.set("calm", not s.calm)
			redraw()
		end
	)
	order += 1
	line(
		body,
		"Reduced Motion follows your Roblox settings: every animation stops when it is on.",
		18,
		UI.INK_SOFT,
		order
	)
end

local HOW = {
	"Ride the Lantern Express through Hollowmere with up to five friends.",
	"At each stop, carry coal, Parts, oil and critter crates to the train. A friend can help carry a crate.",
	"When the fog bell rings, hurry back and sit down. The fog only sends you back to the train.",
	"At night, sit at a lamp turret and shine the beam on the shadow wisps. They puff into sparkles.",
	"At the Depot, spend this run's Parts on the train and vote for the next line.",
	"Every critter you bring home stays in your album for good.",
	"Ping wheel: hold Q, the left bumper, or tap the ping button.",
}

-- Panels ---------------------------------------------------------------------------------------------------

local PANELS: { [string]: { tabs: { string }, draw: (body: ScrollingFrame, tab: string, redraw: () -> ()) -> () } } = {
	ALBUM = {
		tabs = { "GRID", "WHERE", "FOLLOWER" },
		draw = function(body, tab, redraw)
			if tab == "GRID" then
				albumGrid(body)
			elseif tab == "WHERE" then
				albumWhere(body, redraw)
			else
				albumFollower(body)
			end
		end,
	},
	LOCKER = {
		tabs = { "LIVERY", "LAMP", "BADGE" },
		draw = function(body, tab)
			if tab == "BADGE" then
				lockerBadge(body)
			else
				lockerSlot(body, string.lower(tab))
			end
		end,
	},
	REWARDS = {
		tabs = { "WEEKLY", "MONTHLY", "QUESTS" },
		draw = function(body, tab)
			if tab == "QUESTS" then
				quests(body)
			else
				loginTrack(body, if tab == "WEEKLY" then "week" else "month")
			end
		end,
	},
	BOARD = { tabs = { "THIS WEEK" }, draw = board },
	SETTINGS = {
		tabs = { "SOUND", "HOW TO PLAY" },
		draw = function(body, tab, redraw)
			if tab == "SOUND" then
				settings(body, redraw)
			else
				for i, s in HOW do
					local t = line(body, s, 20, nil, i)
					t.TextWrapped = true
					t.Size = UDim2.new(1, 0, 0, 56)
				end
			end
		end,
	},
}

local openPanel: UiKit.Panel? = nil
local redrawOpen: () -> () = function() end
local function open(name: string)
	local def = PANELS[name]
	local key = string.upper(string.sub(name, 1, 1)) .. string.lower(string.sub(name, 2))
	local p = UiKit.panel(gui, name, ACCENT[key] or UI.LILAC)
	openPanel = p
	p.onClose = function()
		if openPanel == p then
			openPanel = nil
		end
	end
	local function redraw()
		if p.frame.Parent then
			clear(p.body)
			def.draw(p.body, p.tab or def.tabs[1], redraw)
		end
	end
	redrawOpen = redraw
	UiKit.tabs(p, def.tabs, function()
		redraw()
	end)
	p.setTab(def.tabs[1])
	UiKit.selectFirst(p.frame)
end
-- Redraw the open panel when the save changes (a claim, a purchase, a rescue).
player:GetAttributeChangedSignal("Profile"):Connect(function()
	if openPanel and openPanel.frame.Parent then
		redrawOpen()
	end
end)

-- Start menu -----------------------------------------------------------------------------------------------

local hub = TrackRules.at(TrackRules.build(LanternConfig.TRACKS.forest.points, true), 0)
local hubAt = ClientState.v3(hub) + Vector3.new(0, 6, 0)
local function orbitPose(t: number): CFrame
	local a = if ClientState.still() then 0.6 else t * 0.05 -- a slow orbit, still under Reduced Motion
	return CFrame.lookAt(hubAt + Vector3.new(math.cos(a) * 80, 28, math.sin(a) * 80), hubAt)
end

local playing = false
local menu
local orbit: RBXScriptConnection? = RunService.RenderStepped:Connect(function()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = orbitPose(os.clock())
end)

local function play()
	if playing then
		return
	end
	playing = true
	UiKit.setEnabled(menu.play, false)
	local ok = ClientState.request("play")
	UiKit.setEnabled(menu.play, true)
	if not ok then
		playing = false
		return
	end
	if orbit then
		orbit:Disconnect()
		orbit = nil
	end
	menu.frame.Visible = false
	if openPanel then
		openPanel.close()
	end
	ClientState.setMenu(false)
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local goal = if root then root.CFrame * CFrame.new(0, 6, 14) else camera.CFrame
	UiKit.flyTo(
		camera,
		camera.CFrame,
		CFrame.lookAt(goal.Position, if root then root.Position else goal.Position),
		1.6,
		function()
			camera.CameraType = Enum.CameraType.Custom
			ClientState.sound("whistle", 0.6)
		end
	)
end

local function side(label: string, icon: string)
	return {
		icon = icon,
		label = label,
		onClick = function()
			open(label)
		end,
	}
end
menu = UiKit.startMenu(gui, play, {
	side("ALBUM", "album"),
	side("LOCKER", "locker"),
	side("REWARDS", "rewards"),
	side("BOARD", "board"),
	side("SETTINGS", "settings"),
})

-- The showcase: the Ember Kit first, then the player's album (or the commons to find).
local function showcase()
	local p = ClientState.profile()
	local list = { "emberkit" }
	for _, id in p.index do
		if id ~= "emberkit" then
			table.insert(list, id)
		end
	end
	if #list < 3 then
		for _, id in { "mossmouse", "puddlefrog", "fogpup" } do
			if not table.find(list, id) then
				table.insert(list, id)
			end
		end
	end
	menu.showcase(list)
end

local function badges()
	local p = ClientState.profile()
	local day = today()
	local n = LanternProgress.claimable(p, day)
	for _, q in MetaRules.questsFor(LanternConfig.QUESTS, day) do
		if p.quests.day == day and not p.quests.claimed[q.id] and (p.quests.progress[q.stat] or 0) >= q.goal then
			n += 1
		end
	end
	menu.setBadge("REWARDS", if n > 0 then n else nil)
end
-- In a run: MENU (bottom left, above PING) opens the same five panels.
local menuButton = UiKit.button(gui, "MENU", UI.INK_SOFT, "medium", 150, function()
	local sheet = UiKit.modal(gui, "MENU", UI.INK_SOFT, 640, 230)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1, Parent = sheet.body }, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, name in { "ALBUM", "LOCKER", "REWARDS", "BOARD", "SETTINGS" } do
		local key = string.upper(string.sub(name, 1, 1)) .. string.lower(string.sub(name, 2))
		UiKit.iconButton(row, string.lower(name), name, ACCENT[key] or UI.LILAC, function()
			sheet.close()
			open(name)
		end).LayoutOrder =
			i
	end
	UiKit.selectFirst(sheet.frame)
end)
menuButton.AnchorPoint = Vector2.new(0, 1)
menuButton.Position = UDim2.new(0, 24, 1, -320)
menuButton.Visible = false
ClientState.MenuChanged:Connect(function(isOpen: boolean)
	menuButton.Visible = not isOpen
end)

showcase()
badges()
local lastIndex = #ClientState.profile().index
player:GetAttributeChangedSignal("Profile"):Connect(function()
	badges()
	local n = #ClientState.profile().index
	if n ~= lastIndex then
		lastIndex = n
		showcase()
	end
end)
UiKit.selectFirst(menu.frame)

-- Saving offline: say so once, kindly (the kit's newer-save guard or a DataStore outage).
task.delay(3, function()
	if player:GetAttribute("ProfileOnline") == false then
		ClientState.toast(
			"Saving is offline on this server: progress here lasts this session only.",
			"notice",
			UI.CORAL
		)
	end
end)
