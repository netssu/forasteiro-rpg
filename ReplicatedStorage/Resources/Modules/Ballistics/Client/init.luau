local Client = {}

local BulletHoleEvent: UnreliableRemoteEvent = script.BulletHole

local Settings = require(script.Parent.Settings)
local Utils = require(script.Parent.Utils)
local BULLET_HOLE_DURATION = Settings.BULLET_HOLE_DURATION
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

Client.Initialized = false

local HoleCache = {}
local ActiveHoles = {}

local function GetHoleFromCache()
	local hole = table.remove(HoleCache)
	if hole then
		return hole
	end

	local newHole = script.VFX.BulletHole:Clone()
	newHole.Parent = workspace.VFX
	return newHole
end

local function ReturnHoleToCache(hole)
	hole.Parent = nil
	table.insert(HoleCache, hole)
end

function Client:FireClients(Holes)
	BulletHoleEvent:FireAllClients(Holes)
end

function Client:GetBulletHoles(Ballistic)
	local Holes = {}

	for Index, Hit in Ballistic.Hits do
		if Hit.Type == "Object" then
			table.insert(Holes, {Hit.Position, Hit.Normal})

			if Index > 1 then
				local Thickness = Utils:GetThickness(Hit.Instance, Hit.Normal)
				local ExitPosition = Hit.Position - Hit.Normal * Thickness
				table.insert(Holes, {ExitPosition, -Hit.Normal})
			end
		end
	end

	return Holes
end

function Client.RenderHole(Hole)
	local HoleVFX = GetHoleFromCache()
	HoleVFX.CFrame = CFrame.new(Hole[1], Hole[1] + Hole[2])
	HoleVFX.Parent = workspace.VFX

	for _, VFX in HoleVFX:GetDescendants() do
		if VFX:IsA("ParticleEmitter") then
			VFX:Emit(VFX:GetAttribute("EmitCount"))
		end
	end

	ActiveHoles[HoleVFX] = true

	task.delay(BULLET_HOLE_DURATION, function()
		if ActiveHoles[HoleVFX] then
			ActiveHoles[HoleVFX] = nil
			ReturnHoleToCache(HoleVFX)
		end
	end)
end

function Client:Init()
	if Client.Initialized then
		return
	end

	Client.Initialized = true

	if RunService:IsClient() then
		BulletHoleEvent.OnClientEvent:Connect(function(Holes)
			for _, Hole in Holes do
				Client.RenderHole(Hole)
			end
		end)
	end
end

return Client
