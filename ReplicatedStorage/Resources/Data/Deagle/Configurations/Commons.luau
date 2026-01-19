return {
	["Equip_Time"] = 1,
	["Reload_Time"] = {
		EmptyReload = 2.8;
		Reload = 2;
	},
	
	["Firerate"] = 200, -- // MINUTE / RPM
	["BurstFireIteration"] = 3,
	["MaxPenetration"] = 4,
	
	["AmmoPerMagazine"] = 7;
	
	["Range"] = 500,
	
	["Base_Damage"] = 55,
	["Headshot_Multipiler"] = 2,
	
	["WeaponType"] = {
		HandCannon = true;
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
			Enabled = false,

			Min = 2,
			Max = 5,
		},

		["Random_Yaw_KickPower"] = {
			Enabled = true,

			Min = 2,
			Max = 5
		},

		["Pitch_KickPower"] = -10,
		["Yaw_KickPower"] = 5	
	}
}