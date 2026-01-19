local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Resources = ReplicatedStorage:WaitForChild("Resources")
local GunModels = Resources.Miscs.GunModel

local Configuration = {
	["Commons"] = require(script:WaitForChild("Configurations").Commons);
	["Muzzleflash"] = Resources.Miscs.Muzzleflashes.Pistol;

	["Rigging"] = require(script:WaitForChild("Configurations").Rigging);
	["Offsets"] = require(script:WaitForChild("Configurations").Offsets);
	["AudioSettings"] = require(script:WaitForChild("Configurations").AudioSettings);
	
	["Slot"] = "Secondary",
	
	["Model"] = {
		Viewmodel = GunModels.Viewmodel[script.Name];
	};
	
	["Animations"] = {
		Viewmodel = script:WaitForChild("ViewmodelAnimations");
		Worldmodel = script:WaitForChild("ViewmodelAnimations");
	}
}

return Configuration