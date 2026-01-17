local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)

local remote = ReplicatedStorage.Remotes.Events.LikeReward

local LikeRewardService = {}

local function get(url)
	return game.HttpService:GetAsync(url)
end
local function userFollowsUser(userId, targetId)
	local url = "https://friends.roproxy.com/v1/users/%d/followings?limit=100"
	local cursor = ""
	while cursor do
		local response = get(url:format(userId) .. "&cursor=" .. cursor)
		local data = game.HttpService:JSONDecode(response)
		for _, user in pairs(data.data) do
			if user.id == tonumber(targetId) then
				return true
			end
		end
		cursor = data.nextPageCursor
	end
	return false
end

local likeRewardDBs = {}
function LikeRewardService.Listener()
	remote.OnServerEvent:Connect(function(plr, event)
		if not likeRewardDBs[plr.Name] then
			likeRewardDBs[plr.Name] = true
			delay(0.1, function()
				likeRewardDBs[plr.Name] = nil
			end)
		else
			return
		end

		local playerData = PlayerDataService.GetDataRemote(plr)
		if not playerData then
			return
		end

		if event == "Visible" then
			if not playerData.LikeRewardVisible then
				PlayerDataService.SetData(plr, "LikeRewardVisible", true)
			end
		elseif event == "Tabbed" then
			if playerData.LikeRewardVisible and not playerData.CanClaimLikeReward then
				PlayerDataService.SetData(plr, "CanClaimLikeReward", true)
			end
		elseif event == "Claim" then
			if playerData.ClaimedLikeReward then
				return
			end
			if not playerData.CanClaimLikeReward then
				remote:FireClient(plr, true, false)
				return
			end

			PlayerDataService.SetData(plr, "ClaimedLikeReward", true)

			plr.leaderstats.Coins.Value += 500

			remote:FireClient(plr, true, true)
			remote:FireClient(plr, "notif", "+500 Coins")
		end
	end)
end

function LikeRewardService.Handler()
	LikeRewardService.Listener()
end

return LikeRewardService
