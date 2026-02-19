execute as @e[team=runners] unless score @s manhunt_rid matches -2147483647.. run execute store result score @s manhunt_rid run data get entity @s UUID[0]

#Prevent a late joiner from having a compass
execute if score Starts: manhunt_display matches 1.. run clear @a[team=hunters] minecraft:compass

#Game over detection (runners)
execute unless entity @e[team=runners,tag=!manhunt_died] run function manhunt:decide_winners

#Game over detection (hunters)
execute unless entity @a[team=hunters] run function manhunt:decide_winners

#Game over detection (dragon death)
execute in minecraft:the_end as @a[predicate=manhunt:in_end] if score Temp manhunt_end matches 1.. run scoreboard players remove Temp manhunt_end 1
execute if score Temp manhunt_end matches 0 unless entity @e[type=minecraft:ender_dragon] run function manhunt:dragon_death

#Give runners compass
execute as @a[team=hunters] unless entity @s[nbt={Inventory:[{id:"minecraft:compass"}]}] run give @s minecraft:compass

function manhunt:grab_position

execute as @a[team=hunters] at @s if predicate manhunt:in_overworld run function manhunt:update_compass_overworld_old
execute as @a[team=hunters] at @s if predicate manhunt:in_nether run function manhunt:update_compass_nether_old

execute as @a[team=hunters] at @s if predicate manhunt:in_overworld run function manhunt:update_compass_overworld_new
execute as @a[team=hunters] at @s if predicate manhunt:in_nether run function manhunt:update_compass_nether_new