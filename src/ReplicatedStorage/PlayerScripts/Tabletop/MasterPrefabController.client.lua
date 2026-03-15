------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//CONSTANTS
local GUI_NAME: string = "MasterGui"
local WINDOW_NAME: string = "PrefabWindow"
local TOGGLE_NAME: string = "PrefabToggleButton"
local REMOTE_NAME: string = "MasterBuildEvent"
local PREFAB_FOLDER_NAME: string = "Prefrab"
local BUILD_FOLDER_NAME: string = "TabletopBuildParts"

local HOLD_TO_SPRAY_SECONDS: number = 1
local FREQUENCY_MIN: number = 1
local FREQUENCY_MAX: number = 12

local OTHER_FRAME_NAMES: {string} = {
	"EnvironmentWindow",
	"PlayersWindow",
	"CombatWindow",
	"BuildSidebar",
	"RoomSidebar",
	"NpcSidebar",
	"TerrainWindow",
}

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")
local mouse: Mouse = player:GetMouse()

local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local masterBuildEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)
local prefabRoot: Folder = ReplicatedStorage:WaitForChild(PREFAB_FOLDER_NAME)

local currentCategory: string? = nil
local currentPrefabName: string? = nil
local placeModeEnabled: boolean = false
local deleteModeEnabled: boolean = false
local randomScaleEnabled: boolean = false
local randomRotationEnabled: boolean = false
local frequencyPerSecond: number = 2

local activeGui: ScreenGui? = nil
local selectedDeleteTarget: Instance? = nil
local mouseDownAt: number? = nil
local sprayActive: boolean = false
local boundWindows: {[GuiObject]: boolean} = {}
local selectedItemButton: TextButton? = nil
local previewInstance: Instance? = nil
local previewConnection: RBXScriptConnection? = nil
local deleteSelectionBox: SelectionBox? = nil

local ITEM_DEFAULT_COLOR = Color3.fromRGB(28, 31, 39)
local ITEM_SELECTED_COLOR = Color3.fromRGB(201, 176, 62)

local refresh_selected_label: (window: GuiObject) -> ()
local refresh_toggles: (window: GuiObject) -> ()
local is_valid_delete_target: (inst: Instance?) -> boolean

