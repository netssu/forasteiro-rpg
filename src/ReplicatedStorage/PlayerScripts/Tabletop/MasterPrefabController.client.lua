------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local GUI_NAME: string = "MasterGui"
local WINDOW_NAME: string = "PrefabWindow"
local TOGGLE_NAME: string = "PrefabToggleButton"
local REMOTE_NAME: string = "MasterBuildEvent"
local PREFAB_FOLDER_NAME: string = "Prefrab"

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
local activeGui: ScreenGui? = nil

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

	if previewClone:IsA("BasePart") then
		previewClone.Anchored = true
	end

	for _, descendant in previewClone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
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
	local target = mouse.Target
	if not target then
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

local function refresh_selected_label(window: Frame): ()
	local body = window:FindFirstChild("Body")
	local selectedLabel = body and body:FindFirstChild("SelectedLabel")
	if selectedLabel and selectedLabel:IsA("TextLabel") then
		if currentCategory and currentPrefabName then
			selectedLabel.Text = string.format("Selecionado: %s/%s", currentCategory, currentPrefabName)
		else
			selectedLabel.Text = "Selecionado: nenhum"
		end
	end
end

local function refresh_place_button(window: Frame): ()
	local body = window:FindFirstChild("Body")
	local placeToggle = body and body:FindFirstChild("PlaceToggleButton")
	if placeToggle and placeToggle:IsA("TextButton") then
		placeToggle.Text = placeModeEnabled and "Modo colocar: ON" or "Modo colocar: OFF"
		placeToggle.BackgroundColor3 = placeModeEnabled and Color3.fromRGB(69, 114, 84) or Color3.fromRGB(34, 36, 44)
	end
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

	if toggleButton and toggleButton:IsA("TextButton") and not toggleButton:GetAttribute("PrefabBound") then
		toggleButton:SetAttribute("PrefabBound", true)
		toggleButton.MouseButton1Click:Connect(function()
			if window.Visible then
				populate_categories(window)
				if currentCategory then
					populate_prefab_list(window, currentCategory)
				end
			end
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
			refresh_place_button(window)
		end)
	end

	refresh_place_button(window)
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

local function try_place_prefab(): ()
	if not placeModeEnabled then
		return
	end

	if not currentCategory or not currentPrefabName then
		return
	end

	if not activeGui then
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

	masterBuildEvent:FireServer({
		Action = "CreatePrefab",
		Category = currentCategory,
		PrefabName = currentPrefabName,
		CFrame = placeCFrame,
	})
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

mouse.Button1Down:Connect(function()
	try_place_prefab()
end)
