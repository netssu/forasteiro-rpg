tag @s add manhunt_seen

team leave @s
team join runners @s
scoreboard players enable @s manhunt_action

function manhunt:give_menu_book

tellraw @s [{"text":"[Manhunt] ","color":"gold","bold":true},{"text":"Livro entregue. Clique para escolher: ","color":"yellow"},{"text":"[Runner] ","color":"red","underlined":true,"click_event":{"action":"run_command","command":"trigger manhunt_action set 1"}},{"text":"ou ","color":"white"},{"text":"[Hunter]","color":"blue","underlined":true,"click_event":{"action":"run_command","command":"trigger manhunt_action set 2"}}]
