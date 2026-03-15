------------------//SERVICES
local StarterGui: StarterGui = game:GetService("StarterGui")

------------------//CONSTANTS
local MASTER_GUI_NAME: string = "MasterGui"
local PLAYER_HUD_NAME: string = "PlayerHud"

local SPECTATOR_BUTTON_NAME: string = "PlayerSpectatorToggleButton"
local PREFAB_ITEM_GRID_LAYOUT_NAME: string = "PrefabItemGridLayout"
local PREFAB_CATEGORY_LIST_LAYOUT_NAME: string = "PrefabCategoryListLayout"
local NPC_LIST_LAYOUT_NAME: string = "NpcListLayout"

local PLAYERS_ROW_TEMPLATE_NAME: string = "PlayersListRowTemplate"
local PLAYERS_LIST_LAYOUT_NAME: string = "PlayersListLayout"
local ORDER_ROW_TEMPLATE_NAME: string = "OrderRowTemplate"

------------------//FUNCTIONS
local function ensure_child(parent: Instance, childName: string, className: string): Instance?
	local child = parent:FindFirstChild(childName)
	if child then
		if child.ClassName ~= className then
			warn(string.format("[HudBootstrap] '%s' existe com tipo '%s', esperado '%s'", childName, child.ClassName, className))
			return nil
		end
		return child
	end

	local newChild = Instance.new(className)
	newChild.Name = childName
	newChild.Parent = parent
	return newChild
end

local function ensure_path(root: Instance, path: {string}): Instance?
	local current: Instance? = root
	for _, name in path do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function ensure_corner(parent: Instance, radius: number): ()
	local corner = ensure_child(parent, "Corner", "UICorner")
	if corner and corner:IsA("UICorner") then
		corner.CornerRadius = UDim.new(0, radius)
	end
end

local function ensure_stroke(parent: Instance, thickness: number, transparency: number): ()
	local stroke = ensure_child(parent, "Stroke", "UIStroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Thickness = thickness
		stroke.Transparency = transparency
	end
end

local function ensure_spectator_button(playerHud: ScreenGui): ()
	local topBar = ensure_path(playerHud, {"Main", "TopBar"})
	if not topBar then
		return
	end

	local button = ensure_child(topBar, SPECTATOR_BUTTON_NAME, "TextButton")
	if not button or not button:IsA("TextButton") then
		return
	end

	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -145, 0.5, 0)
	button.Size = UDim2.fromOffset(130, 30)
	button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	button.BackgroundTransparency = 0.15
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = "Espectador"
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 14
	button.AutoButtonColor = true
	button.Visible = false
	button.ZIndex = 2
end

local function ensure_prefab_layouts(masterGui: ScreenGui): ()
	local itemList = ensure_path(masterGui, {"PrefabWindow", "Body", "ItemList"})
	if itemList and itemList:IsA("ScrollingFrame") then
		local grid = ensure_child(itemList, PREFAB_ITEM_GRID_LAYOUT_NAME, "UIGridLayout")
		if grid and grid:IsA("UIGridLayout") then
			grid.CellPadding = UDim2.new(0, 8, 0, 8)
			grid.CellSize = UDim2.new((1 / 3), -10, 0, 108)
			grid.SortOrder = Enum.SortOrder.LayoutOrder
			grid.FillDirection = Enum.FillDirection.Horizontal
			grid.FillDirectionMaxCells = 3
			grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
			grid.VerticalAlignment = Enum.VerticalAlignment.Top
		end
	end

	local categoryList = ensure_path(masterGui, {"PrefabWindow", "Body", "CategoryList"})
	if categoryList and categoryList:IsA("ScrollingFrame") then
		local listLayout = ensure_child(categoryList, PREFAB_CATEGORY_LIST_LAYOUT_NAME, "UIListLayout")
		if listLayout and listLayout:IsA("UIListLayout") then
			listLayout.Padding = UDim.new(0, 6)
			listLayout.SortOrder = Enum.SortOrder.LayoutOrder
			listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		end
	end
end

local function ensure_npc_layouts(masterGui: ScreenGui): ()
	local npcList = ensure_path(masterGui, {"NpcSidebar", "NpcList"})
	if not npcList or not npcList:IsA("ScrollingFrame") then
		return
	end

	local listLayout = ensure_child(npcList, NPC_LIST_LAYOUT_NAME, "UIListLayout")
	if not listLayout or not listLayout:IsA("UIListLayout") then
		return
	end

	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
end

