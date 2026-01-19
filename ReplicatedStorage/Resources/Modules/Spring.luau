-- ==============================================
-- rodexiy's edited for fps (fix delta iterations)
-- nickibreeki's thirdparty collection
-- blackshibe's spring 
-- ==============================================

local SPRING = {}

local FIXED_DT = 1/60
local FORCE_MULTIPLIER = 0.2

function SPRING.create(self, mass, force, damping, speed)

	local spring = {
		Target      = Vector3.new(),
		Position    = Vector3.new(),
		Velocity    = Vector3.new(),

		Mass        = mass or 5,
		Force       = force or 50,
		Damping     = damping or 4,
		Speed       = speed  or 4,

		_accumulator = 0,
	}

	function spring:shove(force, dt)
		dt = dt or FIXED_DT
		self.Velocity += force * (dt * 60) * FORCE_MULTIPLIER
	end

	function spring:update(dt)
		self._accumulator += dt

		while self._accumulator >= FIXED_DT do
			self._accumulator -= FIXED_DT

			local displacement = self.Target - self.Position
			local force = displacement * self.Force
			local accel = (force - self.Velocity * self.Damping) / self.Mass

			self.Velocity += accel * FIXED_DT * self.Speed
			self.Position += self.Velocity * FIXED_DT
		end

		return self.Position
	end

	return spring
end

return SPRING
