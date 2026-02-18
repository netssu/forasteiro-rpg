return {

	Easy = { -- 25 rounds, low count / learning
		["1"]  = {"Scout", "Scout", "Soldier"},
		["2"]  = {"Soldier", "Soldier", "Scout", "Skeleton"},
		["3"]  = {"Heavy", "Soldier", "Soldier", "Soldier"},
		["4"]  = {"Heavy", "Scout", "Scout", "Skeleton", "Heavy", "Soldier"},

		["5"]  = {"Heavy", "Scout","Ghost", "TNT", "TNT"},
		["6"]  = {"Heavy", "TNT", "TNT", "TNT", "TNT", "Soldier", "Soldier"},
		["7"]  = {"Scout", "Heavy", "Heavy", "Soldier", "Soldier"},
		["8"]  = {"Heavy", "Soldier", "Scout", "Scout", "TNT", "Ghost", "Ghost"},
		["9"]  = {"Heavy", "Ghost", "Soldier", "Ghost", "Scout", "Ghost"},
		["10"] = {"Boss", "Heavy", "Soldier", "Ghost", "Ghost"},
	},

	Medium = { -- 28 rounds, more variety, still low counts
		["1"]  = {"Scout", "Scout", "Heavy", "Soldier", "Soldier"},
		["2"]  = {"Heavy", "Scout", "Scout", "Ghost", "Heavy"},
		["3"]  = {"Heavy", "Soldier", "TNT", "TNT", "Heavy"},
		["4"]  = {"Heavy", "Soldier", "Scientist", "Heavy"},

		["5"]  = {"Scientist", "Heavy Ghost", "Scientist"},
		["6"]  = {"Skeleton", "Heavy", "Heavy Ghost", "Scientist", "Scientist"},
		["7"]  = {"Scout", "Ghost", "Heavy", "Ghost", "Scientist", "Ghost"},
		["8"]  = {"Heavy", "Scientist", "Scientist", "Scientist"},
		["9"]  = {"Heavy", "Scout", "Heavy", "Soldier", "Soldier"},
		["10"] = {"Boss", "Heavy", "Scientist"},

		["11"] = {"Heavy", "Scientist", "Ghost", "Heavy"},
		["12"] = {"Ghost", "Ghost", "Ghost", "Ghost", "Ghost", "Ghost"},
		["13"] = {"Heavy", "Heavy", "Scientist", "Ghost"},
		["14"] = {"Heavy", "Heavy", "Scientist", "Ghost", "Soldier"},
		["15"] = {"Heavy", "Heavy", "Scientist", "Ghost", "Skeleton Boss"},
	},

	Hard = { -- 30 rounds, 2–6 enemies, bosses more common
		["1"]  = {"Scout", "Scout", "Heavy", "Heavy"},
		["2"]  = {"Armored Soldier", "Heavy", "Scientist", "Scientist"},
		["3"]  = {"Armored Soldier", "Ghost", "Ghost", "Armored Soldier"},
		["4"]  = {"Armored Soldier", "Heavy", "Armored Soldier", "Soldier"},

		["5"]  = {"Boss", "Armored Soldier", "Scientist", "TNT", "TNT"},
		["6"]  = {"Heavy", "Armored Soldier", "Scientist", "Ghost"},
		["7"]  = {"Heavy", "Armored Soldier", "Ghost"},
		["8"]  = {"Heavy", "Armored Soldier", "Ghost", "TNT"},
		["9"]  = {"Heavy", "Armored Soldier", "Scientist", "Ghost"},
		["10"] = {"Heavy", "Armored Soldier", "Scientist", "Ghost", "Boss"},

		["11"] = {"Heavy", "Armored Soldier", "Scientist", "Ghost"},
		["12"] = {"Heavy", "Armored Soldier", "Scientist", "Ghost", "Boss"},
		["13"] = {"Heavy", "Armored Soldier", "Scientist", "Ghost", "Soldier"},
		["14"] = {"Heavy", "Armored Soldier", "Scientist", "Ghost", "Soldier", "Skeleton"},
		["15"] = {"Heavy", "Armored Soldier", "Scientist", "Ghost", "Soldier", "Skeleton", "Skeleton Boss"},

		["16"] = {"Heavy", "Heavy", "Armored Soldier", "Scientist"},
		["17"] = {"Heavy", "Heavy", "Armored Soldier", "Scientist", "Ghost"},
		["18"] = {"Heavy", "Heavy", "Armored Soldier", "Scientist", "Ghost"},
		["19"] = {"Heavy", "Heavy", "Armored Soldier", "Scientist", "Ghost", "TNT"},
		["20"] = {"Heavy", "Heavy", "Armored Soldier", "Scientist", "Ghost", "TNT", "Molten Boss"},
	},

	Impossible = { -- 35 rounds, low count but very chunky enemies
		["1"]  = {"Heavy", "Armored Soldier", "Scientist"},
		["2"]  = {"Heavy", "Armored Soldier", "Scientist", "Ghost"},
		["3"]  = {"Heavy", "Armored Soldier", "Armored Heavy"},
		["4"]  = {"Heavy", "Armored Soldier", "Armored Heavy", "Boss"},

		["5"]  = {"Heavy", "Armored Soldier", "Armored Heavy", "Scientist"},
		["6"]  = {"Heavy", "Armored Soldier", "Armored Heavy", "Scientist", "Ghost"},
		["7"]  = {"Heavy", "Armored Soldier", "Armored Heavy", "Ghost"},
		["8"]  = {"Heavy", "Armored Soldier", "Armored Heavy", "Ghost", "Boss"},
		["9"]  = {"Heavy", "Heavy", "Armored Soldier", "Armored Heavy"},
		["10"] = {"Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Boss", "Skeleton Boss"},

		["11"] = {"Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Scientist"},
		["12"] = {"Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Scientist", "Boss", "Skeleton Boss"},
		["13"] = {"Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Scientist", "Skeleton", "Boss", "Skeleton Boss"},
		["14"] = {"Heavy", "Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Scientist", "Boss", "Skeleton Boss"},
		["15"] = {"Heavy", "Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Scientist", "Boss", "Skeleton Boss"},

		["16"] = {"Heavy", "Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Scientist", "Boss", "Skeleton Boss"},
		["17"] = {"Heavy", "Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Scientist", "Boss", "Skeleton Boss"},
		["18"] = {"Heavy", "Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Scientist", "Boss", "Skeleton Boss", "Molten Boss"},
		["19"] = {"Heavy", "Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Scientist", "Boss", "Boss", "Skeleton Boss", "Molten Boss"},
		["20"] = {"Heavy", "Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Scientist", "Boss", "Boss", "Skeleton Boss", "Molten Boss"},

		["21"] = {"Heavy", "Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Ghost", "Boss", "Boss", "Skeleton Boss", "Molten Boss"},
		["22"] = {"Heavy", "Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Ghost", "Boss", "Boss", "Skeleton Boss", "Molten Boss"},
		["23"] = {"Heavy", "Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Ghost", "Boss", "Boss", "Skeleton Boss", "Molten Boss", "Molten Boss"},
		["24"] = {"Heavy", "Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Ghost", "Boss", "Boss", "Skeleton Boss", "Molten Boss", "Molten Boss"},
		["25"] = {"Heavy", "Heavy", "Heavy", "Armored Soldier", "Armored Heavy", "Ghost", "Boss", "Boss", "Skeleton Boss", "Molten Boss", "Molten Boss"},
	},

}
