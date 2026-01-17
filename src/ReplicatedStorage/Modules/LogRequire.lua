-- Most modules load so fast it appears instant. That is why this number is so low.
local MINIMUM_TIME_WARN = 0.05

return function(module)
	local LOG_INDENT_LINE = `[{module.Name}]`
	local status = {
		wasLoaded = false,
		startedAt = os.clock(),
	}

	print(`{LOG_INDENT_LINE} Loading...`)

	task.delay(MINIMUM_TIME_WARN, function()
		if not status.wasLoaded then
			warn(`{LOG_INDENT_LINE} Loading is taking longer than expected!`)
		end
	end)

	local result = require(module)
	status.endedAt = os.clock()
	status.took = status.endedAt - status.startedAt
	status.wasLoaded = true

	if status.took < MINIMUM_TIME_WARN then
		print(`{LOG_INDENT_LINE} Loaded. Took {string.format("%.2f", status.took)}s`)
	else
		status.overshot = status.endedAt - status.startedAt - MINIMUM_TIME_WARN

		warn(
			`{LOG_INDENT_LINE} Loaded. Took {string.format("%.2f", status.took)}s, which is {string.format(
				"%.2f",
				status.overshot
			)}s longer than expected!`
		)
	end

	return result
end
