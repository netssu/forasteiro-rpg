------------------//MODULES
local masterBuildFolder: Folder = script.Parent

------------------//MAIN FUNCTIONS
local MasterBuildModuleRegistry = {}

function MasterBuildModuleRegistry.load(): {[string]: any}
	local modules = {
		Constants = require(masterBuildFolder:WaitForChild("MasterBuildConstants")),
		Utility = require(masterBuildFolder:WaitForChild("MasterBuildUtility")),
		Permissions = require(masterBuildFolder:WaitForChild("MasterBuildPermissions")),
		Raycast = require(masterBuildFolder:WaitForChild("MasterBuildRaycast")),
		Gui = require(masterBuildFolder:WaitForChild("MasterBuildGui")),
		Selection = require(masterBuildFolder:WaitForChild("MasterBuildSelection")),
		Preview = require(masterBuildFolder:WaitForChild("MasterBuildPreview")),
		Drag = require(masterBuildFolder:WaitForChild("MasterBuildDrag")),
		Actions = require(masterBuildFolder:WaitForChild("MasterBuildActions")),
		Hitbox = require(masterBuildFolder:WaitForChild("MasterBuildHitbox")),
	}

	return modules
end

return MasterBuildModuleRegistry
