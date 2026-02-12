------------------//MODULE
local MaterialData = {}

------------------//DATABASE
MaterialData.Materials = {
	["Plastic"] = {
		Order = 1,
		Name = "Plastic",
		CoinMultiplier = 1.0,
		MinBreakForce = 40,
		Color = Color3.fromRGB(200, 200, 200)
	},
	["Wood"] = {
		Order = 2,
		Name = "Wood",
		CoinMultiplier = 1.2,
		MinBreakForce = 60,
		Color = Color3.fromRGB(139, 69, 19)
	},
	["Iron"] = {
		Order = 3,
		Name = "Iron",
		CoinMultiplier = 1.5,
		MinBreakForce = 90,
		Color = Color3.fromRGB(161, 161, 161)
	},
	["Steel"] = {
		Order = 4,
		Name = "Steel",
		CoinMultiplier = 1.8,
		MinBreakForce = 120,
		Color = Color3.fromRGB(97, 108, 117)
	},
	["Gold"] = {
		Order = 5,
		Name = "Gold",
		CoinMultiplier = 3.5,
		MinBreakForce = 160,
		Color = Color3.fromRGB(255, 215, 0)
	},
	["Diamond"] = {
		Order = 6,
		Name = "Diamond",
		CoinMultiplier = 5.0,
		MinBreakForce = 220,
		Color = Color3.fromRGB(0, 255, 255)
	},
	["Obsidian"] = {
		Order = 7,
		Name = "Obsidian",
		CoinMultiplier = 8.0,
		MinBreakForce = 300,
		Color = Color3.fromRGB(50, 0, 80)
	}
}

------------------//FUNCTIONS
function MaterialData.Get(materialName: string)
	return MaterialData.Materials[materialName] or MaterialData.Materials["Plastic"]
end

function MaterialData.GetAllSorted()
	local list = {}
	for id, data in pairs(MaterialData.Materials) do
		table.insert(list, {Id = id, Data = data})
	end
	table.sort(list, function(a, b)
		return a.Data.Order < b.Data.Order
	end)
	return list
end

return MaterialData