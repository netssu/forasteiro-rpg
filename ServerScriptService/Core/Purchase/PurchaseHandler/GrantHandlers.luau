--// Services //--
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Dependencies //--
local Core = ServerScriptService.Core
local Shared = ReplicatedStorage.Shared

local TycoonManager = require(Core.Tycoon.TycoonManager)
local PlayerManager = require(Core.Player.PlayerManager)
local CurrencyManager = require(Core.Player.CurrencyManager)
local ToolManager = require(Core.Player.ToolManager)

local Configs = Shared.Configs
local ConfigManager = require(Configs.ConfigManager)
local CatchingSession = require(Core.Catching.CatchingSession)
local LuckyBlocksConfig = require(Configs.LuckyBlocksConfig)

local AddBrainrotToCage = ServerScriptService.Bindables.Catching.AddBrainrotToCage

local Utilities = Shared.Utilities
local BigNum = require(Utilities.BigNum)

--// Setup //--
local GrantHandlers = {}

--// Grant Handlers //--
local Handlers = {}

Handlers = {
	Tank = function(player: Player, tankName: string): boolean
		return TycoonManager.unlockTank(player, tankName)
	end,

	TankUpgrade = function(player: Player, tankName: string): boolean
		return TycoonManager.upgradeTank(player, tankName)
	end,
	
	LuckyBlocks = function(player: Player, variationName: string): boolean
		local info = LuckyBlocksConfig.getInfo(variationName)
		if not info then return false end

		local amount = LuckyBlocksConfig.getAmount(variationName)
		if amount <= 0 then return false end

		for i = 1, amount do
			local brainrotName = LuckyBlocksConfig.rollBrainrot()
			if brainrotName then
				grant_brainrot(player, brainrotName)
			end
		end

		return true
	end,

	Tool = function(player: Player, toolName: string): boolean
		return true --ToolManager.unlockTool(player, toolName)
	end,

	ToolUpgrade = function(player: Player, toolName: string, statName: string): boolean
		return true --ToolManager.upgradeTool(player, toolName, statName)
	end,

	UnlockTank = function(player: Player, tankName: string): boolean
		local tankInfo = ConfigManager.Tank.getTankInfo(tankName)
		if not tankInfo then return false end

		local purchaseResult = CurrencyManager.purchase(player, tankInfo.Price)
		if not purchaseResult.success then return false end

		return TycoonManager.unlockTank(player, tankName)
	end,

	UpgradeTank = function(player: Player, tankName: string): boolean
		local currentLevel = TycoonManager.getTankLevel(player, tankName)
		if not currentLevel then return false end

		local price = ConfigManager.Tank.calculateUpgradePrice(tankName, currentLevel)
		if not price then return false end

		local purchaseResult = CurrencyManager.purchase(player, price)
		if not purchaseResult.success then return false end

		return TycoonManager.upgradeTank(player, tankName)
	end,

	UnlockTool = function(player: Player, toolName: string): boolean
		local toolInfo = ConfigManager.Tool.getInfo(toolName)
		if not toolInfo then return false end

		local purchaseResult = CurrencyManager.purchase(player, toolInfo.UnlockPrice)
		if not purchaseResult.success then return false end

		return ToolManager.unlockTool(player, toolName)
	end,

	UpgradeTool = function(player: Player, toolName: string, statName: string): boolean
		if not statName then return false end

		local currentLevel = ToolManager.getToolLevel(player, toolName, statName)
		local nextLevel = currentLevel + 1
		local statInfo = ConfigManager.Tool.getStat(toolName, statName, nextLevel)

		if not statInfo then return false end

		local purchaseResult = CurrencyManager.purchase(player, statInfo.Price)
		if not purchaseResult.success then return false end

		return ToolManager.upgradeTool(player, toolName, statName)
	end,

	Cash = function(player: Player, amount: any): boolean
		return CurrencyManager.adjust(player,"Cash",amount)
	end,

	Plutonium = function(player: Player, amount: number): boolean
		return CurrencyManager.adjust(player,"Plutonium",amount)
	end,

	CashMultiplier = function(player: Player, itemName: string, multiplier: number): boolean
		local playerObj = PlayerManager.getPlayerObject(player)
		if not playerObj then return false end

		playerObj:setStatMultiplier("CashMultiplier", itemName, multiplier)
		return true
	end,

	Bundle = function(player: Player, itemName: string, purchaseType: string): boolean
		local item = ConfigManager.Shop.getShopItem(itemName)
		if not item or not item.Contents then return false end

		local contents = item.Contents

		if contents.Currency then
			if contents.Currency.Cash then
				Handlers.Cash(player, contents.Currency.Cash)
			end
			if contents.Currency.Plutonium then
				Handlers.Plutonium(player, contents.Currency.Plutonium)
			end
		end

		if contents.Items then
			for contentItemName, quantity in pairs(contents.Items) do
				for _ = 1, quantity do
					local category = ConfigManager.getCategory(contentItemName)
					if category then
						GrantHandlers.grantItem(player, {
							itemName = contentItemName,
							purchaseType = purchaseType,
							category = category
						})
					end
				end
			end
		end

		if contents.Stats then
			local playerObj = PlayerManager.getPlayerObject(player)
			if playerObj then
				local source = `Bundle_{itemName}`
				for statName, multiplier in pairs(contents.Stats) do
					playerObj:setStatMultiplier(statName, source, multiplier)
				end
			end
		end

		if contents.Special then
			for specialName, enabled in pairs(contents.Special) do
				if enabled then
					Handlers.Special(player, specialName)
				end
			end
		end

		return true
	end,

	Special = function(player: Player, itemName: string): boolean
		return false
	end,
}

--// Main Entry Point //--

function grant_brainrot(player: Player, brainrotName: string): ()
	CatchingSession.AddBrainrotCatch(player, brainrotName)

	if AddBrainrotToCage then
		if AddBrainrotToCage:IsA("BindableFunction") then
			pcall(function()
				AddBrainrotToCage:Invoke(player, brainrotName)
			end)
		elseif AddBrainrotToCage:IsA("BindableEvent") then
			AddBrainrotToCage:Fire(player, brainrotName)
		end
	end
end

function GrantHandlers.grantItem(player: Player, data: {
	itemName: string,
	purchaseType: string?,
	ignoreCash: boolean?,
	productId: number?,
	giftData: any?,
	category: string?,
	extraParam: string?
	}): boolean
	local itemName = data.itemName
	local category = data.category or ConfigManager.getCategory(itemName)

	if not category then
		warn(`Unknown item: {itemName}`)
		return false
	end

	local handler = Handlers[category]

	if not handler then
		warn(`No handler for category: {category}`)
		return false
	end

	local success = false

	if category == "Cash" or category == "Plutonium" then
		local amount = tonumber(string.match(itemName, "%d+")) or 0
		success = handler(player, amount)

	elseif category == "CashMultiplier" then
		local amount = tonumber(string.match(itemName, "%d+%.?%d*")) or 0
		success = handler(player, itemName, amount)

	elseif category == "Bundle" then
		success = handler(player, itemName, data.purchaseType)

	elseif category == "ToolUpgrade" or category == "UpgradeTool" then
		success = handler(player, itemName, data.extraParam)

	else
		success = handler(player, itemName)
	end

	if success then
		if category == "Tank" then
--[[			if MissionManager then
				MissionManager.updateProgress(player, {TanksUnlocked = 1})
			end]]
		elseif category == "TankUpgrade" then
--[[			if MissionManager then
				MissionManager.updateProgress(player, {TanksUpgraded = 1})
			end]]
		end
	end

	return success
end

return GrantHandlers