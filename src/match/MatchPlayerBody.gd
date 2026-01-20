extends CharacterBody2D

# --- STATS PARA LA UI ---
@export_group("Atleta Stats")
@export var player_name: String = "Idabel"
@export var speed_stat: int = 8
@export var hands_stat: int = 5
@export var stamina_stat: int = 7
@export var arm_stat: int = 6
@export var agility_stat: int = 4
@export var game_sense_stat: int = 5


# --- LÓGICA DEL JUEGO ---
var current_stamina_percentage: float = 100.0 # La barra siempre inicia al 100
var active_route: Array = []
var target_index: int = 0
var is_running: bool = false
var current_stamina: float = 0.0 # Estamina actual en tiempo real
var player_id: int = 0

var has_ball: bool = false # Controlado por el Ball.gd al hacer attach

const WORLD_SPEED_SCALE = 15.0

@onready var anim = $Visuals/AnimatedSprite2D

func _ready():
	# Aseguramos que el personaje sea clickeable
	input_pickable = true
	# Inicializamos la estamina con el valor del stat
	current_stamina = float(stamina_stat)
	
	# REPRODUCCIÓN DE IDLE AL INICIO
	if anim.sprite_frames.has_animation("idabel_idle_back"):
		anim.play("idabel_idle_back")
		print("Animación iniciada: ", anim.animation) 
	else:
		anim.play("idabel_running_back")
		anim.stop()
	
func _physics_process(delta):
	# 1. Si no está corriendo, mantenemos el idle y salimos
	if not is_running:
		if anim.animation != "idabel_idle_back":
			anim.play("idabel_idle_back")
		return

	# 2. Validación de seguridad para la ruta
	if active_route.is_empty(): 
		is_running = false
		return

	# 3. COMPROBACIÓN DE LÍMITES 
	if target_index >= active_route.size():
		is_running = false
		active_route = [] 
		anim.play("idabel_idle_back")
		return

	# --- LÓGICA DE CONSUMO DE ESTAMINA ---
	if current_stamina_percentage > 0:
		var consumption_rate = 10.0 / float(stamina_stat)
		current_stamina_percentage -= delta * consumption_rate
		_send_data_to_ui()
	
	# 4. MOVIMIENTO HACIA EL PUNTO ACTUAL
	var target_pos = active_route[target_index]
	var direction = global_position.direction_to(target_pos)
	
	# Ajuste de velocidad por estamina
	var final_speed = (speed_stat * WORLD_SPEED_SCALE)
	if current_stamina_percentage <= 0:
		final_speed *= 0.4 
		
	velocity = direction * final_speed
	move_and_slide()
	_update_animation_logic(direction)

	# 5. LÓGICA DE CAMBIO DE PUNTO
	if global_position.distance_to(target_pos) < 10.0:
		target_index += 1
		# Verificación inmediata tras incrementar el índice
		if target_index >= active_route.size():
			is_running = false
			active_route = [] 
			anim.play("idabel_idle_back")

func _update_animation_logic(dir: Vector2):
	if dir.length() < 0.1: return
	
	if abs(dir.x) > abs(dir.y):
		anim.play("idabel_running_90")
		$Visuals.scale.x = -1 if dir.x < 0 else 1
	elif dir.y > 0:
		anim.play("idabel_running_front")
		$Visuals.scale.x = 1
	else:
		anim.play("idabel_running_back")
		$Visuals.scale.x = 1

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_send_data_to_ui()

func _send_data_to_ui():
	var match_ui = get_tree().current_scene.find_child("MatchUI", true, false)
	if match_ui and match_ui.has_method("update_player_stats"):
		match_ui.update_player_stats({
			"name": player_name,
			"speed": speed_stat,
			"hands": hands_stat,
			"stamina_display": stamina_stat,        # El número fijo
			"stamina_current": current_stamina_percentage, # La barra
			"arm": arm_stat,
			"agility": agility_stat,
			"game_sense": game_sense_stat
		})
