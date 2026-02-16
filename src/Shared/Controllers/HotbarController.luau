local HotbarController = {}

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

-- CONSTANTS
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local WeaponData = require(ReplicatedStorage.Modules.Constants.WeaponsData)
local KEY_BINDS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}
local CAMERA_OFFSET = Vector3.new(1, 3, 1)
local MAX_HOTBAR_SLOTS = 9

-- VARIABLES
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local MainUI = PlayerGui:WaitForChild("Main")
local HUD = MainUI:WaitForChild("HUDFR")
local HotbarFrame = HUD:WaitForChild("HotbarFR")
local HotbarTemplate = HotbarFrame:WaitForChild("HotbarBT")
local BackpackFrame = HUD:WaitForChild("BackpackBT")
local BackpackButton = HotbarFrame:WaitForChild("HotbarBT")
local BackpackBG = BackpackFrame:WaitForChild("BackpackBG")
local BackpackScrollingFrame = BackpackBG:WaitForChild("GridScrollingFrame")
local BackpackTemplate = BackpackScrollingFrame:WaitForChild("ItemBT")
local AssetTools = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Tools")
local equippedWeaponName = ''
local isWeaponInHand = false
local allWeapons = {}

-- FUNCTIONS
local function SetupViewport(viewportFrame, weaponName)
	viewportFrame:ClearAllChildren()

	local modelTemplate = AssetTools:FindFirstChild(weaponName)
	if not modelTemplate then return end

	local modelClone = modelTemplate:Clone()
	
	for _, child in ipairs(modelClone:GetDescendants()) do
		if child:IsA("Script") or child:IsA("LocalScript") then
			child:Destroy()
		end
	end

	local primaryPart = modelClone.PrimaryPart or modelClone:FindFirstChild("Handle", true) or modelClone:FindFirstChildWhichIsA("BasePart")
	
	if not primaryPart then 
		modelClone:Destroy()
		return 
	end

	modelClone:PivotTo(CFrame.new(Vector3.new(0, 0, 0)))
	modelClone.Parent = viewportFrame

	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(primaryPart.Position + CAMERA_OFFSET, primaryPart.Position)
	camera.Parent = viewportFrame
	
	viewportFrame.CurrentCamera = camera
end

local function ToggleWeaponInHand(weaponName)
	local targetWeapon = weaponName or equippedWeaponName
	if not targetWeapon or targetWeapon == '' then return end
	
	Packets.Action:Fire("ToggleHand", targetWeapon)
end

local function EquipWeapon(weaponName)
	if not weaponName or weaponName == '' then return end
	
	Packets.Action:Fire("ToggleHand", weaponName)
end

local function UpdateEquipIcon()
	for _, child in ipairs(HotbarFrame:GetChildren()) do
		if child:IsA("GuiButton") and child ~= HotbarTemplate and child ~= BackpackButton then
			local equipIcon = child:FindFirstChild("EquipIcon")
			if equipIcon then
				equipIcon.Visible = (child.Name == equippedWeaponName and isWeaponInHand)
			end
		end
	end
	
	for _, child in ipairs(BackpackScrollingFrame:GetChildren()) do
		if child:IsA("GuiButton") and child ~= BackpackTemplate then
			local equipIcon = child:FindFirstChild("EquipIcon")
			if equipIcon then
				equipIcon.Visible = (child.Name == equippedWeaponName and isWeaponInHand)
			end
		end
	end
end

local function CheckIfWeaponInHand()
	local character = Player.Character
	if not character then return false end
	
	local tool = character:FindFirstChildOfClass("Tool")
	if tool and tool.Name == equippedWeaponName then
		return true
	end
	
	return false
end

local function SetupCharacterListeners()
	local character = Player.Character or Player.CharacterAdded:Wait()
	
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == equippedWeaponName then
			isWeaponInHand = true
			UpdateEquipIcon()
		end
	end)
	
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child.Name == equippedWeaponName then
			isWeaponInHand = false
			UpdateEquipIcon()
		end
	end)
	
	isWeaponInHand = CheckIfWeaponInHand()
	UpdateEquipIcon()
end

