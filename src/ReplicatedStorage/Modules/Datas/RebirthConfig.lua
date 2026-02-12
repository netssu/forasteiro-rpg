------------------//VARIABLES
local RebirthConfig = {}

------------------//CONSTANTS
RebirthConfig.BASE_COINS_REQ = 500
RebirthConfig.BASE_POWER_REQ = 250
RebirthConfig.COIN_SCALING = 1.8
RebirthConfig.POWER_SCALING = 1.2
RebirthConfig.TOKENS_PER_REBIRTH = 1
RebirthConfig.POWER_RESET_VALUE = 120

------------------//FUNCTIONS
function RebirthConfig.GetRequirement(currentRebirths: number)
	local coinsReq = math.floor(RebirthConfig.BASE_COINS_REQ * (RebirthConfig.COIN_SCALING ^ currentRebirths))
	local powerReq = math.floor(RebirthConfig.BASE_POWER_REQ * (RebirthConfig.POWER_SCALING ^ currentRebirths))
	return coinsReq, powerReq
end

return RebirthConfig