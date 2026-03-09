------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService: UserInputService = game:GetService("UserInputService")
local RunService: RunService = game:GetService("RunService")

------------------//CONSTANTS
local MASTER_TEAM_NAME: string = "Mestre"
local GUI_NAME: string = "MasterGui"
local SIDEBAR_NAME: string = "BuildSidebar"
local TOGGLE_BUTTON_NAME: string = "BuildToggleButton"
local REMOTE_NAME: string = "MasterBuildEvent"
local BUILD_FOLDER_NAME: string = "TabletopBuildParts"

local TOOL_MODE_NONE: string = ""
local TOOL_MODE_SELECT: string = "Select"
local TOOL_MODE_CREATE: string = "Create"
local TOOL_MODE_WALL: string = "Wall"

local DEFAULT_GRID_SIZE: number = 1
local DEFAULT_WALL_HEIGHT: number = 12
local DEFAULT_WALL_THICKNESS: number = 1
local DEFAULT_CREATE_SIZE: Vector3 = Vector3.new(8, 4, 8)
local DEFAULT_COLOR: Color3 = Color3.fromRGB(163, 162, 165)

local PREVIEW_TRANSPARENCY: number = 0.45
local ROTATION_STEP_DEGREES: number = 15
local DRAG_SEND_INTERVAL: number = 0.03
local WALL_HEIGHT_STEP: number = 1
local WALL_ENDPOINT_SNAP_DISTANCE: number = 5

local ACTIVE_BUTTON_COLOR: Color3 = Color3.fromRGB(219, 184, 74)
local INACTIVE_BUTTON_COLOR: Color3 = Color3.fromRGB(34, 36, 44)

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local masterBuildEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)

local masterGui: ScreenGui? = nil
local topBar: Frame? = nil
local buildToggleButton: TextButton? = nil
local buildSidebar: Frame? = nil
local buildBody: Frame? = nil

local selectModeButton: TextButton? = nil
local createModeButton: TextButton? = nil
local wallModeButton: TextButton? = nil
local deleteButton: TextButton? = nil
local applySizeButton: TextButton? = nil
local applyColorButton: TextButton? = nil
local wallHeightMinusButton: TextButton? = nil
local wallHeightPlusButton: TextButton? = nil
local statusLabel: TextLabel? = nil

local sizeXBox: TextBox? = nil
local sizeYBox: TextBox? = nil
local sizeZBox: TextBox? = nil
local gridBox: TextBox? = nil
local wallHeightBox: TextBox? = nil
local wallThicknessBox: TextBox? = nil
local colorRBox: TextBox? = nil
local colorGBox: TextBox? = nil
local colorBBox: TextBox? = nil

local toolMode: string = TOOL_MODE_NONE
local gridSize: number = DEFAULT_GRID_SIZE
local wallHeight: number = DEFAULT_WALL_HEIGHT
local wallThickness: number = DEFAULT_WALL_THICKNESS
local createSize: Vector3 = DEFAULT_CREATE_SIZE
local buildColor: Color3 = DEFAULT_COLOR

local previewPart: Part? = nil
local highlight: Highlight? = nil
local hoverHighlight: Highlight? = nil
local moveHandles: Handles? = nil
local resizeHandles: Handles? = nil
local rotateHandles: ArcHandles? = nil

local selectedKind: string = ""
local selectedPart: BasePart? = nil
local selectedPlayer: Player? = nil

local createAnchor: Vector3? = nil
local wallAnchor: Vector3? = nil

local dragMode: string = ""
local dragFace: Enum.NormalId? = nil
local dragAxis: Enum.Axis? = nil
local dragBasePartCFrame: CFrame? = nil
local dragBasePartSize: Vector3? = nil
local dragBasePlayerCFrame: CFrame? = nil
local lastDragSend: number = 0

local gizmoHoverCount: number = 0
local gizmoDragging: boolean = false
local buttonsConnected: boolean = false
local handlesConnected: boolean = false

local playerMouseDragActive: boolean = false
local playerMouseDragTarget: Player? = nil
local playerMouseDragPlaneY: number = 0
local playerMouseDragOffset: Vector3 = Vector3.zero
local lastPlayerMouseDragSend: number = 0

------------------//FUNCTIONS
local function is_master(): boolean
	return player.Team ~= nil and player.Team.Name == MASTER_TEAM_NAME
end

local function get_current_camera(): Camera
	local currentCamera = workspace.CurrentCamera

	while not currentCamera do
		task.wait()
		currentCamera = workspace.CurrentCamera
	end

	return currentCamera
end

local function is_sidebar_visible(): boolean
	return buildSidebar ~= nil and buildSidebar.Visible
end

local function get_build_folder(): Folder?
	local folder = workspace:FindFirstChild(BUILD_FOLDER_NAME)

	if folder and folder:IsA("Folder") then
		return folder
	end

	return nil
end

local function is_valid_selected_part(part: BasePart?): boolean
	if not part then
		return false
	end

	local buildFolder = get_build_folder()

	if not buildFolder then
		return false
	end

	return part.Parent == buildFolder and part:GetAttribute("IsTabletopBuildPart") == true
end

local function is_valid_selected_player(targetPlayer: Player?): boolean
	if not targetPlayer then
		return false
	end

	return targetPlayer.Parent == Players
end

local function fire_build(action: string, payload: any?): ()
	local request = payload or {}
	request.Action = action
	masterBuildEvent:FireServer(request)
end

local function sanitize_text_number(text: string, fallback: number, minimum: number): number
	local numberValue = tonumber(text)

	if not numberValue then
		return fallback
	end

	return math.max(minimum, numberValue)
end

local function clamp_color_channel(value: number): number
	return math.clamp(math.floor(value + 0.5), 0, 255)
