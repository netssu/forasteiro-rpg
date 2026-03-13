------------------//SERVICES
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//VARIABLES
local modulesFolder: Folder = ServerStorage:WaitForChild("Modules")
local gameFolder: Folder = modulesFolder:WaitForChild("Game")
local TeamServerController = require(gameFolder:WaitForChild("TeamServerController"))

------------------//MAIN FUNCTIONS
TeamServerController.connect()
