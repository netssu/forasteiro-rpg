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

local function create_label(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number, bold: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(230, 232, 240)
	label.TextSize = textSize
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = size
	label.Position = position
	label.Parent = parent
	return label
end

local function create_button(parent: Instance, name: string, text: string, size: UDim2, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.fromRGB(245, 245, 250)
	button.TextSize = 12
	button.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
	button.BorderSizePixel = 0
	button.Size = size
	button.Position = position
	button.AutoButtonColor = true
	button.Parent = parent
	create_corner(button, 0.18)
	create_stroke(button, 0.8)
	return button
end

local function create_textbox(parent: Instance, name: string, defaultText: string, size: UDim2, position: UDim2): TextBox
	local box = Instance.new("TextBox")
	box.Name = name
	box.Text = defaultText
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.GothamMedium
	box.TextColor3 = Color3.fromRGB(245, 245, 250)
	box.TextSize = 12
	box.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	box.BorderSizePixel = 0
	box.Size = size
	box.Position = position
	box.Parent = parent
	create_corner(box, 0.16)
	create_stroke(box, 0.82)
	return box
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
	window.Size = UDim2.new(0.26, 0, 0.72, 0)
	window.Position = UDim2.new(0.73, 0, 0.08, 0)
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
	header.Size = UDim2.new(1, 0, 0.1, 0)
	header.Parent = window

	create_label(header, "TitleLabel", "Prefabs", UDim2.new(0.72, 0, 0.58, 0), UDim2.new(0.04, 0, 0.2, 0), 16, true)
	create_button(header, "CloseButton", "×", UDim2.new(0.09, 0, 0.58, 0), UDim2.new(0.87, 0, 0.2, 0)).TextSize = 18

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0.03, 0, 0.11, 0)
	body.Size = UDim2.new(0.94, 0, 0.88, 0)
	body.Parent = window

	local categoryList = Instance.new("ScrollingFrame")
	categoryList.Name = "CategoryList"
	categoryList.BackgroundColor3 = Color3.fromRGB(20, 22, 29)
	categoryList.BorderSizePixel = 0
	categoryList.Size = UDim2.new(0.33, 0, 0.6, 0)
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
	itemList.Size = UDim2.new(0.65, 0, 0.6, 0)
	itemList.Position = UDim2.new(0.35, 0, 0, 0)
	itemList.ScrollBarThickness = 5
	itemList.CanvasSize = UDim2.new(0, 0, 1, 0)
	itemList.Parent = body
	create_corner(itemList, 0.05)
	create_stroke(itemList, 0.85)

	local itemLayout = Instance.new("UIListLayout")
	itemLayout.Padding = UDim.new(0.02, 0)
	itemLayout.Parent = itemList

	create_label(body, "SettingsLabel", "Configuração de colocação", UDim2.new(1, 0, 0.05, 0), UDim2.new(0, 0, 0.62, 0), 12, true)

	create_button(body, "PlaceToggleButton", "Modo colocar: OFF", UDim2.new(0.48, 0, 0.06, 0), UDim2.new(0, 0, 0.68, 0))
	create_button(body, "RandomRotationButton", "Rotação aleatória: OFF", UDim2.new(0.48, 0, 0.06, 0), UDim2.new(0.52, 0, 0.68, 0))
	create_button(body, "RandomScaleButton", "Tamanho aleatório: OFF", UDim2.new(0.48, 0, 0.06, 0), UDim2.new(0, 0, 0.75, 0))

	create_label(body, "ScaleMinLabel", "Escala min", UDim2.new(0.16, 0, 0.05, 0), UDim2.new(0.52, 0, 0.745, 0), 11, false)
	create_label(body, "ScaleMaxLabel", "Escala max", UDim2.new(0.16, 0, 0.05, 0), UDim2.new(0.76, 0, 0.745, 0), 11, false)
	create_textbox(body, "ScaleMinBox", "0.8", UDim2.new(0.2, 0, 0.055, 0), UDim2.new(0.52, 0, 0.79, 0))
	create_textbox(body, "ScaleMaxBox", "1.2", UDim2.new(0.2, 0, 0.055, 0), UDim2.new(0.76, 0, 0.79, 0))

	create_label(body, "FrequencyLabel", "Frequência (itens/seg) ao segurar 2s", UDim2.new(1, 0, 0.05, 0), UDim2.new(0, 0, 0.85, 0), 11, false)

	local freqTrack = Instance.new("Frame")
	freqTrack.Name = "FrequencyTrack"
	freqTrack.BackgroundColor3 = Color3.fromRGB(31, 34, 44)
	freqTrack.BorderSizePixel = 0
	freqTrack.Size = UDim2.new(0.78, 0, 0.026, 0)
	freqTrack.Position = UDim2.new(0, 0, 0.91, 0)
	freqTrack.Parent = body
	create_corner(freqTrack, 0.5)
	create_stroke(freqTrack, 0.88)

	local freqFill = Instance.new("Frame")
	freqFill.Name = "FrequencyFill"
	freqFill.BackgroundColor3 = Color3.fromRGB(120, 196, 156)
	freqFill.BorderSizePixel = 0
	freqFill.Size = UDim2.new(0.2, 0, 1, 0)
	freqFill.Parent = freqTrack
	create_corner(freqFill, 0.5)

	local freqKnob = Instance.new("Frame")
	freqKnob.Name = "FrequencyKnob"
	freqKnob.BackgroundColor3 = Color3.fromRGB(234, 236, 245)
	freqKnob.BorderSizePixel = 0
	freqKnob.AnchorPoint = Vector2.new(0.5, 0.5)
	freqKnob.Size = UDim2.new(0.05, 0, 2, 0)
	freqKnob.Position = UDim2.new(0.2, 0, 0.5, 0)
	freqKnob.Parent = freqTrack
	create_corner(freqKnob, 0.5)

	create_label(body, "FrequencyValueLabel", "2.0/s", UDim2.new(0.2, 0, 0.05, 0), UDim2.new(0.8, 0, 0.895, 0), 11, true)

	create_label(body, "SelectedLabel", "Selecionado: nenhum", UDim2.new(1, 0, 0.05, 0), UDim2.new(0, 0, 0.95, 0), 12, false).TextColor3 = Color3.fromRGB(150, 190, 255)

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
