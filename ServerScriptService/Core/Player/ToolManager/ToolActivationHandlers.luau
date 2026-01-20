--// Services //--
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

--// Dependencies //--
local BrainrotController = require(ServerScriptService.Core.Catching.BrainrotController)
local CatchingManager = require(ServerScriptService.Core.Catching.CatchingManager)
local CatchingConfig = require(ReplicatedStorage.Shared.Configs.CatchingConfig)
local Cache = require(ReplicatedStorage.Shared.Utilities.Cache)
local Bindables = ServerScriptService.Bindables
local DataService = require(ServerScriptService.Core.Data.DataService)
local CatchingSession = require(ServerScriptService.Core.Catching.CatchingSession)
local SoundModule = require(ReplicatedStorage.Shared.Utilities.SoundModule)


--// Variables //--
local Assets = ReplicatedStorage.Assets

local Remotes = ReplicatedStorage.Remotes
local Events = Remotes.Events

local UpdateLabel = ReplicatedStorage.Remotes.Events.LabelUpdateSession
local Bindables = ServerScriptService.Bindables
local CatchingBindables = Bindables.Catching
local OnBrainThrow = CatchingBindables.OnBrainThrow

--// Helpers //--
local function playAnimation(character: Model, animationId: string): AnimationTrack
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then return end

	local animator: Animator = humanoid:FindFirstChildWhichIsA("Animator") or humanoid

	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. animationId

	local track = animator:LoadAnimation(animation)
	track:Play()

	animation:Destroy()

	return track
end

