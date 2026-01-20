--// Services //--
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

--// Dependencies //--
local Core = ServerScriptService.Core
local PlayerManager = require(Core.Player.PlayerManager)
local CurrencyManager = require(Core.Player.CurrencyManager)

local Shared = ReplicatedStorage.Shared
local GeneralConfig = require(Shared.Configs.GeneralConfig)
local TycoonTypes = require(ServerScriptService.Types.TycoonTypes)
local Cache = require(Shared.Utilities.Cache)

local SoundModule = require(ReplicatedStorage.Shared.Utilities.SoundModule)


--// Module //--
local Customer = {}
Customer.__index = Customer

export type Customer = typeof(Customer.new())

--// Debug //--
local function DEBUG(...)
	print("[DEBUG]", ...)
end

--// Constructor //--
function Customer.new(BaseObject: TycoonTypes.BaseObject)
	local self = setmetatable({}, Customer)

	self.Base = BaseObject
	self.CustomersFolder = nil

	self.Customers = {}                         -- ordered queue (front at index 1)
	self.QueueCheckpoints = {}
	self.QueueStart = nil
	self.QueueEnd = nil

	self.LastCustomerSpawn = 0
	self.SpawnThread = nil

	return self
end

--// Building Setup //--
function Customer.onSpawnBuilding(self: Customer)
	if not self.Base.Building then
		warn(`[Base {self.Base.ID}][Customer] No building`)
		return
	end

	self.CustomersFolder = self.Base.Building:WaitForChild("Customers")

	local queue = self.Base.Building:WaitForChild("Queue")
	self.QueueStart = queue:WaitForChild("Start")
	self.QueueEnd = queue:WaitForChild("End")

	for i = 1, (GeneralConfig.QUEUE_CAPACITY or 10) do
		local cp = queue:FindFirstChild("QueueCheckpoint" .. i)
		if cp and cp:IsA("Attachment") then
			self.QueueCheckpoints[i] = cp
		else
			break
		end
	end

--[[	DEBUG("Queue setup complete",
		"Checkpoints:", #self.QueueCheckpoints,
		"Start:", self.QueueStart and self.QueueStart.Name,
		"End:", self.QueueEnd and self.QueueEnd.Name
	)]]
end

--// Spawn Thread //--
function Customer.startSpawnThread(self: Customer)
	if self.SpawnThread then return end

	self.SpawnThread = task.spawn(function()
		while self.Base and self.Base.Owned do
			task.wait(0.5)

			local now = tick()

			if now - self.LastCustomerSpawn >= self:_getSpawnCooldown()
				and self:_canSpawnCustomer() then

				self:_spawnCustomer()
				self.LastCustomerSpawn = now
			end
		end
	end)
end

function Customer.stopSpawnThread(self: Customer)
	if self.SpawnThread then
		task.cancel(self.SpawnThread)
		self.SpawnThread = nil
	end
end

--// Spawn Conditions //--
function Customer._canSpawnCustomer(self:Customer)
	local storage = self.Base.Production and self.Base.Production.Storage or {}
	if #storage <= 0 then return false end

	local capacity = self:_getQueueCapacity()
	if #self.Customers >= capacity then return false end

	if #self.Customers >= #storage then return false end

	return true
end

function Customer._getSpawnCooldown(self:Customer)
	local playerObj = self.Base.Owner and PlayerManager.getPlayerObject(self.Base.Owner)
	if not playerObj then
		return GeneralConfig.CUSTOMER_SPAWN_COOLDOWN or 3
	end

	local speed = playerObj:getStat("CustomerSpawnSpeed") or 1
	return (GeneralConfig.CUSTOMER_SPAWN_COOLDOWN or 3) / speed
end

function Customer._getQueueCapacity(self:Customer)
	return GeneralConfig.MAX_CUSTOMERS_QUEUE or (GeneralConfig.QUEUE_CAPACITY or 10)
end

--// Customer Creation //--
function Customer._spawnCustomer(self:Customer)
	local part = Cache.RetrieveFromCache("Customer") or Instance.new("Part")
	part.Name = "Customer"
	part.Size = Vector3.new(2, 5, 2)
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Color = Color3.fromRGB(11, 149, 255)
	part.Parent = self.CustomersFolder

	part:SetAttribute("Base", self.Base.Folder.Name)
	part:SetAttribute("Speed", GeneralConfig.CUSTOMER_SPEED or 10)

	-- spawn at start
	part.Position = self.QueueStart.WorldPosition

	-- find back-most free spot (the smallest available index)
	local pos = self:_getNextQueueSpot()
	part:SetAttribute("QueuePosition", pos)
	part:SetAttribute("CurrentCheckpoint", 0)

	local info: TycoonTypes.CustomerData = {
		Instance = part,
		QueuePosition = pos,
		CurrentCheckpoint = 0,
		PurchaseComplete = false,
	}

	table.insert(self.Customers, info)

	-- Move to assigned slot immediately
	self:_moveToSlot(info)

	CollectionService:AddTag(part, "Customer")

--[[	DEBUG("Spawned customer",
		"QueuePosition:", pos,
		"CustomersInQueue:", #self.Customers
	)]]
end

