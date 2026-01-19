local AllSkins = require(script.Parent)

local Utils = {}

function Utils.GetSkinByID(ID: number)
	return AllSkins[ID]
end

function Utils.GetSkinsByWeapon(Weapon: string)
	local Skins = {}
	for _, Skin in AllSkins do
		if Skin.Weapon == Weapon then
			table.insert(Skins, Skin)
		end
	end
	
	return Skins
end

function Utils.GetSkinByName(Name: string)
	for _, Skin in AllSkins do
		if Skin.Name == Name then
			return Skin
		end
	end
end

return Utils