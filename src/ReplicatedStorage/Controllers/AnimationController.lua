local AnimationController = {}
local Replicated = game:GetService("ReplicatedStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local animationsTable = require(ReplicatedStorage.Arrays.AnimationTable)
local loopedAnimation
local loopedAnimation2
local loopedAnimation3
local loopedAnimation4
local loopedAnimationNPC

local function isR6(character)
	return character:FindFirstChild("Torso") ~= nil
end

local function resolveAnimation(animator, anim)
	local character = animator.Parent and animator.Parent.Parent
	if not character then
		return anim
	end
	if not isR6(character) then
		return anim
	end
	local animsFolder = Replicated.Assets:FindFirstChild("Animations")
	if not animsFolder then
		return anim
	end
	local r6Folder = animsFolder:FindFirstChild("R6Animations")
	if not r6Folder then
		return anim
	end
	for _, subFolder in ipairs(r6Folder:GetChildren()) do
		local r6Anim = subFolder:FindFirstChild(anim.Name)
		if r6Anim then
			return r6Anim
		end
	end
	return anim
end

function AnimationController.PlayLoopedAnimation(animator, anim, NPC, fadetime)
	local animation = animator:LoadAnimation(resolveAnimation(animator, anim))
	if NPC then
		AnimationController.StopLoopedAnimation(true)
		loopedAnimationNPC = animation
	else
		AnimationController.StopLoopedAnimation(false)
		loopedAnimation = animation
	end
	animation:Play(fadetime)
end

function AnimationController.PlayLoopedAnimation2(animator, anim, fadetime)
	local animation = animator:LoadAnimation(resolveAnimation(animator, anim))
	AnimationController.StopLoopedAnimation(false, 2)
	loopedAnimation2 = animation
	animation:Play(fadetime)
end

function AnimationController.PlayLoopedAnimation3(animator, anim, fadetime)
	local animation = animator:LoadAnimation(resolveAnimation(animator, anim))
	AnimationController.StopLoopedAnimation(false, 3)
	loopedAnimation3 = animation
	animation:Play(fadetime)
end

function AnimationController.PlayLoopedAnimation4(animator, anim, fadetime)
	local animation = animator:LoadAnimation(resolveAnimation(animator, anim))
	AnimationController.StopLoopedAnimation(false, 4)
	loopedAnimation4 = animation
	animation:Play(fadetime)
end

function AnimationController.StopLoopedAnimation(NPC, arg)
	if NPC then
		if loopedAnimationNPC then
			loopedAnimationNPC:Stop()
		end
	else
		if arg == 2 then
			if loopedAnimation2 then
				loopedAnimation2:Stop()
			end
		elseif arg == 3 then
			if loopedAnimation3 then
				loopedAnimation3:Stop()
			end
		elseif arg == 4 then
			if loopedAnimation4 then
				loopedAnimation4:Stop()
			end
		else
			if loopedAnimation then
				loopedAnimation:Stop()
			end
		end
	end
end

-- Build animations in ReplicatedStorage
local function makeAnimations()
	for categoryName, category in pairs(animationsTable.AnimTable) do
		local folder = Instance.new("Folder")
		folder.Name = categoryName
		folder.Parent = Replicated.Assets.Animations
		if categoryName == "R6Animations" then
			for subCategoryName, subCategory in pairs(category) do
				local subFolder = Instance.new("Folder")
				subFolder.Name = subCategoryName
				subFolder.Parent = folder
				for animName, animId in pairs(subCategory) do
					local animation = Instance.new("Animation")
					animation.Name = animName
					animation.AnimationId = animId
					animation.Parent = subFolder
				end
			end
		else
			for animName, animId in pairs(category) do
				local animation = Instance.new("Animation")
				animation.Name = animName
				animation.AnimationId = animId
				animation.Parent = folder
			end
		end
	end
end

local function preloadAnimations()
	local animationInstances = {}

	local function collectAnimations(parent)
		for _, child in pairs(parent:GetChildren()) do
			if child:IsA("Animation") then
				table.insert(animationInstances, child)
			elseif child:IsA("Folder") then
				collectAnimations(child)
			end
		end
	end

	local animationsFolder = Replicated.Assets:FindFirstChild("Animations")
	if animationsFolder then
		collectAnimations(animationsFolder)
	end

	if #animationInstances > 0 then
		print("Preloading " .. #animationInstances .. " animations...")
		ContentProvider:PreloadAsync(animationInstances)
		print("Animation preloading complete!")
	end
end

function AnimationController.Handler()
	makeAnimations()
	preloadAnimations()
end

return AnimationController
