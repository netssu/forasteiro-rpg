-- [[ Inventario de skins e skins equipadas ]]

local SkinInventoryService = {}

local Skins = require(game.ReplicatedStorage.Resources.Skins)
local SkinUtils = require(game.ReplicatedStorage.Resources.Skins.Utils)

local DataService

-- para enviar ao cliente quando algo acontecer
local DeleteSkinPacket
local EquipSkinPacket
local UnequipSkinPacket
local EquippedSkinsPacket
local SkinInventoryPacket


function SkinInventoryService:AddSkin(Player: Player, SkinID: number)
	local Data = DataService:GetData(Player)
	if not Data then return false end
	
	Data.LastSkinID += 1
	
	local Skin = {
		SkinID = SkinID,
		InventoryID = Data.LastSkinID
	}
	table.insert(Data.Skins, Skin)
	
	task.spawn(function()
		SkinInventoryPacket:FireClient(Player,Skin)
	end)
	
	return true
end

function SkinInventoryService:GetSkinByInventoryID(Player: Player, InventoryID: number)
	InventoryID = tonumber(InventoryID)

	local Data = DataService:GetData(Player)
	if not Data then return false end
	
	for Index, Skin in Data.Skins do
		if Skin.InventoryID == InventoryID then
			return Skin, Index
		end
	end
	
	return false
end

function SkinInventoryService:RemoveSkin(Player: Player, InventoryID: number)
	InventoryID = tonumber(InventoryID)
	local Data = DataService:GetData(Player)
	if not Data then return false end

	for Index, Skin in Data.Skins do
		if Skin.InventoryID == InventoryID then
			table.remove(Data.Skins, Index)
			
			task.spawn(function()
				DeleteSkinPacket:FireClient(Player,InventoryID)
			end)
			
			return true
		end
	end
	
	return false
end

-- PUBLIC
function SkinInventoryService:EquipSkin(Player: Player, InventoryID: number)
	InventoryID = tonumber(InventoryID)

	local Data = DataService:GetData(Player)
	if not Data then return false end
	
	local Skin = SkinInventoryService:GetSkinByInventoryID(Player, InventoryID)
	if not Skin then return false end
	
	local SkinData = SkinUtils.GetSkinByID(Skin.SkinID)
	Data.EquippedSkins[SkinData.Weapon] = Skin.InventoryID
	
	task.spawn(function()
		EquipSkinPacket:FireClient(Player,Skin)
	end)

	return true
end

-- PUBLIC
function SkinInventoryService:UnequipSkin(Player: Player, Weapon: string)
	local Data = DataService:GetData(Player)
	if not Data then return false end
	
	task.spawn(function()
		UnequipSkinPacket:FireClient(Player,Weapon)
	end)
	
	Data.EquippedSkins[Weapon] = nil
	
	return true
end

-- PUBLIC
function SkinInventoryService:GetEquippedSkins(Player: Player)
	local Data = DataService:GetData(Player)
	if not Data then return false end
	
	local Skins = {}

	for Weapon, InventoryID in Data.EquippedSkins do
		local skin,_ = self:GetSkinByInventoryID(Player,InventoryID)
		Skins[Weapon] = skin
	end
	
	return Skins
end

-- PUBLIC
function SkinInventoryService:GetInventory(Player: Player)
	local Data = DataService:GetData(Player)
	if not Data then 
		return false   
	end
	
	return Data.Skins
end

-- PUBLIC 
function SkinInventoryService:DeleteSkin(Player: Player, InventoryID: number)
	InventoryID = tonumber(InventoryID)

	local Data = DataService:GetData(Player)
	if not Data then return false end
		
	if self:RemoveSkin(Player, InventoryID) then
		return true
	end
	
	return false
end

local Packet

function SkinInventoryService:Init()
	DataService = self.Services.DataService
	Packet = self.Libs.Packet
	
	
	
	EquipSkinPacket = Packet("EquipSkin", Packet.Any):Response(Packet.Any)
	
	UnequipSkinPacket = Packet("UnequipSkin", Packet.Any):Response(Packet.Any)
	
	EquippedSkinsPacket = Packet("GetEquippedSkins", Packet.Any):Response(Packet.Any)
	
	SkinInventoryPacket = Packet("GetInventory", Packet.Any):Response(Packet.Any)
	
	DeleteSkinPacket = Packet("DeleteSkin", Packet.Any):Response(Packet.Any)
	
	
	
	EquipSkinPacket.OnServerInvoke = function(Player: Player, InventoryID: number)
		return SkinInventoryService:EquipSkin(Player, InventoryID)
	end
	UnequipSkinPacket.OnServerInvoke = function(Player: Player, Weapon: string)
		return SkinInventoryService:UnequipSkin(Player, Weapon)
	end
	EquippedSkinsPacket.OnServerInvoke = function(Player: Player)
		return SkinInventoryService:GetEquippedSkins(Player)
	end
	SkinInventoryPacket.OnServerInvoke = function(Player: Player)
		return SkinInventoryService:GetInventory(Player)
	end
	DeleteSkinPacket.OnServerInvoke = function(Player: Player, InventoryID: number)
		return SkinInventoryService:DeleteSkin(Player, InventoryID)
	end
	
end




return SkinInventoryService