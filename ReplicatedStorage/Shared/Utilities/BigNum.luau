local BigNum = {}
BigNum.__index = BigNum

--// Suffix Configuration //--
local SUFFIXES = {
	"K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"
}

local SUFFIX_TO_POWER = {} -- Cache suffix -> power mapping
for i, suffix in ipairs(SUFFIXES) do
	SUFFIX_TO_POWER[suffix] = i
end

local MAX_SAFE_INTEGER = 9007199254740992 -- 2^53, Lua's max safe integer
local EPSILON = 1e-15 -- For floating point comparisons (increased precision)

--// Types //--
export type BigNumModule = typeof(BigNum)

export type BigNum = {
	mantissa: number,
	exponent: number,
} & BigNumModule 

--// Constructor //--

function BigNum.new(value: number | string | BigNum) : BigNum
	local self = setmetatable({}, BigNum)

	if type(value) == "table" and value.mantissa then
		-- Clone existing BigNum
		self.mantissa = value.mantissa
		self.exponent = value.exponent
	elseif type(value) == "string" then
		-- Parse string (handles both old suffix format and new scientific notation)
		self:_parseString(value)
	else
		-- Parse number
		self:_parseNumber(value)
	end

	self:_normalize()
	return self
end

--// Private Methods //--

function BigNum:_parseNumber(num: number)
	if num == 0 then
		self.mantissa = 0
		self.exponent = 0
		return
	end

	local sign = num < 0 and -1 or 1
	num = math.abs(num)

	-- Convert to scientific notation
	local exp = math.floor(math.log10(num))
	local mantissa = num / (10 ^ exp)

	self.mantissa = sign * mantissa
	self.exponent = exp
end

function BigNum:_parseString(str: string)
	str = string.gsub(str, ",", "") -- Remove commas
	str = string.gsub(str, "%s+", "") -- Remove whitespace

	-- Try parsing as scientific notation first (new format: "6.712e12")
	local scientificNum = tonumber(str)
	if scientificNum then
		self:_parseNumber(scientificNum)
		return
	end

	-- Check for explicit scientific notation pattern (e.g., "1.5e10")
	local mantissa, exp = string.match(str, "^([%d%.%-]+)e([%d%-]+)$")
	if mantissa and exp then
		local m = tonumber(mantissa)
		local e = tonumber(exp)
		if m and e then
			self.mantissa = m
			self.exponent = e
			return
		end
	end

	-- Fall back to old suffix format (e.g., "67.12T") for migration
	local numPart, suffix = string.match(str, "^([%d%.%-]+)(%a*)$")

	if not numPart then
		warn(`Invalid BigNum string: {str}`)
		self.mantissa = 0
		self.exponent = 0
		return
	end

	local num = tonumber(numPart)
	if not num then
		warn(`Invalid number in BigNum string: {numPart}`)
		self.mantissa = 0
		self.exponent = 0
		return
	end

	-- Calculate exponent from suffix
	local suffixPower = 0
	if suffix and suffix ~= "" then
		suffixPower = SUFFIX_TO_POWER[suffix]
		if not suffixPower then
			warn(`Unknown suffix: {suffix}`)
			suffixPower = 0
		end
	end

	-- Convert to internal representation
	self:_parseNumber(num)
	self.exponent = self.exponent + (suffixPower * 3) -- Each suffix = 10^3
end

function BigNum:_normalize()
	if self.mantissa == 0 then
		self.exponent = 0
		return
	end

	-- Keep mantissa between 1 and 10 (or -10 and -1)
	while math.abs(self.mantissa) >= 10 do
		self.mantissa = self.mantissa / 10
		self.exponent = self.exponent + 1
	end

	while math.abs(self.mantissa) < 1 and self.mantissa ~= 0 do
		self.mantissa = self.mantissa * 10
		self.exponent = self.exponent - 1
	end
end

--// Conversion Methods //--

function BigNum:toStorageString(): string
	-- Returns full-precision scientific notation for storage
	-- This preserves all precision: "6.712e12"
	if self.mantissa == 0 then
		return "0"
	end

	-- Format with maximum precision
	return string.format("%.15ge%d", self.mantissa, self.exponent)
end

function BigNum.fromStorageString(str: string): BigNum
	-- Alias for constructor, but explicit about purpose
	return BigNum.new(str)
end

-- Remove trailing zeros after decimal point
local function trimZeros(str)
	str = str:gsub("(%..-)0+$", "%1")
	-- Remove decimal point if no decimals remain
	str = str:gsub("%.$", "")
	return str
end

