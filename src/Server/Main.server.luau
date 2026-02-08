local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Packages.Framework)

Framework:SetServices(ServerScriptService.Services)
Framework:SetComponents(ServerScriptService.Components)

Framework:Start()
	:andThen(function(deltaTime)
		print(`Server load completed. Took: {math.round(deltaTime)}ms`)
	end)
	:catch(function(err)
		warn(`Something went wrong while starting the framework: {err}`)
	end)
