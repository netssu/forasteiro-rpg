local CommandService = {}

local Resources = game.ReplicatedStorage.Resources
local Players = game:GetService("Players")
local ServerStorage = game.ServerStorage

local Separator = " " -- what separates the words in the command message
local Prefix = ":" -- what to put before the command


-- list of commands and their functions
local Commands = {
	
	{ -- adds money to the user
		Command = "addmoney",
		Whitelist = {
			UserIds = {
				127422851,
			},

			GroupRank = {
				-- [group id] = {group ranks}
				[16473008] = {250,255},

			}
		},
		Function = function(user:Player,...)
			local target,amount = ...
			
			print(target,amount)
			
			amount = tonumber(amount)
			if not amount then
				return
			end
			
			local player:Player
			for _, plr in pairs(Players:GetPlayers()) do
				if string.lower(plr.Name) == target then
					player = plr
				end
			end
			
			if target == "me" then
				player = user
			end
			print(player)
			if not player or not player:IsA("Player") then
				return
			end
			
			local MoneyService = CommandService.Services.MoneyService
			print(MoneyService)
			
			MoneyService:AddMoney(player, amount)
			
		end,
	},
	
	
	{ -- starts a match with the provided map name
		Command = "startmap",
		Whitelist = {
			UserIds = { -- faster than group rank check
				127422851, -- meu id (arthurkla)
				123, -- põe o seu aq e nos outros comandos
			},

			GroupRank = {
				-- [group id] = {group ranks}
				[16473008] = {250,255},
			}
		},
		Function = function(user:Player,...)
			local args = table.pack(...)
			local mapName = table.concat(args)
			print(mapName)
			
			local MapService = CommandService.Services.MapService

			local Map = MapService:GetMap(mapName)
			if not Map then
				return
			end
			
			local GameplayService = CommandService.Services.GameplayService
			
			local gamemode = workspace:GetAttribute("Gamemode")
			print(gamemode)
			
			local function skipCountdown(times)
				for i = 1, times do
					GameplayService:Countdown(0)
					task.wait(1)
				end
			end
			
			if gamemode == "MAP VOTE" then
				skipCountdown(1)
			elseif gamemode == "INTERMISSION" then
				skipCountdown(2)
			else
				skipCountdown(3)
			end
			print(MapService)
			MapService:SpawnMap(Map.Name)
		end,
	},
	
	
	{ -- loads a map by name
		Command = "loadmap",
		Whitelist = {
			UserIds = { -- faster than group rank check
				127422851, -- meu id (arthurkla)
				123, -- põe o seu aq e nos outros comandos
			},

			GroupRank = {
				-- [group id] = {group ranks}
				[16473008] = {250,255},
			}
		},
		Function = function(user:Player,...)
			local args = table.pack(...)
			local mapName = table.concat(args)
			
			local MapService = CommandService.Services.MapService

			local Map = MapService:GetMap(mapName)
			if not Map then
				return
			end
			
			print(MapService)
			MapService:SpawnMap(Map.Name)
		end,
	},
	
	
	{ -- skips the current countdown
		Command = "skip",
		Whitelist = {
			UserIds = {
				127422851,
			},

			GroupRank = {
				-- [group id] = {group ranks}
				[16473008] = {250,255},
				
			}
		},
		Function = function(user:Player,...)
			local GameplayService = CommandService.Services.GameplayService
			GameplayService:Countdown(0)
		end,
	},
	
}




-- processes the message as a command
function CommandService:InterpretCommand(player,message)
	
	local text = string.lower(message)
	local components = string.split(text,Separator)

	-- looks for the first string that is not nothing
	local base
	local baseIndex = 1
	for i = 1,#components do
		local baseCheck = components[i]
		if not baseCheck or baseCheck == "" or baseCheck == " " then
			continue
		end
		base = components[i]
		baseIndex = i
		break
	end
	if not base then
		return
	end

	-- checks if the base has the command prefix
	local hasPrefix = string.find(base,Prefix,1)
	if not hasPrefix then
		return
	end

	-- adds arguments to the table
	local arguments = {}
	for i = baseIndex+1, #components do
		local baseCheck = components[i]
		if not baseCheck or baseCheck == "" or baseCheck == " " then
			continue
		end
		table.insert(arguments,components[i])
	end

	local baseComponents = string.split(base,Prefix)
	local commandName = baseComponents[2]
	
	local CommandData = CommandService:GetCommand(commandName)
	if not CommandData then
		return
	end
	
	local permission = CommandService:HasCommandPermission(player,CommandData)
	if not permission then
		return
	end
	
	CommandData.Function(player,table.unpack(arguments))
end


-- checks the command whitelist table to see if player can execute it
function CommandService:HasCommandPermission(player:Player,CommandData)
	local whitelist = CommandData.Whitelist
	
	local UserIds = whitelist.UserIds
	local GroupRanks = whitelist.GroupRank
	
	if UserIds then
		local index = table.find(UserIds,player.UserId)
		if index then
			return true
		end
	end
	
	if GroupRanks then
		for groupId, ranks in pairs(GroupRanks) do
			local rank = player:GetRankInGroupAsync(groupId)
			for _, minRank in pairs(ranks) do
				if rank == minRank then
					return true
				end
			end
		end
	end
	
end


-- gets command data from command name
function CommandService:GetCommand(name)
	for _, command in pairs(Commands) do
		if string.lower(command.Command) == name then
			return command
		end
	end
end


-- starts listening to commands from player
function CommandService:LoadPlayer(player:Player)
	player.Chatted:Connect(function(message)
		CommandService:InterpretCommand(player,message)
	end)
end


function CommandService:Init()
	local Packet = self.Libs.Packet
end

function CommandService:Start()
end

return CommandService
