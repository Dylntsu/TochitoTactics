extends Area2D

# ==============================================================================
# SEÑALES
# ==============================================================================
signal start_route_requested(player_node)
signal moved(player_node)
signal interaction_ended 

# ==============================================================================
# ENTIDAD DE DATOS
# ==============================================================================
@export var data: PlayerStats:
	set(value):
		data = value
		if is_inside_tree(): _apply_data_to_visuals()

@export_group("Simulación de Movimiento")
@export var min_pixels_per_sec: float = 200.0 
@export var max_pixels_per_sec: float = 600.0

# Getters
var stamina_stat: float: 
	get: return data.stamina if data else 50.0
var speed_stat: float: 
	get: return data.speed if data else 50.0
var hands_stat: float: 
	get: return data.hands if data else 50.0
var arm_stat: float: 
	get:return data.arm if data else 50.0
var game_sense_stat: float: 
	get: return data.game_sense if data else 50.0
var agility_stat: float:
	get: return data.agility if data else 50.0
var player_name: String: 
	get: return data.full_name if data else ""

# ==============================================================================
# PROPIEDADES VISUALES
# ==============================================================================
@export var player_id: int = 0
@onready var sprite = $Sprite2D 
@onready var label = $Label 
@export var target_head_size: float = 80.0

# Buscamos el nodo de animación de forma segura
@onready var anim = get_node_or_null("Visuals/AnimatedSprite2D")
@onready var visuals_node = get_node_or_null("Visuals")

var current_route: PackedVector2Array = []
var starting_position: Vector2 
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var limit_rect: Rect2 = Rect2()
var _active_tween: Tween
var is_playing: bool = false
var role: String = "WR" 
@onready var visual_panel = get_node_or_null("Panel")
var is_running: bool = false 

# ==============================================================================
# CICLO DE VIDA
# ==============================================================================
func _ready():
	input_pickable = true 
	
	if sprite and sprite.material:
		sprite.material = sprite.material.duplicate()
	
	if visual_panel:
		visual_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.0, 0.4, 0.8, 1.0)
		style.set_corner_radius_all(20)
		visual_panel.add_theme_stylebox_override("panel", style)
	
	_apply_data_to_visuals()

func setup_stats(new_data: Resource):
	if new_data is PlayerStats:
		self.data = new_data
		print("Stats inyectados a Player ", player_id, " | Vel Real: ", _get_real_movement_speed())

func _get_real_movement_speed() -> float:
	var stat_value = clamp(self.speed_stat, 0.0, 100.0)
	var weight = stat_value / 100.0
	return lerp(min_pixels_per_sec, max_pixels_per_sec, weight)
	
func _apply_data_to_visuals():
	if not data: return
	if data.portrait:
		setup_player_visual(data.portrait, player_id)
	else:
		setup_player_visual(sprite.texture if sprite else null, player_id)

func setup_player_visual(texture: Texture2D, id: int):
	if sprite == null: sprite = $Sprite2D
	if label == null: label = $Label
	
	var display_name = player_name
	if display_name == "": display_name = "Prospecto " + str(id + 1)
	
	if sprite and texture:
		sprite.texture = texture
		var original_size = texture.get_size()
		if original_size.x > 0 and original_size.y > 0:
			var max_side = max(original_size.x, original_size.y)
			var scale_factor = target_head_size / max_side
			sprite.scale = Vector2(scale_factor, scale_factor)
			sprite.centered = true
			
	if label:
		label.text = display_name
		var vertical_offset = (target_head_size / 2.0) + 20
		label.position = Vector2(0, -vertical_offset)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.grow_horizontal = Control.GROW_DIRECTION_BOTH

# ==============================================================================
# LÓGICA DE ANIMACIÓN 
# ==============================================================================
func _update_animation_logic(dir: Vector2):
	if not anim: return
	if dir.length() < 0.1: return
	
	# Lógica para elegir animación según hacia dónde se mueve
	if abs(dir.x) > abs(dir.y):
		if anim.sprite_frames.has_animation("idabel_running_90"):
			anim.play("idabel_running_90")
		if visuals_node:
			visuals_node.scale.x = -1 if dir.x < 0 else 1
	elif dir.y > 0: # Moviéndose hacia abajo (Front)
		if anim.sprite_frames.has_animation("idabel_running_front"):
			anim.play("idabel_running_front")
		if visuals_node: visuals_node.scale.x = 1
	else: # Moviéndose hacia arriba (Back)
		if anim.sprite_frames.has_animation("idabel_running_back"):
			anim.play("idabel_running_back")
		if visuals_node: visuals_node.scale.x = 1

