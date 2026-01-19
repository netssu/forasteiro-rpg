local DataService = {}

--// Services //--
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

--// Dependencies //--
local ProfileStore = require(script.ProfileStore)
local DefaultData = require(script.Parent.DataTemplate)

--// Variables //--
local devIndex = 13 -- datastore version number for studio
local gameIndex = 7 -- datastore version number for game

local MaxWaitForProfile = 1

local isStudio = RunService:IsStudio()

local dataName = isStudio and `Studio{devIndex}` or `Beta{gameIndex}`

local PlayerStore = ProfileStore.New(dataName, DefaultData)

DataService.Profiles = {}
DataService.Leaderboards = {}

export type Data = typeof(DefaultData)

export type entry = {
	UserId: number,
	Value: any
}

--// Functions

local function LoadProfile(player: Player): Data
	local key = "Player_" .. player.UserId
	local profile = PlayerStore:StartSessionAsync(key, {
		Cancel = function()
			return player.Parent ~= Players
		end
	})
	if not profile then
		-- replace with automatic rejoin later
		player:Kick("Data load fail")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	--[[
	profile.OnSessionEnd:Connect(function()
		DataService.Profiles[player.UserId] = nil
		player:Kick("Profile session ended")
	end)
	]]--

	if player.Parent == Players then
		DataService.Profiles[player.UserId] = profile
	else
		profile:EndSession()
	end

	--// CORREÇÃO AQUI: Retornar o profile, não profile.Data
	return profile 
end

local function SaveProfile(player: Player)
	local profile = DataService.Profiles[player.UserId]
	if profile then
		profile:EndSession()
		DataService.Profiles[player.UserId] = nil

		return profile.Data
	end
end

local function GetData(player: Player): Data
	local profile = DataService.Profiles[player.UserId]

	local startTick = tick()

	while not profile do
		task.wait(0.1)
		profile = DataService.Profiles[player.UserId]

		if tick() - startTick >= MaxWaitForProfile and not profile then return nil end
	end

	return profile.Data
end

-- varargs will be array with value to set as the final arg
local function SetData(player: Player, ...)
	local profile = DataService.Profiles[player.UserId]
	if not profile then return end

	local args = {...}
	if #args < 2 then return end

	local value = args[#args]
	local tbl = profile.Data

	for i = 1, #args - 1 do
		local key = args[i]
		if not tbl[key] then
			tbl[key] = {}
		end
		tbl = tbl[key]
	end

	local finalKey = args[#args - 1]
	if typeof(tbl) == "table" then
		tbl[args[#args - 1]] = value
	end
end

local function AddData(player: Player, ...)
	local profile = DataService.Profiles[player.UserId]
	if not profile then return end

	local args = {...}
	if #args < 2 then return end

	local value = args[#args]
	local tbl = profile.Data

	for i = 1, #args - 1 do
		local key = args[i]
		if not tbl[key] then
			tbl[key] = {}
		end
		tbl = tbl[key]
	end

	table.insert(tbl, value)
end

-- leaderboard
local function RegisterLeaderboard(leaderboardName: string): OrderedDataStore
	leaderboardName = leaderboardName .. dataName

	local leaderboard = DataService.Leaderboards[leaderboardName]
	if leaderboard then return leaderboard end

	leaderboard = DataStoreService:GetOrderedDataStore(leaderboardName)
	DataService.Leaderboards[leaderboardName] = leaderboard

	return leaderboard
end

local function GetLeaderboard(leaderboardName: string): OrderedDataStore
	return RegisterLeaderboard(leaderboardName)
end

local function UpdateLeaderboard(player: Player, leaderboardName: string, value: any): boolean
	local leaderboard = GetLeaderboard(leaderboardName)

	local success, err = pcall(function()
		leaderboard:SetAsync(player.UserId, value)
	end)

	if not success then
		warn(`[DataService] Failed to update leaderboard {leaderboardName} for {player.Name}: {err}`, value)
		return false
	end

	return true
end

local function GetLeaderboardData(leaderboardName: string, ascending: boolean, pageSize: number): {entry?}
	local leaderboard = GetLeaderboard(leaderboardName)

	local success, pages = pcall(function()
		return leaderboard:GetSortedAsync(ascending or false, pageSize or 10)
	end)

	if not success then
		warn(`[DataService] Failed to get leaderboard data for {leaderboardName}: {pages}`)
		return {}
	end

	local data = {}
	local entries = pages:GetCurrentPage()

	for _, entry in entries do
		table.insert(data, {
			UserId = entry.key,
			Value = entry.value
		})
	end

	return data
end

DataService.GetData = GetData
DataService.SetData = SetData
DataService.AddData = AddData
DataService.LoadProfile = LoadProfile
DataService.SaveProfile = SaveProfile
DataService.RegisterLeaderboard = RegisterLeaderboard
DataService.GetLeaderboardData = GetLeaderboardData
DataService.UpdateLeaderboard = UpdateLeaderboard
DataService.GetLeaderboard = GetLeaderboard

RegisterLeaderboard("CashLeaderboard")
RegisterLeaderboard("PlutoniumLeaderboard")

return DataService