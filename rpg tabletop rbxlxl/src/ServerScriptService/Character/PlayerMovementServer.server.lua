------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//CONSTANTS
local ASSETS_FOLDER_NAME: string = "Assets"
local REMOTES_FOLDER_NAME: string = "Remotes"
local REMOTE_NAME: string = "PlayerMovementEvent"

------------------//VARIABLES
local assetsFolder: Folder = ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME)
local remotesFolder: Folder = assetsFolder:WaitForChild(REMOTES_FOLDER_NAME)
local movementEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)

local MovementManager = require(ServerStorage.Modules.Game.MovementManager)

------------------//FUNCTIONS
local function on_player_removing(player: Player): ()
	MovementManager.remove_player(player)
end

------------------//MAIN FUNCTIONS
movementEvent.OnServerEvent:Connect(MovementManager.process_request)
Players.PlayerRemoving:Connect(on_player_removing)

------------------//INIT