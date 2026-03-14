------------------//SERVICES
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local GUI_NAME: string = "MasterGui"
local TOGGLE_NAME: string = "PrefabToggleButton"
local WINDOW_NAME: string = "PrefabWindow"

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

------------------//FUNCTIONS
local function create_corner(parent: Instance, radiusScale: number): ()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radiusScale, 0)
	corner.Parent = parent
end

local function create_stroke(parent: Instance, transparency: number): ()
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 1
	stroke.Transparency = transparency
	stroke.Parent = parent
end

local function create_topbar_button(topBar: Frame): TextButton
	local button = topBar:FindFirstChild(TOGGLE_NAME)
	if button and button:IsA("TextButton") then
		button.Text = "Prefab"
		button.LayoutOrder = 8
		return button
	end

	local prefabButton = Instance.new("TextButton")
	prefabButton.Name = TOGGLE_NAME
	prefabButton.Text = "Prefab"
	prefabButton.Font = Enum.Font.GothamBold
	prefabButton.TextColor3 = Color3.fromRGB(245, 245, 250)
	prefabButton.TextSize = 13
	prefabButton.TextWrapped = true
	prefabButton.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
	prefabButton.BorderSizePixel = 0
	prefabButton.Size = UDim2.new(1, 0, 0.09, 0)
	prefabButton.LayoutOrder = 8
	prefabButton.Parent = topBar

	create_corner(prefabButton, 0.2)
	create_stroke(prefabButton, 0.8)

	return prefabButton
end

local function create_prefab_window(gui: ScreenGui): Frame
	local oldWindow = gui:FindFirstChild(WINDOW_NAME)
	if oldWindow then
		oldWindow:Destroy()
	end

	local window = Instance.new("Frame")
	window.Name = WINDOW_NAME
	window.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	window.BorderSizePixel = 0
	window.Size = UDim2.new(0.23, 0, 0.62, 0)
	window.Position = UDim2.new(0.76, 0, 0.08, 0)
	window.Visible = false
	window.Parent = gui

	create_corner(window, 0.035)
	create_stroke(window, 0.82)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 24, 31)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 15, 21)),
	})
	gradient.Rotation = 90
	gradient.Parent = window

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.BackgroundColor3 = Color3.fromRGB(120, 196, 156)
	accent.BorderSizePixel = 0
	accent.Size = UDim2.new(1, 0, 0.01, 0)
	accent.Parent = window

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0.11, 0)
	header.Parent = window

	local title = Instance.new("TextLabel")
	title.Name = "TitleLabel"
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0.04, 0, 0.2, 0)
	title.Size = UDim2.new(0.74, 0, 0.6, 0)
	title.Font = Enum.Font.GothamBold
	title.Text = "Prefabs"
	title.TextColor3 = Color3.fromRGB(240, 240, 245)
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Text = "×"
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 18
	closeButton.TextColor3 = Color3.fromRGB(245, 245, 250)
	closeButton.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
	closeButton.BorderSizePixel = 0
	closeButton.Size = UDim2.new(0.09, 0, 0.58, 0)
	closeButton.Position = UDim2.new(0.87, 0, 0.2, 0)
	closeButton.Parent = header
	create_corner(closeButton, 0.25)
	create_stroke(closeButton, 0.8)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0.03, 0, 0.12, 0)
	body.Size = UDim2.new(0.94, 0, 0.86, 0)
	body.Parent = window

	local categoryList = Instance.new("ScrollingFrame")
	categoryList.Name = "CategoryList"
	categoryList.BackgroundColor3 = Color3.fromRGB(20, 22, 29)
	categoryList.BorderSizePixel = 0
	categoryList.Size = UDim2.new(0.33, 0, 1, 0)
	categoryList.Position = UDim2.new(0, 0, 0, 0)
	categoryList.ScrollBarThickness = 5
	categoryList.CanvasSize = UDim2.new(0, 0, 1, 0)
	categoryList.Parent = body
	create_corner(categoryList, 0.06)
	create_stroke(categoryList, 0.85)

	local categoryLayout = Instance.new("UIListLayout")
	categoryLayout.Padding = UDim.new(0.015, 0)
	categoryLayout.Parent = categoryList

	local itemList = Instance.new("ScrollingFrame")
	itemList.Name = "ItemList"
	itemList.BackgroundColor3 = Color3.fromRGB(20, 22, 29)
	itemList.BorderSizePixel = 0
	itemList.Size = UDim2.new(0.65, 0, 0.84, 0)
	itemList.Position = UDim2.new(0.35, 0, 0, 0)
	itemList.ScrollBarThickness = 5
	itemList.CanvasSize = UDim2.new(0, 0, 1, 0)
	itemList.Parent = body
	create_corner(itemList, 0.05)
	create_stroke(itemList, 0.85)

	local itemLayout = Instance.new("UIListLayout")
	itemLayout.Padding = UDim.new(0.02, 0)
	itemLayout.Parent = itemList

	local placeToggle = Instance.new("TextButton")
	placeToggle.Name = "PlaceToggleButton"
	placeToggle.Text = "Modo colocar: OFF"
	placeToggle.Font = Enum.Font.GothamBold
	placeToggle.TextColor3 = Color3.fromRGB(245, 245, 250)
	placeToggle.TextSize = 13
	placeToggle.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
	placeToggle.BorderSizePixel = 0
	placeToggle.Size = UDim2.new(0.65, 0, 0.13, 0)
	placeToggle.Position = UDim2.new(0.35, 0, 0.87, 0)
	placeToggle.Parent = body
	create_corner(placeToggle, 0.16)
	create_stroke(placeToggle, 0.8)

	local selectedLabel = Instance.new("TextLabel")
	selectedLabel.Name = "SelectedLabel"
	selectedLabel.BackgroundTransparency = 1
	selectedLabel.Size = UDim2.new(1, 0, 0.14, 0)
	selectedLabel.Position = UDim2.new(0, 0, 0.86, 0)
	selectedLabel.Font = Enum.Font.GothamMedium
	selectedLabel.TextSize = 12
	selectedLabel.TextColor3 = Color3.fromRGB(150, 190, 255)
	selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
	selectedLabel.Text = "Selecionado: nenhum"
	selectedLabel.Parent = body

	return window
end

local function patch_gui(gui: ScreenGui): ()
	local topBar = gui:FindFirstChild("TopBar")
	if not topBar or not topBar:IsA("Frame") then
		return
	end

	create_topbar_button(topBar)
	create_prefab_window(gui)
	gui:SetAttribute("PrefabUiPatched", true)
end

local function try_patch_existing(): ()
	local gui = playerGui:FindFirstChild(GUI_NAME)
	if gui and gui:IsA("ScreenGui") then
		patch_gui(gui)
	end
end

------------------//INIT
try_patch_existing()

playerGui.ChildAdded:Connect(function(child)
	if child.Name == GUI_NAME and child:IsA("ScreenGui") then
		task.defer(function()
			patch_gui(child)
		end)
	end
end)
