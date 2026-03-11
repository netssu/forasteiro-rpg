------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//CONSTANTS
local CHARACTERS_FOLDER_NAME: string = "Characters"
local ROLE_IMAGE_REMOTE_NAME: string = "RoleImageEvent"

------------------//VARIABLES
local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local roleImageEvent: RemoteEvent = remotesFolder:WaitForChild(ROLE_IMAGE_REMOTE_NAME)
local charactersFolder: Folder = workspace:WaitForChild(CHARACTERS_FOLDER_NAME)

local RoleManager = require(ServerStorage.Modules.Game.RoleManager)

------------------//FUNCTIONS
local function on_character_added(character: Model): ()
	RoleManager.initialize_character(character)
end

local function on_character_removing(character: Model): ()
	RoleManager.clear_character(character)
end

local function on_player_added(player: Player): ()
	player:GetPropertyChangedSignal("Team"):Connect(function()
		local character = player.Character
		if character and character.Parent == charactersFolder then
			RoleManager.apply_role_state(character)
		end
	end)
end

------------------//MAIN FUNCTIONS
roleImageEvent.OnServerEvent:Connect(RoleManager.process_image_request)

charactersFolder.ChildAdded:Connect(function(child: Instance)
	if child:IsA("Model") then
		on_character_added(child)
	end
end)

charactersFolder.ChildRemoved:Connect(function(child: Instance)
	if child:IsA("Model") then
		on_character_removing(child)
	end
end)

Players.PlayerAdded:Connect(on_player_added)

------------------//INIT
for _, player in Players:GetPlayers() do
	on_player_added(player)
end

for _, child in charactersFolder:GetChildren() do
	if child:IsA("Model") then
		on_character_added(child)
	end
end