local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TankConfig = {}

export type TankConfig = {
	Tanks: {[string]: TankInfo},
} & typeof(TankConfig)

export type Checkpoint = {Number: number, Movement: "Moving" | "Falling"}


export type TankInfo = {
	Brainrot: string,
	StartingLevel: number,
	Price: number,
	Required: number,
	Checkpoints: {Checkpoint},
	IsPremium: boolean,
}

TankConfig.Tanks = {
	Tank_1 = {
		Brainrot = "Lirili_Zombila",
		StartingLevel = 1,
		Required = 1,
		Price = 0,
		Checkpoints = {
			{Number = 1, Movement = "Moving"}, 
			{Number = 2, Movement = "Moving"},
			{Number = 3, Movement = "Moving"},
			{Number = 4, Movement = "Moving"},
		}
	},

	Tank_2 = {
		Brainrot = "Chimpanzinni_Bananini",
		StartingLevel = 1,
		Required = 2,
		Price = 1000,
		Checkpoints = {
			{Number = 1, Movement = "Moving"}, 
			{Number = 2, Movement = "Moving"},
			{Number = 3, Movement = "Moving"},
			{Number = 4, Movement = "Moving"},
		}
	},

	Tank_3 = {
		Brainrot = "Pumpkin_Din_Din_Dun",
		StartingLevel = 1,
		Required = 1,
		Price = 5000,
		Checkpoints = {
			{Number = 1, Movement = "Moving"}, 
			{Number = 2, Movement = "Moving"},
			{Number = 3, Movement = "Moving"},
			{Number = 4, Movement = "Moving"},
		}
	},

	Tank_4 = {
		Brainrot = "Cauldrona_Signora",
		StartingLevel = 1,
		Price = 25000,
		Required = 1,
		Checkpoints = {
			{Number = 3, Movement = "Moving"},
			{Number = 4, Movement = "Moving"},
		}
	},

	Tank_5 = {
		Brainrot = "Vampire_Sahur",
		StartingLevel = 1,
		Price = 100000,
		Required = 1,
		Checkpoints = {
			{Number = 3, Movement = "Moving"},
			{Number = 4, Movement = "Moving"},
		}
	},

	Tank_6 = {
		Brainrot = "La_La_House",
		StartingLevel = 1,
		Price = 500000,
		Required = 1,
		Checkpoints = {
			{Number = 3, Movement = "Moving"},
			{Number = 4, Movement = "Moving"},
		}
	},

	Tank_7 = {
		Brainrot = "Nooo_My_Candy",
		StartingLevel = 1,
		Price = 2500000,
		Required = 2,
		Checkpoints = {
			{Number = 7, Movement = "Moving"},
			{Number = 1, Movement = "Falling"},
			{Number = 2, Movement = "Moving"},
			{Number = 3, Movement = "Moving"},
			{Number = 4, Movement = "Moving"},
		}
	},

	Tank_8 = {
		Brainrot = "Agarrinnila_Scytheinni",
		StartingLevel = 1,
		Price = 10000000,
		Required = 1,
		Checkpoints = {
			{Number = 7, Movement = "Moving"},
			{Number = 1, Movement = "Falling"},
			{Number = 2, Movement = "Moving"},
			{Number = 3, Movement = "Moving"},
			{Number = 4, Movement = "Moving"},
		}
	},

	Tank_9 = {
		Brainrot = "Tralalenstein_Tralala",
		StartingLevel = 1,
		Price = 50000000,
		Required = 1,
		Checkpoints = {
			{Number = 7, Movement = "Moving"},
			{Number = 1, Movement = "Falling"},
			{Number = 2, Movement = "Moving"},
			{Number = 3, Movement = "Moving"},
			{Number = 4, Movement = "Moving"},
		}
	},

	Tank_10 = {
		Brainrot = "Boneca",
		StartingLevel = 1,
		Price = 250000000,
		Required = 2,
		Checkpoints = {
			{Number = 5, Movement = "Moving"},
			{Number = 6, Movement = "Moving"},
			{Number = 7, Movement = "Moving"},
			{Number = 1, Movement = "Falling"},
			{Number = 2, Movement = "Moving"},
			{Number = 3, Movement = "Moving"},
			{Number = 4, Movement = "Moving"},
		}
	},

	Tank_11 = {
		Brainrot = "Spooky_Kar_Kir_Kur",
		StartingLevel = 1,
		Price = 1000000000,
		Required = 1,
		Checkpoints = {
			{Number = 5, Movement = "Moving"},
			{Number = 6, Movement = "Moving"},
			{Number = 7, Movement = "Moving"},
			{Number = 1, Movement = "Falling"},
			{Number = 2, Movement = "Moving"},
			{Number = 3, Movement = "Moving"},
			{Number = 4, Movement = "Moving"},
		}
	},

	-- Premium Tanks - Configuração "Normal"
	PremiumTank_1 = {
		Brainrot = "Frigo_Bonemelo",
		StartingLevel = 1, -- Nível 1 para permitir upgrades normais
		Required = 1,
		Price = 0, -- Grátis no tycoon (requer gamepass)
		IsPremium = true,
		Checkpoints = {
			{Number = 2, Movement = "Moving"},
			{Number = 3, Movement = "Moving"},
			{Number = 4, Movement = "Moving"},
		}
	},

	PremiumTank_2 = {
		Brainrot = "Zombie_Footera",
		StartingLevel = 1,
		Required = 1,
		Price = 0,
		IsPremium = true,
		Checkpoints = {
			{Number = 2, Movement = "Moving"},
			{Number = 3, Movement = "Moving"},
			{Number = 4, Movement = "Moving"},
		}
	},

	PremiumTank_3 = {
		Brainrot = "Bonebardiro_Crocodrilo",
		StartingLevel = 1,
		Required = 1,
		Price = 0,
		IsPremium = true,
		Checkpoints = {
			{Number = 2, Movement = "Moving"},
			{Number = 3, Movement = "Moving"},
			{Number = 4, Movement = "Moving"},
		}
	},

	PremiumTank_4 = {
		Brainrot = "Bonebinni_Gussini",
		StartingLevel = 1,
		Required = 1,
		Price = 0,
		IsPremium = true,
		Checkpoints = {
			{Number = 2, Movement = "Moving"},
			{Number = 3, Movement = "Moving"},
			{Number = 4, Movement = "Moving"},
		}
	},
} :: {[string]: TankInfo}

