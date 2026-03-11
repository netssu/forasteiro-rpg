local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService: UserInputService = game:GetService("UserInputService")
local RunService: RunService = game:GetService("RunService")

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
local TOOL_MODE_LIGHT: string = "Light"

local DEFAULT_GRID_SIZE: number = 1
local DEFAULT_WALL_HEIGHT: number = 12
local DEFAULT_WALL_THICKNESS: number = 1
local DEFAULT_CREATE_SIZE: Vector3 = Vector3.new(8, 4, 8)
local DEFAULT_COLOR: Color3 = Color3.fromRGB(163, 162, 165)
local DEFAULT_LIGHT_COLOR: Color3 = Color3.fromRGB(255, 253, 224)
local PLAYER_TEAM_NAME: string = "Jogador"
local PLAYER_SPECTATOR_ATTRIBUTE_NAME: string = "PlayerSpectatorEnabled"

local PREVIEW_TRANSPARENCY: number = 0.45
local ROTATION_STEP_DEGREES: number = 15
local DRAG_SEND_INTERVAL: number = 0.03
local WALL_HEIGHT_STEP: number = 1
local WALL_ENDPOINT_SNAP_DISTANCE: number = 5

local ACTIVE_BUTTON_COLOR: Color3 = Color3.fromRGB(219, 184, 74)
local INACTIVE_BUTTON_COLOR: Color3 = Color3.fromRGB(34, 36, 44)

