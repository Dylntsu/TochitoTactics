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

# --- ESTADOS DEL JUGADOR ---
enum State { IDLE, RUNNING, QB_AIMING, QB_THROWING }
var current_state = State.IDLE

# --- VARIABLES DE LANZAMIENTO ---
var has_ball: bool = false
var aim_start_pos: Vector2
var throw_vector: Vector2 = Vector2.ZERO
var max_throw_power: float = 300.0 

# Línea visual para apuntar 
var aim_line: Line2D

# --- LÓGICA DEL JUEGO ---
var current_stamina_percentage: float = 100.0 
var active_route: Array = []
var target_index: int = 0
var is_running: bool = false
var current_stamina: float = 0.0 
var player_id: int = 0

const WORLD_SPEED_SCALE = 15.0

@onready var anim = $Visuals/AnimatedSprite2D

func _ready():
	input_pickable = true
	current_stamina = float(stamina_stat)
	
	# Configurar línea de apuntado
	aim_line = Line2D.new()
	aim_line.width = 4.0
	aim_line.default_color = Color(1, 1, 0, 0.7) 
	aim_line.visible = false
	add_child(aim_line)
	
	# Animación inicial (Seguridad)
	if anim.sprite_frames.has_animation("idabel_idle_back"):
		anim.play("idabel_idle_back")

# ==============================================================================
# 1. FUNCIÓN PARA RECIBIR DATOS 
# ==============================================================================
func setup_stats(data: Resource):
	if not data: return
		
	var val = data.get("full_name")
	player_name = val if val != null else "Jugador"
	val = data.get("speed")
	speed_stat = int(val) if val != null else 50
	val = data.get("stamina")
	stamina_stat = int(val) if val != null else 50
	val = data.get("hands")
	hands_stat = int(val) if val != null else 50
	val = data.get("arm")
	arm_stat = int(val) if val != null else 50
	val = data.get("agility")
	agility_stat = int(val) if val != null else 50
	val = data.get("game_sense")
	game_sense_stat = int(val) if val != null else 50
	
	current_stamina = float(stamina_stat)
	print("Stats cargados en MatchPlayer: ", player_name, " Vel: ", speed_stat)

# ==============================================================================
# 2. FUNCIÓN PARA CAMINAR AL INICIO 
# ==============================================================================
func move_to_setup(target_pos: Vector2, duration: float = 1.0):
	# 1. Calcular dirección para la animación mientras camina
	var direction = global_position.direction_to(target_pos)
	_update_animation_logic(direction)
	
	# 2. Mover suavemente con Tween
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(self, "global_position", target_pos, duration)
	
	# 3. AL LLEGAR: Poner Idle correcto
	tween.tween_callback(func():
		if anim:
			# Verificamos que el nombre sea "Dani" antes de poner su animación
			if player_name == "Dani" and anim.sprite_frames.has_animation("dani_back_idle"):
				anim.play("dani_back_idle")
			else:
				# Para todos los demás (Idabel, HeadHunter, Zack, etc.)
				anim.play("idabel_idle_back")
				
		$Visuals.scale.x = 1
	)

# ==============================================================================
# MECÁNICA DE LANZAMIENTO (NOMBRES UNIFICADOS)
# ==============================================================================

# 1. Llamado por el MatchPlayer tras el Snap
func receive_snap():
	has_ball = true
	current_state = State.QB_AIMING
	
	print(player_name, ": ¡Balón recibido!")
	
	# IMPORTANTE: Usamos "dani_back_launching" que es el que usas abajo
	if anim.sprite_frames.has_animation("dani_back_launching"):
		anim.stop() 
		anim.frame = 0 
		anim.play("dani_back_launching")
		
		# Conectamos señal
		if not anim.frame_changed.is_connected(_on_anim_frame_changed):
			anim.frame_changed.connect(_on_anim_frame_changed)
	else:
		print("ERROR: No encuentro la animación 'dani_back_launching'")

# 2. Control preciso de frames
func _on_anim_frame_changed():
	# IMPORTANTE: Verificar el mismo nombre que arriba
	if anim.animation == "dani_back_launching":
		# Frame 0, 1: Alzando
		# Frame 2: PAUSA (Listo para lanzar)
		if anim.frame == 2 and current_state == State.QB_AIMING:
			anim.pause() 

