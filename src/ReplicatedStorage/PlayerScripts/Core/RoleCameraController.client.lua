------------------//SERVICES
local Players: Players = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")
local Lighting: Lighting = game:GetService("Lighting")
local ContextActionService: ContextActionService = game:GetService("ContextActionService")
local GuiService: GuiService = game:GetService("GuiService")

------------------//CONSTANTS
local MASTER_TEAM_NAME: string = "Mestre"
local PLAYER_TEAM_NAME: string = "Jogador"
local CAMERA_PART_NAME: string = "TeamSelectionCameraPart"
local SPECTATOR_BIND_NAME: string = "MasterSpectatorCamera"
local BLUR_NAME: string = "TeamSelectBlur"

local PLAYER_HUD_NAME: string = "PlayerHud"
local MOUSE_UNLOCK_BUTTON_NAME: string = "MouseUnlockFrame"

local LOOK_SENSITIVITY: number = 0.003
local MOVE_SPEED: number = 36
local FAST_MOVE_SPEED: number = 90
local WHEEL_MOVE_STEP: number = 10
local MIN_PITCH: number = math.rad(-89)
local MAX_PITCH: number = math.rad(89)
local PLAYER_MOUSE_TOGGLE_KEY: Enum.KeyCode = Enum.KeyCode.P
local PLAYER_SPECTATOR_TOGGLE_KEY: Enum.KeyCode = Enum.KeyCode.L
local PLAYER_CAMERA_OFFSET_Y: number = 1
local PLAYER_BLOCK_MOVE_ACTION_NAME: string = "PlayerSpectatorBlockMove"

local PLAYER_SPECTATOR_ATTRIBUTE_NAME: string = "PlayerSpectatorEnabled"
local PLAYER_SPECTATOR_BUTTON_NAME: string = "SpectatorToggleButton"
local PLAYER_SPECTATOR_BUTTON_TEXT: string = "Espectador (L)"
local PLAYER_FIRST_PERSON_BUTTON_TEXT: string = "1ª Pessoa (L)"
local MASTER_SPECTATOR_JUMP_ATTRIBUTE_NAME: string = "MasterSpectatorJumpCFrame"

local PLAYER_SPECTATOR_BACK_DISTANCE: number = 14
local PLAYER_SPECTATOR_HEIGHT: number = 6

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local spectatorEnabled: boolean = false
local isRotatingCamera: boolean = false
local playerMouseFrameEnabled: boolean = false
local playerSpectatorRequested: boolean = false
local yaw: number = 0
local pitch: number = 0
local spectatorCFrame: CFrame = CFrame.new()

local playerHud: ScreenGui? = nil
local mouseUnlockFrame: TextButton? = nil
local spectatorToggleButton: TextButton? = nil

local inputState = {
	forward = false,
	backward = false,
	left = false,
	right = false,
	up = false,
	down = false,
	fast = false,
}

------------------//FUNCTIONS
local function get_current_camera(): Camera
	local currentCamera = workspace.CurrentCamera

	while not currentCamera do
		task.wait()
		currentCamera = workspace.CurrentCamera
	end

	return currentCamera
end

local function sink_player_move_action(
	_: string,
	_: Enum.UserInputState,
	_: InputObject
): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

local function is_master_role(): boolean
	return player.Team ~= nil and player.Team.Name == MASTER_TEAM_NAME
end

local function is_player_role(): boolean
	return player.Team ~= nil and player.Team.Name == PLAYER_TEAM_NAME
end

local function get_player_controls(): any
	local playerScripts = player:FindFirstChild("PlayerScripts")
	if not playerScripts then
		return nil
	end

	local playerModule = playerScripts:FindFirstChild("PlayerModule")
	if not playerModule then
		return nil
	end

	local okModule, module = pcall(require, playerModule)
	if not okModule then
		return nil
	end

	local okControls, controls = pcall(function()
		return module:GetControls()
	end)

	if okControls then
		return controls
	end

	return nil
end

local function set_character_rotation_locked(isLocked: boolean): ()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.AutoRotate = not isLocked
	end
end

local function set_character_movement_enabled(isEnabled: boolean): ()
	if isEnabled then
		ContextActionService:UnbindAction(PLAYER_BLOCK_MOVE_ACTION_NAME)

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:Move(Vector3.zero, true)
		end

		return
	end

	ContextActionService:BindActionAtPriority(
		PLAYER_BLOCK_MOVE_ACTION_NAME,
		sink_player_move_action,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.W,
		Enum.KeyCode.A,
		Enum.KeyCode.S,
		Enum.KeyCode.D,
		Enum.KeyCode.Up,
		Enum.KeyCode.Down,
		Enum.KeyCode.Left,
		Enum.KeyCode.Right,
		Enum.KeyCode.Space
	)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Move(Vector3.zero, true)
	end
