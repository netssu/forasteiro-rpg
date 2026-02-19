scoreboard objectives add manhunt_action trigger
tag @s add manhunt_seen

team join runners @s
scoreboard players enable @s manhunt_action

function manhunt:give_menu_book

tellraw @s [{"text":"[Manhunt] ","color":"gold","bold":true},{"text":"Livro entregue. Teste clique: ","color":"yellow"},{"text":"[Runner] ","color":"red","underlined":true,"click_event":{"action":"run_command","command":"trigger manhunt_action set 1"},"hover_event":{"action":"show_text","value":"Entrar no time Runner"}},{"text":"ou ","color":"white"},{"text":"[Hunter]","color":"blue","underlined":true,"click_event":{"action":"run_command","command":"trigger manhunt_action set 2"},"hover_event":{"action":"show_text","value":"Entrar no time Hunter"}}]
