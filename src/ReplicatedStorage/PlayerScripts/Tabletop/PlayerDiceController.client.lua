------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//VARIABLES
local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local gameFolder: Folder = modulesFolder:WaitForChild("Game")
local DiceController = require(gameFolder:WaitForChild("DiceController"))

------------------//MAIN FUNCTIONS
DiceController.run()
