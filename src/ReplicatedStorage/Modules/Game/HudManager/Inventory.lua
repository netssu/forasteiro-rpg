------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

------------------//CONSTANTS
local CATEGORY_MAPPINGS = {
	["BTPets"] = "Pets",
	["BTPogos"] = "Pogos"
}

local COLOR_EQUIPPED = Color3.fromRGB(197, 255, 209)
local COLOR_DEFAULT = Color3.fromRGB(255, 255, 255)
local COLOR_AFFORD = Color3.fromHex("fff0a6")
local COLOR_NO_AFFORD = Color3.fromHex("ff9294")
local COLOR_SELECTED_SLOT = Color3.fromRGB(100, 150, 255)

local MAX_PET_SLOTS = 2
local EXTRA_SLOT_GAMEPASS_ID = 1700692919

------------------//VARIABLES
local InventoryController = {}
local localPlayer = Players.LocalPlayer

local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local MathUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("MathUtility"))
local DataPets = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PetsData"))
local PogoData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PogoData"))
local RarityData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("RaritysData"))
local HudManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("HudManager"))
local NotificationUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("NotificationUtility"))

local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local equipPetRemote = remotesFolder:WaitForChild("EquipPet")
local shopActionRemote = remotesFolder:WaitForChild("ShopAction")

local createdFrames = {}
local currentCategory = "Pets"
local currentSearchQuery = ""

local ownedPets = {}
local equippedPets = {}
local ownedPogos = {}
local equippedPogo = "BasicPogo"
local currentCoins = 0
local currentRebirths = 0

local hasExtraPetSlots = false 

local selectedSlot = 1

local notifiedPogos = {}

------------------//FUNCTIONS

local function get_ui_references()
	local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
	if not playerGui then return nil end

	local invFrame = playerGui:FindFirstChild("Inventory", true)
	if not invFrame then return nil end

	local categoryFR = invFrame:FindFirstChild("CategoryFR", true)
	local indexBG = invFrame:FindFirstChild("IndexBG", true)

	local gridScrollingFrame = indexBG and indexBG:FindFirstChild("GridScrollingFrame")
	local template = gridScrollingFrame and gridScrollingFrame:FindFirstChild("Template")

	local searchBT = indexBG and indexBG:FindFirstChild("SearchBT")
	local textboxBG = indexBG and indexBG:FindFirstChild("TextboxBG")
	local textBox = textboxBG and textboxBG:FindFirstChild("TextBox")

	local slotEquip = invFrame:FindFirstChild("SlotEquip", true)
	local slot1 = slotEquip and slotEquip:FindFirstChild("Slot1")
	local slot2 = slotEquip and slotEquip:FindFirstChild("Slot2")
	local lockIcon = slot2 and slot2:FindFirstChild("LockIcon")

	local closeBT = invFrame:FindFirstChild("CloseBT", true)

	return {
		Main = invFrame,
		Index = indexBG,
		CategoryFR = categoryFR,
		ScrollingFrame = gridScrollingFrame,
		Template = template,
		SearchBT = searchBT,
		TextBox = textBox,
		SlotEquip = slotEquip,
		Slot1 = slot1,
		Slot2 = slot2,
		LockIcon = lockIcon,
		CloseBT = closeBT
	}
end

local function clear_grid()
	for _, frame in pairs(createdFrames) do
		frame:Destroy()
	end
	table.clear(createdFrames)
end

