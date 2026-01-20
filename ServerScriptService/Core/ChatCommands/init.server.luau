local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CommandsConfig = require(script.CommandsConfig)

local CommandMap = {}
local AliasMap = {}

local function buildCommandMaps()
	for _, cmd in ipairs(CommandsConfig) do
		CommandMap[cmd.name] = cmd

		for _, alias in ipairs(cmd.aliases) do
			AliasMap[alias] = cmd.name
		end
	end
end

local function parseCommand(player: Player, message: string)
	if not RunService:IsStudio() then
		return
	end

	if string.sub(message, 1, 1) ~= "/" then
		return
	end

	local parts = string.split(string.sub(message, 2), " ")
	local commandName = string.lower(parts[1])
	local args = {select(2, unpack(parts))}

	local actualCommandName = AliasMap[commandName] or commandName
	local command = CommandMap[actualCommandName]

	if command then
		task.spawn(function()
			local success, err = pcall(command.handler, player, unpack(args))

			if not success then
				warn(`Command error: {err}`)
			end
		end)
	else
	end
end

buildCommandMaps()

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
--		print(message)
		parseCommand(player, message)
	end)
end)

--print("[CommandHandler] Initialized with", #CommandsConfig, "commands")
