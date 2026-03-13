------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//MODULES
local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local dictionaryFolder: Folder = modulesFolder:WaitForChild("Dictionary")
local MovementDictionary = require(dictionaryFolder:WaitForChild("MovementDictionary"))

------------------//VARIABLES
local cache: {[string]: Instance} = {}

------------------//FUNCTIONS
local function get_assets_folder(): Folder
	if cache.assetsFolder then
		return cache.assetsFolder :: Folder
	end

	local assetsFolder = ReplicatedStorage:WaitForChild(MovementDictionary.ASSETS_FOLDER_NAME) :: Folder
	cache.assetsFolder = assetsFolder
	return assetsFolder
end

local function get_remotes_folder(): Folder
	if cache.remotesFolder then
		return cache.remotesFolder :: Folder
	end

	local remotesFolder = get_assets_folder():WaitForChild(MovementDictionary.REMOTES_FOLDER_NAME) :: Folder
	cache.remotesFolder = remotesFolder
	return remotesFolder
end

local function get_remote(remoteName: string): RemoteEvent
	local key = "remote_" .. remoteName
	if cache[key] then
		return cache[key] :: RemoteEvent
	end

	local remote = get_remotes_folder():WaitForChild(remoteName) :: RemoteEvent
	cache[key] = remote
	return remote
end

------------------//MAIN FUNCTIONS
local MovementRemoteUtility = {}

function MovementRemoteUtility.get_movement_remote(): RemoteEvent
	return get_remote(MovementDictionary.MOVEMENT_EVENT_NAME)
end

function MovementRemoteUtility.get_turn_remote(): RemoteEvent
	return get_remote(MovementDictionary.TURN_EVENT_NAME)
end

return MovementRemoteUtility
