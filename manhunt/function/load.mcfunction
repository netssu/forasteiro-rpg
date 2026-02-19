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
scoreboard objectives add manhunt_joined dummy

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

execute unless score Temp manhunt_lead matches -2147483647.. run scoreboard players set Temp manhunt_lead 180
execute unless score Config:StartMode manhunt_lead matches -2147483647.. run scoreboard players set Config:StartMode manhunt_lead 3
execute unless score Config:CompassDelay manhunt_lead matches -2147483647.. run scoreboard players set Config:CompassDelay manhunt_lead 180
execute unless score Config:WarnDistance manhunt_lead matches -2147483647.. run scoreboard players set Config:WarnDistance manhunt_lead 100

team add hunters "hunters"
team add runners "runners"

scoreboard objectives add manhunt_prev dummy
execute unless score Temp manhunt_prev matches -2147483647.. run function manhunt:first_load

gamerule locatorBar false

tellraw @a {"text":"Manhunt (1.17.x, 1.18.x, 1.19.x, 1.20.x, 1.21.x)-13 Loaded","bold":true,"color":"gold"}
function manhunt:show_menu
