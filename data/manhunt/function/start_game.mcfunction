scoreboard players reset @a manhunt_x_o
scoreboard players reset @a manhunt_y_o
scoreboard players reset @a manhunt_z_o

scoreboard players reset @a manhunt_x_n
scoreboard players reset @a manhunt_y_n
scoreboard players reset @a manhunt_z_n

scoreboard players reset @a manhunt_tid
tag @a[team=runners] remove manhunt_alerted

tag @e remove manhunt_died
tag @e remove manhunt_previous

time set 0
scoreboard players set Temp manhunt_enabled 1
scoreboard players set Temp manhunt_end 10

gamemode survival @a

effect give @a minecraft:saturation 100 1
clear @a

execute if score Temp manhunt_start_mode matches 0 run scoreboard players operation Starts: manhunt_display = Temp manhunt_lead
execute if score Temp manhunt_start_mode matches 3 run scoreboard players operation Starts: manhunt_display = Temp manhunt_compass_delay
scoreboard objectives setdisplay sidebar manhunt_display

execute as @a[team=runners,limit=1] at @s if score Temp manhunt_start_mode matches 1 run function manhunt:spread_hunters
execute if entity @a[team=runners] as @a[team=runners,limit=1] at @s if score Temp manhunt_start_mode matches 2 run spreadplayers ~ ~ 0 80 false @a[team=runners]
execute if entity @a[team=runners] as @a[team=runners,limit=1] at @s if score Temp manhunt_start_mode matches 2 run function manhunt:spread_hunters

execute as @a[team=hunters,limit=1] at @s run setworldspawn ~ ~ ~

execute if score Temp manhunt_start_mode matches 1..2 run function manhunt:start_hunt

tellraw @a {"text":"Partida iniciada. Para encerrar: /function manhunt:stop","color":"gold"}
