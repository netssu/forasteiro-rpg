------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//VARIABLES
local DataEggs = {
	["Begginer Egg"] = {
		Price = 1,
		Currency = "Coins",
		Model = workspace.FolderEgg["Begginer Egg"],
		Weights = {
			["Cat"] = 50,
			["Dog"] = 50,
			["Bear"] = 10,
			["Tiger"] = 3,
			["Pig"] = 0
		}
	},
	["Rare Egg"] = {
		Price = 1000,
		Currency = "Coins",
		Model = workspace.FolderEgg["Rare Egg"],
		Weights = {
			["Cat"] = 15,
			["Dog"] = 15,
			["Bear"] = 50,
			["Tiger"] = 19,
			["Pig"] = 1
		}
	},
	["Epic Egg"] = {
		Price = 2500,
		Currency = "Coins",
		Model = workspace.FolderEgg["Epic Egg"],
		Weights = {
			["Cat"] = 5,
			["Dog"] = 5,
			["Bear"] = 30,
			["Tiger"] = 50,
			["Pig"] = 10
		}
	},
	["Lava Egg"] = {
		Price = 5,
		Currency = "RebirthTokens",
		Model = workspace.FolderEgg["Lava Egg"],
		Weights = {
			["Bear"] = 40,
			["Tiger"] = 40,
			["Pig"] = 20
		}
	},
	["Mega Egg"] = {
		Price = 10,
		Currency = "RebirthTokens",
		Model = workspace.FolderEgg["Mega Egg"],
		Weights = {
			["Tiger"] = 30,
			["Pig"] = 70
		}
	}
}

------------------//INIT
return DataEggs