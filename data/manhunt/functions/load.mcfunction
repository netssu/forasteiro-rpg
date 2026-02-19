scoreboard objectives add reg_1 dummy

scoreboard objectives add manhunt_rid dummy
scoreboard objectives add manhunt_tid dummy

scoreboard objectives add manhunt_ticks dummy
scoreboard objectives add manhunt_enabled dummy
scoreboard objectives add manhunt_end dummy

scoreboard objectives add manhunt_display dummy
scoreboard objectives modify manhunt_display displayname ""

scoreboard objectives add manhunt_deaths deathCount
scoreboard objectives add manhunt_lead dummy

scoreboard objectives add manhunt_x dummy
scoreboard objectives add manhunt_y dummy
scoreboard objectives add manhunt_z dummy

scoreboard objectives add manhunt_x_o dummy
scoreboard objectives add manhunt_y_o dummy
scoreboard objectives add manhunt_z_o dummy

scoreboard objectives add manhunt_x_n dummy
scoreboard objectives add manhunt_y_n dummy
scoreboard objectives add manhunt_z_n dummy

scoreboard objectives add manhunt_dst dummy
scoreboard objectives add manhunt_min_dst dummy
scoreboard objectives add manhunt_hhp dummy

execute unless score Temp manhunt_lead matches -2147483647.. run scoreboard players set Temp manhunt_lead 45
execute unless score Temp manhunt_compass_delay matches -2147483647.. run scoreboard players set Temp manhunt_compass_delay 180
execute unless score Temp manhunt_start_dist matches -2147483647.. run scoreboard players set Temp manhunt_start_dist 400
execute unless score Temp manhunt_start_mode matches -2147483647.. run scoreboard players set Temp manhunt_start_mode 0

team add hunters "hunters"
team add runners "runners"

team modify hunters nametagVisibility always
team modify runners nametagVisibility always
team modify hunters friendlyFire false
team modify runners friendlyFire false

scoreboard objectives add manhunt_prev dummy
execute unless score Temp manhunt_prev matches -2147483647.. run function manhunt:first_load

gamerule locatorBar false
tellraw @a {"text":"Manhunt Loaded","bold":true,"color":"gold"}
function manhunt:controls
