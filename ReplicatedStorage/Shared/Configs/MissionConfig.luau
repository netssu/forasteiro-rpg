--// MissionConfig //--
local MissionConfig = {}

------------------//MISSIONS
MissionConfig.Missions = {
	------------------//DAILY
	Daily_CatchBrainrots = {
		Type = "Daily",
		Name = "Daily Catch",
		Description = "Catch 10 brainrots today",
		Difficulty = "Easy",
		ImageId = "rbxassetid://15997912345",
		Tasks = {
			BrainrotsCaught = 10,
		},
		Rewards = {
			Cash = 5000,
			Plutonium = 5,
			Exp = 50,
		},
	},

	Daily_EarnCash = {
		Type = "Daily",
		Name = "Daily Earnings",
		Description = "Earn $10,000 today",
		Difficulty = "Easy",
		ImageId = "rbxassetid://15997912346",
		Tasks = {
			CashEarned = "10000",
		},
		Rewards = {
			Plutonium = 10,
			Exp = 75,
		},
	},

	------------------//WEEKLY
	Weekly_UnlockTanks = {
		Type = "Weekly",
		Name = "Weekly Expansion",
		Description = "Unlock 2 tanks this week",
		Difficulty = "Medium",
		ImageId = "rbxassetid://15997912347",
		Tasks = {
			TanksUnlocked = 2,
		},
		Rewards = {
			Cash = 50000,
			Plutonium = 50,
			Exp = 500,
		},
	},

	------------------//HOURLY
	Hourly_QuickCatch = {
		Type = "Hourly",
		Name = "Quick Hunt",
		Description = "Catch 5 brainrots",
		Difficulty = "Easy",
		ImageId = "rbxassetid://15997912348",
		Tasks = {
			BrainrotsCaught = 5,
		},
		Rewards = {
			Cash = 1000,
			Exp = 25,
		},
	},

	------------------//QUEST CHAIN
	Quest_1 = {
		Type = "Quest",
		Name = "First Catch",
		Description = "Catch your first brainrot",
		Difficulty = "Easy",
		ImageId = "rbxassetid://15997912349",
		Tasks = {
			BrainrotsCaught = 1,
		},
		Rewards = {
			Cash = 500,
			Exp = 10,
		},
		NextQuest = "Quest_2",
	},

	Quest_2 = {
		Type = "Quest",
		Name = "Fill the Tank",
		Description = "Place a brainrot in a tank",
		Difficulty = "Easy",
		ImageId = "rbxassetid://15997912350",
		Tasks = {
			BrainrotsPlaced = 1,
		},
		Rewards = {
			Cash = 1000,
			Exp = 25,
		},
		PreviousQuest = "Quest_1",
		NextQuest = "Quest_3",
	},

	Quest_3 = {
		Type = "Quest",
		Name = "First Sale",
		Description = "Sell an item to a customer",
		Difficulty = "Easy",
		ImageId = "rbxassetid://15997912351",
		Tasks = {
			ItemsSold = 1,
		},
		Rewards = {
			Cash = 2000,
			Exp = 50,
		},
		PreviousQuest = "Quest_2",
		NextQuest = "Quest_4",
	},

	Quest_4 = {
		Type = "Quest",
		Name = "Tank Expansion",
		Description = "Unlock Tank 2",
		Difficulty = "Medium",
		ImageId = "rbxassetid://15997912352",
		Tasks = {
			TanksUnlocked = 1,
		},
		Rewards = {
			Cash = 5000,
			Plutonium = 5,
			Exp = 100,
		},
		PreviousQuest = "Quest_3",
		NextQuest = "Quest_5",
	},

	Quest_5 = {
		Type = "Quest",
		Name = "Power Up",
		Description = "Upgrade any tank to level 2",
		Difficulty = "Medium",
		ImageId = "rbxassetid://15997912353",
		Tasks = {
			TanksUpgraded = 1,
		},
		Rewards = {
			Cash = 10000,
			Plutonium = 10,
			Exp = 200,
		},
		PreviousQuest = "Quest_4",
	},

	------------------//ACHIEVEMENTS
	Achievement_Catch100 = {
		Type = "Achievement",
		Name = "Brainrot Hunter",
		Description = "Catch 100 brainrots total",
		Difficulty = "Medium",
		ImageId = "rbxassetid://15997912354",
		Tasks = {
			BrainrotsCaught = 100,
		},
		Rewards = {
			Cash = 25000,
			Plutonium = 25,
			Exp = 250,
		},
	},

	Achievement_Catch1000 = {
		Type = "Achievement",
		Name = "Brainrot Master",
		Description = "Catch 1000 brainrots total",
		Difficulty = "Hard",
		ImageId = "rbxassetid://15997912355",
		Tasks = {
			BrainrotsCaught = 1000,
		},
		Rewards = {
			Cash = 250000,
			Plutonium = 100,
			Exp = 2500,
		},
	},

	Achievement_Millionaire = {
		Type = "Achievement",
		Name = "Millionaire",
		Description = "Earn $1,000,000 total",
		Difficulty = "Hard",
		ImageId = "rbxassetid://15997912356",
		Tasks = {
			TotalCashEarned = "1000000",
		},
		Rewards = {
			Cash = 100000,
			Plutonium = 50,
			Exp = 5000,
		},
	},

	Achievement_AllTanks = {
		Type = "Achievement",
		Name = "Tank Collector",
		Description = "Unlock all 11 regular tanks",
		Difficulty = "Hard",
		ImageId = "rbxassetid://15997912357",
		Tasks = {
			TanksUnlocked = 11,
		},
		Rewards = {
			Cash = 500000,
			Plutonium = 200,
			Exp = 10000,
		},
	},

	Achievement_MaxLevel = {
		Type = "Achievement",
		Name = "Maximum Efficiency",
		Description = "Upgrade any tank to level 3",
		Difficulty = "Hard",
		ImageId = "rbxassetid://15997912358",
		Tasks = {
			MaxLevelTanks = 1,
		},
		Rewards = {
			Plutonium = 100,
			Exp = 1000,
		},
	},

	Achievement_PlayTime = {
		Type = "Achievement",
		Name = "Dedicated Player",
		Description = "Play for 1 hour total",
		Difficulty = "Easy",
		ImageId = "rbxassetid://15997912359",
		Tasks = {
			PlayTime = 3600,
		},
		Rewards = {
			Cash = 10000,
			Exp = 500,
		},
	},
}

