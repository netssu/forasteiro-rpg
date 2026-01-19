local MoneyService = {}

local DataService


local MoneyName = "Ether"

local MoneyUpdatedPacket

function MoneyService:AddMoney(Player: Player, Amount: number): number
	local Data = DataService:GetData(Player)
	Data[MoneyName] += Amount
	
	MoneyUpdatedPacket:FireClient(Player, Data[MoneyName])
	return Data[MoneyName]
end

function MoneyService:GetMoney(Player: Player): number
	local Data = DataService:GetData(Player)
	return Data[MoneyName]
end

function MoneyService:HaveMoney(Player: Player, Amount: number): boolean
	local Data = DataService:GetData(Player)
	
	return Data[MoneyName] >= Amount
end

function MoneyService:RemoveMoney(Player: Player, Amount: number): boolean
	local Data = DataService:GetData(Player)
	if MoneyService:HaveMoney(Player, Amount) then
		Data[MoneyName] -= Amount
		
		MoneyUpdatedPacket:FireClient(Player, Data[MoneyName])
		return true
	end
	
	return false
end

function MoneyService:Init()
	DataService = self.Services.DataService
	
	local Packet = self.Libs.Packet
	MoneyUpdatedPacket = Packet("MoneyUpdated", Packet.Any)
	
	Packet("GetMoney", Packet.Any):Response(Packet.Any).OnServerInvoke = function(Player: Player)
		return MoneyService:GetMoney(Player)
	end

end

return MoneyService