------------------//SERVICES

------------------//CONSTANTS

------------------//VARIABLES
local DiceManager = {}

------------------//FUNCTIONS
function DiceManager.parse_and_roll(expression: string): any
	local cleanExpression = string.gsub(string.lower(expression), "%s+", "")
	local countStr, sidesStr, modStr = string.match(cleanExpression, "(%d*)d(%d+)([+-]?%d*)")

	if not sidesStr then
		return nil
	end

	local count = tonumber(countStr) or 1
	local sides = tonumber(sidesStr)
	local mod = tonumber(modStr) or 0

	if count > 50 then count = 50 end
	if count < 1 then count = 1 end
	if sides < 2 then sides = 2 end

	local total = 0
	local rolls = {}

	for i = 1, count do
		local r = math.random(1, sides)
		table.insert(rolls, r)
		total += r
	end

	total += mod

	local modString = ""
	if mod > 0 then
		modString = "+" .. tostring(mod)
	elseif mod < 0 then
		modString = tostring(mod)
	end

	local formattedExpression = tostring(count) .. "d" .. tostring(sides) .. modString

	return {
		Total = total,
		Rolls = rolls,
		Expression = formattedExpression,
		Mod = mod
	}
end

return DiceManager