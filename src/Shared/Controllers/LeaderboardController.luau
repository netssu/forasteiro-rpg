local LeaderboardController = {}

-- // Services
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- // Folders
local Packages = ReplicatedStorage:WaitForChild('Packages')
local Modules = ReplicatedStorage:WaitForChild('Modules')
local GameModules = Modules:WaitForChild('Game')
local Assets = ReplicatedStorage:WaitForChild('Assets')
local Models = Assets:WaitForChild('Models')

--// Dependencies
local Abbreviate =
	require(Modules:WaitForChild('Math'):WaitForChild('Abbreviate'))
local Packets = require(GameModules:WaitForChild('Packets'))
local PlayerDataManager = require(Packages:WaitForChild('PlayerDataManager'))

-- // Types
type LeaderboardEntry = {
	Rank: string,
	UserId: string,
	Score: string,
}

-- // Variables
local localPlayer = Players.LocalPlayer
local activeLeaderboards = {} :: {
	[Model]: {
		statPath: string,
		scrollingFrame: ScrollingFrame,
		localPlayerFrame: Frame,
	},
}
local UPDATE_INTERVAL = 60

-- // Private Functions

--[=[
	Applies a color gradient to a TextLabel based on the specified type.
	
	@param textLabel -- The TextLabel to apply the gradient to
	@param gradientType -- Type of gradient: "gold", "silver", "bronze", or "score"
	
	@private
]=]
local function applyGradient(textLabel: TextLabel, gradientType: string): ()
	local gradient = Instance.new('UIGradient')

	if gradientType == 'gold' then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 185, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(218, 165, 32)),
		})
	elseif gradientType == 'silver' then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 230, 230)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(192, 192, 192)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(169, 169, 169)),
		})
	elseif gradientType == 'bronze' then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(205, 127, 50)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(184, 115, 51)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 90, 40)),
		})
	elseif gradientType == 'score' then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 129, 122)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 10, 10)),
		})
	end

	gradient.Rotation = 90
	gradient.Parent = textLabel
end

--[=[
	Sets up the leaderboard header with the appropriate title and emoji.
	
	@param header -- The header part of the leaderboard model
	
	@private
]=]
local function setupHeader(header: BasePart): ()
	local surfaceGui = header:FindFirstChildWhichIsA('SurfaceGui')
	if not surfaceGui then
		warn('[LeaderboardController] - SurfaceGui not found in header!')
		return
	end

	local frame = surfaceGui:FindFirstChildWhichIsA('Frame')
	if not frame then
		warn('[LeaderboardController] - Frame not found in SurfaceGui!')
		return
	end

	local textLabel = frame:FindFirstChildWhichIsA('TextLabel')
	if not textLabel then
		warn('[LeaderboardController] - TextLabel not found in Frame!')
		return
	end

	local leaderboardAttribute = header.Parent:GetAttribute('Leaderboard')
	if not leaderboardAttribute then
		warn(
			"[LeaderboardController] - Leaderboard attribute not found on header's parent!"
		)
		return
	end

	local headerEmojis = {
		['Pinata_Level'] = '📊',
		['Coins'] = '💰',
		['Rebirth'] = '🔁',
		['PlayTime'] = '⏱️',
	}

	local emoji = headerEmojis[leaderboardAttribute]
	leaderboardAttribute = leaderboardAttribute == 'Pinata_Level'
		and 'Pinata Level'
		or leaderboardAttribute
	local text = emoji and `{emoji} {leaderboardAttribute}`
		or leaderboardAttribute

	textLabel.Text = text
end

--[=[
	Retrieves a stat value from a player's data using a dot-separated path.
	
	@param player -- The player to get data from
	@param valuePath -- Dot-separated path to the stat (e.g., "Currency.Coins")
	@return any -- The value at the specified path
	
	@private
]=]
local function getStatValue(player: Player, valuePath: string): any
	local path = {}

	for segment in string.gmatch(valuePath, '[^%.]+') do
		table.insert(path, segment)
	end

	return PlayerDataManager:Get(player, path)
end

