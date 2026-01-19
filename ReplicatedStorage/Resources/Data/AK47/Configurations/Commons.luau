return {
	["Equip_Time"] = 1,
	["Reload_Time"] = {
		EmptyReload = 2.5;
		Reload = 2.25;
	},
	
	["Range"] = 500,
	["Firerate"] = 380, -- // MINUTE / RPM
	["BurstFireIteration"] = 3,
	["MaxPenetration"] = 6,
	
	["AmmoPerMagazine"] = 30;
	
	["Base_Damage"] = 24,
	["Headshot_Multipiler"] = 2,
	
	["WeaponType"] = {
		Shotgun = false;
		Sniper = false;
	},
	
	["Sniper_Config"] = {
		["ZoomLayer"] = {
			[1] = 50;
			[2] = 25;
		} 
	},
	
	["DelayBeforePump"] = 0.2,
	["InsertTime"] = 1,
	["PumpAction"] = false, -- // IF YOUR GUN IS SNIPER, PumpAction will be becoming BoltAction.
	["ExcludePumpSoundOnReload"] = true;

	["CurrentFiremode"] = 2,
	["FireMode"] = {
		{Enabled = false; Label = "Semi"};
		{Enabled = true; Label = "Auto"};
		{Enabled = false; Label = "Burst"};
	},
	
	["Recoil_Config"] = {
		["Recovery"] = true,
		
		["TiltValue"] = {
			Enabled = true,
			
			Min = 1,
			Max = 6,
		},
		
		["Random_Yaw_KickPower"] = {
			Enabled = true,
			
			Min = 1,
			Max = 6
		},
		
		["Pitch_KickPower"] = -9,
		["Yaw_KickPower"] = 6	
	}
}