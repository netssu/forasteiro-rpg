------------------//SERVICES
local RunService: RunService = game:GetService("RunService")
local Lighting: Lighting = game:GetService("Lighting")
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local BLUR_NAME: string = "TeamSelectBlur"
local CAMERA_PART_NAME: string = "TeamSelectionCameraPart"
local MENU_CAMERA_BIND_NAME: string = "TeamSelectionMenuCamera"
local MENU_BLUR_SIZE: number = 24

------------------//VARIABLES
local MenuCamera = {}
local player: Player = Players.LocalPlayer

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

function MenuCamera.enable(): ()
	local blur = Lighting:WaitForChild(BLUR_NAME) :: BlurEffect
	blur.Enabled = true
	blur.Size = MENU_BLUR_SIZE

	RunService:BindToRenderStep(MENU_CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, update_menu_camera)
	update_menu_camera()
end

function MenuCamera.disable(): ()
	local blur = Lighting:WaitForChild(BLUR_NAME) :: BlurEffect
	blur.Enabled = false
	RunService:UnbindFromRenderStep(MENU_CAMERA_BIND_NAME)
end

return MenuCamera