------------------//FUNCTIONS
function MissionConfig.getMission(missionId: string)
	return MissionConfig.Missions[missionId]
end

function MissionConfig.getMissionsByType(missionType: string): {string}
	local missions = {}
	for missionId, missionDef in pairs(MissionConfig.Missions) do
		if missionDef.Type == missionType then
			table.insert(missions, missionId)
		end
	end
	return missions
end

function MissionConfig.getAllMissions(): {string}
	local missions = {}
	for missionId, _ in pairs(MissionConfig.Missions) do
		table.insert(missions, missionId)
	end
	return missions
end

function MissionConfig.getFirstQuest(): string?
	for missionId, missionDef in pairs(MissionConfig.Missions) do
		if missionDef.Type == "Quest" and not missionDef.PreviousQuest then
			return missionId
		end
	end
	return nil
end

function MissionConfig.getNextQuest(currentQuestId: string): string?
	local quest = MissionConfig.Missions[currentQuestId]
	return quest and quest.NextQuest
end

function MissionConfig.isQuestAvailable(questId: string, completedQuests: {string}): boolean
	local quest = MissionConfig.Missions[questId]
	if not quest or quest.Type ~= "Quest" then
		return false
	end

	if quest.PreviousQuest then
		return table.find(completedQuests, quest.PreviousQuest) ~= nil
	end

	return true
end

return MissionConfig
