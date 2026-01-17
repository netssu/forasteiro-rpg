local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedModules = ReplicatedStorage.Modules
local clientModules = Players.LocalPlayer.PlayerScripts.Modules
local LogRequire = require(sharedModules.LogRequire)

LogRequire(clientModules.FeedbackMailbox.FeedbackMailboxSystem).init()

for _, v in ReplicatedStorage.Controllers:GetChildren() do
	if v:IsA("ModuleScript") then
		print(v, "module")
		require(v).Handler()
	end
end
