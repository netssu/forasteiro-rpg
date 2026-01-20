local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopStorage = require(ReplicatedStorage.ShopAndPurchases.ShopStorage)
-- Data store for persistent gamepass gifts
local GiftDataStore = DataStoreService:GetDataStore("PlayerGifts")

local GiftManager = {}

-- Store pending gifts: [productId] = {buyerId, recipientId, itemName, itemType, timestamp, originalCategory}
local pendingGifts = {}

-- Store gifted gamepasses per player for persistence
local playerGiftedGamepasses = {} -- [userId] = {[itemName] = true}

-- Info modules for unified lookup
local infoModules = {
    Ore = require(ReplicatedStorage.OreInfo),
    Brainrot = require(ReplicatedStorage.BrainrotInfo),
    Relic = require(ReplicatedStorage.RelicInfo)
}

---------------------------------------------------------------------------------------------------
-- CORE GIFT FUNCTIONS
---------------------------------------------------------------------------------------------------

-- Store pending gift data
function GiftManager.storePendingGift(productId: number, buyerId: number, recipientId: number, itemName: string, itemType: string?, originalCategory: string?)
    pendingGifts[productId] = {
        buyerId = buyerId,
        recipientId = recipientId, 
        itemName = itemName,
        itemType = itemType, -- nil for non-tool items like gamepasses
        originalCategory = originalCategory, -- Store original category for proper handling
        timestamp = tick()
    }

    -- Auto-cleanup after 5 minutes if not processed
    task.delay(300, function()
        if pendingGifts[productId] then
            pendingGifts[productId] = nil
            warn("Gift expired:", productId)
        end
    end)
end

-- Get and remove pending gift data
function GiftManager.consumePendingGift(productId: number)
    local giftData = pendingGifts[productId]
    if giftData then
        pendingGifts[productId] = nil
        return giftData
    end
    return nil
end

-- Validate gift before purchase
function GiftManager.validateGift(buyerId: number, recipientId: number): (boolean, string?)
    if buyerId == recipientId then
        return false, "Cannot gift to yourself"
    end

    local buyer = Players:GetPlayerByUserId(buyerId)
    local recipient = Players:GetPlayerByUserId(recipientId)

    if not buyer then
        return false, "Buyer not found"
    end
    if not recipient then
        return false, "Recipient not found"
    end

    return true
end

---------------------------------------------------------------------------------------------------
-- GAMEPASS GIFT PERSISTENCE
---------------------------------------------------------------------------------------------------

-- Load gifted gamepasses for a player
function GiftManager.loadPlayerGifts(player: Player)
    if playerGiftedGamepasses[player.UserId] then
        return -- Already loaded
    end

    local success, data = pcall(function()
        return GiftDataStore:GetAsync("Gifts_" .. player.UserId)
    end)

    if success and data then
        playerGiftedGamepasses[player.UserId] = data
    else
        playerGiftedGamepasses[player.UserId] = {}
    end
end

-- Save gifted gamepasses for a player
function GiftManager.savePlayerGifts(player: Player)
    local playerData = playerGiftedGamepasses[player.UserId]
    if not playerData then return end

    local success, error = pcall(function()
        GiftDataStore:SetAsync("Gifts_" .. player.UserId, playerData)
    end)

    if not success then
        warn("Failed to save player gifts:", error)
    end
end

-- Add a gifted gamepass to a player's data
function GiftManager.addPlayerGift(player: Player, itemName: string)
    if not playerGiftedGamepasses[player.UserId] then
        GiftManager.loadPlayerGifts(player)
    end

    playerGiftedGamepasses[player.UserId][itemName] = true
    GiftManager.savePlayerGifts(player)
end

-- Check if player has received a specific gift
function GiftManager.hasPlayerGift(player: Player, itemName: string): boolean
    if not playerGiftedGamepasses[player.UserId] then
        GiftManager.loadPlayerGifts(player)
    end

    return playerGiftedGamepasses[player.UserId][itemName] == true
end

---------------------------------------------------------------------------------------------------
-- GIFT TYPE DETECTION
---------------------------------------------------------------------------------------------------
-- Determine if an item is giftable and get its gift product ID
function GiftManager.getGiftInfo(itemName: string, itemType: string?): (boolean, number?, string?)
    -- Check tool-based items first
    if itemType and infoModules[itemType] then
        local itemInfo = infoModules[itemType].getInfo(itemName)
        if itemInfo and itemInfo.GiftProductID then
            return true, itemInfo.GiftProductID, itemType
        end
    end

    -- Check all tool types if itemType not specified
    if not itemType then
        for typeName, infoModule in pairs(infoModules) do
            local itemInfo = infoModule.getInfo and infoModule.getInfo(itemName)
            if itemInfo and itemInfo.GiftProductID then
                return true, itemInfo.GiftProductID, typeName
            end
        end
    end

    -- Check ShopStorage for non-tool items with GiftProductID
    local shopItem = ShopStorage.getShopItem(itemName)
    if shopItem and shopItem.GiftProductID then
        return true, shopItem.GiftProductID, shopItem.Category
    end

    return false, nil, nil
end

-- Get all giftable items
function GiftManager.getGiftableItems(): {[string]: {itemType: string?, category: string, giftProductId: number}}
    local giftableItems = {}

    -- Add tool-based items
    for typeName, infoModule in pairs(infoModules) do
        if infoModule.Info then
            for itemName, itemInfo in pairs(infoModule.Info) do
                if itemInfo.GiftProductID then
                    giftableItems[itemName] = {
                        itemType = typeName,
                        category = "Direct" .. typeName,
                        giftProductId = itemInfo.GiftProductID
                    }
                end
            end
        end
    end

    -- Add ShopStorage items with GiftProductID
    local ShopStorage = require(ReplicatedStorage.ShopAndPurchases.ShopStorage)
    for categoryName, items in pairs(ShopStorage.Storage) do
        for itemName, itemData in pairs(items) do
            if itemData.GiftProductID then
                giftableItems[itemName] = {
                    itemType = nil, -- Non-tool item
                    category = categoryName,
                    giftProductId = itemData.GiftProductID
                }
            end
        end
    end

    return giftableItems
end

---------------------------------------------------------------------------------------------------
-- EVENT HANDLERS
---------------------------------------------------------------------------------------------------

-- Clean up gifts when players leave
Players.PlayerRemoving:Connect(function(player)
    -- Clean up pending gifts
    for productId, giftData in pairs(pendingGifts) do
        if giftData.buyerId == player.UserId or giftData.recipientId == player.UserId then
            pendingGifts[productId] = nil
        end
    end

    -- Save player's gifted gamepass data
    GiftManager.savePlayerGifts(player)

    -- Clean up memory
    playerGiftedGamepasses[player.UserId] = nil
end)

-- Load player data when they join
Players.PlayerAdded:Connect(function(player)---------------------------MIGHT WANT TO MOVE TO LEADERSTATS
    -- Load after a short delay to ensure other systems are ready
    task.wait(2)
    GiftManager.loadPlayerGifts(player)
end)

---------------------------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
---------------------------------------------------------------------------------------------------

-- Debug function to get pending gifts
function GiftManager.getPendingGifts()
    return pendingGifts
end

-- Debug function to get player gift data
function GiftManager.getPlayerGiftData(player: Player)
    return playerGiftedGamepasses[player.UserId]
end

return GiftManager