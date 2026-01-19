--// Services //--
local ServerScriptService = game:GetService("ServerScriptService")

local BindableConfig = require(script.BindableConfig)

local BindableManager = {}

--// Main //--
local function ProcessBindable(bindableName, ...)
	-- Validation
	local config = BindableConfig[bindableName]
	if not config then
		warn("[BindableManager] No config found for bindable:", bindableName)
		return
	end

	local handler = config.Handler
	if not handler then
		warn("[BindableManager] No handler found for bindable:", bindableName)
		return
	end

	-- Call handler
	local success, err = pcall(handler, ...)
	if not success then
		warn(string.format("[BindableManager] Error in handler for %s: %s", bindableName, tostring(err)))
	end
end

--// Initialization //--
function BindableManager.Initialize()
	local bindablesFolder = ServerScriptService.Bindables

	if not bindablesFolder then
		warn("[BindableManager] Bindables folder not found in ServerScriptService")
		return
	end

	for _, bindableEvent in bindablesFolder:GetDescendants() do
		if not bindableEvent:IsA("BindableEvent") then continue end

		local config = BindableConfig[bindableEvent.Name]
		if not config then
			warn("[BindableManager] No config found for bindable:", bindableEvent.Name)
			continue
		end

		bindableEvent.Event:Connect(function(...)
			ProcessBindable(bindableEvent.Name, ...)
		end)
	end

	--print("[BindableManager] Initialized")
end

return BindableManager