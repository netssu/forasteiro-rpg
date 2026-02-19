tag @s add manhunt_died

summon item ~ ~ ~ {Item:{id:"minecraft:player_head",count:1,components:{"minecraft:profile":{id:[I;0,0,0,0]}}},Tags:["manhunt_head_drop"]}
data modify entity @e[type=item,tag=manhunt_head_drop,sort=nearest,limit=1,distance=..3] Item.components."minecraft:profile".id set from entity @s UUID
tag @e[type=item,tag=manhunt_head_drop,sort=nearest,limit=1,distance=..3] remove manhunt_head_drop

gamemode spectator @s
