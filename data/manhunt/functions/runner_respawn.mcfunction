
gamemode survival @s
execute at @r[team=runners,tag=!manhunt_runner_dead] run spreadplayers ~ ~ 0 10 false @s

scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.0 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.1 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.2 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.3 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.4 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.5 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.6 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.7 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.8 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.9 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.10 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.11 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.12 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.13 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.14 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.15 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.16 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.17 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.18 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.19 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.20 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.21 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.22 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.23 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.24 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.25 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.26 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.27 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.28 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.29 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.30 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.31 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.32 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.33 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.34 with air
scoreboard players random @s reg_1 0 1
execute if score @s reg_1 matches 1 run item replace entity @s container.35 with air

effect give @s minecraft:glowing 60 0 true
tag @s remove manhunt_runner_dead
scoreboard players reset @s manhunt_respawn_s
title @s actionbar {"text":""}
