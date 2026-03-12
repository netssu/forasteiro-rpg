------------------//VARIABLES
local module = {}

------------------//FUNCTIONS
function module.is_master(self): boolean
	local state = self.state
	return state.Player.Team ~= nil and state.Player.Team.Name == state.MASTER_TEAM_NAME
end

function module.is_player_spectator_drag_enabled(self): boolean
	local state = self.state

	return state.Player.Team ~= nil
		and state.Player.Team.Name == state.PLAYER_TEAM_NAME
		and state.Player:GetAttribute(state.PLAYER_SPECTATOR_ATTRIBUTE_NAME) == true
end

function module.can_use_character_drag(self): boolean
	return module.is_master(self) or module.is_player_spectator_drag_enabled(self)
end

return module