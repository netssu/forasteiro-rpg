------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//MODULES
local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local dictionaryFolder: Folder = modulesFolder:WaitForChild("Dictionary")
local utilityFolder: Folder = modulesFolder:WaitForChild("Utility")
local MovementDictionary = require(dictionaryFolder:WaitForChild("MovementDictionary"))
local MovementRemoteUtility = require(utilityFolder:WaitForChild("MovementRemoteUtility"))

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local movementEvent: RemoteEvent
local turnEvent: RemoteEvent

local moveFrame: Frame? = nil
local distanceLabel: TextLabel? = nil
local undoButton: TextButton? = nil
local undoConnection: RBXScriptConnection? = nil

local isTracking = false
local isMyTurn = false
local serverTurnActive = false
local startCFrame: CFrame? = nil
local lastPoint: Vector3? = nil
local currentDistance = 0

------------------//FUNCTIONS
local function is_player_role(): boolean
	if player.Team and player.Team.Name == MovementDictionary.PLAYER_TEAM_NAME then
		return true
	end

	local character = player.Character
	if player.Team and player.Team.Name == MovementDictionary.MASTER_TEAM_NAME and character and character:GetAttribute("IsNPC") then
		return true
	end

	return false
end

local function is_player_spectator_enabled(): boolean
	return player:GetAttribute(MovementDictionary.PLAYER_SPECTATOR_ATTRIBUTE_NAME) == true
end

local function clear_trail(): ()
	movementEvent:FireServer({ Action = MovementDictionary.CLEAR_TRAIL_ACTION })
end

local function update_ui(): ()
	if not distanceLabel then
		return
	end

	local distanceInMeters = currentDistance / MovementDictionary.STUDS_PER_METER
	distanceLabel.Text = string.format("%.1f / %.1f m", distanceInMeters, MovementDictionary.MAX_DISTANCE_METERS)
	distanceLabel.TextColor3 = currentDistance >= MovementDictionary.MAX_DISTANCE_STUDS and MovementDictionary.DISTANCE_TEXT_COLOR_LIMIT or MovementDictionary.DISTANCE_TEXT_COLOR_DEFAULT
end

local function restore_walkspeed(): ()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = MovementDictionary.DEFAULT_WALKSPEED
	end
end

local function block_walkspeed(): ()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
	end
end

