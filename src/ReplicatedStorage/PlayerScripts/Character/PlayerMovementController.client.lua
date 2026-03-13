------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//VARIABLES
local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local gameFolder: Folder = modulesFolder:WaitForChild("Game")
local MovementController = require(gameFolder:WaitForChild("MovementController"))

------------------//MAIN FUNCTIONS
MovementController.run()