function BigNum:toString(decimals: number?): string
	-- Display format with suffixes (e.g., "67.12T")
	decimals = decimals or 2
	if self.mantissa == 0 then
		return "0"
	end

	-- Calculate the full value first
	local fullValue = self.mantissa * (10 ^ self.exponent)

	-- Determine suffix based on absolute value
	local absValue = math.abs(fullValue)
	local suffixIndex = 0

	-- Find appropriate suffix
	if absValue >= 1000 then
		suffixIndex = math.floor(math.log10(absValue) / 3)
	end

	if suffixIndex <= 0 then
		-- No suffix needed
		if absValue >= 1000 then
			-- Use K suffix
			local displayValue = fullValue / 1000
			local multiplier = 10 ^ decimals
			displayValue = math.floor(displayValue * multiplier) / multiplier
			local formatted = string.format(`%.{decimals}f`, displayValue)
			return trimZeros(formatted) .. "K"
		else
			local multiplier = 10 ^ decimals
			fullValue = math.floor(fullValue * multiplier) / multiplier
			local formatted = string.format(`%.{decimals}f`, fullValue)
			return trimZeros(formatted)
		end
	end

	if suffixIndex > #SUFFIXES then
		-- Beyond max suffix, use scientific notation
		return string.format(`%.{decimals}fe%d`, self.mantissa, self.exponent)
	end

	-- Calculate display value by dividing by the suffix power
	local divisor = 10 ^ (suffixIndex * 3)
	local displayValue = fullValue / divisor
	local suffix = SUFFIXES[suffixIndex]

	-- Floor to desired decimal places instead of rounding
	local multiplier = 10 ^ decimals
	displayValue = math.floor(displayValue * multiplier) / multiplier

	local formatted = string.format(`%.{decimals}f`, displayValue)
	return trimZeros(formatted) .. suffix
end

function BigNum:toNumber(): number
	-- Convert to regular number (may lose precision or return inf)
	return self.mantissa * (10 ^ self.exponent)
end

function BigNum:toOrderedDataStore(): number
	-- Convert to INTEGER for OrderedDataStore (returns whole numbers only)
	if self.mantissa == 0 then return 0 end

	local sign = self.mantissa < 0 and -1 or 1
	local absValue = math.abs(self.mantissa) * (10 ^ self.exponent)

	-- If within safe range, return directly (as integer)
	if absValue < MAX_SAFE_INTEGER then
		return sign * math.floor(absValue)
	end

	-- For very large numbers, encode as INTEGER using formula:
	-- encoded = sign * floor(1e15 + exponent * 1000 + (mantissa - 1) * 100)
	-- This gives us ~3 decimal places of mantissa precision encoded as integer
	local mantissaEncoded = math.floor((math.abs(self.mantissa) - 1) * 100)
	local encoded = 1e15 + self.exponent * 1000 + mantissaEncoded

	return sign * math.floor(encoded)
end

function BigNum.fromOrderedDataStore(value: number): BigNum
	local sign = value < 0 and -1 or 1
	local absValue = math.abs(value)

	-- Check if it's an encoded value
	if absValue >= 1e15 then
		-- Decode the integer-encoded value
		local encoded = absValue - 1e15
		local exponent = math.floor(encoded / 1000)
		local mantissaEncoded = encoded % 1000
		local mantissa = sign * (1 + mantissaEncoded / 100)

		local bn = BigNum.new(0)
		bn.mantissa = mantissa
		bn.exponent = exponent
		bn:_normalize()
		return bn
	else
		-- Regular number
		return BigNum.new(value)
	end
end

--// Arithmetic Operations //--

function BigNum:add(other: BigNum | number): BigNum
	other = BigNum.new(other)

	if self.mantissa == 0 then return BigNum.new(other) end
	if other.mantissa == 0 then return BigNum.new(self) end

	-- Align exponents for high precision
	local expDiff = self.exponent - other.exponent

	if math.abs(expDiff) > 15 then
		-- One number is insignificant compared to the other
		return expDiff > 0 and BigNum.new(self) or BigNum.new(other)
	end

	-- Use the larger exponent as base
	local baseExp = math.max(self.exponent, other.exponent)
	local m1 = self.mantissa * (10 ^ (self.exponent - baseExp))
	local m2 = other.mantissa * (10 ^ (other.exponent - baseExp))

	local result = BigNum.new(0)
	result.mantissa = m1 + m2
	result.exponent = baseExp
	result:_normalize()

	return result
end

function BigNum:subtract(other: BigNum | number): BigNum
	other = BigNum.new(other)

	if self.mantissa == 0 then 
		local result = BigNum.new(other)
		result.mantissa = -result.mantissa
		return result
	end
	if other.mantissa == 0 then return BigNum.new(self) end

	-- Same logic as add but subtract
	local expDiff = self.exponent - other.exponent

	if math.abs(expDiff) > 15 then
		return expDiff > 0 and BigNum.new(self) or BigNum.new(other)
	end

	local baseExp = math.max(self.exponent, other.exponent)
	local m1 = self.mantissa * (10 ^ (self.exponent - baseExp))
	local m2 = other.mantissa * (10 ^ (other.exponent - baseExp))

	local result = BigNum.new(0)
	result.mantissa = m1 - m2
	result.exponent = baseExp
	result:_normalize()

	return result
