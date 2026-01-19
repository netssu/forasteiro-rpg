return {
	["Equip_Time"] = 1,
	["Reload_Time"] = {
		EmptyReload = 2.8;
		Reload = 2.1;
	},
	
	["Firerate"] = 620, -- // MINUTE / RPM
	["BurstFireIteration"] = 3,
	
	["AmmoPerMagazine"] = 64;
	
	["Range"] = 500,

	
	["Base_Damage"] = 18,
	["Headshot_Multipiler"] = 1.8,
	
	["WeaponType"] = {
		Pistol = true;
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
			Max = 7,
		},
		
		["Random_Yaw_KickPower"] = {
			Enabled = true,
			
			Min = 1,
			Max = 7
		},
		
		["Pitch_KickPower"] = -6,
		["Yaw_KickPower"] = 2	
	}
}