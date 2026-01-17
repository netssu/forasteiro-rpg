local PlayerDataService = {}
local ProfileTemplate = {
	Coins = 0,
	Wins = 0,
	Streak = 0,
	PastStreak = 0,
	Vip = false,
	Multiplier = 1,
	Emotes = {},
	MoneyUpgradeMultiplier = 0,
	PotLuckMultiplier = 1,
	LikeRewardVisible = false,
	ClaimedLikeReward = false,
	CanClaimLikeReward = false,
	DoubleStreak = false,
	GoldenMug = false,
	DoubleWins = false,
	StarterPack = false,
	EquippedCups = "Default",
	EquippedBalls = "Default",
	CupsInventory = { "Default" },
	BallsInventory = { "Default" },
}
----- Loaded Modules -----
local ProfileService = require(script.Parent.Parent.Packages.ProfileService)
----- Private Variables -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local storeName = game:GetService("RunService"):IsStudio() and "PlayerData.V1" or "PlayerDataV10"
local ProfileStore = ProfileService.GetProfileStore("PlayerDataV10", ProfileTemplate)
--local ProfileStore = ProfileService.GetProfileStore("TEST_PlayerDataV3", ProfileTemplate)
local Profiles = {} -- [player] = profile
local connections = {}

-- Store leaderboard references for updates
local LeaderboardFrames = {
	Wins = nil,
	Streak = nil,
}

----- Private Functions -----

-- Helper function to validate numeric values
local function IsValidNumber(value)
	if type(value) ~= "number" then
		return false
	end
	-- Check for NaN (NaN ~= NaN)
	if value ~= value then
		return false
	end
	-- Check for infinity
	if value == math.huge or value == -math.huge then
		return false
	end
	return true
end

local function MakeLeaderstats(plr, profile)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = plr

	local Coins = Instance.new("NumberValue")
	Coins.Name = "Coins"
	Coins.Value = profile.Data.Coins
	Coins.Parent = leaderstats

	local Wins = Instance.new("NumberValue")
	Wins.Name = "Wins"
	Wins.Value = profile.Data.Wins
	Wins.Parent = leaderstats

	local Streak = Instance.new("NumberValue")
	Streak.Name = "Streak"
	Streak.Value = profile.Data.Streak
	Streak.Parent = leaderstats

	local playerConnections = connections[plr]

	table.insert(playerConnections, Coins:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = Coins.Value

		if IsValidNumber(newValue) and profile.Data.Coins ~= newValue then
			profile.Data.Coins = newValue
		elseif not IsValidNumber(newValue) then
			warn("[PlayerDataService]: Invalid Coins value detected: " .. tostring(newValue))
			Coins.Value = profile.Data.Coins -- Revert to last valid value
		end
	end))

	table.insert(playerConnections, Wins:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = Wins.Value

		if IsValidNumber(newValue) and profile.Data.Wins ~= newValue then
			profile.Data.ChristmasWins = profile.Data.ChristmasWins + 1

			if plr.PlayerStats.DoubleWins.Value == true then
				profile.Data.Wins = newValue + 1
				Wins.Value = newValue + 1
			else
				profile.Data.Wins = newValue
			end
			-- Update OrderedDataStore when Wins changes
			UpdateOrderedDataStore(plr.UserId, "Wins", newValue)
		elseif not IsValidNumber(newValue) then
			warn("[PlayerDataService]: Invalid Wins value detected: " .. tostring(newValue))
			Wins.Value = profile.Data.Wins
		end
	end))

	table.insert(playerConnections, Streak:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = Streak.Value

		if IsValidNumber(newValue) and profile.Data.Streak ~= newValue then
			if plr.PlayerStats.DoubleStreak.Value == true then
				profile.Data.Streak = newValue + 1
				Streak.Value = newValue + 1
			else
				profile.Data.Streak = newValue
			end

			-- Update OrderedDataStore when Streak changes
			UpdateOrderedDataStore(plr.UserId, "Streak", newValue)
		elseif not IsValidNumber(newValue) then
			warn("[PlayerDataService]: Invalid Streak value detected: " .. tostring(newValue))
			Streak.Value = profile.Data.Streak
		end
	end))

	return leaderstats
end

