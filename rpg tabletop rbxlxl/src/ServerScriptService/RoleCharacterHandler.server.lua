------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")


------------------//CONSTANTS
local MASTER_TEAM_NAME: string = "Mestre"
local PLAYER_TEAM_NAME: string = "Jogador"

local ASSETS_FOLDER_NAME: string = "Assets"
local REMOTES_FOLDER_NAME: string = "Remotes"
local ROLE_IMAGE_REMOTE_NAME: string = "RoleImageEvent"
local CHARACTERS_FOLDER_NAME: string = "Characters"

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

local DEFAULT_ROLE_IMAGE_ID: string = "rbxassetid://102504382273976"

------------------//VARIABLES
local sanitizeVersionByCharacter: {[Model]: number} = {}

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

local charactersFolder = workspace:FindFirstChild(CHARACTERS_FOLDER_NAME)
if not charactersFolder then
	charactersFolder = Instance.new("Folder")
	charactersFolder.Name = CHARACTERS_FOLDER_NAME
	charactersFolder.Parent = workspace
end

------------------//FUNCTIONS
local function get_character_role(character: Model): string
	if character:GetAttribute("IsNPC") then
		return PLAYER_TEAM_NAME
	end

	local player = Players:GetPlayerFromCharacter(character)
	if player and player.Team then
		return player.Team.Name
	end
	return PLAYER_TEAM_NAME
end

local function is_master(character: Model): boolean
	return get_character_role(character) == MASTER_TEAM_NAME
end

local function is_player_role(character: Model): boolean
	return get_character_role(character) == PLAYER_TEAM_NAME
end

local function set_rbx_character_sounds_enabled(character: Model, isEnabled: boolean): ()
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	local playerScripts = player:FindFirstChild("PlayerScripts")
	if not playerScripts then return end

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

local function get_character_image_asset(character: Model): string
	local rawValue = character:GetAttribute(ROLE_IMAGE_ATTRIBUTE_NAME)

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
	local scale = character:GetAttribute("TokenScale") or 1

	return Vector3.new(width * scale, height * scale, TOKEN_THICKNESS)
end

local function create_surface_image(parent: SurfaceGui, imageName: string, imageAsset: string, imageColor: Color3?): ()
	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = imageName
	imageLabel.Size = UDim2.fromScale(1, 1)
	imageLabel.Position = UDim2.fromScale(0, 0)
	imageLabel.BackgroundTransparency = 1
	imageLabel.BorderSizePixel = 0
	imageLabel.ScaleType = Enum.ScaleType.Fit
	imageLabel.Image = imageAsset

	if imageColor then
		imageLabel.ImageColor3 = imageColor
	end

	imageLabel.Parent = parent
end

local function create_surface_gui(tokenPart: BasePart, guiName: string, imageName: string, face: Enum.NormalId, imageAsset: string): SurfaceGui
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

	local imageColor = nil
	local isBack = guiName == ROLE_TOKEN_BACK_GUI_NAME
	if isBack then
		imageColor = Color3.new(0.207843, 0.207843, 0.207843)
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

local function create_or_update_player_token(character: Model): ()
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local imageAsset = get_character_image_asset(character)
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
	local isLocked = character:GetAttribute("MovementLocked") == true

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant.Name == "HumanoidRootPart" then
				descendant.Anchored = isLocked
			else
				descendant.Anchored = false
			end

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
	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 50
	humanoid.JumpHeight = 7.2
end

local function sanitize_master_character(character: Model): ()
	remove_existing_token(character)
	destroy_master_visual_objects(character)
	destroy_character_sounds(character)
	apply_master_part_state(character)
	apply_master_humanoid_state(character)
	set_rbx_character_sounds_enabled(character, false)
end

local function sanitize_player_character(character: Model): ()
	hide_player_visual_objects(character)
	destroy_character_sounds(character)
	apply_player_part_state(character)
	apply_player_humanoid_state(character)
	create_or_update_player_token(character)
	set_rbx_character_sounds_enabled(character, false)
end

local function apply_default_state(character: Model): ()
	remove_existing_token(character)
	set_rbx_character_sounds_enabled(character, true)
end

local function run_sanitize_loop(character: Model, totalPasses: number, interval: number): ()
	local nextVersion = (sanitizeVersionByCharacter[character] or 0) + 1
	sanitizeVersionByCharacter[character] = nextVersion

	for passIndex = 1, totalPasses do
		local currentPassIndex = passIndex

		task.delay((currentPassIndex - 1) * interval, function()
			if sanitizeVersionByCharacter[character] ~= nextVersion then
				return
			end

			if not character.Parent then
				return
			end

			if is_master(character) then
				sanitize_master_character(character)
				return
			end

			if is_player_role(character) then
				sanitize_player_character(character)
				return
			end

			apply_default_state(character)
		end)
	end
end

local function apply_role_state(character: Model): ()
	if not character or not character.Parent then
		return
	end

	if is_master(character) then
		run_sanitize_loop(character, MASTER_SANITIZE_PASSES, MASTER_SANITIZE_INTERVAL)
		return
	end

	if is_player_role(character) then
		run_sanitize_loop(character, PLAYER_SANITIZE_PASSES, PLAYER_SANITIZE_INTERVAL)
		return
	end

	sanitizeVersionByCharacter[character] = (sanitizeVersionByCharacter[character] or 0) + 1
	apply_default_state(character)
end

local function on_character_added(character: Model): ()
	sanitizeVersionByCharacter[character] = 0

	local currentImage = character:GetAttribute(ROLE_IMAGE_ATTRIBUTE_NAME)
	if currentImage == nil or currentImage == "" then
		character:SetAttribute(ROLE_IMAGE_ATTRIBUTE_NAME, DEFAULT_ROLE_IMAGE_ID)
	end

	character:GetAttributeChangedSignal(ROLE_IMAGE_ATTRIBUTE_NAME):Connect(function()
		apply_role_state(character)
	end)

	task.defer(function()
		apply_role_state(character)
	end)
end

local function on_character_removing(character: Model): ()
	sanitizeVersionByCharacter[character] = nil
end

local function on_role_image_request(sender: Player, payload: any): ()
	local characterCheck = Players:GetPlayerFromCharacter(sender.Character)

	if not is_master(sender.Character and sender.Character or sender) and (characterCheck and sender.Team and sender.Team.Name ~= MASTER_TEAM_NAME) then
		return
	end

	if typeof(payload) ~= "table" then
		return
	end

	if typeof(payload.Character) ~= "Instance" or not payload.Character:IsA("Model") or typeof(payload.ImageId) ~= "string" then
		return
	end

	local character = payload.Character
	character:SetAttribute(ROLE_IMAGE_ATTRIBUTE_NAME, normalize_image_id(payload.ImageId))

	apply_role_state(character)
end

local function on_player_added(player: Player): ()
	player:GetPropertyChangedSignal("Team"):Connect(function()
		local character = player.Character
		if character and character.Parent == charactersFolder then
			apply_role_state(character)
		end
	end)
end

------------------//MAIN FUNCTIONS
roleImageEvent.OnServerEvent:Connect(on_role_image_request)

charactersFolder.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		on_character_added(child)
	end
end)

charactersFolder.ChildRemoved:Connect(function(child)
	if child:IsA("Model") then
		on_character_removing(child)
	end
end)

Players.PlayerAdded:Connect(on_player_added)

------------------//INIT
for _, player in Players:GetPlayers() do
	on_player_added(player)
end

for _, child in charactersFolder:GetChildren() do
	if child:IsA("Model") then
		on_character_added(child)
	end
end