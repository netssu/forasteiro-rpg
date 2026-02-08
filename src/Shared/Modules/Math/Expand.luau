local multipliers = {
	K = 1e3,
	M = 1e6,
	B = 1e9,
	T = 1e12,
	Qa = 1e15,
	Qi = 1e18,
}

-- Expands an abbreviated number string back to its full numerical value.
local function expand(abbreviated: string): number | string
	local number = tonumber(abbreviated)
	if number then
		return number
	end

	local value, suffix = abbreviated:match("([%d%.]+)(%a)")
	if value and suffix and multipliers[suffix:upper()] then
		return tonumber(value) * multipliers[suffix:upper()]
	end

	return ""
end

return expand
