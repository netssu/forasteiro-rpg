execute as @e[team=runners] unless score @s manhunt_rid matches -2147483647.. run execute store result score @s manhunt_rid run data get entity @s UUID[0]

#Compass unlock countdown
execute if score Starts: manhunt_display matches 1.. run scoreboard players remove Starts: manhunt_display 1
execute if score Starts: manhunt_display matches 1.. run clear @a[team=hunters] minecraft:compass

#Game over detection (runners)
execute unless entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_respawn_wait,gamemode=!spectator] run function manhunt:decide_winners

#Game over detection (hunters)
execute unless entity @a[team=hunters] run function manhunt:decide_winners

#Game over detection (dragon death)
execute in minecraft:the_end as @a[predicate=manhunt:in_end] if score Temp manhunt_end matches 1.. run scoreboard players remove Temp manhunt_end 1
execute if score Temp manhunt_end matches 0 unless entity @e[type=minecraft:ender_dragon] run function manhunt:dragon_death

#Give hunters compass after countdown
execute if score Starts: manhunt_display matches ..0 as @a[team=hunters] unless entity @s[nbt={Inventory:[{id:"minecraft:compass"}]}] run give @s minecraft:compass

#Show hunters health on tab list only for hunters
execute as @a[team=hunters] store result score @s manhunt_tab_hp run data get entity @s Health 1
scoreboard players reset @a[team=runners] manhunt_tab_hp

#Alert when a hunter enters the 100 block radius of any runner
tag @a[team=hunters] remove manhunt_near_now
execute as @a[team=hunters] at @s if entity @e[team=runners,tag=!manhunt_died,distance=..100] run tag @s add manhunt_near_now
execute as @a[team=hunters,tag=manhunt_near_now,tag=!manhunt_near_before] run tellraw @a [{"text":"[Manhunt] ","color":"gold"},{"selector":"@s","color":"blue"},{"text":" está no raio de 100 blocos de um runner.","color":"yellow"}]
tag @a[team=hunters] remove manhunt_near_before
tag @a[team=hunters,tag=manhunt_near_now] add manhunt_near_before

function manhunt:grab_position

execute as @a[team=hunters] at @s if predicate manhunt:in_overworld run function manhunt:update_compass_overworld_old
execute as @a[team=hunters] at @s if predicate manhunt:in_nether run function manhunt:update_compass_nether_old

execute as @a[team=hunters] at @s if predicate manhunt:in_overworld run function manhunt:update_compass_overworld_new
execute as @a[team=hunters] at @s if predicate manhunt:in_nether run function manhunt:update_compass_nether_new


#Runner respawn timer and glowing
execute as @a[team=runners,tag=manhunt_respawn_wait,scores={manhunt_runner_respawn=1..}] run title @s actionbar [{"text":"Respawn em ","color":"yellow"},{"score":{"name":"@s","objective":"manhunt_runner_respawn"},"color":"gold"},{"text":"s","color":"yellow"}]
scoreboard players remove @a[team=runners,tag=manhunt_respawn_wait,scores={manhunt_runner_respawn=1..}] manhunt_runner_respawn 1

execute as @a[team=runners,tag=manhunt_respawn_wait,scores={manhunt_runner_respawn=..0}] if entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_respawn_wait,gamemode=!spectator,limit=1] at @a[team=runners,tag=!manhunt_died,tag=!manhunt_respawn_wait,gamemode=!spectator,sort=random,limit=1] run tp @s ~ ~ ~
execute as @a[team=runners,tag=manhunt_respawn_wait,scores={manhunt_runner_respawn=..0}] if entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_respawn_wait,gamemode=!spectator,limit=1] run gamemode survival @s
execute as @a[team=runners,tag=manhunt_respawn_wait,scores={manhunt_runner_respawn=..0}] if entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_respawn_wait,gamemode=!spectator,limit=1] run tag @s remove manhunt_respawn_wait
execute as @a[team=runners,tag=manhunt_respawn_wait,scores={manhunt_runner_respawn=..0}] if entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_respawn_wait,gamemode=!spectator,limit=1] run scoreboard players set @s manhunt_runner_glow 60
execute as @a[team=runners,tag=manhunt_respawn_wait,scores={manhunt_runner_respawn=..0}] if entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_respawn_wait,gamemode=!spectator,limit=1] run effect give @s minecraft:glowing 60 0 true
execute as @a[team=runners,tag=manhunt_respawn_wait,scores={manhunt_runner_respawn=..0}] unless entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_respawn_wait,gamemode=!spectator,limit=1] run tag @s add manhunt_died
execute as @a[team=runners,tag=manhunt_respawn_wait,scores={manhunt_runner_respawn=..0}] unless entity @a[team=runners,tag=!manhunt_died,tag=!manhunt_respawn_wait,gamemode=!spectator,limit=1] run tag @s remove manhunt_respawn_wait

execute as @a[team=runners,scores={manhunt_runner_glow=1..}] run effect give @s minecraft:glowing 2 0 true
scoreboard players remove @a[team=runners,scores={manhunt_runner_glow=1..}] manhunt_runner_glow 1
