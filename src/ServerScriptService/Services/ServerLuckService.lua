local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)

local ServerLuckService = {}

local EndTime = 0
local LuckBoost = 1

function ServerLuckService.Timer()
	ReplicatedStorage.Server.LuckBoost:GetAttributeChangedSignal("EndTime"):Connect(function()
		local newEndTime = ReplicatedStorage.Server.LuckBoost:GetAttribute("EndTime")
		local currentLuck = ReplicatedStorage.Server.LuckBoost.Value

		-- If the luck value is the same or higher, and the new end time is later, extend the timer
		if currentLuck >= LuckBoost and newEndTime > EndTime then
			EndTime = newEndTime
			LuckBoost = currentLuck
		end
	end)

	ReplicatedStorage.Server.LuckBoost.Changed:Connect(function(value)
		-- If luck increased, set new end time and boost
		if value > LuckBoost then
			EndTime = ReplicatedStorage.Server.LuckBoost:GetAttribute("EndTime")
			LuckBoost = value
		end
	end)

	task.spawn(function()
		while task.wait(1) do
			if EndTime - os.time() > 0 then
				ReplicatedStorage.Server.LuckBoost.Value = LuckBoost
				ReplicatedStorage.Server.LuckBoost:SetAttribute("EndTime", EndTime)
			else
				ReplicatedStorage.Server.LuckBoost.Value = 1
				ReplicatedStorage.Server.LuckBoost:SetAttribute("EndTime", 0)
			end
		end
	end)
end

function ServerLuckService.Handler()
	ServerLuckService.Timer()
end

return ServerLuckService