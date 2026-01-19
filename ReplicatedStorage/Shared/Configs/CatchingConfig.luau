local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.Configs.BrainrotConfig)

local CatchingConfig = {}

--// Session Settings //--
CatchingConfig.Session = {
	SlotSpacing = 2000,
}

--// AI Behavior //--
CatchingConfig.Brainrot = {
}

--// Spawn Settings //--
CatchingConfig.Spawn = {
	MinBrainrots = 1,
	MaxBrainrots = 10,
}

CatchingConfig.WorldsBrainrots = {
	[1] = {
		Lirili_Zombila = BrainrotConfig.Brainrots.Lirili_Zombila,
		Chimpanzinni_Bananini = BrainrotConfig.Brainrots.Chimpanzinni_Bananini,
		Pumpkin_Din_Din_Dun = BrainrotConfig.Brainrots.Pumpkin_Din_Din_Dun,
		Cauldrona_Signora = BrainrotConfig.Brainrots.Cauldrona_Signora,
		Nooo_My_Candy = BrainrotConfig.Brainrots.Nooo_My_Candy,
		--Zombie_Footera = BrainrotConfig.Brainrots.Zombie_Footera,
		--Frigo_Bonemelo = BrainrotConfig.Brainrots.Frigo_Bonemelo,
	},

	[2] = {
		Bonebardiro_Crocodrilo = BrainrotConfig.Brainrots.Bonebardiro_Crocodrilo,
		Vampire_Sahur = BrainrotConfig.Brainrots.Vampire_Sahur,
		La_La_House = BrainrotConfig.Brainrots.La_La_House,
		Agarrinnila_Scytheinni = BrainrotConfig.Brainrots.Agarrinnila_Scytheinni,
		Tralalenstein_Tralala = BrainrotConfig.Brainrots.Tralalenstein_Tralala,
		Boneca = BrainrotConfig.Brainrots.Boneca,
		Spooky_Kar_Kir_Kur = BrainrotConfig.Brainrots.Spooky_Kar_Kir_Kur,
	},
}

--// Rarity Distribution //--
CatchingConfig.RarityWeights = {
	Common = 50,
	Uncommon = 25,
	Rare = 15,
	Epic = 7,
	Legendary = 2,
	Mythic = 1,
}

--// Validation //--
CatchingConfig.Validation = {
	HitMaxDistance = 15,
	HitMaxAngle = 60,
}

--// Map Structure //--
CatchingConfig.MapStructure = {
	BrainrotSpawnsFolder = "BrainrotSpawns",
	BrainrotPartsFolder = "BrainrotParts", 
	PlayerSpawnName = "PlayerSpawn",
	LaneName = "Lane",
	EndsFolder = "Ends",
	GroundName = "Ground",
	BrainsFolder = "Brains",
}

--// Helper Functions //--

function CatchingConfig.getRarityWeight(rarity: string): number
	return CatchingConfig.RarityWeights[rarity] or 1
end

function CatchingConfig.getSessionDuration(mapName: string): number
	return CatchingConfig.Session.MapDurations[mapName] or CatchingConfig.Session.DefaultDuration
end

function CatchingConfig.getRandomBrainrot(world) -- returns name, data
	local pool = {}
	local total = 0

	for name, data in CatchingConfig.WorldsBrainrots[world] do
		local w = CatchingConfig.getRarityWeight(data.Rarity)
		total += w
		pool[#pool + 1] = {Name = name, Data = data, Weight = w}
	end

	local rnd = math.random() * total
	local acc = 0

	for _, entry in ipairs(pool) do
		acc += entry.Weight
		if rnd <= acc then
			return entry.Name, entry.Data
		end
	end
end

return CatchingConfig
