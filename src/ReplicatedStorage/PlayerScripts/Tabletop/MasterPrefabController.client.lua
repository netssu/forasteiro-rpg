------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//CONSTANTS
local GUI_NAME: string = "MasterGui"
local WINDOW_NAME: string = "PrefabWindow"
local TOGGLE_NAME: string = "PrefabToggleButton"
local REMOTE_NAME: string = "MasterBuildEvent"
local PREFAB_FOLDER_NAME: string = "Prefrab"
local BUILD_FOLDER_NAME: string = "TabletopBuildParts"

local HOLD_TO_SPRAY_SECONDS: number = 2
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

------------------//FUNCTIONS
local function clear_container(container: Instance): ()
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function update_scroll_canvas(list: ScrollingFrame): ()
	local layout = list:FindFirstChildOfClass("UIListLayout")
	if not layout then
		return
	end
	list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
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

local function close_other_frames(gui: ScreenGui): ()
	for _, frameName in OTHER_FRAME_NAMES do
		local frame = gui:FindFirstChild(frameName)
		if frame and frame:IsA("GuiObject") then
			frame.Visible = false
		end
	end
end

local function sanitize_scale_range(window: Frame): (number, number)
	local body = window:FindFirstChild("Body")
	if not body then
		return 0.8, 1.2
	end

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

local function is_valid_delete_target(inst: Instance?): boolean
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

	if target:GetAttribute("IsTabletopBuildPart") ~= true or target:GetAttribute("BuildKind") ~= "Prefab" then
		return nil
	end

	local buildFolder = workspace:FindFirstChild(BUILD_FOLDER_NAME)
	if not buildFolder then
		return target
	end

	local modelAncestor = target:FindFirstAncestorOfClass("Model")
	if modelAncestor and modelAncestor.Parent == buildFolder then
		return modelAncestor
	end

	return target
end

local function refresh_selected_label(window: Frame): ()
	local body = window:FindFirstChild("Body")
	if not body then
		return
	end

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

local function refresh_toggles(window: Frame): ()
	local body = window:FindFirstChild("Body")
	if not body then
		return
	end

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

local function update_frequency_slider(window: Frame, pct: number): ()
	pct = math.clamp(pct, 0, 1)
	frequencyPerSecond = FREQUENCY_MIN + ((FREQUENCY_MAX - FREQUENCY_MIN) * pct)

	local body = window:FindFirstChild("Body")
	if not body then
		return
	end

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
	itemButton.BackgroundColor3 = Color3.fromRGB(28, 31, 39)
	itemButton.BorderSizePixel = 0
	itemButton.Text = ""
	itemButton.AutoButtonColor = true
	itemButton.Size = UDim2.new(0.95, 0, 0.24, 0)
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
	viewport.Size = UDim2.new(0.36, 0, 0.8, 0)
	viewport.Position = UDim2.new(0.03, 0, 0.1, 0)
	viewport.Parent = itemButton

	local viewportCorner = Instance.new("UICorner")
	viewportCorner.CornerRadius = UDim.new(0.1, 0)
	viewportCorner.Parent = viewport

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0.42, 0, 0.22, 0)
	title.Size = UDim2.new(0.54, 0, 0.3, 0)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(240, 240, 245)
	title.Text = prefab.Name
	title.Parent = itemButton

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.new(0.42, 0, 0.52, 0)
	hint.Size = UDim2.new(0.54, 0, 0.24, 0)
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 11
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = Color3.fromRGB(150, 156, 170)
	hint.Text = categoryName
	hint.Parent = itemButton

	fill_viewport(viewport, prefab)

	itemButton.MouseButton1Click:Connect(function()
		currentCategory = categoryName
		currentPrefabName = prefab.Name
		if activeGui then
			local window = activeGui:FindFirstChild(WINDOW_NAME)
			if window and window:IsA("Frame") then
				refresh_selected_label(window)
			end
		end
	end)
end

local function populate_prefab_list(window: Frame, categoryName: string): ()
	local body = window:FindFirstChild("Body")
	if not body then
		return
	end

	local itemList = body:FindFirstChild("ItemList")
	if not itemList or not itemList:IsA("ScrollingFrame") then
		return
	end

	clear_container(itemList)
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

local function populate_categories(window: Frame): ()
	local body = window:FindFirstChild("Body")
	if not body then
		return
	end

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
				currentCategory = child.Name
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
	if not window or not window:IsA("Frame") or not window.Visible then
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
	if not window or not window:IsA("Frame") or not window.Visible then
		return
	end

	selectedDeleteTarget = resolve_target_from_mouse()
	refresh_selected_label(window)
end

local function delete_selected_target(): ()
	if not selectedDeleteTarget or not is_valid_delete_target(selectedDeleteTarget) then
		return
	end

	masterBuildEvent:FireServer({
		Action = "DeletePrefabTarget",
		Target = selectedDeleteTarget,
	})

	selectedDeleteTarget = nil
	if activeGui then
		local window = activeGui:FindFirstChild(WINDOW_NAME)
		if window and window:IsA("Frame") then
			refresh_selected_label(window)
		end
	end
