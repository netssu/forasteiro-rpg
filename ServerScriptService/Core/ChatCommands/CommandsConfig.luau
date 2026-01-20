local ServerScriptService = game:GetService("ServerScriptService")
local TycoonManager = require(ServerScriptService.Core.Tycoon.TycoonManager)
local PlayerManager = require(ServerScriptService.Core.Player.PlayerManager)

local CommandsConfig = {}

CommandsConfig = {
	--// Economy //--
	{
		name = "givecash",
		aliases = {"cash", "money"},
		description = "Give player cash",
		usage = "/givecash [amount]",
		handler = function(player: Player, amount: string)
			amount = tonumber(amount) or 10000
			local cash = player:FindFirstChild("rawCash")
			if cash then
				cash.Value += amount
				print(`Gave {player.Name} ${amount}`)
			end
		end
	},

	{
		name = "giveplut",
		aliases = {"plut", "plutonium"},
		description = "Give player plutonium",
		usage = "/giveplut [amount]",
		handler = function(player: Player, amount: string)
			amount = tonumber(amount) or 100
			local plut = player:FindFirstChild("rawPlutonium")
			if plut then
				plut.Value += amount
				print(`Gave {player.Name} {amount} Plutonium`)
			end
		end
	},

	--// Tycoon //--
	{
		name = "addbrainrot",
		aliases = {"addbr"},
		description = "Add brainrots to cage",
		usage = "/addbrainrot [name] [count]",
		handler = function(player: Player, brainrotName: string, count: string)
			count = tonumber(count) or 5
			local brainrots = {[brainrotName] = count}
			TycoonManager.addBrainrotsToCage(player, brainrots)
			print(`Added {count}x {brainrotName} to {player.Name}'s cage`)
		end
	},

	{
		name = "unlocktank",
		aliases = {},
		description = "Unlock a tank",
		usage = "/unlocktank [tankname]",
		handler = function(player: Player, tankName: string)
			local success = TycoonManager.unlockTank(player, tankName)
			print(`Unlock {tankName} for {player.Name}: {success}`)
		end
	},

	{
		name = "upgradetank",
		aliases = {},
		description = "Upgrade a tank",
		usage = "/upgradetank [tankname]",
		handler = function(player: Player, tankName: string)
			local success = TycoonManager.upgradeTank(player, tankName)
			print(`Upgrade {tankName} for {player.Name}: {success}`)
		end
	},

	{
		name = "tankinfo",
		aliases = {},
		description = "Get tank information",
		usage = "/tankinfo [tankname]",
		handler = function(player: Player, tankName: string)
			local base = TycoonManager.getBase(player)
			if not base then
				print("Player has no base")
				return
			end

			local tankData = base.Tank.Tanks[tankName]
			if not tankData then
				print("Tank not found:", tankName)
				return
			end

			print("=== TANK INFO ===")
			print("Name:", tankData.Name)
			print("Unlocked:", tankData.Unlocked)
			print("Level:", tankData.Level)
			print("Brainrot:", tankData.Brainrot or "None")
			print("Brainrot Count:", tankData.BrainrotCount)
			print("Uses Remaining:", tankData.UsesRemaining)
			print("Producing:", tankData.ProducingItem)
		end
	},

	{
		name = "baseinfo",
		aliases = {"base"},
		description = "Get base information",
		usage = "/baseinfo",
		handler = function(player: Player)
			local base = TycoonManager.getBase(player)
			if not base then
				print("Player has no base")
				return
			end

			print("=== BASE INFO ===")
			print("Base ID:", base.ID)
			print("Owner:", base.Owner and base.Owner.Name or "None")
			print("Items in Storage:", #base.Storage)
			print("Active Customers:", #base.Customers)

			print("\n=== CAGE ===")
			for brainrotName, count in pairs(base.Cage) do
				print(brainrotName, ":", count)
			end

			print("\n=== TANKS ===")
			for tankName, tankData in pairs(base.Tank.Tanks) do
				if tankData.Unlocked then
					print(tankName, "- Level", tankData.Level, "-", tankData.Brainrot or "Empty", "(" .. tankData.BrainrotCount .. ")")
				end
			end
		end
	},

	--// Tools //--
	{
		name = "unlocktool",
		aliases = {},
		description = "Unlock a tool",
		usage = "/unlocktool [toolname]",
		handler = function(player: Player, toolName: string)
			local playerObject = PlayerManager.getPlayerObject(player)
			if not playerObject then
				print("No PlayerObject found")
				return
			end

			local success = playerObject.ToolManager:unlockTool(toolName)
			print(`Unlock {toolName} for {player.Name}: {success}`)
		end
	},

	{
		name = "upgradetool",
		aliases = {},
		description = "Upgrade a tool stat",
		usage = "/upgradetool [toolname] [statname]",
		handler = function(player: Player, toolName: string, statName: string)
			local playerObject = PlayerManager.getPlayerObject(player)
			if not playerObject then
				print("No PlayerObject found")
				return
			end

			local success = playerObject.ToolManager:upgradeTool(toolName, statName)
			print(`Upgrade {toolName}.{statName} for {player.Name}: {success}`)
		end
	},

	{
		name = "maxupgradetool",
		aliases = {"maxtool"},
		description = "Max upgrade all stats of a tool",
		usage = "/maxupgradetool [toolname]",
		handler = function(player: Player, toolName: string)
			local playerObject = PlayerManager.getPlayerObject(player)
			if not playerObject then
				print("No PlayerObject found")
				return
			end

			local toolData = playerObject.ToolManager.Tools[toolName]
			if not toolData then
				print("Tool not found")
				return
			end

			for statName, _ in pairs(toolData.Stats) do
				while playerObject.ToolManager:upgradeTool(toolName, statName) do
					task.wait()
				end
			end

			playerObject.ToolManager:giveTools()
			print(`Maxed all stats for {toolName}`)
		end
	},

	{
		name = "toolinfo",
		aliases = {},
		description = "Get tool information",
		usage = "/toolinfo [toolname]",
		handler = function(player: Player, toolName: string)
			local playerObject = PlayerManager.getPlayerObject(player)
			if not playerObject then
				print("No PlayerObject found")
				return
			end

			local toolData = playerObject.ToolManager.Tools[toolName]
			if not toolData then
				print("Tool not found:", toolName)
				return
			end

			print("=== TOOL INFO ===")
			print("Name:", toolName)
			print("Unlocked:", toolData.Unlocked)

			print("\n=== STATS ===")
			for statName, level in pairs(toolData.Stats) do
				local value = playerObject.ToolManager:getToolStat(toolName, statName)
				print(`{statName}: Level {level} (Value: {value})`)
			end
		end
	},

	{
		name = "listtools",
		aliases = {"tools"},
		description = "List all player tools",
		usage = "/listtools",
		handler = function(player: Player)
			local playerObject = PlayerManager.getPlayerObject(player)
			if not playerObject then
				print("No PlayerObject found")
				return
			end

			print("=== PLAYER TOOLS ===")
			for toolName, toolData in pairs(playerObject.ToolManager.Tools) do
				print(`{toolName}: {toolData.Unlocked and "Unlocked" or "Locked"}`)
			end

			local equipped = playerObject:getEquippedTool()
			print(`\nEquipped: {equipped or "None"}`)
		end
	},

	{
		name = "equiptool",
		aliases = {"equip"},
		description = "Force equip a tool",
		usage = "/equiptool [toolname]",
		handler = function(player: Player, toolName: string)
			local playerObject = PlayerManager.getPlayerObject(player)
			if not playerObject then
				print("No PlayerObject found")
				return
			end

			playerObject:setEquippedTool(toolName)
			print(`Equipped {toolName} for {player.Name}`)
		end
	},

	--// Help //--
	{
		name = "help",
		aliases = {"commands", "cmds"},
		description = "Show all commands",
		usage = "/help",
		handler = function(player: Player)
			print("\n=== AVAILABLE COMMANDS ===")
			for _, cmd in CommandsConfig do
				print(`{cmd.usage} - {cmd.description}`)
			end
		end
	},
}

return CommandsConfig