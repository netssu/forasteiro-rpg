------------------//SERVICES
local Teams: Teams = game:GetService("Teams")

------------------//CONSTANTS
local MASTER_TEAM_NAME: string = "Mestre"
local PLAYER_TEAM_NAME: string = "Jogador"

local VALID_TEAMS = {
	[MASTER_TEAM_NAME] = true,
	[PLAYER_TEAM_NAME] = true,
}

------------------//VARIABLES
local TeamManager = {}

------------------//FUNCTIONS
local function get_team_by_name(teamName: string): Team?
	local team = Teams:FindFirstChild(teamName)

	if team and team:IsA("Team") then
		return team
	end

	return nil
end

function TeamManager.set_player_team(player: Player, teamName: string): ()
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

function TeamManager.return_player_to_menu(player: Player): ()
	player.Team = nil
	player.Neutral = true
end

return TeamManager