------------------//SERVICES
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService: CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//DEPENDENCIES
local DataService = require(ServerScriptService.Core.Data.DataService)

------------------//CONSTANTS
local UPDATE_INTERVAL: number = 600
local MAX_ENTRIES: number = 50
local LEADERBOARD_TAG: string = "Leaderboard"
local LEADERBOARD_ATTRIBUTE: string = "LeaderboardName"

------------------//VARIABLES
local Leaderboards = {}

local remotes = ReplicatedStorage.Remotes

local remoteEvents = remotes.Events
local remoteFunctions = remotes.Functions

function Leaderboards.update()
	remoteEvents.UpdateLeaderboard:FireAllClients()
end

------------------//INIT
remoteFunctions.Info.GetLeaderboardData.OnServerInvoke = function(player: Player, leaderboardName: string)
	return DataService.GetLeaderboardData(leaderboardName, false, MAX_ENTRIES)
end

task.spawn(function()
	Leaderboards.update()
	
	while true do
		task.wait(UPDATE_INTERVAL)
		Leaderboards.update()
	end
end)

return Leaderboards
