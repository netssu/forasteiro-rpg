------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

------------------//CONSTANTS
local DATA_UTILITY = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local DATA_PETS = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PetsData"))

local PET_DISTANCE = 6      -- Distância para trás
local PET_SIDE_OFFSET = 4   -- Distância para os lados (ajustei para ficarem bem separados)
local FLY_HEIGHT = 3
local BOBBING_SPEED = 4
local BOBBING_AMPLITUDE = 0.5
local FLY_BOBBING_AMPLITUDE = 0.5
local ALIGN_RESPONSIVENESS = 25
local ALIGN_MAX_FORCE = 25000
local ALIGN_MAX_VELOCITY = 40
local ROTATION_RESPONSIVENESS = 80
local ROTATION_MAX_TORQUE = 15000
local ROTATION_MAX_ANGULAR_VELOCITY = 20
local TELEPORT_DISTANCE = 60

------------------//VARIABLES
local activePets = {}

------------------//FUNCTIONS
local function get_model_size(model)
	if model:IsA("BasePart") then return model.Size end
	local cf, size = model:GetBoundingBox()
	return size
end

local function create_pet_holder(character)
	local hrp = character:WaitForChild("HumanoidRootPart")

	local holder = Instance.new("Part")
	holder.Name = "PetHolder"
	holder.Transparency = 1
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Massless = true
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = hrp.CFrame
	holder.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = holder
	weld.Parent = holder

	return holder
end

local function create_pet_physics(petObject, petRoot, character, isFlying, fixRotation, slotIndex)
	local hrp = character:WaitForChild("HumanoidRootPart")
	local humanoid = character:WaitForChild("Humanoid")

	local holder = character:FindFirstChild("PetHolder") or create_pet_holder(character)

	local charAttachment = Instance.new("Attachment")
	charAttachment.Name = "PetTargetAttachment"
	charAttachment.Parent = holder

	local petAttachment = Instance.new("Attachment")
	petAttachment.Name = "PetBaseAttachment"
	petAttachment.Parent = petRoot

	local alignPos = Instance.new("AlignPosition")
	alignPos.Mode = Enum.PositionAlignmentMode.TwoAttachment
	alignPos.Attachment0 = petAttachment
	alignPos.Attachment1 = charAttachment
	alignPos.Responsiveness = ALIGN_RESPONSIVENESS
	alignPos.MaxForce = ALIGN_MAX_FORCE
	alignPos.MaxVelocity = ALIGN_MAX_VELOCITY
	alignPos.Parent = petRoot

	local alignRot = Instance.new("AlignOrientation")
	alignRot.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignRot.Attachment0 = petAttachment
	alignRot.Responsiveness = ROTATION_RESPONSIVENESS
	alignRot.MaxTorque = ROTATION_MAX_TORQUE
	alignRot.MaxAngularVelocity = ROTATION_MAX_ANGULAR_VELOCITY
	alignRot.Parent = petRoot

	local petSize = get_model_size(petObject)
	local petHalfHeight = petSize.Y / 2

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {petObject, character}

	task.spawn(function()
		local t = 0
		while petObject.Parent and character.Parent do
			local dt = task.wait()
			t = t + dt * BOBBING_SPEED

			local bobbingX = math.cos(t) * BOBBING_AMPLITUDE
			local offsetX, offsetZ

			-- LÓGICA CORRIGIDA AQUI
			-- Ambos usam PET_DISTANCE positivo para ficarem atrás
			-- O OffsetX define se é esquerda ou direita
			if slotIndex == 1 then
				-- Pet 1: Direita e Atrás
				offsetX = (PET_SIDE_OFFSET) + (bobbingX * 0.2)
				offsetZ = PET_DISTANCE 
			elseif slotIndex == 2 then
				-- Pet 2: Esquerda e Atrás
				offsetX = -(PET_SIDE_OFFSET) - (bobbingX * 0.2)
				offsetZ = PET_DISTANCE -- Antes estava -PET_DISTANCE (isso jogava pra frente)
			else
				-- Caso tenha mais pets, joga eles mais pra trás ou alterna
				offsetX = (PET_SIDE_OFFSET * (slotIndex % 2 == 0 and -1 or 1))
				offsetZ = PET_DISTANCE + (math.floor(slotIndex/3) * 3) 
			end

			local targetY

			if isFlying then
				targetY = FLY_HEIGHT + (math.sin(t) * FLY_BOBBING_AMPLITUDE)
			else
				local holderCFrame = holder.CFrame
				-- ToWorldSpace converte o offset local (atrás do player) para posição no mundo
				local targetWorldPos = holderCFrame:ToWorldSpace(CFrame.new(offsetX, 0, offsetZ)).Position

				local rayOrigin = targetWorldPos + Vector3.new(0, 10, 0)
				local rayDirection = Vector3.new(0, -20, 0)

				local rayResult = Workspace:Raycast(rayOrigin, rayDirection, rayParams)

				if rayResult then
					local groundY = rayResult.Position.Y
					local playerY = hrp.Position.Y
					targetY = (groundY - playerY) + petHalfHeight
				else
					local currentHipHeight = humanoid.HipHeight
					if currentHipHeight == 0 then currentHipHeight = 2 end
					targetY = -currentHipHeight + petHalfHeight
				end
			end

			charAttachment.Position = Vector3.new(offsetX, targetY, offsetZ)

			local playerLookVector = hrp.CFrame.LookVector
			local petPos = petRoot.Position
			local forwardPoint = petPos + (playerLookVector * 10)
			local targetRotation = CFrame.lookAt(petPos, Vector3.new(forwardPoint.X, petPos.Y, forwardPoint.Z))

			if fixRotation then
				targetRotation = targetRotation * CFrame.Angles(0, math.pi, 0)
			end

			alignRot.CFrame = targetRotation

			if (petRoot.Position - hrp.Position).Magnitude > TELEPORT_DISTANCE then
				petObject:PivotTo(hrp.CFrame)
			end
		end
	end)
