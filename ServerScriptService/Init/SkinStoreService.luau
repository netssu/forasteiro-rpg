local SkinStoreService = {}

local DataService
local MoneyService
local SkinInventoryService

local Crates = require(game.ReplicatedStorage.Resources.Crates)
local SkinsModule = require(game.ReplicatedStorage.Resources.Skins)
local AvailableSkins = {}
local DailySkins = {}

local DailySeed = 0
local CurrentDay = 0

local Players = game:GetService("Players")

local SkinStoreUpdatedPacket

function SkinStoreService:GetStoreToSend()
	local Store = {}

	for _, Skin in DailySkins do
		table.insert(Store, Skin.SkinID)
	end

	return Store
end

function SkinStoreService:GetStore(Player: Player)
	return self:GetStoreToSend()
end

function ReRollSKin(SkinId, Rng, slotcheck)
	local NewId = Rng:NextInteger(1, #AvailableSkins)
	repeat NewId = Rng:NextInteger(1, #AvailableSkins) until slotcheck ~= SkinId
	return NewId
end

function SkinStoreService:GenerateStore()
	local Rng = Random.new(DailySeed)

	table.clear(DailySkins)

	for Index = 1, 3 do
		local SkinId = Rng:NextInteger(1, #AvailableSkins)
		local Skin = AvailableSkins[SkinId]
		for _, slotcheck in DailySkins do
			if slotcheck.SkinID == SkinId then
				local reroll =ReRollSKin(SkinId,Rng, slotcheck.SkinID)
				SkinId = reroll
				break
			end
		end
		DailySkins[Index] = Skin
		Skin.SkinID = SkinId
	end

	self:StoreUpdated()
end

function SkinStoreService:StoreUpdated()
	SkinStoreUpdatedPacket:Fire(self:GetStoreToSend())
end

function SkinStoreService:GenerateSeedFromDay()
	local Date = os.date("*t")
	local DayCode = Date.year * 10000 + Date.month * 100 + Date.day
	DailySeed = DayCode
	CurrentDay = DayCode
end

function SkinStoreService:BuySkin(Player: Player, SkinID: number)
	local Data = DataService:GetData(Player)
	if not Data then return false end

	local SelectedSkin
	
	for _, Skin in DailySkins do
		if Skin.SkinID == SkinID then
			SelectedSkin = Skin
			break
		end
	end

	if not SelectedSkin then
		return false
	end

	local Price = SelectedSkin.Price -- talvez por raridade
	
	if not Price then
		warn("THE SKIN HAS NO DEFINED PRICE")
		return
	end

	if MoneyService:RemoveMoney(Player, Price) then
		SkinInventoryService:AddSkin(Player, SkinID)
		return true
	end
end

function SkinStoreService:Init()
	DataService = self.Services.DataService
	MoneyService = self.Services.MoneyService
	SkinInventoryService = self.Services.SkinInventoryService

	for _, Skin in SkinsModule do
		if Skin.Rarity and Skin.Weapon ~= "Gloves" and Skin.Weapon ~= "Knife" and Skin.Rarity ~= "Holy" then
			table.insert(AvailableSkins, Skin)
		end
	end

	local Packet = self.Libs.Packet

	SkinStoreUpdatedPacket = Packet("SkinStoreUpdated", Packet.Any)

	Packet("GetSkinStore", Packet.Any)
		:Response(Packet.Any)
		.OnServerInvoke = function()
			return self:GetStore()
		end

	Packet("BuySkin", Packet.Any)
		:Response(Packet.Any)
		.OnServerInvoke = function(Player:Player, SkinID)
			return SkinStoreService:BuySkin(Player, SkinID)
		end
end

function SkinStoreService:Start()
	self:GenerateSeedFromDay()

	while true do
		task.wait(1)

		local Date = os.date("*t")
		local DayCode = Date.year * 10000 + Date.month * 100 + Date.day

		if DayCode ~= CurrentDay or #DailySkins == 0 then
			self:GenerateSeedFromDay()
			self:GenerateStore()
		end
	end
end

return SkinStoreService
