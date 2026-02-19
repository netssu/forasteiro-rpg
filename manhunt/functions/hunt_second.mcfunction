execute as @a unless score @s manhunt_joined matches 1.. run function manhunt:player_joined

execute as @e[team=runners] unless score @s manhunt_rid matches -2147483647.. run execute store result score @s manhunt_rid run data get entity @s UUID[0]

#Compass unlock countdown
execute if score Starts: manhunt_display matches 1.. run scoreboard players remove Starts: manhunt_display 1
execute if score Starts: manhunt_display matches 1.. run clear @a[team=hunters] minecraft:compass

#Mode 3: lock hunters until compass unlock
execute if score Temp manhunt_start_mode matches 3 if score Starts: manhunt_display matches 1.. run effect give @a[team=hunters] minecraft:slowness 2 255
execute if score Temp manhunt_start_mode matches 3 if score Starts: manhunt_display matches 1.. run effect give @a[team=hunters] minecraft:blindness 2 255
execute if score Temp manhunt_start_mode matches 3 if score Starts: manhunt_display matches ..0 run effect clear @a[team=hunters] minecraft:slowness
execute if score Temp manhunt_start_mode matches 3 if score Starts: manhunt_display matches ..0 run effect clear @a[team=hunters] minecraft:blindness

#Game over detection (runners)
execute unless entity @e[team=runners,tag=!manhunt_died] run function manhunt:decide_winners

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

#Alert when a hunter enters configured radius of any runner
execute store result storage manhunt:config alert_distance int 1 run scoreboard players get Temp manhunt_alert_distance
function manhunt:proximity_check with storage manhunt:config

function manhunt:grab_position

execute as @a[team=hunters] at @s if predicate manhunt:in_overworld run function manhunt:update_compass_overworld_old
execute as @a[team=hunters] at @s if predicate manhunt:in_nether run function manhunt:update_compass_nether_old

execute as @a[team=hunters] at @s if predicate manhunt:in_overworld run function manhunt:update_compass_overworld_new
execute as @a[team=hunters] at @s if predicate manhunt:in_nether run function manhunt:update_compass_nether_new
