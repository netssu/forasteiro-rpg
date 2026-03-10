------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService: UserInputService = game:GetService("UserInputService")

local RunService: RunService = game:GetService("RunService")

------------------//CONSTANTS
local HUD_NAME: string = "PlayerHud"
local MAIN_FRAME_NAME: string = "Main"
local BUTTON_NAME: string = "ToggleButton"
local ASSETS_FOLDER_NAME: string = "Assets"
local REMOTES_FOLDER_NAME: string = "Remotes"
local REMOTE_NAME: string = "FlashlightEvent"
local UPDATE_REMOTE_NAME: string = "FlashlightUpdateEvent"

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")
local camera: Camera = workspace.CurrentCamera

local assetsFolder: Folder = ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME)
local remotesFolder: Folder = assetsFolder:WaitForChild(REMOTES_FOLDER_NAME)
local flashlightEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME) :: RemoteEvent
local flashlightUpdateEvent: UnreliableRemoteEvent = remotesFolder:WaitForChild(UPDATE_REMOTE_NAME) :: UnreliableRemoteEvent

local isFlashlightOn: boolean = false

------------------//FUNCTIONS
local function get_toggle_button(): TextButton?
	local hud = playerGui:FindFirstChild(HUD_NAME)

	if not hud then
		return nil
	end

	local mainFrame = hud:FindFirstChild(MAIN_FRAME_NAME)

	if not mainFrame then
		return nil
	end

	local button = mainFrame:FindFirstChild(BUTTON_NAME)

	if button and button:IsA("TextButton") then
		return button
	end

	return nil
end

local function toggle_flashlight(): ()
	isFlashlightOn = not isFlashlightOn

	local button = get_toggle_button()

	if isFlashlightOn then
		if button then
			button.BackgroundColor3 = Color3.fromRGB(60, 64, 78)
		end
	else
		if button then
			button.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
		end
	end

	flashlightEvent:FireServer(isFlashlightOn)
end

local function on_input_began(input: InputObject, gameProcessed: boolean): ()
	if input.KeyCode == Enum.KeyCode.O then
		toggle_flashlight()
	end
end

local function connect_button(button: TextButton): ()
	button.MouseButton1Click:Connect(function()
		toggle_flashlight()
	end)
end

local function check_and_connect_gui(child: Instance): ()
	if child.Name ~= HUD_NAME then
		return
	end

	task.defer(function()
		local button = get_toggle_button()

		if button then
			connect_button(button)
		end
	end)
end

local function update_local_flashlight(): ()
	if not isFlashlightOn then return end

	local character = player.Character
	local head = character and character:FindFirstChild("Head")

	if head then
		local attachment = head:FindFirstChild("FlashlightAttachment")
		if attachment then
			local targetWorldCFrame = CFrame.lookAt(head.Position, head.Position + camera.CFrame.LookVector)
			attachment.CFrame = head.CFrame:ToObjectSpace(targetWorldCFrame)
		end
	end
end

------------------//MAIN FUNCTIONS
UserInputService.InputBegan:Connect(on_input_began)
playerGui.ChildAdded:Connect(check_and_connect_gui)
RunService.RenderStepped:Connect(update_local_flashlight)

task.spawn(function()
	while true do
		task.wait(0.1)
		if isFlashlightOn then
			flashlightUpdateEvent:FireServer(camera.CFrame.LookVector)
		end
	end
end)

------------------//INIT
local existingGui = playerGui:FindFirstChild(HUD_NAME)

if existingGui then
	check_and_connect_gui(existingGui)
end