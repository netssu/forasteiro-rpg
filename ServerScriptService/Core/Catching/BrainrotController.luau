local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local BrainrotConfig = require(ReplicatedStorage.Shared.Configs.BrainrotConfig)
local CatchingConfig = require(ReplicatedStorage.Shared.Configs.CatchingConfig)
local CatchingManager = require(ServerScriptService.Core.Catching.CatchingManager)

local BrainrotController = {}

local range = 40

local function tween(brainrot, speed, position): Tween
	local primary = brainrot.PrimaryPart
	if not primary then return nil end

	if math.abs(primary.Position.Y - position.Y) < 1 then
		local direction = (position - primary.Position)
		direction = Vector3.new(direction.X, 0, direction.Z).Unit
		local baseCF = CFrame.lookAt(primary.Position, primary.Position + direction)
		TweenService:Create(primary, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {CFrame = baseCF}):Play()
	end

	local distance = (primary.Position - position).Magnitude
	local duration = distance / math.max(0.0001, speed)
	local t = TweenService:Create(primary, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Position = position})
	t:Play()
	return t
end

function BrainrotController.startBrainrot(brainrot: Model, PathPosition: Vector3, Brain: Model, PlayerRootPart: Part)
	if not brainrot or not brainrot.PrimaryPart then return end

	local primary = brainrot.PrimaryPart
	local heightOffset = Vector3.new(0, brainrot:GetExtentsSize().Y/2, 0)

	local hole = brainrot.hole and brainrot.hole.Value

	local speed = BrainrotConfig.getSpeed(brainrot.Name) or 16

	local WalkAnimationId = BrainrotConfig.getWalkAnimation(brainrot.Name)
	local WalkAnimation = Instance.new("Animation")

	WalkAnimation.AnimationId = WalkAnimationId

	local animator = brainrot:FindFirstChild("AnimationController") and brainrot.AnimationController:FindFirstChild("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = brainrot.AnimationController
	end
	local walkAnim = animator:LoadAnimation(WalkAnimation)

	brainrot:SetAttribute("Walking", false)

	while brainrot:GetAttribute("Walking") == false do
		if brainrot and brainrot.PrimaryPart and (PlayerRootPart.Position - brainrot.PrimaryPart.Position).Magnitude > range then
			if brainrot:GetAttribute("Walking") == true then return end
			brainrot:SetAttribute("Walking", true)

			local HoleTween = tween(brainrot, 50, hole.Position + heightOffset)
			
			local crosshair = ReplicatedStorage.Assets.VFX.Crosshair:Clone()
			crosshair.Parent = primary
			crosshair.Attachment.ParticleEmitter:Emit(1)

			local weld = Instance.new("Weld")
			weld.Part0 = primary
			weld.Part1 = crosshair
			weld.C1 = CFrame.new(0, 0, 0)
			weld.Parent = crosshair

			Debris:AddItem(crosshair, 1)

			if hole then
				for _, v in ipairs(hole:GetDescendants()) do
					if v:IsA("ParticleEmitter") then
						v.Enabled = false
					end
				end
				if hole.emit then
					for _, v in ipairs(hole.emit:GetChildren()) do
						if v and v:IsA("ParticleEmitter") then
							v:Emit(30)
						end 
					end
				end
			end

			HoleTween.Completed:Wait()
			walkAnim:Play()

			local distracted = true
			local tweening = false

			while distracted do
				local anyBasePart = brainrot:FindFirstChildWhichIsA("BasePart")
				if not anyBasePart then return end
				
				if (PlayerRootPart.Position - anyBasePart.Position).Magnitude > range then
					if tweening == false then
						local BrainTween = tween(brainrot, speed, Brain.BrainBottom.Position + heightOffset)
						tweening = true
					end
				else
					distracted = false
					break
				end
				task.wait(0.5)
			end

			local Session = brainrot.Parent.Parent
			local Waypoints = Session.Waypoints:GetChildren()

			table.sort(Waypoints, function(a, b)
				return a.Position.Z < b.Position.Z
			end)

			local BrainrotEnd

			if brainrot.PrimaryPart.Position.Z < PlayerRootPart.Position.Z then
				BrainrotEnd = Session.Ends.Start
			else
				BrainrotEnd = Session.Ends.End
			end

			local EndPos = BrainrotEnd.Position

			local closest, second, third
			local d1, d2, d3 = math.huge, math.huge, math.huge

			for _, v in Waypoints do
				local d = (brainrot.PrimaryPart.Position - v.Position).Magnitude

				if d < d1 then
					third, d3 = second, d2
					second, d2 = closest, d1
					closest, d1 = v, d
				elseif d < d2 then
					third, d3 = second, d2
					second, d2 = v, d
				elseif d < d3 then
					third, d3 = v, d
				end
			end

			local BrainrotZ = brainrot.PrimaryPart.Position.Z
			local chosenWaypoint

			if BrainrotZ < PlayerRootPart.Position.Z then
				if closest.Position.Z < BrainrotZ then
					chosenWaypoint = closest
				elseif second.Position.Z < BrainrotZ then
					chosenWaypoint = second
				else
					chosenWaypoint = third
				end
			else
				if closest.Position.Z > BrainrotZ then
					chosenWaypoint = closest
				elseif second.Position.Z > BrainrotZ then
					chosenWaypoint = second
				else
					chosenWaypoint = third
				end
			end

			local startIndex

			for i, v in Waypoints do
				if v == chosenWaypoint then
					startIndex = i
					break
				end
			end

			local step = BrainrotZ < PlayerRootPart.Position.Z and -1 or 1

			local function goTo(pos)
				if not brainrot or not brainrot.PrimaryPart then return end
				
				print(pos)
				
				local t = tween(brainrot, speed, Vector3.new(
					pos.X,
					brainrot.PrimaryPart.Position.Y,
					pos.Z
					))
				t.Completed:Wait()
			end

			goTo(chosenWaypoint.Position)

			local i = startIndex + step
			while Waypoints[i] do
				goTo(Waypoints[i].Position)
				i += step
			end
			
			goTo(EndPos)

			WalkAnimation:Destroy()
			brainrot:Destroy()
		end
		if not Brain.Parent then break end
		task.wait(1)
	end
end

return BrainrotController
