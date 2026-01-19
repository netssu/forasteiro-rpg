--// Services //--
local ServerScriptService = game:GetService("ServerScriptService")

--// Dependencies //--
local Core = ServerScriptService.Core
local CatchingManager = require(Core.Catching.CatchingManager)
local PlayerManager = require(Core.Player.PlayerManager)

--// Types //--
export type BindableConfig = {
	[string]: {
		Handler: (...any) -> ()
	}
}

--// Handlers //--
local module = {
	OnBrainThrow = {
		Handler = function(player: Player, brain: Model)
			local session = CatchingManager.getSession(player)
			if not session then
				warn(`[BindableConfig] No session found for {player.Name}`)
				return
			end

			session:addBrain(brain)
		end,
	},

}

return module :: BindableConfig