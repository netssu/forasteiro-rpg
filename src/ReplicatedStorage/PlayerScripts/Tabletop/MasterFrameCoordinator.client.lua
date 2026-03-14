------------------//SERVICES
local Players: Players = game:GetService("Players")
local TweenService: TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local GUI_NAME: string = "MasterGui"
local ACTIVE_BUTTON_COLOR: Color3 = Color3.fromRGB(255, 208, 74)
local INACTIVE_BUTTON_COLOR: Color3 = Color3.fromRGB(34, 36, 44)
local TOPBAR_COLLAPSED_X_SCALE: number = 0.937
local TOPBAR_TWEEN_INFO: TweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local BUTTON_TO_FRAME: {[string]: string} = {
	EnvironmentToggleButton = "EnvironmentWindow",
	PlayersToggleButton = "PlayersWindow",
	CombatToggleButton = "CombatWindow",
	BuildToggleButton = "BuildSidebar",
	RoomToggleButton = "RoomSidebar",
	NpcToggleButton = "NpcSidebar",
	TerrainToggleButton = "TerrainWindow",
	PrefabToggleButton = "PrefabWindow",
}

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")
local activePositionTweens: {[GuiObject]: Tween} = {}

------------------//FUNCTIONS
local function get_master_gui(): ScreenGui?
	local gui = playerGui:FindFirstChild(GUI_NAME)
	if gui and gui:IsA("ScreenGui") then
		return gui
	end
	return nil
end

local function find_gui_object(parent: Instance, childName: string): GuiObject?
	local child = parent:FindFirstChild(childName)
	if child and child:IsA("GuiObject") then
		return child
	end
	return nil
end

local function get_frames(gui: ScreenGui): {[string]: GuiObject?}
	return {
		EnvironmentWindow = find_gui_object(gui, "EnvironmentWindow"),
		PlayersWindow = find_gui_object(gui, "PlayersWindow"),
		CombatWindow = find_gui_object(gui, "CombatWindow"),
		BuildSidebar = find_gui_object(gui, "BuildSidebar"),
		RoomSidebar = find_gui_object(gui, "RoomSidebar"),
		NpcSidebar = find_gui_object(gui, "NpcSidebar"),
		TerrainWindow = find_gui_object(gui, "TerrainWindow"),
		PrefabWindow = find_gui_object(gui, "PrefabWindow"),
	}
end

local function close_except(frames: {[string]: GuiObject?}, keepName: string?): ()
	for name, frame in frames do
		if frame and name ~= keepName then
			frame.Visible = false
		end
	end
end

local function has_any_frame_open(frames: {[string]: GuiObject?}): boolean
	for _, frame in frames do
		if frame and frame.Visible then
			return true
		end
	end

	return false
end

local function cache_normal_position(guiObject: GuiObject): ()
	if guiObject:GetAttribute("NormalPositionXScale") == nil then
		guiObject:SetAttribute("NormalPositionXScale", guiObject.Position.X.Scale)
		guiObject:SetAttribute("NormalPositionXOffset", guiObject.Position.X.Offset)
		guiObject:SetAttribute("NormalPositionYScale", guiObject.Position.Y.Scale)
		guiObject:SetAttribute("NormalPositionYOffset", guiObject.Position.Y.Offset)
	end
end

local function get_normal_position(guiObject: GuiObject): UDim2
	return UDim2.new(
		guiObject:GetAttribute("NormalPositionXScale") or 0,
		guiObject:GetAttribute("NormalPositionXOffset") or 0,
		guiObject:GetAttribute("NormalPositionYScale") or 0,
		guiObject:GetAttribute("NormalPositionYOffset") or 0
	)
end

local function play_horizontal_tween(guiObject: GuiObject, targetPosition: UDim2): ()
	if guiObject.Position == targetPosition then
		return
	end

	local currentTween = activePositionTweens[guiObject]
	if currentTween then
		currentTween:Cancel()
		activePositionTweens[guiObject] = nil
	end

	local tween = TweenService:Create(guiObject, TOPBAR_TWEEN_INFO, {
		Position = targetPosition,
	})
	activePositionTweens[guiObject] = tween

	tween.Completed:Connect(function()
		if activePositionTweens[guiObject] == tween then
			activePositionTweens[guiObject] = nil
		end
	end)

	tween:Play()
