local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedModules = ReplicatedStorage.Modules
local TableUtils = require(sharedModules.Utils.TableUtils)

local FeedbackMailboxConsts = {
	TAG_NAME = "FeedbackMailbox",
	OPEN_COOLDOWN_DURATION = 2,
}

return TableUtils.setupConsts(FeedbackMailboxConsts)