local function ensure_players_row_template(playersList: ScrollingFrame): ()
	local listLayout = ensure_child(playersList, PLAYERS_LIST_LAYOUT_NAME, "UIListLayout")
	if listLayout and listLayout:IsA("UIListLayout") then
		listLayout.Padding = UDim.new(0, 8)
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	end

	local row = ensure_child(playersList, PLAYERS_ROW_TEMPLATE_NAME, "Frame")
	if not row or not row:IsA("Frame") then
		return
	end

	row.Size = UDim2.new(1, -8, 0, 136)
	row.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
	row.BorderSizePixel = 0
	row.Visible = false
	ensure_corner(row, 10)
	ensure_stroke(row, 1, 0.8)

	local nameLabel = ensure_child(row, "NameLabel", "TextLabel")
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.fromOffset(174, 8)
		nameLabel.Size = UDim2.new(1, -186, 0, 18)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = "Nome [Classe]"
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 13
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	end

	local stateLabel = ensure_child(row, "StateLabel", "TextLabel")
	if stateLabel and stateLabel:IsA("TextLabel") then
		stateLabel.BackgroundTransparency = 1
		stateLabel.Position = UDim2.fromOffset(174, 28)
		stateLabel.Size = UDim2.new(1, -186, 0, 14)
		stateLabel.Font = Enum.Font.GothamMedium
		stateLabel.Text = "Movimento"
		stateLabel.TextColor3 = Color3.fromRGB(170, 255, 170)
		stateLabel.TextSize = 12
		stateLabel.TextXAlignment = Enum.TextXAlignment.Left
	end

	local hpLabel = ensure_child(row, "HpLabel", "TextLabel")
	if hpLabel and hpLabel:IsA("TextLabel") then
		hpLabel.BackgroundTransparency = 1
		hpLabel.Position = UDim2.fromOffset(12, 8)
		hpLabel.Size = UDim2.fromOffset(24, 18)
		hpLabel.Font = Enum.Font.GothamBold
		hpLabel.Text = "HP"
		hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		hpLabel.TextSize = 12
	end

	local currentBox = ensure_child(row, "CurrentHealthBox", "TextBox")
	if currentBox and currentBox:IsA("TextBox") then
		currentBox.Size = UDim2.fromOffset(52, 20)
		currentBox.Position = UDim2.fromOffset(40, 8)
		currentBox.BackgroundColor3 = Color3.fromRGB(24, 25, 32)
		currentBox.BorderSizePixel = 0
		currentBox.ClearTextOnFocus = false
		currentBox.Font = Enum.Font.GothamMedium
		currentBox.Text = "0"
		currentBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		currentBox.TextSize = 13
		ensure_corner(currentBox, 8)
		ensure_stroke(currentBox, 1, 0.8)
	end

	local slashLabel = ensure_child(row, "SlashLabel", "TextLabel")
	if slashLabel and slashLabel:IsA("TextLabel") then
		slashLabel.BackgroundTransparency = 1
		slashLabel.Position = UDim2.fromOffset(96, 8)
		slashLabel.Size = UDim2.fromOffset(14, 18)
		slashLabel.Font = Enum.Font.GothamBold
		slashLabel.Text = "/"
		slashLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		slashLabel.TextSize = 12
	end

	local maxBox = ensure_child(row, "MaxHealthBox", "TextBox")
	if maxBox and maxBox:IsA("TextBox") then
		maxBox.Size = UDim2.fromOffset(52, 20)
		maxBox.Position = UDim2.fromOffset(110, 8)
		maxBox.BackgroundColor3 = Color3.fromRGB(24, 25, 32)
		maxBox.BorderSizePixel = 0
		maxBox.ClearTextOnFocus = false
		maxBox.Font = Enum.Font.GothamMedium
		maxBox.Text = "0"
		maxBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		maxBox.TextSize = 13
		ensure_corner(maxBox, 8)
		ensure_stroke(maxBox, 1, 0.8)
	end

	local function style_button(button: TextButton, text: string, size: UDim2, position: UDim2)
		button.Size = size
		button.Position = position
		button.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.Text = text
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.TextSize = 13
		button.AutoButtonColor = true
		ensure_corner(button, 10)
		ensure_stroke(button, 1, 0.75)
	end

	local teleportButton = ensure_child(row, "TeleportButton", "TextButton")
	if teleportButton and teleportButton:IsA("TextButton") then
		style_button(teleportButton, "Ir até", UDim2.new(0.32, -8, 0, 24), UDim2.fromOffset(12, 48))
	end

	local lockButton = ensure_child(row, "LockButton", "TextButton")
	if lockButton and lockButton:IsA("TextButton") then
		style_button(lockButton, "Bloquear", UDim2.new(0.32, -8, 0, 24), UDim2.new(0.34, 0, 0, 48))
	end

	local addTurnButton = ensure_child(row, "AddTurnButton", "TextButton")
	if addTurnButton and addTurnButton:IsA("TextButton") then
		style_button(addTurnButton, "Add Turno", UDim2.new(0.32, -8, 0, 24), UDim2.new(0.68, -4, 0, 48))
	end

	local imageLabel = ensure_child(row, "ImageLabel", "TextLabel")
	if imageLabel and imageLabel:IsA("TextLabel") then
		imageLabel.BackgroundTransparency = 1
		imageLabel.Position = UDim2.fromOffset(12, 80)
		imageLabel.Size = UDim2.fromOffset(48, 24)
		imageLabel.Font = Enum.Font.GothamBold
		imageLabel.Text = "IMAGEM"
		imageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		imageLabel.TextSize = 12
	end

	local imageIdBox = ensure_child(row, "ImageIdBox", "TextBox")
	if imageIdBox and imageIdBox:IsA("TextBox") then
		imageIdBox.Size = UDim2.new(1, -24, 0, 24)
		imageIdBox.Position = UDim2.fromOffset(12, 104)
		imageIdBox.BackgroundColor3 = Color3.fromRGB(24, 25, 32)
		imageIdBox.BorderSizePixel = 0
		imageIdBox.ClearTextOnFocus = false
		imageIdBox.Font = Enum.Font.GothamMedium
		imageIdBox.Text = ""
		imageIdBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		imageIdBox.TextSize = 13
		ensure_corner(imageIdBox, 8)
		ensure_stroke(imageIdBox, 1, 0.8)
	end
