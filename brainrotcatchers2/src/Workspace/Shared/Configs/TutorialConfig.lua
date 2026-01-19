local TutorialConfig = {}

export type TutorialStage = {
	Enabled:boolean,
	Spotlight: {
		Enabled: boolean,
		Position: UDim2,
		Size: UDim2,
		Ratio: number
	},
	Text: {
		Position: UDim2,
		Size: UDim2,
		Text: string
	},
}

TutorialConfig.Stages = {
	[0] = {
		Enabled = false,
		Spotlight = {
			Enabled = true,
			Position = UDim2.fromScale(0,0),
			Size = UDim2.fromScale(0,0),
			Ratio = 1
		},
		Text = {
			Text = `Welcome to Brainrot Catchers!`,
			Position = UDim2.fromScale(0.5,0.5),
			Size = UDim2.fromScale(0.6,0.25),	
		}
	},
	[1] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			Position = UDim2.fromScale(0.2,0.4),
			Size = UDim2.fromScale(0.3,0.6),
			Ratio = 0.5
		},
		Text = {
			Text = `Click the "Catch" button`,
			Position = UDim2.fromScale(0.5,0.028),
			Size = UDim2.fromScale(0.4,0.1),	
		}
	},
	[2] = {
		Enabled = true,
		Spotlight = {
			Enabled = false,
			Position = UDim2.fromScale(0.6,0.7),
			Size = UDim2.fromScale(0.1,0.2),
			Ratio = 2
		},
		Text = {
			Text = `wow good job`,
			Position = UDim2.fromScale(0.5,0.028),
			Size = UDim2.fromScale(0.4,0.1),	
		}
	},
	[3] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			Position = UDim2.fromScale(0.2,0.1),
			Size = UDim2.fromScale(0.3,0.6),
			Ratio = 4
		},
		Text = {
			Text = `amazing`,
			Position = UDim2.fromScale(0.5,0.028),
			Size = UDim2.fromScale(0.4,0.1),	
		}
	},
	[4] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			Position = UDim2.fromScale(0.9,0.4),
			Size = UDim2.fromScale(0.5,0.1),
			Ratio = 1
		},
		Text = {
			Text = `sigma`,
			Position = UDim2.fromScale(0.5,0.028),
			Size = UDim2.fromScale(0.4,0.1),	
		}
	},
	[5] = {
		Enabled = false
	},
}

function TutorialConfig.getStage(stageNumber: number) : TutorialStage
	stageNumber = tonumber(stageNumber)
	warn(stageNumber)
	return TutorialConfig.Stages[stageNumber]
end

return TutorialConfig
