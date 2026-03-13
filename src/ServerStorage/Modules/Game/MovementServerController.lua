------------------//SERVICES
local Players: Players = game:GetService("Players")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//MODULES
local serverModulesFolder: Folder = ServerStorage:WaitForChild("Modules")
local serverGameFolder: Folder = serverModulesFolder:WaitForChild("Game")
local MovementManager = require(serverGameFolder:WaitForChild("MovementManager"))

local replicatedModulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local utilityFolder: Folder = replicatedModulesFolder:WaitForChild("Utility")
local MovementRemoteUtility = require(utilityFolder:WaitForChild("MovementRemoteUtility"))

------------------//FUNCTIONS
local function on_player_removing(player: Player): ()
	MovementManager.remove_player(player)
end

------------------//MAIN FUNCTIONS
local MovementServerController = {}

function MovementServerController.connect(): ()
	local movementEvent = MovementRemoteUtility.get_movement_remote()
	movementEvent.OnServerEvent:Connect(MovementManager.process_request)
	Players.PlayerRemoving:Connect(on_player_removing)
end

return MovementServerController
