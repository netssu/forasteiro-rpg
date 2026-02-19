$execute if score Temp manhunt_start_mode matches 1 as @a[team=runners,limit=1] at @s run spreadplayers ~ ~ $(spawn_distance) $(spawn_distance) true @a[team=hunters]
$execute if score Temp manhunt_start_mode matches 1 unless entity @a[team=runners] run spreadplayers ~ ~ $(spawn_distance) $(spawn_distance) true @a[team=hunters]

$execute if score Temp manhunt_start_mode matches 2 positioned 0 0 0 run spreadplayers ~ ~ 0 10000 true @a[team=runners]
$execute if score Temp manhunt_start_mode matches 2 as @a[team=runners,limit=1] at @s run spreadplayers ~ ~ $(spawn_distance) $(spawn_distance) true @a[team=hunters]
$execute if score Temp manhunt_start_mode matches 2 unless entity @a[team=runners] run spreadplayers ~ ~ 0 10000 true @a[team=hunters]

# Mode 3 keeps everyone in place, hunters are locked until compass unlock
