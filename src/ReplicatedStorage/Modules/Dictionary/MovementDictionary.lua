------------------//CONSTANTS
local MovementDictionary = {
	PLAYER_TEAM_NAME = "Jogador",
	MASTER_TEAM_NAME = "Mestre",
	GUI_NAME = "PlayerHud",
	MAIN_FRAME_NAME = "Main",
	MOVEMENT_FRAME_NAME = "MovementFrame",
	DISTANCE_LABEL_NAME = "DistanceLabel",
	UNDO_BUTTON_NAME = "UndoButton",
	UNDO_BUTTON_TEXT = "Desfazer (Z)",
	PLAYER_SPECTATOR_ATTRIBUTE_NAME = "PlayerSpectatorEnabled",
	MAX_MOVEMENT_DISTANCE_ATTRIBUTE_NAME = "MaxMovementDistance",
	MOVEMENT_EVENT_NAME = "PlayerMovementEvent",
	TURN_EVENT_NAME = "PlayerTurnEvent",
	DRAW_SEGMENT_ACTION = "DrawSegment",
	CLEAR_TRAIL_ACTION = "ClearTrail",
	ASSETS_FOLDER_NAME = "Assets",
	REMOTES_FOLDER_NAME = "Remotes",
	MAX_DISTANCE_METERS = 9.0,
	STUDS_PER_METER = 3.6,
	POINT_INTERVAL = 0.5,
	TELEPORT_THRESHOLD = 8.0,
	DEFAULT_WALKSPEED = 16,
	FOOT_HEIGHT_OFFSET = 2.5,
	UNDO_KEYCODE = Enum.KeyCode.Z,
	DISTANCE_TEXT_COLOR_DEFAULT = Color3.fromRGB(255, 255, 255),
	DISTANCE_TEXT_COLOR_LIMIT = Color3.fromRGB(255, 80, 80),
}

MovementDictionary.MAX_DISTANCE_STUDS = MovementDictionary.MAX_DISTANCE_METERS * MovementDictionary.STUDS_PER_METER

return MovementDictionary
