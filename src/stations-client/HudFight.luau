--!strict
-- Fight feel: the team plates, the press cards for power moves, the hit numbers, the music and the camera.
-- One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BattleRules = require(Shared:WaitForChild("BattleRules"))
local FightFx = require(Shared:WaitForChild("FightFx"))
local LevelRules = require(Shared:WaitForChild("LevelRules"))
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local WaveRuns = require(Shared:WaitForChild("WaveRuns"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local Format = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Format"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Style = require(script.Parent:WaitForChild("Style"))
local remotes = ReplicatedStorage:WaitForChild("StationsRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local player = game:GetService("Players").LocalPlayer
local App: any = require(script.Parent:WaitForChild("HudApp"))
local S = App.S
local C = App.C
local N = Style.N
local result = App.result
local screen = App.screen
local root = App.root
local uiScale = App.uiScale
local Hud = App.Hud
local coinsText = App.coinsText
local plates = App.plates

-- Fight feel (decision 0097) ---------------------------------------------------------------------------
-- Words that pop over the fight (PERFECT!, a combo, BLOCKED!, a power attack's name), a flash and a
-- shake, the boss's bar across the top, the shield button and the warnings before enemy power attacks,
-- and the fight's music. Display only: the server decides, the shield button only asks.
do
	local POWER_MOVES: { [string]: string } = {
		lion = "KING'S ROAR",
		jackal = "PACK AMBUSH",
		tortoise = "SHELL SLAM",
		meerkat = "BURROW BLITZ",
		cheetah = "LIGHTNING DASH",
		rhino = "HORN CHARGE",
		flamingo = "PINK CYCLONE",
		giraffe = "SKY KICK",
		elephant = "EARTHQUAKE STOMP",
	}
	-- Roblox-licensed audio (docs/assets/register.md): APM music and stings, Pro Sound Effects
	local AUDIO = {
		fight = "rbxassetid://9048541013",
		boss = "rbxassetid://1848096079",
		win = "rbxassetid://1836473422",
		lose = "rbxassetid://9039598193",
		roar = "rbxassetid://9113980319",
		whoosh = "rbxassetid://9114373663",
		shield = "rbxassetid://9125920594",
		gong = "rbxassetid://9125585534",
	}
	local SoundService = game:GetService("SoundService")
	local audio: { [string]: Sound } = {}
	local function sound(name: string, volume: number?): Sound
		local s = audio[name]
		if s == nil then
			s = Instance.new("Sound")
			local made = s :: Sound
			made.SoundId = AUDIO[name]
			made.Parent = SoundService
			audio[name] = made
		end
		local out = s :: Sound
		out.Volume = volume or 0.6
		return out
	end
	local function fxSound(name: string, volume: number?)
		sound(name, volume):Play()
	end

	local track: Sound? = nil
	S.music = function(kind: string?)
		local old = track
		if old then
			local fade = TweenService:Create(old, TweenInfo.new(0.8), { Volume = 0 })
			fade.Completed:Once(function()
				if track ~= old then
					old:Stop()
				end
			end)
			fade:Play()
		end
		track = nil
		if kind == "fight" or kind == "boss" then
			local s = sound(kind, 0.25)
			s.Looped = true
			s.TimePosition = 0
			s:Play()
			track = s
			fxSound("gong", 0.45)
		elseif kind == "win" or kind == "lose" then
			fxSound(kind, 0.7)
		end
	end

	local function jolt(strength: number)
		player:SetAttribute("CamShake", strength) -- ArenaCamera reads these
		player:SetAttribute("CamShakeAt", os.clock())
	end

	local whiteout = Instance.new("Frame")
	whiteout.Name = "Flash"
	whiteout.Size, whiteout.BackgroundColor3, whiteout.BackgroundTransparency =
		UDim2.fromScale(1, 1), Color3.new(1, 1, 1), 1
	whiteout.BorderSizePixel, whiteout.ZIndex, whiteout.Active = 0, 9, false
	whiteout.Parent = root
	local function flashScreen(strength: number)
		whiteout.BackgroundTransparency = 1 - 0.5 * strength
		TweenService:Create(whiteout, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	end

	local function bigWords(at: UDim2, size: number, stroke: Color3): (TextLabel, UIStroke, UIScale)
		local t = Style.text(root, "", size, C.gold, UDim2.new(1, 0, 0, size + 20))
		t.AnchorPoint, t.Position, t.TextTransparency = Vector2.new(0.5, 0.5), at, 1
		t.TextXAlignment, t.ZIndex = Enum.TextXAlignment.Center, 8
		local edge = Instance.new("UIStroke")
		edge.Thickness, edge.Color, edge.Transparency = 5, stroke, 1
		edge.Parent = t
		local scale = Instance.new("UIScale")
		scale.Parent = t
		return t, edge, scale
	end
	local popText, popEdge, popScale = bigWords(UDim2.fromScale(0.5, 0.36), 60, C.ink)
	local moveText, moveEdge, moveScale = bigWords(UDim2.fromScale(0.5, 0.25), 42, C.bad)
	moveText.TextColor3 = Color3.new(1, 1, 1)
	local popped, moved = 0, 0
	local function popWords(words: string, colour: Color3, big: number)
		popped += 1
		local mine = popped
		popText.Text, popText.TextColor3 = words, colour
		popText.TextTransparency, popEdge.Transparency, popScale.Scale = 0, 0, 0.3
		TweenService
			:Create(popScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = big })
			:Play()
		task.delay(0.9, function()
			if popped == mine then
				TweenService:Create(popText, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
				TweenService:Create(popEdge, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			end
		end)
	end
	S.moveName = function(species: string)
		local words = POWER_MOVES[species]
		if words == nil then
			return
		end
		moved += 1
		local mine = moved
		moveText.Text = `{words}!`
		moveText.TextTransparency, moveEdge.Transparency, moveScale.Scale = 0, 0, 1.6
		moveText.Position = UDim2.new(0.5, -40, 0.25, 0)
		local snap = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(moveScale, snap, { Scale = 1 }):Play()
		TweenService:Create(moveText, snap, { Position = UDim2.fromScale(0.5, 0.25) }):Play()
		fxSound("whoosh", 0.5)
		task.delay(1.1, function()
			if moved == mine then
				TweenService:Create(moveText, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				TweenService:Create(moveEdge, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end)
	end
	player:GetAttributeChangedSignal("FxPopAt"):Connect(function()
		local words, kind = player:GetAttribute("FxPop"), player:GetAttribute("FxPopKind")
		if type(words) ~= "string" then
			return
		elseif kind == "shield" then
			popWords(words, C.info, 1)
		elseif kind == "big" then
			popWords(words, C.bad, 1.35)
			flashScreen(1)
			jolt(1)
			Style.sound("claim")
		else
			popWords(words, C.gold, 1.15)
			flashScreen(0.6)
			jolt(0.6)
			Style.sound("claim")
		end
	end)

	-- the boss's bar, under the stage strip: it slams in as the dragon lands. Marks at each third.
	local bossBar = Style.glass(root, UDim2.fromOffset(520, 40), 12)
	local bossEdge = bossBar:FindFirstChildOfClass("UIStroke") :: UIStroke
	bossEdge.Color = N.bad
	bossBar.AnchorPoint, bossBar.Position, bossBar.Visible, bossBar.ZIndex =
		Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 80), false, 6
	local bossName = Style.text(bossBar, "", 15, Color3.fromRGB(255, 179, 198), UDim2.fromOffset(172, 40))
	bossName.Position, bossName.TextWrapped, bossName.TextTruncate =
		UDim2.fromOffset(14, 0), false, Enum.TextTruncate.AtEnd
	local bossHp, fillBoss = Style.track(bossBar, UDim2.new(1, -262, 0, 14), C.bad)
	bossHp.Position = UDim2.fromOffset(192, 13)
	for third = 1, 2 do
		local mark = Style.frame(bossHp, UDim2.new(0, 2, 1, 0), N.glass)
		mark.Position, mark.ZIndex = UDim2.fromScale(third / 3, 0), 3
	end
	local bossPct = Style.text(bossBar, "", 14, N.text, UDim2.fromOffset(52, 40))
	bossPct.AnchorPoint, bossPct.Position, bossPct.TextXAlignment =
		Vector2.new(1, 0), UDim2.new(1, -12, 0, 0), Enum.TextXAlignment.Right
	local function setBossHp(share: number)
		fillBoss(share)
		bossPct.Text = `{math.ceil(share * 100)}%`
	end
	local bossScale = Instance.new("UIScale")
	bossScale.Parent = bossBar
	local bossOf: Model? = nil

	-- the shield (key F): a round glass button, bottom left, with its cooldown drawn round it; its edge
	-- flashes gold while an enemy power attack is coming
	local tellUntil = 0
	local shieldRing, setShield = Style.pie(root, 86, N.edge, N.key)
	shieldRing.Name, shieldRing.Visible, shieldRing.ZIndex = "Shield", false, 4
	shieldRing.AnchorPoint, shieldRing.Position = Vector2.new(0, 1), UDim2.new(0, 34, 1, -44)
	local shieldButton = Instance.new("TextButton")
	shieldButton.Text, shieldButton.AutoButtonColor, shieldButton.BorderSizePixel = "", false, 0
	shieldButton.AnchorPoint, shieldButton.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	shieldButton.Size, shieldButton.BackgroundColor3, shieldButton.ZIndex = UDim2.fromOffset(72, 72), N.glass, 2
	Style.round(shieldButton, 36)
	local shieldEdge = Style.stroke(shieldButton, N.edge, 2)
	shieldButton.Parent = shieldRing
	local shieldIcon = Instance.new("ImageLabel")
	shieldIcon.BackgroundTransparency, shieldIcon.Image = 1, Style.ICONS.shield -- STATION-150
	shieldIcon.AnchorPoint, shieldIcon.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	shieldIcon.Size, shieldIcon.ZIndex = UDim2.fromScale(0.66, 0.66), 3
	shieldIcon.Parent = shieldButton
	local shieldKey = Style.key(shieldRing, "F", true)
	shieldKey.AnchorPoint, shieldKey.Position = Vector2.new(1, 1), UDim2.new(1, 4, 1, 2)
	local shieldNote = Style.small(shieldRing, "", 12, N.muted, UDim2.fromOffset(130, 16))
	shieldNote.AnchorPoint, shieldNote.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 1, 6)
	shieldNote.TextXAlignment = Enum.TextXAlignment.Center
	Style.stroke(shieldNote, Color3.fromRGB(42, 22, 64), 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	local shieldLook = ""
	local function raiseShield()
		if not shieldRing.Visible then
			return
		end
		local ready = player:GetAttribute("ShieldReady")
		if type(ready) == "number" and Workspace:GetServerTimeNow() < ready then
			Style.sound("denied")
			return
		end
		local ok, code = request:InvokeServer("shield")
		if ok then
			fxSound("shield", 0.5)
		elseif code == "shield_wait" then
			Style.sound("denied")
		end
	end
	shieldButton.Activated:Connect(raiseShield)
	UserInputService.InputBegan:Connect(function(input, used)
		if not used and input.KeyCode == Enum.KeyCode.F then
			raiseShield()
		end
	end)
	-- the bubble round the team while the shield is up
	player:GetAttributeChangedSignal("ShieldAt"):Connect(function()
		local at = player:GetAttribute("ShieldAt")
		if type(at) ~= "number" then
			return
		end
		task.delay(math.max(0, at - Workspace:GetServerTimeNow()), function()
			local folder = Workspace:FindFirstChild(player:GetAttribute("FightFolder") or `WaveShow{player.UserId}`)
			for _, m in if folder then folder:GetChildren() else {} do
				local hp = m:GetAttribute("Hp")
				if m:IsA("Model") and m:GetAttribute("Side") == 1 and type(hp) == "number" and hp > 0 then
					local cf, size = m:GetBoundingBox()
					local ball = Instance.new("Part")
					ball.Shape, ball.Material, ball.Color = Enum.PartType.Ball, Enum.Material.ForceField, C.info
					ball.Size, ball.CFrame = Vector3.one * math.max(size.X, size.Y, size.Z) * 1.1, cf
					ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.CastShadow =
						true, false, false, false, false
					ball.Parent = Workspace
					TweenService:Create(ball, TweenInfo.new(BattleRules.SHIELD_SECONDS + 0.3), { Transparency = 1 })
						:Play()
					Debris:AddItem(ball, BattleRules.SHIELD_SECONDS + 0.4)
				end
			end
		end)
	end)

	-- An enemy power attack is coming (the server sets TellAt, when it lands): a disc under the attacker,
	-- orange while it is too soon to shield, red and closing while a shield now would be up when it lands.
	local function warnOf(m: Model)
		local at = m:GetAttribute("TellAt")
		if type(at) ~= "number" then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local deadline = at - FightFx.TAP_AHEAD - now -- the last moment a press still raises it in time
		local opens = deadline - BattleRules.SHIELD_SECONDS + 0.1
		if deadline <= 0 then
			return
		end
		local cf, size = m:GetBoundingBox()
		local r = math.max(size.X, size.Z) * 0.8
		local disc = Instance.new("Part")
		disc.Shape, disc.Material, disc.Color, disc.Transparency =
			Enum.PartType.Cylinder, Enum.Material.Neon, C.accent, 0.35
		disc.Size = Vector3.new(0.2, r * 2.4, r * 2.4)
		disc.CFrame = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2 + 0.3, cf.Position.Z)
			* CFrame.Angles(0, 0, math.pi / 2)
		disc.Anchored, disc.CanCollide, disc.CanQuery, disc.CanTouch, disc.CastShadow = true, false, false, false, false
		disc.Parent = Workspace
		TweenService:Create(disc, TweenInfo.new(deadline, Enum.EasingStyle.Linear), { Size = Vector3.new(0.2, r, r) })
			:Play()
		task.delay(math.max(0, opens), function()
			disc.Color = C.bad
			tellUntil = os.clock() + math.min(deadline, BattleRules.SHIELD_SECONDS)
		end)
		task.delay(deadline, function()
			disc.Color = C.night
			TweenService
				:Create(disc, TweenInfo.new(math.max(0.1, at - Workspace:GetServerTimeNow())), { Transparency = 1 })
				:Play()
		end)
		Debris:AddItem(disc, at - now + 0.5)
	end

	-- knockouts (decision 0101): a counter that pops, and coins out of each fallen foe to the counter
	local koText, koEdge, koScale = bigWords(UDim2.new(0.5, 0, 0, 120), 34, C.ink)
	koText.TextColor3 = C.gold
	-- in the top right corner, out of the fight's way
	koText.AnchorPoint, koText.Position, koText.Size =
		Vector2.new(1, 0), UDim2.new(1, -22, 0, 108), UDim2.fromOffset(220, 54)
	koText.TextXAlignment = Enum.TextXAlignment.Right
	local kos = 0
	local fallen: { [Model]: boolean } = {}
	local function knockout(m: Model)
		kos += 1
		koText.Text = `{kos} KO!`
		koText.TextTransparency, koEdge.Transparency, koScale.Scale = 0, 0, 1.4
		TweenService:Create(koScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		local camera = Workspace.CurrentCamera
		local at, seen = camera:WorldToViewportPoint(m:GetPivot().Position)
		if not seen then
			return
		end
		local to = coinsText.AbsolutePosition + Vector2.new(0, coinsText.AbsoluteSize.Y / 2)
		for i = 1, 3 do
			local coin = Instance.new("Frame")
			coin.Size, coin.AnchorPoint, coin.BackgroundColor3 = UDim2.fromOffset(14, 14), Vector2.new(0.5, 0.5), C.gold
			coin.ZIndex, coin.Position = 12, UDim2.fromOffset(at.X + math.random(-16, 16), at.Y + math.random(-16, 4))
			Style.round(coin, 7)
			Style.stroke(coin, C.ink, 2)
			coin.Parent = screen
			local fly = TweenService:Create(
				coin,
				TweenInfo.new(0.6 + i * 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromOffset(to.X, to.Y), Size = UDim2.fromOffset(8, 8) }
			)
			fly.Completed:Once(function()
				coin:Destroy()
			end)
			fly:Play()
		end
	end
	-- the power bar: each side's power still standing (its fighters' power x their HP left), over the plates
	local tug = Instance.new("Frame")
	tug.Name, tug.BackgroundTransparency, tug.LayoutOrder, tug.Visible = "PowerBar", 1, 0, false
	tug.Size, tug.ZIndex = UDim2.fromOffset(540, 16), 6
	tug.Parent = plates
	local tugBar = Style.frame(tug, UDim2.fromOffset(300, 10), C.bad)
	tugBar.AnchorPoint, tugBar.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	Style.round(tugBar, 5)
	Style.stroke(tugBar, Color3.fromRGB(27, 16, 48), 2)
	local ourSide = Style.frame(tugBar, UDim2.fromScale(0.5, 1), N.good)
	Style.round(ourSide, 5)
	local tugLabel = Style.small(tug, "", 13, N.text, UDim2.fromOffset(112, 16))
	tugLabel.TextXAlignment = Enum.TextXAlignment.Right
	local tugThem = Style.small(tug, "", 13, N.text, UDim2.fromOffset(112, 16))
	tugThem.AnchorPoint, tugThem.Position = Vector2.new(1, 0), UDim2.fromScale(1, 0)
	for _, words in { tugLabel, tugThem } do
		Style.stroke(words, Color3.fromRGB(42, 22, 64), 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	end
	local powerCache: { [Model]: number } = {}
	local function powerOf(m: Model, side: number): number
		local got = powerCache[m]
		if got == nil then
			local stats = {}
			for _, stat in StationConfig.STATS do
				local x = m:GetAttribute(stat)
				stats[stat] = if type(x) == "number" then x else 0
			end
			local id = m:GetAttribute(if side == 1 then "Species" else "FoeId")
			got = if type(id) == "string" then BattleRules.powerOf({ s = id, stats = stats :: any }, side) else 0
			powerCache[m] = got
		end
		return got :: number
	end

	local warned: { [Model]: boolean } = {}
	-- Every tick of the fight (from the plates' loop): hook new enemies' warnings, the boss's bar, the
	-- shield button, and the music building as the enemies fall.
	local docked = false
	S.fightTick = function(folder: Instance?, showing: boolean)
		shieldRing.Visible = showing and not result.Visible
		if showing ~= docked then -- the ranch's dock, goal and To battle make way for the fight (decision 0114)
			docked = showing
			S.fighting = showing
			screen:SetAttribute("Night", showing) -- messages turn to glass in a fight (Style.toast)
			-- nobody walks in a fight: on a phone the walking stick and jump make way for the shield and the presses
			game:GetService("GuiService").TouchControlsEnabled = not showing
			Hud.navShown()
		end
		-- knockouts and the power bar
		local us, them = 0, 0
		for _, m in if folder then folder:GetChildren() else {} do
			local side, hp, max = m:GetAttribute("Side"), m:GetAttribute("Hp"), m:GetAttribute("MaxHp")
			if m:IsA("Model") and type(side) == "number" and type(hp) == "number" and type(max) == "number" then
				local left = math.max(0, hp) / math.max(1, max)
				if side == 1 then
					us += powerOf(m, 1) * left
				else
					them += powerOf(m, 2) * left
					if hp <= 0 and not fallen[m] then
						fallen[m] = true
						knockout(m)
					end
				end
			end
		end
		tug.Visible = showing and us + them > 0 and not result.Visible
		if us + them > 0 then
			ourSide.Size = UDim2.fromScale(math.clamp(us / (us + them), 0.02, 0.98), 1)
			tugLabel.Text, tugThem.Text =
				`You {Format.short(math.floor(us))}`, `Legion {Format.short(math.floor(them))}`
		end
		if not showing and kos > 0 then -- the fight is over: the count starts again next time
			kos = 0
			koText.TextTransparency, koEdge.Transparency = 1, 1
			table.clear(fallen)
			table.clear(powerCache)
		end
		local boss: Model? = nil
		local left, total = 0, 0
		for _, m in if folder then folder:GetChildren() else {} do
			if m:IsA("Model") and m:GetAttribute("Side") == 2 then
				if not warned[m] then
					warned[m] = true
					m:GetAttributeChangedSignal("TellAt"):Connect(function()
						warnOf(m)
					end)
					m.Destroying:Connect(function()
						warned[m] = nil
					end)
				end
				local hp, max = m:GetAttribute("Hp"), m:GetAttribute("MaxHp")
				if type(hp) == "number" and type(max) == "number" then
					left += math.max(0, hp)
					total += max
				end
				if m:GetAttribute("Boss") == true then
					boss = m
				end
			end
		end
		if track and total > 0 then
			track.Volume = 0.25 + 0.25 * (1 - left / total)
		end
		-- the boss
		if boss ~= bossOf then
			bossOf = boss
			bossBar.Visible = false
			if boss then
				local landAt = boss:GetAttribute("LandAt")
				task.delay(
					if type(landAt) == "number" then math.max(0, landAt - Workspace:GetServerTimeNow()) else 0,
					function()
						if bossOf ~= boss then
							return
						end
						bossName.Text = string.upper(tostring(boss:GetAttribute("FoeName") or "Boss"))
						bossBar.Visible, bossScale.Scale = true, 1.8
						TweenService
							:Create(bossScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								Scale = 1,
							})
							:Play()
						fxSound("roar", 0.8)
						jolt(1)
					end
				)
			end
		end
		if boss then
			local hp, max = boss:GetAttribute("Hp"), boss:GetAttribute("MaxHp")
			if type(hp) == "number" and type(max) == "number" then
				setBossHp(math.max(0, hp) / math.max(1, max))
			end
		end
		-- the stage (decision 0106): its number and name and ten pips (cleared, this wave, its boss), at the
		-- top, under the boss's bar once there is one. Made on first use and found by name: the HUD's main
		-- chunk is close to Luau's 200 locals.
		local strip = root:FindFirstChild("StageStrip") :: Frame?
		if strip == nil then
			local made = Style.glass(root, UDim2.fromOffset(380, 58), 14)
			made.Name, made.AnchorPoint, made.ZIndex = "StageStrip", Vector2.new(0.5, 0), 6
			local title = Style.text(made, "", 15, N.text, UDim2.new(1, -20, 0, 20))
			title.Name, title.Position, title.TextXAlignment =
				"Title", UDim2.fromOffset(10, 5), Enum.TextXAlignment.Center
			local row = Instance.new("Frame")
			row.Name, row.BackgroundTransparency = "Pips", 1
			row.Size, row.Position = UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 29)
			row.Parent = made
			Style.list(row, 4, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
			for i = 1, LevelRules.STAGE do
				local pip = Style.frame(row, UDim2.fromOffset(if i == LevelRules.STAGE then 46 else 28, 22), N.key)
				pip.Name, pip.LayoutOrder = `Pip{i}`, i
				Style.round(pip, 7)
				Style.stroke(pip, N.lilac, 2)
				local label = Style.text(pip, "", 12, N.text, UDim2.fromScale(1, 1))
				label.Name, label.TextXAlignment = "Label", Enum.TextXAlignment.Center
			end
			strip = made
		end
		local bar = strip :: Frame
		local fought = player:GetAttribute("FightWave")
		bar.Visible = showing and type(fought) == "number" and not result.Visible
		bar.Position = UDim2.new(0.5, 0, 0, 14)
		bossBar.Position = UDim2.new(0.5, 0, 0, if bar.Visible then 80 else 14)
		if type(fought) == "number" and bar:GetAttribute("Wave") ~= fought then
			bar:SetAttribute("Wave", fought)
			local st = LevelRules.stage(fought)
			local title = bar:FindFirstChild("Title") :: TextLabel
			title.Text = `STAGE {st.n} · {string.upper(st.name)} · WAVE {fought}`
			for i = 1, LevelRules.STAGE do
				local pip = (bar:FindFirstChild("Pips") :: Frame):FindFirstChild(`Pip{i}`) :: Frame
				local label = pip:FindFirstChild("Label") :: TextLabel
				local w, isBoss = st.first + i - 1, i == LevelRules.STAGE
				-- cleared green, this wave gold (the one loud colour), the boss berry, the rest dark
				pip.BackgroundColor3 = if w < fought
					then Color3.fromRGB(60, 154, 46)
					elseif w == fought then N.gold
					elseif isBoss then Color3.fromRGB(200, 55, 106)
					else N.key
				local edge = pip:FindFirstChildOfClass("UIStroke")
				if edge then
					edge.Color = if w < fought
						then Color3.fromRGB(158, 224, 142)
						elseif w == fought then Color3.fromRGB(255, 233, 168)
						elseif isBoss then Color3.fromRGB(255, 179, 198)
						else N.edge
				end
				label.Text = if isBoss then "BOSS" elseif w <= fought then tostring(w) else ""
				label.TextColor3 = if w == fought then Color3.fromRGB(42, 22, 64) else N.text
			end
		end
		-- the shield button: cooling down, warning (flashing), or ready
		local ready = player:GetAttribute("ShieldReady")
		local wait = if type(ready) == "number" then ready - Workspace:GetServerTimeNow() else 0
		local look = if wait > 0
			then `wait {math.ceil(wait)}`
			elseif os.clock() < tellUntil then (if math.floor(os.clock() * 6) % 2 == 0 then "warn" else "warn2")
			else "ready"
		setShield(if wait > 0 then 1 - wait / BattleRules.SHIELD_COOLDOWN else 1)
		if look ~= shieldLook then
			shieldLook = look
			shieldNote.Text = if wait > 0
				then `Shield in {math.ceil(wait)}s`
				elseif look == "ready" then "Shield"
				else "Shield now!"
			shieldIcon.ImageTransparency = if wait > 0 then 0.6 else 0
			shieldEdge.Color = if look == "warn" then N.gold elseif look == "warn2" then N.lilac else N.edge
			shieldKey.BackgroundColor3 = if look == "warn" or look == "warn2" then N.gold else N.key
			shieldKey.TextColor3 = if look == "warn" or look == "warn2" then Color3.fromRGB(42, 22, 64) else N.text
		end
		-- the run, top left: wins in a row, the pot and the boons it has stacked
		local run = S.run
		local box = root:FindFirstChild("RunInfo") :: Frame?
		if run and box == nil then
			local made = Instance.new("Frame")
			made.Name, made.BackgroundTransparency = "RunInfo", 1
			made.Position, made.Size, made.ZIndex = UDim2.fromOffset(16, 84), UDim2.fromOffset(420, 80), 4
			Style.list(made, 7)
			made.Parent = root
			box = made
		end
		if box then
			box.Visible = showing and run ~= nil and not result.Visible
			if run and box:GetAttribute("At") ~= run.at then
				box:SetAttribute("At", run.at)
				Style.clear(box)
				local line = Style.glass(box, UDim2.fromOffset(0, 32), 12)
				line.AutomaticSize = Enum.AutomaticSize.X
				local words = Style.text(
					line,
					`{run.streak} {if run.streak == 1 then "win" else "wins in a row"}{if run.pot > 0
						then `  ·  {Format.commas(run.pot)} in the pot`
						else ""}`,
					14,
					N.text,
					UDim2.fromOffset(0, 32)
				)
				words.AutomaticSize, words.TextWrapped = Enum.AutomaticSize.X, false
				Style.pad(words, 0)
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 13), UDim.new(0, 13)
				pad.Parent = line
				local chips = Instance.new("Frame")
				chips.BackgroundTransparency, chips.Size, chips.LayoutOrder = 1, UDim2.new(1, 0, 0, 26), 2
				Style.list(chips, 6, true, true)
				chips.Parent = box
				local counts, order = {}, {}
				for _, id in run.boons do
					if counts[id] == nil then
						table.insert(order, id)
					end
					counts[id] = (counts[id] or 0) + 1
				end
				for _, id in order do
					local boon = WaveRuns.boon(id)
					local chip = Style.chip(chips, `{if boon then boon.name else id}  x{counts[id]}`, N.glass, N.text)
					chip.TextSize, chip.BackgroundTransparency = 13, 0.1
					local edge = chip:FindFirstChildOfClass("UIStroke") :: UIStroke
					edge.Color = N.edge
				end
			end
		end
	end
end

-- Power attacks in a fight (decision 0092): a plate for each of the team's animals, bottom right, with
-- its name, its number key and its mana (the power meter), nothing else. A full meter lights the plate and
-- pops its quick press up on the screen (decision 0106, BattleRules.pressOf): the ring closes on its mark,
-- the needle swings through the gold, the chain's 1-2-3 are tapped in order, the mash counts presses. Tap
-- the pop-up, the plate or the key. The server decides: a refused tap does nothing.

type Plate = {
	button: TextButton,
	power: (number) -> (),
	holder: Frame,
	health: (number) -> (),
	fill: Frame, -- the mana bar's
	key: TextLabel, -- the press's key, shown while the meter is full
	full: boolean,
	press: string,
	label: string, -- the animal's name
	fullAt: number, -- os.clock() when this client saw the meter fill
	close: number, -- seconds after that when the press is due (the ring's close, the needle's first crossing)
	sent: boolean, -- its power tap is on its way
	presses: number, -- a mash's count
	mashUntil: number,
	-- its pop-up while the meter is full, and the parts of it that change
	card: TextButton?,
	hand: Frame?, -- the needle's
	count: TextLabel?, -- the mash's presses
	marks: { TextButton }, -- the chain's 1-2-3
	marked: number,
	parts: any, -- its pop-up's moving parts (PressPops.card)
	holdAt: number?, -- the ring: os.clock() when the hold began
	model: Model?, -- the animal on the field, which its pop-up stands over (PressPops)
	keys: { Enum.KeyCode }?, -- its card's keys (PressPops.claim)
}
local plateOf: { [number]: Plate } = {}
-- Quick presses and clicks (decision 0106) keep their functions here, set in the block below: the HUD's
-- main chunk is close to Luau's 200 locals.
local Press: {
	SWING: number, -- how far the needle swings from the middle of its bar (1 wide)
	tap: (slot: number) -> (), -- the plate, its pop-up or its key is pressed
	hold: (slot: number, down: boolean) -> (), -- the ring's key or pop-up pressed or let go
	on: (p: Plate, slot: number) -> (), -- its meter has just filled
	off: (p: Plate) -> (), -- it is empty again, or gone
	catcher: TextButton, -- the click layer
	pops: any, -- PressPops: stands the pop-ups over their animals (decision 0109)
} =
	{ SWING = 0.46 } :: any

local function firePower(slot: number, presses: number?)
	local p = plateOf[slot]
	if p == nil or not p.full or p.sent then
		return
	end
	p.sent = true
	local failed = presses == BattleRules.FAILED
	if p.card then -- done: it bursts (red when messed up) and is gone at once, never waiting for the attack to play
		Press.pops.fired(p.card, p.card:GetAttribute("Hot") == true, failed)
		p.card = nil
	end
	local ok, code = request:InvokeServer("power", slot, presses)
	for _ = 1, 20 do -- turned down (no foe between rushes, a moment early): sent again, so a press is never lost
		if ok or failed or code == "no_fight" or not p.full then
			break
		end
		task.wait(0.25)
		ok, code = request:InvokeServer("power", slot, presses)
	end
	if ok then
		Style.sound("claim")
		if S.fired and not failed then -- the intro's lessons: this kind of press was done
			S.fired[p.press] = true
		end
	else
		p.sent = false
		if p.full and not failed then -- turned down for good while the meter is still full: a fresh card to press again
			Press.on(p, slot)
		end
	end
end

local plateRow = Instance.new("Frame")
plateRow.Name, plateRow.BackgroundTransparency, plateRow.LayoutOrder = "Row", 1, 1
plateRow.Size, plateRow.AutomaticSize = UDim2.fromOffset(0, 72), Enum.AutomaticSize.X
Style.list(plateRow, 8, true).VerticalAlignment = Enum.VerticalAlignment.Bottom
plateRow.Parent = plates
result:GetPropertyChangedSignal("Visible"):Connect(function() -- the result's line takes the bottom between waves
	plateRow.Visible = not result.Visible
end)
local ROLE_COLOUR: { [string]: Color3 } = { attack = C.bad, defense = C.info, utility = C.good, titan = N.gold }
do -- the empty fourth plate (the IntroOwn board): where a Titan comes from, while the player has none
	local ivory = StationConfig.egg("ivory")
	local ghost = Style.glass(plateRow, UDim2.fromOffset(196, 62), 14)
	ghost.Name, ghost.LayoutOrder, ghost.Visible, ghost.BackgroundTransparency = "TitanSlot", 99, false, 0.45
	Style.small(ghost, "TITAN", 12, N.gold, UDim2.new(1, -20, 0, 16)).Position = UDim2.fromOffset(12, 10)
	local where = Style.text(ghost, `Ivory Egg · level {if ivory then ivory.level or 24 else 24}`, 15, N.muted)
	where.Position, where.Size, where.AutomaticSize =
		UDim2.fromOffset(12, 28), UDim2.new(1, -20, 0, 20), Enum.AutomaticSize.None
	function Hud.titanSlot(on: boolean)
		ghost.Visible = on
	end
end

-- A plate (decision 0114): the animal's picture, its class, its health and its mana. A full meter lifts
-- it, edges it in gold and shows the key of its press.
local function plate(slot: number, label: string, press: string, asset: string?, role: string?): Plate
	local holder = Instance.new("Frame")
	local wide = if Style.compact(root.Size.Y.Offset) then 150 else 196 -- a phone: clear of the shield and the corners
	holder.BackgroundTransparency, holder.Size, holder.LayoutOrder = 1, UDim2.fromOffset(wide, 72), slot
	holder.Parent = plateRow
	local b = Style.button(holder, "", function()
		Press.tap(slot)
	end, "night", UDim2.fromOffset(wide, 62))
	b.Position = UDim2.fromOffset(0, 10)
	Style.radius(b, 14)
	if asset then
		local face = Portrait.new(b, asset, { size = UDim2.fromOffset(48, 48), background = N.key })
		face.Position, face.ZIndex = UDim2.fromOffset(7, 7), 2
		Style.round(face, 11)
	end
	local class = Style.frame(b, UDim2.fromOffset(9, 9), ROLE_COLOUR[role or ""] or N.muted)
	class.Position, class.ZIndex = UDim2.fromOffset(63, 10), 2
	Style.round(class, 3)
	local name = Style.text(b, label, 14, N.text, UDim2.new(1, -88, 0, 16))
	name.Position, name.TextWrapped, name.TextTruncate, name.ZIndex =
		UDim2.fromOffset(77, 6), false, Enum.TextTruncate.AtEnd, 2
	local hpBar, setHp = Style.track(b, UDim2.new(1, -73, 0, 8), N.good)
	hpBar.Position, hpBar.ZIndex = UDim2.fromOffset(63, 28), 2
	local manaBar, setPower, fill = Style.track(b, UDim2.new(1, -73, 0, 8), N.edge)
	manaBar.Position, manaBar.ZIndex = UDim2.fromOffset(63, 42), 2
	if wide < 196 then -- a phone's plate: the picture says who it is, the bars get the room
		name.Visible, class.Position = false, UDim2.fromOffset(63, 9)
		hpBar.Position, manaBar.Position = UDim2.fromOffset(63, 24), UDim2.fromOffset(63, 40)
	end
	local key = Style.key(b, "", true)
	key.AnchorPoint, key.Position, key.Visible = Vector2.new(1, 1), UDim2.new(1, -6, 0, 7), false
	key.BackgroundColor3, key.TextColor3 = N.gold, Color3.fromRGB(42, 22, 64)
	return {
		button = b,
		holder = holder,
		power = setPower,
		health = setHp,
		fill = fill,
		key = key,
		full = false,
		press = press,
		label = label,
		fullAt = 0,
		close = 0,
		sent = false,
		presses = 0,
		mashUntil = 0,
		marks = {},
		marked = 0,
	}
end

do
	-- Clicks (decision 0106): a click anywhere on the fight that is not on a button strikes the front line.
	-- The server lands each strike FightFx.TAP_AHEAD later; here a click is answered at once (a slash on the
	-- nearest foe, a tick, the hit count), and the clicks go up in batches (`strike`) every STRIKE_SEND
	-- seconds. The quick presses' pop-ups live here too, above the clicks. A screen of its own, under the HUD.
	-- Where the needle is `age` seconds after the meter filled: through the middle at `close`, then every
	-- NEEDLE_EVERY after it, swinging out and back between (the server's crossings: BattleRules.perfect).
	local function needleAt(age: number, close: number): number
		local x = (age - close) / BattleRules.NEEDLE_EVERY
		local k = math.floor(x)
		return 0.5 + Press.SWING * (if k % 2 == 0 then 1 else -1) * math.sin(math.pi * (x - k))
	end

	local clickFx = Instance.new("ScreenGui")
	clickFx.Name, clickFx.ResetOnSpawn, clickFx.IgnoreGuiInset = "StationsClicks", false, true
	clickFx.DisplayOrder = screen.DisplayOrder - 1
	clickFx.Parent = player:WaitForChild("PlayerGui")
	local catcher = Instance.new("TextButton")
	catcher.Name, catcher.Text, catcher.AutoButtonColor = "Strike", "", false
	catcher.BackgroundTransparency, catcher.Size, catcher.Visible = 1, UDim2.fromScale(1, 1), false
	catcher.Parent = clickFx
	local hitCount = Style.text(root, "", 44, C.sand, UDim2.fromOffset(280, 56))
	hitCount.AnchorPoint, hitCount.Position, hitCount.ZIndex = Vector2.new(1, 0.5), UDim2.new(1, -24, 0.3, 0), 5
	hitCount.TextXAlignment, hitCount.Visible = Enum.TextXAlignment.Right, false
	Style.outline(hitCount)
	local STRIKE_SEND, CHAIN_HIT = 0.25, 0.8 -- seconds between sends; clicks this close keep the hit count
	local clicks, hits, lastClick = 0, 0, -math.huge

	-- the standing foes nearest the team (the front line first), up to `n`, by their unseen Hit boxes
	local function frontFoes(n: number): { BasePart }
		local folder = Workspace:FindFirstChild(player:GetAttribute("FightFolder") or `WaveShow{player.UserId}`)
		local ours, foes = {}, {}
		for _, m in if folder then folder:GetChildren() else {} do
			local hit, hp = m:FindFirstChild("Hit"), m:GetAttribute("Hp")
			if m:IsA("Model") and hit and hit:IsA("BasePart") and type(hp) == "number" and hp > 0 then
				if m:GetAttribute("Side") == 1 then
					if (m:GetAttribute("Owner") or player.UserId) == player.UserId then -- the player's own team
						table.insert(ours, hit.Position)
					end
				elseif m:GetAttribute("Side") == 2 then
					table.insert(foes, hit)
				end
			end
		end
		if #ours == 0 then
			return {}
		end
		local mid = Vector3.zero
		for _, at in ours do
			mid += at / #ours
		end
		table.sort(foes, function(a, b)
			return (a.Position - mid).Magnitude < (b.Position - mid).Magnitude
		end)
		return table.move(foes, 1, math.min(n, #foes), 1, {})
	end

	local function slash(at: Vector3)
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local v, on = camera:WorldToViewportPoint(at)
		if not on then
			return
		end
		local k = uiScale.Scale
		local bar = Style.frame(clickFx, UDim2.fromOffset(44 * k, 6 * k), C.card)
		bar.AnchorPoint, bar.Rotation = Vector2.new(0.5, 0.5), math.random(-40, 40)
		bar.Position = UDim2.fromOffset(v.X + math.random(-14, 14) * k, v.Y + math.random(-14, 14) * k)
		Style.round(bar, 3)
		TweenService:Create(bar, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Size = UDim2.fromOffset(96 * k, 2 * k),
			BackgroundTransparency = 1,
		}):Play()
		Debris:AddItem(bar, 0.25)
	end

	catcher.Activated:Connect(function()
		-- clicks count only once the wave has started, not while the enemies walk in (SHANNON, 2026-11-24)
		if not plates.Visible or Workspace:GetServerTimeNow() < (player:GetAttribute("FightFrom") or math.huge) then
			return
		end
		clicks = math.min(clicks + 1, 40)
		local now = os.clock()
		hits = if now - lastClick <= CHAIN_HIT then hits + 1 else 1
		lastClick = now
		Style.sound("hover")
		local foe = frontFoes(1)[1]
		if foe then
			slash(foe.Position)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(STRIKE_SEND)
			if clicks > 0 then
				local n = math.min(clicks, 20)
				clicks -= n
				S.strikes = (S.strikes or 0) + n -- the intro's first lesson counts them
				task.spawn(function()
					request:InvokeServer("strike", n)
				end)
			end
		end
	end)

	-- the pop-ups stand over their animals (decision 0109, SHANNON's pick B): PressPops places them
	Press.pops = require(script.Parent:WaitForChild("PressPops"))
	Press.pops.init(clickFx)

	local function pressOff(p: Plate)
		if p.card then
			p.card:Destroy()
		end
		if p.keys then
			Press.pops.free(p.keys)
		end
		p.card, p.hand, p.count, p.marks, p.marked, p.keys = nil, nil, nil, {}, 0, nil
	end

	-- The chain: the next of its 1-2-3 is struck (tapped, or the pop-up, the plate or the key); the last fires.
	local function chainHit(p: Plate, slot: number, k: number)
		if not p.full or p.sent or k ~= p.marked + 1 then
			return
		end
		p.marked = k
		if p.card and p.marks[k] then
			Press.pops.press(p.card, p.marks[k], Press.pops.GREEN)
			if k >= #p.marks then
				p.card:SetAttribute(
					"Hot",
					os.clock() - p.fullAt <= BattleRules.PERFECT_AT + BattleRules.PERFECT_LATE - 0.3
				)
			end
		end
		for i, m in p.marks do
			local e = m:FindFirstChildOfClass("UIStroke")
			if e then
				e.Color = if i <= k then Press.pops.GREEN elseif i == k + 1 then Press.pops.GOLD else Press.pops.EDGE
			end
			if i <= k then
				m.Text = "✓"
			end
		end
		local foe = frontFoes(1)[1]
		if foe then
			slash(foe.Position)
		end
		if k >= #p.marks then
			firePower(slot)
		end
	end

	-- A meter has just filled: its press pops up (decision 0106). Its timing is the ring's (decision 0097): due
	-- when a tap would land BattleRules.PERFECT_AT after the fill, a little earlier for the player's ping.
	local function pressOn(p: Plate, slot: number)
		pressOff(p)
		local ping = math.min(0.25, player:GetNetworkPing() * 2)
		p.fullAt, p.close = os.clock(), math.max(0.2, BattleRules.PERFECT_AT - FightFx.TAP_AHEAD - ping)
		p.sent, p.presses = false, 0
		-- the reference's look (decision 0109, amended): PressPops draws the card
		local k = uiScale.Scale * 0.85 -- over the animals: compact
		local wide = 2 * Press.SWING * math.sin(math.pi * BattleRules.PERFECT_EARLY / BattleRules.NEEDLE_EVERY)
		p.keys = Press.pops.claim(p.press)
		local card, parts = Press.pops.card(clickFx, p.press, Press.pops.names(p.keys :: { Enum.KeyCode }), k, wide, {
			press = function()
				Press.tap(slot)
			end,
			down = function()
				Press.hold(slot, true)
			end,
			up = function()
				Press.hold(slot, false)
			end,
			mark = function(i: number)
				chainHit(p, slot, i)
			end,
		})
		p.parts, p.holdAt, p.hand, p.marks = parts, nil, parts.hand, parts.marks
		if p.press == "mash" then -- the presses go up together at MASH_COUNT, or when time is up
			local window = math.max(0.5, BattleRules.MASH_BY - FightFx.TAP_AHEAD - ping)
			p.mashUntil = p.fullAt + window
			task.delay(window, function()
				if p.full and not p.sent and p.presses > 0 and not S.intro then -- short of MASH_FAIL: messed up
					firePower(slot, if p.presses < BattleRules.MASH_FAIL then BattleRules.FAILED else p.presses)
				end
			end)
		end
		p.card = card
		card:SetAttribute("PressKind", p.press) -- the intro's spotlight finds the card it teaches
		Press.pops.attach(card, p.model, p.press, k)
		task.delay(BattleRules.AUTO_FIRE - 0.1, function() -- left too long: it fails (the server's AUTO_FIRE)
			if p.card == card and not p.sent and not S.intro then -- the intro's presses wait (BattleRules patient)
				p.sent, p.card = true, nil
				Press.pops.fired(card, false, true)
			end
		end)
	end

	local function pressPlate(slot: number)
		local p = plateOf[slot]
		if p == nil or not p.full or p.sent then
			return
		end
		if p.press == "ring" then
			if p.holdAt == nil then -- the plate tapped, not held: it fires now, never a Perfect
				firePower(slot, 0)
			end
		elseif p.press == "mash" then
			p.presses += 1
			Style.sound("hover")
			if p.parts and p.parts.fill then
				p.parts.fill.Size = UDim2.fromScale(math.min(1, p.presses / BattleRules.MASH_COUNT), 1)
				Press.pops.press(p.card, p.parts.key, nil, true)
				p.card:SetAttribute("Hot", p.presses >= BattleRules.MASH_COUNT)
			end
			if p.presses >= BattleRules.MASH_COUNT or os.clock() > p.mashUntil then
				firePower(slot, p.presses)
			end
		elseif p.press == "chain" then
			chainHit(p, slot, p.marked + 1)
		elseif p.press == "needle" and p.card and p.card:GetAttribute("Hot") ~= true then
			firePower(slot, BattleRules.FAILED) -- stopped outside the green
		else
			firePower(slot)
		end
	end

	-- The ring (decision 0109, amended): held while it fills; let go, it fires with how long it was held (in
	-- tenths, which the server caps by its own clock), and held to full it fires itself, a Perfect.
	local function holdRing(slot: number, down: boolean)
		local p = plateOf[slot]
		if p == nil or not p.full or p.sent or p.press ~= "ring" then
			return
		end
		if down and p.holdAt == nil then
			p.holdAt = os.clock()
			Style.sound("hover")
			if p.card and p.parts and p.parts.key then
				Press.pops.press(p.card, p.parts.key)
			end
		elseif not down and p.holdAt then
			local tenths = math.clamp(math.floor((os.clock() - p.holdAt) * 10), 0, 30)
			p.holdAt = nil
			firePower(slot, if tenths < BattleRules.RING_FAIL then BattleRules.FAILED else tenths) -- let go too soon
		end
	end

	-- the needles swing; the hit count shows while the clicks keep coming
	RunService.RenderStepped:Connect(function()
		if not plates.Visible then
			return
		end
		for slot, p in plateOf do
			if p.hand then
				p.hand.Position = UDim2.fromScale(needleAt(os.clock() - p.fullAt, p.close), 0.5)
			end
			if p.parts and #p.parts.dots > 0 and p.full and not p.sent then -- the ring fills while held
				local held = if p.holdAt then (os.clock() - p.holdAt) * 10 / BattleRules.HOLD_TENTHS else 0
				Press.pops.lit(p.parts, math.floor(math.min(1, held) * #p.parts.dots))
				if p.card then
					p.card:SetAttribute("Hot", held >= 1)
				end
				for i, dot in p.parts.dots do
					local lit = i / #p.parts.dots <= held
					dot.BackgroundColor3 = if not lit
						then Press.pops.DIM
						elseif held >= 0.8 then Press.pops.GOLD
						else Press.pops.LIT
				end
				p.parts.edge.Color = if held >= 0.8 then Press.pops.GOLD else Press.pops.EDGE
				if held >= 1 then
					p.holdAt = nil
					task.spawn(firePower, slot, BattleRules.HOLD_TENTHS)
				end
			elseif p.parts and p.hand and p.full then -- the needle's card goes green while the marker is in it
				local x = needleAt(os.clock() - p.fullAt, p.close)
				local wide = Press.SWING * math.sin(math.pi * BattleRules.PERFECT_EARLY / BattleRules.NEEDLE_EVERY)
				p.parts.edge.Color = if math.abs(x - 0.5) <= wide then Press.pops.GREEN else Press.pops.EDGE
				if p.card then
					p.card:SetAttribute("Hot", math.abs(x - 0.5) <= wide)
				end
			end
		end
		hitCount.Visible = hits >= 3 and os.clock() - lastClick < CHAIN_HIT + 0.4
		hitCount.Text = `{hits} HITS`
	end)
	Press.tap, Press.on, Press.off, Press.catcher, Press.hold = pressPlate, pressOn, pressOff, catcher, holdRing
end

-- the press keys (PressPops.claim): each card's own, taken from the character while the fight is on
plates:GetPropertyChangedSignal("Visible"):Connect(function()
	Press.pops.listen(if plates.Visible
		then function(key: Enum.KeyCode, down: boolean)
			for slot, p in plateOf do
				local keys = p.keys
				if keys == nil or not p.full or p.sent then
					continue
				end
				if p.press == "ring" and keys[1] == key then
					Press.hold(slot, down)
				elseif down and p.press ~= "ring" and keys[if p.press == "chain" then p.marked + 1 else 1] == key then
					Press.tap(slot) -- the chain's next key, or the needle's or the mash's
				elseif down and p.press == "chain" and table.find(keys, key) then
					firePower(slot, BattleRules.FAILED) -- one of its keys out of order
				end
			end
		end
		else nil)
end)

task.spawn(function()
	while true do
		task.wait(0.1)
		local folder = Workspace:FindFirstChild(player:GetAttribute("FightFolder") or `WaveShow{player.UserId}`)
		local seen: { [number]: boolean } = {}
		if folder then
			for _, m in folder:GetChildren() do
				local slot = m:GetAttribute("Seat") or m:GetAttribute("Slot")
				local owner = m:GetAttribute("Owner") or player.UserId
				if
					m:GetAttribute("Side") == 1
					and type(slot) == "number"
					and owner ~= player.UserId
					and m:IsA("Model")
				then
					-- another player's animal: only a marker over it while its meter is full (decision 0109)
					local s, power, hp = m:GetAttribute("Species"), m:GetAttribute("Power"), m:GetAttribute("Hp")
					Press.pops.ally(
						m,
						if type(s) == "string" then BattleRules.pressOf({ s = s } :: any) else "ring",
						type(power) == "number" and power >= 1 and type(hp) == "number" and hp > 0
					)
				elseif m:GetAttribute("Side") == 1 and type(slot) == "number" then
					seen[slot] = true
					local p = plateOf[slot]
					if p == nil then
						local s, v = m:GetAttribute("Species"), m:GetAttribute("Variant")
						local va = if type(s) == "string" and type(v) == "string"
							then StationConfig.variant(s, v)
							else nil
						local sp = if type(s) == "string" then StationConfig.species(s) else nil
						local press = if type(s) == "string"
							then BattleRules.pressOf({ s = s, v = if type(v) == "string" then v else nil } :: any)
							else "ring"
						p = plate(
							slot,
							if va then va.name elseif sp then sp.name else "?",
							press,
							if type(s) == "string"
								then StationRules.assetOf(s, if type(v) == "string" then v else nil)
								else nil,
							if type(s) == "string" then StationRules.role({ s = s, v = v } :: any) else nil
						)
						plateOf[slot] = p
						m:GetAttributeChangedSignal("AnimAt"):Connect(function()
							if m:GetAttribute("Anim") == "magic" and type(s) == "string" then -- its power attack: say its name
								S.moveName(s)
							end
						end)
					end
					p.model = if m:IsA("Model") then m else nil
					local hp = m:GetAttribute("Hp")
					local alive = type(hp) == "number" and hp > 0
					local power = m:GetAttribute("Power")
					local share = if type(power) == "number" then math.clamp(power, 0, 1) else 0
					local full = alive and share >= 1
					p.power(share)
					local max = m:GetAttribute("MaxHp")
					p.health(
						if type(hp) == "number" and type(max) == "number" then math.max(0, hp) / math.max(1, max) else 0
					)
					p.fill.BackgroundColor3 = if full then N.gold else N.edge
					p.key.Visible = full and p.keys ~= nil and not Style.touch()
					if p.keys then
						p.key.Text = if p.press == "chain"
							then "Arrows"
							elseif p.press == "mash" then "Space"
							else Press.pops.names(p.keys)[1] or ""
					end
					if full ~= p.full then
						p.full = full
						if full then
							Press.on(p, slot)
						else
							Press.off(p)
						end
						Style.kind(p.button, if full then "nightHot" else if alive then "night" else "nightOff")
						p.button.Position = UDim2.fromOffset(0, if full then 0 else 10)
					elseif not alive then
						Style.kind(p.button, "nightOff")
					end
				end
			end
		end
		for slot, p in plateOf do
			if not seen[slot] then
				Press.off(p)
				p.holder:Destroy()
				plateOf[slot] = nil
			end
		end
		plates.Visible = next(plateOf) ~= nil
		Hud.titanSlot(plates.Visible and not S.intro and S.profile ~= nil and S.profile.titan == nil)
		Press.catcher.Visible = plates.Visible
		S.fightTick(folder, plates.Visible)
	end
end)

return nil