end

local function snap_number(value: number, stepValue: number): number
	local safeStep = math.max(0.25, stepValue)
	return math.floor((value / safeStep) + 0.5) * safeStep
end

local function snap_vector3(value: Vector3, stepValue: number): Vector3
	return Vector3.new(
		snap_number(value.X, stepValue),
		snap_number(value.Y, stepValue),
		snap_number(value.Z, stepValue)
	)
end

local function vector_from_normal_id(normalId: Enum.NormalId, cframe: CFrame): Vector3
	if normalId == Enum.NormalId.Right then
		return cframe.RightVector
	end

	if normalId == Enum.NormalId.Left then
		return -cframe.RightVector
	end

	if normalId == Enum.NormalId.Top then
		return cframe.UpVector
	end

	if normalId == Enum.NormalId.Bottom then
		return -cframe.UpVector
	end

	if normalId == Enum.NormalId.Front then
		return -cframe.LookVector
	end

	return cframe.LookVector
end

local function vector_from_player_normal_id(normalId: Enum.NormalId, cframe: CFrame): Vector3
	if normalId == Enum.NormalId.Right then
		return cframe.RightVector
	end

	if normalId == Enum.NormalId.Left then
		return -cframe.RightVector
	end

	if normalId == Enum.NormalId.Top then
		return cframe.UpVector
	end

	if normalId == Enum.NormalId.Bottom then
		return -cframe.UpVector
	end

	if normalId == Enum.NormalId.Front then
		return cframe.LookVector
	end

	return -cframe.LookVector
end

local function local_axis_name_from_normal(normalId: Enum.NormalId): string
	if normalId == Enum.NormalId.Right or normalId == Enum.NormalId.Left then
		return "X"
	end

	if normalId == Enum.NormalId.Top or normalId == Enum.NormalId.Bottom then
		return "Y"
	end

	return "Z"
end

local function rotation_cframe_from_axis(axis: Enum.Axis, angle: number): CFrame
	if axis == Enum.Axis.X then
		return CFrame.Angles(angle, 0, 0)
	end

	if axis == Enum.Axis.Y then
		return CFrame.Angles(0, angle, 0)
	end

	return CFrame.Angles(0, 0, angle)
end

local function get_rotation_only_cframe(cframe: CFrame): CFrame
	local rx, ry, rz = cframe:ToOrientation()
	return CFrame.fromOrientation(rx, ry, rz)
end

local function ensure_preview_part(): Part
	if previewPart and previewPart.Parent == workspace then
		return previewPart
	end

	local part = Instance.new("Part")
	part.Name = "MasterBuildPreview"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.ForceField
	part.Color = buildColor
	part.Transparency = PREVIEW_TRANSPARENCY
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = workspace

	previewPart = part

	return part
end

local function ensure_highlight(): Highlight
	if highlight and highlight.Parent == playerGui then
		return highlight
	end

	local newHighlight = Instance.new("Highlight")
	newHighlight.Name = "MasterBuildHighlight"
	newHighlight.FillTransparency = 0.75
	newHighlight.OutlineTransparency = 0
	newHighlight.OutlineColor = Color3.fromRGB(255, 220, 80)
	newHighlight.Parent = playerGui

	highlight = newHighlight

	return newHighlight
end

local function ensure_hover_highlight(): Highlight
	if hoverHighlight and hoverHighlight.Parent == playerGui then
		return hoverHighlight
	end

	local newHighlight = Instance.new("Highlight")
	newHighlight.Name = "MasterBuildHoverHighlight"
	newHighlight.FillTransparency = 1
	newHighlight.OutlineTransparency = 0
	newHighlight.OutlineColor = Color3.fromRGB(170, 220, 255)
	newHighlight.Parent = playerGui

	hoverHighlight = newHighlight

	return newHighlight
end

local function clear_hover_highlight(): ()
	local currentHoverHighlight = ensure_hover_highlight()
	currentHoverHighlight.Adornee = nil
end

local function ensure_handles(): ()
	if not moveHandles or moveHandles.Parent ~= playerGui then
		moveHandles = Instance.new("Handles")
		moveHandles.Name = "MasterMoveHandles"
		moveHandles.Style = Enum.HandlesStyle.Movement
		moveHandles.Color3 = Color3.fromRGB(120, 220, 255)
		moveHandles.Parent = playerGui
	end

	if not resizeHandles or resizeHandles.Parent ~= playerGui then
		resizeHandles = Instance.new("Handles")
		resizeHandles.Name = "MasterResizeHandles"
		resizeHandles.Style = Enum.HandlesStyle.Resize
		resizeHandles.Color3 = Color3.fromRGB(255, 180, 100)
		resizeHandles.Parent = playerGui
	end

	if not rotateHandles or rotateHandles.Parent ~= playerGui then
		rotateHandles = Instance.new("ArcHandles")
		rotateHandles.Name = "MasterRotateHandles"
		rotateHandles.Color3 = Color3.fromRGB(170, 255, 170)
		rotateHandles.Parent = playerGui
	end
end

