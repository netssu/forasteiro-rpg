--!strict

local Short = {}

--\\ NUMBER FORMATTING CONSTANTS \\ -- TR
local SUFFIXES = {"K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No"}
local ABBREVIATE_THRESHOLD = 1000

--\\ ABBREVIATE FUNCTION \\ -- TR
function Short:Abbreviate(Value: number, MinValue: number?, Decimals: number?): string
	local Threshold: number = if typeof(MinValue) == "number" then MinValue else ABBREVIATE_THRESHOLD
	local ProvidedPrecision: number? = if typeof(Decimals) == "number" then math.max(0, math.floor(Decimals)) else nil
	local Precision: number = ProvidedPrecision or 1
	local AbsValue: number = math.abs(Value)

	if AbsValue >= Threshold then
		local LogValue = math.log10(AbsValue)
		local Index = math.floor(LogValue / 3)
		local ScaledValue = AbsValue / (10 ^ (Index * 3))

		if Index >= 1 and Index <= #SUFFIXES then
			local Format = "%." .. tostring(Precision) .. "f"
			local Text = string.format(Format, ScaledValue)

			if Precision > 0 then
				local IntegerPart, FractionPart = Text:match("^(%-?%d+)%.(%d+)$")
				if IntegerPart and FractionPart then
					FractionPart = FractionPart:gsub("0+$", "")
					if FractionPart == "" then
						Text = IntegerPart
					else
						Text = IntegerPart .. "." .. FractionPart
					end
				end
			end

			if Value < 0 then
				Text = "-" .. Text
			end

			return Text .. SUFFIXES[Index]
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
