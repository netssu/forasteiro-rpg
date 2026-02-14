local InventoryController = {}

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local WeaponData = require(ReplicatedStorage.Modules.Constants.WeaponsData)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui
local Main = PlayerGui:WaitForChild('Main')
local InventoryFR = Main:WaitForChild('InventoryFR')
local InventoryBG = InventoryFR:WaitForChild('InventoryBG')
local SearchBoxBG = InventoryBG:WaitForChild('SearchBoxBG')
local SearchTextBox = SearchBoxBG:WaitForChild('TextBox')
local GridScrollingFrame = InventoryBG:WaitForChild('GridScrollingFrame')
local ItemTemplateBT = GridScrollingFrame:WaitForChild('ItemTemplateBT')
local janitor = Janitor.new()
local itemCards = {}
local cardJanitors = {}

local function renderWeaponPreview(itemImage, weaponName)
	local assetTools = ReplicatedStorage:FindFirstChild('Assets'):FindFirstChild('Tools')
	if not assetTools then return end

	local model = assetTools:FindFirstChild(weaponName)
	if not model then return end

	for _, child in ipairs(itemImage:GetChildren()) do
		if child:IsA('ViewportFrame') then
			child:Destroy()
		end
	end

	local viewportFrame = Instance.new('ViewportFrame')
	viewportFrame.Size = UDim2.fromScale(1, 1)
	viewportFrame.BackgroundTransparency = 1
	viewportFrame.BorderSizePixel = 0
	viewportFrame.Parent = itemImage

	local camera = Instance.new('Camera')
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	local clonedModel = model:Clone()
	clonedModel.Parent = viewportFrame

	local cf, size = clonedModel:GetBoundingBox()
	local maxSize = math.max(size.X, size.Y, size.Z)
	local distance = maxSize * 0.8

	camera.CFrame = CFrame.new(
		cf.Position + Vector3.new(distance * 0.5, distance * 0.3, distance),
		cf.Position
	)
end

local function updateEquippedState(equippedWeaponName)
	for weaponName, card in pairs(itemCards) do
		local equipIcon = card:FindFirstChild('EquipIcon')
		if equipIcon then
			equipIcon.Visible = (weaponName == equippedWeaponName and equippedWeaponName ~= '')
		end
	end
end

local function applySearchFilter()
	local searchText = string.lower(SearchTextBox.Text)
	
	for weaponName, card in pairs(itemCards) do
		local weaponConfig = WeaponData[weaponName]
		if weaponConfig then
			local itemName = string.lower(weaponConfig.Name)
			
			if searchText == "" or string.find(itemName, searchText, 1, true) then
				card.Visible = true
			else
				card.Visible = false
			end
		end
	end
end

local function createItemCard(weaponName)
	if typeof(weaponName) ~= "string" then return end
	
	if itemCards[weaponName] then 
		local equippedWeapon = PlayerDataManager:Get(LocalPlayer, { 'Inventory', 'EquippedWeapon' })
		local equipIcon = itemCards[weaponName]:FindFirstChild('EquipIcon')
		if equipIcon then
			equipIcon.Visible = (weaponName == equippedWeapon and equippedWeapon ~= '')
		end
		return 
	end

	local weaponConfig = WeaponData[weaponName]
	if not weaponConfig then return end

	local card = ItemTemplateBT:Clone()
	card.Name = weaponName
	
	local searchText = string.lower(SearchTextBox.Text)
	if searchText ~= "" and not string.find(string.lower(weaponConfig.Name), searchText, 1, true) then
		card.Visible = false
	else
		card.Visible = true
	end

	local itemNameTX = card:FindFirstChild('ItemNameTX')
	local itemImage = card:FindFirstChild('ItemImage')
	local itemAmountTX = card:FindFirstChild('ItemAmountTX')
	local equipIcon = card:FindFirstChild('EquipIcon')

	if itemNameTX then
		itemNameTX.Text = weaponConfig.Name
	end

	if itemAmountTX then
		itemAmountTX.Visible = false
	end

	if equipIcon then
		local equippedWeapon = PlayerDataManager:Get(LocalPlayer, { 'Inventory', 'EquippedWeapon' })
		equipIcon.Visible = (weaponName == equippedWeapon and equippedWeapon ~= '')
	end

	if itemImage then
		renderWeaponPreview(itemImage, weaponName)
	end

	local cardJanitor = Janitor.new()
	
	cardJanitor:Add(card.MouseButton1Down:Connect(function()
		Packets.Action:Fire("ToggleHotbar", weaponName)
	end), 'Disconnect')
	
	cardJanitor:Add(card.Activated:Connect(function()
		Packets.Action:Fire("ToggleHotbar", weaponName)
	end), 'Disconnect')

	cardJanitors[weaponName] = cardJanitor

	card.Parent = GridScrollingFrame
	itemCards[weaponName] = card
end

local function removeItemCard(weaponName)
	local card = itemCards[weaponName]
	if card then
		local cardJanitor = cardJanitors[weaponName]
		if cardJanitor then
			cardJanitor:Destroy()
			cardJanitors[weaponName] = nil
		end
		card:Destroy()
		itemCards[weaponName] = nil
	end
end

local function buildInventory()
	local weapons = PlayerDataManager:Get(LocalPlayer, { 'Inventory', 'Weapons' })
	if not weapons then return end

	for weaponName, card in pairs(itemCards) do
		local cardJanitor = cardJanitors[weaponName]
		if cardJanitor then
			cardJanitor:Destroy()
			cardJanitors[weaponName] = nil
		end
		card:Destroy()
	end
	itemCards = {}

	local count = 0
	for _, _ in pairs(weapons) do
		count = count + 1
	end
	
	for _, weaponName in ipairs(weapons) do
		if typeof(weaponName) == "string" then
			createItemCard(weaponName)
		end
	end
	
	if count > 0 and #weapons == 0 then
		for key, value in pairs(weapons) do
			local weaponName = if typeof(value) == "string" then value else (if typeof(key) == "string" then key else nil)
			if weaponName then
				createItemCard(weaponName)
			end
		end
	end

	task.wait()
	
	local equippedWeapon = PlayerDataManager:Get(LocalPlayer, { 'Inventory', 'EquippedWeapon' })
	updateEquippedState(equippedWeapon)
end

function InventoryController:Init()
	ItemTemplateBT.Visible = false
	
	repeat task.wait() until PlayerDataManager:Get(LocalPlayer, { 'Inventory' })
	
	buildInventory()

	janitor:Add(
		PlayerDataManager:GetValueInsertedSignal(LocalPlayer, { 'Inventory', 'Weapons' }):Connect(function(arg1, arg2)
			local weaponName = if typeof(arg1) == "string" then arg1 else arg2
			createItemCard(weaponName)
		end), 'Disconnect'
	)

	janitor:Add(
		PlayerDataManager:GetValueRemovedSignal(LocalPlayer, { 'Inventory', 'Weapons' }):Connect(function(arg1, arg2)
			local weaponName = if typeof(arg1) == "string" then arg1 else arg2
			removeItemCard(weaponName)
		end), 'Disconnect'
	)

	janitor:Add(
		PlayerDataManager:GetValueChangedSignal(LocalPlayer, { 'Inventory', 'EquippedWeapon' }):Connect(function(newValue, oldValue)
			updateEquippedState(newValue)
		end), 'Disconnect'
	)
	
	janitor:Add(
		SearchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
			applySearchFilter()
		end), 'Disconnect'
	)
end

return InventoryController