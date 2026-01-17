local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolServiceEvent = ReplicatedStorage.Remotes.Events.ToolService

local ToolConnections = {}
local ToolLock = false

local ToolTable = {
	["CommonEgg"] = {
		Use = function(tool) end,
		ServerUse = function(plr, tool, pos) end,
		SecondaryUse = function(tool, stopped) end,
		ServerSecondaryUse = function(plr, tool, argtable) end,
		Equip = function() end,
		ServerEquip = function() end,
		Unequip = function(plr, tool) end,
		ServerUnequip = function(plr, tool) end,
	},
	["UncommonEgg"] = {
		Use = function(tool) end,
		ServerUse = function(plr, tool, pos) end,
		SecondaryUse = function(tool, stopped) end,
		ServerSecondaryUse = function(plr, tool, argtable) end,
		Equip = function() end,
		ServerEquip = function() end,
		Unequip = function(plr, tool) end,
		ServerUnequip = function(plr, tool) end,
	},
	["LegendaryEgg"] = {
		Use = function(tool) end,
		ServerUse = function(plr, tool, pos) end,
		SecondaryUse = function(tool, stopped) end,
		ServerSecondaryUse = function(plr, tool, argtable) end,
		Equip = function() end,
		ServerEquip = function() end,
		Unequip = function(plr, tool) end,
		ServerUnequip = function(plr, tool) end,
	},
	["DivineEgg"] = {
		Use = function(tool) end,
		ServerUse = function(plr, tool, pos) end,
		SecondaryUse = function(tool, stopped) end,
		ServerSecondaryUse = function(plr, tool, argtable) end,
		Equip = function() end,
		ServerEquip = function() end,
		Unequip = function(plr, tool) end,
		ServerUnequip = function(plr, tool) end,
	},
}

return ToolTable