local function cache_gui_objects(): ()
	local guiObject = playerGui:FindFirstChild(GUI_NAME)

	if not guiObject or not guiObject:IsA("ScreenGui") then
		masterGui = nil
		topBar = nil
		buildToggleButton = nil
		buildSidebar = nil
		buildBody = nil
		return
	end

	masterGui = guiObject
	topBar = masterGui:FindFirstChild("TopBar")
	buildToggleButton = topBar and topBar:FindFirstChild(TOGGLE_BUTTON_NAME) or nil
	buildSidebar = masterGui:FindFirstChild(SIDEBAR_NAME)
	buildBody = buildSidebar and buildSidebar:FindFirstChild("Body") or nil

	selectModeButton = buildBody and buildBody:FindFirstChild("SelectModeButton") or nil
	createModeButton = buildBody and buildBody:FindFirstChild("CreateModeButton") or nil
	wallModeButton = buildBody and buildBody:FindFirstChild("WallModeButton") or nil
	deleteButton = buildBody and buildBody:FindFirstChild("DeleteButton") or nil
	applySizeButton = buildBody and buildBody:FindFirstChild("ApplySizeButton") or nil
	applyColorButton = buildBody and buildBody:FindFirstChild("ApplyColorButton") or nil
	wallHeightMinusButton = buildBody and buildBody:FindFirstChild("WallHeightMinusButton") or nil
	wallHeightPlusButton = buildBody and buildBody:FindFirstChild("WallHeightPlusButton") or nil
	statusLabel = buildBody and buildBody:FindFirstChild("StatusLabel") or nil

	sizeXBox = buildBody and buildBody:FindFirstChild("SizeXBox") or nil
	sizeYBox = buildBody and buildBody:FindFirstChild("SizeYBox") or nil
	sizeZBox = buildBody and buildBody:FindFirstChild("SizeZBox") or nil
	gridBox = buildBody and buildBody:FindFirstChild("GridBox") or nil
	wallHeightBox = buildBody and buildBody:FindFirstChild("WallHeightBox") or nil
	wallThicknessBox = buildBody and buildBody:FindFirstChild("WallThicknessBox") or nil
	colorRBox = buildBody and buildBody:FindFirstChild("ColorRBox") or nil
	colorGBox = buildBody and buildBody:FindFirstChild("ColorGBox") or nil
	colorBBox = buildBody and buildBody:FindFirstChild("ColorBBox") or nil
end

local function sync_boxes_from_state(): ()
	if sizeXBox then
		sizeXBox.Text = tostring(createSize.X)
	end

	if sizeYBox then
		sizeYBox.Text = tostring(createSize.Y)
	end

	if sizeZBox then
		sizeZBox.Text = tostring(createSize.Z)
	end

	if gridBox then
		gridBox.Text = tostring(gridSize)
	end

	if wallHeightBox then
		wallHeightBox.Text = tostring(wallHeight)
	end

	if wallThicknessBox then
		wallThicknessBox.Text = tostring(wallThickness)
	end

	if colorRBox then
		colorRBox.Text = tostring(clamp_color_channel(buildColor.R * 255))
	end

	if colorGBox then
		colorGBox.Text = tostring(clamp_color_channel(buildColor.G * 255))
	end

	if colorBBox then
		colorBBox.Text = tostring(clamp_color_channel(buildColor.B * 255))
	end
end

local function read_color_from_boxes(): Color3
	local r = sanitize_text_number(colorRBox and colorRBox.Text or "163", 163, 0)
	local g = sanitize_text_number(colorGBox and colorGBox.Text or "162", 162, 0)
	local b = sanitize_text_number(colorBBox and colorBBox.Text or "165", 165, 0)

	return Color3.fromRGB(
		clamp_color_channel(r),
		clamp_color_channel(g),
		clamp_color_channel(b)
	)
end

local function sync_color_boxes_from_part(part: BasePart): ()
	buildColor = part.Color
	sync_boxes_from_state()
end

local function set_status(text: string): ()
	if statusLabel then
		statusLabel.Text = text
	end
end

local function update_mode_buttons(): ()
	if selectModeButton then
		selectModeButton.BackgroundColor3 = toolMode == TOOL_MODE_SELECT and ACTIVE_BUTTON_COLOR or INACTIVE_BUTTON_COLOR
	end

	if createModeButton then
		createModeButton.BackgroundColor3 = toolMode == TOOL_MODE_CREATE and ACTIVE_BUTTON_COLOR or INACTIVE_BUTTON_COLOR
	end

	if wallModeButton then
		wallModeButton.BackgroundColor3 = toolMode == TOOL_MODE_WALL and ACTIVE_BUTTON_COLOR or INACTIVE_BUTTON_COLOR
	end
end

local function get_root_part_for_player(targetPlayer: Player): BasePart?
	local character = targetPlayer.Character

	if not character then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end

	return nil
end

local function stop_player_mouse_drag(): ()
	playerMouseDragActive = false
	playerMouseDragTarget = nil
	playerMouseDragPlaneY = 0
	playerMouseDragOffset = Vector3.zero
	lastPlayerMouseDragSend = 0
end

local function finish_gizmo_drag(): ()
	gizmoDragging = false
	dragMode = ""
	dragFace = nil
	dragAxis = nil
	dragBasePartCFrame = nil
	dragBasePartSize = nil
	dragBasePlayerCFrame = nil
	lastDragSend = 0
end

local function clear_selection(): ()
	selectedKind = ""
	selectedPart = nil
	selectedPlayer = nil
	gizmoHoverCount = 0
	finish_gizmo_drag()
	stop_player_mouse_drag()

	local currentHighlight = ensure_highlight()
	currentHighlight.Adornee = nil

	ensure_handles()

	if moveHandles then
		moveHandles.Adornee = nil
	end

	if resizeHandles then
		resizeHandles.Adornee = nil
	end

	if rotateHandles then
		rotateHandles.Adornee = nil
	end

	clear_hover_highlight()
end

local function validate_selection(): ()
	if selectedKind == "Part" and not is_valid_selected_part(selectedPart) then
		clear_selection()
		return
	end

	if selectedKind == "Player" and not is_valid_selected_player(selectedPlayer) then
		clear_selection()
	end
end

