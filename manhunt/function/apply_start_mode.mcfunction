# Mode 1: hunters are teleported away from runners (runners keep position)
execute if score Temp manhunt_start_mode matches 1 if score Temp manhunt_spawn_distance matches ..349 as @a[team=runners,limit=1] at @s run spreadplayers ~ ~ 300 300 true @a[team=hunters]
execute if score Temp manhunt_start_mode matches 1 if score Temp manhunt_spawn_distance matches 350..549 as @a[team=runners,limit=1] at @s run spreadplayers ~ ~ 400 400 true @a[team=hunters]
execute if score Temp manhunt_start_mode matches 1 if score Temp manhunt_spawn_distance matches 550.. as @a[team=runners,limit=1] at @s run spreadplayers ~ ~ 700 700 true @a[team=hunters]

# Mode 2: runners go random first, then hunters are teleported away from runners
execute if score Temp manhunt_start_mode matches 2 positioned 0 0 0 run spreadplayers ~ ~ 0 10000 true @a[team=runners]
execute if score Temp manhunt_start_mode matches 2 if score Temp manhunt_spawn_distance matches ..349 as @a[team=runners,limit=1] at @s run spreadplayers ~ ~ 300 300 true @a[team=hunters]
execute if score Temp manhunt_start_mode matches 2 if score Temp manhunt_spawn_distance matches 350..549 as @a[team=runners,limit=1] at @s run spreadplayers ~ ~ 400 400 true @a[team=hunters]
execute if score Temp manhunt_start_mode matches 2 if score Temp manhunt_spawn_distance matches 550.. as @a[team=runners,limit=1] at @s run spreadplayers ~ ~ 700 700 true @a[team=hunters]

# Mode 3: everyone keeps position; hunter lock happens in hunt_second countdown
