tag @s add manhunt_respawn_wait
gamemode spectator @s

execute if entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_respawn_wait,gamemode=!spectator,limit=1] run scoreboard players set @s manhunt_runner_respawn 60
execute if entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_respawn_wait,gamemode=!spectator,limit=1] run scoreboard players set @a[team=runners,tag=!manhunt_died,tag=!manhunt_respawn_wait,gamemode=!spectator] manhunt_runner_glow 120

execute unless entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_respawn_wait,gamemode=!spectator,limit=1] run tag @s add manhunt_died
execute unless entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_respawn_wait,gamemode=!spectator,limit=1] run tag @s remove manhunt_respawn_wait
