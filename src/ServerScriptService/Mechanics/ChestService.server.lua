------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

------------------//CONSTANTS
local DATA_UTILITY = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))

local GOLD_MIN = 50
local GOLD_MAX = 1000

local BOOST_DURATION = 120

local REWARDS = {
	{type = "Gold", weight = 40},
	{type = "Coins2x", weight = 30},
	{type = "Lucky2x", weight = 30},
}

------------------//VARIABLES
local chestRemote = nil
local playerChestCooldowns = {}

------------------//FUNCTIONS

local function generateGoldReward()
	return math.random(GOLD_MIN, GOLD_MAX)
end

local function selectReward()
	local totalWeight = 0
	for _, reward in ipairs(REWARDS) do
		totalWeight += reward.weight
	end

	local randomValue = math.random() * totalWeight
	local cumulativeWeight = 0

	for _, reward in ipairs(REWARDS) do
		cumulativeWeight += reward.weight
		if randomValue <= cumulativeWeight then
			return reward.type
		end
	end

	return "Gold"
end

local function giveChestRewards(player)
	local userId = player.UserId
	local lastOpen = playerChestCooldowns[userId]

	-- Reduzi o cooldown para 1 segundo para permitir pegar múltiplos baús em sequência
	if lastOpen and (os.clock() - lastOpen) < 1 then
		warn("[CHEST] " .. player.Name .. " tentou abrir baú muito rápido")
		return nil
	end

	playerChestCooldowns[userId] = os.clock()

	local rewardType = selectReward()
	local rewards = {}

	if rewardType == "Gold" then
		local goldAmount = generateGoldReward()
		local currentGold = DATA_UTILITY.server.get(player, "Coins") or 0
		DATA_UTILITY.server.set(player, "Coins", currentGold + goldAmount)

		rewards.gold = goldAmount
		print("[CHEST] " .. player.Name .. " recebeu " .. goldAmount .. " moedas")

	elseif rewardType == "Coins2x" or rewardType == "Lucky2x" then
		if _G.BoostManager then
			_G.BoostManager.activateBoost(player, rewardType, BOOST_DURATION)
			rewards.boost = rewardType
			print("[CHEST] " .. player.Name .. " recebeu boost: " .. rewardType)
		end
	end

	return rewards
end

local function setupChestRemote()
	local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")

	chestRemote = remotesFolder:FindFirstChild("ChestRemote")
	if not chestRemote then
		chestRemote = Instance.new("RemoteFunction")
		chestRemote.Name = "ChestRemote"
		chestRemote.Parent = remotesFolder
	end

	chestRemote.OnServerInvoke = function(player)
		if not player or not player:IsDescendantOf(Players) then
			return nil
		end

		local hasProfile = pcall(function()
			return DATA_UTILITY.server.get(player, "Coins")
		end)

		if not hasProfile then
			warn("[CHEST] Perfil de " .. player.Name .. " não está carregado")
			return nil
		end

		local rewards = giveChestRewards(player)

		if rewards then
			print("[CHEST DEBUG] Recompensas para " .. player.Name .. ":")
			print("  Gold: " .. tostring(rewards.gold))
			print("  Boost: " .. tostring(rewards.boost))
		end

		return rewards
	end

end

local function onPlayerRemoving(player)
	local userId = player.UserId
	if playerChestCooldowns[userId] then
		playerChestCooldowns[userId] = nil
	end
end

------------------//INIT
DATA_UTILITY.server.ensure_remotes()

setupChestRemote()

Players.PlayerRemoving:Connect(onPlayerRemoving)

_G.ChestRewards = {
	giveChestRewards = giveChestRewards,
	GOLD_MIN = GOLD_MIN,
	GOLD_MAX = GOLD_MAX,
}