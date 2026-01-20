--// Services //--
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Variables //--
local Caches = ReplicatedStorage.Caches
local CacheTable = {} -- Stores instances in groups by name 

--// Helpers //--
function CreateCacheGroup(name:string)
	CacheTable[name] = CacheTable[name] or {}
	return CacheTable[name]
end

--// Main //--
local module = {}

function module.AddToCache(obj:Instance)
	local CacheGroup = CacheTable[obj.Name]
	local CacheInstance = CacheGroup and CacheGroup[obj]
	-- Validation
	obj.Parent = nil
	if CacheInstance then
		print("Instance is already cached")
		return
	end
	
	CacheGroup = CacheGroup or CreateCacheGroup(obj.Name)
	
	CacheGroup[obj] = true

	-- auto cleanup after disuse logic?
end

function module.RetrieveFromCache(name:string)
	local CacheGroup = CacheTable[name]
	-- Validation
	if not CacheGroup then
--		print("Cache group does not exist")
		return nil
	end
	
	local CacheInstance = table.remove(CacheGroup,1)
	-- Validation
	if not CacheInstance then
--		print("Cache group is empty")
		return nil
	end
	
	return CacheInstance
end

return module
