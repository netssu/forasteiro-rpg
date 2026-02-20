execute as @a[tag=manhunt_hunter_dead,scores={manhunt_respawn_s=1..}] run title @s actionbar [{"text":"Respawn em ","color":"gold"},{"score":{"name":"@s","objective":"manhunt_respawn_s"},"color":"yellow"},{"text":"s","color":"gold"}]
execute as @a[tag=manhunt_runner_dead,scores={manhunt_respawn_s=1..}] run title @s actionbar [{"text":"Respawn em ","color":"gold"},{"score":{"name":"@s","objective":"manhunt_respawn_s"},"color":"yellow"},{"text":"s","color":"gold"}]

execute as @a[tag=manhunt_hunter_dead,scores={manhunt_respawn_s=1..}] run scoreboard players remove @s manhunt_respawn_s 1
execute as @a[tag=manhunt_runner_dead,scores={manhunt_respawn_s=1..}] run scoreboard players remove @s manhunt_respawn_s 1

execute as @a[tag=manhunt_hunter_dead,scores={manhunt_respawn_s=..0}] run function manhunt:hunter_respawn
execute as @a[tag=manhunt_runner_dead,scores={manhunt_respawn_s=..0}] run function manhunt:runner_respawn

execute if entity @a[team=runners,tag=manhunt_runner_dead] run effect give @a[team=runners,tag=!manhunt_runner_dead] minecraft:glowing 120 0 true
