--\\ Services
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
--\\ Locals
local TagsFunctions = require(script:WaitForChild("TagsFunctions"))
local HelperModule = require(script:WaitForChild("HelperModule"))
--\\ Variables
local HitboxModule = {}
HitboxModule.__index = HitboxModule

local ActiveHitboxes = {}
local heartbeatConnected = false
--\\ Functions

local function CreateHitbox(data : HitboxData): HitboxData
	if not data then warn("[Hitbox] Data Invalid") return end

	local self = setmetatable({}, HitboxModule)

	self.Size = data.Size
	self.CFrame = data.CFrame
	self.Type = data.Type or "Unic"
	self.Duration = data.Duration or 1
	self.IgnoreList = data.IgnoreList or {}
	self.Callback = data.Callback
	self.StartTime = os.clock()
	self.Visualize = data.Visualize or false

	table.insert(ActiveHitboxes, self)
	HitboxModule.ConnectHeartbeat()

	return self
end

function HitboxModule:GetParts()
	if self.Visualize then
		HelperModule.ShowHitbox(self.CFrame,self.Size)
	end
	
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = workspace:GetDescendants()

	local parts = workspace:GetPartBoundsInBox(self.CFrame, self.Size, overlapParams)

	if #parts > 0 then
		self:ProcessHits(parts)
	end
end

function HitboxModule:ProcessHits(parts)
	local hits = {}
	local currentTime = os.clock()

	for _, part in ipairs(parts) do
		local target = part.Parent

		for tag, func in pairs(TagsFunctions) do
			if (CollectionService:HasTag(part, tag) or CollectionService:HasTag(target, tag)) and not self.IgnoreList[target] then
				func(target)
				self.IgnoreList[target] = true
			end
		end

		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if typeof(self.Type) == "string" and self.Type == "Unic" then
				if not self.IgnoreList[target] then
					self.IgnoreList[target] = currentTime
					table.insert(hits, target)
				end

			elseif typeof(self.Type) == "table" and self.Type[1] == "Constant" then
				local interval = self.Type[2] or 1
				if (currentTime - (self.IgnoreList[target] or 0)) >= interval then
					self.IgnoreList[target] = currentTime
					table.insert(hits, target)
				end
			end
		end
	end

	if #hits > 0 then
		self.Callback(hits)
	end
end

function HitboxModule:Start()
	self.Connection = RunService.Heartbeat:Connect(function()
		if os.clock() <= self.StartTime + self.Duration then
			self:GetParts()
		else
			self:Destroy()
		end
	end)
end

function HitboxModule:Destroy()
	for i, hb in ipairs(ActiveHitboxes) do
		if hb == self then
			table.remove(ActiveHitboxes, i)
			break
		end
	end
end

local function ConnectHeartbeat()
	if heartbeatConnected then return end
	heartbeatConnected = true

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for i = #ActiveHitboxes, 1, -1 do
			local hitbox = ActiveHitboxes[i]
			if now <= hitbox.StartTime + hitbox.Duration then
				hitbox:GetParts()
			else
				table.remove(ActiveHitboxes, i)
			end
		end
	end)
end

--\\ Start
HitboxModule.CreateHitbox = CreateHitbox
HitboxModule.ConnectHeartbeat = ConnectHeartbeat

--\\ Export Types
type UnicType = "Unic"
type ConstantType = { Mode: "Constant", Interval: number }
type HitboxType = UnicType | ConstantType

export type HitboxData = {
	Size: Vector3,
	CFrame: CFrame,
	Type: HitboxType,
	Duration: number,
	IgnoreList: { [Instance]: Instance }?,
	Callback: (Instance) -> (),
}

--\\ End
return HitboxModule