local function MakePlayerStats(plr, profile)
	local PlayerStats = Instance.new("Folder")
	PlayerStats.Name = "PlayerStats"
	PlayerStats.Parent = plr

	local EquippedCups = Instance.new("StringValue")
	EquippedCups.Name = "EquippedCups"
	EquippedCups.Value = profile.Data.EquippedCups
	EquippedCups.Parent = PlayerStats

	local EquippedBalls = Instance.new("StringValue")
	EquippedBalls.Name = "EquippedBalls"
	EquippedBalls.Value = profile.Data.EquippedBalls
	EquippedBalls.Parent = PlayerStats

	local Vip = Instance.new("BoolValue")
	Vip.Name = "Vip"
	Vip.Value = profile.Data.Vip
	Vip.Parent = PlayerStats

	local Multiplier = Instance.new("NumberValue")
	Multiplier.Name = "Multiplier"
	Multiplier.Value = profile.Data.Multiplier
	Multiplier.Parent = PlayerStats

	local PotLuckMultiplier = Instance.new("NumberValue")
	PotLuckMultiplier.Name = "PotLuckMultiplier"
	PotLuckMultiplier.Value = profile.Data.PotLuckMultiplier
	PotLuckMultiplier.Parent = PlayerStats

	local Stakes = Instance.new("NumberValue")
	Stakes.Name = "Stakes"
	Stakes.Value = 0
	Stakes.Parent = PlayerStats

	local PastStreak = Instance.new("NumberValue")
	PastStreak.Name = "PastStreak"
	PastStreak.Value = profile.Data.PastStreak
	PastStreak.Parent = PlayerStats

	local EarnedMoney = Instance.new("NumberValue")
	EarnedMoney.Name = "EarnedMoney"
	EarnedMoney.Value = 0
	EarnedMoney.Parent = PlayerStats

	local MoneyUpgradeMultiplier = Instance.new("NumberValue")
	MoneyUpgradeMultiplier.Name = "MoneyUpgradeMultiplier"
	MoneyUpgradeMultiplier.Value = profile.Data.MoneyUpgradeMultiplier
	MoneyUpgradeMultiplier.Parent = PlayerStats

	local StarterPack = Instance.new("BoolValue")
	StarterPack.Name = "StarterPack"
	StarterPack.Value = profile.Data.StarterPack
	StarterPack.Parent = PlayerStats

	local GoldenMug = Instance.new("BoolValue")
	GoldenMug.Name = "GoldenMug"
	GoldenMug.Value = profile.Data.GoldenMug
	GoldenMug.Parent = PlayerStats

	local DoubleStreak = Instance.new("BoolValue")
	DoubleStreak.Name = "DoubleStreak"
	DoubleStreak.Value = profile.Data.DoubleStreak
	DoubleStreak.Parent = PlayerStats

	local DoubleWins = Instance.new("BoolValue")
	DoubleWins.Name = "DoubleWins"
	DoubleWins.Value = profile.Data.DoubleWins
	DoubleWins.Parent = PlayerStats

	local playerConnections = connections[plr]

	table.insert(playerConnections, DoubleStreak:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = DoubleStreak.Value

		if profile.Data.DoubleStreak ~= newValue then
			profile.Data.DoubleStreak = newValue
		end
	end))

	table.insert(playerConnections, DoubleWins:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = DoubleWins.Value

		if profile.Data.DoubleWins ~= newValue then
			profile.Data.DoubleWins = newValue
		end
	end))

	table.insert(playerConnections, Vip:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = Vip.Value

		if profile.Data.Vip ~= newValue then
			profile.Data.Vip = newValue
		end
	end))

	table.insert(playerConnections, StarterPack:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = StarterPack.Value

		if profile.Data.StarterPack ~= newValue then
			profile.Data.StarterPack = newValue
		end
	end))

	table.insert(playerConnections, GoldenMug:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = GoldenMug.Value

		if profile.Data.GoldenMug ~= newValue then
			profile.Data.GoldenMug = newValue
		end
	end))

	-- dont uncomment, else it will stack up boosts
	--  table.insert(playerConnections, Multiplier:GetPropertyChangedSignal("Value"):Connect(function()
	--  local newValue = Multiplier.Value
	--	if IsValidNumber(newValue) and profile.Data.Multiplier ~= newValue then
	--		profile.Data.Multiplier = newValue
	--	elseif not IsValidNumber(newValue) then
	--		warn("[PlayerDataService]: Invalid Multiplier value detected: " .. tostring(newValue))
	--		Multiplier.Value = profile.Data.Multiplier
	--	end
	--  end))

	table.insert(playerConnections, PastStreak:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = PastStreak.Value

		if IsValidNumber(newValue) and profile.Data.PastStreak ~= newValue then
			profile.Data.PastStreak = newValue
		elseif not IsValidNumber(newValue) then
			warn("[PlayerDataService]: Invalid PastStreak value detected: " .. tostring(newValue))
			PastStreak.Value = profile.Data.PastStreak
		end
	end))

	table.insert(playerConnections, MoneyUpgradeMultiplier:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = MoneyUpgradeMultiplier.Value

		if IsValidNumber(newValue) and profile.Data.MoneyUpgradeMultiplier ~= newValue then
			profile.Data.MoneyUpgradeMultiplier = newValue
		elseif not IsValidNumber(newValue) then
			warn("[PlayerDataService]: Invalid MoneyUpgradeMultiplier value detected: " .. tostring(newValue))
			MoneyUpgradeMultiplier.Value = profile.Data.MoneyUpgradeMultiplier
		end
	end))

	table.insert(playerConnections, PotLuckMultiplier:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = PotLuckMultiplier.Value

		if IsValidNumber(newValue) and profile.Data.PotLuckMultiplier ~= newValue then
			profile.Data.PotLuckMultiplier = newValue
		elseif not IsValidNumber(newValue) then
			warn("[PlayerDataService]: Invalid PotLuckMultiplier value detected: " .. tostring(newValue))
			PotLuckMultiplier.Value = profile.Data.PotLuckMultiplier
		end
	end))

	table.insert(playerConnections, EquippedCups:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = EquippedCups.Value

		if profile.Data.EquippedCups ~= newValue then
			profile.Data.EquippedCups = newValue
		end
	end))

	table.insert(playerConnections, EquippedBalls:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = EquippedBalls.Value

		if profile.Data.EquippedBalls ~= newValue then
			profile.Data.EquippedBalls = newValue
		end
	end))

	return PlayerStats
