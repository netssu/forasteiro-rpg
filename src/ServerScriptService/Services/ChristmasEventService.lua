local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local ChristmasEventTable = require(ReplicatedStorage.Arrays.ChristmasEventTable)
local remote = ReplicatedStorage.Remotes.Events.ChristmasQuest

local ChristmasEventService = {}

function ChristmasEventService.Listener()
	remote.OnServerEvent:Connect(function(plr: Player, reward)
		print(reward)
		local rewardData = ChristmasEventTable[reward] 
		print(rewardData)
		local PlrData = PlayerDataService.GetDataRemote(plr)
		if not PlrData then
			return
		end
		if PlrData.ChristmasWins >= rewardData.AmountRequired then
			rewardData.Function(plr)
			print("Getting")
		end
	end)
end

function ChristmasEventService.Handler()
	--ChristmasEventService.Listener()
end

return ChristmasEventService
