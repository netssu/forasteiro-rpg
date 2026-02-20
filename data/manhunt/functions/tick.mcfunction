execute if score Temp manhunt_enabled matches 1.. as @a[scores={manhunt_deaths=1..},team=hunters] run function manhunt:hunter_death
execute if score Temp manhunt_enabled matches 1.. as @a[scores={manhunt_deaths=1..},team=runners] if entity @a[team=runners,limit=2] run function manhunt:runner_death_multi
execute if score Temp manhunt_enabled matches 1.. as @a[scores={manhunt_deaths=1..},team=runners] unless entity @a[team=runners,limit=2] run function manhunt:hunted_death
scoreboard players set @a manhunt_deaths 0

scoreboard players add Temp manhunt_ticks 1
execute if score Temp manhunt_ticks matches 20.. run function manhunt:second
