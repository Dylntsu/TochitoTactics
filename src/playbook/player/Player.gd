extends Area2D

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
		if limit_rect.has_area():
			target_pos.x = clamp(target_pos.x, limit_rect.position.x, limit_rect.end.x)
			target_pos.y = clamp(target_pos.y, limit_rect.position.y, limit_rect.end.y)
		
		global_position = target_pos
		moved.emit(self) # Emitimos señal al movernos

# Calcula el centro exacto del jugador 
func get_route_anchor() -> Vector2:
	# se multipica por 'scale' por si el jugador está agrandado
	return position + (visual_panel.size / 2.0) * scale

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			start_route_requested.emit(self)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			start_dragging()

func _input(event):
	if is_dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if not event.pressed:
			stop_dragging()

func start_dragging():
	is_dragging = true
	# Ajustamos el offset para que no salte al centro del mouse al arrastrar
	drag_offset = get_global_mouse_position() - global_position 
	modulate.a = 0.7 
	scale = Vector2(1.2, 1.2)
	z_index = 20 

func stop_dragging():
	is_dragging = false
	modulate.a = 1.0
	scale = Vector2(1.0, 1.0)
	z_index = 10