local function update_slot_visuals()
	local ui = get_ui_references()
	if not ui or not ui.Slot1 or not ui.Slot2 then return end

	if selectedSlot == 2 and not hasExtraPetSlots then
		selectedSlot = 1
	end

	local function set_slot_color(guiObject, isActive)
		local targetColor = isActive and COLOR_EQUIPPED or COLOR_DEFAULT

		if guiObject:IsA("ImageButton") or guiObject:IsA("ImageLabel") then
			guiObject.ImageColor3 = targetColor
		else
			guiObject.BackgroundColor3 = targetColor
		end
	end

	set_slot_color(ui.Slot1, selectedSlot == 1)
	set_slot_color(ui.Slot2, selectedSlot == 2 and hasExtraPetSlots)

	if ui.LockIcon then
		ui.LockIcon.Visible = not hasExtraPetSlots
	end
	
	local function update_slot_content(slotFrame, petId)
		for _, child in pairs(slotFrame:GetChildren()) do
			if child:IsA("ViewportFrame") then
				child:Destroy()
			end
		end

		local rarityTX = slotFrame:FindFirstChild("Rarity")
		local itemNameTX = slotFrame:FindFirstChild("ItemNameTX")

		if petId and petId ~= "" then
			local petData = DataPets.GetPetData(petId)
			if petData then
				local viewport = DataPets.GetPetViewport(petId)
				if viewport then
					viewport.Size = UDim2.new(0.8, 0, 0.8, 0)
					viewport.Position = UDim2.new(0.5, 0, 0.5, 0)
					viewport.AnchorPoint = Vector2.new(0.5, 0.5)
					viewport.BackgroundTransparency = 1
					viewport.ZIndex = 3
					viewport.Parent = slotFrame
				end

				if itemNameTX then
					itemNameTX.Text = petData.DisplayName or petId
					itemNameTX.Visible = true
				end

				if rarityTX then
					local rarityKey = petData.Raritys
					local rarityInfo = RarityData[rarityKey]

					if rarityInfo then
						rarityTX.Text = rarityInfo.DisplayName
						rarityTX.TextColor3 = rarityInfo.Color
					else
						rarityTX.Text = rarityKey or "Unknown"
						rarityTX.TextColor3 = Color3.fromRGB(255, 255, 255)
					end
					rarityTX.Visible = true
				end
			end
		else
			if rarityTX then rarityTX.Visible = false end
			if itemNameTX then itemNameTX.Visible = false end
		end
	end
	update_slot_content(ui.Slot1, equippedPets["1"] or equippedPets[1])
	update_slot_content(ui.Slot2, equippedPets["2"] or equippedPets[2])
end

local function check_gamepass_ownership()
	task.spawn(function()
		local success, hasPass = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(localPlayer.UserId, EXTRA_SLOT_GAMEPASS_ID)
		end)

		if success and hasPass then
			hasExtraPetSlots = true
			update_slot_visuals()
		end
	end)
end

local function update_visuals()
	for itemId, frame in pairs(createdFrames) do
		local category = frame:GetAttribute("Category")
		local targetColor = COLOR_DEFAULT

		if category == "Pets" then
			local petInSelectedSlot = equippedPets[tostring(selectedSlot)] or equippedPets[selectedSlot]

			if itemId == petInSelectedSlot then
				targetColor = COLOR_EQUIPPED
			end
		elseif category == "Pogos" then
			local isOwned = ownedPogos[itemId]
			if isOwned then
				if itemId == equippedPogo then
					targetColor = COLOR_EQUIPPED
				else
					targetColor = COLOR_DEFAULT
				end
			else
				local pogoPrice = frame:GetAttribute("Price") or 0
				local pogoRebirths = frame:GetAttribute("Rebirths") or 0

				local canAfford = (currentCoins >= pogoPrice) and (currentRebirths >= pogoRebirths)
				if canAfford then
					targetColor = COLOR_AFFORD
				else
					targetColor = COLOR_NO_AFFORD
				end
			end
		end

		if frame:IsA("ImageButton") or frame:IsA("ImageLabel") then
			frame.ImageColor3 = targetColor
		else
			frame.BackgroundColor3 = targetColor
		end
	end

	update_slot_visuals()
end

