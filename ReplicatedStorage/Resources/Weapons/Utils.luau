local AllWeapons = require(script.Parent)

local Utils = {}

function Utils.GetWeaponData(Name: string)
	for _, weaponData in AllWeapons do
		if weaponData.Name == Name then
			return weaponData
		end
	end
end

return Utils