------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//VARIABLES
local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local gameFolder: Folder = modulesFolder:WaitForChild("Game")
local FlashlightController = require(gameFolder:WaitForChild("FlashlightController"))

------------------//MAIN FUNCTIONS
FlashlightController.run()
