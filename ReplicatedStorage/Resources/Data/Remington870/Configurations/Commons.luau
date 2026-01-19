return {
	["Equip_Time"] = 1.4,
	["Reload_Time"] = {
		EmptyReload = 1.2;
		Reload = 1;
	},
	
	["Firerate"] = 90, -- // MINUTE / RPM
	["BurstFireIteration"] = 3,
	
	["Dispersion"] = {
		Min = 5, -- minimum amount of pellets
		Max = 8, -- maximum amount of pellets
		
		MaxOffset = 4, -- max offset from the center
		MinOffset = 0, -- min offset from the center
	},
	
	["Range"] = 90,

	["AmmoPerMagazine"] = 8;
	
	["Base_Damage"] = 20,
	["Headshot_Multipiler"] = 2,
	
	["WeaponType"] = {
		Shotgun = true;
		Sniper = false;
	},
	
	["Sniper_Config"] = {
		["ZoomLayer"] = {
			[1] = 50;
			[2] = 25;
		} 
	},
	
	["DelayBeforePump"] = 0,
	["InsertTime"] = 0.7,
	["PumpAction"] = true, -- // IF YOUR GUN IS SNIPER, PumpAction will be becoming BoltAction.
	["ExcludePumpSoundOnReload"] = true;

	["CurrentFiremode"] = 1,
	["FireMode"] = {
		{Enabled = true; Label = "Semi"};
		{Enabled = false; Label = "Auto"};
		{Enabled = false; Label = "Burst"};
	},
	
	["Recoil_Config"] = {
		["Recovery"] = true,
		
		["TiltValue"] = {
			Enabled = true,
			
			Min = 1,
			Max = 7,
		},
		
		["Random_Yaw_KickPower"] = {
			Enabled = true,
			
			Min = 1,
			Max = 7
		},
		
		["Pitch_KickPower"] = -16,
		["Yaw_KickPower"] = 5	
	}
}