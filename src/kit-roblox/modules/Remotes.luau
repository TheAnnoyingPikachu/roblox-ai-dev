--!strict
-- Kit (Roblox side): creates a game's remotes and binds the request RemoteFunction to a pure
-- kit/Router. Server only: `require` it from a server script.
--
--   local remotes = Remotes.create("SpireRemotes", router)
--   remotes.fx(player, "build", { floor = 3 })  -- server -> client effects, display only
--
-- Layout: ReplicatedStorage.<name> (Folder) with Request (RemoteFunction) and Fx (RemoteEvent).
-- Clients call Request:InvokeServer(action, ...) and get (ok, code).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Router = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Router"))

local Remotes = {}

export type Handle = {
	folder: Folder,
	request: RemoteFunction,
	event: RemoteEvent,
	fx: (player: Player, kind: string, payload: any) -> (),
	fxAll: (kind: string, payload: any) -> (),
}

function Remotes.create(name: string, router: Router.Router): Handle
	assert(ReplicatedStorage:FindFirstChild(name) == nil, `Remotes: {name} already exists`)
	local folder = Instance.new("Folder")
	folder.Name = name
	local request = Instance.new("RemoteFunction")
	request.Name = "Request"
	request.Parent = folder
	local event = Instance.new("RemoteEvent")
	event.Name = "Fx"
	event.Parent = folder

	request.OnServerInvoke = function(player: Player, action: any, ...: any)
		return router:handle(player, os.clock(), action, ...)
	end
	Players.PlayerRemoving:Connect(function(player)
		router:forget(player)
	end)
	folder.Parent = ReplicatedStorage

	return {
		folder = folder,
		request = request,
		event = event,
		fx = function(player, kind, payload)
			event:FireClient(player, kind, payload)
		end,
		fxAll = function(kind, payload)
			event:FireAllClients(kind, payload)
		end,
	}
end

return Remotes
