local validIndexMetatable = {
	__index = function(_, key)
		error(`Table does not contain key "{key}".`)
	end,
}

local TableUtils = {}

--[[
	Returns a deep copy of the table.
]]
function TableUtils.deepCopy(t)
	local tCopy = table.clone(t)

	for k, v in tCopy do
		if typeof(v) == "table" then
			tCopy[k] = TableUtils.deepCopy(v)
		end
	end

	return tCopy
end

--[[
	Fills in missing keys in a table from another template table.
]]
function TableUtils.reconcile(t, tTemplate)
	for k, v in tTemplate do
		if t[k] ~= nil then
			continue
		end

		t[k] = if typeof(v) == "table" then TableUtils.deepCopy(v) else v
	end
end

--[[
	Performs a deep freeze of the table by recursively freezing any nested tables.

	The same table is returned.
]]
function TableUtils.deepFreeze(t)
	if not table.isfrozen(t) then
		table.freeze(t)
	end

	for _, v in t do
		if typeof(v) == "table" then
			TableUtils.deepFreeze(v)
		end
	end

	return t
end

--[[
	Sets the metatable of the table. This metatable raises an error if the original table is indexed with a key which doesn't exist.

	The same table is returned.
]]
function TableUtils.requireValidIndex(t)
	return setmetatable(t, validIndexMetatable)
end

--[[
	Calls `TableUtils.requireValidIndex` and `TableUtils.deepFreeze` on the table. This gives it constant-like behavior.

	The same table is returned.
]]
function TableUtils.setupConsts(t)
	return TableUtils.deepFreeze(TableUtils.requireValidIndex(t))
end

--[[
	Returns true if all keys in t1 exist in t2, returns false if not. Nested tables are recursively checked.
]]
function TableUtils.doKeysExist(t1, t2)
	for k, v in t1 do
		if typeof(v) == "table" and typeof(t2[k]) == "table" then
			if not TableUtils.doKeysExist(v, t2[k]) then
				return false
			end
		elseif v ~= t2[k] then
			return false
		end
	end

	return true
end

--[[
	Returns true if both tables have the same keys, returns false if not. Nested tables must also have the same keys.
]]
function TableUtils.deepCompare(t1, t2)
	return TableUtils.doKeysExist(t1, t2) and TableUtils.doKeysExist(t2, t1)
end

--[[
	Returns the length of the array or dictionary passed. By default, only arrays support the # operator, so dictionaries return 0.
]]
function TableUtils.getLength(t)
	local length = #t

	if length == 0 then
		for _ in t do
			length += 1
		end
	end

	return length
end

--[[
	Returns the key and value at the specified integer index in the dictionary. By default, dictionaries have no way to do this, as they are usually indexed with non-integer values.
]]
function TableUtils.dictionaryAt(t, i)
	assert(t, "Target must be a table.")
	assert(i // 1 == i and i > 0, "Index must be an integer larger than 0.")

	local idx = 0

	for k, v in t do
		idx += 1

		if idx == i then
			return k, v
		end
	end

	return
end

--[[
	Returns the key and integer index of the first occurrence of the value in the dictionary. If the key is not found, returns nil.

	A linear search algorithm is performed.
]]
function TableUtils.dictionaryFind(t, needle)
	local i = 0

	for k, v in t do
		i += 1

		if rawequal(v, needle) then
			return k, i
		end
	end

	return
end

return TableUtils
