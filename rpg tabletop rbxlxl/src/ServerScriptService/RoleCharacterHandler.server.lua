------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local MASTER_TEAM_NAME: string = "Mestre"
local PLAYER_TEAM_NAME: string = "Jogador"

local ASSETS_FOLDER_NAME: string = "Assets"
local REMOTES_FOLDER_NAME: string = "Remotes"
local ROLE_IMAGE_REMOTE_NAME: string = "RoleImageEvent"

local MASTER_SANITIZE_PASSES: number = 6
local MASTER_SANITIZE_INTERVAL: number = 0.2
local PLAYER_SANITIZE_PASSES: number = 6
local PLAYER_SANITIZE_INTERVAL: number = 0.2

local ROLE_TOKEN_PART_NAME: string = "RoleTokenPart"
local ROLE_TOKEN_WELD_NAME: string = "RoleTokenWeld"
local ROLE_TOKEN_FRONT_GUI_NAME: string = "RoleTokenFrontGui"
local ROLE_TOKEN_BACK_GUI_NAME: string = "RoleTokenBackGui"
local ROLE_TOKEN_FRONT_IMAGE_NAME: string = "RoleTokenFrontImage"
local ROLE_TOKEN_BACK_IMAGE_NAME: string = "RoleTokenBackImage"

local ROLE_IMAGE_ATTRIBUTE_NAME: string = "RoleImageId"
local TOKEN_FORWARD_OFFSET: number = 1.75
local TOKEN_THICKNESS: number = 0.05
local TOKEN_MIN_WIDTH: number = 3
local TOKEN_WIDTH_RATIO: number = 0.72
local TOKEN_MIN_HEIGHT: number = 5

------------------//VARIABLES
local sanitizeVersionByPlayer: {[Player]: number} = {}

local assetsFolder: Folder = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME) or Instance.new("Folder")
assetsFolder.Name = ASSETS_FOLDER_NAME
assetsFolder.Parent = ReplicatedStorage

local remotesFolder: Folder = assetsFolder:FindFirstChild(REMOTES_FOLDER_NAME) or Instance.new("Folder")
remotesFolder.Name = REMOTES_FOLDER_NAME
remotesFolder.Parent = assetsFolder

local roleImageEvent: RemoteEvent = remotesFolder:FindFirstChild(ROLE_IMAGE_REMOTE_NAME) :: RemoteEvent
if not roleImageEvent then
	roleImageEvent = Instance.new("RemoteEvent")
	roleImageEvent.Name = ROLE_IMAGE_REMOTE_NAME
	roleImageEvent.Parent = remotesFolder
end

------------------//FUNCTIONS
local function get_team_name(player: Player): string
	local team = player.Team

	if not team then
		return ""
	end

	return team.Name
end

local function is_master(player: Player): boolean
	return get_team_name(player) == MASTER_TEAM_NAME
end

local function is_player_role(player: Player): boolean
	return get_team_name(player) == PLAYER_TEAM_NAME
end

local function get_player_scripts(player: Player): Instance?
	return player:FindFirstChild("PlayerScripts")
end

local function set_rbx_character_sounds_enabled(player: Player, isEnabled: boolean): ()
	local playerScripts = get_player_scripts(player)

	if not playerScripts then
		return
	end

	local soundScript = playerScripts:FindFirstChild("RbxCharacterSounds", true)

	if soundScript and soundScript:IsA("LocalScript") then
		soundScript.Enabled = isEnabled
	end
end

local function destroy_character_sounds(character: Model): ()
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Sound") then
			descendant:Destroy()
		end
	end
end

local function destroy_master_visual_objects(character: Model): ()
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Accessory") then
			descendant:Destroy()
		elseif descendant:IsA("Shirt") then
			descendant:Destroy()
		elseif descendant:IsA("Pants") then
			descendant:Destroy()
		elseif descendant:IsA("ShirtGraphic") then
			descendant:Destroy()
		elseif descendant:IsA("Decal") then
			descendant:Destroy()
		elseif descendant:IsA("Texture") then
			descendant:Destroy()
		end
	end
end

local function hide_player_visual_objects(character: Model): ()
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Decal") then
			descendant.Transparency = 1
		elseif descendant:IsA("Texture") then
			descendant.Transparency = 1
		elseif descendant:IsA("WrapLayer") then
			descendant.Enabled = false
		end
	end
end

local function remove_existing_token(character: Model): ()
	local existingToken = character:FindFirstChild(ROLE_TOKEN_PART_NAME)

	if existingToken then
		existingToken:Destroy()
	end
end

local function normalize_image_id(rawValue: string): string
	local trimmed = string.gsub(rawValue, "^%s*(.-)%s*$", "%1")

	if trimmed == "" then
		return ""
	end

	if string.find(trimmed, "rbxassetid://", 1, true) == 1 then
		return trimmed
	end

	local numericId = string.match(trimmed, "%d+")

	if numericId then
		return "rbxassetid://" .. numericId
	end

	return trimmed
