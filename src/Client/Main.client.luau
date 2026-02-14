local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Packages.Framework)

Framework:SetControllers(ReplicatedStorage.Controllers)
Framework:SetComponents(ReplicatedStorage.Components)
Framework:SetUI(ReplicatedStorage.Controllers.UIController)


Framework:Start()
	:andThen(function(deltaTime)
		print(`Client load completed. Took: {math.round(deltaTime)}ms`)
	end)
	:catch(function(err)
		warn(`Something went wrong while starting the framework: {err}`)
	end)