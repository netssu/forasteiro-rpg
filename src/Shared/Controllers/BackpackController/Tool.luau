local module = {}

-- // Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- // Dependencies
local Janitor = require(ReplicatedStorage.Packages.Janitor)

-- // Variables
local Janitors = {}

-- // Public Functions
function module:Equip(tool: Tool, character: Model)
	if not character then return end

	local rightHand = character:FindFirstChild('RightHand')
	if not rightHand or not rightHand:IsA('BasePart') then return end

	if Janitors[character] then Janitors[character]:Cleanup() end

	Janitors[character] = Janitor.new()
	local JanitorModel = Janitors[character]
	local toolModel = ReplicatedStorage.Assets.Tools:FindFirstChild(tool.Name)

	if not toolModel then return end

	local toolClone = toolModel:Clone() :: Model
	toolClone.Parent = workspace.Map.Debris

	local gripEnd = toolClone:FindFirstChild('Handle', true)
	if not gripEnd or not gripEnd:IsA('BasePart') then
		toolClone:Destroy()
		return
	end

	for _, child in toolClone:GetDescendants() do
		if
			child:IsA('Motor6D')
			or child:IsA('WeldConstraint')
			or child:IsA('Weld')
		then
			child:Destroy()
		end
	end

	for _, child in toolClone:GetDescendants() do
		if child:IsA('BasePart') then
			child.CanCollide = false
			child.Massless = false
			child.Anchored = false

			if child ~= toolClone.PrimaryPart then
				local weld = Instance.new('WeldConstraint')
				weld.Part0 = child
				weld.Part1 = gripEnd
				weld.Parent = child
			end
		end
	end

	if not toolClone.PrimaryPart then toolClone.PrimaryPart = gripEnd end

	toolClone:PivotTo(rightHand.CFrame)

	local Weld = Instance.new('WeldConstraint')
	Weld.Part0 = gripEnd
	Weld.Part1 = rightHand
	Weld.Parent = gripEnd

	JanitorModel:Add(toolClone, 'Destroy')

	Janitors[character]:Add(
		character.AncestryChanged:Connect(function(_, a1: Instance?)
			if a1 and not a1.Parent then
				Janitors[character]:Destroy()
				Janitors[character] = nil
			end
		end),
		'Disconnect'
	)
end

function module:Unequip(character: Model)
	if Janitors[character] then Janitors[character]:Cleanup() end
end

return module
