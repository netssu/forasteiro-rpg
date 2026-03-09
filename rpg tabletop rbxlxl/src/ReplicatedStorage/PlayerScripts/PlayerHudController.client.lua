------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local PLAYER_TEAM_NAME: string = "Jogador"
local TEAM_REMOTE_NAME: string = "TeamSelectEvent"
local GUI_NAME: string = "PlayerHud"
local RETURN_TO_MENU_ACTION: string = "ReturnToMenu"

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local teamSelectEvent: RemoteEvent = remotesFolder:WaitForChild(TEAM_REMOTE_NAME)

local playerHud: ScreenGui? = nil
local returnButton: TextButton? = nil
local buttonsConnected: boolean = false

------------------//FUNCTIONS
local function is_player_role(): boolean
	return player.Team ~= nil and player.Team.Name == PLAYER_TEAM_NAME
end

local function cache_gui_objects(): ()
	local guiObject = playerGui:FindFirstChild(GUI_NAME)

	if not guiObject or not guiObject:IsA("ScreenGui") then
		playerHud = nil
		returnButton = nil
		return
	end

	playerHud = guiObject
	returnButton = playerHud:FindFirstChild("Main")
		and playerHud.Main:FindFirstChild("TopBar")
		and playerHud.Main.TopBar:FindFirstChild("ReturnButton")
		or nil
end

local function update_gui_state(): ()
	cache_gui_objects()

	if not playerHud then
		return
	end

	playerHud.Enabled = is_player_role()
end

local function connect_buttons(): ()
	if buttonsConnected or not returnButton then
		return
	end

	buttonsConnected = true

	returnButton.MouseButton1Click:Connect(function()
		teamSelectEvent:FireServer({
			Action = RETURN_TO_MENU_ACTION,
		})
	end)
end

local function on_gui_added(child: Instance): ()
	if child.Name ~= GUI_NAME then
		return
	end

	buttonsConnected = false

	task.defer(function()
		cache_gui_objects()
		connect_buttons()
		update_gui_state()
	end)
end

------------------//MAIN FUNCTIONS
player:GetPropertyChangedSignal("Team"):Connect(function()
	update_gui_state()
end)

player.CharacterAdded:Connect(function()
	task.defer(function()
		update_gui_state()
	end)
end)

playerGui.ChildAdded:Connect(on_gui_added)

------------------//INIT
cache_gui_objects()
connect_buttons()
update_gui_state()