------------------//SERVICES
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//VARIABLES
local modulesFolder: Folder = ServerStorage:WaitForChild("Modules")
local gameFolder: Folder = modulesFolder:WaitForChild("Game")
local FlashlightManager = require(gameFolder:WaitForChild("FlashlightManager"))

------------------//MAIN FUNCTIONS
FlashlightManager.connect()
