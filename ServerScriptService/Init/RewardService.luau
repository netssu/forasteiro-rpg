local RewardService = {}

-- services

local Players = game:GetService("Players")

local RoundService
local DataService
local GamepassService
local MoneyService

local RewardPacket

-- tables

local killAmount = 100
local NPCAmount = 50

local rewards = {
	{
		Name = "MVPReward",
		Ether = 1000,
		Text = "MVP Reward: $",
	},
	{
		Name = "SecondPlaceReward",
		Ether = 500,
		Text = "#2 Place Reward: $",
	},
	{
		Name = "ThirdPlaceReward",
		Ether = 250,
		Text = "#3 Place Reward: $",
	},
}

local rewardingPlayers = {}


-- gets reward data
function RewardService:GetRewardByName(rewardName)
	for _, data in pairs(rewards) do
		if data.Name == rewardName then
			return data
		end
	end
end


-- rewards a kill based on it being a player or an NPC
function RewardService:RewardKill(player:Player, isNPC:boolean)
	local amount = isNPC and NPCAmount or killAmount
	amount = RewardService:AdjustAmount(player,amount)
	
	return MoneyService:AddMoney(player,amount) and amount
end


-- rewards a player with one of the existing rewards
function RewardService:RewardPlayer(player:Player, rewardName:string)
	
	local reward = RewardService:GetRewardByName(rewardName)
	if not reward then
		return
	end
	
	if not rewardingPlayers[player] then
		rewardingPlayers[player] = {}
	end
	
	table.insert(rewardingPlayers[player],rewardName)
	
	RewardPacket:FireClient(player,reward.Name,reward.Ether, reward.Text)
end


-- claims an existing reward
function RewardService:ClaimReward(player:Player, rewardName:string)
	local currentRewards = rewardingPlayers[player]
	if not currentRewards then
		return
	end
	
	local index = table.find(currentRewards,rewardName)
	if not index then
		return
	end
	
	table.remove(currentRewards,index)
	
	local reward = RewardService:GetRewardByName(rewardName)
	if not reward then
		return
	end
	
	local amount = RewardService:AdjustAmount(player,reward.Ether)
	return MoneyService:AddMoney(player,amount) and true
end


-- adjusts the passed amount to how much the player should be rewarded based on stuff like gamepasses
function RewardService:AdjustAmount(player:Player, amount:number)
	local hasGamepass = GamepassService:HasGamepass(player, "V.I.P Player")
	
	if hasGamepass then
		local additional = math.round(amount*1.5)
		amount = amount + additional
	end
	
	print(amount,hasGamepass)
	
	return amount
end



function RewardService:Init()
	local Packet = self.Libs.Packet
	
	RewardPacket = Packet("RewardPacket", Packet.String, Packet.NumberU32, Packet.String):Response(Packet.Any)
	
	RewardPacket.OnServerInvoke = function(player:Player, rewardName:string)
		return RewardService:ClaimReward(player,rewardName)
	end
	
end



function RewardService:Start()
	RoundService = self.Services.RoundService
	DataService = self.Services.DataService
	GamepassService = self.Services.GamepassService
	MoneyService = self.Services.MoneyService
	
end



return RewardService
