local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GiveTools = ServerScriptService.Bindables.GiveTools

local ToolConfig = require(ReplicatedStorage.Shared.Configs.ToolConfig)
local ToolActivationHandlers = require(script.ToolActivationHandlers)

local ToolManager = {}
ToolManager.__index = ToolManager

export type ToolManager = {} & typeof(ToolManager)
export type ToolObjectData = {
	Player:Player,
	Tools:{[string]:ToolData},
	Cooldowns:{[string]: number}
}

export type ToolObject = ToolObjectData & ToolManager
export type ToolData = {
	Unlocked: boolean,
	Stats: {[string]: number}, -- Level of each stat
}

--// Constructor //--
function ToolManager.new(player: Player) : ToolObject
	local self = setmetatable({}, ToolManager)
	
	self.Player = player
	self.Tools = {}
	self.Cooldowns = {}
	
	self:initializeStarterTools()
	
	return self
end

--// Helper //--
local function initializeStats(toolName: string)
	local toolInfo = ToolConfig.getInfo(toolName)
	local toolStats = {}
	
	if toolInfo and toolInfo.Stats then
		for statName in pairs(toolInfo.Stats) do
			toolStats[statName] = 1
		end
	end
	
	return toolStats
end

--// Private Methods //--

-- Tool stuff
function ToolManager.initializeStarterTools(self: ToolObject)
	for _, toolName in ipairs(ToolConfig.getStarterTools()) do
		self.Tools[toolName] = {
			Unlocked = true,
			Stats = initializeStats(toolName),
		}
	end
end

function ToolManager.createTool(self: ToolObject, toolName: string, toolStats: {[string]: number})
	local toolTemplate = ReplicatedStorage.Assets.Tools:FindFirstChild(toolName)
	if not toolTemplate then
		warn(`Tool template not found: {toolName}`)
		return
	end
	
	local tool = toolTemplate:Clone()

	if toolStats then
		for statName, level in toolStats do
			local statInfo = ToolConfig.getStat(toolName, statName, level)
			if statInfo then
				tool:SetAttribute(statName, statInfo.Value)
			end
		end
	end
	
	local starterGear = self.Player:FindFirstChild("StarterGear")
	if starterGear then
		tool:Clone().Parent = starterGear
	end
	
	tool.Parent = self.Player.Backpack
end

-- Cooldown stuff
function ToolManager.isOnCooldown(self: ToolObject, toolName: string): boolean
	local lastUsed = self.Cooldowns[toolName]
	if not lastUsed then
		return false
	end

	local cooldownDuration = self:getToolStat(toolName, "Cooldown")
	if not cooldownDuration then
		return false
	end

	return (tick() - lastUsed) < cooldownDuration
end

function ToolManager.setCooldown(self: ToolObject, toolName: string)
	self.Cooldowns[toolName] = tick()
end

--// Tool Management //--
function ToolManager.removeTools(self: ToolObject)
	local backpack = self.Player:FindFirstChild("Backpack")
	local starterGear = self.Player:FindFirstChild("StarterGear")

	if backpack then
		backpack:ClearAllChildren()
	end
	if starterGear then
		starterGear:ClearAllChildren()
	end
	
	local character = self.Player.Character or self.Player.CharacterAdded:Wait()
	for _, tool in character:GetChildren() do
		if tool:IsA("Tool") then
			tool:Destroy()
		end
	end
end

function ToolManager.giveTools(self: ToolObject)
	local character = self.Player.Character or self.Player.CharacterAdded:Wait()
	self:removeTools()

	for toolName, toolData in pairs(self.Tools) do
		print(toolName, toolData)
		if toolData.Unlocked then
			print("pegou tool: " .. toolName)
			self:createTool(toolName, toolData.Stats)
		end
	end
end

function ToolManager.giveToolsWithPlayer(player: Player)
	
end

function ToolManager.unlockTool(self: ToolObject, toolName: string): boolean
	if self.Tools[toolName] and self.Tools[toolName].Unlocked then
		return false
	end

	self.Tools[toolName] = {
		Unlocked = true,
		Stats = initializeStats(toolName)
	}

	return true
end

function ToolManager.canUpgradeTool(self: ToolObject, toolName: string, statName: string): boolean
	local toolData = self.Tools[toolName]
	if not toolData or not toolData.Unlocked then
		return false
	end

	local currentLevel = toolData.Stats[statName] or 1

	if ToolConfig.isMaxLevel(toolName, statName, currentLevel) then
		return false
	end
	
	return true
end

function ToolManager.upgradeTool(self: ToolObject, toolName: string, statName: string): boolean
	if not self:canUpgradeTool(toolName, statName) then return end
	local toolData = self.Tools[toolName]
	
	local currentLevel = toolData.Stats[statName] or 1

	toolData.Stats[statName] = currentLevel + 1
	return true
end

function ToolManager.isToolUnlocked(self: ToolObject, toolName: string): boolean
	return self.Tools[toolName] and self.Tools[toolName].Unlocked or false
end

function ToolManager.getToolStatLevel(self: ToolObject, toolName: string, statName: string): number
	if not self.Tools[toolName] then
		return 1
	end

	return self.Tools[toolName].Stats[statName]
end

function ToolManager.getToolUpgradePrice(self: ToolObject, toolName: string, statName: string): number?
	local currentLevel = self:getToolStatLevel(toolName, statName)
	local nextLevel = currentLevel + 1

	local statInfo = ToolConfig.getStat(toolName, statName, nextLevel)
	return statInfo and statInfo.Price
end

function ToolManager.getToolStat(self: ToolObject, toolName: string, statName: string): number?
	local currentLevel = self:getToolStatLevel(toolName, statName)
	local statInfo = ToolConfig.getStat(toolName, statName, currentLevel)

	return statInfo and statInfo.Value
end

ToolManager.getPrice = ToolConfig.getPrice

--// Tool Activation //--

function ToolManager.activateTool(self: ToolObject, playerObject, toolName: string): boolean
	local equippedTool = playerObject.Player.Character and playerObject.Player.Character:FindFirstChildWhichIsA("Tool")
	if not equippedTool or equippedTool.Name ~= toolName then
		warn(`[ToolManager] {self.Player.Name} tried to activate {toolName} but has {equippedTool or "nothing"} equipped`)
		return false
	end

	if not self:isToolUnlocked(toolName) then
		warn(`[ToolManager] {self.Player.Name} tried to activate locked tool: {toolName}`)
		--return false
	end

	if self:isOnCooldown(toolName) then
		return false
	end

	local handler = ToolActivationHandlers[toolName]
	if not handler then
		warn(`[ToolManager] No activation handler for {toolName}`)
		return false
	end

	local success, result = pcall(handler, self.Player, self)
	if not success then
		warn(`[ToolManager] Error activating {toolName}: {result}`)
		return false
	end

	if result then
		self:setCooldown(toolName)
	end

	return result
end

--// Serialization //--

function ToolManager.serialize(self: ToolObject)
	return {
		Tools = self.Tools
	}
end

function ToolManager.deserialize(self: ToolObject, data)
	if not data or not data.Tools then return end

	self.Tools = data.Tools
end

GiveTools.Event:Connect(function(player: Player)
	
end)

return ToolManager :: ToolManager