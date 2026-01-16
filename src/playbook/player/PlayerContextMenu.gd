# PlayerContextMenu.gd
extends Control

signal role_changed(new_role: String)

@onready var pos_button = %PosButton
@onready var stat_bars = {
	"stamina": %StaminaBar,
	"velocity": %VelocityBar,
	"hands": %HandsBar,
	"arm": %ArmBar,
	"game_sense": %SenseBar,
	"agility": %AgilityBar
}

# Iconos para el ciclo
var icons = {
	"WR": preload("res://assets/sprites/icons/gloves_icon.png"),
	"CENTER": preload("res://assets/sprites/Icons/center_icon.png"),
	"QB": preload("res://assets/sprites/icons/ball_icon.png")
}
var roles = ["WR", "CENTER", "QB"]
var current_role_idx = 0

func setup(player_node):
	# 1. Cargar retrato y stats reales del jugador
	%Portrait.texture = player_node.player_sprite.texture
	for stat in stat_bars:
		stat_bars[stat].value = player_node.get(stat + "_stat")
	
	# 2. Sincronizar el rol actual
	current_role_idx = roles.find(player_node.role)
	_update_button_visuals()
	show()

func _on_pos_button_pressed():
	# Ciclo: WR (Guantes) -> CENTER (Centro) -> QB (Balón)
	current_role_idx = (current_role_idx + 1) % roles.size()
	var new_role = roles[current_role_idx]
	
	_update_button_visuals()
	role_changed.emit(new_role)

func _update_button_visuals():
	var role = roles[current_role_idx]
	pos_button.texture_normal = icons[role]
	%RoleLabel.text = role
