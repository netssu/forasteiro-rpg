--!strict

local Short = {}

--\\ NUMBER FORMATTING CONSTANTS \\ -- TR
local SUFFIXES = {"K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No"}
local ABBREVIATE_THRESHOLD = 1000000

--\\ ABBREVIATE FUNCTION \\ -- TR
function Short:Abbreviate(Value: number): string
	if Value >= ABBREVIATE_THRESHOLD then
		local LogValue = math.log10(Value)
		local Index = math.floor(LogValue / 3)
		local ScaledValue = Value / (10 ^ (Index * 3))

		if Index <= #SUFFIXES then
			return string.format("%.1f%s", ScaledValue, SUFFIXES[Index])
		end
	end

	return tostring(Value)
end

--\\ COMMAS FUNCTION \\ -- TR
function Short:Commas(Value: number): string
	local StringValue = tostring(math.floor(Value))
	local Length = #StringValue

	local Result = ""
	for i = 1, Length do
		if i > 1 and (Length - i + 1) % 3 == 0 then
			Result = Result .. ","
		end
		Result = Result .. StringValue:sub(i, i)
	end

	return Result
end

return Short