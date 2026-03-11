------------------//SERVICES
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local ROLE_TOKEN_PART_NAME: string = "RoleTokenPart"
local ROLE_TOKEN_FRONT_GUI_NAME: string = "RoleTokenFrontGui"
local ROLE_TOKEN_BACK_GUI_NAME: string = "RoleTokenBackGui"
local PLAYER_SPECTATOR_ATTRIBUTE_NAME: string = "PlayerSpectatorEnabled"
local MASTER_TEAM_NAME: string = "Mestre"

------------------//VARIABLES
local player: Player = Players.LocalPlayer

------------------//FUNCTIONS
local function should_show_own_token(): boolean
	if player.Team and player.Team.Name == MASTER_TEAM_NAME then
		return true
	end

	return player:GetAttribute(PLAYER_SPECTATOR_ATTRIBUTE_NAME) == true
end

local function update_own_token_visibility(character: Model): ()
	local tokenPart = character:FindFirstChild(ROLE_TOKEN_PART_NAME)

	if not tokenPart or not tokenPart:IsA("BasePart") then
		return
	end

	local enabled = should_show_own_token()

	local frontGui = tokenPart:FindFirstChild(ROLE_TOKEN_FRONT_GUI_NAME)
	local backGui = tokenPart:FindFirstChild(ROLE_TOKEN_BACK_GUI_NAME)

	if frontGui and frontGui:IsA("SurfaceGui") then
		frontGui.Enabled = enabled
	end

	if backGui and backGui:IsA("SurfaceGui") then
		backGui.Enabled = enabled
	end
end

local function watch_character(character: Model): ()
	update_own_token_visibility(character)

	character.DescendantAdded:Connect(function(descendant: Instance)
		if descendant.Name == ROLE_TOKEN_PART_NAME and descendant:IsA("BasePart") then
			task.defer(function()
				update_own_token_visibility(character)
			end)
			return
		end

		if descendant.Name == ROLE_TOKEN_FRONT_GUI_NAME or descendant.Name == ROLE_TOKEN_BACK_GUI_NAME then
			task.defer(function()
				update_own_token_visibility(character)
			end)
		end
	end)
end

local function refresh_current_character(): ()
	local character = player.Character
	if character then
		update_own_token_visibility(character)
	end
end

------------------//MAIN FUNCTIONS
player.CharacterAdded:Connect(watch_character)
player:GetAttributeChangedSignal(PLAYER_SPECTATOR_ATTRIBUTE_NAME):Connect(refresh_current_character)
player:GetPropertyChangedSignal("Team"):Connect(refresh_current_character)

------------------//INIT
if player.Character then
	watch_character(player.Character)
end