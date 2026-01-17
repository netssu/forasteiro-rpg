local BuyablesController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local lighting = game:GetService("Lighting")
local UIController = require(script.Parent.UIController)
local PongItemsConfig = require(ReplicatedStorage.Arrays.PongItemsConfig)
local Essentials = require(ReplicatedStorage.KiwiBird.Essentials)

local plr = Players.LocalPlayer

local BuyablesServiceEvent = ReplicatedStorage.Remotes.Events.BuyablesService

function BuyablesController.ChangeLook()
	local GetDataRemote = game.ReplicatedStorage.Remotes.Functions.GetData
	local playerData = nil

	while not playerData do
		playerData = GetDataRemote:InvokeServer()

		task.wait()
	end

	for _, v in workspace.Buyables.Cups:GetDescendants() do
		if v:IsA("BillboardGui") and v.Name == "OwnedText" then
			if table.find(playerData["CupsInventory"], v.Parent.Name) then

				if v.Parent.Name == playerData["EquippedCups"] then
					v.TextLabel.Text = "Unequip"
				else
					v.TextLabel.Text = "Equip"
				end
			end
		elseif v:IsA("ProximityPrompt") then
			local parent = v.Parent.Parent

			if table.find(playerData["CupsInventory"], parent.Name) then
				if parent.Name == playerData["EquippedCups"] then
					v.ActionText = "Unequip"
				else
					v.ActionText = "Equip"
				end
			end
		end
	end

	for _, v in workspace.Buyables.Balls:GetDescendants() do
		if v:IsA("BillboardGui") and v.Name == "OwnedText" then
			if table.find(playerData["BallsInventory"], v.Parent.Name) then
				if v.Parent.Name == playerData["EquippedBalls"] then
					v.TextLabel.Text = "Unequip"
				else
					v.TextLabel.Text = "Equip"
				end
			end
		elseif v:IsA("ProximityPrompt") then
			local parent = v.Parent.Parent

			if table.find(playerData["BallsInventory"], parent.Name) then
				if parent.Name == playerData["EquippedBalls"] then
					v.ActionText = "Unequip"
				else
					v.ActionText = "Equip"
				end
			end
		end
	end
end

function BuyablesController.Buy(itemname, itemtype)
	if plr.leaderstats.Coins.Value >= PongItemsConfig[itemname].Price then
		print("?")
		BuyablesServiceEvent:FireServer({ ["Action"] = "Buy", ["ItemName"] = itemname, ["ItemType"] = itemtype })
		Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.buy, workspace, 1)
		task.delay(0.05, function()
			BuyablesController.ChangeLook()
		end)
	else
		if PongItemsConfig[itemname].ProductID then
			game:GetService("MarketplaceService"):PromptProductPurchase(plr, PongItemsConfig[itemname].ProductID)
		end
		Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.Deny, workspace, 1)
	end
end

function BuyablesController.Unequip(itemname, itemtype)
	BuyablesServiceEvent:FireServer({ ["Action"] = "Unequip", ["ItemName"] = itemname, ["ItemType"] = itemtype })

	Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.equip, workspace, 1)
	task.delay(0.05, function()
		BuyablesController.ChangeLook()
	end)
end

function BuyablesController.Equip(itemname, itemtype)
	BuyablesServiceEvent:FireServer({ ["Action"] = "Equip", ["ItemName"] = itemname, ["ItemType"] = itemtype })
	Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.equip, workspace, 1)
	task.delay(0.05, function()
		BuyablesController.ChangeLook()
	end)
end

function BuyablesController.Handler()
	task.spawn(function()
		while task.wait(3) do
			BuyablesController.ChangeLook()
		end
	end)
end

return BuyablesController
