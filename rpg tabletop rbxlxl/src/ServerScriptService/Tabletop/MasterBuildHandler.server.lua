------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local REMOTE_NAME: string = "MasterBuildEvent"

------------------//VARIABLES
local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local masterBuildEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)

local MasterBuildManager = require(ReplicatedStorage.Modules.Game.MasterBuildManager)

------------------//MAIN FUNCTIONS
masterBuildEvent.OnServerEvent:Connect(MasterBuildManager.process_request)

------------------//INIT