TankConfig.UpgradeLevels = {
	[1] = {
		Multiplier = 2,
		Cooldown = 5, 
		Amount = 1,
		Uses = 60,
		Price = {
			Cash = 0,
			Plutonium = 0,
		}
	},
	[2] = {
		Multiplier = 4,
		Cooldown = 3,
		Amount = 1,
		Uses = 120,
		Price = {
			Cash = 100,
			Plutonium = 0
		}
	},
	[3] = {
		Multiplier = 8,
		Cooldown = 1,
		Amount = 1,
		Uses = -1,
		Price = {
			Cash = 10000,
			Plutonium = 10
		}
	}
}

--// Helper Functions //--
function TankConfig.getAllTanks()
	return TankConfig.Tanks :: {[string]: TankInfo}
end

-- Get tank info by name
function TankConfig.getTankInfo(tankName: string)
	return TankConfig.Tanks[tankName]
end

-- Get upgrade level info
function TankConfig.getUpgradeInfo(level: number)
	return TankConfig.UpgradeLevels[level]
end

-- Calculate upgrade price based on tank base price and upgrade level
function TankConfig.calculateUpgradePrice(tankName: string, currentLevel: number): {Cash: number, Plutonium: number}?
	local tankInfo = TankConfig.Tanks[tankName]
	if not tankInfo then return nil end

	local nextLevel = currentLevel + 1
	local upgradeInfo = TankConfig.UpgradeLevels[nextLevel]

	if not upgradeInfo or not upgradeInfo.Price then
		return nil -- Max level or invalid
	end

	local cashPrice = 0
	local plutoniumPrice = 0

	if upgradeInfo.Price.Cash and upgradeInfo.Price.Cash > 0 then
		-- Para tanques Premium com Price=0, o upgrade seria grátis se multiplicarmos.
		-- Vamos definir um preço base fixo para upgrades de tanques premium se Price for 0.
		local basePrice = tankInfo.Price
		if basePrice == 0 and tankInfo.IsPremium then
			basePrice = 1000000 -- Exemplo: Valor base alto para upgrades de tanques premium
		end

		cashPrice = basePrice * upgradeInfo.Price.Cash
	end

	if upgradeInfo.Price.Plutonium and upgradeInfo.Price.Plutonium > 0 then
		plutoniumPrice = upgradeInfo.Price.Plutonium
	end

	return {
		Cash = cashPrice,
		Plutonium = plutoniumPrice
	}
end

-- Check if tank is at max level
function TankConfig.isMaxLevel(level: number): boolean
	return level >= 3
end

-- Get all tank names
function TankConfig.getAllTankNames(): {string}
	local names = {}
	for name, _ in pairs(TankConfig.Tanks) do
		table.insert(names, name)
	end
	return names
end

-- Get regular tanks only
function TankConfig.getRegularTanks(): {string}
	local names = {}
	for name, info in pairs(TankConfig.Tanks) do
		if not info.IsPremium then
			table.insert(names, name)
		end
	end
	return names
end

-- Get premium tanks only
function TankConfig.getPremiumTanks(): {string}
	local names = {}
	for name, info in pairs(TankConfig.Tanks) do
		if info.IsPremium then
			table.insert(names, name)
		end
	end
	return names
end

-- Get premium tanks info only
function TankConfig.getPremiumTanksInfo(): { [string]: { [string]: any } }
	local infos = {}
	for name, info in pairs(TankConfig.Tanks) do
		if info.IsPremium then
			infos[name] = info
		end
	end
	return infos
end

-- Get brainrot tank
function TankConfig.getBrainrotTank(name: string): string
	for tankName, info in pairs(TankConfig.Tanks) do
		if info.Brainrot == name then
			return tankName
		end
	end
end

-- Check if brainrot is premium
function TankConfig.isPremiumBrainrot(name: string): boolean
	local premiumTanks = TankConfig.getPremiumTanksInfo()

	for tankName, info in premiumTanks do
		if info.Brainrot == name then
			return true
		end
	end 

	return false
end

return TankConfig :: TankConfig