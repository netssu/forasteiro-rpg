--// Mission Manager System //--
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Dependencies //--
local Core = ServerScriptService.Core
local Shared = ReplicatedStorage.Shared

local Configs = Shared.Configs
local MissionConfig = require(Configs.MissionConfig)

local PlayerManager = require(Core.Player.PlayerManager)
local Utilities = Shared.Utilities
local Notifications = require(Utilities.Notifications)
local BigNum = require(Utilities.BigNum)

local UpdateMissionProgress = ServerScriptService.Bindables.UpdateMissionProgress

--// Setup //--
local MissionManager = {}

--// Player Mission Data //--
local PlayerMissions = {} -- [player] = MissionData

--// Types //--
export type MissionProgress = {
	Progress: {[string]: any}, -- [taskStat] = current value (number or BigNum string) 
	Completed: boolean,
	LastReset: number?,
	ClaimTime: number?, -- When mission was completed
}

export type MissionTypeData = {
	Missions: {string}, -- Array of mission IDs
	Progress: {[string]: MissionProgress},
	LastReset: number,
}

export type PlayerMissionData = {
	Daily: MissionTypeData,
	Weekly: MissionTypeData,
	Hourly: MissionTypeData,
	Quest: {
		CurrentQuest: string?,
		CompletedQuests: {string},
		Progress: {[string]: MissionProgress},
	},
	Achievements: {
		Progress: {[string]: MissionProgress},
	},
}

--// Constants //--
local MISSION_COUNTS = {
	Daily = 3,
	Weekly = 2,
	Hourly = 3,
}

local RESET_INTERVALS = {
	Daily = 86400, -- 24 hours
	Weekly = 604800, -- 7 days
	Hourly = 3600, -- 1 hour
}

--// Helper Functions //--

local function getNextResetTime(missionType: string): number
	local now = tick()

	if missionType == "Daily" then
		local secondsSinceMidnight = now % 86400
		return now + 86400 - secondsSinceMidnight
	elseif missionType == "Weekly" then
		local dayOfWeek = (math.floor(now / 86400) + 4) % 7
		local secondsSinceMidnight = now % 86400
		local secondsUntilMonday = ((7 - dayOfWeek) % 7) * 86400
		return now + secondsUntilMonday + 86400 - secondsSinceMidnight
	elseif missionType == "Hourly" then
		local secondsSinceHour = now % 3600
		return now + 3600 - secondsSinceHour
	end

	return math.huge
end


