local LeaderboardService = {}

-- // Services
local DataStoreService = game:GetService('DataStoreService')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- // Dependencies
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)

-- // Types
export type LeaderboardEntry = {
	Rank: string,
	UserId: string,
	Score: string,
}

export type LeaderboardRequest = {
	StatPath: string,
	Amount: number,
}

type OrderedDataStore = typeof(DataStoreService:GetOrderedDataStore(''))

-- // Variables
local STATS_TO_TRACK = {
	'Pinata.Level',
	'Currency.Coins',
	'Currency.RebirthCount',
	'Metadata.TotalPlayTime',
}

local LeaderboardStores: { [string]: OrderedDataStore } = {}

-- // Private Functions

--[=[
	Retrieves the value from a player's data at the specified stat path.
	
	@param player -- The player whose data to retrieve
	@param statPath -- Dot-separated path to the stat (e.g., "Currency.Coins")
	@return any -- The value at the specified path
	
	@private
]=]
local function getStatValue(player: Player, statPath: string): any
	local path = {}

	for segment in string.gmatch(statPath, '[^%.]+') do
		table.insert(path, segment)
	end

	return PlayerDataManager:Get(player, path)
end

--[=[
	Creates OrderedDataStores for each tracked stat.
	
	@private
]=]
local function createLeaderboardStores(): ()
	for _, stat in STATS_TO_TRACK do
		local storeName = `Leaderboard_{stat:gsub('%.', '_')}`
		LeaderboardStores[stat] =
			DataStoreService:GetOrderedDataStore(storeName)
	end
end

--[=[
	Updates a player's score in the leaderboard for a specific stat.
	
	@param statPath -- The stat path to update (e.g., "Currency.Coins")
	@param userId -- The user ID of the player
	@param score -- The new score value
	
	@private
]=]
local function updateLeaderboard(
	statPath: string,
	userId: number,
	score: number
): ()
	local leaderboard = LeaderboardStores[statPath]
	if not leaderboard then
		warn(`No leaderboard store found for stat: {statPath}`)
		return
	end

	local success, errorMessage = pcall(function()
		leaderboard:SetAsync(tostring(userId), score)
	end)

	if not success then
		warn(
			`Failed to update leaderboard for stat: {statPath}, error: {errorMessage}`
		)
	end
end

--[=[
	Sets up tracking for all stats for a player. Connects to value changed
	signals and updates the leaderboard when values change.
	
	@param player -- The player to set up tracking for
	
	@private
]=]
local function setupPlayerTracking(player: Player): ()
	for _, statPath in ipairs(STATS_TO_TRACK) do
		local path = {}

		for segment in string.gmatch(statPath, '[^%.]+') do
			table.insert(path, segment)
		end

		local valueChangedSignal =
			PlayerDataManager:GetValueChangedSignal(player, path)
		valueChangedSignal:Connect(function(newValue)
			updateLeaderboard(statPath, player.UserId, newValue)
		end)

		task.defer(function()
			local initialValue = getStatValue(player, statPath)
			if initialValue then
				updateLeaderboard(statPath, player.UserId, initialValue)
			end
		end)
	end
end

-- // Public Functions

--[=[
	Retrieves the top N players for a specific stat from the leaderboard.
	
	@param statPath -- The stat path to query (e.g., "Currency.Coins")
	@param amount -- Number of top players to retrieve (1-100)
	@return {LeaderboardEntry} -- Array of leaderboard entries with Rank, UserId, and Score
	
	**Example:**
    ```luau
	local topCoins = LeaderboardService.GetTop("Currency.Coins", 10)
	for _, entry in ipairs(topCoins) do
		print(entry.Rank, entry.UserId, entry.Score)
	end
    ```
]=]
function LeaderboardService.GetTop(
	statPath: string,
	amount: number
): { LeaderboardEntry }
	local leaderboard = LeaderboardStores[statPath]
	if not leaderboard then
		warn(`No leaderboard store found for stat: {statPath}`)
		return {}
	end

	amount = math.clamp(amount, 1, 100)

	local success, pages = pcall(function()
		return leaderboard:GetSortedAsync(false, amount)
	end)

	if not success then
		warn(
			`Failed to retrieve leaderboard for stat: {statPath}, error: {pages}`
		)
		return {}
	end

	local topEntries = pages:GetCurrentPage()
	local results: { LeaderboardEntry } = {}

	for rank, entry in ipairs(topEntries) do
		table.insert(results, {
			UserId = tostring(entry.key),
			Score = tostring(entry.value),
			Rank = tostring(rank),
		})
	end

	return results
end

--[=[
	Gets a player's rank on the leaderboard for a specific stat.
	
	@param player -- The player to get the rank for
	@param statPath -- The stat path to query (e.g., "Currency.Coins")
	@return number? -- The player's rank (1-indexed), or nil if not found
	
	**Example:**
    ```luau
	local rank = LeaderboardService.GetPlayerRank(player, "Currency.Coins")
	if rank then
		print(`You are rank #{rank}!`)
	end
    ```
]=]
function LeaderboardService.GetPlayerRank(
	player: Player,
	statPath: string
): number?
	local leaderboard = LeaderboardStores[statPath]
	if not leaderboard then
		warn(`No leaderboard store found for stat: {statPath}`)
		return nil
	end

	local success, score = pcall(function()
		return leaderboard:GetAsync(tostring(player.UserId))
	end)

	if not success or not score then
		warn(
			`Failed to retrieve player rank for stat: {statPath}, error: {score}`
		)
		return nil
	end

	local pagesAbove = leaderboard:GetSortedAsync(false, 100)
	local rank = 1

	for _, data in ipairs(pagesAbove:GetCurrentPage()) do
		if data.key == tostring(player.UserId) then return rank end
		rank += 1
	end

	return nil
end

--[=[
	Initializes the LeaderboardService. Creates leaderboard stores, sets up
	player tracking, and configures the network packet handler.
	
	**Must be called once on server startup.**
	
	**Example:**
    ```luau
	LeaderboardService.Init()
    ```
]=]
function LeaderboardService.Init(): ()
	createLeaderboardStores()

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(setupPlayerTracking, player)
	end

	Players.PlayerAdded:Connect(setupPlayerTracking)

	Packets.Leaderboard.OnServerInvoke = function(
		player: Player,
		action: string,
		data: { any }
	): { LeaderboardEntry }?
		if action == 'GetTop' then
			local statPath: string? = data.StatPath
			local amount: number? = data.Amount

			if typeof(statPath) ~= 'string' or typeof(amount) ~= 'number' then
				warn(
					`Invalid data received for GetTop from {player.Name}: {data}`
				)
				return {}
			end

			local topEntries = LeaderboardService.GetTop(statPath, amount)
			return topEntries
		end

		return {}
	end
end

export type LeaderboardService = typeof(LeaderboardService)

return LeaderboardService
