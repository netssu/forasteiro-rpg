------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//VARIABLES
local LuckyBlocksConfig = {}

LuckyBlocksConfig.LuckyBlocks = {
	["Special_1"] = {
		Price = 249,
		Currency = "Robux",
		ProductID = 3470785080,
		GiftProductID = 1234,
		Amount = 1,
	},
	["Special_3"] = {
		Price = 699,
		Currency = "Robux",
		ProductID = 3470785155,
		GiftProductID = 1234,
		Amount = 3,
	},
	["Special_10"] = {
		Price = 1999,
		Currency = "Robux",
		ProductID = 3470785229,
		GiftProductID = 1234,
		Amount = 10,
	},
}

LuckyBlocksConfig.DropTable = {
	{ Brainrot = "Lirili_Zombila", Chance = 55 },
	{ Brainrot = "Chimpanzinni_Bananini", Chance = 34 },
	{ Brainrot = "Frigo_Bonemelo", Chance = 9 },
	{ Brainrot = "Zombie_Footera", Chance = 1 },
	{ Brainrot = "Vampire_Sahur", Chance = 1 },
}

local rng: Random = Random.new()

------------------//FUNCTIONS
local function get_total_chance(): number
	local total = 0
	local drops = LuckyBlocksConfig.DropTable
	for i = 1, #drops do
		total += drops[i].Chance
	end
	return total
end

function LuckyBlocksConfig.getInfo(variationName: string)
	return LuckyBlocksConfig.LuckyBlocks[variationName]
end

function LuckyBlocksConfig.getAmount(variationName: string): number
	local info = LuckyBlocksConfig.LuckyBlocks[variationName]
	if not info then
		return 0
	end
	return info.Amount or 0
end

function LuckyBlocksConfig.rollBrainrot(): string?
	local drops = LuckyBlocksConfig.DropTable
	local total = get_total_chance()
	if total <= 0 then
		return nil
	end

	local roll = rng:NextNumber(0, total)
	local acc = 0

	for i = 1, #drops do
		acc += drops[i].Chance
		if roll <= acc then
			return drops[i].Brainrot
		end
	end

	return drops[#drops].Brainrot
end

return LuckyBlocksConfig
