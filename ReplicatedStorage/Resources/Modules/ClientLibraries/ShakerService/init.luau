--[[
Copyright (©) 2025, Judash399
ShakerService: Version 1.0.0

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”),
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

--Services
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

--Modules
local Templates = require(script.Templates)

local Signal = CollectionService:GetTagged("Signal")

if Signal[1] then
	Signal = require(Signal[1])
else
	error("Unable to find a signal library! ShakerService requires one! Get a Signal library and make sure it has a 'Signal' tag!")
end

--Types
export type VisualConfig = {
	RotationalShaking: boolean, --Do shakers, shake by moving the rotation of the camera.
	TranslationalShaking: boolean, --Do shakers, shake by moving the position of the camera.
	FallOfRate: number, --How much of the intensity a shake loses per second. Once this reaches 0 the shake object is automaticly cleaned up.
	RotationalStrength: Vector3, -- Multiplied on each axis when rotational shaking applyed. The higher the number the stronger the same amount of shake is.
	TranslationalStrength: Vector3, -- Multiplied on each axis when translational shaking applyed. The higher the number the stronger the same amount of shake is.
	SpeedMultiplier: number, --How fast the noise which generates the shake moves. 
}

export type Connection = {
	Connected: boolean,
	Disconnect: typeof(
		function(connection: Connection) end
	)
}

export type Signal<Parameters...> = {
	Connect: typeof(
		function(signal: Signal<Parameters...>, callback: (Parameters...) -> ()): Connection end
	),
	Once: typeof(
		function(signal: Signal<Parameters...>, callback: (Parameters...) -> ()): Connection end
	),
	Wait: typeof(
		function(signal: Signal<Parameters...>): Parameters... end
	)
}

export type ShakeInfo = {
	intensity: number,
	direction: Vector3,
}

export type Config = {
	AutoUpdates: boolean
}

--Variables
local defaultVisualConfig = Templates.Default


local defaultConfig = {
	AutoUpdates = true
}

local module = {}
local shakerfunc = {}

--returns a new shaker object.
function module.new(camera: Camera, visualConfig: VisualConfig?, technicalConfig: Config?)
	assert(camera, "Cannot create a shaker object without a camera!")
	
	visualConfig = visualConfig or {}
	technicalConfig = technicalConfig or {}
	
	local shaker = setmetatable({
		_config = setmetatable(visualConfig, {__index = defaultVisualConfig}),
		_technicalConfig = setmetatable(technicalConfig, {__index = defaultConfig}),
		_camera = camera,
	}, {__index = shakerfunc})
	
	shaker._currentShakes = {}
	
	shaker._identifier = tick() .. "-" .. tostring(math.random(1, 9999))
	
	shaker._cleaningUp = false
	
	shaker.shakeAdded = Signal():: Signal<ShakeInfo>
	shaker.shakeDeminished = Signal():: Signal
	
	if technicalConfig.AutoUpdates then
		RunService:BindToRenderStep("Shaker:" .. shaker._identifier, Enum.RenderPriority.Camera.Value + 1, function(delta)
			shaker:Update(delta)
		end)
	end
	
	return shaker
end

--AUTO RAN, ONLY USE IF AUTO UPDATE DISABLED.
--Updates the camera shake for this frame.
function shakerfunc:Update(delta: number)
	local offset = Vector3.new(0,0,0)
	local rotationOffset = CFrame.new()

	for i, shake in ipairs(self._currentShakes) do
		
		shake.intensity -= delta * self._config.FallOfRate
		
		if shake.intensity <= 0 then
			table.remove(self._currentShakes, i)
			self.shakeDeminished:Fire()
			continue
		end
		
		local t = os.clock()
		-- Noise-based shake
		local xNoise = math.noise(t * self._config.SpeedMultiplier, 0, 0)
		local yNoise = math.noise(t * self._config.SpeedMultiplier, 5, 0)
		local zNoise = math.noise(t * self._config.SpeedMultiplier, 10, 0)
		
		if shake.direction == Vector3.zero then
			offset += Vector3.new(xNoise, yNoise, zNoise) * shake.intensity
			rotationOffset = rotationOffset * CFrame.Angles(math.rad(xNoise * shake.intensity * self._config.RotationalStrength.X), math.rad(yNoise * shake.intensity * self._config.RotationalStrength.Y), math.rad(zNoise * shake.intensity * self._config.RotationalStrength.Z))
		else
			local dir = Vector3.new(shake.direction.X, shake.direction.Y, shake.direction.Z)
			offset += Vector3.new(xNoise * dir.X * self._config.RotationalStrength.X, yNoise * dir.Y * self._config.RotationalStrength.Y, zNoise * dir.Z * self._config.RotationalStrength.Z) * shake.intensity
			
			local dir = shake.direction.Magnitude > 0 and shake.direction.Unit or Vector3.new(0,0,0)
			-- Rotate 90 degrees around Y
			local rotatedDir = Vector3.new(-dir.Y, dir.X, dir.Z)

			rotationOffset *= CFrame.Angles(
				math.rad(xNoise * shake.intensity * rotatedDir.X),
				math.rad(yNoise * shake.intensity * rotatedDir.Y),
				math.rad(zNoise * shake.intensity * rotatedDir.Z)
			)

		end
	end

	if self._config.RotationalShaking then
		self._camera.CFrame = self._camera.CFrame * (rotationOffset)
	end
	
	if self._config.TranslationalShaking then
		self._camera.CFrame = self._camera.CFrame * CFrame.new((offset * self._config.TranslationalStrength))
	end
end

--Adds Shake as if its coming from a certain position in the world.
function shakerfunc:shakeFromPosition(intensity: number, position: Vector3 | BasePart)
	if self._cleaningUp then
		warn("Currently In the process of smoothly cleaning up this shaker! Cannot create add any new shake!")
		return
	end
	
	if position:IsA("BasePart") then
		position = position.Position
	end
	local direction = (position - self._camera.CFrame.Position).Unit
	self:directionalShake(intensity, direction)
end

--Adds Shake without it having any direction to it.
--It's achived by making the shake vector equal to (0, 0, 0)
function shakerfunc:nonDirectionalShake(intensity: number)
	if self._cleaningUp then
		warn("Currently In the process of smoothly cleaning up this shaker! Cannot create add any new shake!")
		return
	end
	
	self:directionalShake(intensity, Vector3.new(0,0,0))
end

--Adds Shake as if its coming from a certain position offset to the camera.
--So if the direction is (1, 0, 0) it will seem as if its coming from the right.
function shakerfunc:directionalShake(intensity: number, direction: Vector3)
	if self._cleaningUp then
		warn("Currently In the process of smoothly cleaning up this shaker! Cannot create add any new shake!")
		return
	end
	
	if direction ~= Vector3.zero then
		direction = direction.Unit
	end
	
	table.insert(self._currentShakes, {creationTime = os.clock(), intensity = intensity, direction = direction})
	
	self.shakeAdded:Fire({intensity = intensity, direction = direction})
end

--Cleans up the shaker object.
--Keep in mind that this will <em><strong>stop all shaking immediately!</em></strong> if that behavor is not desired use <code>cleanupSmoothly()<code>!
function shakerfunc:cleanup()
	RunService:UnbindFromRenderStep("Shaker:" .. self._identifier)
	
	self.shakeAdded:DisconnectAll()
	self.shakeDeminished:DisconnectAll()
	
	for k in pairs(self) do
		self[k] = nil
	end
	
	table.freeze(self)
end

--Cleans up the shaker object, but waits until all currently applied shake effects are gone.
--Prevents any new shakes from being created.
function shakerfunc:cleanupSmoothly()
	if self._cleaningUp then
		warn("Already smoothly cleaning up!")
		return
	end
	
	self._cleaningUp = true
	
	task.spawn(function()
		while #self._currentShakes ~= 0 do
			task.wait(0)
		end
		
		self:cleanup()
	end)
end

module.ConfigTemplates = Templates

table.freeze(module)

return module