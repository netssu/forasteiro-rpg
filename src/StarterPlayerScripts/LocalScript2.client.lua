local stakebox = workspace:WaitForChild("stakebox")

stakebox.Touched:Connect(function(h)
	if h.Parent:FindFirstChild("Humanoid") then
		local plr = game.Players:GetPlayerFromCharacter(h.Parent)
		if plr and plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Wins") then

			local wins = plr.leaderstats.Wins.Value
			local part = stakebox

			-- If player has LESS than 10 wins → part is solid + visible
			-- If player has 10 OR MORE wins → part is invisible + not solid
			if wins < 10 then
				part.CanCollide = true
			else
				part.CanCollide = false	
			end
		end
	end
end)
