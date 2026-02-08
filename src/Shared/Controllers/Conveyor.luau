local module = {}

-- // Services
local CollectionService = game:GetService('CollectionService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

-- // Variables
local activeCandies = {}

-- // Private Functions
local function createCandie(Data: {}) end

-- // Public Functions
function module:Init()
	-- Connections
	CollectionService:GetInstanceAddedSignal('Candy'):Connect(function(candy)
		activeCandies[candy] = true
	end)

	CollectionService:GetInstanceRemovedSignal('Candy'):Connect(function(candy)
		activeCandies[candy] = nil
	end)

	for _, candy in ipairs(CollectionService:GetTagged('Candy')) do
		activeCandies[candy] = true
	end
end

function module:Start()
	RunService.Heartbeat:Connect(function(a0: number)
		for candy in activeCandies do
			if not candy or not candy.Parent then
				activeCandies[candy] = nil
				continue
			end

			local ray =
				workspace:Raycast(candy.Position, vector.create(0, -2, 0))

			if ray and CollectionService:HasTag(ray.Instance, 'Conveyor') then
				local conveyor = ray.Instance
				candy.CFrame = candy.CFrame
					+ (conveyor.CFrame.LookVector * 5 * a0)
			end
		end
	end)
end

return module
