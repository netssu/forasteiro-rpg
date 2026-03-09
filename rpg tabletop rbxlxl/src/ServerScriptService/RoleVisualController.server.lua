------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams: Teams = game:GetService("Teams")

------------------//CONSTANTS
local REMOTE_NAME: string = "TeamSelectEvent"
local MASTER_TEAM_NAME: string = "Mestre"
local PLAYER_TEAM_NAME: string = "Jogador"
local RETURN_TO_MENU_ACTION: string = "ReturnToMenu"

local VALID_TEAMS = {
	[MASTER_TEAM_NAME] = true,
	[PLAYER_TEAM_NAME] = true,
}

------------------//VARIABLES
local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local teamSelectEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)

------------------//FUNCTIONS
local function get_team_by_name(teamName: string): Team?
	local team = Teams:FindFirstChild(teamName)

	if team and team:IsA("Team") then
		return team
	end

	return nil
end

local function set_player_team(player: Player, teamName: string): ()
	if not VALID_TEAMS[teamName] then
		return
	end

	local team = get_team_by_name(teamName)

	if not team then
		warn("Time não encontrado: " .. teamName)
		return
	end

	player.Neutral = false
	player.Team = team
end

local function return_player_to_menu(player: Player): ()
	player.Team = nil
	player.Neutral = true
end

local function resolve_request(request: any): (string, string?)
	if typeof(request) == "string" then
		if VALID_TEAMS[request] then
			return "SetRole", request
		end

		if request == RETURN_TO_MENU_ACTION then
			return RETURN_TO_MENU_ACTION, nil
		end
	end

	if typeof(request) == "table" then
		local action = request.Action

		if action == "SetRole" and typeof(request.TeamName) == "string" then
			return "SetRole", request.TeamName
		end

		if action == RETURN_TO_MENU_ACTION then
			return RETURN_TO_MENU_ACTION, nil
		end
	end

	return "", nil
end

local function on_team_request(player: Player, request: any): ()
	local action, teamName = resolve_request(request)

	if action == "SetRole" and teamName then
		set_player_team(player, teamName)
		return
	end

	if action == RETURN_TO_MENU_ACTION then
		return_player_to_menu(player)
	end
end

local function on_player_added(player: Player): ()
	player.Neutral = true
end

------------------//MAIN FUNCTIONS
teamSelectEvent.OnServerEvent:Connect(on_team_request)

------------------//INIT
for _, player in Players:GetPlayers() do
	on_player_added(player)
end

Players.PlayerAdded:Connect(on_player_added)