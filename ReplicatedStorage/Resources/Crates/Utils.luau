local Crates = require(script.Parent)
local Skins = require(script.Parent.Parent.Skins)

local Utils = {}

Utils.RarityWeight = {
	Bad = 60,
	Ok = 38,
	Goated = 2,
	Holy = 0.5
}

function Utils.GetCrateData(CrateId)
	local crate = Crates[CrateId]
	if crate then
		return crate
	end
end

function Utils.GetRandomSkinFromCrate(CrateId: number)
	local crate = Crates[CrateId]
	local SkinsByRarity = {}

	for _, skinId in crate.Drops do
		local data = Skins[skinId]
		if not SkinsByRarity[data.Rarity] then
			SkinsByRarity[data.Rarity] = {}
		end
		table.insert(SkinsByRarity[data.Rarity], skinId)
	end

	local totalWeight = 0
	for rarity, weight in Utils.RarityWeight do
		if SkinsByRarity[rarity] then
			totalWeight += weight
		end
	end

	local r = math.random() * totalWeight
	local accum = 0
	local chosenRarity

	for rarity, weight in Utils.RarityWeight do
		if SkinsByRarity[rarity] then
			accum += weight
			if r <= accum then
				chosenRarity = rarity
				break
			end
		end
	end

	local list = SkinsByRarity[chosenRarity]
	return list[math.random(1, #list)]
end

return Utils
