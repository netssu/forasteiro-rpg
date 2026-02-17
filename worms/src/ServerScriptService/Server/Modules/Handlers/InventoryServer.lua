--  services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

--  variables

local Remotes = ReplicatedStorage.Remotes
local InventoryRemotes = Remotes.Inventory
local PetModels = ReplicatedStorage.Storage.Towers

--  modules

local TowerData = require(game.ReplicatedStorage.Modules.StoredData.TowerData)
local ActivePets = {}

--  functions

local function verifyOwnership(Player : Player, UnitName : string) --  checks if player owns the unit
	local UserData = Player:FindFirstChild("UserData")
	if not UserData then return false end

	local Inventory = UserData:FindFirstChild("Inventory")
	if not Inventory then return false end

	local TargetData

	--  search inventory for unit
	for _, Item in ipairs(Inventory:GetChildren()) do
		if Item.Value == UnitName then
			TargetData = Item
		end	
	end

	return TargetData ~= nil
end

local function equip(Player : Player, UnitName : string) --  handles equipping/unequipping units to hotbar

	local UserData = Player:FindFirstChild("UserData")
	local Level = UserData:FindFirstChild("Level")
	local Hotbar = UserData:FindFirstChild("Hotbar")

	--  sort hotbar slots numerically
	local HotbarSlots = {}
	for _, Slot in ipairs(Hotbar:GetChildren()) do
		table.insert(HotbarSlots, Slot)
	end
	table.sort(HotbarSlots, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)

	--  check if already equipped, unequip if so
	for _, Slot in ipairs(HotbarSlots) do
		if Slot.Value == UnitName then
			Slot.Value = ""
			Remotes.Notification.SendNotification:FireClient(Player, "Unequipped "..UnitName.."!", "Info")
			return nil
		end
	end

	--  find first available slot with level requirements
	for _, Slot in ipairs(HotbarSlots) do
		local slotNumber = tonumber(Slot.Name)

		--  slot 5 requires level 10
		if slotNumber == 5 and Level.Value < 10 then
			Remotes.Notification.SendNotification:FireClient(Player, "You need to be level 10 to equip slot 5!", "Error")
			return nil
			--  slot 6 requires level 15
		elseif slotNumber == 6 and Level.Value < 15 then
			Remotes.Notification.SendNotification:FireClient(Player, "You need to be level 15 to equip slot 6!", "Error")
			return nil
		end

		if Slot.Value == "" then
			return Slot
		end
	end

	Remotes.Notification.SendNotification:FireClient(Player, "No empty hotbar slots available!", "Error")
	return nil

end

local function EquipPet(Player: Player, PetName: string) --  spawns and attaches pet to player

	--  destroy existing pet if any
	--[[if ActivePets[Player] then
		ActivePets[Player]:Destroy()
		ActivePets[Player] = nil
	end

	local PetModel = PetModels:FindFirstChild(PetName)
	if not PetModel then return end

	local Pet = PetModel:Clone()
	
	for _, Part in ipairs(Pet:GetDescendants()) do
		if Part:IsA("BasePart") then
			Part.CanCollide = false
			Part.CanQuery = false
		end
	end

	Pet.Parent = workspace
	if not Pet.PrimaryPart then return end

	ActivePets[Player] = Pet

	--  pet follow loop
	task.spawn(function()
		Player.AncestryChanged:Connect(function()
			print("gone")
			Pet:Destroy()
		end)
		while Pet.Parent and Player.Character and Player.Character.PrimaryPart do

			--  disable collision on all pet parts
			for _, BasePart in ipairs(Pet:GetDescendants()) do
				if BasePart:IsA("BasePart") then
					BasePart.CanCollide = false
				end
			end

			--  tween pet to follow behind player
			local root = Player.Character.PrimaryPart
			local followPos = root.Position - (root.CFrame.LookVector * 4)
			local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Linear)
			local tween = TweenService:Create(Pet.PrimaryPart, tweenInfo, { CFrame = CFrame.new(followPos, root.Position) })
			tween:Play()
			task.wait(0.05)
		end
	end)

	return Pet--]]

end

local function UnequipPet(Player: Player) --  removes active pet from player
	if ActivePets[Player] then
		ActivePets[Player]:Destroy()
		ActivePets[Player] = nil
	end

	local UserData = Player:FindFirstChild("UserData")
	if not UserData then return end

	local Hotbar = UserData:FindFirstChild("Hotbar")
	if not Hotbar then return end

	Remotes.Notification.SendNotification:FireClient(Player, "Pet unequipped!", "Info")
end

--  events

