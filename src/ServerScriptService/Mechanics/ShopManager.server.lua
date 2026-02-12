------------------//SERVICES
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local BOOST_DURATION = 120

------------------//VARIABLES
local ProductsData = require(ReplicatedStorage.Modules.Datas.ProductsData)
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)

local processingPurchases = {}

------------------//FUNCTIONS
local function give_coins(player: Player, amount: number)
	local currentCoins = DataUtility.server.get(player, "Coins") or 0
	DataUtility.server.set(player, "Coins", currentCoins + amount)
	print("[SHOP] " .. player.Name .. " recebeu " .. amount .. " moedas")
end

local function give_boost(player: Player, boostType: string)
	if _G.BoostManager then
		_G.BoostManager.activateBoost(player, boostType, BOOST_DURATION)
		print("[SHOP] " .. player.Name .. " recebeu boost: " .. boostType .. " (" .. BOOST_DURATION .. "s)")
	else
		warn("[SHOP] BoostManager não encontrado! Boost não foi ativado.")
	end
end

local function give_gamepass_reward(player: Player, dataPath: string)
	DataUtility.server.set(player, dataPath, true)
	print("[SHOP] " .. player.Name .. " recebeu gamepass: " .. dataPath)
end

local function process_developer_product(player: Player, productKey: string, productData)
	if not productData or not productData.Rewards then
		warn("[SHOP] Dados de produto inválidos:", productKey)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local rewards = productData.Rewards

	if rewards.Coins then
		give_coins(player, rewards.Coins)
	end

	if rewards.BoostType then
		give_boost(player, rewards.BoostType)
	end

	print("[SHOP] Compra processada:", player.Name, "-", productKey)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function process_gamepass(player: Player, gamepassKey: string, gamepassData)
	if not gamepassData or not gamepassData.DataPath then
		warn("[SHOP] Dados de gamepass inválidos:", gamepassKey)
		return
	end

	give_gamepass_reward(player, gamepassData.DataPath)
	print("[SHOP] Gamepass concedido:", player.Name, "-", gamepassKey)
end

local function on_developer_product_purchase(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseKey = receiptInfo.PlayerId .. "_" .. receiptInfo.PurchaseId
	if processingPurchases[purchaseKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	processingPurchases[purchaseKey] = true

	local productData, productKey = ProductsData.GetProductById(receiptInfo.ProductId)
	if not productData or not productKey then
		warn("[SHOP] Produto não encontrado - ID:", receiptInfo.ProductId)
		processingPurchases[purchaseKey] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local result = process_developer_product(player, productKey, productData)

	return result
end

local function on_gamepass_purchase_finished(player: Player, gamepassId: number, wasPurchased: boolean)
	if not wasPurchased then return end

	local gamepassData, gamepassKey = ProductsData.GetGamepassById(gamepassId)
	if not gamepassData or not gamepassKey then
		warn("[SHOP] Gamepass não encontrado - ID:", gamepassId)
		return
	end

	task.wait(1)

	local hasGamepass = false
	local success = pcall(function()
		hasGamepass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)

	if success and hasGamepass then
		process_gamepass(player, gamepassKey, gamepassData)
	else
		warn("[SHOP] Falha ao verificar gamepass para", player.Name)
	end
end

local function check_existing_gamepasses(player: Player)
	task.wait(2)

	for gamepassKey, gamepassData in pairs(ProductsData.Gamepasses) do
		if gamepassData.GamepassId and gamepassData.GamepassId > 0 then
			local success, hasGamepass = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassData.GamepassId)
			end)

			if success and hasGamepass then
				local currentValue = DataUtility.server.get(player, gamepassData.DataPath)
				if not currentValue then
					give_gamepass_reward(player, gamepassData.DataPath)
					print("[SHOP] Gamepass existente concedido:", gamepassKey, "-", player.Name)
				end
			end
		end
	end
end

------------------//INIT
DataUtility.server.ensure_remotes()

MarketplaceService.ProcessReceipt = on_developer_product_purchase
MarketplaceService.PromptGamePassPurchaseFinished:Connect(on_gamepass_purchase_finished)

Players.PlayerAdded:Connect(function(player)
	check_existing_gamepasses(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(check_existing_gamepasses, player)
end

print("[SHOP] Sistema de produtos inicializado!")

return {}