end

local function get_player_image_asset(player: Player): string
	local rawValue = player:GetAttribute(ROLE_IMAGE_ATTRIBUTE_NAME)

	if typeof(rawValue) ~= "string" then
		return ""
	end

	return normalize_image_id(rawValue)
end

local function get_character_height(character: Model): number
	local _, size = character:GetBoundingBox()
	return math.max(TOKEN_MIN_HEIGHT, size.Y)
end

local function get_token_size(character: Model): Vector3
	local height = get_character_height(character)
	local width = math.max(TOKEN_MIN_WIDTH, height * TOKEN_WIDTH_RATIO)

	return Vector3.new(width, height, TOKEN_THICKNESS)
end

local function create_surface_image(parent: SurfaceGui, imageName: string, imageAsset: string): ()
	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = imageName
	imageLabel.Size = UDim2.fromScale(1, 1)
	imageLabel.Position = UDim2.fromScale(0, 0)
	imageLabel.BackgroundTransparency = 1
	imageLabel.BorderSizePixel = 0
	imageLabel.ScaleType = Enum.ScaleType.Fit
	imageLabel.Image = imageAsset
	imageLabel.Parent = parent
end

local function create_surface_gui(tokenPart: BasePart, guiName: string, imageName: string, face: Enum.NormalId, imageAsset: string, imageColor: Color3): SurfaceGui
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = guiName
	surfaceGui.Face = face
	surfaceGui.LightInfluence = 0
	surfaceGui.Brightness = 1
	surfaceGui.AlwaysOnTop = false
	surfaceGui.ResetOnSpawn = false
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 50
	surfaceGui.Parent = tokenPart
	
	local isBack = guiName == ROLE_TOKEN_BACK_GUI_NAME
	if isBack then
		imageColor = Color3.new(0.0666667, 0.0666667, 0.0666667)
	end

	create_surface_image(surfaceGui, imageName, imageAsset, imageColor)

	return surfaceGui
end
local function update_token_images(tokenPart: BasePart, imageAsset: string): ()
	local frontGui = tokenPart:FindFirstChild(ROLE_TOKEN_FRONT_GUI_NAME)
	local backGui = tokenPart:FindFirstChild(ROLE_TOKEN_BACK_GUI_NAME)

	if frontGui and frontGui:IsA("SurfaceGui") then
		local imageLabel = frontGui:FindFirstChild(ROLE_TOKEN_FRONT_IMAGE_NAME)
		if imageLabel and imageLabel:IsA("ImageLabel") then
			imageLabel.Image = imageAsset
		end
	end

	if backGui and backGui:IsA("SurfaceGui") then
		local imageLabel = backGui:FindFirstChild(ROLE_TOKEN_BACK_IMAGE_NAME)
		if imageLabel and imageLabel:IsA("ImageLabel") then
			imageLabel.Image = imageAsset
		end
	end
end

local function create_or_update_player_token(player: Player, character: Model): ()
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local imageAsset = get_player_image_asset(player)
	local tokenPart = character:FindFirstChild(ROLE_TOKEN_PART_NAME)

	if tokenPart and not tokenPart:IsA("BasePart") then
		tokenPart:Destroy()
		tokenPart = nil
	end

	local size = get_token_size(character)

	if not tokenPart then
		local newTokenPart = Instance.new("Part")
		newTokenPart.Name = ROLE_TOKEN_PART_NAME
		newTokenPart.Anchored = false
		newTokenPart.CanCollide = false
		newTokenPart.CanTouch = false
		newTokenPart.CanQuery = false
		newTokenPart.Massless = true
		newTokenPart.Transparency = 1
		newTokenPart.CastShadow = false
		newTokenPart.TopSurface = Enum.SurfaceType.Smooth
		newTokenPart.BottomSurface = Enum.SurfaceType.Smooth
		newTokenPart.Size = size
		newTokenPart.CFrame = rootPart.CFrame * CFrame.new(0, 0, -TOKEN_FORWARD_OFFSET)
		newTokenPart.Parent = character

		local weld = Instance.new("Motor6D", newTokenPart)
		weld.Name = ROLE_TOKEN_WELD_NAME
		weld.Part0 = rootPart
		weld.Part1 = newTokenPart

		create_surface_gui(newTokenPart, ROLE_TOKEN_FRONT_GUI_NAME, ROLE_TOKEN_FRONT_IMAGE_NAME, Enum.NormalId.Front, imageAsset)
		create_surface_gui(newTokenPart, ROLE_TOKEN_BACK_GUI_NAME, ROLE_TOKEN_BACK_IMAGE_NAME, Enum.NormalId.Back, imageAsset)

		tokenPart = newTokenPart
	else
		tokenPart.Size = size
		tokenPart.CFrame = rootPart.CFrame * CFrame.new(0, 0, -TOKEN_FORWARD_OFFSET)
	end

	if tokenPart and tokenPart:IsA("BasePart") then
		update_token_images(tokenPart, imageAsset)
	end
