local PlayerData = {}

--// Services //--
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Dependencies //--
local Core = ServerScriptService.Core
local dataFolder = Core.Data
local TycoonManager 

local Shared = ReplicatedStorage.Shared
local Utilities = Shared.Utilities
local BigNum = require(Utilities.BigNum)

local DataService = require(dataFolder.DataService)
local DefaultData = require(dataFolder.DataTemplate)

-- // Variables //--
local leaderstatsValues = {
	{name = "Plutonium", key = "Plutonium", valueType = "StringValue", BigNum = true},
	{name = "Cash", key = "Cash", valueType = "StringValue", BigNum = true},
}

local valueConfig = {
	["Data"] = {
		{name = "Cash", key = "Cash", valueType = "StringValue"},
		{name = "Plutonium", key = "Plutonium", valueType = "StringValue"},
		{name = "PlayTime", key = "PlayTime", valueType = "NumberValue"},
		{name = "WorldNumber", key = "WorldNumber", valueType = "IntValue"},
		{name = "TutorialCompleted", key = "TutorialCompleted", valueType = "BoolValue"},
	},
}

export type valueData = {name:string, valueType:string, key:string, BigNum:boolean?,tag:string?}

--// Functions //--

-- Get value instance from player descendants
-- Can exclude a given instance if multiple of the same name exists
local function getValue(player: Player, name: string, exclude: Instance): ValueBase?
	for _, value in player:GetDescendants() do
		if not value:IsA("ValueBase") then continue end
		if value.Name ~= name then continue end
		if value == exclude then continue end

		return value
	end
end

-- Get value from data table
local function getKeyValue(tab: DataService.Data, name: string): any?
	for index, value in tab do
		if index == name then return value end
		
		if typeof(value) == "table" then
			local found = getKeyValue(value, name)
			
			-- error handling for if its nil maybe
			if found ~= nil then
				return found
			end
		end
	end
end

-- Set value in data table
local function setKeyValue(tab: DataService.Data, name: string, newValue: any): boolean
	for index, value in tab do
		if index == name then tab[index] = newValue return true end

		if typeof(value) == "table" then
			local updated = setKeyValue(value, name, newValue)
			
			if updated then
				return true
			end
		end
	end

	return false
end

-- Create value for player with actual data
-- Automatically updates data profile when changed
local function initValue(valueData: valueData, parent: Instance, data:DataService.Data)
	local value = Instance.new(valueData.valueType) :: ValueBase
	value.Name = valueData.name
	value.Parent = parent
	
	if valueData.tag then
		value:AddTag(valueData.tag)
	end

	local keyValue = getKeyValue(data, valueData.key)
	if keyValue == (nil or "") then
		warn(`[PlayerData] Invalid key for datavalues: {valueData.key}, using default`)
		keyValue = getKeyValue(DefaultData, valueData.key)
	end

	value.Value = keyValue
	
	if valueData.name == "PlayTime" then
		local conn = nil
		conn = task.spawn(function()
			while value do
				task.wait(1)
				value.Value += 1
			end
			if conn then
				conn:Disconnect()
			end
		end)
	end 
	
	value.Changed:Connect(function(value)
		setKeyValue(data, valueData.key, value)
	end)
end

-- Create leaderstats for display only
local function createLeaderstats(player: Player, data: DataService.Data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	for _, valueData in leaderstatsValues do
		local value = Instance.new(valueData.valueType)
		value.Name = valueData.name
		value.Parent = leaderstats
		
		local rawValue = getValue(player, valueData.key, value)
		local targetValue = rawValue and rawValue.Value

		value.Value = not valueData.BigNum and targetValue or BigNum.toString(BigNum.new(targetValue),2)
	
		rawValue.Changed:Connect(function(newValue)
			local formattedValue = newValue
			if valueData.BigNum then
				formattedValue = BigNum.toString(BigNum.new(newValue),2)
			end
			value.Value = formattedValue
		end)
	end
end

local function createValues(player: Player, data: DataService.Data)
	for valueType, valueMaps in valueConfig do
		local valueFolder = Instance.new("Folder")
		valueFolder.Name = valueType
		valueFolder.Parent = player
		
		for _, valueData in valueMaps do
			initValue(valueData, valueFolder,data)
		end
	end 
end

function PlayerData.loadPlayer(player: Player)
	local data = DataService.LoadProfile(player)
	if not data then return end
	
	for name, value in data.Attributes do
		player:SetAttribute(name, value)
	end

	createValues(player, data)
	createLeaderstats(player, data)
	
	player:SetAttribute("DataLoaded", true)
	
	return {
		Tycoon = data.Tycoon,
		Tools = data.Tools,
		Missions = data.Missions,
		PlayerStats = data.PlayerStats,
	}
end

function PlayerData.savePlayer(player: Player)
	local data = DataService.GetData(player)
	if not data then
		warn(`[PlayerData] Tried saving but data is nil: {player.Name}`)
		return
	end
	
	for name, value in player:GetAttributes() do
		if not data.Attributes[name] then continue end
		data.Attributes[name] = value
	end

	for _, dataFolder in player:GetChildren() do
		if not dataFolder:IsA("Folder") or dataFolder.Name == "leaderstats" then continue end
		
		for _, value in dataFolder:GetChildren() do
			if not value:IsA("ValueBase") then continue end

			setKeyValue(data, value.Name, value.Value)
		end
	end
	
	if not TycoonManager then 
		TycoonManager = require(Core.Tycoon.TycoonManager)
	end
	
	local tycoonData = TycoonManager.savePlayerData(player)
	if tycoonData then
		data.Tycoon = tycoonData
	end
	
	DataService.UpdateLeaderboard(player, "CashLeaderboard", BigNum.new(data.Cash):toOrderedDataStore())
	DataService.UpdateLeaderboard(player, "PlutoniumLeaderboard", BigNum.new(data.Plutonium):toOrderedDataStore())
	
	DataService.SaveProfile(player)

	--print(`[PlayerData] Saved data for: {player.Name}`, data)
end

PlayerData.GetData = DataService.GetData
PlayerData.AddData = DataService.AddData
PlayerData.SetData = DataService.SetData

return PlayerData