--// Queue Slot Logic //--
function Customer._getNextQueueSpot(self:Customer)
	local used = {}
	for _, cust in self.Customers do
		used[cust.QueuePosition] = true
	end

	for i = 1, self:_getQueueCapacity() do
		if not used[i] then
			return i
		end
	end

	return self:_getQueueCapacity()
end

--// Movement //--
function Customer._moveToSlot(self:Customer, data)
	local checkpoint = self.QueueCheckpoints[data.QueuePosition]
	if not checkpoint then
		warn(`Base {self.Base.ID}][Customer}] Missing checkpoint for QueuePosition: `, data.QueuePosition)
		return
	end

	local target = checkpoint.WorldPosition
	local travel = self:_walkTime(self.QueueStart.WorldPosition, target)

	data.Instance:SetAttribute("Exiting", nil) -- ensure not marked exiting during queue movement
	data.Instance:SetAttribute("GoalPosition", target)

--[[	DEBUG("Set move to slot",
		"QueuePosition:", data.QueuePosition)
]]
	task.delay(travel, function()
		if not data.Instance or not data.Instance.Parent then return end

		data.CurrentCheckpoint = data.QueuePosition
		data.Instance:SetAttribute("CurrentCheckpoint", data.QueuePosition)

		-- Front-most customer at 1 initiates purchase
		if data.QueuePosition == 1 then
			self:_handlePurchase(data)
		end
	end)
end

--// Purchase Flow //--
function Customer._handlePurchase(self:Customer, data)
	local storage = self.Base.Production and self.Base.Production.Storage or {}
	if #storage == 0 then
		--DEBUG("Front customer found no storage, exiting")
		self:_exitQueue(data)
		return
	end

	--DEBUG("Front customer purchasing...")

	task.wait(GeneralConfig.CUSTOMER_PURCHASE_DELAY or 2)

	local item = self.Base.Production:removeItemFromStorage(1)
	if item and self.Base.Owner then
		SoundModule.PlayForPlayers(self.Base.Owner, "Selling Item to NPC")
		CurrencyManager.grantEarnings(self.Base.Owner, item.Value, true)
	end

	data.PurchaseComplete = true

	self:_exitQueue(data)
end

--// Exit //--
function Customer._exitQueue(self:Customer, data)
	if not self.QueueEnd then return end
	
	local endPos = self.QueueEnd.WorldPosition
	local currentPos = self.QueueCheckpoints[data.QueuePosition] and self.QueueCheckpoints[data.QueuePosition].WorldPosition or data.Instance.Position
	local travel = self:_walkTime(currentPos, endPos)

	-- Mark exiting and set final goal
	data.Instance:SetAttribute("Exiting", true)
	data.Instance:SetAttribute("GoalPosition", endPos)

--[[	DEBUG("Customer exiting",
		"FromQueuePosition:", data.QueuePosition,
		"TravelTime:", travel
	)]]

	-- Compact queue AFTER the exiting customer has begun moving to End
	-- But do not remove exiting customer from array until they reach End
	-- Instead, mark a flag and physically remove after travel delay.
	data._Exiting = true

	-- Move others forward
	self:_compactQueue(data)

	-- When they reach End, clean up the server-side part and cache it
	task.delay(travel, function()
		if data.Instance and data.Instance.Parent then
			-- Remove from our queue list
			self:_remove(data)

			-- Clean attributes before caching
			data.Instance:SetAttribute("GoalPosition", nil)
			data.Instance:SetAttribute("CurrentCheckpoint", nil)
			data.Instance:SetAttribute("QueuePosition", nil)
			data.Instance:SetAttribute("Exiting", nil)

			-- Return to server cache
			Cache.AddToCache(data.Instance)

			-- Also remove the tag so client cleanup runs
			pcall(function()
				CollectionService:RemoveTag(data.Instance, "Customer")
			end)
		end
	end)
end

--// Queue Cleanup //--
function Customer._remove(self:Customer, data)
	local i = table.find(self.Customers, data)
	if i then
		table.remove(self.Customers, i)
		--DEBUG("Removed customer from queue", "Remaining:", #self.Customers)
	end
end

function Customer._compactQueue(self:Customer, exitingData)
	-- Shift all non-exiting customers forward by 1 (but not below 1)
	for _, cust in ipairs(self.Customers) do
		if cust ~= exitingData then
			local newPos = math.max(1, cust.QueuePosition - 1)
			if newPos ~= cust.QueuePosition then
				cust.QueuePosition = newPos
				-- announce their new slot
				self:_moveToSlot(cust)
				--DEBUG("Compacted customer", "NewQueuePosition:", newPos)
			end
		end
	end
end

--// Utility //--
function Customer._walkTime(self:Customer, from, to)
	local speed = GeneralConfig.CUSTOMER_SPEED or 10
	return (to - from).Magnitude / speed
end

--// Cleanup //--
function Customer.cleanup(self:Customer)
	self:stopSpawnThread()

	for _, data in self.Customers do
		if data.Instance then
			data.Instance:Destroy()
		end
	end

	table.clear(self.Customers)
	table.clear(self.QueueCheckpoints)

	self.CustomersFolder = nil
	self.QueueStart = nil
	self.QueueEnd = nil
	self.LastCustomerSpawn = 0
end

return Customer