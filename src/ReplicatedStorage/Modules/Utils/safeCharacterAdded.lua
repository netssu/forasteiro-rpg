local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedModules = ReplicatedStorage.Modules
local Maid = require(sharedModules.Nevermore.Maid)

local function safeCharacterAdded(player, callback: (Model) -> ()): typeof(Maid.new())
	local maid = Maid.new()

	if player.Character then
		task.spawn(callback, player.Character)
	end

	maid:GiveTask(player.CharacterAdded:Connect(callback))
	return maid
end

return safeCharacterAdded
