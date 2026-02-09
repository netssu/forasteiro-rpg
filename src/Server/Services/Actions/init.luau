local module = {}

-- // Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- // Dependencies
local Packets = require(ReplicatedStorage.Modules.Game.Packets)

-- // Types
type ActionModule = {
	OnStart: (player: Player, data: { any }) -> (),
}

-- // Variables
local actions: { [string]: ActionModule } = {}

-- // Public Functions
function module:Init()
	for _, child in script:GetChildren() do
		if child:IsA('ModuleScript') then
			local success, actionModule = pcall(require, child)
			
			if
				success
				and type(actionModule) == 'table'
				and typeof(actionModule.OnStart) == 'function'
			then
				actions[child.Name] = actionModule :: ActionModule
			else
				warn(`[ActionService]: failed to load module {child.Name}`)
			end
		end
	end

	Packets.Action.OnServerEvent:Connect(
		function(player: Player, actionName: string, data: { any })
			local action = actions[actionName]

			if action then
				task.spawn(action.OnStart, player, data)
			else
				warn(`[ActionService]: exploit?`)
			end
		end
	)
end

return module
