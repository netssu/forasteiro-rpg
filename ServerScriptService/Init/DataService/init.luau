local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local STUDIO_DATA_STORE_KEY = "STUDIO 1"
local LIVE_DATA_STORE_KEY = "PRODUCTION"
local DataStoreKey = if RunService:IsStudio() then STUDIO_DATA_STORE_KEY else LIVE_DATA_STORE_KEY

local ProfileStore
local PROFILE_TEMPLATE = require(script.ProfileTemplate)

local PlayerStore

local Profiles: { [Player]: typeof(PlayerStore:StartSessionAsync()) } = {}

local DataService = {}

local GamepassService


function DataService:GetData(Player: Player)
	if not Profiles[Player] then
		return nil
	end
	return Profiles[Player].Data
end

function DataService:IsDataLoaded(Player: Player)
	return Profiles[Player] ~= nil
end

local function processReceipt(receipt_info)
	local userId = receipt_info.PlayerId

	local player = Players:GetPlayerByUserId(userId)
	if player then
		GamepassService:GrantProduct(player, receipt_info.ProductId)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function DataService:LoadData(player)
	local profile = PlayerStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile ~= nil then
		profile:AddUserId(player.UserId) -- GDPR compliance
		profile:Reconcile() -- Fill in missing variables from PROFILE_TEMPLATE (optional)

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			player:Kick(`Profile session end - Please rejoin`)
		end)

		if player.Parent == Players then
			Profiles[player] = profile
			player:SetAttribute("DataLoaded", true)
			print(`Profile loaded for {player.DisplayName}!`, profile.Data)
		else
			profile:EndSession()
		end
	else
		player:Kick(`Profile load fail - Please rejoin`)
	end
	
end




function DataService:SaveData(Player: Player)
	local profile = Profiles[Player]
	if profile ~= nil then
		profile:EndSession()
	end
end

function DataService:Init()
	ProfileStore = DataService.Libs.ProfileStore
	PlayerStore = ProfileStore.New(DataStoreKey, PROFILE_TEMPLATE)
	MarketplaceService.ProcessReceipt = processReceipt
	GamepassService = self.Services.GamepassService
end

return DataService