local function get_root_part(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function get_rotation_only_cframe(cframe: CFrame): CFrame
	local rx, ry, rz = cframe:ToOrientation()
	return CFrame.fromOrientation(rx, ry, rz)
end

local function draw_segment(p1: Vector3, p2: Vector3): ()
	movementEvent:FireServer({
		Action = MovementDictionary.DRAW_SEGMENT_ACTION,
		P1 = p1,
		P2 = p2,
	})
end

local function start_new_path(rootPart: BasePart): ()
	startCFrame = rootPart.CFrame
	lastPoint = rootPart.Position - Vector3.new(0, MovementDictionary.FOOT_HEIGHT_OFFSET, 0)
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
	isTracking = isMyTurn

	if moveFrame then
		moveFrame.Visible = isMyTurn and not is_player_spectator_enabled()
	end

	local rootPart = get_root_part()
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
	if not isMyTurn then
		return
	end

	local rootPart = get_root_part()
	if rootPart and startCFrame then
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		rootPart.CFrame = startCFrame
		start_new_path(rootPart)
	end
end

local function bind_undo_button(): ()
	if undoConnection then
		undoConnection:Disconnect()
		undoConnection = nil
	end

	if undoButton then
		undoButton.Text = MovementDictionary.UNDO_BUTTON_TEXT
		undoConnection = undoButton.MouseButton1Click:Connect(undo_path)
	end
end

local function cache_ui(): ()
	local hud = playerGui:FindFirstChild(MovementDictionary.GUI_NAME)
	if not hud then
		moveFrame = nil
		distanceLabel = nil
		undoButton = nil
		return
	end

	local main = hud:FindFirstChild(MovementDictionary.MAIN_FRAME_NAME)
	if not main then
		moveFrame = nil
		distanceLabel = nil
		undoButton = nil
		return
	end

	moveFrame = main:FindFirstChild(MovementDictionary.MOVEMENT_FRAME_NAME) :: Frame?
	if not moveFrame then
		distanceLabel = nil
		undoButton = nil
		return
	end

	distanceLabel = moveFrame:FindFirstChild(MovementDictionary.DISTANCE_LABEL_NAME) :: TextLabel?
	undoButton = moveFrame:FindFirstChild(MovementDictionary.UNDO_BUTTON_NAME) :: TextButton?
	bind_undo_button()
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

local function on_render_stepped(): ()
	if not isTracking then
		return
	end

	local rootPart = get_root_part()
	if not rootPart then
		return
	end

	if not startCFrame or not lastPoint then
		start_new_path(rootPart)
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local currentMaxDistance = character:GetAttribute(MovementDictionary.MAX_MOVEMENT_DISTANCE_ATTRIBUTE_NAME) or MovementDictionary.MAX_DISTANCE_STUDS
	if currentDistance >= currentMaxDistance then
		block_walkspeed()
		return
	end

	local currentFootPos = rootPart.Position - Vector3.new(0, MovementDictionary.FOOT_HEIGHT_OFFSET, 0)
	local distanceMoved = (currentFootPos - lastPoint).Magnitude

	if distanceMoved > MovementDictionary.TELEPORT_THRESHOLD then
		start_new_path(rootPart)
		return
	end

	if distanceMoved < MovementDictionary.POINT_INTERVAL then
		return
	end

	if currentDistance + distanceMoved >= currentMaxDistance then
		local remaining = currentMaxDistance - currentDistance
		local direction = (currentFootPos - lastPoint).Unit
		local finalPos = lastPoint + direction * remaining

		draw_segment(lastPoint, finalPos)
		currentDistance = currentMaxDistance
		lastPoint = finalPos

		rootPart.CFrame = CFrame.new(finalPos + Vector3.new(0, MovementDictionary.FOOT_HEIGHT_OFFSET, 0)) * get_rotation_only_cframe(rootPart.CFrame)
		block_walkspeed()
		update_ui()
		return
	end

	draw_segment(lastPoint, currentFootPos)
	currentDistance += distanceMoved
	lastPoint = currentFootPos
	update_ui()
end

local function on_input_began(input: InputObject, gameProcessed: boolean): ()
	if gameProcessed then
		return
	end

	if not is_player_role() or is_player_spectator_enabled() then
		return
	end

	if isMyTurn and input.KeyCode == MovementDictionary.UNDO_KEYCODE then
		undo_path()
	end
end

local function on_turn_event(state: boolean): ()
	serverTurnActive = state
	set_turn_state(state)
end

local function on_spectator_changed(): ()
	update_visibility()
	set_turn_state(serverTurnActive)
end

local function on_character_added(): ()
	task.wait(0.5)
	update_visibility()

	if isMyTurn then
		set_turn_state(false)
	end
end

local function on_gui_added(child: Instance): ()
	if child.Name == MovementDictionary.GUI_NAME then
		update_visibility()
	end
end

------------------//MAIN FUNCTIONS
local MovementController = {}

function MovementController.run(): ()
	movementEvent = MovementRemoteUtility.get_movement_remote()
	turnEvent = MovementRemoteUtility.get_turn_remote()

	RunService.RenderStepped:Connect(on_render_stepped)
	UserInputService.InputBegan:Connect(on_input_began)
	turnEvent.OnClientEvent:Connect(on_turn_event)
	player:GetAttributeChangedSignal(MovementDictionary.PLAYER_SPECTATOR_ATTRIBUTE_NAME):Connect(on_spectator_changed)
	player:GetPropertyChangedSignal("Team"):Connect(update_visibility)
	player.CharacterAdded:Connect(on_character_added)
	playerGui.ChildAdded:Connect(on_gui_added)

	update_visibility()
	set_turn_state(false)
end

return MovementController
