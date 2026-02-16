local module = {}

-- // SERVICES
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- // DEPENDENCIES
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local WeaponData = require(ReplicatedStorage.Modules.Constants.WeaponsData)

-- // VARIABLES
local Janitors = {}

-- // PUBLIC FUNCTIONS
function module:Equip(tool: Tool, character: Model)
	if not character then return end

	local rightHand = character:FindFirstChild('RightHand')
	if not rightHand or not rightHand:IsA('BasePart') then return end

	local originalHandle = tool:FindFirstChild("Handle")
	if originalHandle and originalHandle:IsA("BasePart") then
		originalHandle.Transparency = 1
	end

	if Janitors[character] then Janitors[character]:Cleanup() end
	Janitors[character] = Janitor.new()

	local toolModel = ReplicatedStorage.Assets.Tools:FindFirstChild(tool.Name)
	if not toolModel then return end

	local toolClone = toolModel:Clone() :: Model
	toolClone.Parent = workspace.Map.Debris -- Ou workspace

	local gripEnd = toolClone:FindFirstChild('Handle', true)
	if not gripEnd or not gripEnd:IsA('BasePart') then
		toolClone:Destroy()
		return
	end

	for _, child in toolClone:GetDescendants() do
		if child:IsA('Motor6D') or child:IsA('WeldConstraint') or child:IsA('Weld') then
			child:Destroy()
		end
		if child:IsA('BasePart') then
			child.CanCollide = false
			child.Massless = true
			child.Anchored = false
			if child ~= gripEnd then
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

	Janitors[character]:Add(toolClone, 'Destroy')

	Janitors[character]:Add(character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			if Janitors[character] then
				Janitors[character]:Cleanup()
				Janitors[character] = nil
			end
		end
	end), 'Disconnect')
end

function module:Unequip(tool: Tool, character: Model)
	if Janitors[character] then 
		Janitors[character]:Cleanup() 
		Janitors[character] = nil
	end

	if tool then
		local originalHandle = tool:FindFirstChild("Handle")
		if originalHandle and originalHandle:IsA("BasePart") then
			originalHandle.Transparency = 0
		end
	end
end

return module