------------------//FUNCTIONS
local function clear_container(container: Instance): ()
	for _, child in container:GetChildren() do
		if not child:IsA("UILayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function update_scroll_canvas(list: ScrollingFrame): ()
	local layout = list:FindFirstChildOfClass("UIGridLayout") or list:FindFirstChildOfClass("UIListLayout")
	if not layout then
		return
	end
	list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
end

local function get_prefab_grid_layout(itemList: ScrollingFrame): UIGridLayout?
	local existing = itemList:FindFirstChildOfClass("UIGridLayout")
	if existing then
		return existing
	end

	warn("[MasterPrefabController] UIGridLayout ausente em PrefabWindow.Body.ItemList")
	return nil
end

local function get_prefab_bounds(prefab: Instance): (CFrame, Vector3)
	if prefab:IsA("Model") then
		return prefab:GetBoundingBox()
	end
	if prefab:IsA("BasePart") then
		return prefab.CFrame, prefab.Size
	end
	return CFrame.new(), Vector3.new(4, 4, 4)
end

local function fill_viewport(viewport: ViewportFrame, source: Instance): ()
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	local previewClone = source:Clone()
	previewClone.Parent = worldModel

	for _, descendant in previewClone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	if previewClone:IsA("BasePart") then
		previewClone.Anchored = true
	end

	local objectCFrame, objectSize = get_prefab_bounds(previewClone)
	local center = objectCFrame.Position
	local maxAxis = math.max(objectSize.X, objectSize.Y, objectSize.Z)
	local distance = math.max(6, maxAxis * 2)

	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(center + Vector3.new(distance, distance * 0.7, distance), center)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function read_grid_size(gui: ScreenGui?): number
	if not gui then
		return 1
	end

	local buildSidebar = gui:FindFirstChild("BuildSidebar")
	local body = buildSidebar and buildSidebar:FindFirstChild("Body")
	local gridBox = body and body:FindFirstChild("GridBox")

	if gridBox and gridBox:IsA("TextBox") then
		local n = tonumber(gridBox.Text)
		if n and n > 0 then
			return math.max(0.25, n)
		end
	end

	return 1
end

local function get_place_cframe(gridSize: number): CFrame?
	if not mouse.Target then
		return nil
	end

	local position = mouse.Hit.Position
	local snapped = Vector3.new(
		math.floor((position.X / gridSize) + 0.5) * gridSize,
		math.floor((position.Y / gridSize) + 0.5) * gridSize,
		math.floor((position.Z / gridSize) + 0.5) * gridSize
	)

	return CFrame.new(snapped)
end

local function update_preview_transform(): ()
	if not previewInstance or not previewInstance.Parent then
		return
	end

	local grid = read_grid_size(activeGui)
	local placeCFrame = get_place_cframe(grid)
	if not placeCFrame then
		return
	end

	if previewInstance:IsA("Model") then
		local currentPivot = previewInstance:GetPivot()
		local _, extentsSize = previewInstance:GetBoundingBox()
		local yOffset = math.max(0, extentsSize.Y * 0.5)
		local targetPivot = placeCFrame * CFrame.new(0, yOffset, 0)
		previewInstance:PivotTo(targetPivot * currentPivot.Rotation)
	elseif previewInstance:IsA("BasePart") then
		local yOffset = math.max(0, previewInstance.Size.Y * 0.5)
		previewInstance.CFrame = placeCFrame * CFrame.new(0, yOffset, 0)
	end
end

local function clear_preview(): ()
	if previewConnection then
		previewConnection:Disconnect()
		previewConnection = nil
	end

	if previewInstance then
		previewInstance:Destroy()
		previewInstance = nil
	end
end


local function clear_delete_selection_box(): ()
	if deleteSelectionBox then
		deleteSelectionBox.Adornee = nil
		deleteSelectionBox:Destroy()
		deleteSelectionBox = nil
	end
end

local function refresh_delete_selection_box(): ()
	if selectedDeleteTarget and is_valid_delete_target(selectedDeleteTarget) then
		if not deleteSelectionBox then
			deleteSelectionBox = Instance.new("SelectionBox")
			deleteSelectionBox.Name = "PrefabDeleteSelection"
			deleteSelectionBox.LineThickness = 0.06
			deleteSelectionBox.Color3 = Color3.fromRGB(255, 90, 90)
			deleteSelectionBox.SurfaceTransparency = 0.85
			deleteSelectionBox.Parent = workspace
		end
		deleteSelectionBox.Adornee = selectedDeleteTarget
	else
		clear_delete_selection_box()
	end
end

local function show_prefab_preview(categoryName: string, prefabName: string): ()
	clear_preview()

	local categoryFolder = prefabRoot:FindFirstChild(categoryName)
	if not categoryFolder or not categoryFolder:IsA("Folder") then
		return
	end

	local prefab = categoryFolder:FindFirstChild(prefabName)
	if not prefab or (not prefab:IsA("Model") and not prefab:IsA("BasePart")) then
		return
	end

	local clone = prefab:Clone()
	clone.Name = "PrefabPlacementPreview"

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Transparency = math.max(descendant.Transparency, 0.55)
			descendant.Material = Enum.Material.ForceField
		end
	end

	if clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanTouch = false
		clone.CanQuery = false
		clone.Transparency = math.max(clone.Transparency, 0.55)
		clone.Material = Enum.Material.ForceField
	end

	clone.Parent = workspace
	previewInstance = clone
	update_preview_transform()
	previewConnection = RunService.RenderStepped:Connect(update_preview_transform)
end

local function set_item_selected(itemButton: TextButton, selected: boolean): ()
	itemButton.BackgroundColor3 = selected and ITEM_SELECTED_COLOR or ITEM_DEFAULT_COLOR
end

local function get_window_body(window: GuiObject): Instance
	local body = window:FindFirstChild("Body")
	if body then
		return body
	end

	return window
end

local function clear_selected_prefab(window: GuiObject): ()
	currentCategory = nil
	currentPrefabName = nil
	placeModeEnabled = false

	if selectedItemButton then
		set_item_selected(selectedItemButton, false)
		selectedItemButton = nil
	end

	clear_preview()
	selectedDeleteTarget = nil
	refresh_delete_selection_box()
	refresh_selected_label(window)
	refresh_toggles(window)
end

local function close_other_frames(gui: ScreenGui): ()
	for _, frameName in OTHER_FRAME_NAMES do
		local frame = gui:FindFirstChild(frameName)
		if frame and frame:IsA("GuiObject") then
			frame.Visible = false
		end
	end
end

local function sanitize_scale_range(window: GuiObject): (number, number)
	local body = get_window_body(window)

	local minBox = body:FindFirstChild("ScaleMinBox")
	local maxBox = body:FindFirstChild("ScaleMaxBox")
	local minValue = (minBox and minBox:IsA("TextBox") and tonumber(minBox.Text)) or 0.8
	local maxValue = (maxBox and maxBox:IsA("TextBox") and tonumber(maxBox.Text)) or 1.2

	minValue = math.clamp(minValue, 0.1, 10)
	maxValue = math.clamp(maxValue, 0.1, 10)

	if minValue > maxValue then
		minValue, maxValue = maxValue, minValue
	end

	if minBox and minBox:IsA("TextBox") then
		minBox.Text = string.format("%.2f", minValue)
	end
	if maxBox and maxBox:IsA("TextBox") then
		maxBox.Text = string.format("%.2f", maxValue)
	end

	return minValue, maxValue
end

function is_valid_delete_target(inst: Instance?): boolean
	if not inst then
		return false
	end

	if inst:IsA("BasePart") then
		return inst:GetAttribute("IsTabletopBuildPart") == true and inst:GetAttribute("BuildKind") == "Prefab"
	end

	if inst:IsA("Model") then
		for _, descendant in inst:GetDescendants() do
			if descendant:IsA("BasePart") and descendant:GetAttribute("IsTabletopBuildPart") == true and descendant:GetAttribute("BuildKind") == "Prefab" then
				return true
			end
		end
	end

	return false
end

local function resolve_target_from_mouse(): Instance?
	local target = mouse.Target
	if not target then
		return nil
	end

	local buildFolder = workspace:FindFirstChild(BUILD_FOLDER_NAME)
	local cursor: Instance? = target
	while cursor do
		if is_valid_delete_target(cursor) then
			if cursor:IsA("BasePart") then
				local modelAncestor = cursor:FindFirstAncestorOfClass("Model")
				if modelAncestor and (not buildFolder or modelAncestor.Parent == buildFolder) and is_valid_delete_target(modelAncestor) then
					return modelAncestor
				end
			end

			if buildFolder and cursor.Parent ~= buildFolder and not cursor:IsDescendantOf(buildFolder) then
				cursor = cursor.Parent
				continue
			end

			return cursor
		end
		cursor = cursor.Parent
	end

	return nil
end

function refresh_selected_label(window: GuiObject): ()
	local body = get_window_body(window)

	local selectedLabel = body:FindFirstChild("SelectedLabel")
	if selectedLabel and selectedLabel:IsA("TextLabel") then
		if currentCategory and currentPrefabName then
			selectedLabel.Text = string.format("Selecionado: %s/%s", currentCategory, currentPrefabName)
		else
			selectedLabel.Text = "Selecionado: nenhum"
		end
	end

	local deleteSelectedLabel = body:FindFirstChild("DeleteSelectedLabel")
	if deleteSelectedLabel and deleteSelectedLabel:IsA("TextLabel") then
		if selectedDeleteTarget and is_valid_delete_target(selectedDeleteTarget) then
			deleteSelectedLabel.Text = "Para apagar: " .. selectedDeleteTarget.Name
		else
			deleteSelectedLabel.Text = "Para apagar: nenhum"
		end
	end
end

function refresh_toggles(window: GuiObject): ()
	local body = get_window_body(window)

	local placeToggle = body:FindFirstChild("PlaceToggleButton")
	if placeToggle and placeToggle:IsA("TextButton") then
		placeToggle.Text = placeModeEnabled and "Modo colocar: ON" or "Modo colocar: OFF"
		placeToggle.BackgroundColor3 = placeModeEnabled and Color3.fromRGB(69, 114, 84) or Color3.fromRGB(34, 36, 44)
	end

	local deleteModeButton = body:FindFirstChild("DeleteModeButton")
	if deleteModeButton and deleteModeButton:IsA("TextButton") then
		deleteModeButton.Text = deleteModeEnabled and "Modo apagar: ON" or "Modo apagar: OFF"
		deleteModeButton.BackgroundColor3 = deleteModeEnabled and Color3.fromRGB(114, 69, 69) or Color3.fromRGB(34, 36, 44)
	end

	local randomScaleButton = body:FindFirstChild("RandomScaleButton")
	if randomScaleButton and randomScaleButton:IsA("TextButton") then
		randomScaleButton.Text = randomScaleEnabled and "Tamanho aleatório: ON" or "Tamanho aleatório: OFF"
		randomScaleButton.BackgroundColor3 = randomScaleEnabled and Color3.fromRGB(69, 114, 84) or Color3.fromRGB(34, 36, 44)
	end

	local randomRotationButton = body:FindFirstChild("RandomRotationButton")
	if randomRotationButton and randomRotationButton:IsA("TextButton") then
		randomRotationButton.Text = randomRotationEnabled and "Rotação aleatória: ON" or "Rotação aleatória: OFF"
		randomRotationButton.BackgroundColor3 = randomRotationEnabled and Color3.fromRGB(69, 114, 84) or Color3.fromRGB(34, 36, 44)
	end

	local frequencyValueLabel = body:FindFirstChild("FrequencyValueLabel")
	if frequencyValueLabel and frequencyValueLabel:IsA("TextLabel") then
		frequencyValueLabel.Text = string.format("%.1f/s", frequencyPerSecond)
	end
end

local function update_frequency_slider(window: GuiObject, pct: number): ()
	pct = math.clamp(pct, 0, 1)
	frequencyPerSecond = FREQUENCY_MIN + ((FREQUENCY_MAX - FREQUENCY_MIN) * pct)

	local body = get_window_body(window)

	local track = body:FindFirstChild("FrequencyTrack")
	if track and track:IsA("Frame") then
		local fill = track:FindFirstChild("FrequencyFill")
		if fill and fill:IsA("Frame") then
			fill.Size = UDim2.new(pct, 0, 1, 0)
		end

		local knob = track:FindFirstChild("FrequencyKnob")
		if knob and knob:IsA("Frame") then
			knob.Position = UDim2.new(pct, 0, 0.5, 0)
		end
	end

	refresh_toggles(window)
end

local function create_item_button(parent: ScrollingFrame, categoryName: string, prefab: Instance): ()
	local itemButton = Instance.new("TextButton")
	itemButton.Name = prefab.Name .. "Button"
	itemButton.BackgroundColor3 = ITEM_DEFAULT_COLOR
	itemButton.BorderSizePixel = 0
	itemButton.Text = ""
	itemButton.AutoButtonColor = true
	itemButton.Size = UDim2.fromScale(1, 1)
	itemButton.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.08, 0)
	corner.Parent = itemButton

	local stroke = Instance.new("UIStroke")
	stroke.Transparency = 0.82
	stroke.Parent = itemButton

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	viewport.BorderSizePixel = 0
	viewport.Size = UDim2.new(1, -10, 1, -32)
	viewport.Position = UDim2.new(0, 5, 0, 5)
	viewport.Parent = itemButton

	local viewportCorner = Instance.new("UICorner")
	viewportCorner.CornerRadius = UDim.new(0.1, 0)
	viewportCorner.Parent = viewport

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 6, 1, -24)
	title.Size = UDim2.new(1, -12, 0, 18)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 11
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextColor3 = Color3.fromRGB(240, 240, 245)
	title.Text = prefab.Name
	title.Parent = itemButton

	fill_viewport(viewport, prefab)

	itemButton.MouseButton1Click:Connect(function()
		if not activeGui then
			return
		end

		local window = activeGui:FindFirstChild(WINDOW_NAME)
		if not window or not window:IsA("GuiObject") then
			return
		end

		if selectedItemButton and selectedItemButton ~= itemButton then
			set_item_selected(selectedItemButton, false)
		end

		if currentCategory == categoryName and currentPrefabName == prefab.Name then
			clear_selected_prefab(window)
			return
		end

		currentCategory = categoryName
		currentPrefabName = prefab.Name
		placeModeEnabled = true
		deleteModeEnabled = false
		selectedItemButton = itemButton
		set_item_selected(itemButton, true)
		show_prefab_preview(categoryName, prefab.Name)
		refresh_selected_label(window)
		refresh_toggles(window)
	end)
