export type reward = { type: string, value: number }
export type CodeConfig = {
	Rewards: { reward },
	OnUse: ((player: Player) -> boolean)?
}

return {
	--[[
	["sorryfordelay"] = {
		Rewards = {
			{type = "Cash", value = 10000},
			{type = "Plutonium", value = 10000}
		},
		OnUse = function()
			print("Get it lil beta 😭🙏")
			return true
		end,
	},
	]]--
} :: {CodeConfig}
