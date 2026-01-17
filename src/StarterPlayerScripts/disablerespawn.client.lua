local StarterGui = game:GetService("StarterGui")

local Success

repeat Success = pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false)
	if not Success then
		task.wait(1/30)
	end
until Success