------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//CONSTANTS
local MASTER_TEAM_NAME: string = "Mestre"

local TEAM_REMOTE_NAME: string = "TeamSelectEvent"
local TABLETOP_REMOTE_NAME: string = "TabletopEvent"
local ROLE_IMAGE_REMOTE_NAME: string = "RoleImageEvent"

local GUI_NAME: string = "MasterGui"
local RETURN_TO_MENU_ACTION: string = "ReturnToMenu"
local ROLE_IMAGE_ATTRIBUTE_NAME: string = "RoleImageId"
local MASTER_SPECTATOR_JUMP_ATTRIBUTE_NAME: string = "MasterSpectatorJumpCFrame"

local ORDER_ROW_HEIGHT: number = 42
local ORDER_ROW_PADDING: number = 6
local ORDER_ROW_SIZE: number = ORDER_ROW_HEIGHT + ORDER_ROW_PADDING

local PLAYERS_ROW_TEMPLATE_NAME: string = "PlayersListRowTemplate"
local ORDER_ROW_TEMPLATE_NAME: string = "OrderRowTemplate"

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local teamSelectEvent: RemoteEvent = remotesFolder:WaitForChild(TEAM_REMOTE_NAME)
local tabletopEvent: RemoteEvent = remotesFolder:WaitForChild(TABLETOP_REMOTE_NAME)
local roleImageEvent: RemoteEvent = remotesFolder:WaitForChild(ROLE_IMAGE_REMOTE_NAME)

local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local utilityFolder: Folder = modulesFolder:WaitForChild("Utility")
local SquareTransition = require(utilityFolder:WaitForChild("SquareTransition"))

local masterGui: ScreenGui? = nil
local topBar: Frame? = nil
local returnButton: TextButton? = nil
local environmentToggleButton: TextButton? = nil
local playersToggleButton: TextButton? = nil
local combatToggleButton: TextButton? = nil

local environmentWindow: Frame? = nil
local playersWindow: Frame? = nil
local combatWindow: Frame? = nil

local rainButton: TextButton? = nil
local playersList: ScrollingFrame? = nil
local orderList: ScrollingFrame? = nil
local activeTurnLabel: TextLabel? = nil
local turnModeButton: TextButton? = nil
local customClockTimeBox: TextBox? = nil
local applyClockTimeButton: TextButton? = nil

local cachedSnapshot = {
	ClockTime = 12,
	PresetName = "NeutralDay",
	RainEnabled = false,
	CombatStarted = false,
	IsSharedTurnModeEnabled = false,
	ActiveTurnIndex = 0,
	Characters = {},
	Order = {},
}

local localOrder = {}
local staticButtonsConnected: boolean = false
local dragState = {
	Active = false,
	Row = nil,
	Entry = nil,
	Index = 0,
	RowStartY = 0,
	StartMouseY = 0,
}

------------------//FUNCTIONS
local function is_master(): boolean
	return player.Team ~= nil and player.Team.Name == MASTER_TEAM_NAME
end

local function fire_tabletop(action: string, payload: any?): ()
	local request = payload or {}
	request.Action = action
	tabletopEvent:FireServer(request)
end

local function clone_order_from_snapshot(): ()
	localOrder = {}

	for _, orderData in cachedSnapshot.Order do
		table.insert(localOrder, {
			Character = orderData.Character,
			Label = orderData.Label,
			RoleName = orderData.RoleName,
			IsActive = orderData.IsActive,
		})
	end
end

local function get_order_characters(): {Model}
	local orderChars = {}

	for _, orderData in localOrder do
		table.insert(orderChars, orderData.Character)
	end

	return orderChars
end

local function sync_order_to_server(): ()
	fire_tabletop("SetCombatOrder", {
		OrderCharacters = get_order_characters(),
	})
end