local function create_item_frame(itemId, parent, template, category, extraData)
	local newFrame = template:Clone()
	newFrame.Name = itemId
	newFrame.Visible = true
	newFrame:SetAttribute("Category", category)

	if newFrame:IsA("GuiButton") then
		newFrame.AutoButtonColor = true
	end

	local itemNameTX = newFrame:FindFirstChild("ItemNameTX")
	local itemCountTX = newFrame:FindFirstChild("ItemCountTX")
	local valueTX = newFrame:FindFirstChild("ValueTX")
	local value2TX = newFrame:FindFirstChild("Value2TX")
	local rarityTX = newFrame:FindFirstChild("Rarity")

	if valueTX then valueTX.Visible = false end
	if value2TX then value2TX.Visible = false end

	if category == "Pets" then
		if itemCountTX then itemCountTX.Visible = false end

		local petData = DataPets.GetPetData(itemId)
		if petData then
			if itemNameTX then itemNameTX.Text = petData.DisplayName or itemId end

			if rarityTX then
				local rarityKey = petData.Raritys
				local rarityInfo = RarityData[rarityKey]
				if rarityInfo then
					rarityTX.Text = rarityInfo.DisplayName
					rarityTX.TextColor3 = rarityInfo.Color
				else
					rarityTX.Text = rarityKey or "Unknown"
					rarityTX.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
				rarityTX.Visible = true
			end

			local boostPetTX = newFrame:FindFirstChild("BoostPetTX")
			if boostPetTX then
				boostPetTX.Visible = true
				local multiplierPercent = (petData.Multiplier or 0) * 100
				boostPetTX.Text = "+" .. MathUtility.format_number(multiplierPercent) .. "%💰"
				boostPetTX.TextColor3 = Color3.fromRGB(255, 215, 0)
			end

			local viewport = DataPets.GetPetViewport(itemId)
			if viewport then
				viewport.Size = UDim2.new(0.7, 0, 0.7, 0)
				viewport.Position = UDim2.new(0.5, 0, 0.4, 0)
				viewport.AnchorPoint = Vector2.new(0.5, 0.5)
				viewport.BackgroundTransparency = 1
				viewport.ZIndex = 2
				viewport.Parent = newFrame
			end
		end

	elseif category == "Pogos" then
		if rarityTX then rarityTX.Visible = false end

		local pogoData = extraData
		local isOwned = ownedPogos[itemId]

		newFrame:SetAttribute("Price", pogoData.Price or 0)
		newFrame:SetAttribute("Rebirths", pogoData.RequiredRebirths or 0)

		if itemNameTX then itemNameTX.Text = pogoData.Name end

		if itemCountTX then
			itemCountTX.Visible = true
			itemCountTX.Text = "⚡ " .. MathUtility.format_number(pogoData.Power or 0)
			itemCountTX.TextColor3 = Color3.fromRGB(100, 200, 255)
		end

		if not isOwned then
			if valueTX then
				valueTX.Visible = true
				valueTX.Text = "$ " .. MathUtility.format_number(pogoData.Price or 0)
			end
			if value2TX and (pogoData.RequiredRebirths or 0) > 0 then
				value2TX.Visible = true
				value2TX.Text = "♻️ " .. MathUtility.format_number(pogoData.RequiredRebirths)
			end
		end
		local viewport = PogoData.GetPogoViewport(itemId)
		if viewport then
			viewport.Size = UDim2.new(0.7, 0, 0.7, 0) 
			viewport.Position = UDim2.new(0.5, 0, 0.45, 0)
			viewport.AnchorPoint = Vector2.new(0.5, 0.5)
			viewport.BackgroundTransparency = 1
			viewport.ZIndex = 0
			viewport.Parent = newFrame
		end
	end

	local function on_click()
		if category == "Pets" then
			local maxSlots = hasExtraPetSlots and MAX_PET_SLOTS or 1

			if selectedSlot > maxSlots then
				selectedSlot = 1
				NotificationUtility:Info("Extra slot is locked! Switched to Slot 1.", 2)
				update_slot_visuals()
			end

			local currentPetInSlot = equippedPets[tostring(selectedSlot)] or equippedPets[selectedSlot]

			if currentPetInSlot == itemId then
				equipPetRemote:FireServer(selectedSlot, nil)
			else
				local isPetInOtherSlot = false
				for slotIndex, petId in pairs(equippedPets) do
					if tostring(slotIndex) ~= tostring(selectedSlot) and petId == itemId then
						isPetInOtherSlot = true
						break
					end
				end

				if isPetInOtherSlot then
					NotificationUtility:Info("This pet is already equipped in another slot!", 3)
				else
					equipPetRemote:FireServer(selectedSlot, itemId)
				end
			end
		elseif category == "Pogos" then
			if ownedPogos[itemId] then
				if equippedPogo ~= itemId then
					shopActionRemote:FireServer("Equip", itemId)
				end
			else
				shopActionRemote:FireServer("Buy", itemId)
			end
		end
	end

	if newFrame:IsA("GuiButton") then
		newFrame.Activated:Connect(on_click)
	else
		newFrame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				on_click()
			end
		end)
	end

	newFrame.Parent = parent
	return newFrame
end

local function matches_search(itemName, displayName)
	if currentSearchQuery == "" or currentSearchQuery == " " then
		return true
	end
	local searchLower = string.lower(currentSearchQuery)
	local nameLower = string.lower(itemName)
	local displayLower = displayName and string.lower(displayName) or ""

	if string.find(nameLower, searchLower) or string.find(displayLower, searchLower) then
		return true
	end
	return false
end

