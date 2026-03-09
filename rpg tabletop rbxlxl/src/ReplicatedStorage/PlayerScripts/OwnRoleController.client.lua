------------------//SERVICES
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local ROLE_TOKEN_PART_NAME: string = "RoleTokenPart"
local ROLE_TOKEN_FRONT_GUI_NAME: string = "RoleTokenFrontGui"
local ROLE_TOKEN_BACK_GUI_NAME: string = "RoleTokenBackGui"

------------------//VARIABLES
local player: Player = Players.LocalPlayer

------------------//FUNCTIONS
local function hide_own_token(character: Model): ()
	local tokenPart = character:FindFirstChild(ROLE_TOKEN_PART_NAME)

	if not tokenPart or not tokenPart:IsA("BasePart") then
		return
	end

	local frontGui = tokenPart:FindFirstChild(ROLE_TOKEN_FRONT_GUI_NAME)
	local backGui = tokenPart:FindFirstChild(ROLE_TOKEN_BACK_GUI_NAME)

	if frontGui and frontGui:IsA("SurfaceGui") then
		frontGui.Enabled = false
	end

	if backGui and backGui:IsA("SurfaceGui") then
		backGui.Enabled = false
	end
end

local function watch_character(character: Model): ()
	hide_own_token(character)

	character.DescendantAdded:Connect(function(descendant: Instance)
		if descendant.Name == ROLE_TOKEN_PART_NAME and descendant:IsA("BasePart") then
			task.defer(function()
				hide_own_token(character)
			end)
			return
		end

		if descendant.Name == ROLE_TOKEN_FRONT_GUI_NAME or descendant.Name == ROLE_TOKEN_BACK_GUI_NAME then
			task.defer(function()
				hide_own_token(character)
			end)
		end
	end)
end

------------------//INIT
if player.Character then
	watch_character(player.Character)
end

player.CharacterAdded:Connect(function(character: Model)
	watch_character(character)
end)