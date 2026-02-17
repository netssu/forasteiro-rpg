local Handler = {}

-- services and player stuff
local Players = game.Players
local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

-- ui references
local MainUi = PlayerGui:WaitForChild("TD")
local Frames = MainUi:WaitForChild("Frames")
local WormsInventory = Frames:WaitForChild("Worms")
local InventoryScrollingUi = WormsInventory:WaitForChild("ScrollingFrame")
local WormsInfo = WormsInventory:WaitForChild("ItemFrame")
local EquipButton = WormsInfo:WaitForChild("Equip")
local UnequipAll = WormsInventory:WaitForChild("Unequip")
local EquipAll = WormsInventory:WaitForChild("Best")
local SellButton = WormsInventory:WaitForChild("Sell")
local CountFrame = WormsInventory:WaitForChild("Count")
local InventorySpaceText = CountFrame:WaitForChild("Count")

-- module stuff
local ReplicatedStorage = game.ReplicatedStorage
local Modules = ReplicatedStorage:WaitForChild("Modules")
local StoredData = Modules:WaitForChild("StoredData")
local TowerData = require(StoredData:WaitForChild("TowerData"))

-- player data folders
local PlayerData = Player:WaitForChild("UserData")
local PlayerInventory = PlayerData:WaitForChild("Inventory")
local PlayerHotbar = PlayerData:WaitForChild("Hotbar")

local ReplicatedStorage = game.ReplicatedStorage
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InventoryRemotes = Remotes:WaitForChild("Inventory")
local SellRemote = InventoryRemotes:WaitForChild("Sell")

-- variables

local Selected = nil

-- higher number = better rarity for sorting
local RarityRanks = {Legendary = 5, Epic = 4, Rare = 3, Uncommon = 2, Common = 1}

-- gradient colors for each rarity
local RarityColor = {
	["Common"] = ColorSequence.new(Color3.fromRGB(238, 235, 255), Color3.fromRGB(57,56,70)),
	["Uncommon"] = ColorSequence.new(Color3.fromRGB(199, 255, 213), Color3.fromRGB(23, 70, 19)),
	["Rare"] = ColorSequence.new(Color3.fromRGB(148, 185, 255), Color3.fromRGB(24, 40, 70)),
	["Epic"] = ColorSequence.new(Color3.fromRGB(162, 69, 255), Color3.fromRGB(34, 21, 70)),
	["Legendary"] = ColorSequence.new(Color3.fromRGB(255, 226, 137), Color3.fromRGB(70, 53, 28)),
}

-- lower number = shows higher in the list
local LayoutOrder = {
	["Common"] = 10,
	["Uncommon"] = 9,
	["Rare"] = 8,
	["Epic"] = 7,
	["Legendary"] = 6
}

-- functions

-- gets the tower model from storage
local function GetModel(ItemName)
	return game.ReplicatedStorage.Storage.Towers:FindFirstChild(ItemName)
end

-- sorts by equipped first, then rarity, then alphabetically
local function SortTable(Table)
	table.sort(Table, function(a, b)
		-- equipped ones go first
		if a.IsEquipped ~= b.IsEquipped then
			return a.IsEquipped
		end

		-- then sort by rarity
		local rarityA = RarityRanks[a.Info.Rarity] or 0
		local rarityB = RarityRanks[b.Info.Rarity] or 0

		if rarityA ~= rarityB then
			return rarityA > rarityB
		end

		-- alphabetical if same rarity
		return a.Name < b.Name
	end)

	return Table
end

-- checks if a unit is in the hotbar
local function CheckkEquipped(UnitName)
	for _, slot in ipairs(PlayerHotbar:GetChildren()) do
		if slot:IsA("StringValue") and slot.Value == UnitName then
			return true
		end
	end

	return false
end

-- clears all the items from a frame
local function PurgeList(Frame)
	for _, child in ipairs(Frame:GetChildren()) do
		if (child:IsA("ImageButton") or child:IsA("Frame")) and (child.Name ~= "Template" or child.Name ~= "Example") then
			if child.Name == "Example" then continue end
			child:Destroy()
		end
	end
end

-- updates the preview panel on the right side
local function UpdatePreview(UnitName)
	local TowerInfo = TowerData[UnitName]
	if not(TowerInfo) then return end -- invalid tower so just return

	Selected = UnitName

	-- change button to show equip or unequip based on state
	if CheckkEquipped(UnitName) then
		-- red unequip button
		EquipButton.MainText.Text = "Unequip"
		EquipButton.UIStroke.Color = Color3.fromRGB(58, 1, 2)
		EquipButton.MainText.UIStroke.Color = Color3.fromRGB(58, 1, 2)
		EquipButton.ImageColor3 = Color3.fromRGB(255, 28, 51)
	else
		-- green equip button
		EquipButton.MainText.Text = "Equip"
		EquipButton.UIStroke.Color = Color3.fromRGB(33, 58, 0)
		EquipButton.MainText.UIStroke.Color = Color3.fromRGB(33, 58, 0)
		EquipButton.ImageColor3 = Color3.fromRGB(81, 255, 0)
	end

	WormsInfo.Visible = true

	-- get the model for rarity stuff, defaults to common if not found
	local TowerModel = GetModel(UnitName) or "Common"

	-- apply the rarity gradient colors
	WormsInfo.UIGradient.Color = RarityColor[TowerModel:GetAttribute("Rarity")]
	WormsInfo.UIStroke.UIGradient.Color = RarityColor[TowerModel:GetAttribute("Rarity")]

	-- fill in all the stats and info
	WormsInfo.WormName.Text = UnitName
	WormsInfo.MainIcon.Image = "rbxassetid://"..TowerInfo.ImageId
	WormsInfo.Range.Stat.Text = TowerModel:GetAttribute("Range") or "Nan"
	WormsInfo.Damage.Stat.Text = TowerModel:GetAttribute("Damage") or "Nan"
	WormsInfo.Rate.Stat.Text = TowerModel:GetAttribute("AttackCooldown") or "Nan"
