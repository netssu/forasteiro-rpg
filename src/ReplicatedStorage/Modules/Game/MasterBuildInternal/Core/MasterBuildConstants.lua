------------------//CONSTANTS
local module = {}

module.MASTER_TEAM_NAME = "Mestre"
module.PLAYER_TEAM_NAME = "Jogador"
module.PLAYER_SPECTATOR_ATTRIBUTE_NAME = "PlayerSpectatorEnabled"

module.GUI_NAME = "MasterGui"

module.BUILD_SIDEBAR_NAME = "BuildSidebar"
module.ROOM_SIDEBAR_NAME = "RoomSidebar"

module.BUILD_TOGGLE_BUTTON_NAME = "BuildToggleButton"
module.ROOM_TOGGLE_BUTTON_NAME = "RoomToggleButton"

module.REMOTE_NAME = "MasterBuildEvent"
module.BUILD_FOLDER_NAME = "TabletopBuildParts"

module.TOOL_MODE_NONE = ""
module.TOOL_MODE_SELECT = "Select"
module.TOOL_MODE_CREATE = "Create"
module.TOOL_MODE_WALL = "Wall"
module.TOOL_MODE_ROOM = "Room"
module.TOOL_MODE_LIGHT = "Light"

module.DEFAULT_GRID_SIZE = 1
module.DEFAULT_WALL_HEIGHT = 12
module.DEFAULT_ROOM_HEIGHT = module.DEFAULT_WALL_HEIGHT
module.DEFAULT_WALL_THICKNESS = 1
module.DEFAULT_CREATE_SIZE = Vector3.new(8, 4, 8)
module.DEFAULT_COLOR = Color3.fromRGB(163, 162, 165)
module.DEFAULT_LIGHT_COLOR = Color3.fromRGB(255, 253, 224)

module.PREVIEW_TRANSPARENCY = 0.45
module.ROTATION_STEP_DEGREES = 15
module.DRAG_SEND_INTERVAL = 0.03
module.WALL_HEIGHT_STEP = 1
module.WALL_ENDPOINT_SNAP_DISTANCE = 5

module.ACTIVE_BUTTON_COLOR = Color3.fromRGB(219, 184, 74)
module.INACTIVE_BUTTON_COLOR = Color3.fromRGB(34, 36, 44)

module.KEY_MAP = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10
}

return module