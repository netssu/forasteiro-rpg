local Entity = workspace:FindFirstChild("Entity") or Instance.new("Folder")
Entity.Name = "Entity"
Entity.Parent = workspace

local BindedCharacters = {}

function FixAccessory(Accessory)
	for _, Part in Accessory:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.CanCollide = false
			Part.CanQuery = false
			Part.Massless = true
			Part.CanTouch = false
		end
	end
end

function BindCharacter(char)
	if table.find(BindedCharacters, char) then return end
	
	for _, Accessory in char:GetChildren() do
		if Accessory:IsA("Accessory") then
			FixAccessory(Accessory)
		end
	end
	
	char.ChildAdded:Connect(function(Accessory)
		if Accessory:IsA("Accessory") then
			FixAccessory(Accessory)
		end
	end)
	
	char.Destroying:Once(function()
		table.remove(BindedCharacters, table.find(BindedCharacters, char))
	end)
	
	table.insert(BindedCharacters, char)
end

for _, Entity in workspace.Entity:GetChildren() do
	BindCharacter(Entity)
end

Entity.ChildAdded:Connect(function(char)
	if char:IsA("Model") then
		BindCharacter(char)
	end
end)