end

-- refreshes the whole inventory list
local function UpdateInventory()
	PurgeList(InventoryScrollingUi)

	local MarkedEquipped = {} -- tracks which ones weve already shown as equipped
	local ItemList = {}

	-- build a list of all items
	for _, Item in ipairs(PlayerInventory:GetChildren()) do
		if not(Item:IsA("StringValue")) then continue end

		local TowerInfo = TowerData[Item.Value]

		if TowerInfo then
			table.insert(ItemList, {Name = Item.Value, Info = TowerInfo, IsEquipped = CheckkEquipped(Item.Value)})
		end

		-- update the count text
		InventorySpaceText.Text = #ItemList.."/100"

		ItemList = SortTable(ItemList)
	end

	-- create ui for each item
	for _, ItemData in ipairs(ItemList) do
		local Rarity = GetModel(ItemData.Name):GetAttribute("Rarity")

		-- container frame
		local NewFrame = Instance.new("Frame", InventoryScrollingUi)
		NewFrame.Transparency = 1
		NewFrame.Name = ItemData.Name

		-- clone the right template for this rarity
		local Template = script:FindFirstChild(`Template_{Rarity or "Common"}`):Clone()

		Template.Name = ItemData.Name
		Template.Parent = NewFrame

		NewFrame.LayoutOrder = LayoutOrder[Rarity] or 10

		Template.Holder.Price.Text = "$"..ItemData.Info.Price
		Template.Holder.Visible = true

		-- show equipped badge if its equipped and we havent marked one already
		if ItemData.IsEquipped and not(MarkedEquipped[ItemData.Name]) then
			Template.Equiped.Visible = true
			MarkedEquipped[ItemData.Name] = true

			-- bump it up in the list
			NewFrame.LayoutOrder -= 10
		else
			Template.LayoutOrder = LayoutOrder[Rarity]
			Template.Equiped.Visible = false
		end

		-- set the icon and name
		Template.Worm_Icon.Image = "rbxassetid://" .. ItemData.Info.ImageId
		Template.WormName.Text = ItemData.Name

		-- clicking it shows the preview
		Template.Activated:Connect(function()
			UpdatePreview(Template.Name)
		end)
	end
end

local debounce = false

-- equip or unequip the selected unit
EquipButton.Activated:Connect(function()
	if Selected and not(debounce) then
		debounce = true
		game.ReplicatedStorage.Remotes.Inventory.Equip:FireServer(Selected)
		task.wait(.1)
		UpdatePreview(Selected)
		UpdateInventory()
		
		task.delay(.3, function()
			debounce = false
		end)
	end
end)

-- sell the selected unit
SellButton.Activated:Connect(function()
	if Selected then
		game.ReplicatedStorage.Remotes.Inventory.Sell:FireServer(Selected)
		task.wait(0.2)
		UpdateInventory()
	end
end)

-- unequip everything
UnequipAll.Activated:Connect(function()
	game.ReplicatedStorage.Remotes.Inventory.UnequipAll:FireServer()
	task.wait(0.1)
	if Selected then
		UpdatePreview(Selected)
	end
	UpdateInventory()
end)

-- finds and equips the best rarity unit
EquipAll.Activated:Connect(function()
	local bestUnit = nil
	local bestRank = 0
	local rarityRank = {Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5}

	-- loop through and find the highest rarity one
	for _, item in ipairs(PlayerInventory:GetChildren()) do
		if item:IsA("StringValue") then
			local info = TowerData[item.Name]
			if info then
				local rank = rarityRank[info.Rarity] or 0
				if rank > bestRank then
					bestRank = rank
					bestUnit = item.Name
				end
			end
		end
	end

	-- equip it if we found one
	if bestUnit then
		game.ReplicatedStorage.Remotes.Inventory.Equip:FireServer(bestUnit)
		task.spawn(function()
			task.wait(0.1)
			UpdatePreview(bestUnit)
			UpdateInventory()
		end)
	end
end)

SellRemote.OnClientEvent:Connect(function()
	WormsInfo.Visible = false
end)

-- refresh when the inventory opens
WormsInventory:GetPropertyChangedSignal("Visible"):Connect(UpdateInventory)

return Handler