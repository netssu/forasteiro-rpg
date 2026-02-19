tag @s add manhunt_seen

team join runners @s

tellraw @s [{"text":"[Manhunt] ","color":"gold","bold":true},{"text":"Clique para escolher time: ","color":"yellow"},{"text":"[Runner] ","color":"red","bold":true,"clickEvent":{"action":"run_command","value":"/team join runners @s"}},{"text":"ou ","color":"white"},{"text":"[Hunter]","color":"blue","bold":true,"clickEvent":{"action":"run_command","value":"/team join hunters @s"}}]
function manhunt:controls
