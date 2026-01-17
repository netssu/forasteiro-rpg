local BuyablesService = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local lighting = game:GetService("Lighting")

local PlayerDataService = require(script.Parent.PlayerDataService)
local PongItemsConfig = require(ReplicatedStorage.Arrays.PongItemsConfig)
local BuyablesServiceEvent = ReplicatedStorage.Remotes.Events.BuyablesService

-- Helper function to recalculate total multiplier from scratch
local function RecalculateMultiplier(plr)
	local playerData = PlayerDataService.GetDataRemote(plr)
	local totalMultiplier = 1 -- Base multiplier starts at 1

	-- Add cup multiplier
	if playerData["EquippedCups"] and PongItemsConfig[playerData["EquippedCups"]] then
		totalMultiplier += PongItemsConfig[playerData["EquippedCups"]].Multiplier
	end

	-- Add ball multiplier
	if playerData["EquippedBalls"] and PongItemsConfig[playerData["EquippedBalls"]] then
		totalMultiplier += PongItemsConfig[playerData["EquippedBalls"]].Multiplier
	end

	plr.PlayerStats.Multiplier.Value = totalMultiplier
end

local vfxPlayer = require(game.ReplicatedStorage["A-Packages"].VFXPlayer)

function BuyablesService.Listener()
	BuyablesServiceEvent.OnServerEvent:Connect(function(plr, argtable)
		local tp = nil
		local action = argtable["Action"]
		-- Validate input
		if argtable["Type"] then
			tp = workspace:FindFirstChild(argtable["Type"] .. "TP")
		end

		-- if not argtable or not argtable["ItemName"] or not argtable["ItemType"] or not argtable["Action"] then
		-- 	warn("Invalid argtable received from player:", plr.Name)
		-- 	return
		-- end

		-- local itemname = argtable["ItemName"]
		-- local itemType = argtable["ItemType"] .. "Inventory"
		-- local action = argtable["Action"]

		-- -- Validate item exists in config
		-- if not PongItemsConfig[itemname] then
		-- 	warn("Item not found in config:", itemname)
		-- 	return
		-- end

		-- Handle Buy action
		if action == "Buy" then
			local itemname = argtable["ItemName"]
			local itemType = argtable["ItemType"] .. "Inventory"

			if plr.leaderstats.Coins.Value >= PongItemsConfig[itemname].Price then
				plr.leaderstats.Coins.Value -= PongItemsConfig[itemname].Price
				PlayerDataService.AddToTable(plr, itemType, itemname)
			end
			vfxPlayer.play(plr, script.Buy)

		-- Handle Equip action
		elseif action == "Equip" then
			local itemname = argtable["ItemName"]
			local itemType = argtable["ItemType"] .. "Inventory"
			local playerData = PlayerDataService.GetDataRemote(plr)

			if itemType == "CupsInventory" then
				-- Check if player owns the item
				if table.find(playerData["CupsInventory"], itemname) then
					PlayerDataService.SetData(plr, "EquippedCups", itemname)
					plr.PlayerStats.EquippedCups.Value = itemname
					RecalculateMultiplier(plr)
				end
			elseif itemType == "BallsInventory" then
				-- Check if player owns the item
				if table.find(playerData["BallsInventory"], itemname) then
					PlayerDataService.SetData(plr, "EquippedBalls", itemname)
					plr.PlayerStats.EquippedBalls.Value = itemname
					RecalculateMultiplier(plr)
				end
			end

		-- Handle Unequip action
		elseif action == "Unequip" then
			local itemname = argtable["ItemName"]
			local itemType = argtable["ItemType"] .. "Inventory"
			if itemType == "CupsInventory" then
				PlayerDataService.SetData(plr, "EquippedCups", "Default")
				plr.PlayerStats.EquippedCups.Value = "Default"
			elseif itemType == "BallsInventory" then
				PlayerDataService.SetData(plr, "EquippedBalls", "Default")
				plr.PlayerStats.EquippedBalls.Value = "Default"
			end
			RecalculateMultiplier(plr)
		elseif action == "Teleport" then
			if plr.Character.InGame.Value == false then
				plr.Character.HumanoidRootPart.CFrame = tp.CFrame
			end
		end
	end)
end

function BuyablesService.Handler()
	BuyablesService.Listener()
end

return BuyablesService
