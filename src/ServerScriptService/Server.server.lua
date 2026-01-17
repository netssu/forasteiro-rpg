for _, v in pairs(script.Parent.Services:GetChildren()) do
	if v:IsA("ModuleScript") then
		require(v).Handler()
	end
end