end

local function get_collapsed_topbar_position(topBar: GuiObject): UDim2
	local normalPosition = get_normal_position(topBar)

	return UDim2.new(
		TOPBAR_COLLAPSED_X_SCALE,
		0,
		normalPosition.Y.Scale,
		normalPosition.Y.Offset
	)
end

------------------//MAIN FUNCTIONS
local function refresh_topbar_layout(gui: ScreenGui): ()
	local topBar = gui:FindFirstChild("TopBar")
	if not topBar or not topBar:IsA("GuiObject") then
		return
	end

	cache_normal_position(topBar)

	local frames = get_frames(gui)
	local hasOpenFrame = has_any_frame_open(frames)

	local normalTopBarPosition = get_normal_position(topBar)
	local collapsedTopBarPosition = get_collapsed_topbar_position(topBar)
	local topBarTargetPosition = hasOpenFrame and normalTopBarPosition or collapsedTopBarPosition

	play_horizontal_tween(topBar, topBarTargetPosition)

	local deltaScaleX = collapsedTopBarPosition.X.Scale - normalTopBarPosition.X.Scale

	for _, frame in frames do
		if frame then
			cache_normal_position(frame)

			local frameNormalPosition = get_normal_position(frame)
			local frameTargetPosition = hasOpenFrame
				and frameNormalPosition
				or UDim2.new(
					frameNormalPosition.X.Scale + deltaScaleX,
					frameNormalPosition.X.Offset,
					frameNormalPosition.Y.Scale,
					frameNormalPosition.Y.Offset
				)

			play_horizontal_tween(frame, frameTargetPosition)
		end
	end
end

local function refresh_topbar_button_states(gui: ScreenGui): ()
	local topBar = gui:FindFirstChild("TopBar")
	if not topBar then
		return
	end

	local frames = get_frames(gui)

	for buttonName, frameName in BUTTON_TO_FRAME do
		local button = topBar:FindFirstChild(buttonName)
		if button and button:IsA("TextButton") then
			local frame = frames[frameName]
			button.BackgroundColor3 = (frame and frame.Visible) and ACTIVE_BUTTON_COLOR or INACTIVE_BUTTON_COLOR
		end
	end

	refresh_topbar_layout(gui)
end

local function wire_gui(gui: ScreenGui): ()
	local topBar = gui:FindFirstChild("TopBar")
	if not topBar then
		return
	end

	for buttonName, frameName in BUTTON_TO_FRAME do
		local button = topBar:FindFirstChild(buttonName)

		if button and button:IsA("TextButton") and not button:GetAttribute("ExclusiveBound") then
			button:SetAttribute("ExclusiveBound", true)

			button.MouseButton1Click:Connect(function()
				task.defer(function()
					local currentGui = get_master_gui()
					if not currentGui then
						return
					end

					local frames = get_frames(currentGui)
					local targetFrame = frames[frameName]

					if targetFrame and targetFrame.Visible then
						close_except(frames, frameName)
					end

					refresh_topbar_button_states(currentGui)
				end)
			end)
		end
	end

	for _, frame in get_frames(gui) do
		if frame and not frame:GetAttribute("MasterFrameVisibleBound") then
			frame:SetAttribute("MasterFrameVisibleBound", true)
			frame:GetPropertyChangedSignal("Visible"):Connect(function()
				local currentGui = get_master_gui()
				if currentGui then
					refresh_topbar_button_states(currentGui)
				end
			end)
		end
	end

	local returnButton = topBar:FindFirstChild("ReturnButton")
	if returnButton and returnButton:IsA("TextButton") and not returnButton:GetAttribute("ExclusiveBound") then
		returnButton:SetAttribute("ExclusiveBound", true)

		returnButton.MouseButton1Click:Connect(function()
			local currentGui = get_master_gui()
			if not currentGui then
				return
			end

			close_except(get_frames(currentGui), nil)
			refresh_topbar_button_states(currentGui)
		end)
	end

	refresh_topbar_button_states(gui)
end

------------------//INIT
local gui = get_master_gui()
if gui then
	wire_gui(gui)
end

playerGui.ChildAdded:Connect(function(child)
	if child.Name == GUI_NAME and child:IsA("ScreenGui") then
		task.defer(function()
			wire_gui(child)
		end)
	end
end)