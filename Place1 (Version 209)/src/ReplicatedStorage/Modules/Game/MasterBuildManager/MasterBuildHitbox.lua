------------------//VARIABLES
local module = {}

------------------//FUNCTIONS
function module.sync_master_hitboxes(self): ()
	local permissions = self.modules.Permissions
	local hitboxesFolder = workspace:FindFirstChild("MasterHitboxes")

	if not permissions.can_use_character_drag(self) then
		if hitboxesFolder then
			hitboxesFolder:Destroy()
		end

		return
	end

	if not hitboxesFolder then
		hitboxesFolder = Instance.new("Folder")
		hitboxesFolder.Name = "MasterHitboxes"
		hitboxesFolder.Parent = workspace
	end

	local charsFolder = workspace:FindFirstChild("Characters")
	if not charsFolder then
		return
	end

	local processed = {}
	local hitboxesByChar = {}

	for _, hb in hitboxesFolder:GetChildren() do
		local targetVal = hb:FindFirstChild("TargetCharacter")

		if targetVal and targetVal:IsA("ObjectValue") and targetVal.Value then
			hitboxesByChar[targetVal.Value] = hb
		end
	end

	for _, charObj in charsFolder:GetChildren() do
		if charObj:IsA("Model") then
			processed[charObj] = true

			local rootPart = charObj:FindFirstChild("HumanoidRootPart")

			if rootPart and rootPart:IsA("BasePart") then
				local hitbox = hitboxesByChar[charObj]

				if not hitbox then
					hitbox = Instance.new("Part")
					hitbox.Name = "Hitbox"
					hitbox.Size = Vector3.new(5, 7, 3)
					hitbox.Transparency = 1
					hitbox.CanCollide = false
					hitbox.CanQuery = true
					hitbox.Massless = true
					hitbox.Shape = Enum.PartType.Block

					local targetVal = Instance.new("ObjectValue")
					targetVal.Name = "TargetCharacter"
					targetVal.Value = charObj
					targetVal.Parent = hitbox

					hitbox.Parent = hitboxesFolder
				end

				hitbox.CFrame = rootPart.CFrame
			end
		end
	end

	for _, hb in hitboxesFolder:GetChildren() do
		local targetVal = hb:FindFirstChild("TargetCharacter")

		if not targetVal or not targetVal:IsA("ObjectValue") or not targetVal.Value or not processed[targetVal.Value] then
			hb:Destroy()
		end
	end
end

return module