local ToolConfig = {}

export type ToolInfo = {
	Name: string,
	Type: string,
	UnlockPrice: number,
	IsStarter: boolean,
	Description: string,
	Stats: {[string]: { [number]: {Value:number, Price:number} }},
}

export type Tools = {
	Tools: {[string]: ToolInfo},
}

export type ToolConfig = typeof(ToolConfig) & Tools
--// Tool Definitions //--
ToolConfig.Tools = {
	-- Starter Tools (Free)
	Brain = {
		Name = "Brain",
		Type = "Attractant",
		UnlockPrice = 0,
		IsStarter = true,
		Description = "Attracts brainrots from mud puddles",
		Stats = {
			Range = {
				[1] = {Value = 25, Price = 0},
				[2] = {Value = 40, Price = 500},
				[3] = {Value = 50, Price = 2000},
			},
			Cooldown = {
				[1] = {Value = 3, Price = 0},
				[2] = {Value = 2, Price = 500},
				[3] = {Value = 1, Price = 2000},
			}
		}
	},

	Shotgun = {
		Name = "Shotgun",
		Type = "Weapon",
		UnlockPrice = 0,
		IsStarter = true, -- true just for while
		Description = "Close-range spread weapon",
		Stats = {
			--[[
			Damage = {-- Per pellet
				[1] = {Value = 10, Price = 0}, 
				[2] = {Value = 15, Price = 1000},
				[3] = {Value = 22, Price = 5000},
				[4] = {Value = 30, Price = 15000},
			},
			]]--
			Pellets = {
				[1] = {Value = 6, Price = 0},
				[2] = {Value = 8, Price = 1000},
				[3] = {Value = 10, Price = 5000},
				[4] = {Value = 12, Price = 15000},
			},
			Spread = {-- Degrees
				[1] = {Value = 15, Price = 0}, 
				[2] = {Value = 12, Price = 1000},
				[3] = {Value = 10, Price = 5000},
				[4] = {Value = 8, Price = 15000},
			},
			Cooldown = {
				[1] = {Value = 1.2, Price = 0},
				[2] = {Value = 0.8, Price = 40000},
				[3] = {Value = 0.5, Price = 60000},
				[4] = {Value = 0.3, Price = 80000},
			},
		}
	},

	Harpoon = {
		Name = "Harpoon",
		Type = "Weapon",
		UnlockPrice = 2500,
		IsStarter = true,
		Description = "Stuns and pulls brainrots",
		Stats = {
			--[[
			Damage = {
				[1] = {Value = 25, Price = 0},
				[2] = {Value = 40, Price = 3000},
				[3] = {Value = 60, Price = 10000},
			},
			PullSpeed = {
				[1] = {Value = 20, Price = 0},
				[2] = {Value = 25, Price = 3000},
				[3] = {Value = 30, Price = 10000},
			},
			StunDuration = {
				[1] = {Value = 2, Price = 0}, -- Seconds
				[2] = {Value = 3, Price = 3000},
				[3] = {Value = 4, Price = 10000},
			},
			]]--
			Length = {
				[1] = {Value = 15, Price = 0},
				[2] = {Value = 22, Price = 3000},
				[3] = {Value = 38, Price = 9000},
				[4] = {Value = 60, Price = 25000},
			},
			Cooldown = {
				[1] = {Value = 2, Price = 0},
				[2] = {Value = 1.5, Price = 1800},
				[3] = {Value = 1, Price = 5000},
				[4] = {Value = 0.5, Price = 16000},
			}
		}
	},

	Jetpack = {
		Name = "Jetpack",
		Type = "Movement",
		UnlockPrice = 0,
		IsStarter = true, -- true just for while
		Description = "Boosts upward or forward",
		Stats = {
			Flight_Boost = {
				[1] = {Value = 10, Price = 0},
				[2] = {Value = 20, Price = 6000},
				[3] = {Value = 35, Price = 14000},
				[4] = {Value = 50, Price = 30000},
			},
			Flight_Duration = {
				[1] = {Value = 1, Price = 0},
				[2] = {Value = 3, Price = 4500},
				[3] = {Value = 5, Price = 10000},
				[4] = {Value = 10, Price = 25000},
			},
			Speed = {
				[1] = {Value = 30, Price = 0},
				[2] = {Value = 40, Price = 800},
				[3] = {Value = 50, Price = 3000},
				[4] = {Value = 60, Price = 10000},
			},
			Fuel = {
				[1] = {Value = 100, Price = 0},
				[2] = {Value = 150, Price = 800},
				[3] = {Value = 200, Price = 3000},
				[4] = {Value = 300, Price = 10000},
			},
			Recharge = {
				[1] = {Value = 20, Price = 0}, -- Fuel per second
				[2] = {Value = 30, Price = 800},
				[3] = {Value = 40, Price = 3000},
				[4] = {Value = 50, Price = 10000},
			}
		}
	},

	-- Future Tools (Commented out for now)
	--[[
	Net = {
		Name = "Net",
		Type = "Weapon",
		UnlockPrice = 5000,
		IsStarter = false,
		Description = "Captures brainrots instantly",
		Stats = {
			Range = {
				[1] = {Value = 10, Price = 0},
				[2] = {Value = 15, Price = 2000},
				[3] = {Value = 20, Price = 8000},
			},
			Cooldown = {
				[1] = {Value = 10, Price = 0},
				[2] = {Value = 8, Price = 2000},
				[3] = {Value = 6, Price = 8000},
			}
		}
	},

	Rocket = {
		Name = "Rocket",
		Type = "Weapon",
		UnlockPrice = 25000,
		IsStarter = false,
		Description = "Area-of-effect explosive",
		Stats = {
			Damage = {
				[1] = {Value = 50, Price = 0},
				[2] = {Value = 75, Price = 10000},
				[3] = {Value = 100, Price = 30000},
			},
			Radius = {
				[1] = {Value = 10, Price = 0},
				[2] = {Value = 15, Price = 10000},
				[3] = {Value = 20, Price = 30000},
			},
			Cooldown = {
				[1] = {Value = 15, Price = 0},
				[2] = {Value = 12, Price = 10000},
				[3] = {Value = 10, Price = 30000},
			}
		}
	},
	]]
}

