local ChristmasEventTable = {
	[1] = {
		Desc = "Win 3 Games";
		RewardName = "1,500 Coins";
		RewardIcon = "rbxassetid://132642313963842";

		ProductID = 3487668361;

		AmountRequired = 3;
		Type = "Wins";

		Function = function(plr: Player, bought)
			local PlayerDataService = require(game:GetService("ServerScriptService").Services.PlayerDataService)
			local Data = PlayerDataService.GetDataRemote(plr)

			if Data.ChristmasWins >= 3 or bought then
				plr.leaderstats.Coins.Value += 1500
				PlayerDataService.SetData(plr, "ChristmasTasks", {true, Data.ChristmasTasks[2], Data.ChristmasTasks[3], Data.ChristmasTasks[4]})
				game:GetService("ReplicatedStorage").Remotes.Events.ChristmasQuest:FireClient(plr, "Load")
			else
				return
			end
		end,
	};
	
	[2] = {
		Desc = "Win 5 Games";
		RewardName = "Christmas Cup";
		RewardIcon = "rbxassetid://81147269997575";
		
		ProductID = 3488057112;
		
		AmountRequired = 5;
		Type = "Wins";
		
		Function = function(plr: Player, bought)
			local PlayerDataService = require(game:GetService("ServerScriptService").Services.PlayerDataService)
			local Data = PlayerDataService.GetDataRemote(plr)
			
			if Data.ChristmasWins >= 5 or bought then
				PlayerDataService.AddToTable(plr, "CupsInventory", "Christmas Cup")
				PlayerDataService.SetData(plr, "ChristmasTasks", {Data.ChristmasTasks[1], true, Data.ChristmasTasks[3], Data.ChristmasTasks[4]})
				game:GetService("ReplicatedStorage").Remotes.Events.ChristmasQuest:FireClient(plr, "Load")
			else
				return
			end
		end,
	};
	
	[3] = {
		Desc = "Win 7 Games";
		RewardName = "3,500 Coins";
		RewardIcon = "rbxassetid://132642313963842";

		ProductID = 3488057239;

		AmountRequired = 7;
		Type = "Wins";

		Function = function(plr: Player, bought)
			local PlayerDataService = require(game:GetService("ServerScriptService").Services.PlayerDataService)
			local Data = PlayerDataService.GetDataRemote(plr)

			if Data.ChristmasWins >= 7 or bought then
				plr.leaderstats.Coins.Value += 3500
				PlayerDataService.SetData(plr, "ChristmasTasks", {Data.ChristmasTasks[1], Data.ChristmasTasks[2], true, Data.ChristmasTasks[4]})
				game:GetService("ReplicatedStorage").Remotes.Events.ChristmasQuest:FireClient(plr, "Load")
			else
				return
			end
		end,
	};
	
	[4] = {
		Desc = "Win 10 Games";
		RewardName = "Christmas Ball";
		RewardIcon = "rbxassetid://101901701782667";

		ProductID = 3488057397;

		AmountRequired = 10;
		Type = "Wins";

		Function = function(plr: Player, bought)
			local PlayerDataService = require(game:GetService("ServerScriptService").Services.PlayerDataService)
			local Data = PlayerDataService.GetDataRemote(plr)

			if Data.ChristmasWins >= 10 or bought then
				PlayerDataService.AddToTable(plr, "BallsInventory", "Christmas Ball")
				PlayerDataService.SetData(plr, "ChristmasTasks", {Data.ChristmasTasks[1], Data.ChristmasTasks[2], Data.ChristmasTasks[3], true})
				game:GetService("ReplicatedStorage").Remotes.Events.ChristmasQuest:FireClient(plr, "Load")
			else
				return
			end
		end,
	};
}

return ChristmasEventTable
