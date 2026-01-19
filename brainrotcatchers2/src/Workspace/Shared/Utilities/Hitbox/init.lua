local HitboxModule = {
	Visualizer = true
}
HitboxModule.__index = HitboxModule

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local GoodSignal = require(script.GoodSignal)
local Types = require(script.Types)

local VisualizerLife = 1

local function _getUniqueHumanoids(self: Types.Hitbox, castResult: {BasePart})
	local uniqueHumanoids = {}
	
	for _, part in castResult do
		local character = part:FindFirstAncestorOfClass("Model")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or table.find(uniqueHumanoids, humanoid) then continue end
		
		uniqueHumanoids[part] = humanoid
	end
	
	return uniqueHumanoids
end

function HitboxModule.new(): Types.Hitbox
	local self = setmetatable({}, HitboxModule)
	self._Boxes = {}
	
	self.HitList = {}
	
	self.Touched = GoodSignal.new()
	
	self.VisualizerTransparency = .9
	self.VisualizerMaterial = Enum.Material.ForceField
	self.VisualizerHitColor = Color3.new(0, 1, 0)
	self.VisualizerColor = Color3.new(1, 0, 0)
	self.Visualizer = HitboxModule.Visualizer
	
	self.DetectionMode = "Default"
	self.OverlapParams = OverlapParams.new()
	
	self.PredictionVector = Vector3.new(1, 0.25, 1)
	self.PredictionTime = .25
	self.Prediction = true
	self.FollowPart = nil
	
	self.Size = Vector3.one
	self.Shape = Enum.PartType.Block
	self.Offset = CFrame.new()
	
	self.Duration = 1
	self.Rate = 5
	
	return self
end

function HitboxModule:Start()
	task.spawn(function()
		for i = 1, self.Rate do
			if self._Stopped then break end
			
			self:_visualizer()
			self:_cast()
			
			task.wait(self.Duration / self.Rate)
		end
		
		self:Stop()
	end)
end

function HitboxModule:Stop()
	if self.Touched then
		self.Touched:DisconnectAll()
	end
	
	self._Stopped = true
end

function HitboxModule:Destroy()
	self:Stop()
end

function HitboxModule._getPredictionVelocity(self: Types.Hitbox): CFrame
	local followPart = self.FollowPart
	if not followPart then return CFrame.new() end
	if not self.Prediction or self.PredictionTime <= 0 then return followPart.CFrame end
	
	local velocity = followPart.AssemblyLinearVelocity * self.PredictionVector * self.PredictionTime
	local position = followPart.Position + velocity
	local cframe = CFrame.new(position) * (followPart.CFrame - followPart.Position)
	
	return cframe
end

function HitboxModule._getCFrame(self: Types.Hitbox): CFrame
	return self:_getPredictionVelocity() * self.Offset
end

function HitboxModule._getCastResult(self: Types.Hitbox): {BasePart}?
	local cframe = self:_getCFrame()
	
	local overlapParams = self.OverlapParams
	local shape = self.Shape
	local size = self.Size
	
	if shape == Enum.PartType.Block then
		return workspace:GetPartBoundsInBox(cframe, size, overlapParams)
	elseif shape == Enum.PartType.Ball then
		return workspace:GetPartBoundsInRadius(cframe.Position, size, overlapParams)
	else
		error("Part type: " .. shape .. " ins't an Block or an Ball Hitbox")
	end
end

function HitboxModule._visualizer(self: Types.Hitbox)
	if not self.Visualizer then return end

	local cf = self:_getCFrame()
	local shape = self.Shape
	local size = self.Size

	local adornment
	if shape == Enum.PartType.Block then
		adornment = Instance.new("BoxHandleAdornment")
		adornment.Size = size
	elseif shape == Enum.PartType.Ball then
		adornment = Instance.new("SphereHandleAdornment")
		adornment.Radius = math.max(size.X, size.Y, size.Z) / 2
	else
		error("Unsupported shape for adornment visualizer")
	end

	adornment.Name = "HitboxVisualizer"
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = cf
	adornment.Color3 = self.VisualizerColor
	adornment.Transparency = self.VisualizerTransparency
	adornment.Visible = true
	adornment.ZIndex = 0
	adornment.AlwaysOnTop = false
	adornment.Parent = workspace.Hitboxes

	Debris:AddItem(adornment, VisualizerLife)

	table.insert(self._Boxes, adornment)
end

function HitboxModule._cast(self: Types.Hitbox)
	local CastResult = self:_getCastResult()
	local DetectionMode = self.DetectionMode
	
	for i, Part in CastResult do
		local Character = Part:FindFirstAncestorOfClass("Model")
		local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		
		if DetectionMode ~= "HitParts" then
			if not Humanoid then continue end
		end
		
		if DetectionMode == "Default" then
			if table.find(self.HitList, Humanoid) then continue end
			table.insert(self.HitList, Humanoid)
				
			self.Touched:Fire(Part, Humanoid)
		elseif DetectionMode == "ConstantDetection" then
			self.Touched:Fire(Part, Humanoid)
		elseif DetectionMode == "HitOnce" then
			local uniqueHumanoids = _getUniqueHumanoids(self, CastResult)
		
			for part, humanoid in uniqueHumanoids do
				if table.find(self.HitList, humanoid) then continue end
				table.insert(self.HitList, humanoid)

				self.Touched:Fire(part, humanoid)
			end
			
			self:Destroy()
		elseif DetectionMode == "HitOne" then
			self.Touched:Fire(Part, Humanoid)

			self:Destroy()
		elseif DetectionMode == "HitParts" then
			self.Touched:Fire(Part, nil)
		end
	end
end

return HitboxModule
