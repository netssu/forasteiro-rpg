--// Services //--
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Events = Remotes:WaitForChild("Events")
local PurchaseRequest = Events:WaitForChild("PurchaseRequest")

--// Dependencies //--
local ConfigManager = require(script.Parent.Parent:WaitForChild("Configs"):WaitForChild("ConfigManager"))

local Purchase = {}

export type PurchaseType = "Pass" | "Product"

local function safePrompt(promptFunc: () -> ())
    local success, err = pcall(promptFunc)
    if not success then
        warn("[Purchase] Prompt failed:", err)
    end
    return success
end

function Purchase.attemptPurchase(player: Player, itemName:string)
	local itemInfo = ConfigManager.getItemInfo(itemName)
	if not itemInfo then
		warn("[Purchase] Item not found:", itemName)
		return
	end
	
	local purchaseType = (itemInfo.Currency ~= "Robux" and "Currency") or (itemInfo.PassID and "Pass") or "Product"
	
	print(purchaseType)
    if purchaseType == "Pass" then
        if safePrompt(function()
                MarketplaceService:PromptGamePassPurchase(player, itemInfo.PassID)
			end) 
		then
			--print("[Purchase] GamePass prompt shown:", itemInfo.PassID)
        end

    elseif purchaseType == "Product" then
        if safePrompt(function() 
				MarketplaceService:PromptProductPurchase(player, itemInfo.ProductID)
			end) 
        then
			--print("[Purchase] Product prompt shown:", itemInfo.ProductID)
        end
	elseif purchaseType == "Currency" then
		PurchaseRequest:FireServer(itemName)
	else
        warn("[Purchase] Invalid purchase type:", purchaseType)
    end
end
--[[
function Purchase.promptDirectPurchase(player: Player, itemName: string, itemType: string)
    local productId = shopStorage.getDirectProductId(itemName, itemType)
	if pr
    return false
endoductId then
        Purchase.promptPurchase(player, productId, "Product")
        return true
    end
]]
return Purchase
