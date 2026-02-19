tag @a[team=hunters] remove manhunt_near_now

execute if score Temp manhunt_alert_distance matches ..74 as @a[team=hunters] at @s if entity @e[team=runners,tag=!manhunt_died,distance=..50] run tag @s add manhunt_near_now
execute if score Temp manhunt_alert_distance matches 75..124 as @a[team=hunters] at @s if entity @e[team=runners,tag=!manhunt_died,distance=..100] run tag @s add manhunt_near_now
execute if score Temp manhunt_alert_distance matches 125.. as @a[team=hunters] at @s if entity @e[team=runners,tag=!manhunt_died,distance=..150] run tag @s add manhunt_near_now

execute as @a[team=hunters,tag=manhunt_near_now,tag=!manhunt_near_before] run tellraw @a [{"text":"[Manhunt] ","color":"gold"},{"selector":"@s","color":"blue"},{"text":" entrou no raio de um runner.","color":"yellow"}]
tag @a[team=hunters] remove manhunt_near_before
tag @a[team=hunters,tag=manhunt_near_now] add manhunt_near_before
