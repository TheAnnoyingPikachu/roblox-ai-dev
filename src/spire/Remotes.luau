--!strict
-- Creates the Neon Spire remote contract (decision 0009, docs/architecture/spire.md 6), copied from
-- src/garden/Remotes.luau: ReplicatedStorage.SpireRemotes with Request and Fx, and the SpireStatus
-- StringValue. The server ignores Fx.OnServerEvent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "SpireRemotes"

local request = Instance.new("RemoteFunction")
request.Name = "Request"
request.Parent = folder

local fxEvent = Instance.new("RemoteEvent")
fxEvent.Name = "Fx"
fxEvent.Parent = folder

local status = Instance.new("StringValue")
status.Name = "SpireStatus"
status.Value = "{}"

folder.Parent = ReplicatedStorage
status.Parent = ReplicatedStorage

local Remotes = {
	Request = request,
	Fx = fxEvent,
	Status = status,
}

-- Display-only event to every client; payloads in docs/architecture/spire.md 6.3.
function Remotes.fx(kind: string, data: { [string]: any })
	fxEvent:FireAllClients(kind, data)
end

-- A message that needs words, to one player only.
function Remotes.notice(player: Player, text: string)
	fxEvent:FireClient(player, "notice", { text = text })
end

return Remotes