local function update_handles_for_selection(): ()
	local currentHighlight = ensure_highlight()
	ensure_handles()

	if selectedKind == "Player" and selectedPlayer then
		local character = selectedPlayer.Character
		local rootPart = get_root_part_for_player(selectedPlayer)

		currentHighlight.Adornee = character

		if moveHandles then
			moveHandles.Adornee = rootPart
		end

		if resizeHandles then
			resizeHandles.Adornee = nil
		end

		if rotateHandles then
			rotateHandles.Adornee = nil
		end

		set_status("Selecionado: jogador")
		return
	end

	if toolMode ~= TOOL_MODE_SELECT then
		currentHighlight.Adornee = nil
		clear_hover_highlight()

		if moveHandles then
			moveHandles.Adornee = nil
		end

		if resizeHandles then
			resizeHandles.Adornee = nil
		end

		if rotateHandles then
			rotateHandles.Adornee = nil
		end

		return
	end

	if selectedKind == "Part" and selectedPart then
		currentHighlight.Adornee = selectedPart

		if moveHandles then
			moveHandles.Adornee = selectedPart
		end

		if resizeHandles then
			resizeHandles.Adornee = selectedPart
		end

		if rotateHandles then
			rotateHandles.Adornee = selectedPart
		end

		set_status("Selecionado: parte")
		return
	end

	clear_selection()
end

local function set_selected_part(part: BasePart): ()
	selectedKind = "Part"
	selectedPart = part
	selectedPlayer = nil
	stop_player_mouse_drag()

	if sizeXBox then
		sizeXBox.Text = tostring(part.Size.X)
	end

	if sizeYBox then
		sizeYBox.Text = tostring(part.Size.Y)
	end

	if sizeZBox then
		sizeZBox.Text = tostring(part.Size.Z)
	end

	sync_color_boxes_from_part(part)
	update_handles_for_selection()
end

local function set_selected_player(targetPlayer: Player): ()
	selectedKind = "Player"
	selectedPart = nil
	selectedPlayer = targetPlayer
	update_handles_for_selection()
end

local function is_pointer_over_gui(): boolean
	local mouseLocation = UserInputService:GetMouseLocation()
	local guiObjects = playerGui:GetGuiObjectsAtPosition(mouseLocation.X, mouseLocation.Y)

	for _, guiObject in guiObjects do
		if masterGui and guiObject:IsDescendantOf(masterGui) then
			return true
		end
	end

	return false
end

local function build_raycast_result(): RaycastResult?
	local currentCamera = get_current_camera()
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = currentCamera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local filterList = {}

	if player.Character then
		table.insert(filterList, player.Character)
	end

	if previewPart then
		table.insert(filterList, previewPart)
	end

	raycastParams.FilterDescendantsInstances = filterList

	return workspace:Raycast(ray.Origin, ray.Direction * 4096, raycastParams)
end

local function resolve_click_target(): (string, BasePart?, Player?)
	local raycastResult = build_raycast_result()

	if not raycastResult then
		return "", nil, nil
	end

	local instance = raycastResult.Instance

	if instance:IsA("BasePart") then
		local buildFolder = get_build_folder()

		if buildFolder and instance.Parent == buildFolder and instance:GetAttribute("IsTabletopBuildPart") == true then
			return "Part", instance, nil
		end

		local model = instance:FindFirstAncestorOfClass("Model")

		if model then
			local targetPlayer = Players:GetPlayerFromCharacter(model)

			if targetPlayer then
				return "Player", nil, targetPlayer
			end
		end
	end

	return "", nil, nil
end

local function update_hover_highlight(): ()
	local currentHoverHighlight = ensure_hover_highlight()

	if not is_master() then
		currentHoverHighlight.Adornee = nil
		return
	end

	if is_pointer_over_gui() then
		currentHoverHighlight.Adornee = nil
		return
	end

	if gizmoHoverCount > 0 or gizmoDragging then
		currentHoverHighlight.Adornee = nil
		return
	end

	local canHoverParts = is_sidebar_visible() and toolMode == TOOL_MODE_SELECT
	local canHoverPlayers = toolMode == TOOL_MODE_NONE or toolMode == TOOL_MODE_SELECT or not is_sidebar_visible()

	local kind, part, targetPlayer = resolve_click_target()

	if kind == "Part" and part and canHoverParts then
		if selectedKind == "Part" and selectedPart == part then
			currentHoverHighlight.Adornee = nil
			return
		end

		currentHoverHighlight.Adornee = part
		return
	end

	if kind == "Player" and targetPlayer and targetPlayer.Character and canHoverPlayers then
		if selectedKind == "Player" and selectedPlayer == targetPlayer then
			currentHoverHighlight.Adornee = nil
			return
		end

		currentHoverHighlight.Adornee = targetPlayer.Character
		return
	end

	currentHoverHighlight.Adornee = nil
end

local function get_snapped_hit_position(): Vector3?
	local raycastResult = build_raycast_result()

	if not raycastResult then
		return nil
	end

	return snap_vector3(raycastResult.Position, gridSize)
end

local function get_mouse_point_on_horizontal_plane(planeY: number): Vector3?
	local currentCamera = get_current_camera()
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = currentCamera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	if math.abs(ray.Direction.Y) < 0.0001 then
		return nil
	end

	local t = (planeY - ray.Origin.Y) / ray.Direction.Y

	if t <= 0 then
		return nil
	end

	return ray.Origin + ray.Direction * t
end

local function start_player_mouse_drag(targetPlayer: Player): ()
	local rootPart = get_root_part_for_player(targetPlayer)

	if not rootPart then
		return
	end

	local planePoint = get_mouse_point_on_horizontal_plane(rootPart.Position.Y)

	if not planePoint then
		return
	end

	playerMouseDragActive = true
	playerMouseDragTarget = targetPlayer
	playerMouseDragPlaneY = rootPart.Position.Y
	playerMouseDragOffset = rootPart.Position - Vector3.new(planePoint.X, rootPart.Position.Y, planePoint.Z)
	lastPlayerMouseDragSend = 0
