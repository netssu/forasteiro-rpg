execute at @s run summon item ~ ~ ~ {Item:{id:"minecraft:player_head",count:1b,tag:{SkullOwner:{}}}}
execute at @s run data modify entity @e[type=item,sort=nearest,limit=1,distance=..2,nbt={Item:{id:"minecraft:player_head"}}] Item.tag.SkullOwner.Id set from entity @s UUID