end

local function cache_player_hud_objects(): ()
	local guiObject = playerGui:FindFirstChild(PLAYER_HUD_NAME)

	if not guiObject or not guiObject:IsA("ScreenGui") then
		playerHud = nil
		mouseUnlockFrame = nil
		spectatorToggleButton = nil
		return
	end

	playerHud = guiObject
	mouseUnlockFrame = playerHud:FindFirstChild("Main")
		and playerHud.Main:FindFirstChild(MOUSE_UNLOCK_BUTTON_NAME)
		or nil
end

local function update_mouse_unlock_frame(): ()
	cache_player_hud_objects()

	if not mouseUnlockFrame then
		return
	end

	mouseUnlockFrame.Visible = is_player_role() and playerMouseFrameEnabled or false
end

local function update_spectator_toggle_button(): ()
	cache_player_hud_objects()

	local main = playerHud and playerHud:FindFirstChild("Main")
	local topBar = main and main:FindFirstChild("TopBar")

	if not topBar or not topBar:IsA("Frame") then
		spectatorToggleButton = nil
		return
	end

	local button = playerGui:FindFirstChild(PLAYER_SPECTATOR_BUTTON_NAME,true)
	if not button then
		button = Instance.new("TextButton")
		button.Name = PLAYER_SPECTATOR_BUTTON_NAME
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -145, 0.5, 0)
		button.Size = UDim2.fromOffset(130, 30)
		button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		button.BackgroundTransparency = 0.15
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextSize = 14
		button.AutoButtonColor = true
		button.Parent = topBar

		button.MouseButton1Click:Connect(function()
			if not is_player_role() then
				return
			end

			player:SetAttribute(
				PLAYER_SPECTATOR_ATTRIBUTE_NAME,
				not playerSpectatorRequested
			)
		end)
	end

	if button:IsA("TextButton") then
		spectatorToggleButton = button
		spectatorToggleButton.Visible = is_player_role()
		spectatorToggleButton.Text = playerSpectatorRequested
			and PLAYER_FIRST_PERSON_BUTTON_TEXT
			or PLAYER_SPECTATOR_BUTTON_TEXT
	else
		spectatorToggleButton = nil
	end
end

local function disable_menu_blur(): ()
	local blur = Lighting:FindFirstChild(BLUR_NAME)

	if blur and blur:IsA("BlurEffect") then
		blur.Enabled = false
	end
end

local function reset_input_state(): ()
	inputState.forward = false
	inputState.backward = false
	inputState.left = false
	inputState.right = false
	inputState.up = false
	inputState.down = false
	inputState.fast = false
end

local function apply_mouse_state(): ()
	if spectatorEnabled then
		if isRotatingCamera then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end

		update_mouse_unlock_frame()
		return
	end

	if is_player_role() then
		if playerMouseFrameEnabled then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		end

		update_mouse_unlock_frame()
		return
	end

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	update_mouse_unlock_frame()
end

local function get_master_start_cframe(): CFrame
	local cameraPart = workspace:FindFirstChild(CAMERA_PART_NAME)

	if cameraPart and cameraPart:IsA("BasePart") then
		return cameraPart.CFrame
	end

	local currentCamera = get_current_camera()
	return currentCamera.CFrame
end

local function get_player_spectator_start_cframe(): CFrame
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	if rootPart and rootPart:IsA("BasePart") then
		local focusPosition = rootPart.Position + Vector3.new(0, PLAYER_CAMERA_OFFSET_Y, 0)
		local startPosition = focusPosition
		- rootPart.CFrame.LookVector * PLAYER_SPECTATOR_BACK_DISTANCE
			+ Vector3.new(0, PLAYER_SPECTATOR_HEIGHT, 0)

		return CFrame.lookAt(startPosition, focusPosition)
	end

	return get_current_camera().CFrame
end

local function move_spectator_by_look(distance: number): ()
	local rotation = CFrame.fromOrientation(pitch, yaw, 0)
	local newPosition = spectatorCFrame.Position + rotation.LookVector * distance
	spectatorCFrame = CFrame.new(newPosition) * rotation
end

