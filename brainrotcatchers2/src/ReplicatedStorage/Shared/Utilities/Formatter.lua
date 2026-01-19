local module = {}
local BigNum = require(script.Parent.BigNum)

function module.formatNumber(number: any): string
	-- Handle BigNum
	if type(number) == "table" and number.mantissa then
		return number:toString(1)
	end

	-- Handle strings (might be BigNum string)
	if type(number) == "string" then
		local bn = BigNum.new(number)
		return bn:toString(1)
	end

	-- Handle regular numbers
	if number < 1000 then
		return tostring(math.floor(number))
	end

	local bn = BigNum.new(number)
	return bn:toString(1)
end

function module.formatCash(number: any): string
	return "$" .. module.formatNumber(number)
end

function module.parseNumber(formattedString: string): any
	return BigNum.new(formattedString)
end

return module