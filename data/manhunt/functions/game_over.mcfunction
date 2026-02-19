clear @a[team=hunters] minecraft:compass
title @a title {"text":"Game over","bold":true,"color":"gold"}
scoreboard players set Temp manhunt_enabled 0
scoreboard players set Starts: manhunt_display 0

execute as @a run function manhunt:give_menu_book
tellraw @a [{"text":"[Manhunt] ","color":"gold","bold":true},{"text":"Use o livro para configurar e iniciar nova partida.","color":"yellow"}]
