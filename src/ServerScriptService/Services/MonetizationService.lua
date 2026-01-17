local MonetizationService = {}

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local MonetizationTable = require(ReplicatedStorage.Arrays.MonetizationTable)
local vfxPlayer = require(game.ReplicatedStorage["A-Packages"].VFXPlayer)

local function listener(player, productId, isGamePass)
	if isGamePass then
		if MarketplaceService:UserOwnsGamePassAsync(player, productId) then
			print(player.Name .. " owns gamepass " .. productId)
			MonetizationTable[tostring(productId)](player)
		end
	else
		print(player.Name .. " purchased developer product " .. productId)

		MonetizationTable[tostring(productId)](player, PlayerDataService)
	end
end

function MonetizationService.Handler()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, productId, wasPurchased)
		if wasPurchased then
			listener(Players:GetPlayerByUserId(player), productId, true)
			vfxPlayer.play(Players:GetPlayerByUserId(player), script.Robux)
		end
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, wasPurchased)
		if wasPurchased then
			listener(Players:GetPlayerByUserId(player), productId, false)
			vfxPlayer.play(Players:GetPlayerByUserId(player), script.Robux)
		end
	end)
end

return MonetizationService