InventoryRemotes.Equip.OnServerEvent:Connect(function(Player : Player, UnitName : string) --  equip unit remote
	if not verifyOwnership(Player, UnitName) then
		return
	end

	local Slot = equip(Player, UnitName)
	if Slot then
		Slot.Value = UnitName
		EquipPet(Player, UnitName)
		Remotes.Notification.SendNotification:FireClient(Player, "Equipped "..UnitName.."!", "Success")
	end
end)

InventoryRemotes.UnequipAll.OnServerEvent:Connect(function(Player : Player) --  unequip all units remote
	local UserData = Player:FindFirstChild("UserData")
	if not UserData then return end

	local Hotbar = UserData:FindFirstChild("Hotbar")
	if not Hotbar then return end

	local done = false

	for _, Slot in ipairs(Hotbar:GetChildren()) do
		if Slot:IsA("StringValue") and Slot.Value ~= "" then
			Slot.Value = ""
			done = true
		end
	end

	if done then
		Remotes.Notification.SendNotification:FireClient(Player, "All units have been unequipped!", "Success")
	end		
end)

InventoryRemotes.Sell.OnServerEvent:Connect(function(Player: Player, UnitName: string) --  sell unit remote

	if not verifyOwnership(Player, UnitName) then
		Remotes.Notification.SendNotification:FireClient(Player, "You don't own this unit!", "Error")
		return
	end

	local UserData = Player:FindFirstChild("UserData")
	if not UserData then return end

	local Inventory = UserData:FindFirstChild("Inventory")
	local Hotbar = UserData:FindFirstChild("Hotbar")
	local Money = UserData:FindFirstChild("Money")
	if not Inventory or not Hotbar or not Money then return end

	--  prevent selling equipped units
	for _, Slot in ipairs(Hotbar:GetChildren()) do
		if Slot:IsA("StringValue") and Slot.Value == UnitName then
			local Amount = 0
			
			for _, TargetItem in ipairs(Inventory:GetChildren()) do
				if TargetItem.Value == UnitName then
					Amount += 1
				end	
			end
			
			if Amount <= 1 then
				Remotes.Notification.SendNotification:FireClient(Player, "You can't sell an equipped unit!", "Error")
				return
			end
		end
	end

	--  find item in inventory
	local Item
	for _, TargetItem in ipairs(Inventory:GetChildren()) do
		if TargetItem.Value == UnitName then
			Item = TargetItem
		end	
	end

	--  calculate sell value based on rarity
	local TowerInfo = TowerData[UnitName]
	local SellValue = 0

	local Rarity = game.ReplicatedStorage.Storage.Towers:FindFirstChild(UnitName):GetAttribute("Rarity")

	if TowerInfo and Rarity then
		local rarity = Rarity
		local prices = {
			Common = 250,
			Uncommon = 500,
			Rare = 1000,
			Epic = 2500,
			Legendary = 5000
		}
		SellValue = prices[rarity] or 100
	else
		SellValue = 100
	end

	print(SellValue)

	--  remove item and give money
	if Item then
		require(game.ServerStorage.Modules.Managers.DataManager).Stored[Player.UserId].Data.Inventory[Item.Name] = nil
		Item:Destroy()
		Money.Value += SellValue
		Remotes.Notification.SendNotification:FireClient(Player, "Sold " .. UnitName .. " for $" .. SellValue .. "!", "Success")	
		Remotes.Inventory.Sell:FireClient(Player)	
	end
end)

Remotes.Pets.EquipPet.Event:Connect(function(Player, WormName) --  event for equipping pets
	EquipPet(Player, WormName)
end)

local function OnPlayerAdded(Plr)
	local UserData = Plr:WaitForChild("UserData", 15)
	local HotBar = UserData:WaitForChild("Hotbar", 15)

	repeat task.wait() until Plr.Character

	task.wait(1)

	print("it here")

	for _, StrVal in ipairs(HotBar:GetChildren()) do
		if StrVal.Value ~= "" then
			EquipPet(Plr, StrVal.Value)
		end
	end
end

for _, Plr in ipairs(Players:GetPlayers()) do
	task.spawn(OnPlayerAdded, Plr)
end

Players.PlayerAdded:Connect(OnPlayerAdded)

Remotes:WaitForChild("Like").OnServerEvent:Connect(function(Plr)
	local UserData = Plr:WaitForChild("UserData")
	local ClaimedLike = UserData:WaitForChild("ClaimedLike")
	
	if ClaimedLike.Value then
		Remotes.Notification.SendNotification:FireClient(Plr, "Already claimed!", "Error")	
	else
		if Plr:IsInGroupAsync(103774916) then
			UserData.Money.Value += 3_000
			ClaimedLike.Value = true
			
			Remotes.Notification.SendNotification:FireClient(Plr, "Claimed!", "Success")	
		else
			Remotes.Notification.SendNotification:FireClient(Plr, "Need to like and join!", "Error")	
		end
	end
end)

return {}