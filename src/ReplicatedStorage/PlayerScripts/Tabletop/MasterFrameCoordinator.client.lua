------------------//SERVICES
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local GUI_NAME: string = "MasterGui"

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
				end)
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
		end)
	end
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
