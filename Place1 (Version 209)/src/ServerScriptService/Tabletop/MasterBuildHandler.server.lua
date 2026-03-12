------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local REMOTE_NAME: string = "MasterBuildEvent"

------------------//VARIABLES
local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local masterBuildEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)

local MasterBuildServer = require(ReplicatedStorage.Modules.Game.MasterBuildServer)

------------------//MAIN FUNCTIONS
masterBuildEvent.OnServerEvent:Connect(MasterBuildServer.process_request)

------------------//INIT