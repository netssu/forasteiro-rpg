summon item ~ ~ ~ {Item:{id:"minecraft:player_head",count:1}}
data modify entity @e[type=item,sort=nearest,limit=1,distance=..2] Item.components."minecraft:profile" set value {name:"Hunter"}
