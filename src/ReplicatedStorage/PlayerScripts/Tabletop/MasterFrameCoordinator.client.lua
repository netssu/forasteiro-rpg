------------------//SERVICES
local Players: Players = game:GetService("Players")
local TweenService: TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local GUI_NAME: string = "MasterGui"
local ACTIVE_BUTTON_COLOR: Color3 = Color3.fromRGB(255, 208, 74)
local INACTIVE_BUTTON_COLOR: Color3 = Color3.fromRGB(34, 36, 44)
local TOPBAR_VISIBLE_WIDTH_WHEN_COLLAPSED: number = 210
local TOPBAR_TWEEN_INFO: TweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local BUTTON_TO_FRAME = {
	EnvironmentToggleButton = "EnvironmentWindow",
	PlayersToggleButton = "PlayersWindow",
	CombatToggleButton = "CombatWindow",
	BuildToggleButton = "BuildSidebar",
	RoomToggleButton = "RoomSidebar",
	NpcToggleButton = "NpcSidebar",
	TerrainToggleButton = "TerrainWindow",
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

local function get_frames(gui: ScreenGui): {[string]: GuiObject?}
	return {
		EnvironmentWindow = gui:FindFirstChild("EnvironmentWindow"),
		PlayersWindow = gui:FindFirstChild("PlayersWindow"),
		CombatWindow = gui:FindFirstChild("CombatWindow"),
		BuildSidebar = gui:FindFirstChild("BuildSidebar"),
		RoomSidebar = gui:FindFirstChild("RoomSidebar"),
		NpcSidebar = gui:FindFirstChild("NpcSidebar"),
		TerrainWindow = gui:FindFirstChild("TerrainWindow"),
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
	if guiObject:GetAttribute("NormalPositionX") == nil then
		guiObject:SetAttribute("NormalPositionX", guiObject.Position.X.Scale)
		guiObject:SetAttribute("NormalPositionXOffset", guiObject.Position.X.Offset)
		guiObject:SetAttribute("NormalPositionY", guiObject.Position.Y.Scale)
		guiObject:SetAttribute("NormalPositionYOffset", guiObject.Position.Y.Offset)
	end
end

local function get_normal_x(guiObject: GuiObject): UDim
	return UDim.new(guiObject:GetAttribute("NormalPositionX") or 0, guiObject:GetAttribute("NormalPositionXOffset") or 0)
end

local function play_horizontal_tween(guiObject: GuiObject, targetX: UDim): ()
	local targetPosition = UDim2.new(targetX.Scale, targetX.Offset, guiObject.Position.Y.Scale, guiObject.Position.Y.Offset)

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

local function refresh_topbar_layout(gui: ScreenGui): ()
	local topBar = gui:FindFirstChild("TopBar")
	if not topBar or not topBar:IsA("Frame") then
		return
	end

	cache_normal_position(topBar)

	local frames = get_frames(gui)
	local hasOpenFrame = has_any_frame_open(frames)
	local normalTopBarX = get_normal_x(topBar)
	local collapsedTopBarX = UDim.new(1, -TOPBAR_VISIBLE_WIDTH_WHEN_COLLAPSED)
	local topBarTargetX = hasOpenFrame and normalTopBarX or collapsedTopBarX

	play_horizontal_tween(topBar, topBarTargetX)

	local deltaX = UDim.new(
		collapsedTopBarX.Scale - normalTopBarX.Scale,
		collapsedTopBarX.Offset - normalTopBarX.Offset
	)

	for _, frame in frames do
		if frame then
			cache_normal_position(frame)

			local frameNormalX = get_normal_x(frame)
			local frameTargetX = hasOpenFrame
				and frameNormalX
				or UDim.new(frameNormalX.Scale + deltaX.Scale, frameNormalX.Offset + deltaX.Offset)

			play_horizontal_tween(frame, frameTargetX)
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