end

function BigNum:multiply(other: BigNum | number): BigNum
	other = BigNum.new(other)

	local result = BigNum.new(0)
	result.mantissa = self.mantissa * other.mantissa
	result.exponent = self.exponent + other.exponent
	result:_normalize()

	return result
end

function BigNum:divide(other: BigNum | number): BigNum
	other = BigNum.new(other)

	if other.mantissa == 0 then
		error("Division by zero")
	end

	local result = BigNum.new(0)
	result.mantissa = self.mantissa / other.mantissa
	result.exponent = self.exponent - other.exponent
	result:_normalize()

	return result
end

function BigNum:power(exponent: number): BigNum
	if exponent == 0 then return BigNum.new(1) end
	if self.mantissa == 0 then return BigNum.new(0) end

	-- Use logarithms: (a * 10^b)^c = a^c * 10^(b*c)
	local newMantissa = math.pow(math.abs(self.mantissa), exponent)
	local newExponent = self.exponent * exponent

	-- Handle negative bases with odd exponents
	if self.mantissa < 0 and exponent % 2 == 1 then
		newMantissa = -newMantissa
	end

	local result = BigNum.new(0)
	result.mantissa = newMantissa
	result.exponent = newExponent
	result:_normalize()

	return result
end

function BigNum:floor(): BigNum
	local value = self:toNumber()
	if value < MAX_SAFE_INTEGER then
		return BigNum.new(math.floor(value))
	end

	-- For very large numbers, floor doesn't matter much
	return BigNum.new(self)
end

function BigNum:ceil(): BigNum
	local value = self:toNumber()
	if value < MAX_SAFE_INTEGER then
		return BigNum.new(math.ceil(value))
	end

	return BigNum.new(self)
end

function BigNum:abs(): BigNum
	local result = BigNum.new(self)
	result.mantissa = math.abs(result.mantissa)
	return result
end

--// Comparison Operations //--

function BigNum:equals(other: BigNum | number): boolean
	other = BigNum.new(other)

	if math.abs(self.exponent - other.exponent) > 0 then
		return false
	end

	return math.abs(self.mantissa - other.mantissa) < EPSILON
end

function BigNum:lessThan(other: BigNum | number): boolean
	other = BigNum.new(other)

	if self.exponent ~= other.exponent then
		return self.exponent < other.exponent
	end

	return self.mantissa < other.mantissa
end

function BigNum:lessThanOrEquals(other: BigNum | number): boolean
	return self:lessThan(other) or self:equals(other)
end

function BigNum:greaterThan(other: BigNum | number): boolean
	return not self:lessThanOrEquals(other)
end

function BigNum:greaterThanOrEquals(other: BigNum | number): boolean
	return not self:lessThan(other)
end

--// Utility Methods //--

function BigNum:clone(): BigNum
	return BigNum.new(self)
end

function BigNum:isZero(): boolean
	return self.mantissa == 0
end

function BigNum:isNegative(): boolean
	return self.mantissa < 0
end

function BigNum:isPositive(): boolean
	return self.mantissa > 0
end

--// Static Helper Functions //--

function BigNum.max(a: BigNum | number, b: BigNum | number)
	a = BigNum.new(a)
	b = BigNum.new(b)
	return a:greaterThan(b) and a or b
end

function BigNum.min(a: BigNum | number, b: BigNum | number)
	a = BigNum.new(a)
	b = BigNum.new(b)
	return a:lessThan(b) and a or b
end

function BigNum.clamp(value: BigNum | number, min: BigNum | number, max: BigNum | number)
	value = BigNum.new(value)
	min = BigNum.new(min)
	max = BigNum.new(max)

	if value:lessThan(min) then return min end
	if value:greaterThan(max) then return max end
	return value
end

--// Metamethods //--

function BigNum:__tostring(): string
	return self:toString()
end

function BigNum:__add(other) : BigNum
	return self:add(other)
end

function BigNum:__sub(other) : BigNum
	return self:subtract(other)
end

function BigNum:__mul(other) : BigNum
	return self:multiply(other)
end

function BigNum:__div(other) : BigNum
	return self:divide(other)
end

function BigNum:__pow(other) : BigNum
	if type(other) == "number" then
		return self:power(other)
	end
	error("Power exponent must be a number")
end

function BigNum:__unm()
	local result = BigNum.new(self)
	result.mantissa = -result.mantissa
	return result
end

function BigNum:__eq(other)
	return self:equals(other)
end

function BigNum:__lt(other)
	return self:lessThan(other)
end

function BigNum:__le(other)
	return self:lessThanOrEquals(other)
end

--// Export //--

return BigNum :: BigNumModule