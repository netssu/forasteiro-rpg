------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService: UserInputService = game:GetService("UserInputService")
local RunService: RunService = game:GetService("RunService")

------------------//MODULES
local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local dictionaryFolder: Folder = modulesFolder:WaitForChild("Dictionary")
local utilityFolder: Folder = modulesFolder:WaitForChild("Utility")
local FlashlightDictionary = require(dictionaryFolder:WaitForChild("FlashlightDictionary"))
local FlashlightRemoteUtility = require(utilityFolder:WaitForChild("FlashlightRemoteUtility"))

------------------//CONSTANTS
local HUD_NAME = "PlayerHud"
local MAIN_FRAME_NAME = "Main"
local BUTTON_NAME = "ToggleButton"

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")
local camera: Camera = workspace.CurrentCamera
local toggleRemote: RemoteEvent
local updateRemote: UnreliableRemoteEvent
local isFlashlightOn = false

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
	if not button or not button:IsA("TextButton") then
		return nil
	end

	return button
end

local function sync_button_state(): ()
	local button = get_toggle_button()
	if not button then
		return
	end

	button.BackgroundColor3 = isFlashlightOn and FlashlightDictionary.BUTTON_ON_COLOR or FlashlightDictionary.BUTTON_OFF_COLOR
end

local function toggle_flashlight(): ()
	isFlashlightOn = not isFlashlightOn
	sync_button_state()
	toggleRemote:FireServer(isFlashlightOn)
end

local function on_input_began(input: InputObject, gameProcessed: boolean): ()
	if gameProcessed then
		return
	end

	if input.KeyCode == FlashlightDictionary.TOGGLE_KEYCODE then
		toggle_flashlight()
	end
end

local function update_local_flashlight(): ()
	if not isFlashlightOn then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end

	local attachment = head:FindFirstChild(FlashlightDictionary.ATTACHMENT_NAME) :: Attachment?
	if not attachment then
		return
	end

	local targetWorldCFrame = CFrame.lookAt(head.Position, head.Position + camera.CFrame.LookVector)
	attachment.CFrame = head.CFrame:ToObjectSpace(targetWorldCFrame)
end

local function on_gui_child_added(child: Instance): ()
	if child.Name ~= HUD_NAME then
		return
	end

	task.defer(sync_button_state)

	local button = get_toggle_button()
	if not button then
		return
	end

	button.MouseButton1Click:Connect(toggle_flashlight)
end

local function start_direction_updates(): ()
	task.spawn(function()
		while true do
			task.wait(FlashlightDictionary.UPDATE_INTERVAL)
			if isFlashlightOn then
				updateRemote:FireServer(camera.CFrame.LookVector)
			end
		end
	end)
end

------------------//MAIN FUNCTIONS
local FlashlightController = {}

function FlashlightController.run(): ()
	toggleRemote, updateRemote = FlashlightRemoteUtility.get_client_remotes()
	UserInputService.InputBegan:Connect(on_input_began)
	playerGui.ChildAdded:Connect(on_gui_child_added)
	RunService.RenderStepped:Connect(update_local_flashlight)
	start_direction_updates()
	sync_button_state()

	local existingHud = playerGui:FindFirstChild(HUD_NAME)
	if existingHud then
		on_gui_child_added(existingHud)
	end
end

return FlashlightController