end

local function GiveCash(profile, amount)
	-- If "Coins" was not defined in the ProfileTemplate at game launch,
	--   you will have to perform the following:
	if profile.Data.Coins == nil then
		profile.Data.Coins = 0
	end
	-- Increment the "Coins" value:
	profile.Data.Coins = profile.Data.Coins + amount
end

local function DoSomethingWithALoadedProfile(player, profile)
	if profile.Data.LogInTimes == nil then
		profile.Data.LogInTimes = 0
	end
	profile.Data.LogInTimes = profile.Data.LogInTimes + 1
	print(
		player.Name
			.. " has logged in "
			.. tostring(profile.Data.LogInTimes)
			.. " time"
			.. ((profile.Data.LogInTimes > 1) and "s" or "")
	)
	print(player.Name .. " owns " .. tostring(profile.Data.Coins) .. " coins now!")
end

local function onPlayerAdded(player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)
	if profile ~= nil then
		profile:AddUserId(player.UserId) -- GDPR compliance
		profile:Reconcile() -- Fill in missing variables from ProfileTemplate (optional)

		profile:ListenToRelease(function()
			Profiles[player] = nil
			-- The profile could've been loaded on another Roblox server:
			player:Kick()
		end)
		if player:IsDescendantOf(Players) == true then
			Profiles[player] = profile
			connections[player] = {}
			-- Create leaderstats and playerstats with listeners
			MakeLeaderstats(player, profile)
			MakePlayerStats(player, profile)
			-- Update OrderedDataStore for this player immediately
			PlayerDataService.UpdateLeaderboardStats(player.UserId, profile)
			-- A profile has been successfully loaded:
		else
			-- Player left before the profile loaded:
			profile:Release()
			player:Kick()
		end
	else
		-- The profile couldn't be loaded possibly due to other
		-- Roblox servers trying to load this profile at the same time:
		player:Kick()
	end
end

local function onPlayerRemoving(player)
	if not connections[player] then
		return
	end

	for _, connection in connections[player] do
		connection:Disconnect()
		connection = nil
	end

	connections[player] = nil

	local profile = Profiles[player]

	if profile ~= nil then
		-- Update OrderedDataStore before releasing
		PlayerDataService.UpdateLeaderboardStats(player.UserId, profile)
		profile:Release()
	end
end

local function GetData(player)
	local profile = Profiles[player]
	if profile then
		return profile.Data
	end
	return nil
end

----- Public Functions -----