end

local function populate_prefab_list(window: GuiObject, categoryName: string): ()
	local body = get_window_body(window)

	local itemList = body:FindFirstChild("ItemList")
	if not itemList or not itemList:IsA("ScrollingFrame") then
		return
	end

	clear_container(itemList)
	local gridLayout = get_prefab_grid_layout(itemList)
	if not gridLayout then
		return
	end

	gridLayout.CellSize = UDim2.new((1 / 3), -10, 0, 108)
	if selectedItemButton then
		selectedItemButton = nil
	end
	clear_preview()
	placeModeEnabled = false
	currentPrefabName = nil
	currentCategory = categoryName
	local categoryFolder = prefabRoot:FindFirstChild(categoryName)
	if not categoryFolder or not categoryFolder:IsA("Folder") then
		return
	end

	for _, prefab in categoryFolder:GetChildren() do
		if prefab:IsA("Model") or prefab:IsA("BasePart") then
			create_item_button(itemList, categoryName, prefab)
		end
	end

	update_scroll_canvas(itemList)
	refresh_selected_label(window)
end

local function populate_categories(window: GuiObject): ()
	local body = get_window_body(window)

	local categoryList = body:FindFirstChild("CategoryList")
	if not categoryList or not categoryList:IsA("ScrollingFrame") then
		return
	end

	clear_container(categoryList)
	for _, child in prefabRoot:GetChildren() do
		if child:IsA("Folder") then
			local categoryButton = Instance.new("TextButton")
			categoryButton.Name = child.Name .. "CategoryButton"
			categoryButton.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
			categoryButton.BorderSizePixel = 0
			categoryButton.Font = Enum.Font.GothamBold
			categoryButton.Text = child.Name
			categoryButton.TextSize = 12
			categoryButton.TextWrapped = true
			categoryButton.TextColor3 = Color3.fromRGB(245, 245, 250)
			categoryButton.Size = UDim2.new(0.94, 0, 0.12, 0)
			categoryButton.Parent = categoryList

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.18, 0)
			corner.Parent = categoryButton

			local stroke = Instance.new("UIStroke")
			stroke.Transparency = 0.82
			stroke.Parent = categoryButton

			categoryButton.MouseButton1Click:Connect(function()
				populate_prefab_list(window, child.Name)
			end)
		end
	end

	update_scroll_canvas(categoryList)
