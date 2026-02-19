scoreboard players set @s manhunt_joined 1
tellraw @s [{"text":"§6[Manhunt] §fBem-vindo! Clique para entrar em um time: "},{"text":"[Runner] ","color":"red","bold":true,"clickEvent":{"action":"run_command","value":"/team join runners"}},{"text":"[Hunter]","color":"blue","bold":true,"clickEvent":{"action":"run_command","value":"/team join hunters"}}]
tellraw @s [{"text":"§6[Manhunt] §fMenu rápido: "},{"text":"[Mostrar opções]","color":"green","clickEvent":{"action":"run_command","value":"/function manhunt:show_menu"}}]
