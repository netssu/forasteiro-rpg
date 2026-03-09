------------------//SERVICES
local Players: Players = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")
local Workspace: Workspace = game:GetService("Workspace")

------------------//CONSTANTS
local PLAYER_TEAM_NAME: string = "Jogador"
local GUI_NAME: string = "PlayerHud"

local MAX_DISTANCE: number = 9.0
local POINT_INTERVAL: number = 0.5
local TELEPORT_THRESHOLD: number = 8.0
local DEFAULT_WALKSPEED: number = 16

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local moveFrame: Frame? = nil
local distanceLabel: TextLabel? = nil
local undoButton: TextButton? = nil

local trailFolder: Folder? = nil
local trailParts = {}

local isTracking: boolean = false
local isMyTurn: boolean = false
local startCFrame: CFrame? = nil
local lastPoint: Vector3? = nil
local currentDistance: number = 0

local uiConnected: boolean = false

------------------//FUNCTIONS
local function is_player_role(): boolean
	return player.Team ~= nil and player.Team.Name == PLAYER_TEAM_NAME
end

local function get_trail_folder(): Folder
	if trailFolder and trailFolder.Parent == Workspace then
		return trailFolder
	end

	local folder = Workspace:FindFirstChild("PlayerTrails")

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PlayerTrails"
		folder.Parent = Workspace
	end

	trailFolder = folder
	return folder
end

local function clear_trail(): ()
	for _, part in trailParts do
		if part then
			part:Destroy()
		end
	end

	table.clear(trailParts)
end

local function update_ui(): ()
	if not distanceLabel then return end

	distanceLabel.Text = string.format("%.1f / %.1f m", currentDistance, MAX_DISTANCE)

	if currentDistance >= MAX_DISTANCE then
		distanceLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	else
		distanceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

local function restore_walkspeed(): ()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.WalkSpeed = DEFAULT_WALKSPEED
	end
end

local function block_walkspeed(): ()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.WalkSpeed = 0
	end
end

local function start_new_path(rootPart: BasePart): ()
	startCFrame = rootPart.CFrame
	lastPoint = rootPart.Position - Vector3.new(0, 2.5, 0)
	currentDistance = 0
	clear_trail()
	restore_walkspeed()
	update_ui()
end

local function set_turn_state(state: boolean): ()
	if not is_player_role() then
		state = false
	end

	isMyTurn = state

	if moveFrame then
		moveFrame.Visible = isMyTurn
	end

	isTracking = isMyTurn

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	if isMyTurn then
		if rootPart then
			start_new_path(rootPart)
		end
	else
		clear_trail()
		restore_walkspeed()
	end
end

local function undo_path(): ()
	if not isMyTurn then return end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	if rootPart and startCFrame then
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		rootPart.CFrame = startCFrame

		start_new_path(rootPart)
	end
end

local function get_rotation_only_cframe(cframe: CFrame): CFrame
	local rx, ry, rz = cframe:ToOrientation()
	return CFrame.fromOrientation(rx, ry, rz)
end

local function draw_segment(p1: Vector3, p2: Vector3): ()
	local distance = (p2 - p1).Magnitude
	local folder = get_trail_folder()

	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 255, 255)

	part.Size = Vector3.new(0.15, 0.15, distance)
	part.CFrame = CFrame.lookAt(p1, p2) * CFrame.new(0, 0, -distance / 2)
	part.Parent = folder

	table.insert(trailParts, part)
end

local function cache_ui(): ()
	local hud = playerGui:FindFirstChild(GUI_NAME)

	if not hud then return end

	local main = hud:FindFirstChild("Main")
	if main then
		moveFrame = main:FindFirstChild("MovementFrame")

		if moveFrame then
			distanceLabel = moveFrame:FindFirstChild("DistanceLabel")
			undoButton = moveFrame:FindFirstChild("UndoButton")

			if not uiConnected then
				if undoButton then
					undoButton.Text = "Desfazer (Z)"
					undoButton.MouseButton1Click:Connect(undo_path)
				end
				uiConnected = true
			end
		end
	end
end

local function update_visibility(): ()
	cache_ui()
	local isPlayer = is_player_role()

	if not isPlayer and isMyTurn then
		set_turn_state(false)
	end
end

------------------//MAIN FUNCTIONS
RunService.RenderStepped:Connect(function()
	if not isTracking then return end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	if not rootPart then return end

	if not startCFrame or not lastPoint then
		start_new_path(rootPart)
		return
	end

	if currentDistance >= MAX_DISTANCE then
		block_walkspeed()
		return
	end

	local currentFootPos = rootPart.Position - Vector3.new(0, 2.5, 0)
	local distanceMoved = (currentFootPos - lastPoint).Magnitude

	if distanceMoved > TELEPORT_THRESHOLD then
		start_new_path(rootPart)
		return
	end

	if distanceMoved >= POINT_INTERVAL then
		if currentDistance + distanceMoved >= MAX_DISTANCE then
			local remaining = MAX_DISTANCE - currentDistance
			local direction = (currentFootPos - lastPoint).Unit
			local finalPos = lastPoint + direction * remaining

			draw_segment(lastPoint, finalPos)
			currentDistance = MAX_DISTANCE
			lastPoint = finalPos

			rootPart.CFrame = CFrame.new(finalPos + Vector3.new(0, 2.5, 0)) * get_rotation_only_cframe(rootPart.CFrame)

			block_walkspeed()
			update_ui()
		else
			draw_segment(lastPoint, currentFootPos)
			currentDistance += distanceMoved
			lastPoint = currentFootPos
			update_ui()
		end
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if not is_player_role() then return end

	if input.KeyCode == Enum.KeyCode.T then
		set_turn_state(not isMyTurn)
		return
	end

	if isMyTurn then
		if input.KeyCode == Enum.KeyCode.Z then
			undo_path()
		end
	end
end)

player:GetPropertyChangedSignal("Team"):Connect(update_visibility)

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	update_visibility()

	if isMyTurn then
		set_turn_state(false)
	end
end)

playerGui.ChildAdded:Connect(function(child: Instance)
	if child.Name == GUI_NAME then
		update_visibility()
	end
end)

------------------//INIT
get_trail_folder()
update_visibility()
set_turn_state(false)