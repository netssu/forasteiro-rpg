--// Services //--
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--// Dependencies //--
local Core = ServerScriptService.Core
local Codes = require(Core.UI.Codes)
local Settings = require(Core.UI.Settings)
local ToolUpgrades = require(Core.UI.ToolUpgrades)
local PlayerManager = require(Core.Player.PlayerManager)
local CatchingManager = require(Core.Catching.CatchingManager)

export type RemoteEntries = {}
export type RemoteConfig = {
	[string]: {Type: "Event" | "Function", Cooldown: number, Handler: (Player) -> ()}
}

--// Handlers //--
local module = {
	EquipTool = {
		Type = "Event",
		Cooldown = 0,
		Handler = function(player, toolName: string)
			if typeof(toolName) ~= "string" then
				warn(`[REMOTE] Invalid toolName type from {player.Name}`)
				return
			end

			local playerObject = PlayerManager.getPlayerObject(player)
			if not playerObject then
				warn(`[REMOTE] No PlayerObject for {player.Name}`)
				return
			end

			if not playerObject.ToolManager:isToolUnlocked(toolName) then
				warn(`[REMOTE] {player.Name} tried to equip locked tool: {toolName}`)
				return
			end

			playerObject:setEquippedTool(toolName)
--			print(`[REMOTE] {player.Name} equipped {toolName}`)
		end,
	},

	UnequipTool = {
		Type = "Event",
		Cooldown = 0,
		Handler = function(player, toolName: string)
			if typeof(toolName) ~= "string" then
				warn(`[REMOTE] Invalid toolName type from {player.Name}`)
				return
			end

			local playerObject = PlayerManager.getPlayerObject(player)
			if not playerObject then
				warn(`[REMOTE] No PlayerObject for {player.Name}`)
				return
			end

			local equippedTool = playerObject:getEquippedTool()
			if equippedTool == toolName then
				playerObject:setEquippedTool(nil)
	--			print(`[REMOTE] {player.Name} unequipped {toolName}`)
			else
				warn(`[REMOTE] {player.Name} tried to unequip {toolName} but has {equippedTool or "nothing"} equipped`)
			end
		end,
	},

	ActivateTool = {
		Type = "Event",
		Cooldown = 0.1,
		Handler = function(player, toolName: string)
			if typeof(toolName) ~= "string" then
				warn(`[REMOTE] Invalid toolName type from {player.Name}`)
				return
			end

			local playerObject = PlayerManager.getPlayerObject(player)
			if not playerObject then
				warn(`[REMOTE] No PlayerObject for {player.Name}`)
				return
			end

			local success = playerObject.ToolManager:activateTool(playerObject, toolName)

			if success then
			--	print(`[REMOTE] {player.Name} successfully activated {toolName}`)
			else
				print(`[REMOTE] {player.Name} failed to activate {toolName}`)
			end
		end,
	},
	
	UpdateSetting = {
		Type = "Event",
		Cooldown = 0,
		Handler = function(player: Player, statName: string)
			Settings.UpdateConfig(player, statName)
		end,
	},
	
	FinishTutorial = {
		Type = "Event",
		Cooldown = 0,
		Handler = function(player: Player)
			local data = player:FindFirstChild("Data")
			if not data then return end
			
			local tutorialValue: BoolValue = data:FindFirstChild("TutorialCompleted")
			if not tutorialValue then return end
			
			tutorialValue.Value = true
		end,
	},
}

return module :: RemoteConfig