local function clear_players_children(): ()
	if not playersList then
		return
	end

	for _, child in playersList:GetChildren() do
		if child.Name ~= PLAYERS_ROW_TEMPLATE_NAME and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function clear_order_children(): ()
	if not orderList then
		return
	end

	for _, child in orderList:GetChildren() do
		if child.Name ~= ORDER_ROW_TEMPLATE_NAME and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function clone_players_row_template(): Frame?
	if not playersList then
		return nil
	end

	local template = playersList:FindFirstChild(PLAYERS_ROW_TEMPLATE_NAME)
	if not template or not template:IsA("Frame") then
		warn("[MasterHudController] Template de player ausente em PlayersList")
		return nil
	end

	local row = template:Clone()
	row.Name = "PlayerRow"
	row.Visible = true
	row.Parent = playersList
	return row
end

local function clone_order_row_template(): Frame?
	if not orderList then
		return nil
	end

	local template = orderList:FindFirstChild(ORDER_ROW_TEMPLATE_NAME)
	if not template or not template:IsA("Frame") then
		warn("[MasterHudController] Template de ordem ausente em OrderList")
		return nil
	end

	local row = template:Clone()
	row.Name = "OrderRow"
	row.Visible = true
	row.Parent = orderList
	return row
end

local function cache_gui_objects(): ()
	local guiObject = playerGui:FindFirstChild(GUI_NAME)

	if not guiObject or not guiObject:IsA("ScreenGui") then
		masterGui = nil
		topBar = nil
		returnButton = nil
		environmentToggleButton = nil
		playersToggleButton = nil
		combatToggleButton = nil
		environmentWindow = nil
		playersWindow = nil
		combatWindow = nil
		rainButton = nil
		playersList = nil
		orderList = nil
		activeTurnLabel = nil
		turnModeButton = nil
		customClockTimeBox = nil
		applyClockTimeButton = nil
		return
	end

	masterGui = guiObject
	topBar = masterGui:FindFirstChild("TopBar")
	returnButton = topBar and topBar:FindFirstChild("ReturnButton") or nil
	environmentToggleButton = topBar and topBar:FindFirstChild("EnvironmentToggleButton") or nil
	playersToggleButton = topBar and topBar:FindFirstChild("PlayersToggleButton") or nil
	combatToggleButton = topBar and topBar:FindFirstChild("CombatToggleButton") or nil

	environmentWindow = masterGui:FindFirstChild("EnvironmentWindow")
	playersWindow = masterGui:FindFirstChild("PlayersWindow")
	combatWindow = masterGui:FindFirstChild("CombatWindow")

	local environmentBody = environmentWindow and environmentWindow:FindFirstChild("Body") or nil
	local playersBody = playersWindow and playersWindow:FindFirstChild("Body") or nil
	local combatBody = combatWindow and combatWindow:FindFirstChild("Body") or nil

	rainButton = environmentBody and environmentBody:FindFirstChild("RainButton") or nil
	customClockTimeBox = environmentBody and environmentBody:FindFirstChild("CustomClockTimeBox") or nil
	applyClockTimeButton = environmentBody and environmentBody:FindFirstChild("ApplyClockTimeButton") or nil

	playersList = playersBody and playersBody:FindFirstChild("PlayersList") or nil
	orderList = combatBody and combatBody:FindFirstChild("OrderList") or nil
	activeTurnLabel = combatBody and combatBody:FindFirstChild("ActiveTurnLabel") or nil

	turnModeButton = combatBody and combatBody:FindFirstChild("TurnModeButton") :: TextButton?
end

local function update_gui_visibility(): ()
	cache_gui_objects()

	if not masterGui then
		return
	end

	masterGui.Enabled = is_master()
end

local function toggle_window(window: Frame?): ()
	if not window then
		return
	end

	window.Visible = not window.Visible
end

local function close_window(window: Frame?): ()
	if not window then
		return
	end

	window.Visible = false
end

local function sanitize_number(value: string): number?
	local numberValue = tonumber(value)

	if not numberValue then
		return nil
	end

	return numberValue
end

local function get_character_image_id(character: Model): string
	if not character then
		return ""
	end

	local value = character:GetAttribute(ROLE_IMAGE_ATTRIBUTE_NAME)

	if typeof(value) ~= "string" then
		return ""
	end

	return value
