type Format = "Compact" | "Extended"

local callbacks = {
	["Compact"] = function(seconds: number): string
		local hours = math.floor(seconds / 3600)
		local minutes = math.floor((seconds % 3600) / 60)
		local secs = seconds % 60

		if hours > 0 then
			return string.format("%d:%02d:%02d", hours, minutes, secs)
		else
			return string.format("%02d:%02d", minutes, secs)
		end
	end,
	["Extended"] = function(seconds)
		local days = math.floor(seconds / 86400)
		local hours = math.floor((seconds % 86400) / 3600)
		local minutes = math.floor((seconds % 3600) / 60)
		local secs = seconds % 60

		local parts = {}

		if days > 0 then
			table.insert(parts, days .. "d")
		end
		if hours > 0 then
			table.insert(parts, hours .. "h")
		end
		if minutes > 0 then
			table.insert(parts, minutes .. "m")
		end

		if secs > 0 or #parts == 0 then
			table.insert(parts, secs .. "s")
		end

		return table.concat(parts, " ")
	end,
} :: { [Format]: (number) -> string }

-- Formats a number of seconds into a time string.
local function formatTime(seconds: number, format: Format?): string
	format = format or "Compact"
	seconds = math.max(0, math.floor(seconds))

	return callbacks[format](seconds)
end

return formatTime
