return {
	Viewmodel = {
		["Name"] = "Grip",

		["BasePart"] = {"Viewmodel", "Torso"},
		["TargetPart"] = {"GunModel", "Grip"},

		["Offset"] = CFrame.identity
	},

	Worldmodel = {
		["Name"] = "Grip",

		["BasePart"] = {"Character", "Torso"},
		["TargetPart"] = {"GunModel", "Grip"},

		["Offset"] = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0)
	},
}