end

local function try_place_prefab(): ()
	if not placeModeEnabled or deleteModeEnabled or not currentCategory or not currentPrefabName or not activeGui then
		return
	end

	local window = activeGui:FindFirstChild(WINDOW_NAME)
	if not window or not window:IsA("GuiObject") or not window.Visible then
		return
	end

	local grid = read_grid_size(activeGui)
	local placeCFrame = get_place_cframe(grid)
	if not placeCFrame then
		return
	end

	local rotationY = 0
	if randomRotationEnabled then
		rotationY = math.random(0, 359)
	end

	local scaleFactor = 1
	if randomScaleEnabled then
		local minScale, maxScale = sanitize_scale_range(window)
		scaleFactor = minScale + ((maxScale - minScale) * math.random())
	end

	masterBuildEvent:FireServer({
		Action = "CreatePrefab",
		Category = currentCategory,
		PrefabName = currentPrefabName,
		CFrame = placeCFrame,
		RotationY = rotationY,
		ScaleFactor = scaleFactor,
	})
end

local function select_target_to_delete(): ()
	if not deleteModeEnabled or not activeGui then
		return
	end

	local window = activeGui:FindFirstChild(WINDOW_NAME)
	if not window or not window:IsA("GuiObject") or not window.Visible then
		return
	end

	local resolved = resolve_target_from_mouse()
	if selectedDeleteTarget and resolved == selectedDeleteTarget then
		selectedDeleteTarget = nil
	else
		selectedDeleteTarget = resolved
	end
	refresh_delete_selection_box()
	refresh_selected_label(window)
