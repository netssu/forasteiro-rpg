------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local MASTER_TEAM_NAME: string = "Mestre"
local REMOTE_NAME: string = "MasterBuildEvent"
local BUILD_FOLDER_NAME: string = "TabletopBuildParts"

local MIN_PART_SIZE: number = 1
local MAX_PART_SIZE: number = 512
local DEFAULT_COLOR: Color3 = Color3.fromRGB(163, 162, 165)

------------------//VARIABLES
local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local masterBuildEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)

------------------//FUNCTIONS
local function is_master(player: Player): boolean
	return player.Team ~= nil and player.Team.Name == MASTER_TEAM_NAME
end

local function get_build_folder(): Folder
	local folder = workspace:FindFirstChild(BUILD_FOLDER_NAME)

	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = BUILD_FOLDER_NAME
	folder.Parent = workspace

	return folder
end

local function is_valid_build_part(inst: Instance?): boolean
	if not inst or not inst:IsA("BasePart") then
		return false
	end

	return inst.Parent == get_build_folder() and inst:GetAttribute("IsTabletopBuildPart") == true
end

local function sanitize_size(size: Vector3): Vector3
	return Vector3.new(
		math.clamp(size.X, MIN_PART_SIZE, MAX_PART_SIZE),
		math.clamp(size.Y, MIN_PART_SIZE, MAX_PART_SIZE),
		math.clamp(size.Z, MIN_PART_SIZE, MAX_PART_SIZE)
	)
end

local function sanitize_color(color: Color3?): Color3
	if color then
		return color
	end

	return DEFAULT_COLOR
end

local function create_build_part(size: Vector3, cframe: CFrame, color: Color3?, buildKind: string?): BasePart
	local folder = get_build_folder()

	local part = Instance.new("Part")
	part.Name = "BuildPart"
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = true
	part.CanQuery = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = sanitize_color(color)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = sanitize_size(size)
	part.CFrame = cframe
	part:SetAttribute("IsTabletopBuildPart", true)
	part:SetAttribute("BuildKind", buildKind or "Part")
	part.Parent = folder

	return part
end

local function update_build_part(part: BasePart, size: Vector3?, cframe: CFrame?, color: Color3?): ()
	if size then
		part.Size = sanitize_size(size)
	end

	if cframe then
		part.CFrame = cframe
	end

	if color then
		part.Color = color
	end
end

local function delete_build_part(part: BasePart): ()
	part:Destroy()
end

local function move_player_to_cframe(targetPlayer: Player, targetCFrame: CFrame): ()
	local character = targetPlayer.Character

	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	rootPart.CFrame = targetCFrame
end

local function on_build_request(player: Player, payload: any): ()
	if not is_master(player) then
		return
	end

	if typeof(payload) ~= "table" then
		return
	end

	local action = payload.Action

	if action == "CreatePart" then
		if typeof(payload.Size) ~= "Vector3" or typeof(payload.CFrame) ~= "CFrame" then
			return
		end

		local color = typeof(payload.Color) == "Color3" and payload.Color or nil
		local buildKind = typeof(payload.BuildKind) == "string" and payload.BuildKind or nil

		create_build_part(payload.Size, payload.CFrame, color, buildKind)
		return
	end

	if action == "UpdatePart" then
		local part = payload.Part

		if not is_valid_build_part(part) then
			return
		end

		local size = typeof(payload.Size) == "Vector3" and payload.Size or nil
		local cframe = typeof(payload.CFrame) == "CFrame" and payload.CFrame or nil
		local color = typeof(payload.Color) == "Color3" and payload.Color or nil

		update_build_part(part, size, cframe, color)
		return
	end

	if action == "DeletePart" then
		local part = payload.Part

		if not is_valid_build_part(part) then
			return
		end

		delete_build_part(part)
		return
	end

	if action == "MovePlayer" then
		if typeof(payload.UserId) ~= "number" or typeof(payload.CFrame) ~= "CFrame" then
			return
		end

		local targetPlayer = Players:GetPlayerByUserId(payload.UserId)

		if not targetPlayer then
			return
		end

		move_player_to_cframe(targetPlayer, payload.CFrame)
	end
end

------------------//MAIN FUNCTIONS
masterBuildEvent.OnServerEvent:Connect(on_build_request)

------------------//INIT
get_build_folder()