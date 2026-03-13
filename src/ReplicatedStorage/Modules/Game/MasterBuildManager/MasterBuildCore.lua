------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//VARIABLES
local module = {}

local internalFolder: Folder = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("MasterBuildInternal")
local coreFolder: Folder = internalFolder:WaitForChild("Core")
local runtimeFolder: Folder = internalFolder:WaitForChild("Runtime")

------------------//INIT
module.Constants = require(coreFolder:WaitForChild("MasterBuildConstants"))
module.Utility = require(coreFolder:WaitForChild("MasterBuildUtility"))
module.State = require(coreFolder:WaitForChild("MasterBuildState"))
module.Permissions = require(runtimeFolder:WaitForChild("MasterBuildPermissions"))
module.Raycast = require(runtimeFolder:WaitForChild("MasterBuildRaycast"))

return module
