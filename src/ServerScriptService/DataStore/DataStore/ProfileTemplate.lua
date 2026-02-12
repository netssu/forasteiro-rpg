local ProfileTemplate = {
	------------------//CORE
	Coins = 0,
	TimePlayed = 0,
	------------------//PROGRESSION
	CurrentWorld = 1,
	CurrentAltitudeTier = 1,
	Rebirths = 0,
	RebirthTokens = 0,
	TutorialCompleted = false,
	------------------//POGO
	EquippedPogoId = "BasicPogo",
	OwnedPogos = {
		["BasicPogo"] = true,
	},
	PogoSettings = {
		base_jump_power = 120,
		gravity_mult = 1.5,
	},
	
	EquippedVfxId = "",
	OwnedVfx = {},
	------------------//PETS
	OwnedPets = {},
	EquippedPets = {},
	------------------//STATS (TRACKING) 
	Stats = {
		TotalJumps = 0,
		TotalLandings = 0,
		PerfectLandings = 0,
		HighestCombo = 0,
	},
	------------------//GAMEPASSES
	Gamepasses = {
		AutoJump = false,
		ExtraPetSlots = false,
		StarterPack = false,
		FasterHatch = false,
		EasierPerfectLandings = false,
	},
	------------------//SETTINGS
	Settings = {
		ShowDamageNumbers = true,
		ShowFloorCracks = true,
		ReducedVFX = false,
	},

	------------------//BOOSTS
	Boosts = {
		Coins2x = 0,
		Coins4x = 0,
		Lucky2x = 0,
		Lucky4x = 0,
	},


	------------------//CODES
	RedeemedCodes = {},

	------------------//QUESTS
	Quests = {},
}
return ProfileTemplate