--[=[
	Sets up a single leaderboard entry with player information and ranking.
	
	@param entry -- The Frame to populate with entry data
	@param rank -- The player's rank on the leaderboard
	@param userId -- The player's UserId
	@param score -- The player's score
	
	@private
]=]
local function setupEntry(
	entry: Frame,
	rank: number,
	userId: number?,
	score: number
): ()
	print(entry)
	local info = entry:FindFirstChild('Info')
	if not info then
		warn('[LeaderboardController] - Info folder not found in entry model!')
		return
	end

	local rankLabel = info:FindFirstChild('Rank')
	local nameLabel = info:FindFirstChild('PlayerName')
	local playerImageLabel = info:FindFirstChild('PlayerImage')
	local scoreLabel = entry:FindFirstChild('Value')

	if not (rankLabel and nameLabel and scoreLabel) then
		warn(
			'[LeaderboardController] - One or more labels (Rank, Name, Score) not found in entry model!'
		)
		return
	end

	if typeof(userId) ~= 'number' or userId <= 0 then
		return
	end

	-- Fetch player information
	local playerName = tostring(userId)
	local nameSuccess, nameResult = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if nameSuccess and typeof(nameResult) == 'string' and nameResult ~= '' then
		playerName = nameResult
	end

	local image = ''
	local imageSuccess, imageResult = pcall(function()
		return Players:GetUserThumbnailAsync(
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size48x48
		)
	end)
	if imageSuccess and typeof(imageResult) == 'string' then
		image = imageResult
	end

	-- Setup entry display
	entry.LayoutOrder = rank
	nameLabel.Text = playerName
	playerImageLabel.Image = image

	scoreLabel.Text = Abbreviate(score)
	applyGradient(scoreLabel, 'score')

	-- Special handling for local player
	if userId == localPlayer.UserId and entry.Name == 'Frame' then
		rankLabel.Visible = false
		return
	end

	-- Setup rank display with gradient for top 3
	rankLabel.Text = `#{tostring(rank)}`
	if rank == 1 then
		applyGradient(rankLabel, 'gold')
		rankLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	elseif rank == 2 then
		applyGradient(rankLabel, 'silver')
		rankLabel.TextColor3 = Color3.fromRGB(192, 192, 192)
	elseif rank == 3 then
		applyGradient(rankLabel, 'bronze')
		rankLabel.TextColor3 = Color3.fromRGB(205, 127, 50)
	else
		rankLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

--[=[
	Updates a leaderboard with fresh data from the server.
	
	@param leaderboard -- The leaderboard model to update
	@param scrollingFrame -- The ScrollingFrame containing leaderboard entries
	@param statPath -- The stat path to query (e.g., "Currency.Coins")
	@param localPlayerFrame -- The local player's dedicated frame
	
	@private
]=]
local function updateLeaderboardData(
	scrollingFrame: ScrollingFrame,
	statPath: string,
	localPlayerFrame: Frame
): ()
	-- Request fresh leaderboard data
	local success, leaderInfo = pcall(function()
		return Packets.Leaderboard:Fire('GetTop', {
			StatPath = statPath,
			Amount = 50,
		})
	end)

	if not success then
		warn(
			`[LeaderboardController] - Failed to update leaderboard: {leaderInfo}`
		)
		return
	end

	-- Update local player's entry
	local localPlayerScore = getStatValue(localPlayer, statPath)
	setupEntry(localPlayerFrame, 0, localPlayer.UserId, localPlayerScore)

	-- Update or create entries for each leaderboard position
	for _, entry in ipairs(leaderInfo) do
		local rank = tonumber(entry.Rank)
		local userId = tonumber(entry.UserId)
		local score = tonumber(entry.Score)

		if not (rank and userId and score) then
			continue
		end

		local frameName = `Rank_{rank}`
		local leaderEntry = scrollingFrame:FindFirstChild(frameName)

		-- Create new entry if it doesn't exist
		if not leaderEntry then
			leaderEntry = Models.LeaderboardTemplate:Clone()
			leaderEntry.Name = frameName
			leaderEntry.Parent = scrollingFrame
		end

		setupEntry(leaderEntry, rank, userId, score)
	end
end

--[=[
	Initializes a leaderboard and sets up its initial state.
	
	@param leaderboard -- The leaderboard model to set up
	
	@private
]=]
local function setupLeaderboard(leaderboard: Model): ()
	local header = leaderboard:WaitForChild('Header')
	if not header then
		warn('[LeaderboardController] - Header not found in leaderboard model!')
		return
	end

	setupHeader(header)

	local main = leaderboard:FindFirstChild('Main')
	if not main then
		warn(
			'[LeaderboardController] - Main part not found in leaderboard model!'
		)
		return
	end

	local leaderboardAttribute = leaderboard:GetAttribute('Leaderboard')
	if not leaderboardAttribute then
		warn(
			'[LeaderboardController] - Leaderboard attribute not found on leaderboard model!'
		)
		return
	end

	local surfaceGui = main:FindFirstChildWhichIsA('SurfaceGui')
	if not surfaceGui then
		warn('[LeaderboardController] - SurfaceGui not found in main part!')
		return
	end

	local scrollingFrame = surfaceGui:FindFirstChildWhichIsA('ScrollingFrame')
	if not scrollingFrame then
		warn('[LeaderboardController] - ScrollingFrame not found in main part!')
		return
	end

	local statPath = {
		['Pinata_Level'] = 'Pinata.Level',
		['Coins'] = 'Currency.Coins',
		['Rebirth'] = 'Currency.RebirthCount',
		['PlayTime'] = 'Metadata.TotalPlayTime',
	}

	local localPlayerFrame = surfaceGui.LocalPlayer.Frame

	-- Store leaderboard references for updates
	activeLeaderboards[leaderboard] = {
		statPath = statPath[leaderboardAttribute],
		scrollingFrame = scrollingFrame,
		localPlayerFrame = localPlayerFrame,
	}

	-- Initial setup
	updateLeaderboardData(
		scrollingFrame,
		statPath[leaderboardAttribute],
		localPlayerFrame
	)
