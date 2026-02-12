local TutorialConfig = {}

------------------//SERVICES

------------------//CONSTANTS

------------------//VARIABLES

------------------//FUNCTIONS
function TutorialConfig.getStage(stageNumber: number)
	stageNumber = tonumber(stageNumber)

	if not stageNumber then
		warn("[TutorialConfig] Invalid stage number provided")
		return nil
	end

	local stage = TutorialConfig.Stages[stageNumber]

	if not stage then
		warn("[TutorialConfig] Stage", stageNumber, "not found")
		return nil
	end

	return stage
end

function TutorialConfig.getTotalStages(): number
	local count = 0
	for _ in pairs(TutorialConfig.Stages) do
		count += 1
	end
	return count
end

function TutorialConfig.stageExists(stageNumber: number): boolean
	return TutorialConfig.Stages[stageNumber] ~= nil
end

function TutorialConfig.getAllStages()
	return TutorialConfig.Stages
end

------------------//INIT
TutorialConfig.Stages = {

	[0] = {
		Enabled = true,
		Spotlight = {
			Enabled = false,
			Padding = 0,
			Ratio = 1
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "🎉 Welcome to Pogo Jump! 🎉\nLet's learn how to play!",
			Position = UDim2.fromScale(0.5, 0.15),
			Size = UDim2.fromScale(0.8, 0.2),
			TextSize = 26
		},
		WaitForCondition = "Wait",
		ConditionValue = 2.5
	},

	[1] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			GuiPath = "UI.GameHUD.BottomBarFR.JumpBT",
			Padding = 15,
			Ratio = 1
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "👆 Click the Pogo button or press SPACE to jump!\n⏱️ Click again when the bar is near the end for perfect landings!",
			Position = UDim2.fromScale(0.5, 0.12),
			Size = UDim2.fromScale(0.85, 0.22),
			TextSize = 20
		},
		WaitForCondition = "CoinsReached",
		ConditionValue = 400
	},

	[2] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			GuiPath = "UI.GameHUD.LeftBTFR.Shop",
			Padding = 14,
			Ratio = 1
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "🛒 Great jumping! Now let's open the Shop!",
			Position = UDim2.fromScale(0.5, 0.15),
			Size = UDim2.fromScale(0.75, 0.16),
			TextSize = 22
		},
		WaitForCondition = "ButtonClick",
		ConditionValue = "Shop"
	},

	[3] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			GuiPath = "UI.Shop.CategoryFR.CategoryBG.BTPogos",
			Padding = 12,
			Ratio = 1.2
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "🎯 Click on the Pogos tab!",
			Position = UDim2.fromScale(0.5, 0.15),
			Size = UDim2.fromScale(0.65, 0.15),
			TextSize = 22
		},
		WaitForCondition = "ButtonClick",
		ConditionValue = "Pogos"
	},

	[4] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			GuiPath = "DYNAMIC_FIRST_POGO",
			Padding = 10,
			Ratio = 0.9
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "💰 Purchase a new pogo!\nBetter pogos = Higher jumps = More rewards!",
			Position = UDim2.fromScale(0.5, 0.12),
			Size = UDim2.fromScale(0.8, 0.2),
			TextSize = 20
		},
		WaitForCondition = "Purchase",
		ConditionValue = "Pogo"
	},

	[5] = {
		Enabled = true,
		Spotlight = {
			Enabled = false,
			Padding = 0,
			Ratio = 1
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "✅ Perfect! Now close the shop.",
			Position = UDim2.fromScale(0.5, 0.15),
			Size = UDim2.fromScale(0.65, 0.15),
			TextSize = 22
		},
		WaitForCondition = "ShopClosed",
		ConditionValue = true
	},

	[6] = {
		Enabled = true,
		Spotlight = {
			Enabled = false,
			Padding = 0,
			Ratio = 1
		},
		Trail = {
			Enabled = true,
			TargetType = "World",
			TargetPath = "Here"
		},
		Text = {
			Text = "🥚 Walk to the Common Egg!\nFollow the yellow beam!\n🎁 Purchase it to get your first pet!",
			Position = UDim2.fromScale(0.5, 0.12),
			Size = UDim2.fromScale(0.85, 0.24),
			TextSize = 20
		},
		WaitForCondition = "EggPurchase",
		ConditionValue = "CommonEgg"
	},

	[7] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			GuiPath = "UI.GameHUD.BottomBarFR.Inventory",
			Padding = 14,
			Ratio = 1
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "🎒 Awesome! Now open your Inventory!",
			Position = UDim2.fromScale(0.5, 0.15),
			Size = UDim2.fromScale(0.75, 0.16),
			TextSize = 22
		},
		WaitForCondition = "ButtonClick",
		ConditionValue = "Inventory"
	},

	[8] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			GuiPath = "UI.Inventory.CategoryFR.CategoryBG.BTPets",
			Padding = 12,
			Ratio = 1.2
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "🐾 Click on the Pets tab!",
			Position = UDim2.fromScale(0.5, 0.15),
			Size = UDim2.fromScale(0.65, 0.15),
			TextSize = 22
		},
		WaitForCondition = "ButtonClick",
		ConditionValue = "Pets"
	},

	[9] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			GuiPath = "DYNAMIC_FIRST_PET",
			Padding = 12,
			Ratio = 1
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "🐾 Click on your pet to equip it!",
			Position = UDim2.fromScale(0.5, 0.15),
			Size = UDim2.fromScale(0.7, 0.15),
			TextSize = 22
		},
		WaitForCondition = "PetEquipped",
		ConditionValue = true
	},

	[10] = {
		Enabled = true,
		Spotlight = {
			Enabled = false,
			Padding = 0,
			Ratio = 1
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "✨ Pets give you multipliers!\n📈 More pets = Better rewards!\n🌟 Collect them all!",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.85, 0.28),
			TextSize = 22
		},
		WaitForCondition = "Wait",
		ConditionValue = 3.5
	},

	[11] = {
		Enabled = true,
		Spotlight = {
			Enabled = false,
			Padding = 0,
			Ratio = 1
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "👍 Great! Now close the inventory.",
			Position = UDim2.fromScale(0.5, 0.15),
			Size = UDim2.fromScale(0.7, 0.15),
			TextSize = 22
		},
		WaitForCondition = "InventoryClosed",
		ConditionValue = true
	},

	[12] = {
		Enabled = true,
		Spotlight = {
			Enabled = false,
			Padding = 0,
			Ratio = 1
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "🎊 Tutorial Complete! 🎊\n\n🏆 Keep jumping to unlock rebirths!\n💎 Earn better rewards!\n🚀 Become the ultimate Pogo Champion!\n\nGood luck! 🌟",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.9, 0.4),
			TextSize = 20
		},
		WaitForCondition = "Wait",
		ConditionValue = 5
	},

	[13] = {
		Enabled = false
	}
}

return TutorialConfig