local function update_inventory()
	local ui = get_ui_references()
	if not ui or not ui.ScrollingFrame or not ui.Template then return end
	if ui.SlotEquip then
		ui.SlotEquip.Visible = (currentCategory == "Pets")
	end

	ui.Template.Visible = false
	clear_grid()

	ui.Index.HeaderTX.Text = currentCategory

	if currentCategory == "Pets" then
		if not ownedPets then return end
		for petName, isOwned in pairs(ownedPets) do
			if isOwned then
				local petData = DataPets.GetPetData(petName)
				local displayName = petData and petData.DisplayName or petName

				if matches_search(petName, displayName) then
					local frame = create_item_frame(petName, ui.ScrollingFrame, ui.Template, "Pets", nil)
					if frame then createdFrames[petName] = frame end
				end
			end
		end

	elseif currentCategory == "Pogos" then
		local allPogos = PogoData.GetSortedList()
		for _, data in ipairs(allPogos) do
			local pogoId = data.Id
			if matches_search(pogoId, data.Name) then
				local frame = create_item_frame(pogoId, ui.ScrollingFrame, ui.Template, "Pogos", data)
				frame.LayoutOrder = data.Order or 0
				if frame then createdFrames[pogoId] = frame end
			end
		end
	end
	update_visuals()
end

local function setup_search_events(ui)
	if not ui.SearchBT or not ui.TextBox then return end
	local function perform_search()
		currentSearchQuery = ui.TextBox.Text
		update_inventory()
	end
	ui.SearchBT.Activated:Connect(perform_search)
	ui.TextBox.FocusLost:Connect(perform_search)
end

local function setup_category_buttons(ui)
	if not ui.CategoryFR then return end
	local categoryBG = ui.CategoryFR:FindFirstChild("CategoryBG")
	if not categoryBG then return end

	for _, btn in ipairs(categoryBG:GetChildren()) do
		if CATEGORY_MAPPINGS[btn.Name] then
			btn.Activated:Connect(function()
				currentCategory = CATEGORY_MAPPINGS[btn.Name]
				currentSearchQuery = ""
				if ui.TextBox then ui.TextBox.Text = "" end
				update_inventory()
			end)
		end
	end
end

local function setup_slot_buttons(ui)
	if not ui.Slot1 or not ui.Slot2 then return end
	if ui.Slot1:IsA("GuiButton") then ui.Slot1.AutoButtonColor = false end
	if ui.Slot2:IsA("GuiButton") then ui.Slot2.AutoButtonColor = false end

	ui.Slot1.Activated:Connect(function()
		selectedSlot = 1
		update_slot_visuals()
	end)

	ui.Slot2.Activated:Connect(function()
		if hasExtraPetSlots then
			selectedSlot = 2
			update_slot_visuals()
		else
			NotificationUtility:Info("Unlock extra pet slot with gamepass!", 3)
		end
	end)
end

local function setup_close_button(ui)
	if not ui.CloseBT then return end

	ui.CloseBT.Activated:Connect(function()
		if ui.Main then
			ui.Main.Visible = false
		end
	end)
end

local function check_pogo_availability()
	local allPogos = PogoData.GetSortedList()
	for _, pogo in ipairs(allPogos) do
		if not ownedPogos[pogo.Id] and not notifiedPogos[pogo.Id] then
			local price = pogo.Price or 0
			local reqRebirths = pogo.RequiredRebirths or 0

			if currentCoins >= price and currentRebirths >= reqRebirths then
				NotificationUtility:Success({
					message = "New Pogo Available! Click here to buy!",
					duration = 5,
					buttonText = "OPEN",
					callback = function()
						local playerGui = localPlayer.PlayerGui
						local uiFolder = playerGui:FindFirstChild("UI")
						if uiFolder then
							local inventoryFrame = uiFolder:FindFirstChild("Inventory")
							if inventoryFrame then
								inventoryFrame.Visible = true
								currentCategory = "Pogos"
								currentSearchQuery = ""
								update_inventory()
							end
						end
					end
				})
				notifiedPogos[pogo.Id] = true
			end
		end
	end
end

local function setup_inventory_event_listener()
	local InventoryEvent = ReplicatedStorage:FindFirstChild("InventoryEvent")
	if not InventoryEvent then
		InventoryEvent = Instance.new("BindableEvent")
		InventoryEvent.Name = "InventoryEvent"
		InventoryEvent.Parent = ReplicatedStorage
	end

	InventoryEvent.Event:Connect(function(category)
		if category == "Pogos" then
			currentCategory = "Pogos"
			currentSearchQuery = ""
			local ui = get_ui_references()
			if ui and ui.TextBox then ui.TextBox.Text = "" end
			update_inventory()
		end
	end)
