local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedModules = ReplicatedStorage.Modules
local TableUtils = require(sharedModules.Utils.TableUtils)
local CHARSET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local VOWELS = {
	["a"] = true,
	["e"] = true,
	["i"] = true,
	["o"] = true,
	["u"] = true,
	["A"] = true,
	["E"] = true,
	["I"] = true,
	["O"] = true,
	["U"] = true,
}
TableUtils.deepFreeze(VOWELS)

local ROMAN_NUMBER_MAP = {
	{ 1000, "M" },
	{ 900, "CM" },
	{ 500, "D" },
	{ 400, "CD" },
	{ 100, "C" },
	{ 90, "XC" },
	{ 50, "L" },
	{ 40, "XL" },
	{ 10, "X" },
	{ 9, "IX" },
	{ 5, "V" },
	{ 4, "IV" },
	{ 1, "I" },
}
TableUtils.deepFreeze(ROMAN_NUMBER_MAP)

local StringUtils = {}

function StringUtils.randomString(length: number): string
	local random = Random.new()
	local characters = {}

	for i = 1, length do
		local i2 = random:NextInteger(1, #CHARSET)
		characters[i] = CHARSET:sub(i2, i2)
	end

	return table.concat(characters)
end

function StringUtils.capitalizeFirstLetter(target: string): string
	return (target:gsub("^%l", string.upper))
end

function StringUtils.aOrAn(target: string): string
	if VOWELS[target:sub(1, 1)] then
		return "an"
	else
		return "a"
	end
end

function StringUtils.toRoman(number: number): string
	assert(typeof(number) == "number" and number // 1 == number, "The number must be an integer.")

	local result = ""

	while number > 0 do
		for _, v in ROMAN_NUMBER_MAP do
			local romanCharacter = v[2]
			local integer = v[1]

			while number >= integer do
				result = `{result}{romanCharacter}`
				number = number - integer
			end
		end
	end

	return result
end

return StringUtils
