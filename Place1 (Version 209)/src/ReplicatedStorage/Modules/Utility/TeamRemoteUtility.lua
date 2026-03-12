------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//MODULES
local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local dictionaryFolder: Folder = modulesFolder:WaitForChild("Dictionary")
local TeamDictionary = require(dictionaryFolder:WaitForChild("TeamDictionary"))

------------------//VARIABLES
local cache: {[string]: Instance} = {}

------------------//FUNCTIONS
local function get_assets_folder(): Folder
	if cache.assetsFolder then
		return cache.assetsFolder :: Folder
	end

	local assetsFolder = ReplicatedStorage:WaitForChild(TeamDictionary.ASSETS_FOLDER_NAME) :: Folder
	cache.assetsFolder = assetsFolder
	return assetsFolder
end

local function get_remotes_folder(): Folder
	if cache.remotesFolder then
		return cache.remotesFolder :: Folder
	end

	local remotesFolder = get_assets_folder():WaitForChild(TeamDictionary.REMOTES_FOLDER_NAME) :: Folder
	cache.remotesFolder = remotesFolder
	return remotesFolder
end

local function get_team_select_event(): RemoteEvent
	if cache.teamSelectEvent then
		return cache.teamSelectEvent :: RemoteEvent
	end

	local remote = get_remotes_folder():WaitForChild(TeamDictionary.TEAM_SELECT_EVENT_NAME) :: RemoteEvent
	cache.teamSelectEvent = remote
	return remote
end

------------------//MAIN FUNCTIONS
local TeamRemoteUtility = {}

function TeamRemoteUtility.get_team_select_event(): RemoteEvent
	return get_team_select_event()
end

return TeamRemoteUtility
