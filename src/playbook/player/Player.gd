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

# Getters para mantener compatibilidad
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

var current_route: PackedVector2Array = []
var starting_position: Vector2 
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var limit_rect: Rect2 = Rect2()
var _active_tween: Tween
var is_playing: bool = false
var role: String = "WR" 
@onready var visual_panel = get_node_or_null("Panel")

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
# LÓGICA DE ANIMACIÓN Y RUTAS
# ==============================================================================
func play_route():
	if current_route.is_empty(): return
	stop_animation()
	if is_dragging: stop_dragging()
	input_pickable = false 
	is_playing = true
	_active_tween = create_tween()
	var duration_per_point = 0.2
	for point in current_route:
		var center_offset = (visual_panel.size / 2.0) if visual_panel else Vector2.ZERO
		var target_pos = point - center_offset
		_active_tween.tween_property(self, "position", target_pos, duration_per_point)\
			.set_trans(Tween.TRANS_LINEAR)
	_active_tween.finished.connect(func(): is_playing = false)

func stop_animation():
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill() 
	is_playing = false
	
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
	
	# Click Izquierdo: Pedir ruta
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		start_route_requested.emit(self)
	
	# Click Derecho: Iniciar arrastre (El editor también detecta esto para mostrar stats)
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
	
func _process(_delta):
	# Solo procesamos movimiento si estamos arrastrando
	if is_dragging:
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
