------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting: Lighting = game:GetService("Lighting")
local RunService: RunService = game:GetService("RunService")

------------------//CONSTANTS
local REMOTE_NAME: string = "TeamSelectEvent"
local GUI_NAME: string = "TeamSelectGui"
local MASTER_TEAM_NAME: string = "Mestre"
local PLAYER_TEAM_NAME: string = "Jogador"
local BLUR_NAME: string = "TeamSelectBlur"
local CAMERA_PART_NAME: string = "TeamSelectionCameraPart"
local MENU_CAMERA_BIND_NAME: string = "TeamSelectionMenuCamera"
local MENU_BLUR_SIZE: number = 24

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local teamSelectEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)

local teamGui: ScreenGui? = nil
local mainFrame: Frame? = nil
local masterButton: TextButton? = nil
local playerButton: TextButton? = nil

local masterConnection: RBXScriptConnection? = nil
local playerConnection: RBXScriptConnection? = nil

------------------//FUNCTIONS
local function get_current_camera(): Camera
	local currentCamera = workspace.CurrentCamera

	while not currentCamera do
		task.wait()
		currentCamera = workspace.CurrentCamera
	end

	return currentCamera
end

local function get_or_create_blur(): BlurEffect
	local blur = Lighting:FindFirstChild(BLUR_NAME)

	if blur and blur:IsA("BlurEffect") then
		return blur
	end

	local newBlur = Instance.new("BlurEffect")
	newBlur.Name = BLUR_NAME
	newBlur.Size = MENU_BLUR_SIZE
	newBlur.Enabled = false
	newBlur.Parent = Lighting

	return newBlur
end

local function get_menu_camera_cframe(): CFrame
	local cameraPart = workspace:FindFirstChild(CAMERA_PART_NAME)

	if cameraPart and cameraPart:IsA("BasePart") then
		return cameraPart.CFrame
	end

	return CFrame.new(0, 60, 0) * CFrame.Angles(math.rad(-90), 0, 0)
end

local function update_menu_camera(): ()
	if player.Team then
		return
	end

	local currentCamera = get_current_camera()
	local cameraCFrame = get_menu_camera_cframe()

	currentCamera.CameraType = Enum.CameraType.Scriptable
	currentCamera.CFrame = cameraCFrame
	currentCamera.Focus = cameraCFrame * CFrame.new(0, 0, -10)
end

local function enable_menu_camera(): ()
	RunService:BindToRenderStep(MENU_CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, update_menu_camera)
	update_menu_camera()
end

local function disable_menu_camera(): ()
	RunService:UnbindFromRenderStep(MENU_CAMERA_BIND_NAME)
end

local function cache_gui_objects(): ()
	local guiObject = playerGui:FindFirstChild(GUI_NAME)

	if not guiObject or not guiObject:IsA("ScreenGui") then
		teamGui = nil
		mainFrame = nil
		masterButton = nil
		playerButton = nil
		return
	end

	teamGui = guiObject
	mainFrame = teamGui:FindFirstChild("Main")
	masterButton = mainFrame and mainFrame:FindFirstChild("MasterButton") or nil
	playerButton = mainFrame and mainFrame:FindFirstChild("PlayerButton") or nil
end

local function disconnect_button_connections(): ()
	if masterConnection then
		masterConnection:Disconnect()
		masterConnection = nil
	end

	if playerConnection then
		playerConnection:Disconnect()
		playerConnection = nil
	end
end

local function select_team(teamName: string): ()
	teamSelectEvent:FireServer(teamName)
end

local function connect_buttons(): ()
	disconnect_button_connections()

	if not masterButton or not playerButton then
		return
	end

	masterConnection = masterButton.MouseButton1Click:Connect(function()
		select_team(MASTER_TEAM_NAME)
	end)

	playerConnection = playerButton.MouseButton1Click:Connect(function()
		select_team(PLAYER_TEAM_NAME)
	end)
end

local function update_menu_state(): ()
	cache_gui_objects()

	local blur = get_or_create_blur()

	if not player.Team then
		if teamGui then
			teamGui.Enabled = true
		end

		blur.Enabled = true
		blur.Size = MENU_BLUR_SIZE

		enable_menu_camera()
		return
	end

	if teamGui then
		teamGui.Enabled = false
	end

	blur.Enabled = false
	disable_menu_camera()
end

local function on_gui_added(child: Instance): ()
	if child.Name ~= GUI_NAME then
		return
	end

	task.defer(function()
		cache_gui_objects()
		connect_buttons()
		update_menu_state()
	end)
end

------------------//MAIN FUNCTIONS
cache_gui_objects()
connect_buttons()
update_menu_state()

player:GetPropertyChangedSignal("Team"):Connect(function()
	update_menu_state()
end)

playerGui.ChildAdded:Connect(on_gui_added)

------------------//INIT