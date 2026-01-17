local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Essentials = require(ReplicatedStorage.KiwiBird.Essentials)
local PongServiceEvent = ReplicatedStorage.Remotes.Events.PongService

local MonetizationTable = {
	-- Cash Purchases
	["3459363159"] = function(plr)
		plr.leaderstats.Coins.Value += 100
	end,
	["3459363160"] = function(plr)
		plr.leaderstats.Coins.Value += 500
	end,

	["3459363157"] = function(plr)
		plr.leaderstats.Coins.Value += 1000
	end,

	["3459363158"] = function(plr)
		plr.leaderstats.Coins.Value += 2500
	end,

	["3459363154"] = function(plr)
		plr.leaderstats.Coins.Value += 5000
	end,
	
	["3457958846"] = function(plr, plrdataservice)
		if not plr.PlayerStats.Vip.Value then
			plrdataservice.AddToTable(plr, "CupsInventory", "Diamond Mug")
			plrdataservice.AddToTable(plr, "BallsInventory", "Diamond Ball")
		end
		
		plr.PlayerStats.Vip.Value = true

		if plr.PlayerStats.Vip.Value then
			local billboard = ReplicatedStorage.Assets.VFX.VIPBanner:Clone()

			billboard.Parent = plr.Character.Head
		end
	end,

	["3458728466"] = function(plr)
		plr.PlayerStats.MoneyUpgradeMultiplier.Value += 1
	end,

	["3463557320"] = function(plr)
		plr.PlayerStats.MoneyUpgradeMultiplier.Value += 1
	end,

	["3463557319"] = function(plr)
		plr.PlayerStats.MoneyUpgradeMultiplier.Value += 1
	end,

	["3463557316"] = function(plr)
		plr.PlayerStats.MoneyUpgradeMultiplier.Value += 1
	end,

	["3459557641"] = function(plr)
		plr.leaderstats.Streak.Value = plr.PlayerStats.PastStreak.Value
		if plr:WaitForChild("leaderstats").Streak and plr:WaitForChild("leaderstats").Streak.Value >= 1 then
			if plr.Character.Head:FindFirstChild("Streak") then
				local billboard = plr.Character.Head.Streak
				billboard.TextLabel.Text = plr.leaderstats.Streak.Value
			else
				local billboard = ReplicatedStorage.Assets.VFX.Streak:Clone()

				billboard.Parent = plr.Character.Head

				billboard.TextLabel.Text = plr.leaderstats.Streak.Value
			end
		end
	end,

	["3459557640"] = function(plr)
		plr.leaderstats.Coins.Value += plr.PlayerStats.EarnedMoney.Value
	end,

	["3459672778"] = function(plr, plrdataservice)
		plr.PlayerStats.StarterPack.Value = true
		plr.leaderstats.Coins.Value += 1000
		plrdataservice.AddToTable(plr, "CupsInventory", "Cup")

		plrdataservice.AddToTable(plr, "BallsInventory", "Football")
	end,
	
	["3488153417"] = function(plr, plrdataservice)
		ReplicatedStorage.Remotes.Events.GoldMug:FireClient(plr)
		plr.PlayerStats.GoldenMug.Value = true
		plrdataservice.AddToTable(plr, "CupsInventory", "Golden Mug")
		ReplicatedStorage.Remotes.Events.Notification:FireClient(plr, "Thank you for your purchase 💖")
	end,
	
	["3460837189"] = function(plr, plrdataservice)
		plrdataservice.AddToTable(plr, "CupsInventory", "Blue Solo")
		ReplicatedStorage.Remotes.Events.Notification:FireClient(plr, "Thank you for your purchase 💖")
	end,
	
	["3460837193"] = function(plr, plrdataservice)
		plrdataservice.AddToTable(plr, "CupsInventory", "Glass Cup")
		ReplicatedStorage.Remotes.Events.Notification:FireClient(plr, "Thank you for your purchase 💖")
	end,
	
	["3460837191"] = function(plr, plrdataservice)
		plrdataservice.AddToTable(plr, "CupsInventory", "Mug")
		ReplicatedStorage.Remotes.Events.Notification:FireClient(plr, "Thank you for your purchase 💖")
	end,
	
	["3460837190"] = function(plr, plrdataservice)
		plrdataservice.AddToTable(plr, "CupsInventory", "Tip Jar")
		ReplicatedStorage.Remotes.Events.Notification:FireClient(plr, "Thank you for your purchase 💖")
	end,
	
	["3460837188"] = function(plr, plrdataservice)
		plrdataservice.AddToTable(plr, "CupsInventory", "Bucket")
		ReplicatedStorage.Remotes.Events.Notification:FireClient(plr, "Thank you for your purchase 💖")
	end,
	
	["3460837186"] = function(plr, plrdataservice)
		plrdataservice.AddToTable(plr, "CupsInventory", "Shiny Cup")
		ReplicatedStorage.Remotes.Events.Notification:FireClient(plr, "Thank you for your purchase 💖")
	end,
	
	["3460839263"] = function(plr, plrdataservice)
		plrdataservice.AddToTable(plr, "BallsInventory", "Billiards")
		ReplicatedStorage.Remotes.Events.Notification:FireClient(plr, "Thank you for your purchase 💖")
	end,
	
	["3460839261"] = function(plr, plrdataservice)
		plrdataservice.AddToTable(plr, "BallsInventory", "Baseball")
		ReplicatedStorage.Remotes.Events.Notification:FireClient(plr, "Thank you for your purchase 💖")
	end,
	
	["3460839264"] = function(plr, plrdataservice)
		plrdataservice.AddToTable(plr, "BallsInventory", "Basketball")
		ReplicatedStorage.Remotes.Events.Notification:FireClient(plr, "Thank you for your purchase 💖")
	end,
	
	["3460839265"] = function(plr, plrdataservice)
		plrdataservice.AddToTable(plr, "BallsInventory", "Football")
		ReplicatedStorage.Remotes.Events.Notification:FireClient(plr, "Thank you for your purchase 💖")
	end,
	
	["3460839262"] = function(plr, plrdataservice)
		plrdataservice.AddToTable(plr, "BallsInventory", "DeathStar")
		ReplicatedStorage.Remotes.Events.Notification:FireClient(plr, "Thank you for your purchase 💖")
	end,
	
	["3460839260"] = function(plr, plrdataservice)
		plrdataservice.AddToTable(plr, "BallsInventory", "Golden Snitch")
		ReplicatedStorage.Remotes.Events.Notification:FireClient(plr, "Thank you for your purchase 💖")
	end,
	
	["3488137050"] = function(plr, plrdataservice)
		ReplicatedStorage.Remotes.Events.Jumpscare:FireAllClients()
		ReplicatedStorage.Remotes.Events.Notification:FireClient(plr, "Thank you for your purchase 💖")
	end,
	
	["3482910359"] = function(plr, plrdataservice)
		plr.PlayerStats.DoubleStreak.Value = true
	end,

	["3486701443"] = function(plr)
		plr.PlayerStats.DoubleWins.Value = true 
	end,
	
	["3487668361"] = function(plr, plrdataservice)
		local ChristmasEventData = require(ReplicatedStorage.Arrays.ChristmasEventTable)
		ChristmasEventData[1].Function(plr, true)
	end,
	
	["3488057112"] = function(plr, plrdataservice)
		local ChristmasEventData = require(ReplicatedStorage.Arrays.ChristmasEventTable)
		ChristmasEventData[2].Function(plr, true)
	end,
	
	["3488057239"] = function(plr, plrdataservice)
		local ChristmasEventData = require(ReplicatedStorage.Arrays.ChristmasEventTable)
		ChristmasEventData[3].Function(plr, true)
	end,
	
	["3488057397"] = function(plr, plrdataservice)
		local ChristmasEventData = require(ReplicatedStorage.Arrays.ChristmasEventTable)
		ChristmasEventData[4].Function(plr, true)
	end,

	["3466651970"] = function(plr)
		local Table = nil
		local target

		print("??1")

		for _, v in workspace.QueueTables:GetChildren() do
			local podium1 = v:FindFirstChild("1")
			local podium2 = v:FindFirstChild("2")

			if podium1:GetAttribute("taken") == plr.Name then
				Table = v
				target = Table.Main["1"]
			elseif podium2:GetAttribute("taken") == plr.Name then
				Table = v
				target = Table.Main["2"]
			end
		end

		print("??2")

		local clone = ReplicatedStorage.Assets.Models.Cups:FindFirstChild(plr.PlayerStats.EquippedCups.Value):Clone()
		clone.Parent = Table.Main["cups" .. target.Name]

		print(plr.PlayerStats.EquippedCups.Value)

		print(clone.Parent)

		local attachment

		for _, v in target:GetChildren() do
			print(Table.Main["cups" .. target.Name]:FindFirstChild(v.Name))
			print(v)
			if not Table.Main["cups" .. target.Name]:FindFirstChild(v.Name) then
				attachment = v

				break
			end
		end

		clone:PivotTo(attachment.WorldCFrame)
		clone.Name = attachment.Name

		local parent1 = Table["1"].BillboardGui.TextLabel
		local parent2 = Table["2"].BillboardGui.TextLabel
		local parent3 = Table.Main["cups" .. target.Name]

		-- if target.Name == "1" then
		-- elseif target.Name == "2" then
		-- end
	end,

	["3461644699"] = function(plr)
		local Table = nil
		local target

		for _, v in workspace.QueueTables:GetChildren() do
			local podium1 = v:FindFirstChild("1")
			local podium2 = v:FindFirstChild("2")

			if podium1:GetAttribute("taken") == plr.Name then
				Table = v
				target = Players:FindFirstChild(Table:FindFirstChild("2"):GetAttribute("taken"))
			elseif podium2:GetAttribute("taken") == plr.Name then
				Table = v
				target = Players:FindFirstChild(Table:FindFirstChild("1"):GetAttribute("taken"))
			end
		end

		-- Players:FindFirstChild(Table:FindFirstChild("2"):GetAttribute("taken"))

		local inkdecal = ReplicatedStorage.Assets.VFX.ink:Clone()

		inkdecal.Parent = target.Character.Head

		Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.splat, target.Character.HumanoidRootPart)

		PongServiceEvent:FireClient(target, { ["Action"] = "Inked" })

		task.delay(3, function()
			inkdecal:Destroy()
		end)
	end,

	["3463468283"] = function(plr)
		plr.PlayerStats.PotLuckMultiplier.Value += 1
	end,
	
	["3488135968"] = function(plr)
		ReplicatedStorage.Server.LuckBoost.Value = 2
		ReplicatedStorage.Server.LuckBoost:SetAttribute("EndTime", os.time() + 600)
		ReplicatedStorage.Remotes.Events.Notification:FireAllClients("Server Luck Boosted to 2x")
	end,
	
	["3488136128"] = function(plr)
		ReplicatedStorage.Server.LuckBoost.Value = 4
		ReplicatedStorage.Server.LuckBoost:SetAttribute("EndTime", os.time() + 600)
		ReplicatedStorage.Remotes.Events.Notification:FireAllClients("Server Luck Boosted to 4x")
	end,
	
	["3488136272"] = function(plr)
		local Boost = ReplicatedStorage.Server.LuckBoost
		
		if Boost.Value == 8 then
			ReplicatedStorage.Server.LuckBoost:SetAttribute("EndTime", Boost:GetAttribute("EndTime") + 600)
			ReplicatedStorage.Remotes.Events.Notification:FireAllClients("Server Luck 10 mins added on!")
		else
			ReplicatedStorage.Remotes.Events.Notification:FireAllClients("Server Luck Boosted to 8x")
			ReplicatedStorage.Server.LuckBoost.Value = 8
			ReplicatedStorage.Server.LuckBoost:SetAttribute("EndTime", os.time() + 600)
		end
	end,
	

	-- Item Purchases
	-- ["3368181270"] = function(plr, inventoryService) -- NormalBlock
	-- 	inventoryService.AddInventoryItem(plr, "NormalBlock", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
	-- ["3368181275"] = function(plr, inventoryService) -- StarterFuel
	-- 	inventoryService.AddInventoryItem(plr, "StarterFuel", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
	-- ["3368181269"] = function(plr, inventoryService) -- Thruster
	-- 	inventoryService.AddInventoryItem(plr, "Thruster", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
	-- ["3368181267"] = function(plr, inventoryService) -- Wing
	-- 	inventoryService.AddInventoryItem(plr, "Wing", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
	-- ["3368181266"] = function(plr, inventoryService) -- simpleFuel
	-- 	inventoryService.AddInventoryItem(plr, "simpleFuel", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
	-- ["3368181264"] = function(plr, inventoryService) -- GlassBlock
	-- 	inventoryService.AddInventoryItem(plr, "GlassBlock", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
	-- ["3368181256"] = function(plr, inventoryService) -- SteelBlock
	-- 	inventoryService.AddInventoryItem(plr, "SteelBlock", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
	-- ["3368181254"] = function(plr, inventoryService) -- BetterThruster
	-- 	inventoryService.AddInventoryItem(plr, "BetterThruster", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
	-- ["3368181253"] = function(plr, inventoryService) -- BetterWing
	-- 	inventoryService.AddInventoryItem(plr, "BetterWing", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
	-- ["3368181252"] = function(plr, inventoryService) -- CarbonFiberBlock
	-- 	inventoryService.AddInventoryItem(plr, "CarbonFiberBlock", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
	-- ["3368181251"] = function(plr, inventoryService) -- GoodFuel
	-- 	inventoryService.AddInventoryItem(plr, "GoodFuel", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
	-- ["3368181250"] = function(plr, inventoryService) -- GreaterWing
	-- 	inventoryService.AddInventoryItem(plr, "GreaterWing", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
	-- ["3368181249"] = function(plr, inventoryService) -- BestWing
	-- 	inventoryService.AddInventoryItem(plr, "BestWing", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
	-- ["3368181248"] = function(plr, inventoryService) -- BestThruster
	-- 	inventoryService.AddInventoryItem(plr, "BestThruster", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
	-- ["3368191827"] = function(plr, inventoryService) -- bestFuel
	-- 	inventoryService.AddInventoryItem(plr, "bestFuel", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
	-- ["3368388193"] = function(plr, inventoryService) -- bestFuel
	-- 	inventoryService.AddInventoryItem(plr, "bestFuel", true)
	-- 	inventoryService.AddInventoryItem(plr, "BestThruster", true)
	-- 	inventoryService.AddInventoryItem(plr, "BestWing", true)
	-- 	Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.InGameSounds.buy2, plr.Character.HumanoidRootPart)
	-- end,
}

return MonetizationTable
