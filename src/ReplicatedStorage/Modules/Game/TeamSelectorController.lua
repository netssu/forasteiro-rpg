------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//MODULES
local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local dictionaryFolder: Folder = modulesFolder:WaitForChild("Dictionary")
local utilityFolder: Folder = modulesFolder:WaitForChild("Utility")
local TeamDictionary = require(dictionaryFolder:WaitForChild("TeamDictionary"))
local TeamRemoteUtility = require(utilityFolder:WaitForChild("TeamRemoteUtility"))
local MenuCamera = require(utilityFolder:WaitForChild("MenuCamera"))
local SquareTransition = require(utilityFolder:WaitForChild("SquareTransition"))

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")
local teamSelectEvent: RemoteEvent

local teamGui: ScreenGui? = nil
local mainFrame: Frame? = nil
local masterButton: TextButton? = nil
local playerButton: TextButton? = nil

local masterConnection: RBXScriptConnection? = nil
local playerConnection: RBXScriptConnection? = nil
local isTransitionPlaying: boolean = false


------------------//FUNCTIONS
local function cache_gui_objects(): ()
	local guiObject = playerGui:FindFirstChild(TeamDictionary.GUI_NAME)
	if not guiObject or not guiObject:IsA("ScreenGui") then
		teamGui = nil
		mainFrame = nil
		masterButton = nil
		playerButton = nil
		return
	end

	teamGui = guiObject
	mainFrame = teamGui:FindFirstChild(TeamDictionary.MAIN_FRAME_NAME) :: Frame?
	masterButton = mainFrame and mainFrame:FindFirstChild(TeamDictionary.MASTER_BUTTON_NAME) :: TextButton?
	playerButton = mainFrame and mainFrame:FindFirstChild(TeamDictionary.PLAYER_BUTTON_NAME) :: TextButton?
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
	if isTransitionPlaying then
		return
	end

	isTransitionPlaying = true

	task.spawn(function()
		local container: GuiObject? = nil
		local screamGui = playerGui:FindFirstChild("screamGui")

		if screamGui and screamGui:IsA("ScreenGui") then
			container = screamGui:FindFirstChild("BothUI") :: GuiObject?
		end

		if not container then
			container = mainFrame
		end

		if not container then
			teamSelectEvent:FireServer(teamName)
			isTransitionPlaying = false
			return
		end

		local success = pcall(function()
			SquareTransition.play(container, {
				tileSize = 100,
				onFilled = function()
					teamSelectEvent:FireServer(teamName)
				end,
			})
		end)

		if not success then
			teamSelectEvent:FireServer(teamName)
		end

		isTransitionPlaying = false
	end)
end

local function connect_buttons(): ()
	disconnect_button_connections()
	if not masterButton or not playerButton then
		return
	end

	masterConnection = masterButton.MouseButton1Click:Connect(function()
		select_team(TeamDictionary.MASTER_TEAM_NAME)
	end)

	playerConnection = playerButton.MouseButton1Click:Connect(function()
		select_team(TeamDictionary.PLAYER_TEAM_NAME)
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
	if child.Name ~= TeamDictionary.GUI_NAME then
		return
	end

	task.defer(function()
		cache_gui_objects()
		connect_buttons()
		update_menu_state()
	end)
end

------------------//MAIN FUNCTIONS
local TeamSelectorController = {}

function TeamSelectorController.run(): ()
	teamSelectEvent = TeamRemoteUtility.get_team_select_event()
	cache_gui_objects()
	connect_buttons()
	update_menu_state()
	player:GetPropertyChangedSignal("Team"):Connect(update_menu_state)
	playerGui.ChildAdded:Connect(on_gui_added)
end

return TeamSelectorController
