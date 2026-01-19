--// Core Server Script //--
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

--// Modules //--
local Core = ServerScriptService.Core

local PlayerData = require(Core.Data.PlayerData)
local Leaderboards = require(Core.Data.Leaderboards)
local PlayerManager = require(Core.Player.PlayerManager)
local TycoonManager = require(Core.Tycoon.TycoonManager)
local MissionManager = require(Core.Player.MissionManager)
local PurchaseHandler = require(Core.Purchase.PurchaseHandler)
local RemoteManager = require(Core.Player.RemoteManager)
local CatchingManager = require(Core.Catching.CatchingManager)

--// Initialize Systems //--
RemoteManager.Initialize()
TycoonManager.initialize()
CatchingManager.initialize()
--print("[CORE] Initialized modules")

--// Constants //--
local DATA_LOAD_TIMEOUT = 60
local SAVE_STALENESS_THRESHOLD = 5

--// Tracking //--
local lastSaveTimes = {}

--// Helper Functions //--
local function waitForDataLoaded(player: Player, timeout: number): boolean
	local waitTime = 0
	repeat
		task.wait(0.25)
		waitTime += 0.25
	until player:GetAttribute("DataLoaded") or waitTime >= timeout or not player.Parent
	return player:GetAttribute("DataLoaded") == true
end

--// Player Lifecycle //--
Players.PlayerAdded:Connect(function(player)
	RemoteManager.InitializePlayer(player)

	local gameData = PlayerData.loadPlayer(player)

	if not gameData then
		player:Kick("Data Load Failure")
		return
	end

	local dataLoaded = waitForDataLoaded(player, DATA_LOAD_TIMEOUT)

	if not dataLoaded then
		warn(`[CORE] Data load timeout for {player.Name}, continuing with defaults`)
		gameData = {}
	end

	-- Player object
	PlayerManager.createPlayerObject(player)
	if gameData.PlayerStats and next(gameData.PlayerStats) then
		PlayerManager.deserializePlayerData(player, gameData.PlayerStats)
	end

	TycoonManager.assignBase(player, gameData.Tycoon)

	-- Mission
	MissionManager.initializePlayer(player)
	if gameData.Missions and next(gameData.Missions) then
		MissionManager.loadPlayerData(player, gameData.Missions)
	end

	task.defer(function()
		PurchaseHandler.checkAndGrantGamepasses(player)
	end)

	--print(`[CORE] {player.Name} joined successfully`)
end)

Players.PlayerRemoving:Connect(function(player)
	PurchaseHandler.cleanupPlayer(player)

	PlayerData.savePlayer(player)
	lastSaveTimes[player] = tick()

	RemoteManager.CleanupPlayer(player)
	TycoonManager.unassignBase(player)
	MissionManager.cleanupPlayer(player)
	PlayerManager.removePlayerObject(player)

	lastSaveTimes[player] = nil
	--print(`[CORE] {player.Name} left and data saved`)
end)

--// Server Shutdown //--
game:BindToClose(function()
	--print("[CORE] Server shutting down, saving all data...")
	task.wait(2)
	--print("[CORE] Shutdown complete")
end)

--print("[CORE] Core server initialized")