local function update_spectator_camera(deltaTime: number): ()
	if not spectatorEnabled then
		return
	end

	local currentCamera = get_current_camera()

	if isRotatingCamera then
		local mouseDelta = UserInputService:GetMouseDelta()

		yaw -= mouseDelta.X * LOOK_SENSITIVITY
		pitch = math.clamp(pitch - mouseDelta.Y * LOOK_SENSITIVITY, MIN_PITCH, MAX_PITCH)
	end

	local rotation = CFrame.fromOrientation(pitch, yaw, 0)

	local moveLocal = Vector3.zero

	if inputState.forward then
		moveLocal += Vector3.new(0, 0, 1)
	end

	if inputState.backward then
		moveLocal += Vector3.new(0, 0, -1)
	end

	if inputState.left then
		moveLocal += Vector3.new(-1, 0, 0)
	end

	if inputState.right then
		moveLocal += Vector3.new(1, 0, 0)
	end

	if inputState.up then
		moveLocal += Vector3.new(0, 1, 0)
	end

	if inputState.down then
		moveLocal += Vector3.new(0, -1, 0)
	end

	if moveLocal.Magnitude > 0 then
		moveLocal = moveLocal.Unit
	end

	local speed = inputState.fast and FAST_MOVE_SPEED or MOVE_SPEED
	local worldMove = rotation.RightVector * moveLocal.X
		+ Vector3.new(0, 1, 0) * moveLocal.Y
		+ rotation.LookVector * moveLocal.Z

	local newPosition = spectatorCFrame.Position + worldMove * speed * deltaTime

	spectatorCFrame = CFrame.new(newPosition) * rotation

	currentCamera.CameraType = Enum.CameraType.Scriptable
	currentCamera.CFrame = spectatorCFrame
	currentCamera.Focus = spectatorCFrame * CFrame.new(0, 0, -10)
end

local function enable_spectator_mode(startCFrameOverride: CFrame?): ()
	if spectatorEnabled then
		return
	end

	disable_menu_blur()

	local currentCamera = get_current_camera()
	local startCFrame = startCFrameOverride or get_master_start_cframe()
	local startPitch, startYaw = startCFrame:ToOrientation()

	spectatorEnabled = true
	isRotatingCamera = false
	playerMouseFrameEnabled = false
	pitch = startPitch
	yaw = startYaw
	spectatorCFrame = startCFrame

	player.CameraMode = Enum.CameraMode.Classic
	currentCamera.CameraType = Enum.CameraType.Scriptable

	apply_mouse_state()

	RunService:BindToRenderStep(
		SPECTATOR_BIND_NAME,
		Enum.RenderPriority.Camera.Value + 2,
		update_spectator_camera
	)
end

local function disable_spectator_mode(): ()
	if not spectatorEnabled then
		return
	end

	spectatorEnabled = false
	isRotatingCamera = false

	RunService:UnbindFromRenderStep(SPECTATOR_BIND_NAME)

	reset_input_state()
	apply_mouse_state()
end

local function apply_player_camera_mode(): ()
	local currentCamera = get_current_camera()

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	currentCamera.CameraType = Enum.CameraType.Custom
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	player.CameraMode = Enum.CameraMode.LockFirstPerson

	if humanoid then
		humanoid.CameraOffset = Vector3.new(0, PLAYER_CAMERA_OFFSET_Y, 0)
	end

	apply_mouse_state()
end

local function enable_player_spectator(): ()
	disable_menu_blur()
	set_character_movement_enabled(false)
	set_character_rotation_locked(true)
	enable_spectator_mode(get_player_spectator_start_cframe())
end

local function enable_player_first_person(): ()
	disable_menu_blur()
	set_character_movement_enabled(true)
	set_character_rotation_locked(false)
	disable_spectator_mode()
	apply_player_camera_mode()
end

local function clear_role_camera_state(): ()
	disable_spectator_mode()
	set_character_movement_enabled(true)
	set_character_rotation_locked(false)

	playerMouseFrameEnabled = false
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 12

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.CameraOffset = Vector3.zero
	end

	apply_mouse_state()
end

local function update_role_state(): ()
	if is_master_role() then
		local char = player.Character
		if char and char:GetAttribute("IsNPC") then
			disable_spectator_mode()

			local currentCamera = get_current_camera()
			currentCamera.CameraType = Enum.CameraType.Custom
			player.CameraMinZoomDistance = 5
			player.CameraMaxZoomDistance = 15
			player.CameraMode = Enum.CameraMode.Classic

			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true

			update_spectator_toggle_button()
			return
		else
			enable_spectator_mode(get_master_start_cframe())
			update_spectator_toggle_button()
			return
		end
	end

	if is_player_role() then
		if playerSpectatorRequested then
			enable_player_spectator()
		else
			enable_player_first_person()
		end

		update_spectator_toggle_button()
		return
	end

	clear_role_camera_state()
	update_spectator_toggle_button()
end

local function jump_master_spectator_camera(targetCFrame: CFrame): ()
	if not is_master_role() then
		return
	end

	if not spectatorEnabled then
		enable_spectator_mode(targetCFrame)
		return
	end

	spectatorCFrame = targetCFrame
	local nextPitch, nextYaw = targetCFrame:ToOrientation()
	pitch = nextPitch
	yaw = nextYaw