end

local function update_pet_multiplier(player)
	local equippedPetsRaw = DATA_UTILITY.server.get(player, "EquippedPets")
	local equippedPets = {}

	if type(equippedPetsRaw) == "string" then
		if equippedPetsRaw ~= "" then
			equippedPets = {[1] = equippedPetsRaw}
		end
	elseif type(equippedPetsRaw) == "table" then
		equippedPets = equippedPetsRaw
	end

	local totalMultiplier = 1

	for _, petName in pairs(equippedPets) do
		if petName and petName ~= "" then
			local petData = DATA_PETS.GetPetData(petName)
			if petData and petData.Multiplier then
				totalMultiplier = totalMultiplier + petData.Multiplier
			end
		end
	end

	player:SetAttribute("Multiplier", totalMultiplier)
end

local function spawn_pets(player)
	if activePets[player] then
		for _, petObj in pairs(activePets[player]) do
			petObj:Destroy()
		end
		activePets[player] = {}
	end

	local equippedPetsRaw = DATA_UTILITY.server.get(player, "EquippedPets")
	local equippedPets = {}

	if type(equippedPetsRaw) == "string" then
		if equippedPetsRaw ~= "" then
			equippedPets = {[1] = equippedPetsRaw}
			DATA_UTILITY.server.set(player, "EquippedPets", equippedPets)
		end
	elseif type(equippedPetsRaw) == "table" then
		equippedPets = equippedPetsRaw
	end

	update_pet_multiplier(player)

	local character = player.Character
	if not character then return end
	local hrp = character:WaitForChild("HumanoidRootPart")

	local petCount = 0
	-- Usar ipairs garante ordem se a tabela for array, mas pairs é mais seguro para dicionários mistos
	for slotIndex, petName in pairs(equippedPets) do
		if petName and petName ~= "" then
			local petData = DATA_PETS.GetPetData(petName)
			if petData and petData.Model then
				local newPet = petData.Model:Clone()
				newPet.Name = player.Name .. "_Pet_" .. slotIndex

				local petRoot
				if newPet:IsA("Model") then
					if not newPet.PrimaryPart then
						newPet.PrimaryPart = newPet:FindFirstChildWhichIsA("BasePart")
					end
					petRoot = newPet.PrimaryPart
					-- Spawn inicial atrás do player para evitar glitch visual
					newPet:PivotTo(hrp.CFrame * CFrame.new(0, 5, 5))
				elseif newPet:IsA("BasePart") then
					petRoot = newPet
					newPet.CFrame = hrp.CFrame * CFrame.new(0, 5, 5)
				end

				if petRoot then
					newPet.Parent = character

					create_pet_physics(
						newPet,
						petRoot,
						character,
						petData.IsFlying or false,
						petData.FixRotation or false,
						tonumber(slotIndex) -- Garante que slotIndex seja numero
					)

					local function setOwner(part)
						part.CanCollide = false
						part.Massless = true
						if not part.Anchored then
							part:SetNetworkOwner(player)
						end
					end

					for _, part in pairs(newPet:GetDescendants()) do
						if part:IsA("BasePart") then setOwner(part) end
					end
					if newPet:IsA("BasePart") then setOwner(newPet) end

					if not activePets[player] then
						activePets[player] = {}
					end
					activePets[player][slotIndex] = newPet

					petCount = petCount + 1
				else
					newPet:Destroy()
				end
			end
		end
	end
end

local function on_character_added(player, character)
	task.wait(1)
	spawn_pets(player)
end

local function on_player_added(player)
	if not player:GetAttribute("Multiplier") then
		player:SetAttribute("Multiplier", 1)
	end

	player.CharacterAdded:Connect(function(character)
		on_character_added(player, character)
	end)

	task.spawn(function()
		local connection = nil
		local attempts = 0

		while attempts < 20 and not connection do
			connection = DATA_UTILITY.server.bind(player, "EquippedPets", function(newVal)
				spawn_pets(player)
			end)

			if connection then
				break
			end

			attempts += 1
			task.wait(0.5)
		end

		if not connection then
			warn("[PetService] Falha ao conectar listener de pets para:", player.Name)
		end
	end)
end

local function on_player_removing(player)
	if activePets[player] then
		for _, petObj in pairs(activePets[player]) do
			petObj:Destroy()
		end
		activePets[player] = nil
	end
end

------------------//INIT
for _, player in ipairs(Players:GetPlayers()) do
	on_player_added(player)
	if player.Character then
		on_character_added(player, player.Character)
	end
end

Players.PlayerAdded:Connect(on_player_added)
Players.PlayerRemoving:Connect(on_player_removing)