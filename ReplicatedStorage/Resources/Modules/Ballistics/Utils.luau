local Utils = {}

local Settings = require(script.Parent.Settings)
local Materials = require(script.Parent.Materials)
local CHARACTER_PENETRATION_LOSS = Settings.CHARACTER_PENETRATION_LOSS
local RunService = game:GetService("RunService")
local Player = game.Players.LocalPlayer

function Utils:GetThickness(Part: BasePart, Normal: Vector3)
	local cf = Part.CFrame
	local size = Part.Size

	local localNormal = cf:VectorToObjectSpace(Normal)
	local absN = Vector3.new(math.abs(localNormal.X), math.abs(localNormal.Y), math.abs(localNormal.Z))

	local thickness
	if absN.X > absN.Y and absN.X > absN.Z then
		thickness = size.X
	elseif absN.Y > absN.Z then
		thickness = size.Y
	else
		thickness = size.Z
	end
	
	return thickness
end

function Utils:GetExitOrigin(lastHit, direction)
	local unit = direction.Unit
	local epsilon = 0.01
	local start = lastHit.Position + unit * epsilon

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { lastHit.Instance }
	params.IgnoreWater = true

	local exit = workspace:Raycast(start, unit * 1000, params)

	if exit then
		print("EXIT HIT")
		return exit.Position + unit * epsilon
	end

	return lastHit.Position + unit * epsilon
end

function Utils:CalculatePenetrationLoss(Hit)
	local PenetrationLoss = 0
	if not Hit.Instance then
		return 0
	end
	
	Hit.Thickness = Hit.Thickness or Utils:GetThickness(Hit.Instance, Hit.Normal)

	if Hit.Type == "Char" then
		PenetrationLoss = CHARACTER_PENETRATION_LOSS
	elseif Hit.Type == "Glass" then
		--PenetrationLoss = Materials.Glass.PLPS * 0.05 * Hit.Thickness
	elseif Hit.Type == "Object" then
		PenetrationLoss = Materials[Hit.Instance.Material.Name].PLPS * Hit.Thickness
	elseif Hit.Type == "Barrel" then
		PenetrationLoss = Materials.Plastic.PLPS * Hit.Thickness
	end
	
	return PenetrationLoss
end

function Utils:ConvertPacketToServer(Ballistic)
	local NewBallistic = {
		Origin = Ballistic[1],
		Direction = Ballistic[2],
	}
	local Hits = {}
	for Index, Hit in Ballistic[3] do
		local NewHit = {
			Type = Settings.TYPES[Hit[1]],
			Position = Hit[2],
			Normal = Hit[3],
		}
		


		if NewHit.Type == "Char" then
			NewHit.CharacterName = Hit[4]
			NewHit.Headshot = Hit[5]
		elseif NewHit.Type == "Glass" then
			NewHit.Instance = Hit[4]
		elseif NewHit.Type == "Object" then
			NewHit.Instance = Hit[4]
		elseif NewHit.Type == "Barrel" then
			NewHit.BarrelID = Hit[4]
		end
		
		
		if NewHit.Instance then
			NewHit.Thickness = Utils:GetThickness(NewHit.Instance, NewHit.Normal)
		end
		Hits[Index] = NewHit
	end

	
	NewBallistic.Hits = Hits
	
	return NewBallistic
end

function Utils:GetPacket(Ballistic)
	local Hits = {}

	for Index, Hit in Ballistic.Hits do

		local NewHit = {
			[1] = table.find(Settings.TYPES, Hit.Type),
			[2] = Hit.Position,
			[3] = Hit.Normal,
		}


		if Hit.Type == "Char" then
			NewHit[4] = Hit.CharacterName
			NewHit[5] = Hit.Headshot
		elseif Hit.Type == "Glass" then
			NewHit[4] = Hit.Instance
		elseif Hit.Type == "Barrel" then
			NewHit[4] = Hit.Instance:GetAttribute("ID")
		elseif Hit.Type == "Object" then
			NewHit[4] = Hit.Instance
		end

		Hits[Index] = NewHit
	end

	return {
		[1] = Ballistic.Origin,
		[2] = Ballistic.Direction,
		[3] = Hits,
	}
end

return Utils