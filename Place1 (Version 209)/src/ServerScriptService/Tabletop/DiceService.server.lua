------------------//SERVICES
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//VARIABLES
local modulesFolder: Folder = ServerStorage:WaitForChild("Modules")
local gameFolder: Folder = modulesFolder:WaitForChild("Game")
local DiceServerController = require(gameFolder:WaitForChild("DiceServerController"))

------------------//MAIN FUNCTIONS
DiceServerController.connect()