end

local function render_players_list(): ()
	if not playersList then
		return
	end

	clear_players_children()

	for _, charData in cachedSnapshot.Characters do
		if charData.Character and charData.Character:GetAttribute("IsNPC") then
			continue
		end

		local row = clone_players_row_template()
		if not row then
			continue
		end

		local nameLabel = row:FindFirstChild("NameLabel")
		local stateLabel = row:FindFirstChild("StateLabel")
		local currentBox = row:FindFirstChild("CurrentHealthBox")
		local maxBox = row:FindFirstChild("MaxHealthBox")
		local teleportToPlayerButton = row:FindFirstChild("TeleportButton")
		local lockButton = row:FindFirstChild("LockButton")
		local addTurnButton = row:FindFirstChild("AddTurnButton")
		local imageIdBox = row:FindFirstChild("ImageIdBox")

		if not (nameLabel and nameLabel:IsA("TextLabel")) then
			row:Destroy()
			continue
		end
		if not (stateLabel and stateLabel:IsA("TextLabel")) then
			row:Destroy()
			continue
		end
		if not (currentBox and currentBox:IsA("TextBox")) then
			row:Destroy()
			continue
		end
		if not (maxBox and maxBox:IsA("TextBox")) then
			row:Destroy()
			continue
		end
		if not (teleportToPlayerButton and teleportToPlayerButton:IsA("TextButton")) then
			row:Destroy()
			continue
		end
		if not (lockButton and lockButton:IsA("TextButton")) then
			row:Destroy()
			continue
		end
		if not (addTurnButton and addTurnButton:IsA("TextButton")) then
			row:Destroy()
			continue
		end
		if not (imageIdBox and imageIdBox:IsA("TextBox")) then
			row:Destroy()
			continue
		end

		nameLabel.Text = charData.Label .. " [" .. (charData.RoleName ~= "" and charData.RoleName or "NPC") .. "]"
		stateLabel.Text = charData.MovementLocked and "Movimento: Travado" or "Movimento: Livre"
		stateLabel.TextColor3 = charData.MovementLocked and Color3.fromRGB(255, 170, 170) or Color3.fromRGB(170, 255, 170)
		currentBox.Text = tostring(math.floor(charData.CurrentHealth + 0.5))
		maxBox.Text = tostring(math.floor(charData.MaxHealth + 0.5))
		lockButton.Text = charData.ManualMovementLocked and "Desbloq." or "Bloquear"
		imageIdBox.Text = get_character_image_id(charData.Character)

		local function sync_health_fields(): ()
			local currentHealth = sanitize_number(currentBox.Text)
			local maxHealth = sanitize_number(maxBox.Text)

			if not currentHealth or not maxHealth then
				currentBox.Text = tostring(math.floor(charData.CurrentHealth + 0.5))
				maxBox.Text = tostring(math.floor(charData.MaxHealth + 0.5))
				return
			end

			fire_tabletop("SetCharacterHealth", {
				Character = charData.Character,
				CurrentHealth = currentHealth,
				MaxHealth = maxHealth,
			})
		end

		currentBox.FocusLost:Connect(function()
			sync_health_fields()
		end)

		maxBox.FocusLost:Connect(function()
			sync_health_fields()
		end)

		lockButton.MouseButton1Click:Connect(function()
			fire_tabletop("SetMovementLock", {
				Character = charData.Character,
				Enabled = not charData.ManualMovementLocked,
			})
		end)

		addTurnButton.MouseButton1Click:Connect(function()
			fire_tabletop("AddOrderEntry", {
				Character = charData.Character,
			})
		end)

		imageIdBox.FocusLost:Connect(function()
			roleImageEvent:FireServer({
				Character = charData.Character,
				ImageId = imageIdBox.Text,
			})
		end)

		teleportToPlayerButton.MouseButton1Click:Connect(function()
			local targetCharacter = charData.Character
			local rootPart = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
			if not rootPart or not rootPart:IsA("BasePart") then
				return
			end

			local targetCFrame = CFrame.lookAt(
				rootPart.Position + Vector3.new(0, 8, 12),
				rootPart.Position + Vector3.new(0, 2, 0)
			)
			player:SetAttribute(MASTER_SPECTATOR_JUMP_ATTRIBUTE_NAME, targetCFrame)
		end)
	end