function PlayerDataService.GetDataRemote(player)
	local data = GetData(player)
	if data then
		return data
	else
		warn("No data found for player: " .. player.Name)
		return nil
	end
end

-- Function to add an item to a table data value
function PlayerDataService.AddToTable(player, dataKey, item)
	local profile = Profiles[player]
	if not profile then
		local i = 1
		repeat
			i += 1
			print("retrying for profile!")
			profile = Profiles[player]
			task.wait(0.5)
		until profile or i > 20
		warn("[PlayerDataService]: No profile found for " .. player.Name)
		if not profile then
			return false
		end
	end

	-- Check if the dataKey exists and is a table
	if profile.Data[dataKey] == nil then
		warn("[PlayerDataService]: Data key '" .. dataKey .. "' does not exist")
		return false
	end

	if type(profile.Data[dataKey]) ~= "table" then
		warn("[PlayerDataService]: Data key '" .. dataKey .. "' is not a table")
		return false
	end

	-- Check if item already exists
	for _, v in ipairs(profile.Data[dataKey]) do
		if v == item then
			warn("[PlayerDataService]: Item '" .. tostring(item) .. "' already exists in " .. dataKey)
			return false
		end
	end

	-- Add the item
	table.insert(profile.Data[dataKey], item)
	return true
end

-- Function to remove an item from a table data value
function PlayerDataService.RemoveFromTable(player, dataKey, item)
	local profile = Profiles[player]
	if not profile then
		local i = 1
		repeat
			i += 1
			print("retrying for profile!")
			profile = Profiles[player]
			task.wait(0.5)
		until profile or i > 20
		warn("[PlayerDataService]: No profile found for " .. player.Name)
		if not profile then
			return false
		end
	end

	-- Check if the dataKey exists and is a table
	if profile.Data[dataKey] == nil then
		warn("[PlayerDataService]: Data key '" .. dataKey .. "' does not exist")
		return false
	end

	if type(profile.Data[dataKey]) ~= "table" then
		warn("[PlayerDataService]: Data key '" .. dataKey .. "' is not a table")
		return false
	end

	-- Find and remove the item
	for i, v in ipairs(profile.Data[dataKey]) do
		if v == item then
			table.remove(profile.Data[dataKey], i)
			return true
		end
	end

	warn("[PlayerDataService]: Item '" .. tostring(item) .. "' not found in " .. dataKey)
	return false
end

-- Function to check if an item exists in a table data value
function PlayerDataService.IsInTable(player, dataKey, item)
	local profile = Profiles[player]
	if not profile then
		local i = 1
		repeat
			i += 1
			print("retrying for profile!")
			profile = Profiles[player]
			task.wait(0.5)
		until profile or i > 20
		warn("[PlayerDataService]: No profile found for " .. player.Name)
		if not profile then
			return false
		end
	end

	-- Check if the dataKey exists and is a table
	if profile.Data[dataKey] == nil then
		warn("[PlayerDataService]: Data key '" .. dataKey .. "' does not exist")
		return false
	end

	if type(profile.Data[dataKey]) ~= "table" then
		warn("[PlayerDataService]: Data key '" .. dataKey .. "' is not a table")
		return false
	end

	-- Check if item exists
	for _, v in ipairs(profile.Data[dataKey]) do
		if v == item then
			return true
		end
	end

	return false
end

function PlayerDataService.SetData(player, dataKey, value)
	local profile = Profiles[player]
	if not profile then
		local i = 1
		repeat
			i += 1
			print("retrying for profile!")
			profile = Profiles[player]
			task.wait(0.5)
		until profile or i > 20
		warn("[PlayerDataService]: No profile found for " .. player.Name)
		if not profile then
			return false
		end
	end

	-- Check if the dataKey exists in ProfileTemplate
	if profile.Data[dataKey] == nil then
		warn("[PlayerDataService]: Data key '" .. dataKey .. "' does not exist in profile")
		return false
	end

	-- Check if the value type matches the template type
	local expectedType = type(profile.Data[dataKey])
	local valueType = type(value)

	if expectedType ~= valueType then
		warn(
			"[PlayerDataService]: Type mismatch for '"
				.. dataKey
				.. "'. Expected "
				.. expectedType
				.. ", got "
				.. valueType
		)
		return false
	end

	-- Validate numeric values
	if valueType == "number" and not IsValidNumber(value) then
		warn("[PlayerDataService]: Invalid number value for '" .. dataKey .. "': " .. tostring(value))
		return false
	end

	-- Set the value
	profile.Data[dataKey] = value

	if dataKey == "Coins" then
		player.leaderstats.Coins.Value = value
	end

	return true
