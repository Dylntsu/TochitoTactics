extends Area2D

# Señales
signal start_route_requested(player_node)
signal moved(player_node) 

@export var player_id: int = 0

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var limit_rect: Rect2 = Rect2() 

@onready var visual_panel = $Panel

func _ready():
	if visual_panel:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.0, 0.4, 0.8, 1.0) 
		style.set_corner_radius_all(20)
		style.anti_aliasing = true
		visual_panel.add_theme_stylebox_override("panel", style)

func _process(_delta):
	if is_dragging:
		var target_pos = get_global_mouse_position() - drag_offset
		
		# --- LÓGICA DE LÍMITES (JAULA PERFECTA) ---
		if limit_rect.has_area():
			var size_x = 64.0
			var size_y = 64.0
			if visual_panel and visual_panel.size.x > 0:
				size_x = visual_panel.size.x
				size_y = visual_panel.size.y
				
			var radius_x = (size_x * scale.x) / 2.0
			var radius_y = (size_y * scale.y) / 2.0
			
			var min_x = limit_rect.position.x + radius_x
			var max_x = limit_rect.end.x - radius_x
			var min_y = limit_rect.position.y + radius_y
			var max_y = limit_rect.end.y - radius_y
			
			# Seguridad anti-bloqueo
			if min_x > max_x: target_pos.x = limit_rect.get_center().x
			else: target_pos.x = clamp(target_pos.x, min_x, max_x)
				
			if min_y > max_y: target_pos.y = limit_rect.get_center().y
			else: target_pos.y = clamp(target_pos.y, min_y, max_y)
		
		global_position = target_pos
		moved.emit(self) 

func get_route_anchor() -> Vector2:
	return position + (visual_panel.size / 2.0) * scale

func _input_event(_viewport, event, _shape_idx):
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