end

local function get_drag_target_index(rowY: number): number
	if #localOrder == 0 then
		return 1
	end

	local targetIndex = math.floor((rowY + ORDER_ROW_HEIGHT * 0.5) / ORDER_ROW_SIZE) + 1
	return math.clamp(targetIndex, 1, #localOrder)
end

local function update_order_canvas(): ()
	if not orderList then
		return
	end

	local totalHeight = math.max(0, (#localOrder * ORDER_ROW_SIZE) - ORDER_ROW_PADDING)
	orderList.CanvasSize = UDim2.fromOffset(0, totalHeight)
end

local function render_order_list(): ()
	if not orderList then
		return
	end

	clear_order_children()
	update_order_canvas()

	for index, orderData in localOrder do
		local row = clone_order_row_template()
		if not row then
			continue
		end

		row.Position = UDim2.fromOffset(4, (index - 1) * ORDER_ROW_SIZE)
		row.BackgroundColor3 = orderData.IsActive and Color3.fromRGB(46, 52, 68) or Color3.fromRGB(26, 28, 34)

		local dragHandle = row:FindFirstChild("DragHandle")
		local removeButton = row:FindFirstChild("RemoveButton")
		local nameLabel = row:FindFirstChild("NameLabel")
		if not (dragHandle and dragHandle:IsA("TextButton")) then
			row:Destroy()
			continue
		end
		if not (removeButton and removeButton:IsA("TextButton")) then
			row:Destroy()
			continue
		end
		if not (nameLabel and nameLabel:IsA("TextLabel")) then
			row:Destroy()
			continue
		end

		nameLabel.Text = tostring(index) .. ". " .. orderData.Label

		removeButton.MouseButton1Click:Connect(function()
			fire_tabletop("RemoveOrderEntry", {
				Index = index,
			})
		end)

		dragHandle.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end

			dragState.Active = true
			dragState.Row = row
			dragState.Entry = orderData
			dragState.Index = index
			dragState.RowStartY = row.Position.Y.Offset
			dragState.StartMouseY = input.Position.Y

			row.ZIndex = 20
			dragHandle.ZIndex = 21
			removeButton.ZIndex = 21
			nameLabel.ZIndex = 21
		end)
	end
end

local function update_status_labels(): ()
	if rainButton then
		rainButton.Text = cachedSnapshot.RainEnabled and "Chuva: ON" or "Chuva: OFF"
	end

	if customClockTimeBox then
		customClockTimeBox.Text = string.format("%.2f", cachedSnapshot.ClockTime)
	end

	if turnModeButton then
		local isEnabled = cachedSnapshot.IsSharedTurnModeEnabled == true
		turnModeButton.Text = isEnabled and "Turno em Grupo: ON" or "Turno em Grupo: OFF"
		turnModeButton.BackgroundColor3 = isEnabled and Color3.fromRGB(255, 208, 74) or Color3.fromRGB(34, 36, 44)
		turnModeButton.TextColor3 = isEnabled and Color3.fromRGB(18, 18, 18) or Color3.fromRGB(255, 255, 255)
	end

	if activeTurnLabel then
		local currentText = "Turno atual: -"

		for _, orderData in cachedSnapshot.Order do
			if orderData.IsActive then
				currentText = "Turno atual: " .. orderData.Label
				break
			end
		end

		activeTurnLabel.Text = currentText
	end
end

local function render_snapshot(): ()
	update_gui_visibility()
	render_players_list()
	render_order_list()
	update_status_labels()
end

local function connect_window_close_buttons(window: Frame?): ()
	if not window then
		return
	end

	local header = window:FindFirstChild("Header")
	local closeButton = header and header:FindFirstChild("CloseButton") or nil

	if closeButton and closeButton:IsA("TextButton") then
		closeButton.MouseButton1Click:Connect(function()
			close_window(window)
		end)
	end
end

local function connect_button_click(button: TextButton?, callback: () -> ()): ()
	if not button then
		return
	end

	button.MouseButton1Click:Connect(callback)
end

local function connect_tabletop_button(button: TextButton?, action: string, payloadBuilder: (() -> any?)?): ()
	connect_button_click(button, function()
		local payload = nil

		if payloadBuilder then
			payload = payloadBuilder()
		end

		fire_tabletop(action, payload)
	end)
end

local function connect_static_buttons(): ()
	if staticButtonsConnected or not masterGui or not topBar then
		return
	end

	staticButtonsConnected = true

	local environmentBody = environmentWindow and environmentWindow:FindFirstChild("Body") or nil
	local combatBody = combatWindow and combatWindow:FindFirstChild("Body") or nil
	local playersHeader = playersWindow and playersWindow:FindFirstChild("Header") or nil

	local dawnButton = environmentBody and environmentBody:FindFirstChild("DawnButton") or nil
	local dayButton = environmentBody and environmentBody:FindFirstChild("DayButton") or nil
	local duskButton = environmentBody and environmentBody:FindFirstChild("DuskButton") or nil
	local nightButton = environmentBody and environmentBody:FindFirstChild("NightButton") or nil

	local neutralDayButton = environmentBody and environmentBody:FindFirstChild("NeutralDayButton") or nil
	local warmEveningButton = environmentBody and environmentBody:FindFirstChild("WarmEveningButton") or nil
	local coldNightButton = environmentBody and environmentBody:FindFirstChild("ColdNightButton") or nil

	local startCombatButton = combatBody and combatBody:FindFirstChild("StartCombatButton") or nil
	local nextTurnButton = combatBody and combatBody:FindFirstChild("NextTurnButton") or nil
	local stopCombatButton = combatBody and combatBody:FindFirstChild("StopCombatButton") or nil
	local clearOrderButton = combatBody and combatBody:FindFirstChild("ClearOrderButton") or nil
	local turnModeBodyButton = combatBody and combatBody:FindFirstChild("TurnModeButton") or nil
	local teleportAllHeaderButton = playersHeader and playersHeader:FindFirstChild("TeleportAllButton") or nil

	local windowsToConnect = {
		environmentWindow,
		playersWindow,
		combatWindow,
	}

	for _, window in windowsToConnect do
		connect_window_close_buttons(window)
	end

	connect_button_click(returnButton, function()
		local container: GuiObject? = playerGui:FindFirstChild("BothUI")
		if not container then
			container = masterGui
		end

		if not container then
			teamSelectEvent:FireServer({ Action = RETURN_TO_MENU_ACTION })
			return
		end

		if masterGui then
			masterGui.Enabled = false
		end

		local ok = pcall(function()
			SquareTransition.play(container, {
				tileSize = 100,
				onFilled = function()
					teamSelectEvent:FireServer({ Action = RETURN_TO_MENU_ACTION })
				end,
			})
		end)

		if not ok then
			teamSelectEvent:FireServer({ Action = RETURN_TO_MENU_ACTION })
		end
	end)

	connect_button_click(environmentToggleButton, function()
		toggle_window(environmentWindow)
	end)

	connect_button_click(playersToggleButton, function()
		toggle_window(playersWindow)
	end)

	connect_tabletop_button(teleportAllHeaderButton, "TeleportAllPlayersToMaster", nil)

	connect_button_click(combatToggleButton, function()
		toggle_window(combatWindow)
	end)

	connect_tabletop_button(rainButton, "SetRain", function()
		return {
			Enabled = not cachedSnapshot.RainEnabled,
		}
	end)

	local environmentBindings = {
		{
			Button = dawnButton,
			Action = "SetClockTime",
			Payload = function()
				return {
					Value = 6,
				}
			end,
		},
		{
			Button = dayButton,
			Action = "SetClockTime",
			Payload = function()
				return {
					Value = 12,
				}
			end,
		},
		{
			Button = duskButton,
			Action = "SetClockTime",
			Payload = function()
				return {
					Value = 18,
				}
			end,
		},
		{
			Button = nightButton,
			Action = "SetClockTime",
			Payload = function()
				return {
					Value = 0,
				}
			end,
		},
		{
			Button = neutralDayButton,
			Action = "ApplyPreset",
			Payload = function()
				return {
					PresetName = "NeutralDay",
				}
			end,
		},
		{
			Button = warmEveningButton,
			Action = "ApplyPreset",
			Payload = function()
				return {
					PresetName = "WarmEvening",
				}
			end,
		},
		{
			Button = coldNightButton,
			Action = "ApplyPreset",
			Payload = function()
				return {
					PresetName = "ColdNight",
				}
			end,
		},
	}

	for _, binding in environmentBindings do
		connect_tabletop_button(binding.Button, binding.Action, binding.Payload)
	end

	connect_button_click(applyClockTimeButton, function()
		if not customClockTimeBox then
			return
		end

		local numberValue = sanitize_number(customClockTimeBox.Text)

		if not numberValue then
			return
		end

		fire_tabletop("SetClockTime", {
			Value = numberValue,
		})
	end)

	local combatBindings = {
		{
			Button = startCombatButton,
			Action = "StartCombat",
		},
		{
			Button = nextTurnButton,
			Action = "NextTurn",
		},
		{
			Button = stopCombatButton,
			Action = "StopCombat",
		},
		{
			Button = clearOrderButton,
			Action = "ClearCombatOrder",
		},
	}

	for _, binding in combatBindings do
		connect_tabletop_button(binding.Button, binding.Action, nil)
	end

	connect_button_click(turnModeBodyButton, function()
		fire_tabletop("SetSharedTurnMode", {
			Enabled = not (cachedSnapshot.IsSharedTurnModeEnabled == true),
		})
	end)
end

local function request_snapshot(): ()
	fire_tabletop("RequestSnapshot")
end

local function on_snapshot_received(payload: any): ()
	if typeof(payload) ~= "table" or payload.Action ~= "Snapshot" or typeof(payload.State) ~= "table" then
		return
	end

	cachedSnapshot = payload.State

	if not dragState.Active then
		clone_order_from_snapshot()
	end

	render_snapshot()
end

local function on_gui_added(child: Instance): ()
	if child.Name ~= GUI_NAME then
		return
	end

	staticButtonsConnected = false

	task.defer(function()
		cache_gui_objects()
		connect_static_buttons()
		render_snapshot()
	end)
end

local function finish_drag(): ()
	if not dragState.Active or not dragState.Row or not dragState.Entry then
		return
	end

	local row = dragState.Row
	local fromIndex = dragState.Index
	local targetIndex = get_drag_target_index(row.Position.Y.Offset)

	row.ZIndex = 1

	if fromIndex >= 1 and fromIndex <= #localOrder then
		table.remove(localOrder, fromIndex)
		table.insert(localOrder, targetIndex, dragState.Entry)
	end

	dragState.Active = false
	dragState.Row = nil
	dragState.Entry = nil
	dragState.Index = 0
	dragState.RowStartY = 0
	dragState.StartMouseY = 0

	render_order_list()
	sync_order_to_server()
end

------------------//MAIN FUNCTIONS
tabletopEvent.OnClientEvent:Connect(on_snapshot_received)

UserInputService.InputChanged:Connect(function(input: InputObject)
	if not dragState.Active or not dragState.Row then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end

	local deltaY = input.Position.Y - dragState.StartMouseY
	local newY = math.max(0, dragState.RowStartY + deltaY)

	dragState.Row.Position = UDim2.fromOffset(4, newY)
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		finish_drag()
	end
end)

player:GetPropertyChangedSignal("Team"):Connect(function()
	update_gui_visibility()

	if is_master() then
		request_snapshot()
	end
end)

playerGui.ChildAdded:Connect(on_gui_added)

------------------//INIT
cache_gui_objects()
connect_static_buttons()
clone_order_from_snapshot()
update_gui_visibility()
request_snapshot()