end

--[=[
	Updates all active leaderboards with fresh data from the server.
	Called periodically to keep leaderboards current.
	
	@private
]=]
local function updateAllLeaderboards(): ()
	for leaderboard, data in pairs(activeLeaderboards) do
		if not leaderboard.Parent then
			-- Cleanup if leaderboard was removed
			activeLeaderboards[leaderboard] = nil
			continue
		end

		updateLeaderboardData(
			data.scrollingFrame,
			data.statPath,
			data.localPlayerFrame
		)
	end
end

--[=[
	Starts and manages the countdown timer display for leaderboard updates.
	Updates the countdown label every second until it reaches zero.
	
	@param leaderboardFolder -- The folder containing all leaderboard models and the LbInfo part
	
	**Example:**
    ```luau
	startUpdateCountdown(workspace.Map.Assets.Leaderboards)
    ```
	
	@private
]=]
local function startUpdateCountdown(leaderboardFolder: Folder): ()
	local LbInfo = leaderboardFolder:FindFirstChild('LbINFO')
	if not LbInfo then
		warn(
			'[LeaderboardController] - LbInfo part not found in Leaderboards folder!'
		)
		return
	end

	local infoBoard = LbInfo:WaitForChild('InfoBoard')
	if not infoBoard then
		warn('[LeaderboardController] - InfoBoard part not found in LbInfo!')
		return
	end

	local surfaceGui = infoBoard:WaitForChild('SurfaceGui')
	if not surfaceGui then
		warn(
			'[LeaderboardController] - SurfaceGui not found in info board part!'
		)
		return
	end

	local updateFrame = surfaceGui:FindFirstChildWhichIsA('Frame')
	if not updateFrame then
		warn(
			'[LeaderboardController] - Frame not found in info board SurfaceGui!'
		)
		return
	end

	local updateLabel = updateFrame:FindFirstChildWhichIsA('TextLabel')
	if not updateLabel then
		warn(
			'[LeaderboardController] - TextLabel not found in info board Frame!'
		)
		return
	end

	local countdownTime = UPDATE_INTERVAL
	updateLabel.Text = `Updating in {countdownTime}s`
	while countdownTime > 0 do
		task.wait(1)
		countdownTime -= 1
		updateLabel.Text = `Updating in {countdownTime}s`
	end
end

-- // Public Functions

--[=[
	Initializes the LeaderboardController. Finds all leaderboards in the map
	and sets up automatic updates every 60 seconds.
	
	**Called by the framework on client startup.**
	
	@within LeaderboardController
]=]
function LeaderboardController:Start(): ()
	local mapFolder = workspace:WaitForChild('Map')
	if not mapFolder then
		warn('[LeaderboardController] - Map folder not found in workspace!')
		return
	end

	local mapAssets = mapFolder:FindFirstChild('Assets')
	if not mapAssets then
		warn('[LeaderboardController] - Assets folder not found in Map!')
		return
	end

	local leaderboardFolder = mapAssets:FindFirstChild('Leaderboards')
	if not leaderboardFolder then
		warn('[LeaderboardController] - Leaderboards folder not found in Map!')
		return
	end

	-- Setup all leaderboards
	for _, folder in ipairs(leaderboardFolder:GetChildren()) do
		local leaderboardModel = folder:FindFirstChild('Leaderboard')
		if leaderboardModel and leaderboardModel:IsA('Model') then
			task.spawn(setupLeaderboard, leaderboardModel)
		end
	end

	-- Start update countdown display
	task.spawn(startUpdateCountdown, leaderboardFolder)

	-- Auto-update leaderboards every *UPDATE_INTERVAL* seconds
	task.spawn(function()
		while true do
			task.wait(UPDATE_INTERVAL)
			updateAllLeaderboards()
			startUpdateCountdown(leaderboardFolder)
		end
	end)
end
return LeaderboardController
