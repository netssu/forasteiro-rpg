------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//MODULES
local replicatedModulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local dictionaryFolder: Folder = replicatedModulesFolder:WaitForChild("Dictionary")
local utilityFolder: Folder = replicatedModulesFolder:WaitForChild("Utility")
local TeamDictionary = require(dictionaryFolder:WaitForChild("TeamDictionary"))
local TeamRemoteUtility = require(utilityFolder:WaitForChild("TeamRemoteUtility"))

local serverModulesFolder: Folder = ServerStorage:WaitForChild("Modules")
local gameFolder: Folder = serverModulesFolder:WaitForChild("Game")
local TeamManager = require(gameFolder:WaitForChild("TeamManager"))

------------------//FUNCTIONS
local function resolve_request(request: any): (string, string?)
	if typeof(request) == "string" then
		if TeamDictionary.VALID_TEAMS[request] then
			return TeamDictionary.SET_ROLE_ACTION, request
		end

		if request == TeamDictionary.RETURN_TO_MENU_ACTION then
			return TeamDictionary.RETURN_TO_MENU_ACTION, nil
		end
	end

	if typeof(request) == "table" then
		local action = request.Action

		if action == TeamDictionary.SET_ROLE_ACTION and typeof(request.TeamName) == "string" then
			return TeamDictionary.SET_ROLE_ACTION, request.TeamName
		end

		if action == TeamDictionary.RETURN_TO_MENU_ACTION then
			return TeamDictionary.RETURN_TO_MENU_ACTION, nil
		end
	end

	return "", nil
end

local function on_team_request(player: Player, request: any): ()
	local action, teamName = resolve_request(request)
	if action == TeamDictionary.SET_ROLE_ACTION and teamName then
		TeamManager.set_player_team(player, teamName)
		return
	end

	if action == TeamDictionary.RETURN_TO_MENU_ACTION then
		TeamManager.return_player_to_menu(player)
	end
end

local function on_player_added(player: Player): ()
	player.Neutral = true
end

------------------//MAIN FUNCTIONS
local TeamServerController = {}

function TeamServerController.connect(): ()
	local teamSelectEvent = TeamRemoteUtility.get_team_select_event()
	teamSelectEvent.OnServerEvent:Connect(on_team_request)

	for _, player in Players:GetPlayers() do
		on_player_added(player)
	end

	Players.PlayerAdded:Connect(on_player_added)
end

return TeamServerController
