local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GamepassService = {}
local DataService
local SkinCrateService

local DevProducts = {
	[3489920592] = function(Player: Player)
		SkinCrateService:OpenCrate(Player)
	end,
	[3489920845] = function(Player: Player)
		SkinCrateService:OpenCrate(Player)
	end,
}

local NamesToId = {}

local DevProductsIds = {
	["Cherry Case"] = 3489920592,
	["Vip Case"] = 3489920845,
	["5x Cherry Case"] = 3513266230,
	["5x Vip Case"] = 3513266536,

}
local GamepassIds = {
-- o id aq
	["V.I.P Player"] = 1671200970,
}

local DevProductVariant = {
	
}

function GamepassService:GetGamepassName(Id: number)
	for Name, FetchedId in GamepassIds do
		if FetchedId == Id then
			return Name
		end
	end

	for Name, FetchedId in DevProductVariant do
		if FetchedId == Id then
			return Name
		end
	end
end

function GamepassService:GetProductName(Id: number)
	for Name, FetchedId in DevProductsIds do
		if FetchedId == Id then
			return Name
		end
	end

	for Name, FetchedId in DevProductVariant do
		if FetchedId == Id then
			return Name
		end
	end
end


function GamepassService:GetRealId(GiftName: number)
	for Name, Id in NamesToId do
		if Name == GiftName then
			return Id
		end
	end
end


function GamepassService:GrantProduct(Player: Player, DevproductId: number, whoGifted: Player)
	if DevProducts[DevproductId] then
		DevProducts[DevproductId](Player, whoGifted)
	end
end

function GamepassService:HasGamepass(Player: Player, GamepassName: string)
	if RunService:IsStudio() then
		return true
	end

	local PlayerData = DataService:GetData(Player)
	if not PlayerData.Gamepass then
		PlayerData.Gamepass = {}
	end
	if not PlayerData.Gamepass[GamepassName] then
		PlayerData.Gamepass[GamepassName] =
			MarketplaceService:UserOwnsGamePassAsync(Player.UserId, NamesToId[GamepassName])
	end

	return PlayerData.Gamepass[GamepassName] == true
end

local Validation = {
	[3475203519] = function(Player: Player)
		local PlayerData = DataService:GetData(Player)
		print(PlayerData)
		if not PlayerData then
			return false
		end

		return true
	end,
}

function GamepassService:BuyGamepass(Player: Player, GamepassName: string)
	local Id = NamesToId[GamepassName]

	if not Id then
		print("no id")
		return
	end
	
	local Validation = Validation[Id]
	if Validation then
		if not Validation(Player) then
			print("false")
			return
		end
	end

	local isProduct = DevProductsIds[GamepassName] ~= nil
	local isPass = GamepassIds[GamepassName] ~= nil

	if not Id then
		warn("Error getting id: ", GamepassName)
		return
	end

	if isProduct then
		MarketplaceService:PromptProductPurchase(Player, Id)
	elseif isPass then
		MarketplaceService:PromptGamePassPurchase(Player, Id)
	end
end

function GamepassService:Init()
	DataService = self.Services.DataService
	SkinCrateService = self.Services.SkinCrateService
	for Name, Id in DevProductsIds do
		NamesToId[Name] = Id
	end
	for Name, Id in GamepassIds do
		NamesToId[Name] = Id
	end
	

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Instance, gamePassId: number, wasPurchased: boolean)
		if wasPurchased then
			local productName = GamepassService:GetGamepassName(gamePassId)

			GamepassService:GrantProduct(player, gamePassId)

			local success, productInfo = pcall(function()
				return MarketplaceService:GetProductInfo(gamePassId, Enum.InfoType.GamePass)
			end)
		end
	end)
	
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, gamePassId: number, wasPurchased: boolean)
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return
		end
		if not wasPurchased then
			SkinCrateService:CancelCrate(player)
		end
	end)
	
end

return GamepassService
