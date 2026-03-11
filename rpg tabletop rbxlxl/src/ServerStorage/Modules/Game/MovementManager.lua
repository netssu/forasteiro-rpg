------------------//SERVICES


------------------//CONSTANTS
local TRAIL_FOLDER_NAME: string = "PlayerTrails"

------------------//VARIABLES
local MovementManager = {}
local trailsFolder: Folder = workspace:WaitForChild(TRAIL_FOLDER_NAME)

------------------//FUNCTIONS
local function get_player_trail_folder(player: Player): Folder
	local playerFolder = trailsFolder:FindFirstChild(player.Name)

	if not playerFolder then
		playerFolder = Instance.new("Folder")
		playerFolder.Name = player.Name
		playerFolder.Parent = trailsFolder
	end

	return playerFolder
end

function MovementManager.clear_trail(player: Player): ()
	local playerFolder = trailsFolder:FindFirstChild(player.Name)
	if playerFolder then
		playerFolder:ClearAllChildren()
	end
end

function MovementManager.draw_segment(player: Player, p1: Vector3, p2: Vector3): ()
	local distance = (p2 - p1).Magnitude

	if distance <= 0.05 then
		return
	end

	local playerFolder = get_player_trail_folder(player)

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

function MovementManager.remove_player(player: Player): ()
	local playerFolder = trailsFolder:FindFirstChild(player.Name)
	if playerFolder then
		playerFolder:Destroy()
	end
end

function MovementManager.process_request(player: Player, data: any): ()
	if typeof(data) ~= "table" then
		return
	end

	local action = data.Action

	if action == "ClearTrail" then
		MovementManager.clear_trail(player)
		return
	end

	if action == "DrawSegment" then
		local p1 = data.P1
		local p2 = data.P2

		if typeof(p1) == "Vector3" and typeof(p2) == "Vector3" then
			MovementManager.draw_segment(player, p1, p2)
		end
	end
end

return MovementManager