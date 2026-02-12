------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local REMOTE_FOLDER_NAME = "Remotes"
local SHOP_ACTION_REMOTE_NAME = "ShopAction"
local EQUIP_REMOTE_NAME = "EquipPet"
local MAX_PET_SLOTS = 2

------------------//VARIABLES
local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local PogoData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PogoData"))
local DataPets = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PetsData"))

local shopActionRemote: RemoteEvent
local equipRemote: RemoteEvent

------------------//FUNCTIONS
local function setup_remotes(): ()
	local assetsFolder = ReplicatedStorage:WaitForChild("Assets")
	local remotesFolder = assetsFolder:FindFirstChild(REMOTE_FOLDER_NAME)

	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = REMOTE_FOLDER_NAME
		remotesFolder.Parent = assetsFolder
	end

	shopActionRemote = remotesFolder:FindFirstChild(SHOP_ACTION_REMOTE_NAME)
	if not shopActionRemote then
		shopActionRemote = Instance.new("RemoteEvent")
		shopActionRemote.Name = SHOP_ACTION_REMOTE_NAME
		shopActionRemote.Parent = remotesFolder
	end

	equipRemote = remotesFolder:FindFirstChild(EQUIP_REMOTE_NAME)
	if not equipRemote then
		equipRemote = Instance.new("RemoteEvent")
		equipRemote.Name = EQUIP_REMOTE_NAME
		equipRemote.Parent = remotesFolder
	end
end

local function get_pogo_data(pogoId: string)
	local allPogos = PogoData.GetSortedList()
	for _, pogoInfo in ipairs(allPogos) do
		if pogoInfo.Id == pogoId then
			return pogoInfo
		end
	end
	return nil
end

local function buy_pogo(player: Player, pogoId: string)
	local pogoInfo = get_pogo_data(pogoId)
	if not pogoInfo then return end

	local ownedPogos = DataUtility.server.get(player, "OwnedPogos") or {}
	if ownedPogos[pogoId] then return end

	local currentCoins = DataUtility.server.get(player, "Coins") or 0
	local currentRebirths = DataUtility.server.get(player, "Rebirths") or 0
	local price = pogoInfo.Price or 0
	local requiredRebirths = pogoInfo.RequiredRebirths or 0

	if currentCoins < price or currentRebirths < requiredRebirths then
		return
	end

	DataUtility.server.set(player, "Coins", currentCoins - price)
	ownedPogos[pogoId] = true
	DataUtility.server.set(player, "OwnedPogos", ownedPogos)
	DataUtility.server.set(player, "EquippedPogoId", pogoId)
	player:SetAttribute("LastPurchase", nil) 
	player:SetAttribute("LastPurchase", "Pogo")
end

local function equip_pogo(player: Player, pogoId: string)
	local ownedPogos = DataUtility.server.get(player, "OwnedPogos") or {}
	if not ownedPogos[pogoId] then return end

	DataUtility.server.set(player, "EquippedPogoId", pogoId)
end

local function on_shop_action(player: Player, action: any, itemId: any)
	if type(action) ~= "string" or type(itemId) ~= "string" then return end

	if action == "Buy" then
		buy_pogo(player, itemId)
	elseif action == "Equip" then
		equip_pogo(player, itemId)
	end
end

local function is_valid_pet(petId: string): boolean
	local petData = DataPets.GetPetData(petId)
	return petData ~= nil
end

local function is_pet_owned(player: Player, petId: string): boolean
	local ownedPets = DataUtility.server.get(player, "OwnedPets")
	if not ownedPets then return false end
	return ownedPets[petId] == true
end

local function get_max_slots(player: Player): number
	local gamepasses = DataUtility.server.get(player, "Gamepasses") or {}

	if gamepasses.ExtraPetSlots == true then
		return MAX_PET_SLOTS
	end

	return 1
end

local function sanitize_equipped_pets(player: Player)
	local maxSlots = get_max_slots(player)
	local equippedPets = DataUtility.server.get(player, "EquippedPets") or {}
	local changed = false

	for slot, _ in pairs(equippedPets) do
		if tonumber(slot) > maxSlots then
			equippedPets[slot] = nil
			changed = true
			warn("[InventoryService] Removido pet do slot bloqueado (".. slot ..") de: " .. player.Name)
		end
	end

	if changed then
		DataUtility.server.set(player, "EquippedPets", equippedPets)
	end
end

local function equip_pet(player: Player, slotIndex: number, petId: string?)
	local maxSlots = get_max_slots(player)

	if slotIndex < 1 or slotIndex > maxSlots then
		warn("[InventoryService] TENTATIVA ILEGAL: " .. player.Name .. " tentou usar Slot " .. slotIndex .. " (Máx permitido: " .. maxSlots .. ")")
		return
	end

	if petId ~= nil then
		if not is_valid_pet(petId) then return end
		if not is_pet_owned(player, petId) then return end
	end

	local equippedPets = DataUtility.server.get(player, "EquippedPets") or {}

	if type(equippedPets) ~= "table" then equippedPets = {} end

	equippedPets[tostring(slotIndex)] = petId

	DataUtility.server.set(player, "EquippedPets", equippedPets)
	print("[InventoryService] " .. player.Name .. " equipou " .. (petId or "NADA") .. " no Slot " .. slotIndex)
end

local function on_equip_request(player: Player, slotIndex: any, petId: any)
	if type(slotIndex) ~= "number" then return end
	if petId ~= nil and type(petId) ~= "string" then return end

	equip_pet(player, slotIndex, petId)
end

------------------//INIT
setup_remotes()
shopActionRemote.OnServerEvent:Connect(on_shop_action)
equipRemote.OnServerEvent:Connect(on_equip_request)

Players.PlayerAdded:Connect(function(player)
	task.wait(2)
	sanitize_equipped_pets(player)
end)

return {}