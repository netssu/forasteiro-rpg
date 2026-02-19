spreadplayers 0 0 16 1000 false @a[team=runners]
execute as @a[team=runners,limit=1] at @s run tp @a[team=hunters] ~400 ~ ~
tellraw @a {"text":"Times teleportados aleatoriamente com ~400 blocos de distancia.","color":"aqua"}
