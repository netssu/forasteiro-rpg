------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local ASSETS_FOLDER = ReplicatedStorage:WaitForChild("Assets")
local PETS_FOLDER = ASSETS_FOLDER:WaitForChild("Pets")

------------------//VARIABLES
local PetsConfig = {
	["Cat"] = {
		Model = PETS_FOLDER:FindFirstChild("Cat"),
		DisplayName = "Cat",
		Raritys = "Common",
		Weight = 30,
		Multiplier = 0.1,
		IsFlying = false,
		FixRotation = false,
	},
	["Dog"] = {
		Model = PETS_FOLDER:FindFirstChild("Dog"),
		DisplayName = "Dog",
		Raritys = "Common",
		Weight = 30,
		Multiplier = 0.1,
		IsFlying = false,
		FixRotation = false,
	},
	["Tiger"] = {
		Model = PETS_FOLDER:FindFirstChild("Tiger"), 
		DisplayName = "Tiger",
		Raritys = "Epic",
		Weight = 10,
		Multiplier = 0.2,
		IsFlying = false,
		FixRotation = true,
	},
	["Bear"] = {
		Model = PETS_FOLDER:FindFirstChild("Bear"),
		DisplayName = "Bear",
		Raritys = "Rare",
		Weight = 25,
		Multiplier = 0.15,
		IsFlying = false,
		FixRotation = true,
	},
	["Pig"] = {
		Model = PETS_FOLDER:FindFirstChild("Pig"),
		DisplayName = "Pig", 
		Raritys = "Legendary",
		Weight = 5,
		Multiplier = 0.3,
		IsFlying = false,
		FixRotation = true,
	},
}

------------------//FUNCTIONS
local DataPets = {}

function DataPets.GetPetData(petName)
	return PetsConfig[petName]
end

function DataPets.GetAllPets()
	return PetsConfig
end

function DataPets.GetPetViewport(petName)
	local petData = PetsConfig[petName]
	if not petData or not petData.Model then 
		warn("Pet ou Modelo não encontrado para: " .. tostring(petName))
		return nil 
	end
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Name = "PetView_" .. petName
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local modelClone = petData.Model:Clone()
	modelClone.Parent = viewport
	local cf, size = modelClone:GetBoundingBox()
	local maxDimension = math.max(size.X, size.Y, size.Z)
	local safetyMargin = 1.7
	local viewAngle = math.rad(30)
	local fov = camera.FieldOfView
	local fitDistance = (maxDimension / 2) / math.tan(math.rad(fov / 2))
	local finalDistance = (size.Z / 2) + (fitDistance * safetyMargin)
	local rotatedDirection = (cf * CFrame.Angles(0, viewAngle, 0)).LookVector
	local cameraPosition = cf.Position + (rotatedDirection * finalDistance)
	cameraPosition = cameraPosition + Vector3.new(0, size.Y * 0.1, 0)
	camera.CFrame = CFrame.lookAt(cameraPosition, cf.Position)
	return viewport
end

------------------//INIT
return DataPets