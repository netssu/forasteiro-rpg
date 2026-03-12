------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//VARIABLES
local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local gameFolder: Folder = modulesFolder:WaitForChild("Game")
local TeamSelectorController = require(gameFolder:WaitForChild("TeamSelectorController"))

------------------//MAIN FUNCTIONS
TeamSelectorController.run()