end

local function toggle_player_mouse_mode(): ()
	if not is_player_role() or spectatorEnabled then
		return
	end

	playerMouseFrameEnabled = not playerMouseFrameEnabled
	apply_player_camera_mode()
end

local function handle_key_input(input: InputObject, isPressed: boolean): ()
	if input.KeyCode == PLAYER_SPECTATOR_TOGGLE_KEY and isPressed and is_player_role() then
		player:SetAttribute(
			PLAYER_SPECTATOR_ATTRIBUTE_NAME,
			not playerSpectatorRequested
		)
		return
	end

	if input.KeyCode == PLAYER_MOUSE_TOGGLE_KEY and isPressed then
		toggle_player_mouse_mode()
		return
	end

	if not spectatorEnabled then
		return
	end

	if input.KeyCode == Enum.KeyCode.W then
		inputState.forward = isPressed
		return
	end

	if input.KeyCode == Enum.KeyCode.S then
		inputState.backward = isPressed
		return
	end

	if input.KeyCode == Enum.KeyCode.A then
		inputState.left = isPressed
		return
	end

	if input.KeyCode == Enum.KeyCode.D then
		inputState.right = isPressed
		return
	end

	if input.KeyCode == Enum.KeyCode.E then
		inputState.up = isPressed
		return
	end

	if input.KeyCode == Enum.KeyCode.Q then
		inputState.down = isPressed
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		inputState.fast = isPressed
	end
end

local function handle_mouse_input(input: InputObject, isPressed: boolean): ()
	if not spectatorEnabled then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isRotatingCamera = isPressed
		apply_mouse_state()
	end
end

local function handle_wheel_input(input: InputObject): ()
	if not spectatorEnabled then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseWheel then
		return
	end

	local mousePosition = UserInputService:GetMouseLocation()
	local guiInset = GuiService:GetGuiInset()
	local hoverX = mousePosition.X
	local hoverY = mousePosition.Y - guiInset.Y
	local hoveredGuiObjects = playerGui:GetGuiObjectsAtPosition(hoverX, hoverY)

	for _, hoveredGuiObject in hoveredGuiObjects do
		if hoveredGuiObject.Visible and (
			hoveredGuiObject.Active
			or hoveredGuiObject:IsA("TextButton")
			or hoveredGuiObject:IsA("ImageButton")
			or hoveredGuiObject:IsA("TextBox")
			or hoveredGuiObject:IsA("ScrollingFrame")
		) then
			return
		end
	end

	move_spectator_by_look(input.Position.Z * WHEEL_MOVE_STEP)
end

local function on_gui_added(child: Instance): ()
	if child.Name ~= PLAYER_HUD_NAME then
		return
	end

	task.defer(function()
		cache_player_hud_objects()
		update_mouse_unlock_frame()
		update_spectator_toggle_button()
		apply_mouse_state()
	end)
end

------------------//MAIN FUNCTIONS

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	handle_key_input(input, true)
	handle_mouse_input(input, true)
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	handle_key_input(input, false)
	handle_mouse_input(input, false)
end)

UserInputService.InputChanged:Connect(function(input: InputObject)
	handle_wheel_input(input)
end)

player:GetAttributeChangedSignal(MASTER_SPECTATOR_JUMP_ATTRIBUTE_NAME):Connect(function()
	local jumpTarget = player:GetAttribute(MASTER_SPECTATOR_JUMP_ATTRIBUTE_NAME)
	if typeof(jumpTarget) ~= "CFrame" then
		return
	end

	jump_master_spectator_camera(jumpTarget)
end)

player:GetAttributeChangedSignal(PLAYER_SPECTATOR_ATTRIBUTE_NAME):Connect(function()
	playerSpectatorRequested = player:GetAttribute(PLAYER_SPECTATOR_ATTRIBUTE_NAME) == true
	update_spectator_toggle_button()
	update_role_state()
end)

player:GetPropertyChangedSignal("Team"):Connect(function()
	playerMouseFrameEnabled = false
	update_role_state()
end)

player.CharacterAdded:Connect(function()
	task.defer(function()
		update_role_state()
	end)
end)

player:GetPropertyChangedSignal("Character"):Connect(update_role_state)

playerGui.ChildAdded:Connect(on_gui_added)

------------------//INIT
player:SetAttribute(PLAYER_SPECTATOR_ATTRIBUTE_NAME, false)
playerSpectatorRequested = false

cache_player_hud_objects()
update_mouse_unlock_frame()
update_spectator_toggle_button()
update_role_state()
