------------------//SERVICES
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//VARIABLES
local modulesFolder: Folder = ServerStorage:WaitForChild("Modules")
local gameFolder: Folder = modulesFolder:WaitForChild("Game")
local MovementServerController = require(gameFolder:WaitForChild("MovementServerController"))

------------------//MAIN FUNCTIONS
MovementServerController.connect()
