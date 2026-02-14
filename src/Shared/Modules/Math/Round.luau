-- Rounds a number to a specified number of decimal places.
local function round(number: number, decimals: number): number
	local mult = 10 ^ decimals
	return math.floor(number * mult + 0.5) / mult
end

return round
