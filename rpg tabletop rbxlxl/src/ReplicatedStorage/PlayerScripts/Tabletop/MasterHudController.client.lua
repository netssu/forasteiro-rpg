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

local ORDER_ROW_HEIGHT: number = 42
local ORDER_ROW_PADDING: number = 6
local ORDER_ROW_SIZE: number = ORDER_ROW_HEIGHT + ORDER_ROW_PADDING

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local teamSelectEvent: RemoteEvent = remotesFolder:WaitForChild(TEAM_REMOTE_NAME)
local tabletopEvent: RemoteEvent = remotesFolder:WaitForChild(TABLETOP_REMOTE_NAME)
local roleImageEvent: RemoteEvent = remotesFolder:WaitForChild(ROLE_IMAGE_REMOTE_NAME)

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
local customClockTimeBox: TextBox? = nil
local applyClockTimeButton: TextButton? = nil

local cachedSnapshot = {
	ClockTime = 12,
	PresetName = "NeutralDay",
	RainEnabled = false,
	CombatStarted = false,
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
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function clear_order_children(): ()
	if not orderList then
		return
	end

	for _, child in orderList:GetChildren() do
		child:Destroy()
	end
end

local function create_corner(parent: Instance, radius: number): ()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function create_stroke(parent: Instance, thickness: number, transparency: number): ()
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.Parent = parent
end

local function create_text_button(parent: Instance, text: string, size: UDim2, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 13
	button.AutoButtonColor = true
	button.Parent = parent

	create_corner(button, 10)
	create_stroke(button, 1, 0.75)

	return button
end

local function create_text_box(parent: Instance, text: string, size: UDim2, position: UDim2): TextBox
	local textBox = Instance.new("TextBox")
	textBox.Size = size
	textBox.Position = position
	textBox.BackgroundColor3 = Color3.fromRGB(24, 25, 32)
	textBox.BorderSizePixel = 0
	textBox.ClearTextOnFocus = false
	textBox.Font = Enum.Font.GothamMedium
	textBox.Text = text
	textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	textBox.TextSize = 13
	textBox.Parent = parent

	create_corner(textBox, 8)
	create_stroke(textBox, 1, 0.8)

	return textBox
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
		-- Pula a criação da interface se o personagem for um NPC
		if charData.Character and charData.Character:GetAttribute("IsNPC") then
			continue
		end

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 118)
		row.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
		row.BorderSizePixel = 0
		row.Parent = playersList

		create_corner(row, 10)
		create_stroke(row, 1, 0.8)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.fromOffset(10, 6)
		nameLabel.Size = UDim2.new(1, -20, 0, 18)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = charData.Label .. " [" .. (charData.RoleName ~= "" and charData.RoleName or "NPC") .. "]"
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 13
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local stateLabel = Instance.new("TextLabel")
		stateLabel.BackgroundTransparency = 1
		stateLabel.Position = UDim2.fromOffset(10, 26)
		stateLabel.Size = UDim2.new(1, -20, 0, 16)
		stateLabel.Font = Enum.Font.GothamMedium
		stateLabel.Text = charData.MovementLocked and "Movimento: Travado" or "Movimento: Livre"
		stateLabel.TextColor3 = charData.MovementLocked and Color3.fromRGB(255, 170, 170) or Color3.fromRGB(170, 255, 170)
		stateLabel.TextSize = 12
		stateLabel.TextXAlignment = Enum.TextXAlignment.Left
		stateLabel.Parent = row

		local hpLabel = Instance.new("TextLabel")
		hpLabel.BackgroundTransparency = 1
		hpLabel.Position = UDim2.fromOffset(10, 48)
		hpLabel.Size = UDim2.fromOffset(26, 24)
		hpLabel.Font = Enum.Font.GothamBold
		hpLabel.Text = "HP"
		hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		hpLabel.TextSize = 12
		hpLabel.Parent = row

		local currentBox = create_text_box(row, tostring(math.floor(charData.CurrentHealth + 0.5)), UDim2.fromOffset(56, 24), UDim2.fromOffset(40, 48))

		local slashLabel = Instance.new("TextLabel")
		slashLabel.BackgroundTransparency = 1
		slashLabel.Position = UDim2.fromOffset(101, 48)
		slashLabel.Size = UDim2.fromOffset(14, 24)
		slashLabel.Font = Enum.Font.GothamBold
		slashLabel.Text = "/"
		slashLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		slashLabel.TextSize = 12
		slashLabel.Parent = row

		local maxBox = create_text_box(row, tostring(math.floor(charData.MaxHealth + 0.5)), UDim2.fromOffset(56, 24), UDim2.fromOffset(118, 48))
		local applyButton = create_text_button(row, "Aplicar", UDim2.fromOffset(70, 24), UDim2.fromOffset(182, 48))
		local lockButton = create_text_button(row, charData.ManualMovementLocked and "Desbloq." or "Bloquear", UDim2.fromOffset(84, 24), UDim2.fromOffset(262, 48))
		local addTurnButton = create_text_button(row, "Add Turno", UDim2.fromOffset(88, 24), UDim2.fromOffset(354, 48))

		local imageLabel = Instance.new("TextLabel")
		imageLabel.BackgroundTransparency = 1
		imageLabel.Position = UDim2.fromOffset(10, 82)
		imageLabel.Size = UDim2.fromOffset(46, 24)
		imageLabel.Font = Enum.Font.GothamBold
		imageLabel.Text = "IMG"
		imageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		imageLabel.TextSize = 12
		imageLabel.Parent = row

		local imageIdBox = create_text_box(row, get_character_image_id(charData.Character), UDim2.fromOffset(240, 24), UDim2.fromOffset(52, 82))
		local applyImageButton = create_text_button(row, "Setar", UDim2.fromOffset(70, 24), UDim2.fromOffset(300, 82))

		applyButton.MouseButton1Click:Connect(function()
			local currentHealth = sanitize_number(currentBox.Text)
			local maxHealth = sanitize_number(maxBox.Text)

			if not currentHealth or not maxHealth then
				return
			end

			fire_tabletop("SetCharacterHealth", {
				Character = charData.Character,
				CurrentHealth = currentHealth,
				MaxHealth = maxHealth,
			})
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

		applyImageButton.MouseButton1Click:Connect(function()
			roleImageEvent:FireServer({
				Character = charData.Character,
				ImageId = imageIdBox.Text,
			})
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
		local row = Instance.new("Frame")
		row.Name = "OrderRow"
		row.Size = UDim2.new(1, -8, 0, ORDER_ROW_HEIGHT)
		row.Position = UDim2.fromOffset(4, (index - 1) * ORDER_ROW_SIZE)
		row.BackgroundColor3 = orderData.IsActive and Color3.fromRGB(46, 52, 68) or Color3.fromRGB(26, 28, 34)
		row.BorderSizePixel = 0
		row.Parent = orderList

		create_corner(row, 10)
		create_stroke(row, 1, 0.8)

		local dragHandle = create_text_button(row, "↕", UDim2.fromOffset(28, 24), UDim2.fromOffset(8, 9))
		local removeButton = create_text_button(row, "X", UDim2.fromOffset(28, 24), UDim2.new(1, -36, 0, 9))

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.fromOffset(46, 0)
		nameLabel.Size = UDim2.new(1, -90, 1, 0)
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.Text = tostring(index) .. ". " .. orderData.Label
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 13
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

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

	local windowsToConnect = {
		environmentWindow,
		playersWindow,
		combatWindow,
	}

	for _, window in windowsToConnect do
		connect_window_close_buttons(window)
	end

	connect_button_click(returnButton, function()
		teamSelectEvent:FireServer({
			Action = RETURN_TO_MENU_ACTION,
		})
	end)

	connect_button_click(environmentToggleButton, function()
		toggle_window(environmentWindow)
	end)

	connect_button_click(playersToggleButton, function()
		toggle_window(playersWindow)
	end)

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