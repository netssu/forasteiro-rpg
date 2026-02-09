local Animations = {}

local Cache = {}
local OriginalProps = setmetatable({}, { __mode = 'k' })

local function getAnimation(Type: string, Name: string)
	Cache[Type] = Cache[Type] or {}

	if not Cache[Type][Name] then
		local folder = script:FindFirstChild(Type)
		local module = folder and folder:FindFirstChild(Name)

		if module then Cache[Type][Name] = require(module) end
	end

	return Cache[Type][Name]
end

function Animations:Play(
	Object: GuiObject | ScreenGui,
	Type: string,
	Animation: string,
	Event: string,
	Args: { any }?
)
	local anim = getAnimation(Type, Animation)

	print(Object, Animation, Type, Event)
	if not anim then return end

	if Object:IsA('GuiObject') then
		if not OriginalProps[Object] then
			OriginalProps[Object] = {
				Position = Object.Position,
				Size = Object.Size,
			}
		end
	end

	local callback = anim[Event]
	if typeof(callback) == 'function' then
		callback(Object, OriginalProps[Object], Args)
	end
end

return Animations
