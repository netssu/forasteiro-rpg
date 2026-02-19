execute as @a[team=runners,tag=!manhunt_near] at @s if entity @a[team=hunters,distance=..50] run function manhunt:runner_entered_radius
execute as @a[team=runners,tag=manhunt_near] at @s unless entity @a[team=hunters,distance=..50] run tag @s remove manhunt_near
