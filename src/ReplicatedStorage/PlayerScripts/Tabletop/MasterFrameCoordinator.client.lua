------------------//SERVICES
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local GUI_NAME: string = "MasterGui"
local ACTIVE_BUTTON_COLOR: Color3 = Color3.fromRGB(255, 208, 74)
local INACTIVE_BUTTON_COLOR: Color3 = Color3.fromRGB(34, 36, 44)
local TOPBAR_COLLAPSED_POSITION: UDim2 = UDim2.fromOffset(12, 12)
local TOPBAR_COLLAPSED_ANCHOR: Vector2 = Vector2.new(0, 0)

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

local function refresh_topbar_layout(gui: ScreenGui): ()
	local topBar = gui:FindFirstChild("TopBar")
	if not topBar or not topBar:IsA("Frame") then
		return
	end

	if topBar:GetAttribute("NormalPositionX") == nil then
		topBar:SetAttribute("NormalPositionX", topBar.Position.X.Scale)
		topBar:SetAttribute("NormalPositionXOffset", topBar.Position.X.Offset)
		topBar:SetAttribute("NormalPositionY", topBar.Position.Y.Scale)
		topBar:SetAttribute("NormalPositionYOffset", topBar.Position.Y.Offset)
		topBar:SetAttribute("NormalAnchorX", topBar.AnchorPoint.X)
		topBar:SetAttribute("NormalAnchorY", topBar.AnchorPoint.Y)
	end

	local frames = get_frames(gui)
	local hasOpenFrame = has_any_frame_open(frames)

	if hasOpenFrame then
		topBar.AnchorPoint = Vector2.new(
			topBar:GetAttribute("NormalAnchorX") or 0,
			topBar:GetAttribute("NormalAnchorY") or 0
		)
		topBar.Position = UDim2.new(
			topBar:GetAttribute("NormalPositionX") or 0,
			topBar:GetAttribute("NormalPositionXOffset") or 0,
			topBar:GetAttribute("NormalPositionY") or 0,
			topBar:GetAttribute("NormalPositionYOffset") or 0
		)
	else
		topBar.AnchorPoint = TOPBAR_COLLAPSED_ANCHOR
		topBar.Position = TOPBAR_COLLAPSED_POSITION
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
