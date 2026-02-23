scoreboard players reset @a manhunt_x_o
scoreboard players reset @a manhunt_y_o
scoreboard players reset @a manhunt_z_o

scoreboard players reset @a manhunt_x_n
scoreboard players reset @a manhunt_y_n
scoreboard players reset @a manhunt_z_n

scoreboard players reset @a manhunt_tid
scoreboard players reset @a manhunt_runner_respawn
scoreboard players reset @a manhunt_runner_glow
scoreboard players reset @a manhunt_hunter_protect

tag @e remove manhunt_died
tag @e remove manhunt_previous
tag @a remove manhunt_near_now
tag @a remove manhunt_near_before
tag @a remove manhunt_respawn_wait

scoreboard players set Temp manhunt_enabled 2
scoreboard players set Temp manhunt_end 10

gamemode survival @a

time set 0

effect give @a minecraft:saturation 100 1
clear @a

execute as @a[team=runners,limit=1] at @s run spreadplayers ~ ~ 800 800 true @a[team=hunters]
execute unless entity @a[team=runners] run spreadplayers ~ ~ 800 800 true @a[team=hunters]

scoreboard players set Starts: manhunt_display 180
scoreboard objectives setdisplay sidebar manhunt_display
