-- CONSTANTS
local ProductsData = {}

ProductsData.DevProducts = {
	["5K Coins"] = {
		ProductId = 3534601972,
		Type = "Coins",
		Amount = 5000,
	},
	["10K Coins"] = {
		ProductId = 3534602037,
		Type = "Coins",
		Amount = 10000,
	},
	["50K Coins"] = {
		ProductId = 3534602111,
		Type = "Coins",
		Amount = 50000,
	},
	["Coins2X"] = {
		ProductId = 3534601764,
		Type = "Boost",
		BoostKey = "Coins2X",
		Duration = 120,
	},
	["Lucky2X"] = {
		ProductId = 3534601655,
		Type = "Boost",
		BoostKey = "Lucky2X",
		Duration = 120,
	},
	["MoreCandy"] = {
		ProductId = 3534601837,
		Type = "Boost",
		BoostKey = "MoreCandy",
		Duration = 120,
	},
}

ProductsData.Gamepasses = {
	["BigCandysOffline"] = {
		GamepassId = 1711344445,
	},
	["SlotCandy"] = {
		GamepassId = 1708493957,
	},
	["Candy2XForever"] = {
		GamepassId = 1711483593,
	},
	["StarterPack"] = {
		GamepassId = 1711334795,
	},
}

ProductsData.ProductIdMap = {}
for name, data in pairs(ProductsData.DevProducts) do
	ProductsData.ProductIdMap[data.ProductId] = {
		Name = name,
		Data = data,
	}
end

return ProductsData