end

local function delete_selected_target(): ()
	if (not selectedDeleteTarget or not is_valid_delete_target(selectedDeleteTarget)) and deleteModeEnabled then
		selectedDeleteTarget = resolve_target_from_mouse()
	end

	if not selectedDeleteTarget or not is_valid_delete_target(selectedDeleteTarget) then
		refresh_delete_selection_box()
		return
	end

	masterBuildEvent:FireServer({
		Action = "DeletePrefabTarget",
		Target = selectedDeleteTarget,
	})

	selectedDeleteTarget = nil
	refresh_delete_selection_box()
	if activeGui then
		local window = activeGui:FindFirstChild(WINDOW_NAME)
		if window and window:IsA("GuiObject") then
			refresh_selected_label(window)
		end
	end
end

local function delete_all_prefabs(): ()
	masterBuildEvent:FireServer({
		Action = "DeleteAllPrefabs",
	})

	selectedDeleteTarget = nil
	refresh_delete_selection_box()
	if activeGui then
		local window = activeGui:FindFirstChild(WINDOW_NAME)
		if window and window:IsA("GuiObject") then
			refresh_selected_label(window)
		end
	end
end

local function start_spray_loop(): ()
	if sprayActive then
		return
	end

	sprayActive = true
	task.spawn(function()
		while sprayActive do
			try_place_prefab()
			local rate = math.max(0.2, frequencyPerSecond)
			task.wait(1 / rate)
		end
	end)