# 3. Input para apuntar 
func _input(event):
	if current_state != State.QB_AIMING: return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				aim_start_pos = get_global_mouse_position()
				aim_line.visible = true
			else:
				perform_throw() 

	elif event is InputEventMouseMotion and aim_line.visible:
		var current_mouse = get_global_mouse_position()
		var drag_vector = aim_start_pos - current_mouse 
		
		if drag_vector.length() > max_throw_power:
			drag_vector = drag_vector.normalized() * max_throw_power
			
		throw_vector = drag_vector
		aim_line.points = [Vector2.ZERO, throw_vector]
		
		var intensity = throw_vector.length() / max_throw_power
		aim_line.default_color = Color.GREEN.lerp(Color.RED, intensity)

# 4. Ejecutar lanzamiento
func perform_throw():
	if throw_vector.length() < 10.0: 
		aim_line.visible = false
		return

	print("¡PASE LANZADO! Fuerza: ", throw_vector.length())
	
	current_state = State.QB_THROWING 
	aim_line.visible = false
	
	# Continuamos la animación "dani_back_launching" donde se quedó
	anim.play("dani_back_launching") 
	
	# Desconectamos para evitar bugs futuros
	if anim.frame_changed.is_connected(_on_anim_frame_changed):
		anim.frame_changed.disconnect(_on_anim_frame_changed)
	
	await anim.animation_finished
	
	# Volver a idle de Dani
	if anim.sprite_frames.has_animation("dani_back_idle"):
		anim.play("dani_back_idle")
	else:
		anim.play("idabel_idle_back")

# ==============================================================================
# LÓGICA PHYSICS PROCESS
# ==============================================================================
func _physics_process(delta):
	# 1. BLOQUEO DE ESTADO QB
	if current_state == State.QB_AIMING or current_state == State.QB_THROWING:
		return

	# 2. VALIDACIONES DE RUTA
	if not is_running:
		return

	if active_route.is_empty(): 
		is_running = false
		return

	if target_index >= active_route.size():
		is_running = false
		active_route = [] 
		# Idle al terminar ruta
		if anim.sprite_frames.has_animation("dani_back_idle") and player_name == "Dani":
			anim.play("dani_back_idle")
		else:
			anim.play("idabel_idle_back")
		return

	# 3. CONSUMO DE ESTAMINA
	if current_stamina_percentage > 0:
		var safe_stamina = max(1, float(stamina_stat)) 
		var consumption_rate = 10.0 / safe_stamina
		current_stamina_percentage -= delta * consumption_rate
		_send_data_to_ui()
	
	# 4. MOVIMIENTO
	var target_pos = active_route[target_index]
	var direction = global_position.direction_to(target_pos)
	
	var final_speed = (speed_stat * WORLD_SPEED_SCALE)
	if current_stamina_percentage <= 0:
		final_speed *= 0.4 
		
	velocity = direction * final_speed
	move_and_slide()
	
	_update_animation_logic(direction)

	# 5. CAMBIO DE WAYPOINT
	if global_position.distance_to(target_pos) < 10.0:
			target_index += 1
			if target_index >= active_route.size():
				is_running = false
				active_route = [] 
				
				if player_name == "Dani" and anim.sprite_frames.has_animation("dani_back_idle"):
					anim.play("dani_back_idle")
				else:
					anim.play("idabel_idle_back")

# ==============================================================================
# LÓGICA DE ANIMACIÓN 8 DIRECCIONES
# ==============================================================================
func _update_animation_logic(dir: Vector2):
	if dir.length() < 0.1: return
	
	var abs_x = abs(dir.x)
	var abs_y = abs(dir.y)
	
	if abs_x > 0.4 and abs_y > 0.4:
		if dir.y > 0: # Front
			if anim.sprite_frames.has_animation("idabel_running_diag_front"):
				anim.play("idabel_running_diag_front")
			$Visuals.scale.x = -1 if dir.x < 0 else 1
		else: # Back
			if anim.sprite_frames.has_animation("idabel_running_diag_back"):
				anim.play("idabel_running_diag_back")
			$Visuals.scale.x = -1 if dir.x > 0 else 1
	else:
		if abs_x > abs_y:
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
			"stamina_display": stamina_stat,
			"stamina_current": current_stamina_percentage,
			"arm": arm_stat,
			"agility": agility_stat,
			"game_sense": game_sense_stat
		})
