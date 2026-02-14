-- Formats a number as currency with commas.
local function formatCurrency(number: number): string
	local stringNumber = tostring(number)
	return stringNumber:reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

return formatCurrency
