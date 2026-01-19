local Cast = {}


local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Utils = require(script.Parent.Utils)

local Settings = require(script.Parent.Settings)
local DEBUG_RAYS_DURATION = Settings.DEBUG_RAYS_DURATION
local DEBUG_RAYS = Settings.DEBUG_RAYS
local CollectionService = game:GetService("CollectionService")

function Cast:Raycast(Origin: Vector3, Direction: Vector3, Params: RaycastParams)
	local result = workspace:Raycast(Origin, Direction, Params)
	
	local DEBUG_RAYS = DEBUG_RAYS 
	
	local debugPart 
	if DEBUG_RAYS then
		debugPart = Instance.new("Part")
		debugPart.Anchored = true
		debugPart.CanCollide = false
		debugPart:AddTag("DEBUG")
		debugPart.Material = Enum.Material.Neon
		debugPart.Parent = workspace
	end

	if result then
		if debugPart then
			local length = (result.Position - Origin).Magnitude
			debugPart.Color = Color3.fromRGB(0, 255, 0)
			debugPart.Size = Vector3.new(0.05, 0.05, length)
			debugPart.CFrame = CFrame.lookAt(Origin, result.Position) * CFrame.new(0, 0, -length / 2)
		end
	else
		if debugPart then
			local length = Direction.Magnitude
			debugPart.Color = Color3.fromRGB(255, 0, 0)
			debugPart.Size = Vector3.new(0.05, 0.05, length)
			debugPart.CFrame = CFrame.lookAt(Origin, Origin + Direction) * CFrame.new(0, 0, -length / 2)
		end
	end

	if debugPart and DEBUG_RAYS_DURATION then
		Debris:AddItem(debugPart, DEBUG_RAYS_DURATION)
	end

	return result
end


-- [[ SE FOR CHAMAR POR UMA IA NO SERVIDOR CRIE E FILTRE O CORPO DA IA NO Params ]]
function Cast:FilteredCast(Ballistic, Params: RaycastParams)
	local Player = game.Players.LocalPlayer
	
	local character
	if RunService:IsClient() then
		character = Player.Character
		if not character then return end
	end
	
	local Origin = Ballistic.Origin
	local Direction = Ballistic.Direction
	
	if #Ballistic.Hits > 0 then
		local lastHit = Ballistic.Hits[#Ballistic.Hits]
		Origin = Utils:GetExitOrigin(lastHit, Ballistic.Direction)
	end

	local maxIterations = 10
	local ignored = {character, table.unpack(Ballistic.Characters), table.unpack(Ballistic.Instances)}
	
	if RunService:IsClient() then
		local CLIENT_CONTAINER = workspace:FindFirstChild("_CLIENT_CONTAINER")
		table.insert(ignored, CLIENT_CONTAINER)
	end

	local result

	local params = Params or RaycastParams.new()
	params.FilterDescendantsInstances = {table.unpack(params.FilterDescendantsInstances), table.unpack(ignored), table.unpack(CollectionService:GetTagged("DEBUG"))}

	for i = 1, maxIterations do

		result = Cast:Raycast(Origin, Direction, params)

		if not result or not result.Instance then
			break
		end

		local hit = result.Instance

		local ancestor = hit
		local shouldIgnore = false

		while ancestor and ancestor ~= workspace do
			if ancestor:IsA("Accessory") then
				shouldIgnore = true
				break
			end
			ancestor = ancestor.Parent
		end

		if shouldIgnore then
			table.insert(params.FilterDescendantsInstances, ancestor)
			result = nil
			continue
		end

		break
	end

	return result
end

function Cast:Fire(Ballistic, Params)
	while true do
		local result = Cast:FilteredCast(Ballistic, Params)
		local hit = result and Ballistic:Hit(result)
		if not result or not hit then
			print("Break")
			break
		end
	end
end

return Cast