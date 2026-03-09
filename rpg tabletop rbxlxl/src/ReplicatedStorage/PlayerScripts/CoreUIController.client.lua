------------------//SERVICES
local Players: Players = game:GetService("Players")
local StarterGui: StarterGui = game:GetService("StarterGui")

------------------//CONSTANTS
local RETRY_COUNT: number = 12
local RETRY_DELAY: number = 0.5

local CORE_GUI_TYPES = {
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.Chat,
	Enum.CoreGuiType.Health,
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.EmotesMenu,
}

------------------//VARIABLES
local player: Player = Players.LocalPlayer

------------------//FUNCTIONS
local function set_core_value(coreName: string, value: any): ()
	for _ = 1, RETRY_COUNT do
		local success = pcall(function()
			StarterGui:SetCore(coreName, value)
		end)

		if success then
			return
		end

		task.wait(RETRY_DELAY)
	end
end

local function set_core_gui_enabled(coreGuiType: Enum.CoreGuiType, isEnabled: boolean): ()
	for _ = 1, RETRY_COUNT do
		local success = pcall(function()
			StarterGui:SetCoreGuiEnabled(coreGuiType, isEnabled)
		end)

		if success then
			return
		end

		task.wait(RETRY_DELAY)
	end
end

local function apply_core_ui_state(): ()
	set_core_value("TopbarEnabled", false)
	set_core_value("ResetButtonCallback", false)

	for _, coreGuiType in CORE_GUI_TYPES do
		set_core_gui_enabled(coreGuiType, false)
	end
end

------------------//MAIN FUNCTIONS
player.CharacterAdded:Connect(function()
	task.defer(function()
		apply_core_ui_state()
	end)
end)

------------------//INIT
apply_core_ui_state()