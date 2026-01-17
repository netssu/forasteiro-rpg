local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local sharedModules = ReplicatedStorage.Modules
local UIController = require(ReplicatedStorage.Controllers.UIController)
local Maid = require(sharedModules.Nevermore.Maid)
local Signal = require(sharedModules.Nevermore.Signal)
local TIMEOUT_DURATION = 5

local TimedPrompt = {}
TimedPrompt.__index = TimedPrompt

function TimedPrompt.new(containerTemplate)
	local self = setmetatable({}, TimedPrompt)
	self._containerTemplate = containerTemplate
	self:_setup()
	return self
end

function TimedPrompt:_setup()
	local maid = Maid.new()
	self._maid = maid

	self._container = self._containerTemplate:Clone()
	self._container.Parent = self._containerTemplate.Parent
	maid:GiveTask(self._container)

	self.activated = Signal.new()
	self._startedAt = os.clock()

	maid:GiveTask(RunService.PreRender:Connect(function()
		local elapsed = os.clock() - self._startedAt
		local progress = math.clamp(elapsed / TIMEOUT_DURATION, 0, 1)

		self._container.barContainer.barHolder.bar.Size = UDim2.fromScale(1 - progress, 1)

		if progress == 1 then
			self:Destroy()
			return
		end
	end))

	maid:GiveTask(self._container.YesButton.Activated:Once(function()
		self.activated:Fire()
		task.defer(self.Destroy, self)
	end))

	maid:GiveTask(self._container.CloseButton.Activated:Once(function()
		self:Destroy()
	end))

	-- Initial show
	task.spawn(function()
		UIController.MenuOpenClose(self._container)
	end)
	
	-- Final hide
	maid:GiveTask(function()
		UIController.MenuOpenClose(self._container)
	end)
end

function TimedPrompt:getMaid()
	return self._maid
end

function TimedPrompt:Destroy()
	self._maid:Destroy()
	setmetatable(self, nil)
	table.clear(self)
end

return TimedPrompt
