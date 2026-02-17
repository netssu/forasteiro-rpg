-- services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- references
local Towers = ReplicatedStorage.Storage.Towers
local Remotes = ReplicatedStorage.Remotes

local CratePrices = require(ReplicatedStorage.Modules.StoredData.CrateData)

-- generates a random string for unique item ids
local function GenerateHash(length)
	length = length or 16
	local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local hash = ""

	for i = 1, length do
		local randIndex = math.random(1, #charset)
		hash ..= charset:sub(randIndex, randIndex)
	end

	return hash
end

-- tracks players currently opening crates to prevent spam
local ActiveUnboxes = {}

-- rarity chances for each crate type (higher number = more likely)
local CrateRarityChances = {
	Normal = { Common = 75, Uncommon = 15, Rare = 7, Epic = 2, Legendary = 1 },
	Steel  = { Common = 50, Uncommon = 25, Rare = 15, Epic = 7, Legendary = 3 },
	Golden = { Common = 10, Uncommon = 25, Rare = 30, Epic = 20, Legendary = 15 },
	Diamond= { Common = 5,  Uncommon = 15, Rare = 30, Epic = 25, Legendary = 25 },
}

-- picks a random key from a weighted table
local function getWeightedKey(t)
	local total = 0
	for _, w in pairs(t) do
		total += w
	end

	local rand = math.random() * total
	local sum = 0

	for k, w in pairs(t) do
		sum += w
		if rand <= sum then
			return k
		end
	end
end

-- picks a random tower based on crate type rarity chances
local function ChooseRandomTower(BoxType)
	local chances = CrateRarityChances[BoxType] or CrateRarityChances.Normal

	-- calculate total weight
	local totalWeight = 0
	for _, w in pairs(chances) do
		totalWeight += w
	end

	-- roll and find which rarity we landed on
	local roll = math.random(1, totalWeight)
	local cumulative = 0
	local chosenRarity = "Common"
	local orderedRarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary"}

	for _, rarity in ipairs(orderedRarities) do
		cumulative += chances[rarity] or 0
		if roll <= cumulative then
			chosenRarity = rarity
			break
		end
	end

	print(string.format("[Unbox Debug] %s Crate : %s (Roll: %.2f)", BoxType, chosenRarity, roll))

	-- find all towers with the chosen rarity
	local candidates = {}
	for _, tower in ipairs(Towers:GetChildren()) do
		if tower:IsA("Model") and tower:GetAttribute("Rarity") == chosenRarity then
			table.insert(candidates, tower)
		end
	end

	-- fallback to any tower if none found with that rarity
	if #candidates == 0 then
		for _, tower in ipairs(Towers:GetChildren()) do
			if tower:IsA("Model") then
				table.insert(candidates, tower)
			end
		end
	end

	if #candidates == 0 then return nil end

	-- pick random from candidates
	return candidates[math.random(1, #candidates)]
end

-- handles opening a crate
Remotes.Game.Unbox.OnServerEvent:Connect(function(Player: Player, BoxType: string)
	-- prevent spam opening
	if ActiveUnboxes[Player] then
		ReplicatedStorage.Remotes.Notification.SendNotification:FireClient(Player, "Please wait before opening another crate!", "Normal")
		return
	end

	local success, err = pcall(function()
		local UserData = Player:FindFirstChild("UserData")
		if not UserData then return end

		local Crates = UserData:FindFirstChild("Crates")
		local Inventory = UserData:FindFirstChild("Inventory")
		if not Crates or not Inventory then return end

		local CrateType = Crates:FindFirstChild(BoxType)
		if not CrateType then return end

		-- check if they have any of this crate
		if CrateType.Value < 1 then
			ReplicatedStorage.Remotes.Notification.SendNotification:FireClient(Player, "You do not own any "..BoxType.." Crates.", "Error")
			return
		end

		-- check inventory space
		if #Inventory:GetChildren() >= 100 then
			ReplicatedStorage.Remotes.Notification.SendNotification:FireClient(Player, "Your inventory is full sell some units!", "Error")
			return
		end

		-- mark as actively unboxing
		ActiveUnboxes[Player] = true

		-- consume the crate
		CrateType.Value -= 1

		-- pick a random tower from the crate
		local SelectedTower = getWeightedKey(CratePrices[BoxType].Contains)
		if not SelectedTower then return end

		-- add to inventory with unique hash id
		local NewData = Instance.new("StringValue")
		NewData.Name = GenerateHash(32)
		NewData.Value = SelectedTower
		NewData.Parent = Inventory

		-- tell client to show the unbox animation
		Remotes.Game.DisplayUnbox:FireClient(Player, SelectedTower, BoxType)
	end)

	if not success then
		warn("Unbox error:", err)
		ActiveUnboxes[Player] = nil
	end

	-- cooldown before they can open another
	task.delay(1.5, function()
		ActiveUnboxes[Player] = nil
	end)
end)

-- handles purchasing crates with money
Remotes.Game.PurchaseBox.OnServerEvent:Connect(function(Player : Player, BoxString : string)
	-- get price from data
	local Price = CratePrices[BoxString] and CratePrices[BoxString].Price
	local UserData = Player:FindFirstChild("UserData")
	local Crates = UserData:FindFirstChild("Crates")
	local CrateData = Crates:FindFirstChild(BoxString)
	local Money = UserData:FindFirstChild("Money")

	-- check if they can afford it
	if Money.Value >= Price then
		-- deduct money and give crate
		Money.Value = Money.Value - Price
		CrateData.Value = CrateData.Value + 1

		Remotes.Notification.SendNotification:FireClient(Player, "Purchased "..CrateData.Name.." Crate", "Success")
		return
	else
		Remotes.Notification.SendNotification:FireClient(Player, "You cannot afford "..CrateData.Name.." Crate", "Error")
		return
	end
end)

return {}