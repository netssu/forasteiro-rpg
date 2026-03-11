------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")
local Workspace: Workspace = game:GetService("Workspace")

------------------//CONSTANTS
local PLAYER_TEAM_NAME: string = "Jogador"
local GUI_NAME: string = "PlayerHud"
local ASSETS_FOLDER_NAME: string = "Assets"
local REMOTES_FOLDER_NAME: string = "Remotes"
local REMOTE_NAME: string = "PlayerMovementEvent"
local TURN_REMOTE_NAME: string = "PlayerTurnEvent"
local PLAYER_SPECTATOR_ATTRIBUTE_NAME: string = "PlayerSpectatorEnabled"

local MAX_DISTANCE_METERS: number = 9.0
local STUDS_PER_METER: number = 3.6
local MAX_DISTANCE_STUDS: number = MAX_DISTANCE_METERS * STUDS_PER_METER

local POINT_INTERVAL: number = 0.5
local TELEPORT_THRESHOLD: number = 8.0
local DEFAULT_WALKSPEED: number = 16

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local assetsFolder: Folder = ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME)
local remotesFolder: Folder = assetsFolder:WaitForChild(REMOTES_FOLDER_NAME)
local movementEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)
local turnEvent: RemoteEvent = remotesFolder:WaitForChild(TURN_REMOTE_NAME)

local moveFrame: Frame? = nil
local distanceLabel: TextLabel? = nil
local undoButton: TextButton? = nil

local isTracking: boolean = false
local isMyTurn: boolean = false
local serverTurnActive: boolean = false
local startCFrame: CFrame? = nil
local lastPoint: Vector3? = nil
local currentDistance: number = 0

local uiConnected: boolean = false

------------------//FUNCTIONS
local function is_player_role(): boolean
	if player.Team ~= nil and player.Team.Name == PLAYER_TEAM_NAME then return true end

	local char = player.Character
	if player.Team ~= nil and player.Team.Name == "Mestre" and char and char:GetAttribute("IsNPC") then
		return true
	end

	return false
end

local function is_player_spectator_enabled(): boolean
	return player:GetAttribute(PLAYER_SPECTATOR_ATTRIBUTE_NAME) == true
end

local function clear_trail(): ()
	movementEvent:FireServer({ Action = "ClearTrail" })
end

local function update_ui(): ()
	if not distanceLabel then return end

	local distanceInMeters = currentDistance / STUDS_PER_METER
	distanceLabel.Text = string.format("%.1f / %.1f m", distanceInMeters, MAX_DISTANCE_METERS)

	if currentDistance >= MAX_DISTANCE_STUDS then
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
	if not is_player_role() or is_player_spectator_enabled() then
		state = false
	end

	isMyTurn = state

	if moveFrame then
		moveFrame.Visible = isMyTurn and not is_player_spectator_enabled()
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
	movementEvent:FireServer({
		Action = "DrawSegment",
		P1 = p1,
		P2 = p2
	})
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
	local isSpectator = is_player_spectator_enabled()

	if moveFrame then
		moveFrame.Visible = isMyTurn and isPlayer and not isSpectator
	end

	if (not isPlayer or isSpectator) and isMyTurn then
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

	local currentMaxDistance = character:GetAttribute("MaxMovementDistance") or MAX_DISTANCE_STUDS

	if currentDistance >= currentMaxDistance then
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
		if currentDistance + distanceMoved >= currentMaxDistance then
			local remaining = currentMaxDistance - currentDistance
			local direction = (currentFootPos - lastPoint).Unit
			local finalPos = lastPoint + direction * remaining

			draw_segment(lastPoint, finalPos)
			currentDistance = currentMaxDistance
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
	if is_player_spectator_enabled() then return end

	if isMyTurn then
		if input.KeyCode == Enum.KeyCode.Z then
			undo_path()
		end
	end
end)

turnEvent.OnClientEvent:Connect(function(state: boolean)
	serverTurnActive = state
	set_turn_state(state)
end)

player:GetAttributeChangedSignal(PLAYER_SPECTATOR_ATTRIBUTE_NAME):Connect(function()
	update_visibility()
	set_turn_state(serverTurnActive)
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
update_visibility()
set_turn_state(false)