------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//CONSTANTS
local MASTER_TEAM_NAME: string = "Mestre"
local GUI_NAME: string = "MasterGui"
local REMOTE_NAME: string = "MasterBuildEvent"

local TOP_BAR_NAME: string = "TopBar"

local TERRAIN_TOGGLE_BUTTON_NAME: string = "TerrainToggleButton"
local TERRAIN_WINDOW_NAME: string = "TerrainWindow"

local BIOME_FRAME_NAME: string = "BiomeFrame"
local WIDTH_FRAME_NAME: string = "WidthFrame"
local MATERIAL_FRAME_NAME: string = "MaterialFrame"
local COLORS_FRAME_NAME: string = "ColorsFrame"

local BRIGHTNESS_VALUE_LABEL_NAME: string = "BrightnessValueLabel"
local BRIGHTNESS_TRACK_NAME: string = "BrightnessTrack"
local BRIGHTNESS_FILL_NAME: string = "BrightnessFill"

local MATERIAL_LABEL_NAME: string = "MaterialLabel"
local MATERIAL_PREV_BUTTON_NAME: string = "MaterialPrevButton"
local MATERIAL_NEXT_BUTTON_NAME: string = "MaterialNextButton"

local DETAIL_TOGGLE_BUTTON_NAME: string = "DetailToggleButton"
local BASEPLATE_TOGGLE_BUTTON_NAME: string = "BaseplateToggleButton"
local APPLY_BUTTON_NAME: string = "ApplyTerrainButton"
local RESET_BUTTON_NAME: string = "ResetTerrainButton"

local TERRAIN_CENTER: Vector3 = Vector3.new(0, 0, 0)

local BIOME_ORDER = {"Arctic", "Dunes", "Canyons", "Lavascape", "Water", "Mountains", "Hills", "Plains", "Marsh"}
local WIDTH_OPTIONS = {192, 256, 320, 384, 448, 512}
local COLOR_PRESETS = {
	Color3.fromRGB(94, 132, 76),
	Color3.fromRGB(143, 122, 86),
	Color3.fromRGB(84, 122, 161),
	Color3.fromRGB(110, 95, 83),
	Color3.fromRGB(164, 151, 116),
	Color3.fromRGB(120, 129, 132),
}
local MATERIAL_OPTIONS = {
	Enum.Material.Grass,
	Enum.Material.Ground,
	Enum.Material.Mud,
	Enum.Material.Sand,
	Enum.Material.Rock,
	Enum.Material.Slate,
	Enum.Material.Snow,
	Enum.Material.Ice,
}

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

local state = {
	SelectedBiome = "Marsh",
	SelectedWidth = 240,
	SelectedColor = COLOR_PRESETS[1],
	SelectedMaterial = Enum.Material.Mud,
	Brightness = 1,
	UseDetailLayer = true,
	HideBaseplate = true,
}

local uiRefs = {
	MasterGui = nil,
	TopBar = nil,
	Window = nil,
	ToggleButton = nil,
	BiomeChecks = {},
	WidthButtons = {},
	ColorButtons = {},
	BrightnessTrack = nil,
	BrightnessFill = nil,
	BrightnessValue = nil,
	MaterialLabel = nil,
	MaterialPrevButton = nil,
	MaterialNextButton = nil,
	DetailToggle = nil,
	BaseplateToggle = nil,
	ApplyButton = nil,
	ResetButton = nil,
}

local materialIndex: number = 1
local brightnessDragging: boolean = false
local boundGui: ScreenGui? = nil

------------------//FUNCTIONS
local function is_master(): boolean
	return player.Team ~= nil and player.Team.Name == MASTER_TEAM_NAME
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

	for index, button in uiRefs.ColorButtons do
		button.BackgroundColor3 = COLOR_PRESETS[index]

		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = state.SelectedColor == COLOR_PRESETS[index] and 0.1 or 0.6
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

	if uiRefs.ToggleButton then
		uiRefs.ToggleButton.Visible = is_master()
	end

	if uiRefs.Window and not is_master() then
		uiRefs.Window.Visible = false
	end
