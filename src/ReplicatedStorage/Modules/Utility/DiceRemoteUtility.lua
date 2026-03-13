------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//MODULES
local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local dictionaryFolder: Folder = modulesFolder:WaitForChild("Dictionary")
local DiceDictionary = require(dictionaryFolder:WaitForChild("DiceDictionary"))

------------------//VARIABLES
local cache: {[string]: Instance} = {}

------------------//FUNCTIONS
local function get_assets_folder(): Folder
	if cache.assetsFolder then
		return cache.assetsFolder :: Folder
	end

	local assetsFolder = ReplicatedStorage:WaitForChild(DiceDictionary.ASSETS_FOLDER_NAME) :: Folder
	cache.assetsFolder = assetsFolder
	return assetsFolder
end

local function get_remotes_folder(): Folder
	if cache.remotesFolder then
		return cache.remotesFolder :: Folder
	end

	local remotesFolder = get_assets_folder():WaitForChild(DiceDictionary.REMOTES_FOLDER_NAME) :: Folder
	cache.remotesFolder = remotesFolder
	return remotesFolder
end

local function get_dice_event(): RemoteEvent
	if cache.diceEvent then
		return cache.diceEvent :: RemoteEvent
	end

	local remote = get_remotes_folder():WaitForChild(DiceDictionary.DICE_EVENT_NAME) :: RemoteEvent
	cache.diceEvent = remote
	return remote
end

------------------//MAIN FUNCTIONS
local DiceRemoteUtility = {}

function DiceRemoteUtility.get_dice_event(): RemoteEvent
	return get_dice_event()
end

return DiceRemoteUtility
