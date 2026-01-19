return {
	["Equip_Time"] = 1,
	["Reload_Time"] = {
		EmptyReload = 2.9;
		Reload = 2.8;
	},
	
	["Firerate"] = 500, -- // MINUTE / RPM
	["BurstFireIteration"] = 3,
	
	["AmmoPerMagazine"] = 30;
	
	["Range"] = 500,

	
	["Base_Damage"] = 20,
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
			Max = 5,
		},

		["Random_Yaw_KickPower"] = {
			Enabled = true,

			Min = 1,
			Max = 5
		},

		["Pitch_KickPower"] = -8,
		["Yaw_KickPower"] = 4	
	}
}