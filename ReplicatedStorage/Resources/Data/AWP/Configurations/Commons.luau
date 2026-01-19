return {
	["Equip_Time"] = 1.3,
	["Reload_Time"] = {
		EmptyReload = 1.9;
		Reload = 1.9;
	},
	
	["Range"] = 2000,

	
	["Firerate"] = 80, -- // MINUTE / RPM
	["BurstFireIteration"] = 3,
	["MaxPenetration"] = 10,

	["AmmoPerMagazine"] = 10;
	
	["Base_Damage"] = 80,
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
	
	["PumpAction"] = true, -- // IF YOUR GUN IS SNIPER, PumpAction will be becoming BoltAction.
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
		
		["Pitch_KickPower"] = -15,
		["Yaw_KickPower"] = 8	
	}
}