end

local function delete_all_prefabs(): ()
	masterBuildEvent:FireServer({
		Action = "DeleteAllPrefabs",
	})

	selectedDeleteTarget = nil
	if activeGui then
		local window = activeGui:FindFirstChild(WINDOW_NAME)
		if window and window:IsA("Frame") then
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

local function wire_window_controls(gui: ScreenGui, window: Frame): ()
	local topBar = gui:FindFirstChild("TopBar")
	if not topBar then
		return
	end

	local toggleButton = topBar:FindFirstChild(TOGGLE_NAME)
	local header = window:FindFirstChild("Header")
	local closeButton = header and header:FindFirstChild("CloseButton")
	local body = window:FindFirstChild("Body")
	local placeToggle = body and body:FindFirstChild("PlaceToggleButton")
	local deleteModeButton = body and body:FindFirstChild("DeleteModeButton")
	local deleteSelectedButton = body and body:FindFirstChild("DeleteSelectedButton")
	local deleteAllButton = body and body:FindFirstChild("DeleteAllButton")
	local randomScaleButton = body and body:FindFirstChild("RandomScaleButton")
	local randomRotationButton = body and body:FindFirstChild("RandomRotationButton")
	local frequencyTrack = body and body:FindFirstChild("FrequencyTrack")
	local sliderDragging = false

	if toggleButton and toggleButton:IsA("TextButton") and not toggleButton:GetAttribute("PrefabBound") then
		toggleButton:SetAttribute("PrefabBound", true)
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
		end)
	end

	if closeButton and closeButton:IsA("TextButton") and not closeButton:GetAttribute("PrefabBound") then
		closeButton:SetAttribute("PrefabBound", true)
		closeButton.MouseButton1Click:Connect(function()
			window.Visible = false
		end)
	end

	if placeToggle and placeToggle:IsA("TextButton") and not placeToggle:GetAttribute("PrefabBound") then
		placeToggle:SetAttribute("PrefabBound", true)
		placeToggle.MouseButton1Click:Connect(function()
			placeModeEnabled = not placeModeEnabled
			if placeModeEnabled then
				deleteModeEnabled = false
			end
			refresh_toggles(window)
		end)
	end

	if deleteModeButton and deleteModeButton:IsA("TextButton") and not deleteModeButton:GetAttribute("PrefabBound") then
		deleteModeButton:SetAttribute("PrefabBound", true)
		deleteModeButton.MouseButton1Click:Connect(function()
			deleteModeEnabled = not deleteModeEnabled
			if deleteModeEnabled then
				placeModeEnabled = false
			end
			refresh_toggles(window)
		end)
	end

	if deleteSelectedButton and deleteSelectedButton:IsA("TextButton") and not deleteSelectedButton:GetAttribute("PrefabBound") then
		deleteSelectedButton:SetAttribute("PrefabBound", true)
		deleteSelectedButton.MouseButton1Click:Connect(delete_selected_target)
	end

	if deleteAllButton and deleteAllButton:IsA("TextButton") and not deleteAllButton:GetAttribute("PrefabBound") then
		deleteAllButton:SetAttribute("PrefabBound", true)
		deleteAllButton.MouseButton1Click:Connect(delete_all_prefabs)
	end

	if randomScaleButton and randomScaleButton:IsA("TextButton") and not randomScaleButton:GetAttribute("PrefabBound") then
		randomScaleButton:SetAttribute("PrefabBound", true)
		randomScaleButton.MouseButton1Click:Connect(function()
			randomScaleEnabled = not randomScaleEnabled
			sanitize_scale_range(window)
			refresh_toggles(window)
		end)
	end

	if randomRotationButton and randomRotationButton:IsA("TextButton") and not randomRotationButton:GetAttribute("PrefabBound") then
		randomRotationButton:SetAttribute("PrefabBound", true)
		randomRotationButton.MouseButton1Click:Connect(function()
			randomRotationEnabled = not randomRotationEnabled
			refresh_toggles(window)
		end)
	end

	if frequencyTrack and frequencyTrack:IsA("Frame") and not frequencyTrack:GetAttribute("PrefabBound") then
		frequencyTrack:SetAttribute("PrefabBound", true)

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
	if not window or not window:IsA("Frame") then
		return
	end

	populate_categories(window)
	wire_window_controls(gui, window)
end

------------------//INIT
local existingGui = playerGui:FindFirstChild(GUI_NAME)
if existingGui and existingGui:IsA("ScreenGui") then
	task.defer(function()
		wire_gui(existingGui)
	end)
end

playerGui.ChildAdded:Connect(function(child)
	if child.Name == GUI_NAME and child:IsA("ScreenGui") then
		task.defer(function()
			wire_gui(child)
		end)
	end
end)

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
