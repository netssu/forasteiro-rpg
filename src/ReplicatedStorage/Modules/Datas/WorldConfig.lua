local WorldConfig = {}

local BASE_GRAVITY = 196.2

WorldConfig.WORLDS = {
	{
		id = 1,
		name = "Core World",
		theme = "Plains",
		gravityMult = 1.5, -- Base
		entryCFrame = CFrame.new(-153.513, 15.378, -264.909),
		requiredPogoPower = 0,
		requiredRebirths = 0,
	},
	{
		id = 2,
		name = "Cloud Paradise",
		theme = "Sky",
		gravityMult = 3.00, 
		entryCFrame = CFrame.new(98095.406, 37.179, -212.693),
		requiredPogoPower = 450, -- Aumentei o requisito
		requiredRebirths = 0,
	},
	{
		id = 3,
		name = "Frost Peaks",
		theme = "Snow",
		gravityMult = 7.50, -- Escala rápida
		entryCFrame = CFrame.new(873019.25, 56.641, -4744.422),
		requiredPogoPower = 1200,
		requiredRebirths = 1,
	},
	{
		id = 4,
		name = "Jungle Rise",
		theme = "Jungle",
		gravityMult = 15.00,
		entryCFrame = CFrame.new(-119376.766, 7.532, -51.993),
		requiredPogoPower = 3500,
		requiredRebirths = 2,
	},
	{
		id = 5,
		name = "Volcanic Rift",
		theme = "Volcano",
		gravityMult = 30.00, -- Gravidade esmagadora
		entryCFrame = CFrame.new(1058227.125, 33.289, 77.999),
		requiredPogoPower = 8500,
		requiredRebirths = 3,
	},
}

function WorldConfig.GetWorld(id: number)
	for _, w in WorldConfig.WORLDS do
		if w.id == id then return w end
	end
	return WorldConfig.WORLDS[1]
end

function WorldConfig.GetNextWorld(currentId: number)
	return WorldConfig.GetWorld(currentId + 1)
end

return WorldConfig