local function CreateHotbarSlot(weaponName, slotNumber)
	local weaponConfig = WeaponData[weaponName]
	if not weaponConfig then return end

	local clone = HotbarTemplate:Clone()
	clone.Name = weaponName
	clone.Visible = true
	clone.LayoutOrder = slotNumber
	
	local nameLabel = clone:FindFirstChild("ItemNameTX")
	local numberLabel = clone:FindFirstChild("ItemNumberTX")
	local itemImage = clone:FindFirstChild("ItemImage")
	local equipIcon = clone:FindFirstChild("EquipIcon")

	if nameLabel then 
		nameLabel.Text = weaponConfig.Name
	end
	
	if numberLabel then 
		numberLabel.Text = tostring(slotNumber)
	end
	
	if equipIcon then
		equipIcon.Visible = (weaponName == equippedWeaponName and isWeaponInHand)
	end
	
	if itemImage and itemImage:IsA("ViewportFrame") then
		SetupViewport(itemImage, weaponName)
	end

	clone.MouseButton1Down:Connect(function()
		ToggleWeaponInHand(weaponName)
	end)
	
	clone.Activated:Connect(function()
		ToggleWeaponInHand(weaponName)
	end)

	clone.Parent = HotbarFrame
	
	if BackpackButton then
		BackpackButton.LayoutOrder = 999
	end
end

local function CreateBackpackSlot(weaponName)
	local weaponConfig = WeaponData[weaponName]
	if not weaponConfig then return end

	local clone = BackpackTemplate:Clone()
	clone.Name = weaponName
	clone.Visible = true
	
	local nameLabel = clone:FindFirstChild("ItemNameTX")
	local itemImage = clone:FindFirstChild("ViewportFrame")
	local equipIcon = clone:FindFirstChild("EquipIcon")

	if nameLabel then 
		nameLabel.Text = weaponConfig.Name
	end
	
	if equipIcon then
		equipIcon.Visible = (weaponName == equippedWeaponName and isWeaponInHand)
	end
	
	if itemImage and itemImage:IsA("ViewportFrame") then
		SetupViewport(itemImage, weaponName)
	end

	clone.MouseButton1Down:Connect(function()
		EquipWeapon(weaponName)
	end)
	
	clone.Activated:Connect(function()
		EquipWeapon(weaponName)
	end)

	clone.Parent = BackpackScrollingFrame
end

local function UpdateBackpackVisibility()
	local hasBackpackItems = #allWeapons > MAX_HOTBAR_SLOTS
	BackpackButton.Visible = hasBackpackItems
end

local function UpdateHotbar()
	for _, child in ipairs(HotbarFrame:GetChildren()) do
		if child:IsA("GuiButton") and child ~= HotbarTemplate and child ~= BackpackButton then
			child:Destroy()
		end
	end
	
	for _, child in ipairs(BackpackScrollingFrame:GetChildren()) do
		if child:IsA("GuiButton") and child.Name ~= "ItemBT" then
			child:Destroy()
		end
	end

	for index, weaponName in ipairs(allWeapons) do
		if index <= MAX_HOTBAR_SLOTS then
			CreateHotbarSlot(weaponName, index)
		else
			CreateBackpackSlot(weaponName)
		end
	end
	
	UpdateBackpackVisibility()
	UpdateEquipIcon()
end

local function UpdateWeaponsList()
	local inventory = PlayerDataManager:Get(Player, { 'Inventory' })
	if not inventory then return end
	
	allWeapons = {}
	
	if inventory.EquippedWeapon and inventory.EquippedWeapon ~= '' then
		table.insert(allWeapons, inventory.EquippedWeapon)
		equippedWeaponName = inventory.EquippedWeapon
	else
		equippedWeaponName = ''
	end
	
	UpdateHotbar()
end

local function ToggleBackpackUI()
	BackpackFrame.Visible = not BackpackFrame.Visible
end

-- INIT
function HotbarController:Init()
	HotbarTemplate.Visible = false
	BackpackTemplate.Visible = false
	BackpackFrame.Visible = false
	
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	repeat task.wait() until PlayerDataManager:Get(Player, { 'Inventory' })
	
	UpdateWeaponsList()

	PlayerDataManager:GetValueChangedSignal(Player, { 'Inventory', 'EquippedWeapon' }):Connect(function(newValue, oldValue)
		equippedWeaponName = newValue or ''
		isWeaponInHand = false
		UpdateWeaponsList()
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		
		local slotNumber = KEY_BINDS[input.KeyCode]
		if slotNumber and slotNumber <= #allWeapons and slotNumber <= MAX_HOTBAR_SLOTS then
			ToggleWeaponInHand(allWeapons[slotNumber])
		end
	end)
	
	BackpackButton.MouseButton1Down:Connect(function()
		ToggleBackpackUI()
	end)
	
	BackpackButton.Activated:Connect(function()
		ToggleBackpackUI()
	end)

	SetupCharacterListeners()
	
	Player.CharacterAdded:Connect(function()
		SetupCharacterListeners()
	end)

	UpdateHotbar()
end

return HotbarController