end

local function ensure_order_row_template(orderList: ScrollingFrame): ()
	local row = ensure_child(orderList, ORDER_ROW_TEMPLATE_NAME, "Frame")
	if not row or not row:IsA("Frame") then
		return
	end

	row.Size = UDim2.new(1, -8, 0, 42)
	row.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
	row.BorderSizePixel = 0
	row.Visible = false
	ensure_corner(row, 10)
	ensure_stroke(row, 1, 0.8)

	local dragHandle = ensure_child(row, "DragHandle", "TextButton")
	if dragHandle and dragHandle:IsA("TextButton") then
		dragHandle.Size = UDim2.fromOffset(28, 24)
		dragHandle.Position = UDim2.fromOffset(8, 9)
		dragHandle.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
		dragHandle.BorderSizePixel = 0
		dragHandle.Font = Enum.Font.GothamBold
		dragHandle.Text = "↕"
		dragHandle.TextColor3 = Color3.fromRGB(255, 255, 255)
		dragHandle.TextSize = 13
		dragHandle.AutoButtonColor = true
		ensure_corner(dragHandle, 10)
		ensure_stroke(dragHandle, 1, 0.75)
	end

	local removeButton = ensure_child(row, "RemoveButton", "TextButton")
	if removeButton and removeButton:IsA("TextButton") then
		removeButton.Size = UDim2.fromOffset(28, 24)
		removeButton.Position = UDim2.new(1, -36, 0, 9)
		removeButton.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
		removeButton.BorderSizePixel = 0
		removeButton.Font = Enum.Font.GothamBold
		removeButton.Text = "X"
		removeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		removeButton.TextSize = 13
		removeButton.AutoButtonColor = true
		ensure_corner(removeButton, 10)
		ensure_stroke(removeButton, 1, 0.75)
	end

	local nameLabel = ensure_child(row, "NameLabel", "TextLabel")
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.fromOffset(46, 0)
		nameLabel.Size = UDim2.new(1, -90, 1, 0)
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.Text = "1. Turno"
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 13
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	end
end

local function ensure_master_hud_templates(masterGui: ScreenGui): ()
	local playersList = ensure_path(masterGui, {"PlayersWindow", "Body", "PlayersList"})
	if playersList and playersList:IsA("ScrollingFrame") then
		ensure_players_row_template(playersList)
	end

	local orderList = ensure_path(masterGui, {"CombatWindow", "Body", "OrderList"})
	if orderList and orderList:IsA("ScrollingFrame") then
		ensure_order_row_template(orderList)
	end
end

local function configure_hud(gui: Instance): ()
	if gui.Name == MASTER_GUI_NAME and gui:IsA("ScreenGui") then
		ensure_prefab_layouts(gui)
		ensure_npc_layouts(gui)
		ensure_master_hud_templates(gui)
	elseif gui.Name == PLAYER_HUD_NAME and gui:IsA("ScreenGui") then
		ensure_spectator_button(gui)
	end
end

------------------//INIT
for _, child in StarterGui:GetChildren() do
	configure_hud(child)
end

StarterGui.ChildAdded:Connect(function(child)
	configure_hud(child)
end)
