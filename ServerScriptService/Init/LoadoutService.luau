local LoadoutService = {}

local DataService
local MoneyService

local Weapons = require(game.ReplicatedStorage.Resources.Weapons)

local UnlockedWeaponPacket
local EquipWeaponPacket
local LoadoutPacket

function LoadoutService:GetWeaponData(WeaponName:string)
	for _, weapon in Weapons do
		if weapon.Name == WeaponName then
			return weapon
		end
	end
end

function LoadoutService:BuyWeapon(Player: Player, WeaponName: string)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then return end
	
	if table.find(PlayerData.UnlockedWeapons, WeaponName) then
		return false
	end
	
	local WeaponData = self:GetWeaponData(WeaponName)
	if not WeaponData then return false end
	if WeaponData.Slot == "Gloves" then return false end
	if not MoneyService:RemoveMoney(Player, WeaponData.Price) then
		return false
	end
	
	table.insert(PlayerData.UnlockedWeapons, WeaponName)
	task.spawn(function()
		UnlockedWeaponPacket:FireClient(Player, WeaponName)
	end)

	return true
end

function LoadoutService:EquipWeapon(Player: Player, WeaponName: string)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then return end
	
	if not table.find(PlayerData.UnlockedWeapons, WeaponName) then
		return false
	end
	
	local WeaponData = self:GetWeaponData(WeaponName)
	if not WeaponData then return false end
	if WeaponData.Slot == "Gloves" then return false end
	
	PlayerData.Loadout[WeaponData.Slot] = WeaponName
	
	task.spawn(function()
		EquipWeaponPacket:FireClient(Player, WeaponName)
	end)
	
	return true
end

function LoadoutService:LoadLoadout(Player: Player)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return
	end

	
	for slot, weapon in PlayerData.Loadout do
		local weaponData = self:GetWeaponData(weapon)
		if not weaponData then continue end
		if slot == "Gloves" then continue end
		local weaponModel = game.ServerStorage.Weapons[weaponData.Name]:Clone()
		
		weaponModel.Parent = Player.Backpack
	end
end

function LoadoutService:GetLoadout(Player: Player)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then return end
	
	local Loadout = {}
	
	for slot, weapon in PlayerData.Loadout do
		local weaponData = self:GetWeaponData(weapon)
		if not weaponData then continue end
		
		Loadout[slot] = weaponData.Name
	end
	
	return Loadout
end

function LoadoutService:GetUnlockedWeapons(Player: Player)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then return end
	return PlayerData.UnlockedWeapons
end

function LoadoutService:Init()
	DataService = self.Services.DataService
	MoneyService = self.Services.MoneyService
	
	local Packet = self.Libs.Packet
	
	LoadoutPacket = Packet("GetLoadout", Packet.Any):Response(Packet.Any)
	UnlockedWeaponPacket = Packet("GetUnlockedWeapons", Packet.Any):Response(Packet.Any)
	EquipWeaponPacket = Packet("EquipWeapon", Packet.Any):Response(Packet.Any)
	
	LoadoutPacket.OnServerInvoke = function(Player: Player)
		return self:GetLoadout(Player)
	end
	UnlockedWeaponPacket.OnServerInvoke = function(Player: Player)
		return self:GetUnlockedWeapons(Player)
	end
	Packet("BuyWeapon", Packet.Any):Response(Packet.Any).OnServerInvoke = function(Player: Player, WeaponName: string)
		return self:BuyWeapon(Player, WeaponName)
	end
	EquipWeaponPacket.OnServerInvoke = function(Player: Player, WeaponName: string)
		return self:EquipWeapon(Player, WeaponName)
	end
	
end

function LoadoutService:Start()
	
end

return LoadoutService