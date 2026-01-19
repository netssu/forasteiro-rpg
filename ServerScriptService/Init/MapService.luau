local MapService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game.ServerStorage

local resources = ReplicatedStorage.Resources
local lightingFolder = resources.Lighting

local LoadMapLightPacket

function MapService:SpawnMap(MapName: string)
	workspace.Map:ClearAllChildren()
	
	local Map = ServerStorage.Maps[MapName]
	local _Map = Map:FindFirstChild("Map")
	
	local ClonedMap
	
	if _Map then
		ClonedMap = _Map:Clone()
	else
		ClonedMap = Map:Clone().Parent	
	end
	for _, SpawnLocation in ClonedMap:GetChildren() do
		if SpawnLocation:IsA("SpawnLocation") then
			SpawnLocation.Enabled = true
		end		
	end
	
	MapService.CurrentMap = MapName
	
	ClonedMap.Parent = workspace.Map
end

function MapService:GetMap(MapName)
	for _, map in pairs(ServerStorage.Maps:GetChildren()) do
		if string.lower(MapName) == string.lower(map.Name) then
			return map
		end
	end
end

function MapService:LoadLightingForPlayer(player,default)
	
	local mapName = MapService.CurrentMap or "Default"

	LoadMapLightPacket:FireClient(player,default and "Default" or mapName)
	
	--print(Map.Name)
	--local Lighting = Map:FindFirstChild("Ligthing")
	--if Lighting then
	--	print("Ligthting found")
	--	game.Lighting:ClearAllChildren()
	--	--local ClonedLighting = Lighting:Clone()
	--	for i,l in Lighting:GetChildren() do
	--		if not l:IsA("NumberValue") then
	--			l:Clone().Parent = game.Lighting
	--		end
	--	end
		--ClonedLighting.Parent = game.Lighting
		--Lighting.Parent = game.Lighting
		--Lighting.Ambient = Lighting:FindFirstChild("Ambient").Value or Color3.new(0.27451, 0.27451, 0.27451)
		--Lighting.Brightness = Lighting:FindFirstChild("Brightness").Value or 2
		--Lighting.ColorShift_Top = Lighting:FindFirstChild("ColorShift_Top").Value or Color3.new(0,0,0)
		--Lighting.ColorShift_Bottom = Lighting:FindFirstChild("ColorShift_Bottom").Value or Color3.new(0,0,0)
		--Lighting.EnvironmentDiffuseScale = Lighting:FindFirstChild("EnvironmentDiffuseScale").Value or 1
		--Lighting.EnvironmentSpecularScale = Lighting:FindFirstChild("EnvironmentSpecularScale").Value or 1
		--Lighting.OutdoorAmbient = Lighting:FindFirstChild("OutdoorAmbient").Value or Color3.new(0.27451, 0.27451, 0.27451)
		--Lighting.ShadowSoftness = Lighting:FindFirstChild("ShadowSoftness").Value or 1
		--Lighting.ClockTime = Lighting:FindFirstChild("ClockTime").Value or 8
		--Lighting.GlobalShadows = Lighting:FindFirstChild("GlobalShadows").Value or true
		--Lighting.GeographicLatitude = Lighting:FindFirstChild("GeographicLatitude").Value or 0
		--Lighting.ExposureCompensation = Lighting:FindFirstChild("ExposureCompensation").Value or 0
	--end
end

function MapService:Start()
	local Packet = self.Libs.Packet
	LoadMapLightPacket = Packet("MapLighting", Packet.Any)
end

return MapService