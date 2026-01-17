local Essentials = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

function Essentials.WeldPartsTogether(partOne, partTwo)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "essentialWeld"
	weld.Parent = partOne
	weld.Part0 = partOne
	weld.Part1 = partTwo
end

function Essentials.WeldAllPartsInModel(model, partToWeldTo)
	for _, part in pairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= partToWeldTo then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "essentialWeld"
			weld.Parent = partToWeldTo
			weld.Part0 = partToWeldTo
			weld.Part1 = part
		end
	end
end

function Essentials.HitBoxWeld(partOne, partTwo, Cframe)
	local weld = Instance.new("Weld")
	weld.Parent = partOne
	weld.Part0 = partOne
	weld.Part1 = partTwo
	weld.C0 = Cframe
	weld.Parent = partOne
end

function Essentials.Explosion(part)
	local explosion = Instance.new("Explosion")
	explosion.BlastPressure = 5000
	explosion.Position = part.Position
	explosion.Parent = workspace
end

function Essentials.PartToPart(partOne, PartTwo)
	partOne.Parent = PartTwo
	partOne.CFrame = PartTwo.CFrame
end

function Essentials.CleanUp(part, seconds)
	task.delay(seconds, function()
		part:Destroy()
	end)
end

function Essentials.PlaySound(sound, parent)
	local soundClone = sound:Clone()
	soundClone.Parent = parent
	soundClone:Play()
	Essentials.CleanUp(soundClone, soundClone.TimeLength)
end

function Essentials.PlaySoundLoop(sound, parent)
	local soundClone = sound:Clone()
	soundClone.Parent = parent
	soundClone:Play()
end

function Essentials.PlaySoundInSpace(sound, position)
	local soundHolder = Instance.new("Part")
	soundHolder.Anchored = true
	soundHolder.CanCollide = false
	soundHolder.Transparency = 1
	soundHolder.Position = position
	soundHolder.Size = Vector3.new(0.1, 0.1, 0.1)
	soundHolder.Parent = workspace

	local soundClone = sound:Clone()
	soundClone.Parent = soundHolder
	soundClone:Play()
	Essentials.CleanUp(soundHolder, soundClone.TimeLength)
end

function Essentials.PlaySoundRandomSpeed(sound, parent, number)
	local random = math.random(sound.PlaybackSpeed * 10, sound.PlaybackSpeed * 10 + number)
	local trueNumber = random * 0.1
	local soundClone = sound:Clone()
	soundClone.PlaybackSpeed = trueNumber
	soundClone.Parent = parent
	soundClone:Play()
	Essentials.CleanUp(soundClone, soundClone.TimeLength)
end

function Essentials.PlaySoundInSpaceRandomSpeed(sound, number, position)
	local soundHolder = Instance.new("Part")
	soundHolder.Anchored = true
	soundHolder.CanCollide = false
	soundHolder.Transparency = 1
	soundHolder.Position = position
	soundHolder.Size = Vector3.new(0.1, 0.1, 0.1)
	soundHolder.Parent = workspace

	local random = math.random(sound.PlaybackSpeed * 10, sound.PlaybackSpeed * 10 + number)
	local trueNumber = random * 0.1
	local soundClone = sound:Clone()
	soundClone.PlaybackSpeed = trueNumber
	soundClone.Parent = soundHolder
	soundClone:Play()
	Essentials.CleanUp(soundHolder, soundClone.TimeLength)
end

function Essentials.PlayAnimationAndStop(animator, anim)
	local animation = animator:LoadAnimation(anim)
	if not animation then
		return
	end
	animation:Play()
	animation.Stopped:Wait()
end

function Essentials.DamageDealer(hum: Humanoid, amount)
	if hum.Health <= amount then
		hum.Health -= hum.Health
	else
		hum.Health -= amount
	end
end

function Essentials.FormatTime(number)
	local minutes = math.floor(number / 60)
	local seconds = number % 60
	return string.format("%d:%02d", minutes, seconds)
