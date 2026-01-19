--// Services //--
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = {}

--// Types //--
export type Currency = "Cash" | "Plutonium" | "Robux"

export type ShopItem = {
	Price: number | {Cash: number, Plutonium: number},
	Currency: Currency,
	ProductID: number?,
	PassID: number?,
	GiftProductID: number?,
	Category: string?,
	Name: string?,
}

export type BundleContents = {
	Currency: {Cash: number?, Plutonium: number?}?,
	Items: {[string]: number}?,
	Stats: {[string]: number}?,
	Special: {[string]: boolean}?,
}

export type BundleItem = ShopItem & {
	Contents: BundleContents,
}

--// Storage //--
ShopConfig.Storage = {} :: {
	[string]: {ShopItem}
}

ShopConfig.Storage = {
	Money = {
		["10000_Cash"] = {Price = 19, Currency = "Robux", ProductID = 1234, GiftProductID = 1234},
		["100000_Cash"] = {Price = 49, Currency = "Robux", ProductID = 1234, GiftProductID = 1234},
		["500000_Cash"] = {Price = 129, Currency = "Robux", ProductID = 1234, GiftProductID = 1234},
		["1000000_Cash"] = {Price = 249, Currency = "Robux", ProductID = 1234, GiftProductID = 1234},
	},

	Plutonium = {
		["50_Plutonium"] = {Price = 19, Currency = "Robux", ProductID = 3470786006, GiftProductID = 1234},
		["265_Plutonium"] = {Price = 59, Currency = "Robux", ProductID = 3470786147, GiftProductID = 1234},
		["600_Plutonium"] = {Price = 115, Currency = "Robux", ProductID = 3470786312, GiftProductID = 1234},
		["1399_Plutonium"] = {Price = 229, Currency = "Robux", ProductID = 3470786711, GiftProductID = 1234},
	},

	Bundles = {
		["StarterPack"] = {
			Price = 49,
			Currency = "Robux",
			ProductID = 3470784989,
			GiftProductID = 1234,
			Contents = {
				Currency = {Cash = 100000, Plutonium = 25},
				Items = {},
				Stats = {ProductionValue = 1.5},
				Special = {},
			}
		},
		["VIP"] = {
			Price = 189,
			Currency = "Robux",
			ProductID = 3470785362,
			GiftProductID = 1612511024,
			Contents = {
				Currency = {Cash = 100000, Plutonium = 25},
				Items = {},
				Stats = {ProductionValue = 1.5},
				Special = {},
			}
		},
		["CurrencyPack"] = {
			Price = 143,
			Currency = "Robux",
			PassID = 1234, -- Atenção: Se for Gamepass, o jogador só recebe UMA VEZ. Se quiser que comprem várias vezes, use ProductID.
			GiftProductID = 1234,
			Contents = {
				Currency = {Plutonium = 750},
				Items = {},
				Stats = {

				},
				Special = {},
			}
		},
	},

	Special = {
		["FasterProduction"] = {
			Price = 229,
			Currency = "Robux",
			PassID = 1612547030,
			GiftProductID = 1234,
		},
	},

	PremiumTanks = {
		["PremiumTank_1"] = {
			Price = 199,
			Currency = "Robux",
			PassID = 1234,
			GiftProductID = 1234,
		},

		["PremiumTank_2"] = {
			Price = 299,
			Currency = "Robux",
			PassID = 1234,
			GiftProductID = 1234,
		},
	},

	LuckyBlocks = {
		["Special_1"] = {
			Price = 249,
			Currency = "Robux",
			ProductID = 3470785,
			GiftProductID = 1234,
		},
		["Special_3"] = {
			Price = 699,
			Currency = "Robux",
			ProductID = 3470785155,
			GiftProductID = 1234,
		},
		["Special_10"] = {
			Price = 1999,
			Currency = "Robux",
			ProductID = 3470785229,
			GiftProductID = 1234,
		},
	}
}

--// Helper Functions //--
function ShopConfig.getShopItem(itemName: string, category: string?): ShopItem?
	if category then
		local categoryItems = ShopConfig.Storage[category]
		if categoryItems and categoryItems[itemName] then
			local item = categoryItems[itemName]
			item.Category = category
			item.Name = itemName
			return item
		end
		return nil
	end

	for cat, items in pairs(ShopConfig.Storage) do
		local item = items[itemName]
		if item then
			item.Category = cat
			item.Name = itemName
			return item
		end
	end

	return nil
end

function ShopConfig.getCategory(itemName: string): string?
	for category, items in pairs(ShopConfig.Storage) do
		if items[itemName] then
			return category
		end
	end
	return nil
end

function ShopConfig.getCategoryItems(category: string): {[string]: ShopItem}?
	return ShopConfig.Storage[category]
end

function ShopConfig.isGiftable(itemName: string): (boolean, number?)
	local item = ShopConfig.getShopItem(itemName)
	if item and item.GiftProductID then
		return true, item.GiftProductID
	end
	return false, nil
end

function ShopConfig.getItemFromProductID(productID: number): (string?, string?)
	for category, items in pairs(ShopConfig.Storage) do
		for itemName, item in pairs(items) do
			if item.ProductID == productID or item.GiftProductID == productID then
				return itemName, category
			end
		end
	end
	return nil, nil
end

function ShopConfig.getItemFromPassID(passID: number): (string?, string?)
	for category, items in pairs(ShopConfig.Storage) do
		for itemName, item in pairs(items) do
			if item.PassID == passID then
				return itemName, category
			end
		end
	end
	return nil, nil
end

function ShopConfig.isGiftProduct(productID: number): boolean
	for _, items in pairs(ShopConfig.Storage) do
		for _, item in pairs(items) do
			if item.GiftProductID == productID then
				return true
			end
		end
	end
	return false
end

return ShopConfig