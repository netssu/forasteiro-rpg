------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local REMOTE_NAME: string = "TeamSelectEvent"
local GUI_NAME: string = "TeamSelectGui"
local MASTER_TEAM_NAME: string = "Mestre"
local PLAYER_TEAM_NAME: string = "Jogador"

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local teamSelectEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)

local MenuCamera = require(ReplicatedStorage.Modules.Utility.MenuCamera)

local teamGui: ScreenGui? = nil
local mainFrame: Frame? = nil
local masterButton: TextButton? = nil
local playerButton: TextButton? = nil

local masterConnection: RBXScriptConnection? = nil
local playerConnection: RBXScriptConnection? = nil

------------------//FUNCTIONS
local function cache_gui_objects(): ()
	local guiObject = playerGui:FindFirstChild(GUI_NAME)

	if not guiObject or not guiObject:IsA("ScreenGui") then
		teamGui = nil
		mainFrame = nil
		masterButton = nil
		playerButton = nil
		return
	end

	teamGui = guiObject
	mainFrame = teamGui:FindFirstChild("Main")
	masterButton = mainFrame and mainFrame:FindFirstChild("MasterButton") or nil
	playerButton = mainFrame and mainFrame:FindFirstChild("PlayerButton") or nil
end

local function disconnect_button_connections(): ()
	if masterConnection then
		masterConnection:Disconnect()
		masterConnection = nil
	end

	if playerConnection then
		playerConnection:Disconnect()
		playerConnection = nil
	end
end

local function select_team(teamName: string): ()
	teamSelectEvent:FireServer(teamName)
end

local function connect_buttons(): ()
	disconnect_button_connections()

	if not masterButton or not playerButton then
		return
	end

	masterConnection = masterButton.MouseButton1Click:Connect(function()
		select_team(MASTER_TEAM_NAME)
	end)

	playerConnection = playerButton.MouseButton1Click:Connect(function()
		select_team(PLAYER_TEAM_NAME)
	end)
end

local function update_menu_state(): ()
	cache_gui_objects()

	if not player.Team then
		if teamGui then
			teamGui.Enabled = true
		end

		MenuCamera.enable()
		return
	end

	if teamGui then
		teamGui.Enabled = false
	end

	MenuCamera.disable()
end

local function on_gui_added(child: Instance): ()
	if child.Name ~= GUI_NAME then
		return
	end

	task.defer(function()
		cache_gui_objects()
		connect_buttons()
		update_menu_state()
	end)
end

------------------//MAIN FUNCTIONS
cache_gui_objects()
connect_buttons()
update_menu_state()

player:GetPropertyChangedSignal("Team"):Connect(update_menu_state)
playerGui.ChildAdded:Connect(on_gui_added)

------------------//INIT