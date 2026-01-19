return {
	["Equip_Time"] = 1.3,
	["Reload_Time"] = {
		EmptyReload = 3;
		Reload = 2.1;
	},
	
	["Range"] = 1000,

	
	["Firerate"] = 300, -- // MINUTE / RPM
	["BurstFireIteration"] = 3,

	["AmmoPerMagazine"] = 10;
	
	["Base_Damage"] = 36,
	["Headshot_Multipiler"] = 3,
	
	["WeaponType"] = {
		Shotgun = false;
		Sniper = true;
	},
	
	["Sniper_Config"] = {
		["ZoomLayer"] = {
			[1] = {FOV = 50; Weight = 4};
			[2] = {FOV = 25; Weight = 8};
		} 
	},
	
	["DelayBeforePump"] = 0,
	["InsertTime"] = 0,
	
	["PumpAction"] = false, -- // IF YOUR GUN IS SNIPER, PumpAction will be becoming BoltAction.
	["ExcludePumpSoundOnReload"] = false;
	
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
			Max = 8,
		},
		
		["Random_Yaw_KickPower"] = {
			Enabled = true,
			
			Min = 1,
			Max = 8
		},
		
		["Pitch_KickPower"] = -13,
		["Yaw_KickPower"] = 5	
	}
}