--!strict
-- Hundred Demon Night client-only state (docs/architecture/night.md section 6): settings that
-- never reach the server, signals between the client scripts, camera requests for CameraFx,
-- and small read-only helpers for NightStatus and one-shot sounds.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local ClientState = {}

export type Settings = { music: boolean, sfx: boolean, shake: boolean, numbers: boolean }
export type Status = {
	state: string,
	wave: number,
	tier: number,
	left: number,
	ids: { number },
	host: number?,
	boss: number?,
}

ClientState.settings = { music = true, sfx = true, shake = true, numbers = true } :: Settings

local settingsChanged = Instance.new("BindableEvent")
ClientState.SettingsChanged = settingsChanged.Event
local dashed = Instance.new("BindableEvent")
ClientState.Dashed = dashed.Event -- (thunder: boolean) fired by Movement on an accepted local dash
local acted = Instance.new("BindableEvent")
ClientState.Acted = acted.Event -- (action: string) fired when this client sends a Combat action

-- Camera requests, read and decayed by CameraFx.
ClientState.shakeUntil = 0
ClientState.shakeSize = 0
ClientState.fov = 0

-- Movement installs its dash here so the touch DASH button (CombatFx) runs the same code.
ClientState.Dash = nil :: (() -> ())?

-- os.clock() of this client's last sent action, for cooldown rings and first-run prompts.
ClientState.sent = { attack = -math.huge, skill = -math.huge, dash = -math.huge, trigger = -math.huge }

function ClientState.set(key: string, value: boolean)
	(ClientState.settings :: any)[key] = value
	settingsChanged:Fire(key)
end

function ClientState.dashed(thunder: boolean)
	ClientState.sent.dash = os.clock()
	dashed:Fire(thunder)
end

function ClientState.acted(action: string)
	ClientState.sent[action] = os.clock()
	acted:Fire(action)
end

-- Shake for `seconds`; size is the offset in studs (0.25 = light, 0.6 = heavy).
function ClientState.shake(seconds: number, size: number?)
	if not ClientState.settings.shake then
		return
	end
	local active = os.clock() < ClientState.shakeUntil
	ClientState.shakeUntil = math.max(ClientState.shakeUntil, os.clock() + seconds)
	ClientState.shakeSize = math.max(if active then ClientState.shakeSize else 0, size or 0.25)
end

function ClientState.fovKick(degrees: number)
	ClientState.fov = math.max(ClientState.fov, degrees)
end

-- NightStatus -----------------------------------------------------------------------------------

local statusValue = ReplicatedStorage:WaitForChild("NightStatus") :: StringValue
ClientState.statusValue = statusValue
local cachedRaw: string? = nil
local cached: Status = { state = "Idle", wave = 0, tier = 1, left = 0, ids = {} }

function ClientState.status(): Status
	local raw = statusValue.Value
	if raw ~= cachedRaw then
		cachedRaw = raw
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(decoded) == "table" then
			cached = {
				state = if type(decoded.state) == "string" then decoded.state else "Idle",
				wave = tonumber(decoded.wave) or 0,
				tier = tonumber(decoded.tier) or 1,
				left = tonumber(decoded.left) or 0,
				ids = if type(decoded.ids) == "table" then decoded.ids else {},
				host = tonumber(decoded.host),
				boss = tonumber(decoded.boss),
			}
		end
	end
	return cached
end

function ClientState.isParticipant(userId: number?): boolean
	local id = userId or (Players.LocalPlayer :: Player).UserId
	return table.find(ClientState.status().ids, id) ~= nil
end

-- A run the local player is fighting in (actions are accepted only in these states).
function ClientState.fighting(): boolean
	local s = ClientState.status().state
	return (s == "Countdown" or s == "Wave" or s == "Break") and ClientState.isParticipant()
end

function ClientState.json(value: any): any
	if type(value) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value)
	return if ok then decoded else nil
end

-- Sounds ----------------------------------------------------------------------------------------

-- One-shot sound, 2D or at a world position; silent when sound effects are off.
function ClientState.sound(id: string, volume: number, at: Vector3?, pitch: number?)
	if not ClientState.settings.sfx then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = pitch or 1
	local holder: Instance = SoundService
	if at then
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = Workspace.Terrain
		holder = a
		s.RollOffMinDistance = 20
		s.RollOffMaxDistance = 220
	end
	s.Parent = holder
	s.Ended:Once(function()
		(if holder == SoundService then s else holder):Destroy()
	end)
	s:Play()
	task.delay(8, function()
		if s.Parent then
			(if holder == SoundService then s else holder):Destroy()
		end
	end)
end

-- Licensed audio (docs/assets/register.md rows added by NIGHT-004) and built-in Roblox sounds.
ClientState.SFX = {
	swingA = "rbxassetid://9114373678",
	swingB = "rbxassetid://9114374642",
	whoosh = "rbxassetid://9114373663",
	dash = "rbxassetid://9125920594",
	pop = "rbxassetid://9125442175",
	roar = "rbxassetid://9113980319",
	beep = "rbxassetid://9117060347",
	gong = "rbxassetid://9125585534",
	bigGong = "rbxassetid://9114630316",
	thud = "rbxasset://sounds/action_jump_land.mp3",
	boom = "rbxasset://sounds/impact_explosion_03.mp3",
	ouch = "rbxasset://sounds/ouch.ogg",
}

-- UI scale for phones: HUD layouts are drawn for a 1100 x 620 screen and scaled to fit.
function ClientState.autoScale(target: GuiObject)
	local scale = Instance.new("UIScale")
	local function fit()
		local view = Workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(view.X / 1100, view.Y / 620), 0.62, 1.25)
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	scale.Parent = target
end

return ClientState
