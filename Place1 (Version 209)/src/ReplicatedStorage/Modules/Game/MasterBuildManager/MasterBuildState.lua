------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//MODULES
local MasterBuildConstants = require(script.Parent:WaitForChild("MasterBuildConstants"))

------------------//VARIABLES
local module = {}

------------------//MAIN FUNCTIONS
function module.new(player: Player)
	local constants = MasterBuildConstants

	local playerGui: PlayerGui = player:WaitForChild("PlayerGui")
	local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
	local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
	local masterBuildEvent: RemoteEvent = remotesFolder:WaitForChild(constants.REMOTE_NAME)

	return {
		Player = player,
		PlayerGui = playerGui,
		AssetsFolder = assetsFolder,
		RemotesFolder = remotesFolder,
		MasterBuildEvent = masterBuildEvent,

		MASTER_TEAM_NAME = constants.MASTER_TEAM_NAME,
		PLAYER_TEAM_NAME = constants.PLAYER_TEAM_NAME,
		PLAYER_SPECTATOR_ATTRIBUTE_NAME = constants.PLAYER_SPECTATOR_ATTRIBUTE_NAME,

		MasterGui = nil,
		TopBar = nil,

		BuildToggleButton = nil,
		RoomToggleButton = nil,

		BuildSidebar = nil,
		RoomSidebar = nil,

		BuildBody = nil,
		RoomBody = nil,

		EnvironmentWindow = nil,
		PlayersWindow = nil,
		CombatWindow = nil,
		NpcSidebar = nil,

		SelectModeButton = nil,
		CreateModeButton = nil,
		WallModeButton = nil,
		RoomModeButton = nil,
		LightModeButton = nil,
		DeleteButton = nil,
		ApplySizeButton = nil,
		ApplyColorButton = nil,
		WallHeightMinusButton = nil,
		WallHeightPlusButton = nil,

		BuildStatusLabel = nil,
		RoomStatusLabel = nil,

		RoomSettingsFrame = nil,
		RoomFloorButton = nil,
		RoomCeilingButton = nil,

		SizeXBox = nil,
		SizeYBox = nil,
		SizeZBox = nil,
		GridBox = nil,
		WallHeightBox = nil,
		WallThicknessBox = nil,
		RoomHeightBox = nil,
		ColorRBox = nil,
		ColorGBox = nil,
		ColorBBox = nil,
		LightRangeBox = nil,
		LightBrightnessBox = nil,

		ToolMode = constants.TOOL_MODE_NONE,
		GridSize = constants.DEFAULT_GRID_SIZE,
		WallHeight = constants.DEFAULT_WALL_HEIGHT,
		WallThickness = constants.DEFAULT_WALL_THICKNESS,
		RoomHeight = constants.DEFAULT_ROOM_HEIGHT,
		CreateSize = constants.DEFAULT_CREATE_SIZE,
		BuildColor = constants.DEFAULT_COLOR,
		LightRange = 20,
		LightBrightness = 2,

		CreateWithFloor = true,
		CreateWithCeiling = true,

		PreviewPart = nil,
		RoomPreviewParts = {},
		Highlight = nil,
		HoverHighlight = nil,
		MoveHandles = nil,
		ResizeHandles = nil,
		RotateHandles = nil,

		SelectedKind = "",
		SelectedPart = nil,
		SelectedCharacter = nil,

		CreateAnchor = nil,
		WallAnchor = nil,

		DragMode = "",
		DragFace = nil,
		DragAxis = nil,
		DragBasePartCFrame = nil,
		DragBasePartSize = nil,
		DragBaseCharacterCFrame = nil,
		LastDragSend = 0,

		GizmoDragging = false,
		ButtonsConnected = false,
		HandlesConnected = false,

		CharacterMouseDragActive = false,
		CharacterMouseDragTarget = nil,
		CharacterMouseDragPlaneY = 0,
		CharacterMouseDragOffset = Vector3.zero,
		LastCharacterMouseDragSend = 0,

		HoverKind = "",
		HoverPart = nil,
		HoverCharacter = nil,
	}
end

return module