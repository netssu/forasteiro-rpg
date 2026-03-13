------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//VARIABLES
local module = {}

local internalFolder: Folder = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("MasterBuildInternal")
local interactionFolder: Folder = internalFolder:WaitForChild("Interaction")

------------------//INIT
module.Selection = require(interactionFolder:WaitForChild("MasterBuildSelection"))
module.Preview = require(interactionFolder:WaitForChild("MasterBuildPreview"))
module.Drag = require(interactionFolder:WaitForChild("MasterBuildDrag"))
module.Actions = require(interactionFolder:WaitForChild("MasterBuildActions"))
module.Hitbox = require(interactionFolder:WaitForChild("MasterBuildHitbox"))

return module