local function selectRandomMissions(missionType: string, count: number): {string}
	local allMissions = MissionConfig.getMissionsByType(missionType)

	if #allMissions <= count then
		return allMissions
	end

	local selected = {}
	local pool = table.clone(allMissions)

	for i = 1, count do
		if #pool > 0 then
			local index = math.random(1, #pool)
			table.insert(selected, pool[index])
			table.remove(pool, index)
		end
	end

	return selected
end

local function isMissionComplete(missionId: string, progress: {[string]: any}): boolean
	local missionDef = MissionConfig.getMission(missionId)
	if not missionDef then return false end

	for taskName, required in pairs(missionDef.Tasks) do
		local current = progress[taskName]

		-- Handle BigNum comparisons for cash tasks
		if taskName == "CashEarned" or taskName == "TotalCashEarned" then
			local currentBN = BigNum.new(current or "0")
			local requiredBN = BigNum.new(required)

			if currentBN:lessThan(requiredBN) then
				return false
			end
		else
			-- Regular number comparison
			if (current or 0) < required then
				return false
			end
		end
	end

	return true
end

local function initializeMissionTypeData(missionType: string): MissionTypeData
	local missions = selectRandomMissions(missionType, MISSION_COUNTS[missionType] or 0)
	local progress = {}

	for _, missionId in ipairs(missions) do
		progress[missionId] = {
			Progress = {},
			Completed = false,
			LastReset = tick(),
		}
	end

	return {
		Missions = missions,
		Progress = progress,
		LastReset = getNextResetTime(missionType),
	}
end

local function resetMissionType(player: Player, missionType: string)
	local playerData = PlayerMissions[player]
	if not playerData then return end

	playerData[missionType] = initializeMissionTypeData(missionType)

	print(`[MISSIONS] Reset {missionType} missions for {player.Name}`)
end

local function checkAndResetMissions(player: Player)
	local playerData = PlayerMissions[player]
	if not playerData then return end

	local now = tick()

	for _, missionType in ipairs({"Daily", "Weekly", "Hourly"}) do
		local typeData = playerData[missionType]
		if typeData and now >= typeData.LastReset then
			resetMissionType(player, missionType)
		end
	end
end

--// Initialization //--

function MissionManager.initializePlayer(player: Player)
	-- Create blank slate
	PlayerMissions[player] = {
		Daily = initializeMissionTypeData("Daily"),
		Weekly = initializeMissionTypeData("Weekly"),
		Hourly = initializeMissionTypeData("Hourly"),
		Quest = {
			CurrentQuest = nil,
			CompletedQuests = {},
			Progress = {},
		},
		Achievements = {
			Progress = {},
		},
	}

	-- Initialize all achievements
	for missionId, missionDef in pairs(MissionConfig.Missions) do
		if missionDef.Type == "Achievement" then
			PlayerMissions[player].Achievements.Progress[missionId] = {
				Progress = {},
				Completed = false,
			}
		end
	end

	-- Initialize first quest
	local firstQuest = MissionConfig.getFirstQuest()
	if firstQuest then
		PlayerMissions[player].Quest.CurrentQuest = firstQuest
		PlayerMissions[player].Quest.Progress[firstQuest] = {
			Progress = {},
			Completed = false,
		}
	end

	--print(`[MISSIONS] Initialized player {player.Name}`)
end

function MissionManager.cleanupPlayer(player: Player)
	PlayerMissions[player] = nil
end

--// Progress Tracking //--

function MissionManager.updateProgress(player: Player, progressData: {[string]: any})
	local playerData = PlayerMissions[player]
	if not playerData then return end

	local completedMissions = {}
	
	-- Update timed missions (Daily, Weekly, Hourly)
	for _, missionType in ipairs({"Daily", "Weekly", "Hourly"}) do
		local typeData = playerData[missionType]
		if not typeData then continue end

		for _, missionId in ipairs(typeData.Missions) do
			local missionProgress = typeData.Progress[missionId]
			if not missionProgress or missionProgress.Completed then continue end

			local missionDef = MissionConfig.getMission(missionId)
			if not missionDef then continue end

			local wasComplete = isMissionComplete(missionId, missionProgress.Progress)

			-- Update matching tasks
			for taskName, value in pairs(progressData) do
				if not missionDef.Tasks[taskName] then print("exited") continue end
				local current = missionProgress.Progress[taskName]
				local required = missionDef.Tasks[taskName]
	
				-- Handle BigNum for cash
				if taskName == "CashEarned" or taskName == "TotalCashEarned" then
					local currentBN = BigNum.new(current or "0")
					local addBN = BigNum.new(value)
					local requiredBN = BigNum.new(required)

					local newBN = currentBN + addBN

					-- Clamp to required without converting to number
					if newBN:greaterThan(requiredBN) then
						newBN = requiredBN
					end

					missionProgress.Progress[taskName] = newBN:toString()
				else
					-- Regular numbers
					local newValue = (current or 0) + value
					if newValue > required then
						newValue = required
					end
					
					missionProgress.Progress[taskName] = newValue
				end
			end

			-- Check completion
			local isComplete = isMissionComplete(missionId, missionProgress.Progress)
			if isComplete and not wasComplete then
				missionProgress.Completed = true
				missionProgress.ClaimTime = tick()
				table.insert(completedMissions, {
					type = missionType,
					id = missionId,
					def = missionDef,
				})
			end
		end
	end

	-- Update current quest (same pattern)
	if playerData.Quest.CurrentQuest then
		local questId = playerData.Quest.CurrentQuest
		local questProgress = playerData.Quest.Progress[questId]

		if questProgress and not questProgress.Completed then
			local questDef = MissionConfig.getMission(questId)

			if questDef then
				local wasComplete = isMissionComplete(questId, questProgress.Progress)

				for taskName, value in pairs(progressData) do
					if not questDef.Tasks[taskName] then continue end

					local current = questProgress.Progress[taskName]
					local required = questDef.Tasks[taskName]

					if taskName == "CashEarned" or taskName == "TotalCashEarned" then
						local currentBN = BigNum.new(current or "0")
						local addBN = BigNum.new(value)
						local requiredBN = BigNum.new(required)

						local newBN = currentBN + addBN
						if newBN:greaterThan(requiredBN) then
							newBN = requiredBN
						end

						questProgress.Progress[taskName] = newBN:toString()
					else
						local newValue = (current or 0) + value
						if newValue > required then
							newValue = required
						end

						questProgress.Progress[taskName] = newValue
					end
				end

				local isComplete = isMissionComplete(questId, questProgress.Progress)
				if isComplete and not wasComplete then
					questProgress.Completed = true
					questProgress.ClaimTime = tick()
					table.insert(completedMissions, {
						type = "Quest",
						id = questId,
						def = questDef,
					})
				end
			end
		end
	end

	-- Update achievements (same pattern)
	for missionId, missionProgress in pairs(playerData.Achievements.Progress) do
		if missionProgress.Completed then continue end

		local missionDef = MissionConfig.getMission(missionId)
		if not missionDef then continue end

		local wasComplete = isMissionComplete(missionId, missionProgress.Progress)

		for taskName, value in pairs(progressData) do
			if not missionDef.Tasks[taskName] then continue end
			
			local current = missionProgress.Progress[taskName]
			local required = missionDef.Tasks[taskName]

			if taskName == "CashEarned" or taskName == "TotalCashEarned" then
				local currentBN = BigNum.new(current or "0")
				local addBN = BigNum.new(value)
				local requiredBN = BigNum.new(required)

				local newBN = currentBN + addBN
				if newBN:greaterThan(requiredBN) then
					newBN = requiredBN
				end

				missionProgress.Progress[taskName] = newBN:toString()
			else
				local newValue = (current or 0) + value
				if newValue > required then
					newValue = required
				end
				missionProgress.Progress[taskName] = newValue
			end
		end

		local isComplete = isMissionComplete(missionId, missionProgress.Progress)
		if isComplete and not wasComplete then
			missionProgress.Completed = true
			missionProgress.ClaimTime = tick()
			table.insert(completedMissions, {
				type = "Achievement",
				id = missionId,
				def = missionDef,
			})
		end
	end

	-- Notify about completed missions
	for _, mission in ipairs(completedMissions) do
		Notifications.sendNotification(player, `Completed: {mission.def.Name}!`)
	end
end

function MissionManager.claimMission(player: Player, missionType: string, missionId: string): boolean
	local playerData = PlayerMissions[player]
	if not playerData then return false end

	local missionProgress
	if missionType == "Quest" then
		missionProgress = playerData.Quest.Progress[missionId]
	else
		local typeData = playerData[missionType]
		missionProgress = typeData and typeData.Progress[missionId]
	end

	if not missionProgress or not missionProgress.Completed then
		return false
	end

	-- Grant rewards
	local missionDef = MissionConfig.getMission(missionId)
	if missionDef and missionDef.Rewards then
		local playerObj = PlayerManager.getPlayerObject(player)
		if playerObj then
			if missionDef.Rewards.Cash then
				playerObj:adjustCurrency("Cash", missionDef.Rewards.Cash)
			end
			if missionDef.Rewards.Plutonium then
				playerObj:adjustCurrency("Plutonium", missionDef.Rewards.Plutonium)
			end
		end
	end

	-- Reset progress for repeatable missions
	if missionType ~= "Achievement" and missionType ~= "Quest" then
		missionProgress.Progress = {}
		missionProgress.Completed = false
		missionProgress.ClaimTime = nil
	end

	return true
end

--// Data Management //--

function MissionManager.loadPlayerData(player: Player, data: {})
	if not data or not next(data) then return end

	local playerData = PlayerMissions[player]
	if not playerData then return end

	-- Load timed missions
	for _, missionType in ipairs({"Daily", "Weekly", "Hourly"}) do
		if data[missionType] then
			playerData[missionType] = data[missionType]
		end
	end

	-- Load quest
	if data.Quest then
		playerData.Quest = data.Quest
	end

	-- Load achievements
	if data.Achievements then
		playerData.Achievements = data.Achievements
	end

	-- Check for resets
	checkAndResetMissions(player)
end

function MissionManager.savePlayerData(player: Player): {}
	local playerData = PlayerMissions[player]
	if not playerData then return {} end

	return {
		Daily = playerData.Daily,
		Weekly = playerData.Weekly,
		Hourly = playerData.Hourly,
		Quest = playerData.Quest,
		Achievements = playerData.Achievements,
	}
end

--// Auto-Reset System //--

------------------//MAIN FUNCTIONS
function MissionManager.getPlayerData(player: Player)
	return PlayerMissions[player]
end

function MissionManager._debugDump(player: Player)
	local pd = PlayerMissions[player]
	if not pd then
		return { ok = false, reason = "NoPlayerData" }
	end

	local hourlyId = pd.Hourly and pd.Hourly.Missions and pd.Hourly.Missions[1] or nil
	return {
		ok = true,
		hasDaily = pd.Daily ~= nil,
		hasWeekly = pd.Weekly ~= nil,
		hasHourly = pd.Hourly ~= nil,
		hourlyMission = hourlyId,
		hourlyReset = pd.Hourly and pd.Hourly.LastReset or nil,
	}
end


task.spawn(function()
	while true do
		task.wait(60) -- Check every minute

		for _, player in Players:GetPlayers() do
			checkAndResetMissions(player)
		end
	end
end)

UpdateMissionProgress.Event:Connect(MissionManager.updateProgress)

return MissionManager