end

local function open_inventory_to_pogos(): ()
	local ui = get_ui_references()
	if not ui or not ui.Main then
		return
	end

	ui.Main.Visible = true
	currentCategory = "Pogos"
	currentSearchQuery = ""

	if ui.TextBox then
		ui.TextBox.Text = ""
	end

	update_inventory()

	local scrolling = ui.ScrollingFrame
	if scrolling then
		local firstNotOwnedAffordable: GuiObject? = nil

		for _, frame in pairs(createdFrames) do
			if frame:GetAttribute("Category") == "Pogos" then
				local pogoId = frame.Name
				local isOwned = ownedPogos[pogoId] == true

				if not isOwned then
					local price = frame:GetAttribute("Price") or 0
					local rebirths = frame:GetAttribute("Rebirths") or 0
					local canAfford = (currentCoins >= price) and (currentRebirths >= rebirths)

					if canAfford then
						firstNotOwnedAffordable = frame
						break
					end
				end
			end
		end

		if firstNotOwnedAffordable then
			scrolling.CanvasPosition = Vector2.new(0, math.max(0, firstNotOwnedAffordable.AbsolutePosition.Y - scrolling.AbsolutePosition.Y))
		else
			scrolling.CanvasPosition = Vector2.new(0, 0)
		end
	end
end

------------------//MAIN FUNCTIONS

function InventoryController.open_pogos_hud(): ()
	open_inventory_to_pogos()
end
DataUtility.client.ensure_remotes()

DataUtility.client.bind("OwnedPets", function(val)
	ownedPets = val or {}
	if currentCategory == "Pets" then update_inventory() end
end)

DataUtility.client.bind("EquippedPets", function(val)
	equippedPets = val or {}
	update_visuals()
end)

DataUtility.client.bind("OwnedPogos", function(val)
	ownedPogos = val or {}
	if currentCategory == "Pogos" then update_inventory() end
	check_pogo_availability()
end)

DataUtility.client.bind("EquippedPogoId", function(val)
	equippedPogo = val
	update_visuals()
end)

DataUtility.client.bind("Coins", function(val)
	currentCoins = val or 0
	if currentCategory == "Pogos" then update_visuals() end
	check_pogo_availability()
end)

DataUtility.client.bind("Rebirths", function(val)
	currentRebirths = val or 0
	if currentCategory == "Pogos" then update_visuals() end
	check_pogo_availability()
end)

DataUtility.client.bind("Gamepasses", function(val)
	if val then
		if val.ExtraPetSlots == true then hasExtraPetSlots = true end
		update_slot_visuals()
	end
end)

task.spawn(function()
	ownedPets = DataUtility.client.get("OwnedPets") or {}
	equippedPets = DataUtility.client.get("EquippedPets") or {}
	ownedPogos = DataUtility.client.get("OwnedPogos") or {}
	equippedPogo = DataUtility.client.get("EquippedPogoId")
	currentCoins = DataUtility.client.get("Coins") or 0
	currentRebirths = DataUtility.client.get("Rebirths") or 0

	local gamepasses = DataUtility.client.get("Gamepasses") or {}
	hasExtraPetSlots = gamepasses.ExtraPetSlots == true
	check_gamepass_ownership()
	
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
		if player == localPlayer and gamePassId == EXTRA_SLOT_GAMEPASS_ID and wasPurchased then
			hasExtraPetSlots = true
			update_slot_visuals()
			NotificationUtility:Success({
				message = "Extra Slot Unlocked!",
				duration = 3
			})
		end
	end)

	local allPogos = PogoData.GetSortedList()
	for _, pogo in ipairs(allPogos) do
		if not ownedPogos[pogo.Id] then
			local price = pogo.Price or 0
			local reqRebirths = pogo.RequiredRebirths or 0
			if currentCoins >= price and currentRebirths >= reqRebirths then
				notifiedPogos[pogo.Id] = true
			end
		end
	end

	local ui = get_ui_references()
	if ui then
		setup_category_buttons(ui)
		setup_search_events(ui)
		setup_slot_buttons(ui)
		setup_close_button(ui)
		setup_inventory_event_listener()
		update_inventory()
	else
		warn("InventoryController: UI não encontrada.")
	end
end)

return InventoryController