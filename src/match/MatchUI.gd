extends CanvasLayer

@onready var name_label = %Label 
@onready var speed_val = %VelocityLabel
@onready var hands_val = %HandsLabel
@onready var stamina_val = %StaminaLabel
@onready var arm_val = %ArmLabel
@onready var agility_val = %AgilityLabel
@onready var sense_val = %BrainLabel
@onready var stamina_bar = %StaminaBar


func update_player_stats(data: Dictionary):
	# 1. Textos básicos 
	if name_label: name_label.text = data["name"]
	if speed_val: speed_val.text = str(data["speed"])
	if hands_val: hands_val.text = str(data["hands"])
	if arm_val: arm_val.text = str(data["arm"])
	if agility_val: agility_val.text = str(data["agility"])
	if sense_val: sense_val.text = str(data["game_sense"])
	
	# Usamos 'stamina_display' que es el valor fijo que enviamos desde el cuerpo
	if %StaminaLabel: 
		%StaminaLabel.text = str(int(data["stamina_display"]))

	# 3. La Barra de Estamina 
	if stamina_bar:
		stamina_bar.max_value = 100.0
		stamina_bar.value = data["stamina_current"]
