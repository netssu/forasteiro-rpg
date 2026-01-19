-- ==============================================
-- nickibreeki's collection
-- (2020) - Timer Module
-- ==============================================

local Timer = {}

function Timer:Start()
	local subfunctions = {}
	local StartTime = os.clock()
	function subfunctions:End()
		local EndTime = os.clock()
		return EndTime - StartTime
	end
	return subfunctions
end

return Timer