scoreboard players reset @a manhunt_x_o
scoreboard players reset @a manhunt_y_o
scoreboard players reset @a manhunt_z_o

scoreboard players reset @a manhunt_x_n
scoreboard players reset @a manhunt_y_n
scoreboard players reset @a manhunt_z_n

scoreboard players reset @a manhunt_tid


tag @e remove manhunt_died
tag @e remove manhunt_previous
tag @a remove manhunt_near_now
tag @a remove manhunt_near_before

scoreboard players set Temp manhunt_enabled 2
scoreboard players set Temp manhunt_end 10

gamemode survival @a

time set 0
gamerule locatorBar false

effect give @a minecraft:saturation 100 1
clear @a

function manhunt:apply_start_mode

scoreboard players operation Starts: manhunt_display = Temp manhunt_compass_delay
scoreboard objectives setdisplay sidebar manhunt_display

function manhunt:show_menu
