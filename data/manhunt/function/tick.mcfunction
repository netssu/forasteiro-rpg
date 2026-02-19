execute as @a[tag=!manhunt_seen] run function manhunt:player_join

execute if score Temp manhunt_enabled matches 1.. as @a[scores={manhunt_deaths=1..},team=runners] run function manhunt:runners_death
execute if score Temp manhunt_enabled matches 1.. as @a[scores={manhunt_deaths=1..},team=hunters] at @s run function manhunt:hunter_death
scoreboard players set @a manhunt_deaths 0

execute as @a[team=hunters] store result score @s manhunt_hhp run data get entity @s Health 1
scoreboard players reset @a[team=!hunters] manhunt_hhp
scoreboard objectives setdisplay list manhunt_hhp

scoreboard players add Temp manhunt_ticks 1
execute if score Temp manhunt_ticks matches 20.. run function manhunt:second

execute if score Starts: manhunt_display matches 1.. run clear @a[team=hunters]