end

local function update_player_mouse_drag(): ()
	if not playerMouseDragActive or not playerMouseDragTarget then
		return
	end

	if not is_valid_selected_player(playerMouseDragTarget) then
		clear_selection()
		return
	end

	local rootPart = get_root_part_for_player(playerMouseDragTarget)

	if not rootPart then
		clear_selection()
		return
	end

	local planePoint = get_mouse_point_on_horizontal_plane(playerMouseDragPlaneY)

	if not planePoint then
		return
	end

	local targetPosition = Vector3.new(
		snap_number(planePoint.X + playerMouseDragOffset.X, gridSize),
		playerMouseDragPlaneY,
		snap_number(planePoint.Z + playerMouseDragOffset.Z, gridSize)
	)

	local newCFrame = CFrame.new(targetPosition) * get_rotation_only_cframe(rootPart.CFrame)
	local nowTime = time()

	if nowTime - lastPlayerMouseDragSend < DRAG_SEND_INTERVAL then
		return
	end

	lastPlayerMouseDragSend = nowTime

	fire_build("MovePlayer", {
		UserId = playerMouseDragTarget.UserId,
		CFrame = newCFrame,
	})
end

local function get_wall_endpoint_candidates(): {Vector3}
	local buildFolder = get_build_folder()

	if not buildFolder then
		return {}
	end

	local points = {}

	for _, child in buildFolder:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("BuildKind") == "Wall" then
			local center = child.Position
			local direction = child.CFrame.LookVector
			local halfLength = child.Size.Z / 2
			local baseY = center.Y - child.Size.Y / 2

			local pointA = center - direction * halfLength
			local pointB = center + direction * halfLength

			table.insert(points, Vector3.new(pointA.X, baseY, pointA.Z))
			table.insert(points, Vector3.new(pointB.X, baseY, pointB.Z))
		end
	end

	return points
end

local function snap_wall_point(rawPoint: Vector3): Vector3
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
		return rawPoint
	end

	local candidates = get_wall_endpoint_candidates()
	local bestPoint = rawPoint
	local bestDistance = WALL_ENDPOINT_SNAP_DISTANCE

	for _, point in candidates do
		local distance = (Vector3.new(point.X, rawPoint.Y, point.Z) - rawPoint).Magnitude

		if distance <= bestDistance then
			bestDistance = distance
			bestPoint = Vector3.new(point.X, point.Y, point.Z)
		end
	end

	return bestPoint
end

local function build_box_from_two_points(pointA: Vector3, pointB: Vector3, minSize: number): (CFrame, Vector3)
	local size = Vector3.new(
		math.max(minSize, math.abs(pointB.X - pointA.X)),
		math.max(minSize, math.abs(pointB.Y - pointA.Y)),
		math.max(minSize, math.abs(pointB.Z - pointA.Z))
	)

	local center = Vector3.new(
		(pointA.X + pointB.X) / 2,
		(pointA.Y + pointB.Y) / 2,
		(pointA.Z + pointB.Z) / 2
	)

	return CFrame.new(center), size
end

local function build_wall_from_points(pointA: Vector3, pointB: Vector3, height: number, thickness: number): (CFrame, Vector3)
	local flatPointA = Vector3.new(pointA.X, pointA.Y, pointA.Z)
	local flatPointB = Vector3.new(pointB.X, pointA.Y, pointB.Z)

	local horizontal = flatPointB - flatPointA
	local length = horizontal.Magnitude

	if length < gridSize then
		length = gridSize
		horizontal = Vector3.new(0, 0, -length)
	end

	local direction = horizontal.Unit
	local center = (flatPointA + flatPointB) / 2 + Vector3.new(0, height / 2, 0)
	local cframe = CFrame.lookAt(center, center + direction)
	local size = Vector3.new(thickness, height, length)

	return cframe, size
end

local function get_create_preview_cframe_and_size(): (CFrame?, Vector3?)
	local currentPoint = get_snapped_hit_position()

	if not currentPoint then
		return nil, nil
	end

	if not createAnchor then
		local cframe = CFrame.new(currentPoint)
		local size = Vector3.new(gridSize, gridSize, gridSize)
		return cframe, size
	end

	return build_box_from_two_points(createAnchor, currentPoint, gridSize)
end

local function get_wall_preview_cframe_and_size(): (CFrame?, Vector3?)
	local currentPoint = get_snapped_hit_position()

	if not currentPoint then
		return nil, nil
	end

	currentPoint = snap_wall_point(currentPoint)

	local height = math.max(1, wallHeight)
	local thickness = math.max(0.25, wallThickness)

	if not wallAnchor then
		local size = Vector3.new(thickness, height, gridSize)
		local cframe = CFrame.lookAt(
			currentPoint + Vector3.new(0, height / 2, 0),
			currentPoint + Vector3.new(0, height / 2, -1)
		)

		return cframe, size
	end

	return build_wall_from_points(wallAnchor, currentPoint, height, thickness)
end

local function hide_preview(): ()
	local part = ensure_preview_part()
	part.Transparency = 1
	part.CanQuery = false
end

local function show_preview(cframe: CFrame, size: Vector3): ()
	local part = ensure_preview_part()
	part.Transparency = PREVIEW_TRANSPARENCY
	part.Size = size
	part.CFrame = cframe
	part.Color = buildColor
	part.CanQuery = false
end