end

local function apply_master_part_state(character: Model): ()
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Transparency = 1
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function apply_player_part_state(character: Model): ()
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Transparency = 1
			descendant.AssemblyLinearVelocity = descendant.AssemblyLinearVelocity
			descendant.AssemblyAngularVelocity = descendant.AssemblyAngularVelocity
		end
	end
end

local function apply_master_humanoid_state(character: Model): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return
	end

	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
end

local function apply_player_humanoid_state(character: Model): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return
	end

	humanoid.AutoRotate = true
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
end

local function sanitize_master_character(player: Player, character: Model): ()
	remove_existing_token(character)
	destroy_master_visual_objects(character)
	destroy_character_sounds(character)
	apply_master_part_state(character)
	apply_master_humanoid_state(character)
	set_rbx_character_sounds_enabled(player, false)
end

local function sanitize_player_character(player: Player, character: Model): ()
	hide_player_visual_objects(character)
	destroy_character_sounds(character)
	apply_player_part_state(character)
	apply_player_humanoid_state(character)
	create_or_update_player_token(player, character)
	set_rbx_character_sounds_enabled(player, false)
end

local function apply_default_state(player: Player, character: Model): ()
	remove_existing_token(character)
	set_rbx_character_sounds_enabled(player, true)
end

local function run_sanitize_loop(player: Player, character: Model, totalPasses: number, interval: number): ()
	local nextVersion = (sanitizeVersionByPlayer[player] or 0) + 1
	sanitizeVersionByPlayer[player] = nextVersion

	for passIndex = 1, totalPasses do
		local currentPassIndex = passIndex

		task.delay((currentPassIndex - 1) * interval, function()
			if player.Parent ~= Players then
				return
			end

			if sanitizeVersionByPlayer[player] ~= nextVersion then
				return
			end

			if player.Character ~= character then
				return
			end

			if not character.Parent then
				return
			end

			if is_master(player) then
				sanitize_master_character(player, character)
				return
			end

			if is_player_role(player) then
				sanitize_player_character(player, character)
				return
			end

			apply_default_state(player, character)
		end)
	end
end

local function apply_role_state(player: Player): ()
	local character = player.Character

	if not character or not character.Parent then
		return
	end

	if is_master(player) then
		run_sanitize_loop(player, character, MASTER_SANITIZE_PASSES, MASTER_SANITIZE_INTERVAL)
		return
	end

	if is_player_role(player) then
		run_sanitize_loop(player, character, PLAYER_SANITIZE_PASSES, PLAYER_SANITIZE_INTERVAL)
		return
	end

	sanitizeVersionByPlayer[player] = (sanitizeVersionByPlayer[player] or 0) + 1
	apply_default_state(player, character)
end

local function on_character_added(player: Player, character: Model): ()
	task.defer(function()
		if player.Character ~= character then
			return
		end

		apply_role_state(player)
	end)
end

local function on_role_image_request(sender: Player, payload: any): ()
	if not is_master(sender) then
		return
	end

	if typeof(payload) ~= "table" then
		return
	end

	if typeof(payload.UserId) ~= "number" or typeof(payload.ImageId) ~= "string" then
		return
	end

	local targetPlayer = Players:GetPlayerByUserId(payload.UserId)

	if not targetPlayer then
		return
	end

	targetPlayer:SetAttribute(ROLE_IMAGE_ATTRIBUTE_NAME, normalize_image_id(payload.ImageId))

	if is_player_role(targetPlayer) then
		apply_role_state(targetPlayer)
	end
end

local function on_player_added(player: Player): ()
	sanitizeVersionByPlayer[player] = 0

	if player:GetAttribute(ROLE_IMAGE_ATTRIBUTE_NAME) == nil then
		player:SetAttribute(ROLE_IMAGE_ATTRIBUTE_NAME, "")
	end

	player:GetPropertyChangedSignal("Team"):Connect(function()
		apply_role_state(player)
	end)

	player:GetAttributeChangedSignal(ROLE_IMAGE_ATTRIBUTE_NAME):Connect(function()
		apply_role_state(player)
	end)

	player.CharacterAdded:Connect(function(character: Model)
		on_character_added(player, character)
	end)

	local currentCharacter = player.Character

	if currentCharacter then
		on_character_added(player, currentCharacter)
	end

	task.delay(1, function()
		if player.Parent ~= Players then
			return
		end

		apply_role_state(player)
	end)
end

local function on_player_removing(player: Player): ()
	sanitizeVersionByPlayer[player] = nil
end

------------------//MAIN FUNCTIONS
roleImageEvent.OnServerEvent:Connect(on_role_image_request)

------------------//INIT
for _, player in Players:GetPlayers() do
	on_player_added(player)
end

Players.PlayerAdded:Connect(on_player_added)
Players.PlayerRemoving:Connect(on_player_removing)