local KEY_MAP: {[Enum.KeyCode]: number} = {
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
local lightModeButton: TextButton? = nil
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
local lightRangeBox: TextBox? = nil
local lightBrightnessBox: TextBox? = nil

local toolMode: string = TOOL_MODE_NONE
local gridSize: number = DEFAULT_GRID_SIZE
local wallHeight: number = DEFAULT_WALL_HEIGHT
local wallThickness: number = DEFAULT_WALL_THICKNESS
local createSize: Vector3 = DEFAULT_CREATE_SIZE
local buildColor: Color3 = DEFAULT_COLOR
local lightRange: number = 20
local lightBrightness: number = 2

local previewPart: Part? = nil
local highlight: Highlight? = nil
local hoverHighlight: Highlight? = nil
local moveHandles: Handles? = nil
local resizeHandles: Handles? = nil
local rotateHandles: ArcHandles? = nil

local selectedKind: string = ""
local selectedPart: BasePart? = nil
local selectedCharacter: Model? = nil

local createAnchor: Vector3? = nil
local wallAnchor: Vector3? = nil

local dragMode: string = ""
local dragFace: Enum.NormalId? = nil
local dragAxis: Enum.Axis? = nil
local dragBasePartCFrame: CFrame? = nil
local dragBasePartSize: Vector3? = nil
local dragBaseCharacterCFrame: CFrame? = nil
local lastDragSend: number = 0

local gizmoDragging: boolean = false
local buttonsConnected: boolean = false
local handlesConnected: boolean = false

local characterMouseDragActive: boolean = false
local characterMouseDragTarget: Model? = nil
local characterMouseDragPlaneY: number = 0
local characterMouseDragOffset: Vector3 = Vector3.zero
local lastCharacterMouseDragSend: number = 0

local kind, part, targetCharacter

local function is_master(): boolean
	return player.Team ~= nil and player.Team.Name == MASTER_TEAM_NAME
end

local function is_player_spectator_drag_enabled(): boolean
	return player.Team ~= nil
		and player.Team.Name == PLAYER_TEAM_NAME
		and player:GetAttribute(PLAYER_SPECTATOR_ATTRIBUTE_NAME) == true
end

local function can_use_character_drag(): boolean
	return is_master() or is_player_spectator_drag_enabled()
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
	if not part then return false end
	local buildFolder = get_build_folder()
	if not buildFolder then return false end
	return part.Parent == buildFolder and part:GetAttribute("IsTabletopBuildPart") == true
end

local function is_valid_selected_character(targetCharacter: Model?): boolean
	if not targetCharacter then return false end
	local charactersFolder = workspace:FindFirstChild("Characters")
	return charactersFolder and targetCharacter.Parent == charactersFolder
end

local function can_drag_character(targetCharacter: Model?): boolean
	if not targetCharacter then
		return false
	end

	if is_master() then
		return is_valid_selected_character(targetCharacter)
	end

	return is_player_spectator_drag_enabled() and targetCharacter == player.Character
end


local function fire_build(action: string, payload: any?): ()
	local request = payload or {}
	request.Action = action
	masterBuildEvent:FireServer(request)
end

local function sanitize_text_number(text: string, fallback: number, minimum: number): number
	local numberValue = tonumber(text)
	if not numberValue then return fallback end
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
	if normalId == Enum.NormalId.Right then return cframe.RightVector end
	if normalId == Enum.NormalId.Left then return -cframe.RightVector end
	if normalId == Enum.NormalId.Top then return cframe.UpVector end
	if normalId == Enum.NormalId.Bottom then return -cframe.UpVector end
	if normalId == Enum.NormalId.Front then return cframe.LookVector end
	return -cframe.LookVector
end

local function vector_from_character_normal_id(normalId: Enum.NormalId, cframe: CFrame): Vector3
	if normalId == Enum.NormalId.Right then return cframe.RightVector end
	if normalId == Enum.NormalId.Left then return -cframe.RightVector end
	if normalId == Enum.NormalId.Top then return cframe.UpVector end
	if normalId == Enum.NormalId.Bottom then return -cframe.UpVector end
	if normalId == Enum.NormalId.Front then return cframe.LookVector end
	return -cframe.LookVector
end

local function local_axis_name_from_normal(normalId: Enum.NormalId): string
	if normalId == Enum.NormalId.Right or normalId == Enum.NormalId.Left then return "X" end
	if normalId == Enum.NormalId.Top or normalId == Enum.NormalId.Bottom then return "Y" end
	return "Z"
end

local function rotation_cframe_from_axis(axis: Enum.Axis, angle: number): CFrame
	if axis == Enum.Axis.X then return CFrame.Angles(angle, 0, 0) end
	if axis == Enum.Axis.Y then return CFrame.Angles(0, angle, 0) end
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
	lightModeButton = buildBody and buildBody:FindFirstChild("LightModeButton") or nil
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
	lightRangeBox = buildBody and buildBody:FindFirstChild("LightRangeBox") or nil
	lightBrightnessBox = buildBody and buildBody:FindFirstChild("LightBrightnessBox") or nil
end

local function sync_boxes_from_state(): ()
	if sizeXBox then sizeXBox.Text = tostring(createSize.X) end
	if sizeYBox then sizeYBox.Text = tostring(createSize.Y) end
	if sizeZBox then sizeZBox.Text = tostring(createSize.Z) end
	if gridBox then gridBox.Text = tostring(gridSize) end
	if wallHeightBox then wallHeightBox.Text = tostring(wallHeight) end
	if wallThicknessBox then wallThicknessBox.Text = tostring(wallThickness) end
	if colorRBox then colorRBox.Text = tostring(clamp_color_channel(buildColor.R * 255)) end
	if colorGBox then colorGBox.Text = tostring(clamp_color_channel(buildColor.G * 255)) end
	if colorBBox then colorBBox.Text = tostring(clamp_color_channel(buildColor.B * 255)) end
	if lightRangeBox then lightRangeBox.Text = tostring(lightRange) end
	if lightBrightnessBox then lightBrightnessBox.Text = tostring(lightBrightness) end
end

local function read_color_from_boxes(): Color3
	local r = sanitize_text_number(colorRBox and colorRBox.Text or "163", 163, 0)
	local g = sanitize_text_number(colorGBox and colorGBox.Text or "162", 162, 0)
	local b = sanitize_text_number(colorBBox and colorBBox.Text or "165", 165, 0)
	return Color3.fromRGB(clamp_color_channel(r), clamp_color_channel(g), clamp_color_channel(b))
end

local function sync_color_boxes_from_part(part: BasePart): ()
	buildColor = part.Color
	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		lightRange = light.Range
		lightBrightness = light.Brightness
	end
	sync_boxes_from_state()
end

local function set_status(text: string): ()
	if statusLabel then statusLabel.Text = text end
end

local function get_ordered_modes(): {string}
	local activeModes = {}

	if selectModeButton then table.insert(activeModes, {btn = selectModeButton, mode = TOOL_MODE_SELECT}) end
	if createModeButton then table.insert(activeModes, {btn = createModeButton, mode = TOOL_MODE_CREATE}) end
	if wallModeButton then table.insert(activeModes, {btn = wallModeButton, mode = TOOL_MODE_WALL}) end
	if lightModeButton then table.insert(activeModes, {btn = lightModeButton, mode = TOOL_MODE_LIGHT}) end

	table.sort(activeModes, function(a, b)
		return a.btn.AbsolutePosition.Y < b.btn.AbsolutePosition.Y
	end)

	local ordered = {}
	for _, item in ipairs(activeModes) do
		table.insert(ordered, item.mode)
	end
	return ordered
end

local function update_mode_buttons(): ()
	if selectModeButton then selectModeButton.BackgroundColor3 = toolMode == TOOL_MODE_SELECT and ACTIVE_BUTTON_COLOR or INACTIVE_BUTTON_COLOR end
	if createModeButton then createModeButton.BackgroundColor3 = toolMode == TOOL_MODE_CREATE and ACTIVE_BUTTON_COLOR or INACTIVE_BUTTON_COLOR end
	if wallModeButton then wallModeButton.BackgroundColor3 = toolMode == TOOL_MODE_WALL and ACTIVE_BUTTON_COLOR or INACTIVE_BUTTON_COLOR end
	if lightModeButton then lightModeButton.BackgroundColor3 = toolMode == TOOL_MODE_LIGHT and ACTIVE_BUTTON_COLOR or INACTIVE_BUTTON_COLOR end
end

local function get_root_part_for_character(character: Model): BasePart?
	if not character then return nil end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end
	return nil
end

local function stop_character_mouse_drag(): ()
	characterMouseDragActive = false
	characterMouseDragTarget = nil
	characterMouseDragPlaneY = 0
	characterMouseDragOffset = Vector3.zero
	lastCharacterMouseDragSend = 0
end

local function finish_gizmo_drag(): ()
	gizmoDragging = false
	dragMode = ""
	dragFace = nil
	dragAxis = nil
	dragBasePartCFrame = nil
	dragBasePartSize = nil
	dragBaseCharacterCFrame = nil
	lastDragSend = 0
end

local function clear_selection(): ()
	selectedKind = ""
	selectedPart = nil
	selectedCharacter = nil
	finish_gizmo_drag()
	stop_character_mouse_drag()

	local currentHighlight = ensure_highlight()
	currentHighlight.Adornee = nil

	ensure_handles()

	if moveHandles then moveHandles.Adornee = nil end
	if resizeHandles then resizeHandles.Adornee = nil end
	if rotateHandles then rotateHandles.Adornee = nil end

	clear_hover_highlight()
end

local function validate_selection(): ()
	if selectedKind == "Part" and not is_valid_selected_part(selectedPart) then
		clear_selection()
		return
	end

	if selectedKind == "Character" and not is_valid_selected_character(selectedCharacter) then
		clear_selection()
	end
end

local function update_handles_for_selection(): ()
	local currentHighlight = ensure_highlight()
	ensure_handles()

	if selectedKind == "Character" and selectedCharacter then
		local rootPart = get_root_part_for_character(selectedCharacter)

		currentHighlight.Adornee = selectedCharacter

		if moveHandles then moveHandles.Adornee = rootPart end
		if resizeHandles then resizeHandles.Adornee = nil end
		if rotateHandles then rotateHandles.Adornee = rootPart end

		set_status("Selecionado: personagem")
		return
	end

	if toolMode ~= TOOL_MODE_SELECT then
		currentHighlight.Adornee = nil
		clear_hover_highlight()

		if moveHandles then moveHandles.Adornee = nil end
		if resizeHandles then resizeHandles.Adornee = nil end
		if rotateHandles then rotateHandles.Adornee = nil end

		return
	end

	if selectedKind == "Part" and selectedPart then
		currentHighlight.Adornee = selectedPart

		if moveHandles then moveHandles.Adornee = selectedPart end
		if resizeHandles then resizeHandles.Adornee = selectedPart end
		if rotateHandles then rotateHandles.Adornee = selectedPart end

		set_status("Selecionado: parte")
		return
	end

	clear_selection()
end

local function set_selected_part(part: BasePart): ()
	selectedKind = "Part"
	selectedPart = part
	selectedCharacter = nil
	stop_character_mouse_drag()

	if sizeXBox then sizeXBox.Text = tostring(part.Size.X) end
	if sizeYBox then sizeYBox.Text = tostring(part.Size.Y) end
	if sizeZBox then sizeZBox.Text = tostring(part.Size.Z) end

	sync_color_boxes_from_part(part)
	update_handles_for_selection()
end

local function set_selected_character(targetCharacter: Model): ()
	selectedKind = "Character"
	selectedPart = nil
	selectedCharacter = targetCharacter
	update_handles_for_selection()
end

local function is_pointer_over_gui(): boolean
	local mouseLocation = UserInputService:GetMouseLocation()
	local guiObjects = playerGui:GetGuiObjectsAtPosition(mouseLocation.X, mouseLocation.Y)

	for _, guiObject in guiObjects do
		if masterGui and guiObject:IsDescendantOf(masterGui) then
			if guiObject.BackgroundTransparency < 1 or guiObject:IsA("TextButton") or guiObject:IsA("TextBox") then
				return true
			end
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

	if player.Character then table.insert(filterList, player.Character) end
	if previewPart then table.insert(filterList, previewPart) end

	local canSelectCharacters = toolMode == TOOL_MODE_NONE or toolMode == TOOL_MODE_SELECT or not is_sidebar_visible()
	if not canSelectCharacters then
		local hitboxesFolder = workspace:FindFirstChild("MasterHitboxes")
		if hitboxesFolder then
			table.insert(filterList, hitboxesFolder)
		end
	end

	raycastParams.FilterDescendantsInstances = filterList
	return workspace:Raycast(ray.Origin, ray.Direction * 4096, raycastParams)
end

local function resolve_click_target(): (string, BasePart?, Model?)
	local mouse = player:GetMouse()
	local instance = mouse.Target

	if not instance then return "", nil, nil end

	if instance:IsA("BasePart") then
		local targetVal = instance:FindFirstChild("TargetCharacter")
		if targetVal and targetVal:IsA("ObjectValue") and targetVal.Value then
			return "Character", nil, targetVal.Value
		end

		local buildFolder = get_build_folder()
		if buildFolder and instance.Parent == buildFolder and instance:GetAttribute("IsTabletopBuildPart") == true then
			return "Part", instance, nil
		end

		local model = instance:FindFirstAncestorOfClass("Model")
		if model then
			local charactersFolder = workspace:FindFirstChild("Characters")
			if charactersFolder and model.Parent == charactersFolder then
				return "Character", nil, model
			end
		end
	end

	return "", nil, nil
end

local function update_hover_highlight(): ()
	local currentHoverHighlight = ensure_hover_highlight()
	local hitboxesFolder = workspace:FindFirstChild("MasterHitboxes")

	if hitboxesFolder then
		for _, hb in hitboxesFolder:GetChildren() do
			if hb:IsA("BasePart") then
				hb.Transparency = 1
			end
		end
	end

	if not can_use_character_drag() then
		currentHoverHighlight.Adornee = nil
		return
	end

	if is_pointer_over_gui() or gizmoDragging then
		currentHoverHighlight.Adornee = nil
		return
	end

	local canHoverParts = is_sidebar_visible() and toolMode == TOOL_MODE_SELECT
	local canHoverCharacters = toolMode == TOOL_MODE_NONE or toolMode == TOOL_MODE_SELECT or not is_sidebar_visible()
	local a, b, c = resolve_click_target()

	kind = a
	part = b
	targetCharacter = c

	if a == "Part" and b and canHoverParts then
		if selectedKind == "Part" and selectedPart == b then
			currentHoverHighlight.Adornee = nil
			return
		end
		currentHoverHighlight.Adornee = b
		return
	end

	if a == "Character" and c and canHoverCharacters then
		if not can_drag_character(c) then
			currentHoverHighlight.Adornee = nil
			return
		end
	
		if hitboxesFolder then
			for _, hb in hitboxesFolder:GetChildren() do
				local targetVal = hb:FindFirstChild("TargetCharacter")
				if targetVal and targetVal.Value == c then
					hb.Transparency = 0.8
					hb.Color = Color3.fromRGB(120, 200, 255)
					hb.Material = Enum.Material.ForceField
					break
				end
			end
		end

		if selectedKind == "Character" and selectedCharacter == c then
			currentHoverHighlight.Adornee = nil
			return
		end

		currentHoverHighlight.Adornee = c
		return
	end

	currentHoverHighlight.Adornee = nil
end

local function get_snapped_hit_position(): Vector3?
	local raycastResult = build_raycast_result()
	if not raycastResult then return nil end
	return snap_vector3(raycastResult.Position, gridSize)
end

local function get_mouse_point_on_horizontal_plane(planeY: number): Vector3?
	local currentCamera = get_current_camera()
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = currentCamera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	if math.abs(ray.Direction.Y) < 0.0001 then return nil end

	local t = (planeY - ray.Origin.Y) / ray.Direction.Y
	if t <= 0 then return nil end

	return ray.Origin + ray.Direction * t
end

local function start_character_mouse_drag(targetCharacter: Model): ()
	if not can_drag_character(targetCharacter) then
		return
	end
	
	local rootPart = get_root_part_for_character(targetCharacter)
	if not rootPart then return end

	local planePoint = get_mouse_point_on_horizontal_plane(rootPart.Position.Y)
	if not planePoint then return end

	characterMouseDragActive = true
	characterMouseDragTarget = targetCharacter
	characterMouseDragPlaneY = rootPart.Position.Y
	characterMouseDragOffset = rootPart.Position - Vector3.new(planePoint.X, rootPart.Position.Y, planePoint.Z)
	lastCharacterMouseDragSend = 0
end

local function update_character_mouse_drag(): ()
	if not characterMouseDragActive or not characterMouseDragTarget then return end

	if not can_drag_character(characterMouseDragTarget) then
		stop_character_mouse_drag()
		return
	end

	if not is_valid_selected_character(characterMouseDragTarget) then
		clear_selection()
		return
	end

	local rootPart = get_root_part_for_character(characterMouseDragTarget)
	if not rootPart then
		clear_selection()
		return
	end

	local planePoint = get_mouse_point_on_horizontal_plane(characterMouseDragPlaneY)
	if not planePoint then return end

	local targetPosition = Vector3.new(
		snap_number(planePoint.X + characterMouseDragOffset.X, gridSize),
		characterMouseDragPlaneY,
		snap_number(planePoint.Z + characterMouseDragOffset.Z, gridSize)
	)

	local newCFrame = CFrame.new(targetPosition) * get_rotation_only_cframe(rootPart.CFrame)
	local nowTime = time()

	rootPart.CFrame = newCFrame

	if nowTime - lastCharacterMouseDragSend < DRAG_SEND_INTERVAL then return end

	lastCharacterMouseDragSend = nowTime

	fire_build("MoveCharacter", {
		Character = characterMouseDragTarget,
		CFrame = newCFrame,
	})
end

local function get_wall_endpoint_candidates(): {Vector3}
	local buildFolder = get_build_folder()
	if not buildFolder then return {} end

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
	if not currentPoint then return nil, nil end

	if not createAnchor then
		local cframe = CFrame.new(currentPoint + Vector3.new(0, gridSize / 2, 0))
		local size = Vector3.new(gridSize, gridSize, gridSize)
		return cframe, size
	end

	return build_box_from_two_points(createAnchor, currentPoint, gridSize)
end

local function get_wall_preview_cframe_and_size(): (CFrame?, Vector3?)
	local currentPoint = get_snapped_hit_position()
	if not currentPoint then return nil, nil end

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

local function get_light_preview_cframe_and_size(): (CFrame?, Vector3?)
	local currentPoint = get_snapped_hit_position()
	if not currentPoint then return nil, nil end
	local cframe = CFrame.new(currentPoint + Vector3.new(0, createSize.Y / 2, 0))
	return cframe, createSize
end

local function hide_preview(): ()
	local part = ensure_preview_part()
	part.Transparency = 1
	part.CanQuery = false
end

local function show_preview(cframe: CFrame, size: Vector3, isLight: boolean?): ()
	local part = ensure_preview_part()
	part.Transparency = PREVIEW_TRANSPARENCY
	part.Size = size
	part.CFrame = cframe
	part.Color = buildColor
	part.CanQuery = false
	part.Shape = Enum.PartType.Block

	if isLight then
		part.Material = Enum.Material.Neon
	else
		part.Material = Enum.Material.ForceField
	end
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

	if toolMode == TOOL_MODE_LIGHT then
		local cframe, size = get_light_preview_cframe_and_size()
		if cframe and size then
			show_preview(cframe, size, true)
			return
		end
	end

	hide_preview()
end

local function apply_inputs_to_state(): ()
	gridSize = sanitize_text_number(gridBox and gridBox.Text or tostring(DEFAULT_GRID_SIZE), DEFAULT_GRID_SIZE, 0.25)
	wallHeight = sanitize_text_number(wallHeightBox and wallHeightBox.Text or tostring(DEFAULT_WALL_HEIGHT), DEFAULT_WALL_HEIGHT, 1)
	wallThickness = sanitize_text_number(wallThicknessBox and wallThicknessBox.Text or tostring(DEFAULT_WALL_THICKNESS), DEFAULT_WALL_THICKNESS, 0.25)

	local sizeX = sanitize_text_number(sizeXBox and sizeXBox.Text or tostring(DEFAULT_CREATE_SIZE.X), DEFAULT_CREATE_SIZE.X, 1)
	local sizeY = sanitize_text_number(sizeYBox and sizeYBox.Text or tostring(DEFAULT_CREATE_SIZE.Y), DEFAULT_CREATE_SIZE.Y, 1)
	local sizeZ = sanitize_text_number(sizeZBox and sizeZBox.Text or tostring(DEFAULT_CREATE_SIZE.Z), DEFAULT_CREATE_SIZE.Z, 1)

	lightRange = sanitize_text_number(lightRangeBox and lightRangeBox.Text or "20", 20, 1)
	lightBrightness = sanitize_text_number(lightBrightnessBox and lightBrightnessBox.Text or "2", 2, 0)

	createSize = Vector3.new(sizeX, sizeY, sizeZ)
	buildColor = read_color_from_boxes()

	sync_boxes_from_state()
	refresh_preview()
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
	elseif toolMode == TOOL_MODE_LIGHT then
		set_status("Modo luz")
		if colorRBox then colorRBox.Text = tostring(math.floor(DEFAULT_LIGHT_COLOR.R * 255)) end
		if colorGBox then colorGBox.Text = tostring(math.floor(DEFAULT_LIGHT_COLOR.G * 255)) end
		if colorBBox then colorBBox.Text = tostring(math.floor(DEFAULT_LIGHT_COLOR.B * 255)) end
		apply_inputs_to_state()
	end

	update_mode_buttons()
	update_handles_for_selection()
	refresh_preview()
end

local function create_current_preview_part(): ()
	local part = ensure_preview_part()

	if part.Transparency >= 1 then
		return
	end

	local kind = "Part"
	if toolMode == TOOL_MODE_WALL then kind = "Wall" end
	if toolMode == TOOL_MODE_LIGHT then kind = "Light" end

	fire_build("CreatePart", {
		Size = part.Size,
		CFrame = part.CFrame,
		Color = buildColor,
		BuildKind = kind,
		LightRange = lightRange,
		LightBrightness = lightBrightness,
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
		LightRange = lightRange,
		LightBrightness = lightBrightness,
	})
end

local function handle_select_click(part: BasePart?, targetCharacter: Model?): ()
	if part then
		set_selected_part(part)
		return
	end

	if targetCharacter then
		set_selected_character(targetCharacter)
		start_character_mouse_drag(targetCharacter)
		return
	end

	clear_selection()
	set_status("Nada selecionado")
end

local function handle_create_click(): ()
	local currentPoint = get_snapped_hit_position()
	if not currentPoint then return end

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
	if not currentPoint then return end

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

local function handle_light_click(): ()
	local currentPoint = get_snapped_hit_position()
	if not currentPoint then return end

	create_current_preview_part()
	set_status("Luz criada")
	refresh_preview()
end

local function handle_world_left_click(): ()
	if not can_use_character_drag() and not is_master() then
		return
	end

	if is_pointer_over_gui() then
		return
	end

	if gizmoDragging then
		return
	end

	local canSelectCharacters = toolMode == TOOL_MODE_NONE or toolMode == TOOL_MODE_SELECT or not is_sidebar_visible()

	if kind == "" then
		clear_selection()
	end

	if kind == "Character" and targetCharacter and canSelectCharacters and can_drag_character(targetCharacter) then
		if selectedCharacter ~= targetCharacter then
			set_selected_character(targetCharacter)
		end
		start_character_mouse_drag(targetCharacter)
		return
	end

	if not is_master() then
		return
	end

	if not is_sidebar_visible() then
		clear_selection()
		return
	end

	apply_inputs_to_state()

	if toolMode == TOOL_MODE_SELECT then
		if kind == "Part" and part then
			handle_select_click(part, nil)
			return
		end
	end

	if toolMode == TOOL_MODE_CREATE then
		handle_create_click()
		return
	end

	if toolMode == TOOL_MODE_WALL then
		handle_wall_click()
		return
	end

	if toolMode == TOOL_MODE_LIGHT then
		handle_light_click()
		return
	end

	clear_selection()
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
		dragBaseCharacterCFrame = nil
		return
	end

	if selectedKind == "Character" and selectedCharacter and is_valid_selected_character(selectedCharacter) then
		local rootPart = get_root_part_for_character(selectedCharacter)
		if rootPart then
			dragBaseCharacterCFrame = rootPart.CFrame
		end

		dragBasePartCFrame = nil
		dragBasePartSize = nil
		stop_character_mouse_drag()
	end
end

local function begin_rotate(axis: Enum.Axis): ()
	gizmoDragging = true
	dragMode = "Rotate"
	dragAxis = axis
	dragFace = nil
	lastDragSend = 0

	if selectedKind == "Part" and selectedPart and is_valid_selected_part(selectedPart) then
		dragBasePartCFrame = selectedPart.CFrame
	elseif selectedKind == "Character" and selectedCharacter and is_valid_selected_character(selectedCharacter) then
		local rootPart = get_root_part_for_character(selectedCharacter)
		if rootPart then
			dragBasePartCFrame = rootPart.CFrame
		end
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

local function update_selected_character_from_drag(distance: number): ()
	if not selectedCharacter or not is_valid_selected_character(selectedCharacter) or not dragBaseCharacterCFrame or not dragFace then
		clear_selection()
		return
	end

	local snappedDistance = snap_number(distance, gridSize)
	local axisVector = vector_from_character_normal_id(dragFace, dragBaseCharacterCFrame)
	local newCFrame = dragBaseCharacterCFrame + axisVector * snappedDistance

	local rootPart = get_root_part_for_character(selectedCharacter)
	if rootPart then
		rootPart.CFrame = newCFrame
	end

	maybe_send_drag_update(time(), function()
		fire_build("MoveCharacter", {
			Character = selectedCharacter,
			CFrame = newCFrame,
		})
	end)
end

local function update_selected_part_rotation(relativeAngle: number): ()
	if not dragBasePartCFrame or not dragAxis then
		clear_selection()
		return
	end

	local snappedDegrees = snap_number(math.deg(relativeAngle), ROTATION_STEP_DEGREES)
	local snappedAngle = math.rad(snappedDegrees)
	local rotation = rotation_cframe_from_axis(dragAxis, snappedAngle)
	local newCFrame = dragBasePartCFrame * rotation

	if selectedKind == "Part" and selectedPart and is_valid_selected_part(selectedPart) then
		maybe_send_drag_update(time(), function()
			fire_build("UpdatePart", {
				Part = selectedPart,
				CFrame = newCFrame,
			})
		end)
	elseif selectedKind == "Character" and selectedCharacter and is_valid_selected_character(selectedCharacter) then
		local rootPart = get_root_part_for_character(selectedCharacter)
		if rootPart then
			rootPart.CFrame = newCFrame
		end
		maybe_send_drag_update(time(), function()
			fire_build("MoveCharacter", {
				Character = selectedCharacter,
				CFrame = newCFrame,
			})
		end)
	end
end

local function connect_handles(): ()
	if handlesConnected then return end

	ensure_handles()
	handlesConnected = true

	if moveHandles then
		moveHandles.MouseButton1Down:Connect(function(face: Enum.NormalId) begin_drag("Move", face) end)
		moveHandles.MouseButton1Up:Connect(function() finish_gizmo_drag() end)
		moveHandles.MouseDrag:Connect(function(face: Enum.NormalId, distance: number)
			if selectedKind == "Part" then update_selected_part_from_drag(distance) return end
			if selectedKind == "Character" then update_selected_character_from_drag(distance) end
		end)
	end

	if resizeHandles then
		resizeHandles.MouseButton1Down:Connect(function(face: Enum.NormalId) begin_drag("Resize", face) end)
		resizeHandles.MouseButton1Up:Connect(function() finish_gizmo_drag() end)
		resizeHandles.MouseDrag:Connect(function(face: Enum.NormalId, distance: number)
			if selectedKind == "Part" then update_selected_part_from_drag(distance) end
		end)
	end

	if rotateHandles then
		rotateHandles.MouseButton1Down:Connect(function(axis: Enum.Axis) begin_rotate(axis) end)
		rotateHandles.MouseButton1Up:Connect(function() finish_gizmo_drag() end)
		rotateHandles.MouseDrag:Connect(function(axis: Enum.Axis, relativeAngle: number)
			dragAxis = axis
			update_selected_part_rotation(relativeAngle)
		end)
	end
end

local function connect_buttons(): ()
	if buttonsConnected then return end
	if not buildToggleButton or not buildSidebar then return end

	buttonsConnected = true

	buildToggleButton.MouseButton1Click:Connect(function()
		buildSidebar.Visible = not buildSidebar.Visible

		if not buildSidebar.Visible then
			createAnchor = nil
			wallAnchor = nil

			if selectedKind ~= "Character" then
				clear_selection()
			else
				hide_preview()
				update_handles_for_selection()
			end
		else
			refresh_preview()
		end
	end)

	if selectModeButton then selectModeButton.MouseButton1Click:Connect(function() set_tool_mode(TOOL_MODE_SELECT) end) end
	if createModeButton then createModeButton.MouseButton1Click:Connect(function() set_tool_mode(TOOL_MODE_CREATE) end) end
	if wallModeButton then wallModeButton.MouseButton1Click:Connect(function() set_tool_mode(TOOL_MODE_WALL) end) end
	if lightModeButton then lightModeButton.MouseButton1Click:Connect(function() set_tool_mode(TOOL_MODE_LIGHT) end) end
	if deleteButton then deleteButton.MouseButton1Click:Connect(function() delete_selected_target() end) end

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
	if child.Name ~= GUI_NAME then return end

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

local function sync_master_hitboxes(): ()
	local hitboxesFolder = workspace:FindFirstChild("MasterHitboxes")

	if not can_use_character_drag() then
		if hitboxesFolder then
			hitboxesFolder:Destroy()
		end
		return
	end

	if not hitboxesFolder then
		hitboxesFolder = Instance.new("Folder")
		hitboxesFolder.Name = "MasterHitboxes"
		hitboxesFolder.Parent = workspace
	end

	local charsFolder = workspace:FindFirstChild("Characters")
	if not charsFolder then
		return
	end

	local processed = {}
	local hitboxesByChar = {}

	for _, hb in hitboxesFolder:GetChildren() do
		local targetVal = hb:FindFirstChild("TargetCharacter")
		if targetVal and targetVal.Value then
			hitboxesByChar[targetVal.Value] = hb
		end
	end

	for _, char in charsFolder:GetChildren() do
		if char:IsA("Model") then
			processed[char] = true
			local rootPart = char:FindFirstChild("HumanoidRootPart")

			if rootPart then
				local hitbox = hitboxesByChar[char]

				if not hitbox then
					hitbox = Instance.new("Part")
					hitbox.Name = "Hitbox"
					hitbox.Size = Vector3.new(5, 8, 5)
					hitbox.Transparency = 1
					hitbox.CanCollide = false
					hitbox.CanQuery = true
					hitbox.Massless = true
					hitbox.Shape = Enum.PartType.Block

					local targetVal = Instance.new("ObjectValue")
					targetVal.Name = "TargetCharacter"
					targetVal.Value = char
					targetVal.Parent = hitbox

					hitbox.Parent = hitboxesFolder
				end

				hitbox.CFrame = rootPart.CFrame
			end
		end
	end

	for _, hb in hitboxesFolder:GetChildren() do
		local targetVal = hb:FindFirstChild("TargetCharacter")
		if not targetVal or not targetVal.Value or not processed[targetVal.Value] then
			hb:Destroy()
		end
	end
end

------------------//MAIN FUNCTIONS
RunService.RenderStepped:Connect(function()
	sync_master_hitboxes()
	validate_selection()
	update_character_mouse_drag()
	update_hover_highlight()
	refresh_preview()
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end

	local keyIndex = KEY_MAP[input.KeyCode]
	if keyIndex and is_master() and is_sidebar_visible() then
		local orderedModes = get_ordered_modes()
		local selectedMode = orderedModes[keyIndex]

		if selectedMode then
			set_tool_mode(selectedMode)
		end
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
		stop_character_mouse_drag()
	end
end)

player:GetAttributeChangedSignal(PLAYER_SPECTATOR_ATTRIBUTE_NAME):Connect(function()
	createAnchor = nil
	wallAnchor = nil
	clear_selection()
	clear_hover_highlight()
	hide_preview()
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