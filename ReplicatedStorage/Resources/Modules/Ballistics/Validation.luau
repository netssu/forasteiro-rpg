local Validation = {}

local Settings = require(script.Parent.Settings)
local Materials = require(script.Parent.Materials)
local Utils = require(script.Parent.Utils)

local CAST_THRESHOLD = Settings.CAST_THRESHOLD -- DISTANCIA ENTRE O CHARACTER QUE ATIROU E O REGISTRO DO INICIO DA BALA
local HIT_THRESHOLD = Settings.HIT_THRESHOLD -- DISTANCIA ENTRE O CHARACTER_HIT POSITION E O RAY POSITION

local MAX_ANGLE = Settings.MAX_ANGLE
local MIN_ANGLE = Settings.MIN_ANGLE
local MIN_DIST = Settings.MIN_DIST  -- DISTANCA MINIMA ONDE O ANGULO É O MAX_ANGLE
local MAX_DIST = Settings.MAX_DIST -- DISTANCIA MAXIMA ONDE O ANGULO É O MIN_ANGLE


local CHARACTER_PENETRATION_LOSS = Settings.CHARACTER_PENETRATION_LOSS

function Validation:AngleHit(Character, Position, Direction, Hit)
	local HitPosition = Hit.Position
	local CharacterPos = Character:GetPivot().Position
	local Distance = (CharacterPos - HitPosition).Magnitude

	local alpha = math.clamp((Distance - MIN_DIST) / (MAX_DIST - MIN_DIST), 0, 1)
	local allowedAngle = MIN_ANGLE + (MAX_ANGLE - MIN_ANGLE) * (1 - alpha)

	local vectorToHit = (HitPosition - Position).Unit
	local dotProduct = Direction.Unit:Dot(vectorToHit)

	local actualAngle = math.deg(math.acos(math.clamp(dotProduct, -1, 1)))

	return actualAngle <= allowedAngle
end

function Validation:CharacterHitPosition(Character: Model, Hit)
	local CharacterHitted = workspace.Entity:FindFirstChild(Hit.CharacterName)
	if not CharacterHitted then
		return true
	end
	
	local distance = (Hit.Position - CharacterHitted:GetPivot().Position).Magnitude
	
	return distance <= HIT_THRESHOLD
end

function Validation:CastPosition(Character, Ballistic)
	local distance = (Ballistic.Origin - Character:GetPivot().Position).Magnitude
	return distance <= CAST_THRESHOLD
end

function Validation:ClampPenetration(Character: Model, Ballistic)
	local Penetration = 0
	local MaxPenetration = Ballistic.MaxPenetration or 1
	
	local PenetrationLoss = 0
	for Index, Hit in Ballistic.Hits do
		Penetration += Utils:CalculatePenetrationLoss(Hit)

		if Penetration > MaxPenetration then
			Ballistic.Hits[Index] = nil
		end
	end
end

function Validation:Validate(Character: Model, Ballistic)
	local result = true
	
	if not Validation:CastPosition(Character, Ballistic) then
		result = false
		print("CAST POSITION INVALID")
	end
	
	Validation:ClampPenetration(Character, Ballistic)
	--if not  then
	--	--result = false
	--	print("PENETRATION INVALID")
	--end


	for _, Hit in Ballistic.Hits do
		--if not Validation:AngleHit(Character, Ballistic.Origin, Ballistic.Direction, Hit) then
		--	result = false
		--	print("ANGLE HIT INVALID")
		--end
		
		if Hit.Type == "Char" then
			if not Validation:CharacterHitPosition(Character, Hit) then
				result = false
				print("CHARACTER HIT INVALID")

			end
		end
	end
	
	return result
end


return Validation