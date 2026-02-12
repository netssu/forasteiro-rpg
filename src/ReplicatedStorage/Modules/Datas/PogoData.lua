local PogoData = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ASSETS_FOLDER = ReplicatedStorage:WaitForChild("Assets")
local POGOS_FOLDER = ASSETS_FOLDER:WaitForChild("Pogos")

PogoData.POGOS = {
	------------------//WORLD 1 (Order 1-5)
	["BasicPogo"] = {
		Name = "Basic Pogo",
		Power = 200,
		Price = 0,
		RequiredRebirths = 0,
		Order = 1,
		Description = "The reliable wooden pogo to start your journey."
	},
	["Rustbucket"] = {
		Name = "Rustbucket",
		Power = 260,
		Price = 200,
		RequiredRebirths = 0,
		Order = 2,
		Description = "Rusty, loud, and barely holding together."
	},
	["MeltingPopsicle"] = {
		Name = "Melting Popsicle",
		Power = 340,
		Price = 3500,
		RequiredRebirths = 0,
		Order = 3,
		Description = "Cold look, messy landing. Drips with every jump."
	},
	["Bloodsucker"] = {
		Name = "Bloodsucker",
		Power = 450,
		Price = 12000,
		RequiredRebirths = 0,
		Order = 4,
		Description = "A red menace that feeds off momentum."
	},
	["GrayGhost"] = {
		Name = "Gray Ghost",
		Power = 600,
		Price = 45000,
		RequiredRebirths = 1,
		Order = 5,
		Description = "Silent springs. You barely hear it coming."
	},

	------------------//WORLD 2 (Order 6-10)
	["AbyssBreather"] = {
		Name = "Abyss Breather",
		Power = 800,
		Price = 120000,
		RequiredRebirths = 1,
		Order = 6,
		Description = "Built for deep drops and darker skies."
	},
	["YellowPiercer"] = {
		Name = "Yellow Piercer",
		Power = 1100,
		Price = 400000,
		RequiredRebirths = 2,
		Order = 7,
		Description = "Punches through air like a spear."
	},
	["Hellheart"] = {
		Name = "Hellheart",
		Power = 1500,
		Price = 1500000,
		RequiredRebirths = 3,
		Order = 8,
		Description = "A burning core that refuses to cool down."
	},
	["TropicPop"] = {
		Name = "Tropic Pop",
		Power = 2100,
		Price = 8000000,
		RequiredRebirths = 5,
		Order = 9,
		Description = "Bright vibes, sharp bounce."
	},
	["TheEnforcer"] = {
		Name = "The Enforcer",
		Power = 3000,
		Price = 35000000,
		RequiredRebirths = 8,
		Order = 10,
		Description = "Heavy duty. No excuses."
	},

	------------------//WORLD 3 (Order 11-15)
	["SodaBomb"] = {
		Name = "Soda Bomb",
		Power = 4200,
		Price = 150000000,
		RequiredRebirths = 12,
		Order = 11,
		Description = "Carbonated power that pops on impact."
	},
	["PressureTank"] = {
		Name = "Pressure Tank",
		Power = 6000,
		Price = 800000000,
		RequiredRebirths = 15,
		Order = 12,
		Description = "Overpressurized. Handle with care."
	},
	["SkyRipper"] = {
		Name = "Sky Ripper",
		Power = 9000,
		Price = 5000000000,
		RequiredRebirths = 20,
		Order = 13,
		Description = "Cuts open the sky with every launch."
	},
	["WoodTotem"] = {
		Name = "Wood Totem",
		Power = 12000,
		Price = 50000000000,
		RequiredRebirths = 25,
		Order = 14,
		Description = "Ancient wood, modern bounce."
	},
	["NeonArc"] = {
		Name = "Neon Arc",
		Power = 15000,
		Price = 120000000000,
		RequiredRebirths = 28,
		Order = 15,
		Description = "Neon lines trace every jump path."
	},

	------------------//WORLD 4 (Order 16-20)
	["StreetScrap"] = {
		Name = "Street Scrap",
		Power = 18000,
		Price = 250000000000,
		RequiredRebirths = 30,
		Order = 16,
		Description = "Built from the street. Hits like a truck."
	},
	["PurpleMechling"] = {
		Name = "Purple Mechling",
		Power = 21000,
		Price = 500000000000,
		RequiredRebirths = 32,
		Order = 17,
		Description = "A compact mech core with purple glow."
	},
	["GuidingStar"] = {
		Name = "Guiding Star",
		Power = 24000,
		Price = 1000000000000,
		RequiredRebirths = 35,
		Order = 18,
		Description = "Follow the star, stick the landing."
	},
	["TurboAngel"] = {
		Name = "Turbo Angel",
		Power = 28000,
		Price = 2500000000000,
		RequiredRebirths = 38,
		Order = 19,
		Description = "Wings out. Throttle up."
	},
	["BubbleRing"] = {
		Name = "Bubble Ring",
		Power = 32000,
		Price = 5000000000000,
		RequiredRebirths = 40,
		Order = 20,
		Description = "A smooth ring that keeps you floating."
	},

	------------------//WORLD 5 (Order 21-25)
	["FutureBeetle"] = {
		Name = "Future Beetle",
		Power = 36000,
		Price = 9000000000000,
		RequiredRebirths = 45,
		Order = 21,
		Description = "A futuristic shell with relentless rebound."
	},
	["PurpleCyclops"] = {
		Name = "Purple Cyclops",
		Power = 41000,
		Price = 15000000000000,
		RequiredRebirths = 50,
		Order = 22,
		Description = "One eye. One mission. Perfect jumps."
	},
	["FloatingPlanet"] = {
		Name = "Floating Planet",
		Power = 47000,
		Price = 25000000000000,
		RequiredRebirths = 55,
		Order = 23,
		Description = "A planet-sized bounce packed into one pogo."
	},
	["PoisonVine"] = {
		Name = "Poison Vine",
		Power = 54000,
		Price = 40000000000000,
		RequiredRebirths = 60,
		Order = 24,
		Description = "Toxic growth, unstoppable spring."
	},
	["GoldenGleam"] = {
		Name = "Golden Gleam",
		Power = 62000,
		Price = 70000000000000,
		RequiredRebirths = 70,
		Order = 25,
		Description = "Pure gold brilliance with god-tier bounce."
	},
}

