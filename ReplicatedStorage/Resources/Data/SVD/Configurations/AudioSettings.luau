local Sounds = script.Parent.Parent:WaitForChild("Sounds")

local module = {
	["Parent"] = {
		Viewmodel = "CurrentCamera";
		Worldmodel = {"Character", "Torso"};
	};
	
	["Zoom"] = {
		Sound = Sounds["Zoom"],

		Pitch = {
			Value = 1,
			Randomize = {
				Enabled = true,
				Min = .95,
				Max = 1.05
			}
		}
	};	
	
	["ZoomInit"] = {
		Sound = Sounds["ZoomInit"],

		Pitch = {
			Value = 1,
			Randomize = {
				Enabled = true,
				Min = .95,
				Max = 1.05
			}
		}
	};	
	
	["Equip"] = {
		Sound = Sounds["Equip"],

		Pitch = {
			Value = 1,
			Randomize = {
				Enabled = true,
				Min = .95,
				Max = 1.05
			}
		}
	};
	
	["Fire"] = {
		Sound = Sounds["Fire"],

		Pitch = {
			Value = 1,
			Randomize = {
				Enabled = true,
				Min = .95,
				Max = 1.05
			}
		}
	};
	
	["DryFire"] = {
		Sound = Sounds["DryFire"],

		Pitch = {
			Value = 1,
			Randomize = {
				Enabled = true,
				Min = .95,
				Max = 1.05
			}
		}
	};
	
	["Reload"] = {
		Sound = Sounds["Reload"],

		Pitch = {
			Value = 1,
			Randomize = {
				Enabled = true,
				Min = .95,
				Max = 1.05
			}
		}
	};
	
	["EmptyReload"] = {
		Sound = Sounds["EmptyReload"],

		Pitch = {
			Value = 1,
			Randomize = {
				Enabled = true,
				Min = .95,
				Max = 1.05
			}
		}
	};
	
	["Insert"] = {
		Sound = Sounds["Insert"],

		Pitch = {
			Value = 1,
			Randomize = {
				Enabled = true,
				Min = .95,
				Max = 1.05
			}
		}
	};
	
	["BoltAction"] = {
		Sound = Sounds["BoltAction"],

		Pitch = {
			Value = 1,
			Randomize = {
				Enabled = true,
				Min = .95,
				Max = 1.05
			}
		}
	},
	["Inspect"] = {
		Sound = Sounds["Inspect"],

		Pitch = {
			Value = 1,
			Randomize = {
				Enabled = true,
				Min = .95,
				Max = 1.05
			}
		}
	},
	
}

return module
