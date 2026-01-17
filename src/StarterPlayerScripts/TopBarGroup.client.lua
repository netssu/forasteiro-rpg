local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GroupService = game:GetService("GroupService")
local SocialService = game:GetService("SocialService")
local Marketplace = game:GetService("MarketplaceService")
local UIController = require(ReplicatedStorage.Controllers.UIController)
local Icon = require(ReplicatedStorage.Icon)

local localPlayer = Players.LocalPlayer

if localPlayer:GetAttribute("GroupIconCreated") then
	print("Group icon already created, skipping")
	return
end

localPlayer:SetAttribute("GroupIconCreated", true)

print("Creating group icon")

local GroupIcon: any = Icon.new()
	:setName("Group")
	:setImageScale(1)
	:setLabel("Join Group")
	:setOrder(1)
	:align("Right")

GroupIcon.toggled:Connect(function(): ()
	GroupIcon:deselect()
	GroupService:PromptJoinAsync(594990245)
end)

local inviteFriends: any = Icon.new()
	:setName("Invite Friends")
	:setImageScale(1)
	:setLabel("Invite Friends")
	:setOrder(2)

inviteFriends.toggled:Connect(function(): ()
	local success, result = pcall(function()
		return SocialService:PromptGameInvite(localPlayer)
	end)

	if not success then
		warn(`Couldn't open friends invite menu: {result}`)
		UIController.showNotification("Couldn't open friends invite menu. Try again later.")
	end
end)

local Jumpscare: any = Icon.new()
	:setName("Jumpscare All")
	:setImageScale(1)
	:setLabel("Jumpscare All")
	:setOrder(2)
	:align("Right")

Jumpscare.toggled:Connect(function(): ()
	Jumpscare:deselect()
	Marketplace:PromptProductPurchase(localPlayer, 3488137050)
end)