--// Main //--
local ToolActivationHandlers = {

	Harpoon = function(player: Player, toolManager)
		local character = player.Character
		if not character then return end

		local harpoonTool = character:FindFirstChildWhichIsA("Tool")
		if not harpoonTool then return end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: Part
		if not humanoidRootPart then return end

		local damage = toolManager:getToolStat("Harpoon", "Damage") or 25
		local pullSpeed = toolManager:getToolStat("Harpoon", "PullSpeed") or 20
		local stunDuration = toolManager:getToolStat("Harpoon", "StunDuration") or 2

		local track = playAnimation(character, "106096609898803")

		track:GetMarkerReachedSignal("Shoot"):Once(function()
			local tool = character:FindFirstChildWhichIsA("Tool")
			if not player.Character or not tool or tool.Name ~= "Harpoon" then return end

			Events.Tool.Harpoon.Shoot:FireAllClients(character)
		end)

		return true
	end,

	Brain = function(player: Player, toolManager)
		local character = player.Character
		if not character then return end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: Part
		if not humanoidRootPart then return end

		local range = toolManager:getToolStat("Brain", "Range") or 50
		local track = playAnimation(character, "106096609898803")

		track:GetMarkerReachedSignal("Shoot"):Once(function()
			local brain = Cache.RetrieveFromCache("Brain") or Assets.Models.Brain:Clone()
			brain:PivotTo(humanoidRootPart.CFrame)
			brain.Parent = workspace.Brains
			brain:SetAttribute("Range", range)
			--print("Brain Tool range attribute set to:", range)
			
			SoundModule.PlayForPlayers(player, "Brain Throwing", nil, nil, brain)

			for _, part in brain:GetDescendants() do
				if not part:IsA("BasePart") then continue end

				part.CollisionGroup = "Debris"
			end

			local charBottom = character:GetBoundingBox().Y - character:GetExtentsSize().Y / 2
			local brainPos = brain:GetBoundingBox().Y
			local height = brainPos - charBottom

			local forceFactor = 0.5

			local charBottom = character:GetBoundingBox().Y - character:GetExtentsSize().Y / 2
			local brainPos = brain:GetBoundingBox().Y
			local height = brainPos - charBottom
			
			local travelTime = math.sqrt(2 * height / workspace.Gravity)
			
			local horizontalVelocity = humanoidRootPart.CFrame.LookVector * (range / travelTime)
			local verticalVelocity = workspace.Gravity * travelTime
			
			local finalVelocity =
				Vector3.new(
					horizontalVelocity.X,
					verticalVelocity,
					horizontalVelocity.Z
				) * forceFactor
			
			local brainBottom = brain:FindFirstChild("BrainBottom") :: BasePart
			if brainBottom then
				brainBottom.AssemblyLinearVelocity = finalVelocity
			else
				warn("[Brain Tool] No bottom part found! Brain object:", brain)
			end
			
			task.delay(travelTime, function()
				--print("GOING TO CREATE BRAINROT - Brain Tool:", brain, "Player session:", CatchingManager.isInSession(player))
				
				if not brain or not CatchingManager.isInSession(player) then return end
				
				local playerSession = CatchingManager.getSession(player) -- gets current player session
				if not playerSession then
					warn("[Brain Tool] No Player Session! Result:", playerSession)
				end
				
				local BrainRange = brain:GetAttribute("Range") or 25 --25 -- for testing
				
				local BrainPos = brainBottom and brainBottom.Position -- gets the brain position
				
				local brainrots = playerSession.Brainrots:GetChildren()
				
				--print("GETTING TOTAL SPAWNED BRAINROTS - ", playerSession.Brainrots, #brainrots)
				
				--if #brainrots == 0 then return end
				for _, brainrot in brainrots do
					if brainrot:GetAttribute("Walking") == true then continue end
					if not brainrot.PrimaryPart or not BrainPos then continue end
					if (brainrot.PrimaryPart.Position - BrainPos).Magnitude > BrainRange then continue end -- if out of range dont start brainrot
					
					local ends = playerSession.Ends:GetChildren()
					
					local lanePos = playerSession.Lane:GetPivot().Position
					
					local pathPosition = Vector3.new(brainrot.PrimaryPart.Position.X, lanePos.Y, lanePos.Z)
					
					BrainrotController.startBrainrot(brainrot, pathPosition, brain, character.PrimaryPart) -- starts brainrot controller
				end
				
				task.wait(15)
				
				if brain then
					brain:Destroy()
				end
			end)
		end)

		return true
	end,

	Shotgun = function(player: Player, playerObject, toolManager)
		local character = player.Character
		if not character then return end

		local track = playAnimation(character, "106096609898803")
		if not track then return end

		track:GetMarkerReachedSignal("Shoot"):Once(function()
			local tool = character:FindFirstChildWhichIsA("Tool")
			if not player.Character or not tool or tool.Name ~= "Shotgun" then return end

			Events.Tool.Shotgun.Shoot:FireAllClients(character)
		end)

		return true
	end,
}

Events.Tool.Harpoon.Hitbox.OnServerEvent:Connect(function(player: Player, hits: {BasePart})
	if #hits == 0 then return end
	
	for _, humanoid in hits do
		local character = humanoid.Parent
		if character and character:GetAttribute("Walking") == true then
			UpdateLabel:FireClient(player, 1)
			character:Destroy()

			CatchingSession.AddBrainrotCatch(player, character.Name)
		end
	end
end)

Events.Tool.Shotgun.Hitbox.OnServerEvent:Connect(function(player: Player, hits: {Instance})
	if type(hits) ~= "table" or #hits == 0 then return end

	local character = player.Character
	local tool = character and character:FindFirstChildWhichIsA("Tool")
	if not character or not tool or tool.Name ~= "Shotgun" then return end

	local uniqueTargets: {[Model]: boolean} = {}

	for i , inst in hits do
		if typeof(inst) ~= "Instance" then
			continue
		end

		local targetModel = inst:FindFirstAncestorOfClass("Model")
		if targetModel and targetModel ~= character then
			uniqueTargets[targetModel] = true
		end
	end

	for targetModel in uniqueTargets do
		if targetModel:GetAttribute("Walking") == true then
			UpdateLabel:FireClient(player, 1)
			CatchingSession.AddBrainrotCatch(player, targetModel.Name)
			targetModel:Destroy()
		end
	end
end)


return ToolActivationHandlers
