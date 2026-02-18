while task.wait(.1) do
	local timer = workspace:GetAttribute("Timer")
	if timer then
		if timer <= 0 then
			script.Parent.Text = "Soon!"
		else
			local seconds = math.round(timer)
			script.Parent.Text = string.format("00:%02d", seconds)
		end
	end
end