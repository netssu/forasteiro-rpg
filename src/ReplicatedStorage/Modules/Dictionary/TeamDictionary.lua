------------------//CONSTANTS
local TeamDictionary = {
	TEAM_SELECT_EVENT_NAME = "TeamSelectEvent",
	RETURN_TO_MENU_ACTION = "ReturnToMenu",
	SET_ROLE_ACTION = "SetRole",
	MASTER_TEAM_NAME = "Mestre",
	PLAYER_TEAM_NAME = "Jogador",
	GUI_NAME = "TeamSelectGui",
	MAIN_FRAME_NAME = "Main",
	MASTER_BUTTON_NAME = "MasterButton",
	PLAYER_BUTTON_NAME = "PlayerButton",
	ASSETS_FOLDER_NAME = "Assets",
	REMOTES_FOLDER_NAME = "Remotes",
}

TeamDictionary.VALID_TEAMS = {
	[TeamDictionary.MASTER_TEAM_NAME] = true,
	[TeamDictionary.PLAYER_TEAM_NAME] = true,
}

return TeamDictionary
