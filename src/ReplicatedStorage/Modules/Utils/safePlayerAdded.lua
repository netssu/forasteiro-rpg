local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedModules = ReplicatedStorage.Modules
local Maid = require(sharedModules.Nevermore.Maid)

local function safePlayerAdded(callback: (Player) -> ()): typeof(Maid.new())
	local maid = Maid.new()

	for _, player in Players:GetPlayers() do
		task.spawn(callback, player)
	end

	maid:GiveTask(Players.PlayerAdded:Connect(callback))
	return maid
end

return safePlayerAdded
