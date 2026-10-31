--!strict
-- Prints the build stamp when a server starts (SPIRE-002), so the F9 server log says which commit
-- is running. Mapped into every place as ServerScriptService.BuildStamp. The text comes from
-- ReplicatedStorage.BuildInfo, which CI writes from build-info/BuildInfo.txt before `rojo build`.
-- Also sets the Workspace attribute "BuildStamp" (short sha or "dev") for other scripts and tests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildStamp = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("BuildStamp"))

local info = ReplicatedStorage:FindFirstChild("BuildInfo")
local text = if info and info:IsA("StringValue") then info.Value else nil
if text == nil then
	warn("[Build] ReplicatedStorage.BuildInfo is missing: this place was not built from the repo project files")
end
workspace:SetAttribute("BuildStamp", BuildStamp.label(text))
print(BuildStamp.line(text, `place {game.PlaceId}, job {game.JobId}`))