end

-- Function to get any data value
function PlayerDataService.GetDataValue(player, dataKey)
	local profile = Profiles[player]
	if not profile then
		local i = 1
		repeat
			i += 1
			print("retrying for profile!")
			profile = Profiles[player]
			task.wait(0.5)
		until profile or i > 20
		warn("[PlayerDataService]: No profile found for " .. player.Name)
		if not profile then
			return nil
		end
	end

	-- Check if the dataKey exists
	if profile.Data[dataKey] == nil then
		warn("[PlayerDataService]: Data key '" .. dataKey .. "' does not exist")
		return nil
	end

	return profile.Data[dataKey]
end

-- Function to increment a numeric data value
function PlayerDataService.IncrementData(player, dataKey, amount)
	local profile = Profiles[player]
	if not profile then
		local i = 1
		repeat
			i += 1
			print("retrying for profile!")
			profile = Profiles[player]
			task.wait(0.5)
		until profile or i > 20
		warn("[PlayerDataService]: No profile found for " .. player.Name)
		if not profile then
			return false
		end
	end

	-- Check if the dataKey exists
	if profile.Data[dataKey] == nil then
		warn("[PlayerDataService]: Data key '" .. dataKey .. "' does not exist")
		return false
	end

	-- Check if it's a number
	if type(profile.Data[dataKey]) ~= "number" then
		warn("[PlayerDataService]: Data key '" .. dataKey .. "' is not a number")
		return false
	end

	-- Validate the amount
	if not IsValidNumber(amount) then
		warn("[PlayerDataService]: Invalid increment amount for '" .. dataKey .. "': " .. tostring(amount))
		return false
	end

	-- Increment the value
	local newValue = profile.Data[dataKey] + amount

	-- Validate the result
	if not IsValidNumber(newValue) then
		warn("[PlayerDataService]: Increment would create invalid value for '" .. dataKey .. "'")
		return false
	end

	profile.Data[dataKey] = newValue
	return true
end

-- Function to get all items in a table data value
function PlayerDataService.GetTable(player, dataKey)
	local profile = Profiles[player]
	if not profile then
		local i = 1
		repeat
			i += 1
			print("retrying for profile!")
			profile = Profiles[player]
			task.wait(0.5)
		until profile or i > 20
		warn("[PlayerDataService]: No profile found for " .. player.Name)
		if not profile then
			return nil
		end
	end

	-- Check if the dataKey exists and is a table
	if profile.Data[dataKey] == nil then
		warn("[PlayerDataService]: Data key '" .. dataKey .. "' does not exist")
		return nil
	end

	if type(profile.Data[dataKey]) ~= "table" then
		warn("[PlayerDataService]: Data key '" .. dataKey .. "' is not a table")
		return nil
	end

	-- Return a copy of the table
	local copy = {}
	for i, v in ipairs(profile.Data[dataKey]) do
		copy[i] = v
	end
	return copy
end

