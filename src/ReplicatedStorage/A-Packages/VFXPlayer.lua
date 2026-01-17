local RunService = game:GetService("RunService")
local jobs = {}
local runtime = nil

local VFXPlayer = {}

function VFXPlayer.play(target, attachment)
	local isPlayer = false

	if target:IsA("Player") then
		local character = target.Character

		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

			if humanoidRootPart then
				target = character:WaitForChild("HumanoidRootPart")
				isPlayer = true
			end
		end
	end

	local emitters = {}
	local longestLifetime = 0
	local maxDelay = 0
	local vfx = attachment:Clone()

	for _, descendant in vfx:GetDescendants() do
		if not descendant:IsA("ParticleEmitter") then
			continue
		end

		descendant.LockedToPart = isPlayer
		table.insert(emitters, descendant)

		local delay = descendant:GetAttribute("EmitDelay") or 0
		local life = descendant.Lifetime.Max

		if delay > maxDelay then
			maxDelay = delay
		end

		if life > longestLifetime then
			longestLifetime = life
		end
	end

	vfx.Parent = target

	local now = os.clock()

	table.insert(jobs, {
		vfx = vfx,
		emitters = emitters,
		emitTime = now + maxDelay,
		cleanupTime = now + maxDelay + longestLifetime,
		emitted = false,
	})

	VFXPlayer._createRuntime()
end

function VFXPlayer._createRuntime()
	if runtime then
		return
	end

	runtime = RunService.PostSimulation:Connect(function()
		local now = os.clock()

		for i = #jobs, 1, -1 do
			local job = jobs[i]

			if not job.emitted and now >= job.emitTime then
				job.emitted = true

				for _, emitter in job.emitters do
					emitter:Emit(emitter:GetAttribute("EmitCount") or 1)
				end
			end

			if now >= job.cleanupTime then
				job.vfx:Destroy()
				table.remove(jobs, i)
			end
		end

		if #jobs == 0 then
			VFXPlayer._destroyRuntime()
		end
	end)
end

function VFXPlayer._destroyRuntime()
	if runtime then
		runtime:Disconnect()
		runtime = nil
	end
end

return VFXPlayer
