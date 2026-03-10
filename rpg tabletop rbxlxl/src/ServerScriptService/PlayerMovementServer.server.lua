------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local ASSETS_FOLDER_NAME: string = "Assets"
local REMOTES_FOLDER_NAME: string = "Remotes"
local REMOTE_NAME: string = "PlayerMovementEvent"
local TURN_REMOTE_NAME: string = "PlayerTurnEvent"
local TRAIL_FOLDER_NAME: string = "PlayerTrails"

------------------//VARIABLES
local assetsFolder: Folder = ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME)
local remotesFolder: Folder = assetsFolder:WaitForChild(REMOTES_FOLDER_NAME)
local movementEvent: RemoteEvent = remotesFolder:FindFirstChild(REMOTE_NAME) or Instance.new("RemoteEvent")
local turnEvent: RemoteEvent = remotesFolder:FindFirstChild(TURN_REMOTE_NAME) or Instance.new("RemoteEvent")

------------------//FUNCTIONS
local function get_main_trail_folder(): Folder
	local folder = workspace:FindFirstChild(TRAIL_FOLDER_NAME)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = TRAIL_FOLDER_NAME
		folder.Parent = workspace
	end

	return folder
end

local function get_player_trail_folder(player: Player): Folder
	local mainFolder = get_main_trail_folder()
	local playerFolder = mainFolder:FindFirstChild(player.Name)

	if not playerFolder then
		playerFolder = Instance.new("Folder")
		playerFolder.Name = player.Name
		playerFolder.Parent = mainFolder
	end

	return playerFolder
end

local function handle_movement_event(player: Player, data: any): ()
	if type(data) ~= "table" then return end

	local action = data.Action

	if action == "ClearTrail" then
		local playerFolder = get_player_trail_folder(player)
		playerFolder:ClearAllChildren()

	elseif action == "DrawSegment" then
		local p1 = data.P1
		local p2 = data.P2

		if typeof(p1) == "Vector3" and typeof(p2) == "Vector3" then
			local playerFolder = get_player_trail_folder(player)
			local distance = (p2 - p1).Magnitude

			if distance > 0.05 then
				local part = Instance.new("Part")
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.Material = Enum.Material.Neon
				part.Color = Color3.fromRGB(255, 255, 255)
				part.Size = Vector3.new(0.15, 0.15, distance)
				part.CFrame = CFrame.lookAt(p1, p2) * CFrame.new(0, 0, -distance / 2)
				part.Parent = playerFolder
			end
		end
	end
end

local function on_player_removing(player: Player): ()
	local mainFolder = workspace:FindFirstChild(TRAIL_FOLDER_NAME)

	if mainFolder then
		local playerFolder = mainFolder:FindFirstChild(player.Name)
		if playerFolder then
			playerFolder:Destroy()
		end
	end
end

------------------//MAIN FUNCTIONS
movementEvent.OnServerEvent:Connect(handle_movement_event)
Players.PlayerRemoving:Connect(on_player_removing)

------------------//INIT
if movementEvent.Name ~= REMOTE_NAME then
	movementEvent.Name = REMOTE_NAME
	movementEvent.Parent = remotesFolder
end

if turnEvent.Name ~= TURN_REMOTE_NAME then
	turnEvent.Name = TURN_REMOTE_NAME
	turnEvent.Parent = remotesFolder
end