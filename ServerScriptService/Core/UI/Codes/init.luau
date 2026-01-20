local CodesModule = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = ServerScriptService.Core

local CurrencyManager = require(Core.Player.CurrencyManager)
local CodesHandlers = require(script.CodesHandlers)
local PlayerData = require(Core.Data.PlayerData)

local remoteEvent = ReplicatedStorage.Remotes.Events

remoteEvent.UseCode.OnServerEvent:Connect(function(player: Player, code: string)
	CodesModule.useCode(player, code)
end)

function CodesModule.getCode(codeName: string): CodesHandlers.CodeConfig
	local code = CodesHandlers[codeName]
	if not code then warn(`[Codes] code: {codeName} doesnt exist!`) return end
	
	return code
end

function CodesModule.giveCodeRewards(player: Player, codeName: string)
	local code = CodesModule.getCode(codeName)
	if not code then return end
	
	for _, rewardData in code.Rewards do
		if rewardData.type == "Plutonium" or rewardData.type == "Cash" then
			CurrencyManager.adjust(player, rewardData.type, rewardData.value)
		end
	end
end

function CodesModule.useCode(player: Player, codeName: string)
	local code = CodesModule.getCode(codeName)
	if not code then return end
	
	local profile = PlayerData.GetData(player)
	if not profile then return end
	if table.find(profile.CodesUsed, codeName) then warn(`[Codes] code: {codeName} already used!`) return end

	local canStore = not code.OnUse and true or code.OnUse()
	if not canStore then return end
	
	CodesModule.giveCodeRewards(player, codeName)
	
	table.insert(profile.CodesUsed, codeName)
end

return CodesModule
