local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CameraController = require(ReplicatedStorage.Controllers.CameraController)
local essentials = require(ReplicatedStorage.KiwiBird.Essentials)
local VfxTable = {
	Explosion = function(plr, specialArg)
		local explosion = ReplicatedStorage.Assets.VFX.Explosion:Clone()
		explosion.Parent = workspace
		explosion.Position = specialArg.pos

		explosion.Explosion:Emit(2)

		explosion.PointLight.Enabled = true

		task.delay(0.1, function()
			explosion.Smoke.Enabled = true
			task.delay(0.045, function()
				explosion.Smoke.Enabled = false
			end)
		end)

		TweenService:Create(explosion.PointLight, TweenInfo.new(0.5), { Range = 0 }):Play()

		task.delay(0.5, function()
			explosion.PointLight.Enabled = false
		end)

		local currentPlr = Players.LocalPlayer

		local distance = (currentPlr.Character.HumanoidRootPart.Position - explosion.Position).Magnitude

		local randomNumber = math.random(5, 8)

		task.spawn(function()
			for i = 1, randomNumber, 1 do
				local debrisSmoke = ReplicatedStorage.Assets.VFX.debrisSmoke:Clone()
				debrisSmoke.Parent = workspace
				debrisSmoke.Position = explosion.Position
				debrisSmoke.Velocity = Vector3.new(math.random(-30, 50), math.random(30, 80), math.random(-30, 50))
				task.delay(2, function()
					debrisSmoke:Destroy()
				end)
			end
		end)

		if distance > 1 and distance < 15 then
			CameraController.ShakeCamera(nil, 2, 1)
		elseif distance > 15 and distance < 25 then
			CameraController.ShakeCamera(nil, 1.5, 0.5)
		elseif distance > 25 and distance < 70 then
			CameraController.ShakeCamera(nil, 0.75, 0.2)
		end

		task.delay(10, function()
			explosion:Destroy()
		end)
	end,
	streak = function(plr, limb)
		local streakClone: Part = ReplicatedStorage.Assets.VFX.streak:Clone()

		streakClone.Parent = plr.Character:FindFirstChild(limb)

		streakClone.CFrame = plr.Character:FindFirstChild(limb).CFrame * CFrame.new(0, -0.8, 0)

		essentials.WeldPartsTogether(streakClone, plr.Character:FindFirstChild(limb))

		task.delay(0.4, function()
			local weld

			if streakClone:FindFirstChildOfClass("WeldConstraint") then
				weld = streakClone:FindFirstChildOfClass("WeldConstraint")
			end

			weld:Destroy()

			streakClone.Anchored = true
		end)
	end,

	streakLight = function(plr, limb)
		print("yes")
		local streakClone: Part = ReplicatedStorage.Assets.VFX.streakLight:Clone()

		streakClone.Parent = plr.Character:FindFirstChild(limb)

		streakClone.CFrame = plr.Character:FindFirstChild(limb).CFrame * CFrame.new(0, -0.8, 0)

		essentials.WeldPartsTogether(streakClone, plr.Character:FindFirstChild(limb))

		task.delay(0.4, function()
			local weld

			if streakClone:FindFirstChildOfClass("WeldConstraint") then
				weld = streakClone:FindFirstChildOfClass("WeldConstraint")
			end

			weld:Destroy()

			streakClone.Anchored = true
		end)
	end,
}

return VfxTable
