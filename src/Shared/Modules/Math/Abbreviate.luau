local suffixes = {
	"",
	"K",
	"M",
	"B",
	"T",
	"Qa",
	"Qi",
}

-- Abbreviates a number with a suffix.
local function abbreviate(Number: number): string
	if tostring(Number) == "inf" then
		return "8"
	end

	for i = 1, #suffixes do
		if Number < 10 ^ (i * 3) then
			local abbreviated_number = Number / (10 ^ ((i - 1) * 3))

			if abbreviated_number == math.floor(abbreviated_number) then
				return tostring(math.floor(abbreviated_number)) .. suffixes[i]
			else
				return string.format("%.2f", abbreviated_number) .. suffixes[i]
			end
		end
	end

	return tostring(Number)
end

return abbreviate
