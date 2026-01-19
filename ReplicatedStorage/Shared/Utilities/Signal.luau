local Signal = {}
Signal.__index = Signal

-- Creates a new signal
function Signal.new()
	local self = setmetatable({}, Signal)
	self._connections = {}
	return self
end

-- Connects a callback function to the signal
-- Returns a connection object with a Disconnect method
function Signal:Connect(callback)
	assert(type(callback) == "function", "Signal:Connect expects a function")

	local connection = {
		Callback = callback,
		Connected = true
	}
	table.insert(self._connections, connection)

	return {
		Disconnect = function()
			if not connection.Connected then return end
			connection.Connected = false

			for i, conn in ipairs(self._connections) do
				if conn == connection then
					table.remove(self._connections, i)
					break
				end
			end
		end
	}
end

-- Fires the signal, calling all connected callbacks with the provided arguments
function Signal:Fire(...)
	for _, connection in ipairs(self._connections) do
		if connection.Connected then
			task.spawn(connection.Callback, ...)
		end
	end
end

-- Disconnects all callbacks from the signal
function Signal:DisconnectAll()
	for _, connection in ipairs(self._connections) do
		connection.Connected = false
	end
	table.clear(self._connections)
end

-- Returns the number of active connections
function Signal:GetConnectionCount()
	return #self._connections
end

-- Connects a callback that automatically disconnects after firing once
function Signal:Once(callback)
	assert(type(callback) == "function", "Signal:Once expects a function")

	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)

	return connection
end

-- Waits until the signal fires, yielding the current thread
-- Returns the arguments passed to Fire()
function Signal:Wait()
	local thread = coroutine.running()
	local connection

	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)

	return coroutine.yield()
end

return Signal