--!strict
-- Creates the Night remote contract (decision 0007): ReplicatedStorage.NightRemotes with Request,
-- Combat and Fx, and the NightStatus StringValue. The server ignores Fx.OnServerEvent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "NightRemotes"

local request = Instance.new("RemoteFunction")
request.Name = "Request"
request.Parent = folder

local combat = Instance.new("RemoteEvent")
combat.Name = "Combat"
combat.Parent = folder

local fxEvent = Instance.new("RemoteEvent")
fxEvent.Name = "Fx"
fxEvent.Parent = folder

local status = Instance.new("StringValue")
status.Name = "NightStatus"
status.Value = "{}"

folder.Parent = ReplicatedStorage
status.Parent = ReplicatedStorage

local Remotes = {
	Request = request,
	Combat = combat,
	Fx = fxEvent,
	Status = status,
}

-- Display-only event to every client; payloads in docs/architecture/night.md section 5.
function Remotes.fx(kind: string, data: { [string]: any })
	fxEvent:FireAllClients(kind, data)
end

return Remotes
