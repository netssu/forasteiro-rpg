local Settings = {}

function Settings.SetConfig(player: Player, name: string, value: any)
	player:SetAttribute(name, value)
end

function Settings.UpdateConfig(player: Player, name: string)
	player:SetAttribute(name, not player:GetAttribute(name))
end

return Settings
