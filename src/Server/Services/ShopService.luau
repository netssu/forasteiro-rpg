local ShopService = {}

-- SERVICES
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CONSTANTS
local ProductsData = require(ReplicatedStorage.Modules.Constants.ProductsData)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local BoostService = require(script.Parent.BoostService)

-- FUNCTIONS
local function processDevProduct(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local productEntry = ProductsData.ProductIdMap[receipt.ProductId]
	if not productEntry then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local data = productEntry.Data
	local success = pcall(function()
		if data.Type == "Coins" then
			PlayerDataManager:Increment(player, {"Currency", "Coins"}, data.Amount)
		elseif data.Type == "Boost" then
			BoostService:ActivateBoost(player, data.BoostKey)
		end
	end)

	return success and Enum.ProductPurchaseDecision.PurchaseGranted or Enum.ProductPurchaseDecision.NotProcessedYet
end

local function onGamepassPurchased(player, gamepassId, wasPurchased)
	if not wasPurchased then return end

	for name, data in pairs(ProductsData.Gamepasses) do
		if data.GamepassId == gamepassId then
			pcall(function()
				PlayerDataManager:Set(player, {"Gamepasses", name}, true)
			end)
            
            if name == "StarterPack" then
                pcall(function()
                    PlayerDataManager:Increment(player, {"Currency", "Coins"}, 2000)
                end)
            end

			if data.BoostKey then
				BoostService:ActivateBoost(player, data.BoostKey)
			end
			break
		end
	end
end

local function syncGamepasses(player)
	for name, data in pairs(ProductsData.Gamepasses) do
		local success, owned = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, data.GamepassId)
		end)

		if success and owned then
			PlayerDataManager:Set(player, {"Gamepasses", name}, true)

			if data.BoostKey then
				BoostService:ActivateBoost(player, data.BoostKey)
			end
		end
	end
end

-- INIT
function ShopService:Init()
	MarketplaceService.ProcessReceipt = processDevProduct
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamepassPurchased)
	Players.PlayerAdded:Connect(syncGamepasses)
end

return ShopService