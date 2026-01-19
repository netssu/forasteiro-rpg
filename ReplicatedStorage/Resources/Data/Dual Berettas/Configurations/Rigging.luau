return {
	Viewmodel = {
		["Name"] = "Grip",

		["BasePart"] = {"Viewmodel", "Torso"},
		["TargetPart"] = {"GunModel", "Grip"},

		["Offset"] = CFrame.identity,

		["AkimboName"] = "Grip_L",
		["AkimboBasePart"] = {"Viewmodel", "Torso"},
		["AkimboTargetPart"] = {"GunModel", "Grip_L"}
	},

	Worldmodel = {
		["Name"] = "Grip",

		["BasePart"] = {"Character", "Torso"},
		["TargetPart"] = {"GunModel", "Grip"},

		["Offset"] = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),

		["AkimboName"] = "Grip_L",
		["AkimboBasePart"] = {"Character", "Torso"},
		["AkimboTargetPart"] = {"GunModel", "Grip_L"}
	},
}