end

function Essentials.GuiDisappear(gui, duration)
	local tweenInfo = TweenInfo.new(duration or 0.5, Enum.EasingStyle.Linear)
	for _, v in pairs(gui:GetDescendants()) do
		if v:IsA("Frame") then
			TweenService:Create(v, tweenInfo, { BackgroundTransparency = 1 }):Play()
		elseif v:IsA("ImageButton") or v:IsA("ImageLabel") then
			TweenService:Create(v, tweenInfo, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif v:IsA("TextLabel") then
			TweenService:Create(v, tweenInfo, { TextTransparency = 1 }):Play()
		elseif v:IsA("ViewportFrame") then
			TweenService:Create(v, tweenInfo, { ImageTransparency = 1 }):Play()
		end
	end
end

function Essentials.GuiReappear(gui, duration)
	local tweenInfo = TweenInfo.new(duration or 0.5, Enum.EasingStyle.Linear)
	for _, v in pairs(gui:GetDescendants()) do
		if v:IsA("Frame") then
			TweenService:Create(v, tweenInfo, { BackgroundTransparency = 0 }):Play()
		elseif v:IsA("ImageButton") or v:IsA("ImageLabel") then
			TweenService:Create(v, tweenInfo, { ImageTransparency = 0, BackgroundTransparency = 0 }):Play()
		elseif v:IsA("TextLabel") then
			TweenService:Create(v, tweenInfo, { TextTransparency = 0 }):Play()
		elseif v:IsA("ViewportFrame") then
			TweenService:Create(v, tweenInfo, { ImageTransparency = 0 }):Play()
		end
	end
end

function Essentials.DestroyPart(destroyerPart, maxDepth, minSize)
	maxDepth = maxDepth or 10
	minSize = minSize or 1
	local partsInBox = workspace:GetPartBoundsInBox(destroyerPart.CFrame, destroyerPart.Size)
	local affectedModels = {}
	local toDestroy = {}
	for _, hit in ipairs(partsInBox) do
		if hit.Parent and hit.Parent.Name == "Destructible" and hit ~= destroyerPart then
			local destructiblePart = hit
			local model = destructiblePart.Parent
			affectedModels[model] = true
			table.insert(toDestroy, { part = destructiblePart, model = model })
		end
	end
	for _, entry in ipairs(toDestroy) do
		local destructiblePart = entry.part
		local model = entry.model
		local originalColor = destructiblePart.Color
		local originalMaterial = destructiblePart.Material
		local originalTransparency = destructiblePart.Transparency
		local impactPoint = destructiblePart.CFrame:PointToObjectSpace(destroyerPart.Position)
		local destroyRadius = destroyerPart.Size.Magnitude / 2
		local effectCount = 0
		local maxEffects = 15 -- Limit total effects per part
		local function subdivide(center, size, depth)
			local distanceToImpact = (center - impactPoint).Magnitude
			local maxDim = math.max(size.X, size.Y, size.Z)
			local divisionsX = math.max(1, math.floor(size.X / minSize + 0.5))
			local divisionsY = math.max(1, math.floor(size.Y / minSize + 0.5))
			local divisionsZ = math.max(1, math.floor(size.Z / minSize + 0.5))
			local pieceX = size.X / 2
			local pieceY = size.Y / 2
			local pieceZ = size.Z / 2
			if pieceX < minSize and pieceY < minSize and pieceZ < minSize then
				if distanceToImpact < destroyRadius then
					local worldPosition = destructiblePart.CFrame * CFrame.new(center)
					print("Destroyed piece at:", worldPosition.Position)

					-- Only play effects for a limited number of pieces
					if effectCount < maxEffects then
						effectCount = effectCount + 1

						local vfx = ReplicatedStorage.Assets.VFX.StudDebris:Clone()
						vfx.Attachment.ParticleEmitter.Color = ColorSequence.new(originalColor)
						vfx.Position = worldPosition.Position
						vfx.Parent = workspace
						vfx.Attachment.ParticleEmitter:Emit(math.random(1, 2))

						Essentials.PlaySoundInSpaceRandomSpeed(
							ReplicatedStorage.Assets.Sounds.lego,
							3,
							worldPosition.Position
						)

						task.delay(3, function()
							vfx:Destroy()
						end)
					end

					return {}
				end
				local piece = Instance.new("Part")
				piece.Size = size
				piece.CFrame = destructiblePart.CFrame * CFrame.new(center)
				piece.Color = originalColor
				piece.Material = originalMaterial
				piece.Transparency = originalTransparency
				piece.CanCollide = true
				piece.Anchored = true
				piece.TopSurface = Enum.SurfaceType.Studs
				piece.BottomSurface = Enum.SurfaceType.Studs
				piece.LeftSurface = Enum.SurfaceType.Studs
				piece.RightSurface = Enum.SurfaceType.Studs
				piece.FrontSurface = Enum.SurfaceType.Studs
				piece.BackSurface = Enum.SurfaceType.Studs
				piece.Parent = model
				return { piece }
			end
			if distanceToImpact < destroyRadius then
				return {}
			end
			if depth >= maxDepth then
				local piece = Instance.new("Part")
				piece.Size = size
				piece.CFrame = destructiblePart.CFrame * CFrame.new(center)
				piece.Color = originalColor
				piece.Material = originalMaterial
				piece.Transparency = originalTransparency
				piece.CanCollide = true
				piece.Anchored = true
				piece.TopSurface = Enum.SurfaceType.Studs
				piece.BottomSurface = Enum.SurfaceType.Studs
				piece.LeftSurface = Enum.SurfaceType.Studs
				piece.RightSurface = Enum.SurfaceType.Studs
				piece.FrontSurface = Enum.SurfaceType.Studs
				piece.BackSurface = Enum.SurfaceType.Studs
				piece.Parent = model
				return { piece }
			end
			local shouldSubdivide = distanceToImpact < (destroyRadius + size.Magnitude * 0.75)
			if not shouldSubdivide then
				local piece = Instance.new("Part")
				piece.Size = size
				piece.CFrame = destructiblePart.CFrame * CFrame.new(center)
				piece.Color = originalColor
				piece.Material = originalMaterial
				piece.Transparency = originalTransparency
				piece.CanCollide = true
				piece.Anchored = true
				piece.TopSurface = Enum.SurfaceType.Studs
				piece.BottomSurface = Enum.SurfaceType.Studs
				piece.LeftSurface = Enum.SurfaceType.Studs
				piece.RightSurface = Enum.SurfaceType.Studs
				piece.FrontSurface = Enum.SurfaceType.Studs
				piece.BackSurface = Enum.SurfaceType.Studs
				piece.Parent = model
				return { piece }
			end
			local subdivideX = size.X > minSize * 1.5
			local subdivideY = size.Y > minSize * 1.5
			local subdivideZ = size.Z > minSize * 1.5
			local pieces = {}
			local xDivisions = subdivideX and 2 or 1
			local yDivisions = subdivideY and 2 or 1
			local zDivisions = subdivideZ and 2 or 1
			local newSizeX = size.X / xDivisions
			local newSizeY = size.Y / yDivisions
			local newSizeZ = size.Z / zDivisions
			local halfSize = Vector3.new(newSizeX, newSizeY, newSizeZ)
			local quarterSizeX = subdivideX and (size.X / 4) or 0
			local quarterSizeY = subdivideY and (size.Y / 4) or 0
			local quarterSizeZ = subdivideZ and (size.Z / 4) or 0
			for x = 0, xDivisions - 1 do
				for y = 0, yDivisions - 1 do
					for z = 0, zDivisions - 1 do
						local offsetX = (x * 2 - (xDivisions - 1)) * quarterSizeX
						local offsetY = (y * 2 - (yDivisions - 1)) * quarterSizeY
						local offsetZ = (z * 2 - (zDivisions - 1)) * quarterSizeZ
						local offset = Vector3.new(offsetX, offsetY, offsetZ)
						local newCenter = center + offset
						local subPieces = subdivide(newCenter, halfSize, depth + 1)
						for _, piece in ipairs(subPieces) do
							table.insert(pieces, piece)
						end
					end
				end
			end
			return pieces
		end
		-- Start subdivision
		subdivide(Vector3.new(0, 0, 0), destructiblePart.Size, 0)

		destructiblePart:Destroy()
	end
	-- Now process connectivity for each affected model
	for model in pairs(affectedModels) do
		local pieces = {}
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") then
				table.insert(pieces, child)
			end
		end
		local function isTouching(part1, part2)
			local distance = (part1.Position - part2.Position).Magnitude
			local touchThreshold = (part1.Size.Magnitude + part2.Size.Magnitude) / 2 + 0.1
			return distance <= touchThreshold
		end
		-- Helper to get nearby pieces efficiently
		local function getNeighbors(part)
			local buffer = 2 -- Adjust based on minSize and typical piece scales; e.g., 2-5 for minSize=1
			local expandedSize = part.Size + Vector3.new(buffer * 2, buffer * 2, buffer * 2)
			local overlapParams = OverlapParams.new()
			overlapParams.FilterType = Enum.RaycastFilterType.Include
			overlapParams.FilterDescendantsInstances = { model }
			local nearby = workspace:GetPartBoundsInBox(part.CFrame, expandedSize, overlapParams)
			local neighbors = {}
			for _, np in ipairs(nearby) do
				if np ~= part and isTouching(part, np) then
					table.insert(neighbors, np)
				end
			end
			return neighbors
		end
		-- Group connected pieces that should fall together
		local function getConnectedGroup(startPart, checked)
			checked = checked or {}
			local group = {}
			local function addToGroup(part)
				if checked[part] then
					return
				end
				checked[part] = true
				table.insert(group, part)
				local neighbors = getNeighbors(part)
				for _, otherPiece in ipairs(neighbors) do
					if not checked[otherPiece] then
						addToGroup(otherPiece)
					end
				end
			end
			addToGroup(startPart)
			return group
		end
		-- Process all pieces - group them first, then check if group is grounded
		local processedPieces = {}
		for _, piece in ipairs(pieces) do
			if not processedPieces[piece] then
				-- Get all connected pieces in this group
				local connectedGroup = getConnectedGroup(piece, processedPieces)
				-- Check if the group is grounded (any piece touches external anchored part)
				local groupIsGrounded = false
				for _, groupPiece in ipairs(connectedGroup) do
					local overlapParams = OverlapParams.new()
					overlapParams.FilterType = Enum.RaycastFilterType.Exclude
					overlapParams.FilterDescendantsInstances = { model }
					local buffer = 0.1 -- Small buffer for ground touch detection
					local expandedSize = groupPiece.Size + Vector3.new(buffer * 2, buffer * 2, buffer * 2)
					local nearbyParts = workspace:GetPartBoundsInBox(groupPiece.CFrame, expandedSize, overlapParams)
					for _, nearbyPart in ipairs(nearbyParts) do
						if nearbyPart.Anchored then
							groupIsGrounded = true
							break
						end
					end
					if groupIsGrounded then
						break
					end
				end
				-- If the group is not grounded, weld it together and make it fall
				if not groupIsGrounded and #connectedGroup > 0 then
					if #connectedGroup == 1 then
						connectedGroup[1].Anchored = false
					else
						local mainPart = connectedGroup[1]
						mainPart.Anchored = false
						for i = 2, #connectedGroup do
							local partToWeld = connectedGroup[i]
							partToWeld.Anchored = false
							local weld = Instance.new("WeldConstraint")
							weld.Part0 = mainPart
							weld.Part1 = partToWeld
							weld.Parent = mainPart
						end
					end
				end
			end
		end
	end
end
return Essentials
