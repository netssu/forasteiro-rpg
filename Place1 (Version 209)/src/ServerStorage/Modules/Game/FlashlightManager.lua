------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//MODULES
local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local dictionaryFolder: Folder = modulesFolder:WaitForChild("Dictionary")
local utilityFolder: Folder = modulesFolder:WaitForChild("Utility")
local FlashlightDictionary = require(dictionaryFolder:WaitForChild("FlashlightDictionary"))
local FlashlightRemoteUtility = require(utilityFolder:WaitForChild("FlashlightRemoteUtility"))

------------------//FUNCTIONS
local function get_head(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("Head") :: BasePart?
end

local function get_or_create_flashlight(head: BasePart): (Attachment, SpotLight)
	local attachment = head:FindFirstChild(FlashlightDictionary.ATTACHMENT_NAME) :: Attachment?
	local light: SpotLight?

	if attachment then
		light = attachment:FindFirstChild(FlashlightDictionary.LIGHT_NAME) :: SpotLight?
	else
		attachment = Instance.new("Attachment")
		attachment.Name = FlashlightDictionary.ATTACHMENT_NAME
		attachment.Parent = head
	end

	if not light then
		light = Instance.new("SpotLight")
		light.Name = FlashlightDictionary.LIGHT_NAME
		light.Brightness = FlashlightDictionary.LIGHT_BRIGHTNESS
		light.Range = FlashlightDictionary.LIGHT_RANGE
		light.Angle = FlashlightDictionary.LIGHT_ANGLE
		light.Color = FlashlightDictionary.LIGHT_COLOR
		light.Shadows = FlashlightDictionary.LIGHT_SHADOWS
		light.Parent = attachment
	end

	return attachment, light
end

local function toggle_flashlight(player: Player, state: boolean): ()
	if typeof(state) ~= "boolean" then
		return
	end

	local head = get_head(player)
	if not head then
		return
	end

	local _, light = get_or_create_flashlight(head)
	light.Enabled = state
end

local function update_flashlight_direction(player: Player, lookVector: Vector3): ()
	if typeof(lookVector) ~= "Vector3" then
		return
	end

	local head = get_head(player)
	if not head then
		return
	end

	local attachment = head:FindFirstChild(FlashlightDictionary.ATTACHMENT_NAME) :: Attachment?
	if not attachment then
		return
	end

	local targetWorldCFrame = CFrame.lookAt(head.Position, head.Position + lookVector)
	attachment.CFrame = head.CFrame:ToObjectSpace(targetWorldCFrame)
end

------------------//MAIN FUNCTIONS
local FlashlightManager = {}

function FlashlightManager.connect(): ()
	local toggleRemote, updateRemote = FlashlightRemoteUtility.get_server_remotes()
	toggleRemote.OnServerEvent:Connect(toggle_flashlight)
	updateRemote.OnServerEvent:Connect(update_flashlight_direction)
end

return FlashlightManager
