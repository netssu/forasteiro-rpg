local ShopController = {}

-- SERVICES
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CONSTANTS
local ProductsData = require(ReplicatedStorage.Modules.Constants.ProductsData)
local PLAYER = Players.LocalPlayer
local MAIN_GUI = PLAYER.PlayerGui:WaitForChild("Main")

-- FUNCTIONS
local function findPurchaseButtons(gui)
	local buttons = {}
	for _, obj in ipairs(gui:GetDescendants()) do
		if obj:IsA("GuiButton") and obj:GetAttribute("ProductName") then
			table.insert(buttons, obj)
		end
	end
	return buttons
end

local function handlePurchase(button)
	local productName = button:GetAttribute("ProductName")
	local isGamepass = button:GetAttribute("IsGamepass")

	if not productName then return end

	if isGamepass then
		local gamepassData = ProductsData.Gamepasses[productName]
		if gamepassData then
			local success, doesOwn = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(PLAYER.UserId, gamepassData.GamepassId)
			end)

			if success and doesOwn then
				warn("Player already owns this gamepass: " .. productName)
				return 
			end

			MarketplaceService:PromptGamePassPurchase(PLAYER, gamepassData.GamepassId)
		end
	else
		local devProductData = ProductsData.DevProducts[productName]
		if devProductData then
			MarketplaceService:PromptProductPurchase(PLAYER, devProductData.ProductId)
		end
	end
end

-- INIT
function ShopController:Init()
	local shopGui = MAIN_GUI:WaitForChild("ShopFR", 10)
	local hudGui = MAIN_GUI:WaitForChild("HUDFR", 10)

	local buttons = {}
	if shopGui then
		for _, btn in ipairs(findPurchaseButtons(shopGui)) do
			table.insert(buttons, btn)
		end
	end
	if hudGui then
		for _, btn in ipairs(findPurchaseButtons(hudGui)) do
			table.insert(buttons, btn)
		end
	end

	for _, button in ipairs(buttons) do
		button.Activated:Connect(function()
			handlePurchase(button)
		end)
	end
end

return ShopController