local function refresh_preview(): ()
	if not is_master() or not is_sidebar_visible() then
		hide_preview()
		return
	end

	if toolMode == TOOL_MODE_NONE or toolMode == TOOL_MODE_SELECT then
		hide_preview()
		return
	end

	if toolMode == TOOL_MODE_CREATE then
		local cframe, size = get_create_preview_cframe_and_size()

		if cframe and size then
			show_preview(cframe, size)
			return
		end
	end

	if toolMode == TOOL_MODE_WALL then
		local cframe, size = get_wall_preview_cframe_and_size()

		if cframe and size then
			show_preview(cframe, size)
			return
		end
	end

	hide_preview()
end

local function set_tool_mode(newMode: string): ()
	createAnchor = nil
	wallAnchor = nil
	clear_selection()

	if toolMode == newMode then
		toolMode = TOOL_MODE_NONE
	else
		toolMode = newMode
	end

	if toolMode == TOOL_MODE_NONE then
		set_status("Modo livre")
	elseif toolMode == TOOL_MODE_SELECT then
		set_status("Modo seleção")
	elseif toolMode == TOOL_MODE_CREATE then
		set_status("Modo criação 3D")
	elseif toolMode == TOOL_MODE_WALL then
		set_status("Modo parede")
	end

	update_mode_buttons()
	update_handles_for_selection()
	refresh_preview()
end

local function apply_inputs_to_state(): ()
	gridSize = sanitize_text_number(gridBox and gridBox.Text or tostring(DEFAULT_GRID_SIZE), DEFAULT_GRID_SIZE, 0.25)
	wallHeight = sanitize_text_number(wallHeightBox and wallHeightBox.Text or tostring(DEFAULT_WALL_HEIGHT), DEFAULT_WALL_HEIGHT, 1)
	wallThickness = sanitize_text_number(wallThicknessBox and wallThicknessBox.Text or tostring(DEFAULT_WALL_THICKNESS), DEFAULT_WALL_THICKNESS, 0.25)

	local sizeX = sanitize_text_number(sizeXBox and sizeXBox.Text or tostring(DEFAULT_CREATE_SIZE.X), DEFAULT_CREATE_SIZE.X, 1)
	local sizeY = sanitize_text_number(sizeYBox and sizeYBox.Text or tostring(DEFAULT_CREATE_SIZE.Y), DEFAULT_CREATE_SIZE.Y, 1)
	local sizeZ = sanitize_text_number(sizeZBox and sizeZBox.Text or tostring(DEFAULT_CREATE_SIZE.Z), DEFAULT_CREATE_SIZE.Z, 1)

	createSize = Vector3.new(sizeX, sizeY, sizeZ)
	buildColor = read_color_from_boxes()

	sync_boxes_from_state()
	refresh_preview()
end

local function create_current_preview_part(): ()
	local part = ensure_preview_part()

	if part.Transparency >= 1 then
		return
	end

	fire_build("CreatePart", {
		Size = part.Size,
		CFrame = part.CFrame,
		Color = buildColor,
		BuildKind = toolMode == TOOL_MODE_WALL and "Wall" or "Part",
	})
end

local function delete_selected_target(): ()
	if toolMode ~= TOOL_MODE_SELECT then
		return
	end

	if selectedKind == "Part" and selectedPart and is_valid_selected_part(selectedPart) then
		fire_build("DeletePart", {
			Part = selectedPart,
		})
	end

	clear_selection()
end

local function apply_color_to_selected_part(): ()
	if toolMode ~= TOOL_MODE_SELECT then
		return
	end

	if not selectedPart or not is_valid_selected_part(selectedPart) then
		clear_selection()
		return
	end

	apply_inputs_to_state()

	fire_build("UpdatePart", {
		Part = selectedPart,
		Color = buildColor,
	})
end

local function handle_select_click(part: BasePart?, targetPlayer: Player?): ()
	if part then
		set_selected_part(part)
		return
	end

	if targetPlayer then
		set_selected_player(targetPlayer)
		start_player_mouse_drag(targetPlayer)
		return
	end

	clear_selection()
	set_status("Nada selecionado")
end

local function handle_create_click(): ()
	local currentPoint = get_snapped_hit_position()

	if not currentPoint then
		return
	end

	if not createAnchor then
		createAnchor = currentPoint
		set_status("Criar: escolha o segundo ponto")
		refresh_preview()
		return
	end

	create_current_preview_part()
	createAnchor = nil
	set_status("Peça criada")
	refresh_preview()
end

local function handle_wall_click(): ()
	local currentPoint = get_snapped_hit_position()

	if not currentPoint then
		return
	end

	currentPoint = snap_wall_point(currentPoint)

	if not wallAnchor then
		wallAnchor = currentPoint
		set_status("Parede: escolha o ponto final")
		refresh_preview()
		return
	end

	create_current_preview_part()
	wallAnchor = nil
	set_status("Parede criada")
	refresh_preview()
end

local function handle_world_left_click(): ()
	if not is_master() then
		return
	end

	if is_pointer_over_gui() or gizmoHoverCount > 0 or gizmoDragging then
		return
	end

	local kind, part, targetPlayer = resolve_click_target()
	local canSelectPlayers = toolMode == TOOL_MODE_NONE or toolMode == TOOL_MODE_SELECT or not is_sidebar_visible()

	if kind == "Player" and targetPlayer and canSelectPlayers then
		set_selected_player(targetPlayer)
		start_player_mouse_drag(targetPlayer)
		return
	end

	if not is_sidebar_visible() then
		if kind == "" then
			clear_selection()
		end

		return
	end

	apply_inputs_to_state()

	if toolMode == TOOL_MODE_SELECT then
		handle_select_click(part, nil)
		return
	end

	if toolMode == TOOL_MODE_CREATE then
		handle_create_click()
		return
	end

	if toolMode == TOOL_MODE_WALL then
		handle_wall_click()
		return
	end

	if kind == "" then
		clear_selection()
		return
	end

	clear_selection()
