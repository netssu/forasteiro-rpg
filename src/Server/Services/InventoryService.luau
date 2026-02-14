local InventoryService = {}

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local WeaponData = require(ReplicatedStorage.Modules.Constants.WeaponsData)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)

local activeWeapons = {}

function InventoryService:AddWeapon(player, weaponName)
	if not WeaponData[weaponName] then return false end
	
	local weapons = PlayerDataManager:Get(player, { 'Inventory', 'Weapons' }) or {}
	
	for _, weapon in ipairs(weapons) do
		if weapon == weaponName then return false end
	end
	
	PlayerDataManager:Insert(player, { 'Inventory', 'Weapons' }, weaponName)
	return true
end

function InventoryService:RemoveWeapon(player, weaponName)
	local weapons = PlayerDataManager:Get(player, { 'Inventory', 'Weapons' }) or {}
	
	local index = nil
	for i, weapon in ipairs(weapons) do
		if weapon == weaponName then
			index = i
			break
		end
	end
	
	if not index then return false end
	
	PlayerDataManager:Remove(player, { 'Inventory', 'Weapons' }, index)
	
	local equippedWeapon = PlayerDataManager:Get(player, { 'Inventory', 'EquippedWeapon' })
	if equippedWeapon == weaponName then
		self:SetHotbarItem(player, '')
	end
	
	return true
end

function InventoryService:RemoveToolFromHand(player)
	local character = player.Character
	if not character then return end
	
	local activeTool = activeWeapons[player]
	if activeTool and activeTool.Parent then
		activeTool:Destroy()
	end
	activeWeapons[player] = nil
	
	local tool = character:FindFirstChildOfClass('Tool')
	if tool then
		tool:Destroy()
	end
end

function InventoryService:SetHotbarItem(player, weaponName)
	local currentEquipped = PlayerDataManager:Get(player, { 'Inventory', 'EquippedWeapon' })
	
	if currentEquipped == weaponName then
		PlayerDataManager:Set(player, { 'Inventory', 'EquippedWeapon' }, '')
		self:RemoveToolFromHand(player)
	else
		if weaponName ~= '' then
			local weapons = PlayerDataManager:Get(player, { 'Inventory', 'Weapons' }) or {}
			local hasWeapon = false
			
			for _, weapon in ipairs(weapons) do
				if weapon == weaponName then
					hasWeapon = true
					break
				end
			end
			
			if not hasWeapon then
				for key, value in pairs(weapons) do
					if value == weaponName or key == weaponName then
						hasWeapon = true
						break
					end
				end
			end
			
			if not hasWeapon then return end
			if not WeaponData[weaponName] then return end
		end
		
		self:RemoveToolFromHand(player)
		PlayerDataManager:Set(player, { 'Inventory', 'EquippedWeapon' }, weaponName)
	end
end

function InventoryService:SpawnToolInHand(player, weaponName)
	local character = player.Character
	if not character then return false end
	
	local equippedWeapon = PlayerDataManager:Get(player, { 'Inventory', 'EquippedWeapon' })
	if equippedWeapon ~= weaponName then return false end
	
	self:RemoveToolFromHand(player)
	
	local assetTools = ReplicatedStorage:FindFirstChild('Assets'):FindFirstChild('Tools')
	if not assetTools then return false end
	
	local toolModel = assetTools:FindFirstChild(weaponName)
	if not toolModel then return false end
	
	local toolClone = toolModel:Clone()
	
	if toolClone:IsA("Tool") then
		toolClone.Parent = character
	elseif toolClone:IsA("Model") then
		local handle = toolClone:FindFirstChild("Handle", true)
		if handle then
			local tool = Instance.new("Tool")
			tool.Name = weaponName
			tool.RequiresHandle = true
			handle.Parent = tool
			for _, child in ipairs(toolClone:GetChildren()) do
				if child ~= handle then
					child.Parent = tool
				end
			end
			toolClone:Destroy()
			toolClone = tool
			toolClone.Parent = character
		else
			toolClone:Destroy()
			return false
		end
	else
		toolClone:Destroy()
		return false
	end
	
	local humanoid = character:FindFirstChildOfClass('Humanoid')
	if humanoid and toolClone.Parent == character then
		task.wait(0.1)
		humanoid:EquipTool(toolClone)
	end
	
	activeWeapons[player] = toolClone
	return true
end

function InventoryService:ToggleWeaponInHand(player, weaponName)
	local character = player.Character
	if not character then return end
	
	local equippedWeapon = PlayerDataManager:Get(player, { 'Inventory', 'EquippedWeapon' })
	if equippedWeapon ~= weaponName then return end
	
	local currentTool = character:FindFirstChildOfClass('Tool')
	
	if currentTool and currentTool.Name == weaponName then
		self:RemoveToolFromHand(player)
	else
		self:SpawnToolInHand(player, weaponName)
	end
end

function InventoryService:HandleAction(player, actionName, actionData)
	if typeof(actionName) ~= "string" then return end
	
	local weaponName = actionData
	
	if actionName == "ToggleHotbar" then
		self:SetHotbarItem(player, weaponName)
	elseif actionName == "ToggleHand" then
		self:ToggleWeaponInHand(player, weaponName)
	end
end

function InventoryService:InitializePlayerData(player)
	task.wait(1)
	local inventory = PlayerDataManager:Get(player, { 'Inventory' })
	if not inventory then return end
	
	if not inventory.EquippedWeapon then
		PlayerDataManager:Set(player, { 'Inventory', 'EquippedWeapon' }, '')
	end
end

function InventoryService:CleanupPlayer(player)
	activeWeapons[player] = nil
end

function InventoryService:Init()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:InitializePlayerData(player)
		end)
	end
	
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			self:InitializePlayerData(player)
		end)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		self:CleanupPlayer(player)
	end)
	
	Packets.Action.OnServerEvent:Connect(function(player, actionName, actionData)
		self:HandleAction(player, actionName, actionData)
	end)
end

return InventoryService