--!strict
-- Creates the Egg Garden remote contract (decision 0008), copied from src/night/Remotes.luau:
-- ReplicatedStorage.GardenRemotes with Request and Fx, and the GardenStatus StringValue.
-- The server ignores Fx.OnServerEvent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "GardenRemotes"

local request = Instance.new("RemoteFunction")
request.Name = "Request"
request.Parent = folder

local fxEvent = Instance.new("RemoteEvent")
fxEvent.Name = "Fx"
fxEvent.Parent = folder

local status = Instance.new("StringValue")
status.Name = "GardenStatus"
status.Value = "{}"

folder.Parent = ReplicatedStorage
status.Parent = ReplicatedStorage

local Remotes = {
	Request = request,
	Fx = fxEvent,
	Status = status,
}

-- Display-only event to every client; payloads in docs/architecture/garden.md section 5.
function Remotes.fx(kind: string, data: { [string]: any })
	fxEvent:FireAllClients(kind, data)
end

-- A display-only event to one player.
function Remotes.fxTo(player: Player, kind: string, data: { [string]: any })
	fxEvent:FireClient(player, kind, data)
end

-- A refusal that needs words, to one player only.
function Remotes.notice(player: Player, text: string)
	fxEvent:FireClient(player, "notice", { text = text })
end

return Remotes
