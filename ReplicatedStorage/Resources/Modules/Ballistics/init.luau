local Ballistics = {}
Ballistics.__index = Ballistics

local Cast = require(script.Cast)
local Materials = require(script.Materials)
local Utils = require(script.Utils)
local Settings = require(script.Settings)

local CHARACTER_PENETRATION_LOSS = Settings.CHARACTER_PENETRATION_LOSS

function Ballistics.new(Origin: Vector3, Direction: Vector3, MaxPenetration: number?)
	return setmetatable({
		Origin = Origin,
		Direction = Direction,
		MaxPenetration = MaxPenetration or 1,
		Penetration = 0,
		Characters = {},
		Instances = {},
		Hits = {}
	}, Ballistics)
end


function Ballistics:Fire(Params: RaycastParams)
	Cast:Fire(self, Params)
end

function Ballistics:GetPacket()
	local Packet = Utils:GetPacket(self)
	return Packet
end

function Ballistics:Hit(Result: RaycastResult): boolean -- if continue or stop the bullet
	local hit = Result.Instance
	local normal = Result.Normal
	local position = Result.Position
	
	local HitObject = {
		Type = "";
		Position = position;
		Normal = normal;
		Instance = hit;		
	}
	
	table.insert(self.Instances, hit)
	
	local thickness = Utils:GetThickness(hit, normal)

	local PenetrationLoss = 0
		
	if hit:HasTag("Glass") then
		HitObject.Type = "Glass"
		--PenetrationLoss = Materials.Glass.PLPS * 0.05 * thickness
	elseif hit:HasTag("ExplosiveBarrel") then
		HitObject.Type = "Barrel"
		HitObject.BarrelID = hit:GetAttribute("ID")
	else 
		local isCharacter = false
		local characterModel = hit:FindFirstAncestorOfClass("Model")
		if characterModel and characterModel:IsDescendantOf(workspace.Entity) then
			local humanoidHit = characterModel:FindFirstChildWhichIsA("Humanoid")
			if humanoidHit then

				local isPlayer = game.Players:GetPlayerFromCharacter(characterModel) ~= nil
				local isHeadshot = (hit.Name == "Head")
				isCharacter = true
				HitObject.Type = "Char"
				HitObject.CharacterName = characterModel.Name
				table.insert(self.Characters, characterModel)

				HitObject.IsHeadshot = isHeadshot
			end
		end
		
		if not isCharacter then
			HitObject.Type = "Object"
			HitObject.Material = Materials[hit.Material.Name].ID
			HitObject.Thickness = thickness
		end
	end
	
	PenetrationLoss = Utils:CalculatePenetrationLoss(HitObject)
	
	self.Hits[#self.Hits + 1] = HitObject
	
	self.Penetration += PenetrationLoss

	if self.Penetration >= self.MaxPenetration then
		return false
	end
	
	return true	
end

function Ballistics:Destroy()
	for k, v in self do
		self[k] = nil
	end
	self = nil
end


return Ballistics