--// Services //--
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Dependencies //--
local Core = ServerScriptService.Core
local Shared = ReplicatedStorage.Shared

local GrantHandlers = require(script.GrantHandlers)

local Configs = Shared.Configs
local ShopConfig = require(Configs.ShopConfig)

local Remotes = ReplicatedStorage.Remotes
local PurchaseRequest = Remotes.Events.PurchaseRequest
local PurchaseResponse = Remotes.Events.PurchaseResponse

--// DataStores //--
local PurchaseHistoryStore = DataStoreService:GetDataStore("PurchaseHistory")
local GiftDataStore = DataStoreService:GetDataStore("PlayerGifts")

--// Module //--
local PurchaseHandler = {}

--// State //--
PurchaseHandler.PendingGifts = {}
local PlayerGiftedItems = {}

--// Helper Functions //--
local function cleanupExpiredGifts()
	local currentTime = tick()
	for productId, giftData in pairs(PurchaseHandler.PendingGifts) do
		if currentTime - giftData.timestamp > 300 then
			PurchaseHandler.PendingGifts[productId] = nil
			warn(`Gift expired: {productId}`)
		end
	end
end

task.spawn(function()
	while true do
		task.wait(60)
		cleanupExpiredGifts()
	end
end)

local function loadPlayerGifts(player: Player)
	if PlayerGiftedItems[player.UserId] then
		return
	end

	local success, data = pcall(function()
		return GiftDataStore:GetAsync("Gifts_" .. player.UserId)
	end)

	PlayerGiftedItems[player.UserId] = (success and data) or {}
end

local function savePlayerGifts(player: Player)
	local playerData = PlayerGiftedItems[player.UserId]
	if not playerData then return end

	pcall(function()
		GiftDataStore:SetAsync("Gifts_" .. player.UserId, playerData)
	end)
end

local function addPlayerGift(player: Player, itemName: string)
	if not PlayerGiftedItems[player.UserId] then
		loadPlayerGifts(player)
	end

	PlayerGiftedItems[player.UserId][itemName] = true
	savePlayerGifts(player)
end

local function hasPlayerGift(player: Player, itemName: string): boolean
	if not PlayerGiftedItems[player.UserId] then
		loadPlayerGifts(player)
	end

	return PlayerGiftedItems[player.UserId][itemName] == true
end

--// Receipt Processing //--
local function processProductReceipt(receiptInfo)
	local success, alreadyGranted = pcall(function()
		return PurchaseHistoryStore:GetAsync(receiptInfo.PurchaseId)
	end)

	if success and alreadyGranted then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local itemName, category = ShopConfig.getItemFromProductID(receiptInfo.ProductId)
	if not itemName or not category then
		warn(`[PurchaseHandler] Unknown ProductId: {receiptInfo.ProductId}. Check ShopConfig!`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local giftData = PurchaseHandler.PendingGifts[receiptInfo.ProductId]
	local isGift = giftData ~= nil

	if isGift then
		player = Players:GetPlayerByUserId(giftData.recipientId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		PurchaseHandler.PendingGifts[receiptInfo.ProductId] = nil
	end

	local grantSuccess = GrantHandlers.grantItem(player, {
		itemName = itemName,
		purchaseType = isGift and "Gift" or "DevProduct",
		productId = receiptInfo.ProductId,
		giftData = giftData,
		category = category
	})

	if grantSuccess then
		pcall(function()
			PurchaseHistoryStore:SetAsync(receiptInfo.PurchaseId, true)
		end)

		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		warn(`[PurchaseHandler] Grant failed for {itemName} (Category: {category})`)
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.ProcessReceipt = processProductReceipt

--// Gamepass Handling //--
function PurchaseHandler.checkAndGrantGamepasses(player: Player)
	local waitTime = 0
	repeat
		task.wait(0.5)
		waitTime += 0.5
	until player:GetAttribute("DataLoaded") or waitTime > 30

	task.wait(2)
	loadPlayerGifts(player)

	for category, items in pairs(ShopConfig.Storage) do
		for itemName, item in pairs(items) do
			if item.PassID then
				if hasPlayerGift(player, itemName) then
					GrantHandlers.grantItem(player, {
						itemName = itemName,
						purchaseType = "Gift",
						category = category
					})
				else
					local success, owns = pcall(function()
						return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.PassID)
					end)

					if success and owns then
						GrantHandlers.grantItem(player, {
							itemName = itemName,
							purchaseType = "Gamepass",
							category = category
						})
					end
				end
			end
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passID, purchased)
	if not purchased then return end

	local itemName, category = ShopConfig.getItemFromPassID(passID)
	if not itemName or not category then return end

	local giftData = nil
	for productId, data in pairs(PurchaseHandler.PendingGifts) do
		if data.itemName == itemName and data.buyerId == player.UserId then
			giftData = data
			PurchaseHandler.PendingGifts[productId] = nil
			break
		end
	end

	if giftData then
		local recipient = Players:GetPlayerByUserId(giftData.recipientId)
		if recipient then
			addPlayerGift(recipient, itemName)
			GrantHandlers.grantItem(recipient, {
				itemName = itemName,
				purchaseType = "Gift",
				giftData = giftData,
				category = category
			})
		end
	else
		GrantHandlers.grantItem(player, {
			itemName = itemName,
			purchaseType = "Gamepass",
			category = category
		})
	end
end)

--// Purchase Requests //--
PurchaseRequest.OnServerEvent:Connect(function(player, purchaseData)
	if not purchaseData or not purchaseData.Type then
		PurchaseResponse:FireClient(player, {success = false, message = "Invalid purchase data"})
		return
	end

	local result = GrantHandlers.grantItem(player, {
		itemName = purchaseData.Param1,
		purchaseType = purchaseData.Type,
		category = purchaseData.Type,
		extraParam = purchaseData.Param2
	})

	PurchaseResponse:FireClient(player, {success = result})
end)

--// Gift System //--
function PurchaseHandler.sendGift(buyer: Player, itemName: string, category: string?, recipientUserId: number)
	if buyer.UserId == recipientUserId then
		return
	end

	local recipient = Players:GetPlayerByUserId(recipientUserId)
	if not recipient then
		return
	end

	local isGiftable, giftProductId = ShopConfig.isGiftable(itemName)
	if not isGiftable or not giftProductId then
		return
	end

	local item = ShopConfig.getShopItem(itemName, category)
	if not item then
		return
	end

	PurchaseHandler.PendingGifts[giftProductId] = {
		buyerId = buyer.UserId,
		recipientId = recipientUserId,
		itemName = itemName,
		category = category or item.Category,
		timestamp = tick()
	}

	if item.PassID then
		MarketplaceService:PromptGamePassPurchase(buyer, item.PassID)
	else
		MarketplaceService:PromptProductPurchase(buyer, giftProductId)
	end
end

--// Cleanup //--
function PurchaseHandler.cleanupPlayer(player: Player)
	for productId, giftData in pairs(PurchaseHandler.PendingGifts) do
		if giftData.buyerId == player.UserId or giftData.recipientId == player.UserId then
			PurchaseHandler.PendingGifts[productId] = nil
		end
	end

	savePlayerGifts(player)
	PlayerGiftedItems[player.UserId] = nil
end

return PurchaseHandler