local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedModules = ReplicatedStorage.Modules
local clientModules = script:FindFirstAncestor("Modules")
local FeedbackMailboxConsts = require("./FeedbackMailboxConsts")
local Maid = require(sharedModules.Nevermore.Maid)
local localPlayer = Players.LocalPlayer

local FeedbackMailbox = {}
FeedbackMailbox.__index = FeedbackMailbox

--[[
    Creates a new object.
]]
function FeedbackMailbox.new(instance)
	local self = setmetatable({}, FeedbackMailbox)
	self._instance = instance
	self:_setup()
	return self
end

--[[
    Sets up the object.
]]
function FeedbackMailbox:_setup()
	local maid = Maid.new()
	self._maid = maid

	maid:GiveTask(self._instance.Hitbox.Touched:Connect(function(hit)
		local character = hit.Parent

		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)

		if not player or player ~= localPlayer then
			return
		end

		-- Prevent multiple hits in quick succession from getting the player stuck.
		if self._lastOpenAt and os.clock() - self._lastOpenAt < FeedbackMailboxConsts.OPEN_COOLDOWN_DURATION then
			return
		end

		self._lastOpenAt = os.clock()
		SocialService:PromptFeedbackSubmissionAsync()
	end))
end

--[[
    Destroys the object.
]]
function FeedbackMailbox:Destroy()
	self._maid:Destroy()
	setmetatable(self, nil)
	table.clear(self)
end

return FeedbackMailbox
