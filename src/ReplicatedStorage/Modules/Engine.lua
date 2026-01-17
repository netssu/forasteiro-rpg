local module = {}

type RandomLoot = {
	['tag'] : {
		Order : number;
		Weight : number;
		Values : {
			[string] : number;
		};
	};
}

function module:GetRandom(list: RandomLoot, luck: number | nil) : (string?, { string : number; }?)
	luck = luck or 1
	local tag_order = {}
	local luck_applied = {}

	-- Convert list to ordered table
	for tag, data in list do
		tag_order[data.Order] = tag
		luck_applied[tag] = data.Weight
	end

	-- Update weights for tags
	local count = 0
	for tag, w in luck_applied do
		if tag == 'Common' then
			count += tonumber(w)
			continue
		end

		luck_applied[tag] = w * luck
		count += tonumber(luck_applied[tag])
	end

	-- Normalize weights
	for _, tag in tag_order do
		local w = luck_applied[tag]
		if w == 0 then continue end
		if count <= 100 then continue end

		local maxSub = w - 1
		local sub = count - 100

		luck_applied[tag] -= sub < w and sub or maxSub
		count -= sub < w and sub or maxSub
	end

	local random = math.random(1, 100)
	local scroll = 0

	-- Pick a random tag
	local pickedTag
	for _, tag in tag_order do
		local w = luck_applied[tag]
		if not w then continue end

		scroll += w
		if random > scroll then continue end

		pickedTag = tag
	end

	for name, w in list[pickedTag].Values do
		scroll += w
		if random > scroll then continue end
		return name, luck_applied
	end
end

function module:Destroy(obj: Model | thread | RBXScriptSignal | {}, deleteInstances: boolean) : ()
	if typeof(obj) == "RBXScriptConnection" then
		obj:Disconnect()
	elseif deleteInstances and typeof(obj) == "Instance" then
		obj:Destroy()
	elseif typeof(obj) == "thread" then
		coroutine.close(obj)
	elseif typeof(obj) == "table" then
		for k, v in obj do
			obj[k] = module:Destroy(v)
		end
		table.clear(obj)
	end
end

function module:FindAncestor( instance: Instance, ancestors: {string} ) : (Instance)
	if not instance or not instance.Parent or not ancestors then return end

	local parent = instance.Parent
	if table.find(ancestors, parent.Name) then
		return parent
	end

	if table.find(ancestors, parent.Parent.Name) then
		return parent.Parent
	end

	local index = #string.split(instance:GetFullName(), '.')
	for i = 1, index do
		if not parent.Parent then break end

		local me = parent
		parent = parent.Parent

		if not table.find( ancestors, parent.Name ) then continue end
		return me
	end
end

function module:DeepClone(tab: {any}) : ({any})
	local clone = {}
	for key, value in tab do
		clone[key] = type(value) == "table" and module:DeepClone(value) or value
	end
	return clone
end

-- Add commas to large numbers
function module:Commas(price: number | string) : (string)
	local k
	local formatted = tostring(price)
	while true do  
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if (k==0) then break end
	end
	return formatted
end

function module:DictionaryToString(dict: { [string | Instance]: string | number }) : (string)
	local str = '{ '
	local length = 0 for _,_ in dict do length += 1 end

	local i = 0
	for k, v in dict or {} do
		i += 1
		str ..= i == #dict and ` [{typeof(k) == 'Instance' and k.Name or k}]: {v}` or `[{k}]: {v}, `
	end
	str ..= ' }'
	return str
end

function module:ArrayToString(array: {string | Instance}) : (string)
	array = array or {}
	local str = ''
	for i, v in array do
		v = typeof(v) == 'Instance' and v.Name or v
		str ..= (str == '') and v or (#array == i) and ` and {v}` or `, {v}`
	end
	return str
end

-- Use this when you encounter this error: Invalid CFrame. Must contain finite values.
function module:FiniteCFrame(cf: CFrame) : (CFrame)
	local x,y,z = cf.Position.X, cf.Position.Y, cf.Position.Z
	local q,w,e = cf:ToOrientation()
	x = x == math.huge and 0 or x
	y = y == math.huge and 0 or y
	z = z == math.huge and 0 or z
	return CFrame.new(Vector3.new(x,y,z)) * CFrame.fromOrientation(q,w,e)
end

function module:TablesAreEqual(t1: {}, t2: {}) : (boolean)
	if typeof(t1) == 'table' and typeof(t2) == 'table' then
		for i,v in next, t1 do if t2[i]~=v then return false end end
		for i,v in next, t2 do if t1[i]~=v then return false end end
		return true
	else
		return typeof(t1) == typeof(t2) and t1 == t2
	end
end

function module:NumberToTimeString(seconds: number) : (string)
	local secondsInADay = 86400
	local secondsInAnHour = 3600

	local days = seconds // secondsInADay
	seconds -= days * secondsInADay

	local hours = seconds // secondsInAnHour
	seconds -= hours * secondsInAnHour

	local minutes = seconds // 60
	seconds -= minutes * 60

	if days > 0 then
		return `{days} days`
	elseif hours > 0 then
		return string.format("%02i:%02i:%02i", hours, minutes, seconds)
	else
		return string.format("%02i:%02i", minutes, seconds)
	end
end

function module:SimulatorPrice(price: number | string) : (string)
	if not price then return '0' end
	local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "De"} -- Thousand, Million, Billion, Trillion
	local i = 1

	while price >= 1000 and i < #suffixes do
		price = price / 1000
		i = i + 1
	end

	-- Format with 1 decimal place if needed
	if price % 1 == 0 then
		return string.format("%d%s", price, suffixes[i])
	else
		return string.format("%.1f%s", price, suffixes[i])
	end
end

return module