-- Function to create and populate a global leaderboard using OrderedDataStore
function PlayerDataService.CreateLeaderboard(parent, dataKey, maxPlayers)
	-- Get the PlayerFrame template
	local playerFrameTemplate = ReplicatedStorage.Assets.LeaderboardAssets.PlayerFrame

	-- Clear existing frames in parent
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Get the OrderedDataStore for this stat - Match the ProfileStore version
	local orderedStore = DataStoreService:GetOrderedDataStore("PlayerDataV9_" .. dataKey)

	local success, pages = pcall(function()
		return orderedStore:GetSortedAsync(false, maxPlayers) -- false = descending order
	end)

	if not success then
		warn("[PlayerDataService]: Failed to fetch leaderboard data for " .. dataKey)
		return
	end

	local currentPage = pages:GetCurrentPage()

	-- Create frames for top players
	for i, entry in ipairs(currentPage) do
		if i > maxPlayers then
			break
		end

		local userId = tonumber(string.match(entry.key, "Player_(%d+)"))
		local playerName = "Unknown"

		-- Try to get player name
		if userId then
			local success, result = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if success then
				playerName = result
			end
		end

		-- Clone the template
		local playerFrame = playerFrameTemplate:Clone()
		playerFrame.Name = "Player" .. i
		playerFrame.Parent = parent

		-- Set position (stack vertically)
		playerFrame.Position = UDim2.new(0, 0, 0, (i - 1) * playerFrame.Size.Y.Offset)

		-- Update text labels
		playerFrame.plrName.Text = playerName
		playerFrame.Place.Text = "#" .. tostring(i)
		playerFrame.Value.Text = tostring(entry.value)

		playerFrame.Visible = true
	end

	print("[PlayerDataService]: Leaderboard created for " .. dataKey .. " with " .. #currentPage .. " entries")
end

-- Function to update OrderedDataStore when player data changes
function UpdateOrderedDataStore(userId, dataKey, value)
	-- Validate the value before saving
	if not IsValidNumber(value) then
		warn("[PlayerDataService]: Invalid value for " .. dataKey .. " (User: " .. userId .. "): " .. tostring(value))
		return -- Don't save invalid values
	end

	local orderedStore = DataStoreService:GetOrderedDataStore("PlayerDataV9_" .. dataKey)
	local key = "Player_" .. userId

	local success, errorMessage = pcall(function()
		orderedStore:SetAsync(key, value)
	end)

	if success then
		print("[PlayerDataService]: Updated " .. dataKey .. " for User " .. userId .. " to " .. value)
	else
		warn("[PlayerDataService]: Failed to update OrderedDataStore for " .. dataKey .. ": " .. tostring(errorMessage))
	end
end

-- Hook into profile saves to update OrderedDataStore
function PlayerDataService.UpdateLeaderboardStats(userId, profile)
	-- Update each stat in the OrderedDataStore
	UpdateOrderedDataStore(userId, "Coins", profile.Data.Coins)
	UpdateOrderedDataStore(userId, "Wins", profile.Data.Wins)
	UpdateOrderedDataStore(userId, "Streak", profile.Data.Streak)
end

function PlayerDataService.GetProfile(player)
	local profile = Profiles[player]
	if not profile then
		local i = 1
		repeat
			i += 1
			print("retrying for profile!")
			profile = Profiles[player]
			task.wait(0.5)
		until profile or i > 20
		print(Profiles)
		print(Profiles[player])
		for Player, Data in ipairs(Profiles) do
			if Player == player then
				print("found")
			end
		end
		if not profile then
			warn("[PlayerDataService]: No profile found for " .. player.Name)
			return nil
		end
	end
	return profile
end

--[[
	Yields until the profile of one player becomes available. Then, if applicable, returns it.
	If the profile is not active, or the player left, immediately returns `nil`.
]]
function PlayerDataService.getOneProfileAsync(player: Player): any?
	local profile

	while not profile and player.Parent == Players do
		profile = PlayerDataService.GetProfile(player)

		if profile then
			break
		end

		task.wait()
	end

	if player.Parent ~= Players then
		return nil
	end

	if not profile or not profile:IsActive() then
		return nil
	end

	return profile
end

----- Initialize -----
function PlayerDataService.Handler()
	-- Store references to leaderboard frames
	LeaderboardFrames.Wins = workspace.WinsLeaderboard.Part.leaderboard.ScrollingFrame
	LeaderboardFrames.Streak = workspace.StreaksLeaderboard.Part.leaderboard.ScrollingFrame

	-- Initial leaderboard creation
	PlayerDataService.CreateLeaderboard(LeaderboardFrames.Wins, "Wins", 25)
	PlayerDataService.CreateLeaderboard(LeaderboardFrames.Streak, "Streak", 25)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Auto-update leaderboards periodically (every 30 seconds)
	task.spawn(function()
		while true do
			task.wait(30)
			-- Update OrderedDataStore for all online players
			for player, profile in pairs(Profiles) do
				if profile:IsActive() then
					PlayerDataService.UpdateLeaderboardStats(player.UserId, profile)
				end
			end

			-- Refresh the visual leaderboards
			PlayerDataService.CreateLeaderboard(LeaderboardFrames.Wins, "Wins", 25)
			PlayerDataService.CreateLeaderboard(LeaderboardFrames.Streak, "Streak", 25)

			print("[PlayerDataService]: Leaderboards refreshed")
		end
	end)

	local GetDataRemote = game.ReplicatedStorage.Remotes.Functions.GetData
	GetDataRemote.OnServerInvoke = function(player)
		return PlayerDataService.GetDataRemote(player)
	end
end

return PlayerDataService