end

local function update_brightness_from_x(mouseX: number): ()
	if not uiRefs.BrightnessTrack then
		return
	end

	local track = uiRefs.BrightnessTrack
	local pct = math.clamp((mouseX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
	state.Brightness = 0.4 + (1.2 * pct)
	refresh_selection_visuals()
end

local function resolve_material_index(): ()
	for index, material in MATERIAL_OPTIONS do
		if material == state.SelectedMaterial then
			materialIndex = index
			return
		end
	end

	materialIndex = 1
end

local function collect_ui_refs(masterGui: ScreenGui): ()
	uiRefs.MasterGui = masterGui
	uiRefs.TopBar = masterGui:WaitForChild(TOP_BAR_NAME)
	uiRefs.Window = masterGui:WaitForChild(TERRAIN_WINDOW_NAME)
	uiRefs.ToggleButton = uiRefs.TopBar:WaitForChild(TERRAIN_TOGGLE_BUTTON_NAME)

	local biomeFrame: Frame = uiRefs.Window:WaitForChild(BIOME_FRAME_NAME)
	local widthFrame: Frame = uiRefs.Window:WaitForChild(WIDTH_FRAME_NAME)
	local materialFrame: Frame = uiRefs.Window:WaitForChild(MATERIAL_FRAME_NAME)
	local colorsFrame: Frame = uiRefs.Window:WaitForChild(COLORS_FRAME_NAME)

	uiRefs.BiomeChecks = {}
	uiRefs.WidthButtons = {}
	uiRefs.ColorButtons = {}

	for _, biomeName in BIOME_ORDER do
		uiRefs.BiomeChecks[biomeName] = biomeFrame:WaitForChild("BiomeCheck_" .. biomeName)
	end

	for _, widthValue in WIDTH_OPTIONS do
		uiRefs.WidthButtons[widthValue] = widthFrame:WaitForChild("WidthButton_" .. tostring(widthValue))
	end

	for index = 1, #COLOR_PRESETS do
		uiRefs.ColorButtons[index] = colorsFrame:WaitForChild("ColorButton_" .. tostring(index))
	end

	uiRefs.BrightnessTrack = uiRefs.Window:WaitForChild(BRIGHTNESS_TRACK_NAME)
	uiRefs.BrightnessFill = uiRefs.BrightnessTrack:WaitForChild(BRIGHTNESS_FILL_NAME)
	uiRefs.BrightnessValue = uiRefs.Window:WaitForChild(BRIGHTNESS_VALUE_LABEL_NAME)

	uiRefs.MaterialLabel = materialFrame:WaitForChild(MATERIAL_LABEL_NAME)
	uiRefs.MaterialPrevButton = materialFrame:WaitForChild(MATERIAL_PREV_BUTTON_NAME)
	uiRefs.MaterialNextButton = materialFrame:WaitForChild(MATERIAL_NEXT_BUTTON_NAME)

	uiRefs.DetailToggle = uiRefs.Window:WaitForChild(DETAIL_TOGGLE_BUTTON_NAME)
	uiRefs.BaseplateToggle = uiRefs.Window:WaitForChild(BASEPLATE_TOGGLE_BUTTON_NAME)
	uiRefs.ApplyButton = uiRefs.Window:WaitForChild(APPLY_BUTTON_NAME)
	uiRefs.ResetButton = uiRefs.Window:WaitForChild(RESET_BUTTON_NAME)
end

local function connect_biome_buttons(): ()
	for _, biomeName in BIOME_ORDER do
		local button = uiRefs.BiomeChecks[biomeName]
		button.MouseButton1Click:Connect(function()
			state.SelectedBiome = biomeName

			local biome = get_biome_config()
			state.SelectedMaterial = biome.Material
			state.SelectedColor = biome.Color

			resolve_material_index()
			refresh_selection_visuals()
		end)
	end
end

local function connect_width_buttons(): ()
	for _, widthValue in WIDTH_OPTIONS do
		local button = uiRefs.WidthButtons[widthValue]
		button.MouseButton1Click:Connect(function()
			state.SelectedWidth = widthValue
			refresh_selection_visuals()
		end)
	end
end

local function connect_color_buttons(): ()
	for index = 1, #COLOR_PRESETS do
		local button = uiRefs.ColorButtons[index]
		local color = COLOR_PRESETS[index]

		button.MouseButton1Click:Connect(function()
			state.SelectedColor = color
			refresh_selection_visuals()
		end)
	end
end

local function connect_material_buttons(): ()
	if not uiRefs.MaterialPrevButton or not uiRefs.MaterialNextButton then
		return
	end

	uiRefs.MaterialPrevButton.MouseButton1Click:Connect(function()
		materialIndex = ((materialIndex - 2) % #MATERIAL_OPTIONS) + 1
		state.SelectedMaterial = MATERIAL_OPTIONS[materialIndex]
		refresh_selection_visuals()
	end)

	uiRefs.MaterialNextButton.MouseButton1Click:Connect(function()
		materialIndex = (materialIndex % #MATERIAL_OPTIONS) + 1
		state.SelectedMaterial = MATERIAL_OPTIONS[materialIndex]
		refresh_selection_visuals()
	end)
end

local function connect_brightness_slider(): ()
	if not uiRefs.BrightnessTrack then
		return
	end

	uiRefs.BrightnessTrack.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			brightnessDragging = true
			update_brightness_from_x(input.Position.X)
		end
	end)

	uiRefs.BrightnessTrack.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			brightnessDragging = false
		end
	end)
end

local function connect_main_buttons(): ()
	if uiRefs.ToggleButton then
		uiRefs.ToggleButton.MouseButton1Click:Connect(function()
			if not uiRefs.Window or not is_master() then
				return
			end

			uiRefs.Window.Visible = not uiRefs.Window.Visible
		end)
	end

	if uiRefs.DetailToggle then
		uiRefs.DetailToggle.MouseButton1Click:Connect(function()
			state.UseDetailLayer = not state.UseDetailLayer
			refresh_selection_visuals()
		end)
	end

	if uiRefs.BaseplateToggle then
		uiRefs.BaseplateToggle.MouseButton1Click:Connect(function()
			state.HideBaseplate = not state.HideBaseplate
			refresh_selection_visuals()
		end)
	end

	if uiRefs.ApplyButton then
		uiRefs.ApplyButton.MouseButton1Click:Connect(apply_terrain)
	end

	if uiRefs.ResetButton then
		uiRefs.ResetButton.MouseButton1Click:Connect(restore_default_world)
	end
end

local function bind_gui(masterGui: ScreenGui): ()
	if boundGui == masterGui then
		return
	end

	boundGui = masterGui

	collect_ui_refs(masterGui)
	resolve_material_index()

	connect_biome_buttons()
	connect_width_buttons()
	connect_color_buttons()
	connect_material_buttons()
	connect_brightness_slider()
	connect_main_buttons()

	refresh_selection_visuals()
end

local function try_bind_gui(): ()
	local masterGui = playerGui:FindFirstChild(GUI_NAME)
	if not masterGui or not masterGui:IsA("ScreenGui") then
		return
	end

	bind_gui(masterGui)
end

------------------//MAIN FUNCTIONS
UserInputService.InputChanged:Connect(function(input: InputObject)
	if brightnessDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		update_brightness_from_x(input.Position.X)
	end
end)

playerGui.ChildAdded:Connect(function(child: Instance)
	if child.Name == GUI_NAME and child:IsA("ScreenGui") then
		task.defer(try_bind_gui)
	end
end)

player:GetPropertyChangedSignal("Team"):Connect(function()
	refresh_selection_visuals()
end)

------------------//INIT
task.defer(function()
	try_bind_gui()
	refresh_selection_visuals()
end)
