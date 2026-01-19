return {
	["Equip_Time"] = 1,
	["Reload_Time"] = {
		EmptyReload = 2;
		Reload = 2.1;
	},
	
	["MaxPenetration"] = 0,
	["Firerate"] = 240, -- // MINUTE / RPM
	["BurstFireIteration"] = 3,
	
	["AmmoPerMagazine"] = "INF";
	
	["Base_Damage"] = 10,
	["Headshot_Multipiler"] = 1,
	
	["WeaponType"] = {
		Melee = true,
	},
	
	["Range"] = 7,
	
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
	
	["Custom Effects"] = {
		["Bleeding"] = true,
	},
	
	["BLEEDING_CONSTANTS"] = {
		totalTime = 1,
		damagePerLevel = 2,
		levelMax = 5,
		tickTime = 0.2
	},
	
	["FireMode"] = {
		{Enabled = true; Label = "Semi"};
		{Enabled = false; Label = "Auto"};
		{Enabled = false; Label = "Burst"};
	},
	
	["Recoil_Config"] = {
		["Recovery"] = false,

		["TiltValue"] = {
			Enabled = true,

			Min = 1,
			Max = 1.5,
		},

		["Random_Yaw_KickPower"] = {
			Enabled = true,

			Min = 1,
			Max = 1.5
		},

		["Pitch_KickPower"] = .8,
		["Yaw_KickPower"] = .8	
	}
}