------------------//FUNCTIONS
function PogoData.GetSortedList()
	local list = {}
	for id, data in pairs(PogoData.POGOS) do
		local entry = table.clone(data)
		entry.Id = id
		table.insert(list, entry)
	end

	table.sort(list, function(a, b)
		return a.Order < b.Order
	end)

	return list
end

function PogoData.GetPogoViewport(pogoName)
	local pogoData = PogoData.POGOS[pogoName]
	local model = POGOS_FOLDER:FindFirstChild(pogoName)

	if not pogoData or not model then
		warn("Pogo ou Modelo não encontrado para: " .. tostring(pogoName))
		return nil
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Name = "PogoView_" .. pogoName

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local modelClone = model:Clone()
	modelClone.Parent = viewport

	local cf, size = modelClone:GetBoundingBox()

	local maxDimension = math.max(size.X, size.Y, size.Z)
	local safetyMargin = 1
	local viewAngle = math.rad(70)

	local fov = camera.FieldOfView
	local fitDistance = (maxDimension / 2) / math.tan(math.rad(fov / 2))
	local finalDistance = (size.Z / 2) + (fitDistance * safetyMargin)

	local rotatedDirection = (cf * CFrame.Angles(0, viewAngle, 0)).LookVector
	local cameraPosition = cf.Position + (rotatedDirection * finalDistance)

	cameraPosition += Vector3.new(0, size.Y * 0.1, 0)

	camera.CFrame = CFrame.lookAt(cameraPosition, cf.Position)

	return viewport
end

function PogoData.Get(id: string)
	return PogoData.POGOS[id] or PogoData.POGOS["BasicPogo"]
end

return PogoData
