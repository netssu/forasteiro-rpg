--// Brainrot Configuration Module //--
local BrainrotConfig = {}

export type BrainrotInfo = {
	Rarity: string,
	Value: number,
	Speed: number,
	Health: number,
	Color: Color3,
	ImageId: string,
	WalkAnimation: string,
	ProductID: number?,
	IsPremium: boolean?,
}

BrainrotConfig.Brainrots = {
	Lirili_Zombila = {
		Rarity = "Common",
		Value = 10,
		Speed = 16,
		Health = 50,
		Color = Color3.fromRGB(150, 200, 100),
		ProductID = nil,
		ImageId = "rbxassetid://101665453995269 ",
		WalkAnimation = "rbxassetid://140689696818107",
	},

	Chimpanzinni_Bananini = {
		Rarity = "Common",
		Value = 50,
		Speed = 18,
		Health = 50,
		Color = Color3.fromRGB(255, 220, 100),
		ProductID = nil,
		ImageId = "rbxassetid://71737885696761",
		WalkAnimation = "rbxassetid://107109939943800",
	},

	Pumpkin_Din_Din_Dun = {
		Rarity = "Uncommon",
		Value = 200,
		Speed = 17,
		Health = 75,
		Color = Color3.fromRGB(255, 140, 50),
		ProductID = nil,
		ImageId = "rbxassetid://77357402684168",
		WalkAnimation = "rbxassetid://70803445682611",
	},

	Bonebardiro_Crocodrilo = {
		Rarity = "Uncommon",
		Value = 500,
		Speed = 20,
		Health = 75,
		Color = Color3.fromRGB(230, 230, 230),
		ProductID = nil,
		ImageId = "rbxassetid://102117571859724",
		WalkAnimation = "rbxassetid://76231597242103",
	},

	-- ADICIONADO: Faltava este brainrot usado no PremiumTank_4
	Bonebinni_Gussini = {
		Rarity = "Rare",
		Value = 2000,
		Speed = 22,
		Health = 100,
		Color = Color3.fromRGB(100, 200, 255),
		ProductID = nil,
		ImageId = "rbxassetid://123456789", -- Substitua pelo ID real se tiver
		WalkAnimation = "rbxassetid://123456789",
	},

	Cauldrona_Signora = {
		Rarity = "Rare",
		Value = 1000,
		Speed = 15,
		Health = 100,
		Color = Color3.fromRGB(120, 80, 150),
		ProductID = nil,
		ImageId = "rbxassetid://134825389713524",
		WalkAnimation = "rbxassetid://97448135410249",
	},

	Vampire_Sahur = {
		Rarity = "Rare",
		Value = 2500,
		Speed = 22,
		Health = 100,
		Color = Color3.fromRGB(200, 0, 50),
		ProductID = nil,
		ImageId = "rbxassetid://137051229627406",
		WalkAnimation = "rbxassetid://130428836300873",
	},

	La_La_House = {
		Rarity = "Epic",
		Value = 5000,
		Speed = 24,
		Health = 150,
		Color = Color3.fromRGB(255, 100, 200),
		ProductID = nil,
		ImageId = "rbxassetid://113328997789001",
		WalkAnimation = "rbxassetid://137838363183333",
	},

	Nooo_My_Candy = {
		Rarity = "Epic",
		Value = 10000,
		Speed = 19,
		Health = 150,
		Color = Color3.fromRGB(255, 180, 230),
		ProductID = nil,
		ImageId = "rbxassetid://74535315101760",
		WalkAnimation = "rbxassetid://74224359023362",
	},

	Agarrinnila_Scytheinni = {
		Rarity = "Legendary",
		Value = 25000,
		Speed = 26,
		Health = 200,
		Color = Color3.fromRGB(100, 100, 100),
		ProductID = nil,
		ImageId = "rbxassetid://82424729774556",
		WalkAnimation = "rbxassetid://77502583659176",
	},

	Tralalenstein_Tralala = {
		Rarity = "Legendary",
		Value = 50000,
		Speed = 25,
		Health = 200,
		Color = Color3.fromRGB(150, 255, 150),
		ProductID = nil,
		ImageId = "rbxassetid://74948060864875",
		WalkAnimation = "rbxassetid://99276243695583",
	},

	Boneca = {
		Rarity = "Mythic",
		Value = 100000,
		Speed = 28,
		Health = 300,
		Color = Color3.fromRGB(255, 215, 0),
		ProductID = nil,
		ImageId = "rbxassetid://115295825304581",
		WalkAnimation = "rbxassetid://84357188055113",
	},

	Zombie_Footera = {
		Rarity = "Common",
		Value = 1000,
		Speed = 16,
		Health = 50,
		Color = Color3.fromRGB(180, 200, 180),
		IsPremium = true,
		ProductID = nil,
		ImageId = "rbxassetid://123023867189749",
		WalkAnimation = "rbxassetid://104473468092670",
	},

	Frigo_Bonemelo = {
		Rarity = "Uncommon",
		Value = 1000,
		Speed = 18,
		Health = 75,
		Color = Color3.fromRGB(180, 220, 255),
		IsPremium = true,
		ProductID = nil,
		ImageId = "rbxassetid://108751406076934",
		WalkAnimation = "rbxassetid://80105846331255",
	},
}

function BrainrotConfig.getInfo(brainrotName: string): BrainrotInfo?
	return BrainrotConfig.Brainrots[brainrotName]
end

function BrainrotConfig.getWalkAnimation(brainrotName: string): string?
	local info = BrainrotConfig.Brainrots[brainrotName]
	return info and info.WalkAnimation
end

function BrainrotConfig.getImageId(brainrotName: string): string?
	local info = BrainrotConfig.Brainrots[brainrotName]
	return info and info.ImageId
end

function BrainrotConfig.getAllNames(): {string}
	local names = {}
	for name in BrainrotConfig.Brainrots do
		table.insert(names, name)
	end
	return names
end

function BrainrotConfig.getByRarity(rarity: string): {string}
	local names = {}
	for name, info in BrainrotConfig.Brainrots do
		if info.Rarity == rarity then
			table.insert(names, name)
		end
	end
	return names
end

function BrainrotConfig.isPremium(brainrotName: string): boolean
	local info = BrainrotConfig.Brainrots[brainrotName]
	return info and info.IsPremium == true
end

function BrainrotConfig.getValue(brainrotName: string): number?
	local info = BrainrotConfig.Brainrots[brainrotName]
	return info and info.Value
end

function BrainrotConfig.getSpeed(brainrotName: string): number?
	local info = BrainrotConfig.Brainrots[brainrotName]
	return info and info.Speed
end

function BrainrotConfig.getHealth(brainrotName: string): number?
	local info = BrainrotConfig.Brainrots[brainrotName]
	return info and info.Health
end

return BrainrotConfig