end

local function apply_size_to_selected_part(): ()
	if toolMode ~= TOOL_MODE_SELECT then
		return
	end

	if not selectedPart or not is_valid_selected_part(selectedPart) then
		clear_selection()
		return
	end

	apply_inputs_to_state()

	fire_build("UpdatePart", {
		Part = selectedPart,
		Size = Vector3.new(createSize.X, createSize.Y, createSize.Z),
	})
end

local function begin_drag(modeName: string, face: Enum.NormalId): ()
	gizmoDragging = true
	dragMode = modeName
	dragFace = face
	dragAxis = nil
	lastDragSend = 0

	if selectedKind == "Part" and selectedPart and is_valid_selected_part(selectedPart) then
		dragBasePartCFrame = selectedPart.CFrame
		dragBasePartSize = selectedPart.Size
		dragBasePlayerCFrame = nil
		return
	end

	if selectedKind == "Player" and selectedPlayer and is_valid_selected_player(selectedPlayer) then
		local rootPart = get_root_part_for_player(selectedPlayer)

		if rootPart then
			dragBasePlayerCFrame = rootPart.CFrame
		end

		dragBasePartCFrame = nil
		dragBasePartSize = nil
		stop_player_mouse_drag()
	end
end

local function begin_rotate(axis: Enum.Axis): ()
	gizmoDragging = true
	dragMode = "Rotate"
	dragAxis = axis
	dragFace = nil
	lastDragSend = 0

	if selectedPart and is_valid_selected_part(selectedPart) then
		dragBasePartCFrame = selectedPart.CFrame
	end
end

local function maybe_send_drag_update(nowTime: number, callback: () -> ()): ()
	if nowTime - lastDragSend < DRAG_SEND_INTERVAL then
		return
	end

	lastDragSend = nowTime
	callback()
end

local function update_selected_part_from_drag(distance: number): ()
	if not selectedPart or not is_valid_selected_part(selectedPart) or not dragBasePartCFrame or not dragBasePartSize or not dragFace then
		clear_selection()
		return
	end

	local snappedDistance = snap_number(distance, gridSize)
	local axisVector = vector_from_normal_id(dragFace, dragBasePartCFrame)

	if dragMode == "Move" then
		local newCFrame = dragBasePartCFrame + axisVector * snappedDistance

		maybe_send_drag_update(time(), function()
			fire_build("UpdatePart", {
				Part = selectedPart,
				CFrame = newCFrame,
			})
		end)

		return
	end

	if dragMode == "Resize" then
		local axisName = local_axis_name_from_normal(dragFace)
		local newSize = dragBasePartSize
		local centerShift = axisVector * (snappedDistance / 2)

		if axisName == "X" then
			newSize = Vector3.new(math.max(1, dragBasePartSize.X + snappedDistance), dragBasePartSize.Y, dragBasePartSize.Z)
		elseif axisName == "Y" then
			newSize = Vector3.new(dragBasePartSize.X, math.max(1, dragBasePartSize.Y + snappedDistance), dragBasePartSize.Z)
		else
			newSize = Vector3.new(dragBasePartSize.X, dragBasePartSize.Y, math.max(1, dragBasePartSize.Z + snappedDistance))
		end

		local newCFrame = dragBasePartCFrame + centerShift

		maybe_send_drag_update(time(), function()
			fire_build("UpdatePart", {
				Part = selectedPart,
				Size = newSize,
				CFrame = newCFrame,
			})
		end)
	end
end

local function update_selected_player_from_drag(distance: number): ()
	if not selectedPlayer or not is_valid_selected_player(selectedPlayer) or not dragBasePlayerCFrame or not dragFace then
		clear_selection()
		return
	end

	local snappedDistance = snap_number(distance, gridSize)
	local axisVector = vector_from_player_normal_id(dragFace, dragBasePlayerCFrame)
	local newCFrame = dragBasePlayerCFrame + axisVector * snappedDistance

	maybe_send_drag_update(time(), function()
		fire_build("MovePlayer", {
			UserId = selectedPlayer.UserId,
			CFrame = newCFrame,
		})
	end)
end

local function update_selected_part_rotation(relativeAngle: number): ()
	if not selectedPart or not is_valid_selected_part(selectedPart) or not dragBasePartCFrame or not dragAxis then
		clear_selection()
		return
	end

	local snappedDegrees = snap_number(math.deg(relativeAngle), ROTATION_STEP_DEGREES)
	local snappedAngle = math.rad(snappedDegrees)
	local rotation = rotation_cframe_from_axis(dragAxis, snappedAngle)
	local newCFrame = dragBasePartCFrame * rotation

	maybe_send_drag_update(time(), function()
		fire_build("UpdatePart", {
			Part = selectedPart,
			CFrame = newCFrame,
		})
	end)
end

