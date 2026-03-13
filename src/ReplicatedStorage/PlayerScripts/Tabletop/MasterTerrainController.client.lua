------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//CONSTANTS
local MASTER_TEAM_NAME: string = "Mestre"
local GUI_NAME: string = "MasterGui"
local REMOTE_NAME: string = "MasterBuildEvent"

local TERRAIN_TOGGLE_BUTTON_NAME: string = "TerrainToggleButton"
local TERRAIN_WINDOW_NAME: string = "TerrainWindow"

local TERRAIN_CENTER: Vector3 = Vector3.new(0, 0, 0)

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local masterBuildEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)

local biomeConfigs = {
	Arctic = {
		Material = Enum.Material.Snow,
		Color = Color3.fromRGB(225, 235, 241),
		Width = 256,
		Accent = Color3.fromRGB(189, 212, 224),
	},
	Dunes = {
		Material = Enum.Material.Sand,
		Color = Color3.fromRGB(215, 188, 133),
		Width = 288,
		Accent = Color3.fromRGB(181, 152, 101),
	},
	Canyons = {
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(144, 99, 77),
		Width = 320,
		Accent = Color3.fromRGB(117, 78, 62),
	},
	Lavascape = {
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(89, 39, 36),
		Width = 288,
		Accent = Color3.fromRGB(171, 74, 41),
	},
	Water = {
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(63, 125, 194),
		Width = 320,
		Accent = Color3.fromRGB(99, 170, 212),
	},
	Mountains = {
		Material = Enum.Material.Rock,
		Color = Color3.fromRGB(115, 120, 123),
		Width = 320,
		Accent = Color3.fromRGB(87, 91, 95),
	},
	Hills = {
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(100, 148, 76),
		Width = 288,
		Accent = Color3.fromRGB(71, 115, 52),
	},
	Plains = {
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(118, 161, 81),
		Width = 352,
		Accent = Color3.fromRGB(93, 136, 58),
	},
	Marsh = {
		Material = Enum.Material.Mud,
		Color = Color3.fromRGB(81, 103, 70),
		Width = 320,
		Accent = Color3.fromRGB(57, 73, 47),
	},
}

local biomeOrder = {"Arctic", "Dunes", "Canyons", "Lavascape", "Water", "Mountains", "Hills", "Plains", "Marsh"}
local widthOptions = {192, 256, 320, 384, 448, 512}
local colorPresets = {
	Color3.fromRGB(94, 132, 76),
	Color3.fromRGB(143, 122, 86),
	Color3.fromRGB(84, 122, 161),
	Color3.fromRGB(110, 95, 83),
	Color3.fromRGB(164, 151, 116),
	Color3.fromRGB(120, 129, 132),
}
local materialOptions = {
	Enum.Material.Grass,
	Enum.Material.Ground,
	Enum.Material.Mud,
	Enum.Material.Sand,
	Enum.Material.Rock,
	Enum.Material.Slate,
	Enum.Material.Snow,
	Enum.Material.Ice,
}

local state = {
	SelectedBiome = "Marsh",
	SelectedWidth = 240,
	SelectedColor = colorPresets[1],
	SelectedMaterial = Enum.Material.Mud,
	Brightness = 1,
	UseDetailLayer = true,
	HideBaseplate = true,
}

local uiRefs = {
	Window = nil,
	ToggleButton = nil,
	BiomeChecks = {},
	WidthButtons = {},
	ColorButtons = {},
	BrightnessFill = nil,
	BrightnessValue = nil,
	MaterialLabel = nil,
	DetailToggle = nil,
	BaseplateToggle = nil,
}

------------------//FUNCTIONS
local function is_master(): boolean
	return player.Team ~= nil and player.Team.Name == MASTER_TEAM_NAME
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

