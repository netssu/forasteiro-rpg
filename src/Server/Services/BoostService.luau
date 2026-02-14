local BoostService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local BoostData = require(ReplicatedStorage.Modules.Constants.BoostsData)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local playerTimers = {}

local function clearTimers(player)
	if playerTimers[player] then
		playerTimers[player]:Destroy()
		playerTimers[player] = nil
	end
end

local function deactivateBoost(player, boostKey)
	if playerTimers[player] then
		playerTimers[player]:Remove("Timer_" .. boostKey)
	end

	pcall(function()
		PlayerDataManager:Set(player, {"Boost", boostKey}, false)
		PlayerDataManager:Set(player, {"BoostTimes", boostKey}, nil)
	end)
end

local function runBoostTimer(player, boostKey, duration)
	if not playerTimers[player] then
		playerTimers[player] = Janitor.new()
	end

	local timerKey = "Timer_" .. boostKey
	playerTimers[player]:Remove(timerKey)

	local timerThread = task.delay(duration, function()
		deactivateBoost(player, boostKey)
	end)

	playerTimers[player]:Add(function()
		task.cancel(timerThread)
	end, true, timerKey)
end

function BoostService:ActivateBoost(player, boostKey)
	local data = BoostData[boostKey]
	if not data then return end

	if data.IsPermanent or data.Duration == math.huge then
		pcall(function()
			PlayerDataManager:Set(player, {"Boost", boostKey}, true)
		end)
		return
	end

	local endTime = os.time() + data.Duration

	pcall(function()
		PlayerDataManager:Set(player, {"Boost", boostKey}, true)
		PlayerDataManager:Set(player, {"BoostTimes", boostKey}, endTime)
	end)

	runBoostTimer(player, boostKey, data.Duration)
end

function BoostService:RestoreBoosts(player)
	for boostKey, data in pairs(BoostData) do
		if data.GamepassId then
			local success, hasPass = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, data.GamepassId)
			end)
			
			if success then
				if hasPass then
					PlayerDataManager:Set(player, {"Boost", boostKey}, true)
				else
					PlayerDataManager:Set(player, {"Boost", boostKey}, false)
				end
			end
		
		elseif data.IsPermanent then
			local isActive = PlayerDataManager:Get(player, {"Boost", boostKey})
		else
			local savedEndTime = PlayerDataManager:Get(player, {"BoostTimes", boostKey})
			if savedEndTime and type(savedEndTime) == "number" then
				local remainingTime = savedEndTime - os.time()
				
				if remainingTime > 0 then
					pcall(function()
						PlayerDataManager:Set(player, {"Boost", boostKey}, true)
					end)
					runBoostTimer(player, boostKey, remainingTime)
				else
					deactivateBoost(player, boostKey)
				end
			else
				local isLegacyActive = PlayerDataManager:Get(player, {"Boost", boostKey})
				if isLegacyActive then
					deactivateBoost(player, boostKey)
				end
			end
		end
	end
end

function BoostService:Init()
	Players.PlayerRemoving:Connect(clearTimers)
	
	Players.PlayerAdded:Connect(function(player)
		task.delay(1.5, function()
			BoostService:RestoreBoosts(player)
		end)
	end)
end

return BoostService