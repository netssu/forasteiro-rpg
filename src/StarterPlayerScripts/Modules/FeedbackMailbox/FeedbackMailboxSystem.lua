local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedModules = ReplicatedStorage.Modules
local clientModules = script:FindFirstAncestor("Modules")
local Binder = require(sharedModules.Nevermore.Binder)
local FeedbackMailbox = require("./FeedbackMailbox")
local FeedbackMailboxConsts = require("./FeedbackMailboxConsts")

local FeedbackMailboxSystem = {}

function FeedbackMailboxSystem.init()
	local binder = Binder.new(FeedbackMailboxConsts.TAG_NAME, FeedbackMailbox)
	binder:Start()
end

return FeedbackMailboxSystem
