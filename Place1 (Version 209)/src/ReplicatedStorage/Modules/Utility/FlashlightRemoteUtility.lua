------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//MODULES
local dictionaryFolder: Folder = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Dictionary")
local FlashlightDictionary = require(dictionaryFolder:WaitForChild("FlashlightDictionary"))

------------------//VARIABLES
local cache: {[string]: Instance} = {}

------------------//FUNCTIONS
local function get_assets_folder(): Folder
	if cache.assetsFolder then
		return cache.assetsFolder :: Folder
	end

	local assetsFolder = ReplicatedStorage:WaitForChild(FlashlightDictionary.ASSETS_FOLDER_NAME) :: Folder
	cache.assetsFolder = assetsFolder

	return assetsFolder
end

local function get_remotes_folder(): Folder
	if cache.remotesFolder then
		return cache.remotesFolder :: Folder
	end

	local remotesFolder = get_assets_folder():WaitForChild(FlashlightDictionary.REMOTES_FOLDER_NAME) :: Folder
	cache.remotesFolder = remotesFolder

	return remotesFolder
end

local function ensure_remote_event(remoteName: string): RemoteEvent
	local key = "remote_" .. remoteName
	if cache[key] then
		return cache[key] :: RemoteEvent
	end

	local remotesFolder = get_remotes_folder()
	local remote = remotesFolder:FindFirstChild(remoteName)

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = remotesFolder
	end

	cache[key] = remote
	return remote :: RemoteEvent
end

local function ensure_unreliable_remote_event(remoteName: string): UnreliableRemoteEvent
	local key = "unreliable_" .. remoteName
	if cache[key] then
		return cache[key] :: UnreliableRemoteEvent
	end

	local remotesFolder = get_remotes_folder()
	local remote = remotesFolder:FindFirstChild(remoteName)

	if not remote then
		remote = Instance.new("UnreliableRemoteEvent")
		remote.Name = remoteName
		remote.Parent = remotesFolder
	end

	cache[key] = remote
	return remote :: UnreliableRemoteEvent
end

local function get_remote_event(remoteName: string): RemoteEvent
	local key = "remote_" .. remoteName
	if cache[key] then
		return cache[key] :: RemoteEvent
	end

	local remote = get_remotes_folder():WaitForChild(remoteName)
	cache[key] = remote

	return remote :: RemoteEvent
end

local function get_unreliable_remote_event(remoteName: string): UnreliableRemoteEvent
	local key = "unreliable_" .. remoteName
	if cache[key] then
		return cache[key] :: UnreliableRemoteEvent
	end

	local remote = get_remotes_folder():WaitForChild(remoteName)
	cache[key] = remote

	return remote :: UnreliableRemoteEvent
end

------------------//MAIN FUNCTIONS
local FlashlightRemoteUtility = {}

function FlashlightRemoteUtility.get_server_remotes(): (RemoteEvent, UnreliableRemoteEvent)
	local toggleRemote = ensure_remote_event(FlashlightDictionary.FLASHLIGHT_EVENT_NAME)
	local updateRemote = ensure_unreliable_remote_event(FlashlightDictionary.FLASHLIGHT_UPDATE_EVENT_NAME)

	return toggleRemote, updateRemote
end

function FlashlightRemoteUtility.get_client_remotes(): (RemoteEvent, UnreliableRemoteEvent)
	local toggleRemote = get_remote_event(FlashlightDictionary.FLASHLIGHT_EVENT_NAME)
	local updateRemote = get_unreliable_remote_event(FlashlightDictionary.FLASHLIGHT_UPDATE_EVENT_NAME)

	return toggleRemote, updateRemote
end

return FlashlightRemoteUtility
