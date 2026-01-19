--// Services //--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Configs = ReplicatedStorage.Shared.Configs

--// Dependencies //--
local Utilities = ReplicatedStorage.Shared.Utilities
local BigNum = require(Utilities.BigNum)

--// Configs //--
local TankConfig = require(Configs.TankConfig)
local BrainrotConfig = require(Configs.BrainrotConfig)
local ToolConfig = require(Configs.ToolConfig)
local GeneralConfig = require(Configs.GeneralConfig)
local MissionConfig = require(Configs.MissionConfig)
local ShopConfig = require(Configs.ShopConfig)
local TutorialConfig = require(Configs.TutorialConfig)

--// Unified Config Manager //--
local ConfigManager = {
	Tank = TankConfig,
	Brainrot = BrainrotConfig,
	Tool = ToolConfig,
--	Item = ItemConfig,
	General = GeneralConfig,
	Mission = MissionConfig,
	Shop = ShopConfig,
}

--// Helper //--
local function normalizePrice(price)
	if type(price) == "table" then
		return {
			Cash = price.Cash or 0,
			Plutonium = price.Plutonium or 0
		}
	elseif type(price) == "number" then
		return {Cash = price, Plutonium = 0}
	else
		warn("Invalid price format:", price)
		return {Cash = 0, Plutonium = 0}
	end
end
--// APIs //--

function ConfigManager.getItemInfo(itemName: string) : ShopConfig.ShopItem & BrainrotConfig.BrainrotInfo 
	return BrainrotConfig.getInfo(itemName)
		or ToolConfig.getInfo(itemName)
--		or ItemConfig.getInfo(itemName)
		or ShopConfig.getShopItem(itemName)
	or TutorialConfig.getStage(itemName)
end

-- Get price for any purchasable item
function ConfigManager.getPrice(itemName: string, extraData): number | {Cash: number, Plutonium: number}?
	-- Extra data prices
	if extraData then
		if extraData.Type == "UnlockTank" then
			local tankInfo = TankConfig.getTankInfo(itemName)
			if tankInfo then
				local price = tankInfo.Price
				local finalPrice = normalizePrice(price)
				return finalPrice
			end

		elseif extraData.Type == "UpgradeTank" then	
			if not extraData.TankLevel then
				warn("TankLevel not given when getting upgrade price")
			end
			return TankConfig.calculateUpgradePrice(itemName, extraData.TankLevel)
		end
	end
	-- Normal prices
	-- Check shop
	local shopItem = ShopConfig.getShopItem(itemName)
	if shopItem then
		return shopItem.Price
	end

	-- Check tools -- gonna need upgrade price later
	local toolInfo = ToolConfig.getInfo(itemName)
	if toolInfo then
		return toolInfo.UnlockPrice
	end

	return nil
end

function ConfigManager.getCategory(itemName: string): string?
	if TankConfig.getTankInfo(itemName) then
		return "Tank"
	elseif BrainrotConfig.getInfo(itemName) then
		return "Brainrot"
	elseif ToolConfig.getInfo(itemName) then
		return "Tool"
--	elseif ItemConfig.getInfo(itemName) then
--		return "Item"
	elseif ShopConfig.getShopItem(itemName) then
		return ShopConfig.getCategory(itemName)
	end

	return nil
end

return ConfigManager