local module = {}

-- // Services
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')

-- // Dependencies
local MetaPlayer = require(ServerScriptService.Modules.Core.MetaPlayer)
local Signal = require(ReplicatedStorage.Packages.Signal)

-- // Variables
module.Signals = {
	AssignPlot = Signal.new(),
	RemovePlot = Signal.new(),
}

-- // Private Functions
local function find_slot()
	for _, plot in ipairs(workspace.Map.Plots:GetChildren()) do
		if
			plot:GetAttribute('Owner')
			and Players:FindFirstChild(plot:GetAttribute('Owner'))
		then
			return false
		end

		return plot
	end
	return nil
end

-- // Public Functions
function module:Init()
	MetaPlayer.Signals.PlayerAdded:Connect(function(metaPlayer)
		local player = metaPlayer.Instance
		local plot = find_slot()

		if plot then
			plot:SetAttribute('Owner', player.UserId)
			metaPlayer.Cache.Plot = plot

			player.CharacterAdded:Connect(function(character)
				local spawnPart = plot.PrimaryPart
				if spawnPart then
					task.defer(function()
						character:PivotTo(
							spawnPart.CFrame + vector.create(0, 3, 0)
						)
					end)
				end
			end)

			if player.Character then
				player.Character:PivotTo(
					plot.PrimaryPart.CFrame + vector.create(0, 3, 0)
				)
			end

			print(`[PlotService]: {player.Name} in {plot.Name}`)
			module.Signals.AssignPlot:Fire(metaPlayer)
		else
			player:Kick('Plots reached.')
		end
	end)
end

return module
