execute if score Temp manhunt_enabled matches 1.. as @a[scores={manhunt_deaths=1..},team=runners] run function manhunt:runners_death
execute if score Temp manhunt_enabled matches 1.. as @a[scores={manhunt_deaths=1..},team=hunters] run function manhunt:hunted_death

execute if score Temp manhunt_enabled matches 1.. as @a[team=hunters,scores={manhunt_hunter_protect=1..}] run effect give @s minecraft:resistance 2 4 true
execute if score Temp manhunt_enabled matches 1.. as @a[team=hunters,scores={manhunt_hunter_protect=1..}] run effect give @s minecraft:blindness 2 1 true
execute if score Temp manhunt_enabled matches 1.. as @a[team=hunters,scores={manhunt_hunter_protect=1..}] run effect give @s minecraft:slowness 2 255 true
execute if score Temp manhunt_enabled matches 1.. as @a[team=hunters,scores={manhunt_hunter_protect=1..}] run effect give @s minecraft:mining_fatigue 2 255 true
execute if score Temp manhunt_enabled matches 1.. run scoreboard players remove @a[team=hunters,scores={manhunt_hunter_protect=1..}] manhunt_hunter_protect 1

scoreboard players set @a manhunt_deaths 0

scoreboard players add Temp manhunt_ticks 1
execute if score Temp manhunt_ticks matches 20.. run function manhunt:second
