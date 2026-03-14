------------------//SERVICES
local RunService: RunService = game:GetService("RunService")
local Lighting: Lighting = game:GetService("Lighting")
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local BLUR_NAME: string = "TeamSelectBlur"
local CAMERA_PART_NAME: string = "TeamSelectionCameraPart"
local MENU_CAMERA_BIND_NAME: string = "TeamSelectionMenuCamera"
local MENU_BLUR_SIZE: number = 24
local HOVER_HEIGHT: number = 1.5
local HOVER_SPEED: number = 0.8
local HOVER_SWAY_ANGLE: number = math.rad(1.2)
local HOVER_SWAY_SPEED: number = 0.6

------------------//VARIABLES
local MenuCamera = {}
local player: Player = Players.LocalPlayer
local menuCameraHoverStartTime: number = 0

------------------//FUNCTIONS
local function get_current_camera(): Camera
	local currentCamera = workspace.CurrentCamera

	while not currentCamera do
		task.wait()
		currentCamera = workspace.CurrentCamera
	end

	return currentCamera
end

local function get_menu_camera_cframe(): CFrame
	local cameraPart = workspace:FindFirstChild(CAMERA_PART_NAME)

	if cameraPart and cameraPart:IsA("BasePart") then
		return cameraPart.CFrame
	end

	return CFrame.new(0, 60, 0) * CFrame.Angles(math.rad(-90), 0, 0)
end

local function get_or_create_blur(): BlurEffect
	local blur = Lighting:FindFirstChild(BLUR_NAME)

	if blur and blur:IsA("BlurEffect") then
		return blur
	end

	local newBlur = Instance.new("BlurEffect")
	newBlur.Name = BLUR_NAME
	newBlur.Enabled = false
	newBlur.Size = MENU_BLUR_SIZE
	newBlur.Parent = Lighting

	return newBlur
end

local function update_menu_camera(): ()
	if player.Team then
		return
	end

	local currentCamera = get_current_camera()
	local baseCameraCFrame = get_menu_camera_cframe()
	local elapsed = time() - menuCameraHoverStartTime
	local bobOffset = math.sin(elapsed * math.pi * 2 * HOVER_SPEED) * HOVER_HEIGHT
	local sway = math.sin(elapsed * math.pi * 2 * HOVER_SWAY_SPEED) * HOVER_SWAY_ANGLE
	local cameraCFrame = baseCameraCFrame * CFrame.new(0, bobOffset, 0) * CFrame.Angles(0, sway, 0)

	currentCamera.CameraType = Enum.CameraType.Scriptable
	currentCamera.CFrame = cameraCFrame
	currentCamera.Focus = cameraCFrame * CFrame.new(0, 0, -10)
end

function MenuCamera.enable(): ()
	local blur = get_or_create_blur()
	blur.Enabled = true
	blur.Size = MENU_BLUR_SIZE
	menuCameraHoverStartTime = time()

	RunService:BindToRenderStep(MENU_CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, update_menu_camera)
	update_menu_camera()
end

function MenuCamera.disable(): ()
	local blur = Lighting:FindFirstChild(BLUR_NAME)
	if blur and blur:IsA("BlurEffect") then
		blur.Enabled = false
	end
	RunService:UnbindFromRenderStep(MENU_CAMERA_BIND_NAME)
end

return MenuCamera