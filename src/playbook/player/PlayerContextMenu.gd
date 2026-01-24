extends Control

signal role_changed(new_role: String)

@onready var pos_button = %PosButton

var icons = {
	"WR": preload("res://assets/sprites/icons/gloves_icon.png"),
	"CENTER": preload("res://assets/sprites/Icons/center_icon.png"),
	"QB": preload("res://assets/sprites/icons/ball_icon.png")
}
var roles = ["WR", "CENTER", "QB"]
var current_role_idx = 0

# Guardamos una referencia al jugador actual para poder cambiarle el rol después
var current_player_node: Node2D

func _ready():
	 # Conexión manual por código para asegurar escalabilidad
	if pos_button:
		if not pos_button.pressed.is_connected(_on_pos_button_pressed):
			pos_button.pressed.connect(_on_pos_button_pressed)

func setup(player_node: Node2D):
	if not is_instance_valid(player_node): return
	current_player_node = player_node
	
	# 1. NOMBRE DEL JUGADOR 
	if %Header:
		var p_name = player_node.get("player_name")
		if p_name == null or p_name == "":
			# Si no tiene nombre, inventamos uno o usamos su posición inicial
			p_name = "Prospecto " + str(player_node.player_id + 1)
		
		%Header.text = str(p_name) + " Manage"
	
	# 2. RETRATO
	if player_node.get("sprite") and player_node.sprite.texture:
		%Portrait.texture = player_node.sprite.texture
	
	# 3. STATS
	_set_bar_value(%StaminaBar, player_node, "stamina_stat")
	_set_bar_value(%VelocityBar, player_node, "speed_stat")
	_set_bar_value(%HandsBar, player_node, "hands_stat")
	_set_bar_value(%ArmBar, player_node, "arm_stat")
	_set_bar_value(%SenseBar, player_node, "game_sense_stat")
	_set_bar_value(%AgilityBar, player_node, "agility_stat")
	
	# 4. ROL ACTUAL
	var current_role = player_node.get("role")
	if current_role == null: current_role = "WR"
	
	current_role_idx = roles.find(current_role)
	if current_role_idx == -1: current_role_idx = 0
	
	_update_button_visuals()

# Función de apoyo para las barras
func _set_bar_value(bar: ProgressBar, node: Node2D, stat_name: String):
	if bar == null: return
	var val = node.get(stat_name)
	bar.value = val if val != null else 0

func _on_pos_button_pressed():
	current_role_idx = (current_role_idx + 1) % roles.size()
	var new_role = roles[current_role_idx]
	
	# Aplicamos el cambio directamente al nodo del jugador para que sea persistente
	if is_instance_valid(current_player_node):
		current_player_node.role = new_role
	
	_update_button_visuals()
	role_changed.emit(new_role)

func _update_button_visuals():
	var role_name = roles[current_role_idx]
	if pos_button:
		pos_button.texture_normal = icons[role_name]
	
	if %RoleLabel:
		%RoleLabel.text = role_name
