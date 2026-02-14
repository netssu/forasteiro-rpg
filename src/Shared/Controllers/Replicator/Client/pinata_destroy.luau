local module = {}

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PLAYER = Players.LocalPlayer
local VFX_FOLDER = ReplicatedStorage.Assets:WaitForChild("VFX")

local function CreateTrail(coin: BasePart)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.5, 0)
	a0.Parent = coin
	
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.5, 0)
	a1.Parent = coin
	
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.3
	trail.MinLength = 0.1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
	
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0) 
	})
	
	trail.Parent = coin
end

local function SpawnCoins(startPos: Vector3, amount: number)
	local template = VFX_FOLDER:FindFirstChild("Coin")
	if not template then return end

	local character = PLAYER.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	for i = 1, amount do
		local coin = template:Clone()
		coin.Position = startPos
		coin.Anchored = true
		coin.CanCollide = false
		
		CreateTrail(coin)
		coin.Parent = workspace.Terrain
		
		local targetX = startPos.X + math.random(-8, 8)
		local targetZ = startPos.Z + math.random(-8, 8)
		
		local rayOrigin = Vector3.new(targetX, startPos.Y + 10, targetZ)
		local raycastResult = workspace:Raycast(rayOrigin, Vector3.new(0, -50, 0))
		
		local floorPos
		if raycastResult then
			floorPos = raycastResult.Position + Vector3.new(0, 0.5, 0)
		else
			floorPos = Vector3.new(targetX, startPos.Y - 4, targetZ)
		end
		
		local scatterTween = TweenService:Create(coin, TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
			Position = floorPos
		})
		scatterTween:Play()
		
		task.delay(math.random(20, 25) / 10, function()
			local duration = 0.5
			local startTime = tick()
			local startFlyPos = coin.Position
			
			local rightVector = rootPart.CFrame.RightVector
			local upVector = rootPart.CFrame.UpVector
			local curveOffset = (rightVector * math.random(-20, 20)) + (upVector * math.random(5, 20))
			
			local connection
			connection = RunService.RenderStepped:Connect(function()
				if not rootPart then
					connection:Disconnect()
					coin:Destroy()
					return
				end
				
				local t = (tick() - startTime) / duration
				
				if t >= 1 then
					t = 1
					connection:Disconnect()
					coin:Destroy()
				end
				
				local p0 = startFlyPos
				local p2 = rootPart.Position
				local p1 = p0:Lerp(p2, 0.5) + curveOffset
				
				local l1 = p0:Lerp(p1, t)
				local l2 = p1:Lerp(p2, t)
				local finalPos = l1:Lerp(l2, t)
				
				coin.Position = finalPos
			end)
		end)
	end
end

function module:Start(data)
	if not data or not data.Position then return end
	
	local posData = data.Position
	local position = Vector3.new(posData.X, posData.Y, posData.Z)
	SpawnCoins(position, math.random(10, 15))
end

return module