local function create_label(parent: Instance, text: string, pos: UDim2, size: UDim2, textSize: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(230, 230, 230)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.TextSize = textSize or 13
	label.Position = pos
	label.Size = size
	label.Parent = parent
	return label
end

local function create_button(parent: Instance, text: string, pos: UDim2, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Color3.fromRGB(36, 40, 53)
	button.BorderSizePixel = 0
	button.TextColor3 = Color3.fromRGB(240, 240, 240)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.Text = text
	button.Position = pos
	button.Size = size
	button.AutoButtonColor = true
	button.Parent = parent
	create_corner(button, 8)
	create_stroke(button, 1, 0.72)
	return button
end

local function fire_build(action: string, payload: {[string]: any}): ()
	payload.Action = action
	masterBuildEvent:FireServer(payload)
end

local function get_biome_config()
	return biomeConfigs[state.SelectedBiome] or biomeConfigs.Marsh
end

local function apply_terrain(): ()
	if not is_master() then
		return
	end

	local biome = get_biome_config()
	local width = state.SelectedWidth > 0 and state.SelectedWidth or biome.Width
	local relief = state.UseDetailLayer and (1 + ((state.Brightness - 1) * 0.8)) or (0.85 + ((state.Brightness - 1) * 0.6))

	fire_build("GenerateBiomeTerrain", {
		Center = TERRAIN_CENTER,
		Width = width,
		Biome = state.SelectedBiome,
		TopMaterial = state.SelectedMaterial,
		Relief = relief,
		HideBaseplate = state.HideBaseplate,
	})
end

local function restore_default_world(): ()
	if not is_master() then
		return
	end

	fire_build("ResetGeneratedTerrain", {})
end

local function refresh_selection_visuals(): ()
	for biomeName, checkButton in uiRefs.BiomeChecks do
		checkButton.Text = state.SelectedBiome == biomeName and "☑" or "☐"
	end

	for widthValue, button in uiRefs.WidthButtons do
		button.BackgroundColor3 = state.SelectedWidth == widthValue and Color3.fromRGB(69, 114, 84) or Color3.fromRGB(36, 40, 53)
	end

	for colorValue, button in uiRefs.ColorButtons do
		button.BackgroundColor3 = colorValue
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = (state.SelectedColor == colorValue) and 0.1 or 0.6
		end
	end

	if uiRefs.BrightnessFill and uiRefs.BrightnessValue then
		local pct = math.clamp((state.Brightness - 0.4) / 1.2, 0, 1)
		uiRefs.BrightnessFill.Size = UDim2.new(pct, 0, 1, 0)
		uiRefs.BrightnessValue.Text = string.format("%.2fx", state.Brightness)
	end

	if uiRefs.MaterialLabel then
		uiRefs.MaterialLabel.Text = "Material: " .. state.SelectedMaterial.Name
	end

	if uiRefs.DetailToggle then
		uiRefs.DetailToggle.Text = state.UseDetailLayer and "Detalhe: ON" or "Detalhe: OFF"
	end

	if uiRefs.BaseplateToggle then
		uiRefs.BaseplateToggle.Text = state.HideBaseplate and "Ocultar baseplate: ON" or "Ocultar baseplate: OFF"
	end
end

local function build_brightness_slider(parent: Instance): ()
	create_label(parent, "Brightness", UDim2.fromOffset(16, 310), UDim2.fromOffset(120, 20))
	local valueLabel = create_label(parent, "1.00x", UDim2.fromOffset(326, 310), UDim2.fromOffset(62, 20))
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	uiRefs.BrightnessValue = valueLabel

	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(16, 334)
	track.Size = UDim2.fromOffset(372, 16)
	track.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
	track.BorderSizePixel = 0
	track.Parent = parent
	create_corner(track, 8)
	create_stroke(track, 1, 0.6)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0.5, 1)
	fill.BackgroundColor3 = Color3.fromRGB(91, 157, 119)
	fill.BorderSizePixel = 0
	fill.Parent = track
	create_corner(fill, 8)
	uiRefs.BrightnessFill = fill

	local dragging = false
	local function update_from_x(mouseX: number)
		local pct = math.clamp((mouseX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		state.Brightness = 0.4 + (1.2 * pct)
		refresh_selection_visuals()
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			update_from_x(input.Position.X)
		end
	end)

	track.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			update_from_x(input.Position.X)
		end
	end)
end

local function build_terrain_ui(masterGui: ScreenGui): ()
	local topBar = masterGui:FindFirstChild("TopBar")
	if not topBar or not topBar:IsA("Frame") then
		return
	end

	local existingToggle = topBar:FindFirstChild(TERRAIN_TOGGLE_BUTTON_NAME)
	if existingToggle then
		existingToggle:Destroy()
	end

	local toggle = create_button(topBar, "Terreno", UDim2.fromOffset(548, 6), UDim2.fromOffset(90, 32))
	toggle.Name = TERRAIN_TOGGLE_BUTTON_NAME
	uiRefs.ToggleButton = toggle

	local existingWindow = masterGui:FindFirstChild(TERRAIN_WINDOW_NAME)
	if existingWindow then
		existingWindow:Destroy()
	end

	local window = Instance.new("Frame")
	window.Name = TERRAIN_WINDOW_NAME
	window.Visible = false
	window.Size = UDim2.fromOffset(410, 610)
	window.Position = UDim2.fromOffset(16, 66)
	window.BackgroundColor3 = Color3.fromRGB(18, 20, 27)
	window.BorderSizePixel = 0
	window.Parent = masterGui
	create_corner(window, 12)
	create_stroke(window, 1, 0.6)
	uiRefs.Window = window

	create_label(window, "Terreno / Bioma", UDim2.fromOffset(16, 10), UDim2.fromOffset(250, 24), 15)

	local biomeFrame = Instance.new("Frame")
	biomeFrame.Position = UDim2.fromOffset(16, 40)
	biomeFrame.Size = UDim2.fromOffset(180, 250)
	biomeFrame.BackgroundColor3 = Color3.fromRGB(25, 27, 34)
	biomeFrame.BorderSizePixel = 0
	biomeFrame.Parent = window
	create_corner(biomeFrame, 10)
	create_stroke(biomeFrame, 1, 0.7)

	create_label(biomeFrame, "Biomes", UDim2.fromOffset(10, 8), UDim2.fromOffset(120, 20))

	for index, biomeName in biomeOrder do
		local rowY = 30 + ((index - 1) * 24)
		local check = create_button(biomeFrame, "☐", UDim2.fromOffset(10, rowY), UDim2.fromOffset(22, 22))
		check.TextSize = 16
		local label = create_label(biomeFrame, biomeName, UDim2.fromOffset(40, rowY + 1), UDim2.fromOffset(130, 20), 14)
		label.TextColor3 = Color3.fromRGB(225, 225, 225)

		check.MouseButton1Click:Connect(function()
			state.SelectedBiome = biomeName
			local biome = get_biome_config()
			state.SelectedMaterial = biome.Material
			state.SelectedColor = biome.Color
			refresh_selection_visuals()
		end)

		uiRefs.BiomeChecks[biomeName] = check
	end

	local widthFrame = Instance.new("Frame")
	widthFrame.Position = UDim2.fromOffset(210, 40)
	widthFrame.Size = UDim2.fromOffset(184, 132)
	widthFrame.BackgroundColor3 = Color3.fromRGB(25, 27, 34)
	widthFrame.BorderSizePixel = 0
	widthFrame.Parent = window
	create_corner(widthFrame, 10)
	create_stroke(widthFrame, 1, 0.7)
	create_label(widthFrame, "Largura predefinida", UDim2.fromOffset(10, 8), UDim2.fromOffset(150, 20))

	for index, widthValue in widthOptions do
		local col = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local btn = create_button(widthFrame, tostring(widthValue), UDim2.fromOffset(10 + (col * 86), 36 + (row * 38)), UDim2.fromOffset(80, 32))
		btn.MouseButton1Click:Connect(function()
			state.SelectedWidth = widthValue
			refresh_selection_visuals()
		end)
		uiRefs.WidthButtons[widthValue] = btn
	end

	local materialFrame = Instance.new("Frame")
	materialFrame.Position = UDim2.fromOffset(210, 186)
	materialFrame.Size = UDim2.fromOffset(184, 104)
	materialFrame.BackgroundColor3 = Color3.fromRGB(25, 27, 34)
	materialFrame.BorderSizePixel = 0
	materialFrame.Parent = window
	create_corner(materialFrame, 10)
	create_stroke(materialFrame, 1, 0.7)

	local materialIndex = 1
	for i, material in materialOptions do
		if material == state.SelectedMaterial then
			materialIndex = i
			break
		end
	end

	local prevMat = create_button(materialFrame, "<", UDim2.fromOffset(10, 38), UDim2.fromOffset(32, 32))
	local nextMat = create_button(materialFrame, ">", UDim2.fromOffset(142, 38), UDim2.fromOffset(32, 32))
	local materialLabel = create_label(materialFrame, "Material", UDim2.fromOffset(48, 44), UDim2.fromOffset(88, 20))
	materialLabel.TextXAlignment = Enum.TextXAlignment.Center
	materialLabel.TextSize = 12
	uiRefs.MaterialLabel = materialLabel

	prevMat.MouseButton1Click:Connect(function()
		materialIndex = ((materialIndex - 2) % #materialOptions) + 1
		state.SelectedMaterial = materialOptions[materialIndex]
		refresh_selection_visuals()
	end)

	nextMat.MouseButton1Click:Connect(function()
		materialIndex = (materialIndex % #materialOptions) + 1
		state.SelectedMaterial = materialOptions[materialIndex]
		refresh_selection_visuals()
	end)

	local colorsFrame = Instance.new("Frame")
	colorsFrame.Position = UDim2.fromOffset(16, 356)
	colorsFrame.Size = UDim2.fromOffset(378, 70)
	colorsFrame.BackgroundColor3 = Color3.fromRGB(25, 27, 34)
	colorsFrame.BorderSizePixel = 0
	colorsFrame.Parent = window
	create_corner(colorsFrame, 10)
	create_stroke(colorsFrame, 1, 0.7)
	create_label(colorsFrame, "Cores base", UDim2.fromOffset(10, 8), UDim2.fromOffset(120, 20))

	for index, color in colorPresets do
		local button = create_button(colorsFrame, "", UDim2.fromOffset(10 + ((index - 1) * 60), 34), UDim2.fromOffset(52, 24))
		button.Text = ""
		button.MouseButton1Click:Connect(function()
			state.SelectedColor = color
			refresh_selection_visuals()
		end)
		uiRefs.ColorButtons[color] = button
	end

	build_brightness_slider(window)

	local detailToggle = create_button(window, "Detalhe: ON", UDim2.fromOffset(16, 430), UDim2.fromOffset(184, 34))
	detailToggle.MouseButton1Click:Connect(function()
		state.UseDetailLayer = not state.UseDetailLayer
		refresh_selection_visuals()
	end)
	uiRefs.DetailToggle = detailToggle

	local baseplateToggle = create_button(window, "Ocultar baseplate: ON", UDim2.fromOffset(210, 430), UDim2.fromOffset(184, 34))
	baseplateToggle.MouseButton1Click:Connect(function()
		state.HideBaseplate = not state.HideBaseplate
		refresh_selection_visuals()
	end)
	uiRefs.BaseplateToggle = baseplateToggle

	local applyButton = create_button(window, "Aplicar terreno", UDim2.fromOffset(16, 482), UDim2.fromOffset(378, 42))
	applyButton.BackgroundColor3 = Color3.fromRGB(57, 109, 76)
	applyButton.MouseButton1Click:Connect(apply_terrain)

	local resetButton = create_button(window, "Voltar ao normal", UDim2.fromOffset(16, 534), UDim2.fromOffset(378, 42))
	resetButton.BackgroundColor3 = Color3.fromRGB(88, 62, 62)
	resetButton.MouseButton1Click:Connect(restore_default_world)

	toggle.MouseButton1Click:Connect(function()
		if not uiRefs.Window then
			return
		end
		uiRefs.Window.Visible = not uiRefs.Window.Visible
	end)

	refresh_selection_visuals()
end

local function try_setup_gui(): ()
	local masterGui = playerGui:FindFirstChild(GUI_NAME)
	if not masterGui or not masterGui:IsA("ScreenGui") then
		return
	end

	local topBar = masterGui:FindFirstChild("TopBar")
	if masterGui:FindFirstChild(TERRAIN_WINDOW_NAME) and topBar and topBar:FindFirstChild(TERRAIN_TOGGLE_BUTTON_NAME) then
		return
	end

	build_terrain_ui(masterGui)
end

playerGui.ChildAdded:Connect(function(child)
	if child.Name == GUI_NAME then
		task.defer(try_setup_gui)
	end
end)

player:GetPropertyChangedSignal("Team"):Connect(function()
	if uiRefs.Window then
		uiRefs.Window.Visible = false
	end

	if uiRefs.ToggleButton then
		uiRefs.ToggleButton.Visible = is_master()
	end
end)

task.defer(function()
	try_setup_gui()
	if uiRefs.ToggleButton then
		uiRefs.ToggleButton.Visible = is_master()
	end
end)