end

local function stop_spray_loop(): ()
	sprayActive = false
end

local function wire_window_controls(gui: ScreenGui, window: GuiObject): ()
	local topBar = gui:FindFirstChild("TopBar")
	if not topBar then
		return
	end

	local toggleButton = topBar:FindFirstChild(TOGGLE_NAME)
	local header = window:FindFirstChild("Header")
	local closeButton = (header and header:FindFirstChild("CloseButton")) or window:FindFirstChild("CloseButton")
	local body = get_window_body(window)
	local placeToggle = body and body:FindFirstChild("PlaceToggleButton")
	local deleteModeButton = body and body:FindFirstChild("DeleteModeButton")
	local deleteSelectedButton = body and body:FindFirstChild("DeleteSelectedButton")
	local deleteAllButton = body and body:FindFirstChild("DeleteAllButton")
	local randomScaleButton = body and body:FindFirstChild("RandomScaleButton")
	local randomRotationButton = body and body:FindFirstChild("RandomRotationButton")
	local frequencyTrack = body and body:FindFirstChild("FrequencyTrack")
	local sliderDragging = false

	if boundWindows[window] then
		update_frequency_slider(window, (frequencyPerSecond - FREQUENCY_MIN) / (FREQUENCY_MAX - FREQUENCY_MIN))
		refresh_toggles(window)
		refresh_selected_label(window)
		return
	end

	boundWindows[window] = true
	window.Destroying:Connect(function()
		boundWindows[window] = nil
	end)

	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.Visible then
			clear_selected_prefab(window)
		end
	end)

	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not gui.Enabled then
			clear_selected_prefab(window)
		end
	end)

	if toggleButton and toggleButton:IsA("TextButton") then
		toggleButton.MouseButton1Click:Connect(function()
			local willOpen = not window.Visible
			if willOpen then
				close_other_frames(gui)
				populate_categories(window)
				if currentCategory then
					populate_prefab_list(window, currentCategory)
				end
			end
			window.Visible = willOpen
			if not willOpen then
				clear_selected_prefab(window)
			end
		end)
	end

	if closeButton and closeButton:IsA("TextButton") then
		closeButton.MouseButton1Click:Connect(function()
			window.Visible = false
			clear_selected_prefab(window)
		end)
	end

	if placeToggle and placeToggle:IsA("TextButton") then
		placeToggle.Visible = false
	end

	if deleteModeButton and deleteModeButton:IsA("TextButton") then
		deleteModeButton.MouseButton1Click:Connect(function()
			deleteModeEnabled = not deleteModeEnabled
			if deleteModeEnabled then
				placeModeEnabled = false
				clear_preview()
			else
				selectedDeleteTarget = nil
				refresh_delete_selection_box()
			end
			refresh_toggles(window)
			refresh_selected_label(window)
		end)
	end

	if deleteSelectedButton and deleteSelectedButton:IsA("TextButton") then
		deleteSelectedButton.MouseButton1Click:Connect(delete_selected_target)
	end

	if deleteAllButton and deleteAllButton:IsA("TextButton") then
		deleteAllButton.MouseButton1Click:Connect(delete_all_prefabs)
	end

	if randomScaleButton and randomScaleButton:IsA("TextButton") then
		randomScaleButton.MouseButton1Click:Connect(function()
			randomScaleEnabled = not randomScaleEnabled
			sanitize_scale_range(window)
			refresh_toggles(window)
		end)
	end

	if randomRotationButton and randomRotationButton:IsA("TextButton") then
		randomRotationButton.MouseButton1Click:Connect(function()
			randomRotationEnabled = not randomRotationEnabled
			refresh_toggles(window)
		end)
	end

	if frequencyTrack and frequencyTrack:IsA("Frame") then
		local function update_by_mouse_x(mouseX: number): ()
			local pct = (mouseX - frequencyTrack.AbsolutePosition.X) / frequencyTrack.AbsoluteSize.X
			update_frequency_slider(window, pct)
		end

		frequencyTrack.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				sliderDragging = true
				update_by_mouse_x(input.Position.X)
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if sliderDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				update_by_mouse_x(input.Position.X)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				sliderDragging = false
			end
		end)
	end

	update_frequency_slider(window, (frequencyPerSecond - FREQUENCY_MIN) / (FREQUENCY_MAX - FREQUENCY_MIN))
	refresh_toggles(window)
	refresh_selected_label(window)
end

local function wire_gui(gui: ScreenGui): ()
	activeGui = gui
	local window = gui:FindFirstChild(WINDOW_NAME)
	if not window or not window:IsA("GuiObject") then
		return
	end

	populate_categories(window)
	wire_window_controls(gui, window)
end

------------------//INIT
local existingGui = playerGui:WaitForChild(GUI_NAME)
wire_gui(existingGui)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	
	if deleteModeEnabled then
		select_target_to_delete()
		return
	end

	if placeModeEnabled then
		try_place_prefab()
		mouseDownAt = os.clock()
		task.delay(HOLD_TO_SPRAY_SECONDS, function()
			if not mouseDownAt then
				return
			end

			if os.clock() - mouseDownAt >= HOLD_TO_SPRAY_SECONDS then
				start_spray_loop()
			end
		end)
	end
end)

UserInputService.InputEnded:Connect(function(input, _gameProcessed)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	mouseDownAt = nil

	if sprayActive then
		stop_spray_loop()
	end
end)
