------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local ASSETS_FOLDER_NAME: string = "Assets"
local REMOTES_FOLDER_NAME: string = "Remotes"
local REMOTE_NAME: string = "FlashlightEvent"
local UPDATE_REMOTE_NAME: string = "FlashlightUpdateEvent"

------------------//VARIABLES
local assetsFolder: Folder = ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME)
local remotesFolder: Folder = assetsFolder:WaitForChild(REMOTES_FOLDER_NAME)
local flashlightEvent: RemoteEvent = remotesFolder:FindFirstChild(REMOTE_NAME) or Instance.new("RemoteEvent")
local flashlightUpdateEvent: UnreliableRemoteEvent = remotesFolder:FindFirstChild(UPDATE_REMOTE_NAME) or Instance.new("UnreliableRemoteEvent")

------------------//FUNCTIONS
local function toggle_flashlight(player: Player, state: boolean): ()
	local character = player.Character
	local head = character and character:FindFirstChild("Head")

	if not head then return end

	local attachment = head:FindFirstChild("FlashlightAttachment")
	local light = attachment and attachment:FindFirstChild("PlayerFlashlight")

	if state then
		if not attachment then
			attachment = Instance.new("Attachment")
			attachment.Name = "FlashlightAttachment"
			attachment.Parent = head

			light = Instance.new("SpotLight")
			light.Name = "PlayerFlashlight"
			light.Brightness = 3
			light.Range = 40
			light.Angle = 60
			light.Color = Color3.fromRGB(255, 245, 225)
			light.Shadows = true
			light.Parent = attachment
		end

		if light then
			light.Enabled = true
		end
	else
		if light then
			light.Enabled = false
		end
	end
end

local function update_flashlight_direction(player: Player, lookVector: Vector3): ()
	if typeof(lookVector) ~= "Vector3" then return end

	local character = player.Character
	local head = character and character:FindFirstChild("Head")

	if head then
		local attachment = head:FindFirstChild("FlashlightAttachment")
		if attachment then
			local targetWorldCFrame = CFrame.lookAt(head.Position, head.Position + lookVector)
			attachment.CFrame = head.CFrame:ToObjectSpace(targetWorldCFrame)
		end
	end
end

------------------//MAIN FUNCTIONS
flashlightEvent.OnServerEvent:Connect(toggle_flashlight)
flashlightUpdateEvent.OnServerEvent:Connect(update_flashlight_direction)

------------------//INIT
if flashlightEvent.Name ~= REMOTE_NAME then
	flashlightEvent.Name = REMOTE_NAME
	flashlightEvent.Parent = remotesFolder
end

if flashlightUpdateEvent.Name ~= UPDATE_REMOTE_NAME then
	flashlightUpdateEvent.Name = UPDATE_REMOTE_NAME
	flashlightUpdateEvent.Parent = remotesFolder
end