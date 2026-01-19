local ToolUpgrades = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")	

local remotes = ReplicatedStorage.Remotes
local remoteFunctions = remotes.Functions
local toolUpgradeEvents = remotes.Events.ToolUpgrade

local PlayerManager = require(ServerScriptService.Core.Player.PlayerManager)
local CurrencyManager = require(ServerScriptService.Core.Player.CurrencyManager)

local toolManager : {}

remoteFunctions.Info.GetToolData.OnServerInvoke = function(player: Player, toolName: string)
	local playerObject = PlayerManager.getPlayerObject(player)
	if not playerObject then return end
	
	--print(toolName)
	--print(playerObject.ToolManager.Tools)
	
	return playerObject.ToolManager.Tools[toolName]
end

toolUpgradeEvents.BuyTool.OnServerEvent:Connect(function(player: Player, toolName: string)
	local playerObject = PlayerManager.getPlayerObject(player)
	if not playerObject then return end
	
	local toolManager = playerObject.ToolManager
	
	if not toolManager:isToolUnlocked(toolName) or not toolManager.getPrice(toolName) then return end
	local price = toolManager.getPrice(toolName)
	
	if CurrencyManager.getValue(player, "Cash") < price then return end
	if not toolManager:unlockTool(toolName) then return end
	
	CurrencyManager.adjust(player, "Cash", -price)
	toolUpgradeEvents.BuyTool:FireClient(player, toolName)
end)

toolUpgradeEvents.UpgradeToolStat.OnServerEvent:Connect(function(player: Player, toolName: string, statName: string)
	local playerObject = PlayerManager.getPlayerObject(player)
	if not playerObject then
		warn("error")
		return 
	end
	
	toolManager = playerObject.ToolManager

	if not toolManager then
		toolManager = require(ServerScriptService.Core.Player.ToolManager)
	end
	
	warn(toolName, statName)
	if not toolManager:canUpgradeTool(toolName, statName) then warn("error") return end

	local price = toolManager:getToolUpgradePrice(toolName, statName)
	--print(price)

	if CurrencyManager.getValue(player, "Cash") < price then warn("error") return end
	if not toolManager:upgradeTool(toolName, statName) then warn("error") return end

	warn("success")
	CurrencyManager.adjust(player, "Cash", -price)
	toolUpgradeEvents.UpdateToolUpgrade:FireClient(player)
end)

return ToolUpgrades
