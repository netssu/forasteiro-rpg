execute if score Config:WarnDistance manhunt_lead matches ..0 run scoreboard players set Config:WarnDistance manhunt_lead 100
execute if score Config:WarnDistance manhunt_lead matches 50 run function manhunt:warn_distance_50
execute if score Config:WarnDistance manhunt_lead matches 100 run function manhunt:warn_distance_100
execute if score Config:WarnDistance manhunt_lead matches 150 run function manhunt:warn_distance_150
execute if score Config:WarnDistance manhunt_lead matches 200 run function manhunt:warn_distance_200
execute unless score Config:WarnDistance manhunt_lead matches 50 unless score Config:WarnDistance manhunt_lead matches 100 unless score Config:WarnDistance manhunt_lead matches 150 unless score Config:WarnDistance manhunt_lead matches 200 run function manhunt:warn_distance_100
