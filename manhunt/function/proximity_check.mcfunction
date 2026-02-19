tag @a[team=hunters] remove manhunt_near_now
$execute as @a[team=hunters] at @s if entity @e[team=runners,tag=!manhunt_died,distance=..$(alert_distance)] run tag @s add manhunt_near_now
execute as @a[team=hunters,tag=manhunt_near_now,tag=!manhunt_near_before] run tellraw @a [{"text":"[Manhunt] ","color":"gold"},{"selector":"@s","color":"blue"},{"text":" está no raio configurado de um runner.","color":"yellow"}]
tag @a[team=hunters] remove manhunt_near_before
tag @a[team=hunters,tag=manhunt_near_now] add manhunt_near_before
