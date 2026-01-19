return {
	--Looks similar to how shaking in the CameraShaker module looked.
	Traditional = {
		RotationalShaking = false,
		TranslationalShaking = true,
		FallOfRate = .5,
		RotationalStrength = Vector3.new(3, 3, 3),
		TranslationalStrength = Vector3.new(1, 1, 1),
		SpeedMultiplier = 50,
	},
	
	--If no template is passed, it defaults to this.
	Default = {
		RotationalShaking = true,
		TranslationalShaking = false,
		FallOfRate = .5,
		RotationalStrength = Vector3.new(3, 3, 3),
		TranslationalStrength = Vector3.new(1, 1, 1),
		SpeedMultiplier = 10,
	},
}