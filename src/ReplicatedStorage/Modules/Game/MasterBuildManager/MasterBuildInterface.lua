------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//VARIABLES
local module = {}

local internalFolder: Folder = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("MasterBuildInternal")
local interfaceFolder: Folder = internalFolder:WaitForChild("Interface")

------------------//INIT
module.Gui = require(interfaceFolder:WaitForChild("MasterBuildGui"))

return module
