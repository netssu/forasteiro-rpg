execute if score @s manhunt_action matches 1 run team join runners @s
execute if score @s manhunt_action matches 1 run tellraw @s {"text":"Você entrou no time runners.","color":"red"}

execute if score @s manhunt_action matches 2 run team join hunters @s
execute if score @s manhunt_action matches 2 run tellraw @s {"text":"Você entrou no time hunters.","color":"blue"}

execute if score @s manhunt_action matches 10 run scoreboard players set Temp manhunt_start_mode 0
execute if score @s manhunt_action matches 11 run scoreboard players set Temp manhunt_start_mode 1
execute if score @s manhunt_action matches 12 run scoreboard players set Temp manhunt_start_mode 2
execute if score @s manhunt_action matches 13 run scoreboard players set Temp manhunt_start_mode 3
execute if score @s manhunt_action matches 10..13 run tellraw @a [{"text":"Modo de início alterado para ","color":"yellow"},{"score":{"name":"Temp","objective":"manhunt_start_mode"},"color":"aqua"}]

execute if score @s manhunt_action matches 20 run function manhunt:start_game

execute if score @s manhunt_action matches 30 run scoreboard players add Temp manhunt_start_dist 50
execute if score @s manhunt_action matches 31 run scoreboard players remove Temp manhunt_start_dist 50
execute if score @s manhunt_action matches 30..31 run tellraw @a [{"text":"Distância inicial: ","color":"yellow"},{"score":{"name":"Temp","objective":"manhunt_start_dist"},"color":"gold"}]

execute if score @s manhunt_action matches 40 run scoreboard players add Temp manhunt_compass_delay 30
execute if score @s manhunt_action matches 41 run scoreboard players remove Temp manhunt_compass_delay 30
execute if score @s manhunt_action matches 40..41 run tellraw @a [{"text":"Delay da bússola: ","color":"yellow"},{"score":{"name":"Temp","objective":"manhunt_compass_delay"},"color":"gold"},{"text":"s","color":"gold"}]

execute if score @s manhunt_action matches 99 run function manhunt:game_over

scoreboard players set @s manhunt_action 0
scoreboard players enable @s manhunt_action
