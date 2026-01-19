local SkinCrateService = {}

local DataService
local GamepassService

local SkinInventoryService
local CrateOpenedPacket

local Crates = require(game.ReplicatedStorage.Resources.Crates)
local Utils = require(game.ReplicatedStorage.Resources.Crates.Utils)

function SkinCrateService:OpenCrate(Player: Player)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData or not PlayerData.OpeningCrate or not PlayerData.OpeningCrates then
		return false
	end

	local LastIndex = #PlayerData.OpeningCrates
	if LastIndex == 0 then
		PlayerData.OpeningCrate = false
		return false
	end

	local CrateID = PlayerData.OpeningCrates[LastIndex]
	table.remove(PlayerData.OpeningCrates, LastIndex)

	PlayerData.OpeningCrate = false

	local SkinID = Utils.GetRandomSkinFromCrate(CrateID)
	SkinInventoryService:AddSkin(Player, SkinID)
	CrateOpenedPacket:FireClient(Player, SkinID, CrateID)
	return SkinID
end

function SkinCrateService:CancelCrate(Player:Player)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData or not PlayerData.OpeningCrate or not PlayerData.OpeningCrates then
		return false
	end

	local LastIndex = #PlayerData.OpeningCrates
	if LastIndex == 0 then
		PlayerData.OpeningCrate = false
		return false
	end

	local CrateID = PlayerData.OpeningCrates[LastIndex]
	table.remove(PlayerData.OpeningCrates, LastIndex)

	PlayerData.OpeningCrate = false
end

function SkinCrateService:Init()
	DataService = self.Services.DataService
	SkinInventoryService = self.Services.SkinInventoryService
	GamepassService = self.Services.GamepassService

	local Packet = self.Libs.Packet

	CrateOpenedPacket = Packet("CrateOpened", Packet.Any, Packet.Any)

	Packet("RequestOpenCrate", Packet.Any).OnServerEvent:Connect(function(Player: Player, CrateID: number)
		local crateData = Utils.GetCrateData(CrateID)
		if not crateData then
			return
		end
		
		local PlayerData = DataService:GetData(Player)
		if not PlayerData then return false end

		if not PlayerData.OpeningCrates then
			PlayerData.OpeningCrates = {}
		end

		if PlayerData.OpeningCrate then
			return false
		end

		PlayerData.OpeningCrate = true

		table.insert(PlayerData.OpeningCrates, CrateID)
		if #PlayerData.OpeningCrates > 50 then
			table.remove(PlayerData.OpeningCrates, 1)
		end

		GamepassService:BuyGamepass(Player, crateData.Name)
	end)
end

function SkinCrateService:Start()

end

return SkinCrateService
