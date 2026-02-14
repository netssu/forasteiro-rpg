-- SERVICES

-- CONSTANTS

-- VARIABLES
local Animations = {}
local Cache = {}
local OriginalProps = setmetatable({}, { __mode = 'k' })

-- FUNCTIONS
local function getAnimationModule(Type: string, Name: string)
	Cache[Type] = Cache[Type] or {}
	
	if not Cache[Type][Name] then
		local folder = script:FindFirstChild(Type)
		local module = folder and folder:FindFirstChild(Name)
		if module then 
			Cache[Type][Name] = require(module)
		end
	end
	
	return Cache[Type][Name]
end

local function saveOriginalProperties(Object: GuiObject)
	if not OriginalProps[Object] then
		OriginalProps[Object] = {
			Position = Object.Position,
			Size = Object.Size,
		}
	end
end

function Animations:PlayButtonAnimation(
	Button: GuiObject,
	AnimationName: string,
	Event: string
)
	local animModule = getAnimationModule('Button', AnimationName)
	
	if not animModule then 
		warn('[Animations] Button animation não encontrada:', AnimationName)
		return 
	end
	
	saveOriginalProperties(Button)
	
	local callback = animModule[Event]
	if typeof(callback) == 'function' then
		callback(Button, OriginalProps[Button])
	end
end

function Animations:PlayFrameAnimation(
	Frame: GuiObject | ScreenGui,
	AnimationName: string,
	Event: string
)
	local animModule = getAnimationModule('Frame', AnimationName)
	
	if not animModule then 
		warn('[Animations] Frame animation não encontrada:', AnimationName)
		return 
	end
	
	if Frame:IsA('GuiObject') then
		saveOriginalProperties(Frame)
	end
	
	local callback = animModule[Event]
	if typeof(callback) == 'function' then
		callback(Frame, OriginalProps[Frame])
	end
end

function Animations:Play(
	Object: GuiObject | ScreenGui,
	Type: string,
	Animation: string,
	Event: string,
	Args: { any }?
)
	if Type == 'Button' then
		self:PlayButtonAnimation(Object, Animation, Event)
	elseif Type == 'Frame' then
		self:PlayFrameAnimation(Object, Animation, Event)
	end
end

-- INIT
return Animations