--// Input Action Definitions //--
ToolConfig.InputActions = {
	Brain = {
		Throw = Enum.UserInputType.MouseButton1, -- doesnt exist MouseButton1 in KeyCode, just in UserInputType
		IsStarter = true,
		ThrowMobile = "ThrowBrain",
	},
	Shotgun = {
		Fire = Enum.UserInputType.MouseButton1,
		IsStarter = true,
		FireMobile = "FireShotgun",
	},
	Harpoon = {
		Fire = Enum.UserInputType.MouseButton1,
		FireMobile = "FireHarpoon",
	},
	Jetpack = {
		Boost = Enum.KeyCode.Space,
		BoostMobile = "JetpackBoost",
	}
}

--// Helper Functions //--

function ToolConfig.getInfo(toolName: string) : ToolInfo
	return ToolConfig.Tools[toolName]
end

function ToolConfig.getAllTools(): {string}
	local tools = {}
	for name, _ in pairs(ToolConfig.Tools) do
		table.insert(tools, name)
	end
	return tools
end

function ToolConfig.getStarterTools(): {string}
	local starters = {}
	for name, info in pairs(ToolConfig.Tools) do
		if info.IsStarter then
			print(name)
			table.insert(starters, name)
		end
	end
	return starters
end

function ToolConfig.getUnlockableTools(): {string}
	local unlockable = {}
	for name, info in pairs(ToolConfig.Tools) do
		if not info.IsStarter then
			table.insert(unlockable, name)
		end
	end
	return unlockable
end

local function getTool(toolName: string)
	local tool = ToolConfig.Tools[toolName]
	if not tool then warn(`[ToolConfig] config of tool: {toolName} doesn't exist!`) return end
	
	return tool
end

function ToolConfig.getStat(toolName: string, statName: string, level: number): number?
	local tool = getTool(toolName)
	if not tool or not tool.Stats or not tool.Stats[statName] then
		return nil
	end

	return tool.Stats[statName][level]
end

function ToolConfig.getPrice(toolName: string): number
	local tool = getTool(toolName)
	if not tool or not tool.UnlockPrice then return end
	
	return tool.UnlockPrice
end

function ToolConfig.getMaxLevel(toolName: string, statName: string): number
	local tool = getTool(toolName)
	if not tool or not tool.Stats or not tool.Stats[statName] then
		return 1
	end

	return #tool.Stats[statName]
end

function ToolConfig.isMaxLevel(toolName: string, statName: string, currentLevel: number): boolean
	return currentLevel >= ToolConfig.getMaxLevel(toolName, statName)
end

function ToolConfig.getInputAction(toolName: string, actionName: string)
	return ToolConfig.InputActions[toolName] and ToolConfig.InputActions[toolName][actionName]
end

return ToolConfig