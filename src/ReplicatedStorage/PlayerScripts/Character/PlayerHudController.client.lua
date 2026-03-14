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

local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local utilityFolder: Folder = modulesFolder:WaitForChild("Utility")
local SquareTransition = require(utilityFolder:WaitForChild("SquareTransition"))

local playerHud: ScreenGui? = nil
local returnButton: TextButton? = nil
local healthLabel: TextLabel? = nil
local buttonsConnected: boolean = false

local healthConnection: RBXScriptConnection? = nil
local maxHealthConnection: RBXScriptConnection? = nil

------------------//FUNCTIONS
local function is_player_role(): boolean
	return player.Team ~= nil and player.Team.Name == PLAYER_TEAM_NAME
end

local function cache_gui_objects(): ()
	local guiObject = playerGui:FindFirstChild(GUI_NAME)

	if not guiObject or not guiObject:IsA("ScreenGui") then
		playerHud = nil
		returnButton = nil
		healthLabel = nil
		return
	end

	playerHud = guiObject

	returnButton = playerHud:FindFirstChild("Main")
		and playerHud.Main:FindFirstChild("TopBar")
		and playerHud.Main.TopBar:FindFirstChild("ReturnButton")
		or nil

	healthLabel = playerHud:FindFirstChild("Main")
		and playerHud.Main:FindFirstChild("HealthLabel")
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
		local container: GuiObject? = playerGui:FindFirstChild("BothUI")
		if not container then
			container = playerHud
		end

		if not container then
			teamSelectEvent:FireServer({ Action = RETURN_TO_MENU_ACTION })
			return
		end

		if playerHud then
			playerHud.Enabled = false
		end

		local ok = pcall(function()
			SquareTransition.play(container, {
				tileSize = 100,
				onFilled = function()
					teamSelectEvent:FireServer({ Action = RETURN_TO_MENU_ACTION })
				end,
			})
		end)

		if not ok then
			teamSelectEvent:FireServer({ Action = RETURN_TO_MENU_ACTION })
		end
	end)
end

local function update_health_display(): ()
	if not healthLabel then return end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		local currentHp = math.floor(humanoid.Health + 0.5)
		local maxHp = math.floor(humanoid.MaxHealth + 0.5)
		healthLabel.Text = "HP: " .. tostring(currentHp) .. " / " .. tostring(maxHp)
	else
		healthLabel.Text = "HP: -- / --"
	end
end

local function setup_character_health(character: Model): ()
	if healthConnection then healthConnection:Disconnect() end
	if maxHealthConnection then maxHealthConnection:Disconnect() end

	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		healthConnection = humanoid.HealthChanged:Connect(update_health_display)
		maxHealthConnection = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update_health_display)
		update_health_display()
	end
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
		update_health_display()
	end)
end

------------------//MAIN FUNCTIONS
player:GetPropertyChangedSignal("Team"):Connect(function()
	update_gui_state()
end)

player.CharacterAdded:Connect(function(character: Model)
	setup_character_health(character)
	task.defer(function()
		update_gui_state()
	end)
end)

playerGui.ChildAdded:Connect(on_gui_added)

------------------//INIT
cache_gui_objects()
connect_buttons()
update_gui_state()

if player.Character then
	setup_character_health(player.Character)
end