local function connect_handles(): ()
	if handlesConnected then
		return
	end

	ensure_handles()
	handlesConnected = true

	if moveHandles then
		moveHandles.MouseEnter:Connect(function()
			gizmoHoverCount += 1
		end)

		moveHandles.MouseLeave:Connect(function()
			gizmoHoverCount = math.max(0, gizmoHoverCount - 1)
		end)

		moveHandles.MouseButton1Down:Connect(function(face: Enum.NormalId)
			begin_drag("Move", face)
		end)

		moveHandles.MouseButton1Up:Connect(function()
			finish_gizmo_drag()
		end)

		moveHandles.MouseDrag:Connect(function(face: Enum.NormalId, distance: number)
			if selectedKind == "Part" then
				update_selected_part_from_drag(distance)
				return
			end

			if selectedKind == "Player" then
				update_selected_player_from_drag(distance)
			end
		end)
	end

	if resizeHandles then
		resizeHandles.MouseEnter:Connect(function()
			gizmoHoverCount += 1
		end)

		resizeHandles.MouseLeave:Connect(function()
			gizmoHoverCount = math.max(0, gizmoHoverCount - 1)
		end)

		resizeHandles.MouseButton1Down:Connect(function(face: Enum.NormalId)
			begin_drag("Resize", face)
		end)

		resizeHandles.MouseButton1Up:Connect(function()
			finish_gizmo_drag()
		end)

		resizeHandles.MouseDrag:Connect(function(face: Enum.NormalId, distance: number)
			if selectedKind == "Part" then
				update_selected_part_from_drag(distance)
			end
		end)
	end

	if rotateHandles then
		rotateHandles.MouseEnter:Connect(function()
			gizmoHoverCount += 1
		end)

		rotateHandles.MouseLeave:Connect(function()
			gizmoHoverCount = math.max(0, gizmoHoverCount - 1)
		end)

		rotateHandles.MouseButton1Down:Connect(function(axis: Enum.Axis)
			begin_rotate(axis)
		end)

		rotateHandles.MouseButton1Up:Connect(function()
			finish_gizmo_drag()
		end)

		rotateHandles.MouseDrag:Connect(function(axis: Enum.Axis, relativeAngle: number)
			if selectedKind == "Part" then
				dragAxis = axis
				update_selected_part_rotation(relativeAngle)
			end
		end)
	end
end

local function connect_buttons(): ()
	if buttonsConnected then
		return
	end

	if not buildToggleButton or not buildSidebar then
		return
	end

	buttonsConnected = true

	buildToggleButton.MouseButton1Click:Connect(function()
		buildSidebar.Visible = not buildSidebar.Visible

		if not buildSidebar.Visible then
			createAnchor = nil
			wallAnchor = nil

			if selectedKind ~= "Player" then
				clear_selection()
			else
				hide_preview()
				update_handles_for_selection()
			end
		else
			refresh_preview()
		end
	end)

	if selectModeButton then
		selectModeButton.MouseButton1Click:Connect(function()
			set_tool_mode(TOOL_MODE_SELECT)
		end)
	end

	if createModeButton then
		createModeButton.MouseButton1Click:Connect(function()
			set_tool_mode(TOOL_MODE_CREATE)
		end)
	end

	if wallModeButton then
		wallModeButton.MouseButton1Click:Connect(function()
			set_tool_mode(TOOL_MODE_WALL)
		end)
	end

	if deleteButton then
		deleteButton.MouseButton1Click:Connect(function()
			delete_selected_target()
		end)
	end

	if applySizeButton then
		applySizeButton.MouseButton1Click:Connect(function()
			apply_inputs_to_state()

			if toolMode == TOOL_MODE_SELECT and selectedKind == "Part" then
				apply_size_to_selected_part()
				return
			end

			set_status("Valores atualizados")
		end)
	end

	if applyColorButton then
		applyColorButton.MouseButton1Click:Connect(function()
			apply_inputs_to_state()

			if toolMode == TOOL_MODE_SELECT and selectedKind == "Part" then
				apply_color_to_selected_part()
				return
			end

			refresh_preview()
			set_status("Cor atualizada")
		end)
	end

	if wallHeightMinusButton then
		wallHeightMinusButton.MouseButton1Click:Connect(function()
			apply_inputs_to_state()
			wallHeight = math.max(1, wallHeight - WALL_HEIGHT_STEP)
			sync_boxes_from_state()
			refresh_preview()
		end)
	end

	if wallHeightPlusButton then
		wallHeightPlusButton.MouseButton1Click:Connect(function()
			apply_inputs_to_state()
			wallHeight += WALL_HEIGHT_STEP
			sync_boxes_from_state()
			refresh_preview()
		end)
	end
end

local function on_gui_added(child: Instance): ()
	if child.Name ~= GUI_NAME then
		return
	end

	buttonsConnected = false

	task.defer(function()
		cache_gui_objects()
		sync_boxes_from_state()
		update_mode_buttons()
		connect_buttons()
		refresh_preview()
	end)
end

local function reset_when_role_changes(): ()
	createAnchor = nil
	wallAnchor = nil
	clear_selection()
	hide_preview()
end

------------------//MAIN FUNCTIONS
RunService.RenderStepped:Connect(function()
	validate_selection()
	update_player_mouse_drag()
	update_hover_highlight()
	refresh_preview()
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		handle_world_left_click()
		return
	end

	if input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.Backspace then
		delete_selected_target()
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		createAnchor = nil
		wallAnchor = nil
		clear_selection()
		refresh_preview()
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftBracket then
		apply_inputs_to_state()
		wallHeight = math.max(1, wallHeight - WALL_HEIGHT_STEP)
		sync_boxes_from_state()
		refresh_preview()
		return
	end

	if input.KeyCode == Enum.KeyCode.RightBracket then
		apply_inputs_to_state()
		wallHeight += WALL_HEIGHT_STEP
		sync_boxes_from_state()
		refresh_preview()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		stop_player_mouse_drag()
	end
end)

player:GetPropertyChangedSignal("Team"):Connect(function()
	reset_when_role_changes()
	cache_gui_objects()
	connect_buttons()
	update_mode_buttons()
end)

playerGui.ChildAdded:Connect(on_gui_added)

------------------//INIT
cache_gui_objects()
sync_boxes_from_state()
ensure_preview_part()
ensure_highlight()
ensure_hover_highlight()
ensure_handles()
connect_handles()
connect_buttons()
update_mode_buttons()
hide_preview()
clear_selection()
clear_hover_highlight()
set_status("Modo livre")