# ==============================================================================
# LÓGICA DE RUTAS
# ==============================================================================
func _process(_delta):
	if is_running and not is_playing and not current_route.is_empty():
		play_route() 
		
	if is_dragging:
		_process_dragging()

func play_route():
	if current_route.is_empty(): return
	
	stop_animation()
	if is_dragging: stop_dragging()
	input_pickable = false 
	is_playing = true
	
	_active_tween = create_tween()
	
	var move_speed_pps = _get_real_movement_speed()
	var center_offset = (visual_panel.size / 2.0) if visual_panel else Vector2.ZERO
	var last_pos = position 
	
	for point in current_route:
		var target_pos = point - center_offset
		var distance = last_pos.distance_to(target_pos)
		var duration = 0.0
		if move_speed_pps > 0:
			duration = distance / move_speed_pps
		
		# Animamos posición
		_active_tween.tween_property(self, "position", target_pos, duration)\
			.set_trans(Tween.TRANS_LINEAR)
		
		_active_tween.parallel().tween_callback(func():
			var dir = last_pos.direction_to(target_pos)
			_update_animation_logic(dir)
		)
		
		last_pos = target_pos

	_active_tween.finished.connect(_on_route_finished)

func _on_route_finished():
	is_playing = false
	is_running = false
	if anim: anim.play("idabel_idle_back") # Regresar a idle al terminar

func stop_animation():
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill() 
	is_playing = false
	is_running = false
	
func reset_to_start():
	stop_animation()
	position = starting_position
	input_pickable = true
	is_playing = false
	modulate.a = 1.0

func save_starting_position():
	starting_position = position

func get_route_anchor() -> Vector2:
	var center_offset = (visual_panel.size / 2.0) if visual_panel else Vector2.ZERO
	return position + center_offset * scale

# ==============================================================================
# INPUT Y ARRASTRE
# ==============================================================================
func _input_event(_viewport, event, _shape_idx):
	if is_playing: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		start_route_requested.emit(self)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		start_dragging()

func _input(event):
	if is_dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		stop_dragging()
		
func start_dragging():
	is_dragging = true
	drag_offset = get_global_mouse_position() - global_position
	modulate.a = 0.7
	scale = Vector2(1.2, 1.2) 
	z_index = 50

func stop_dragging():
	is_dragging = false
	modulate.a = 1.0
	scale = Vector2(1.0, 1.0)
	z_index = 20
	position = position.round()
	save_starting_position() 
	interaction_ended.emit()
	
func _process_dragging():
	var target_pos = get_global_mouse_position() - drag_offset
	if limit_rect.has_area():
		var size_x = visual_panel.size.x if visual_panel else 64.0
		var size_y = visual_panel.size.y if visual_panel else 64.0
		var radius_x = (size_x * scale.x) / 2.0
		var radius_y = (size_y * scale.y) / 2.0
		var min_x = limit_rect.position.x + radius_x
		var max_x = limit_rect.end.x - radius_x
		var min_y = limit_rect.position.y + radius_y
		var max_y = limit_rect.end.y - radius_y
		if min_x > max_x: target_pos.x = limit_rect.get_center().x
		else: target_pos.x = clamp(target_pos.x, min_x, max_x)
		if min_y > max_y: target_pos.y = limit_rect.get_center().y
		else: target_pos.y = clamp(target_pos.y, min_y, max_y)
	global_position = target_pos.round()
	moved.emit(self)
		
func set_role(new_role: String):
	role = new_role
	if label:
		if role == "QB": label.text = "QB"
		elif role == "CENTER": label.text = "C"
		else: label.text = player_name if player_name != "" else str(player_id + 1)
		
func set_selected(value: bool):
	if sprite and sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("is_selected", value)

func move_to_setup(target_pos: Vector2, duration: float = 1.0):
	# 1. Calculamos dirección para la animación
	var direction = global_position.direction_to(target_pos)
	
	# 2. Reproducimos animación de correr según dirección
	_update_animation_logic(direction)
	
	# 3. Creamos el Tween (Movimiento suave)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Mover desde donde estoy hasta el objetivo
	tween.tween_property(self, "global_position", target_pos, duration)
	
	# 4. Al terminar, volver a Idle
	tween.tween_callback(func():
		if anim: anim.play("idabel_idle_back")
		if visuals_node: visuals_node.scale.x = 1 
)
