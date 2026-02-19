tag @s add manhunt_seen

team join runners @s
scoreboard players enable @s manhunt_action

function manhunt:give_menu_book

tellraw @s [{"text":"[Manhunt] ","color":"gold","bold":true},{"text":"Escolha seu time no livro ou clique: ","color":"yellow"},{"text":"[Runner] ","color":"red","bold":true,"clickEvent":{"action":"run_command","value":"/trigger manhunt_action set 1"}},{"text":"ou ","color":"white"},{"text":"[Hunter]","color":"blue","bold":true,"clickEvent":{"action":"run_command","value":"/trigger manhunt_action set 2"}}]
