execute as @a unless score @s manhunt_joined matches 1.. run function manhunt:player_joined

execute if score Temp manhunt_enabled matches 1.. as @a[scores={manhunt_deaths=1..}] run function manhunt:drop_head
execute if score Temp manhunt_enabled matches 1.. as @a[scores={manhunt_deaths=1..},team=runners] run function manhunt:runners_death
scoreboard players set @a manhunt_deaths 0

scoreboard players add Temp manhunt_ticks 1
execute if score Temp manhunt_ticks matches 20.. run function manhunt:second
