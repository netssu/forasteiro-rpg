scoreboard players remove Starts: manhunt_display 1

execute if score Config:StartMode manhunt_lead matches 0 run effect give @a[team=hunters] minecraft:slowness 2 255
execute if score Config:StartMode manhunt_lead matches 0 run effect give @a[team=hunters] minecraft:blindness 2 255
execute if score Config:StartMode manhunt_lead matches 0 run effect give @a[team=hunters] minecraft:mining_fatigue 2 255
execute if score Config:StartMode manhunt_lead matches 0 run effect give @a[team=hunters] minecraft:weakness 2 255

execute if score Starts: manhunt_display matches ..0 run function manhunt:start_hunt
