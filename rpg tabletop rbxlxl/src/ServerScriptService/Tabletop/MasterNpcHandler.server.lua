------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//CONSTANTS
local REMOTE_NAME: string = "MasterNpcEvent"

------------------//VARIABLES
local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local npcEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)

local MasterNpcManager = require(ServerStorage.Modules.Game.MasterNpcManager)

------------------//MAIN FUNCTIONS
npcEvent.OnServerEvent:Connect(MasterNpcManager.process_request)

------------------//INIT