extends Node2D
class_name RouteManager

@export var route_line: Line2D
@export var preview_line: Line2D
@export var max_points: int = 6
@export var bridge_limit_multiplier: float = 3.0

var current_route: Array[Vector2] = []
var active_routes: Dictionary = {} 
var is_editing: bool = false
var current_player_id: int = -1

var _grid_points: Array[Vector2]
var _spacing: int
var _snap_distance: float

func setup(grid_points: Array[Vector2], spacing: int):
	_grid_points = grid_points
	_spacing = spacing
	_snap_distance = spacing * 0.55

# --- NUEVA FUNCIÓN: Actualizar origen de ruta ---
func update_route_origin(player_id: int, new_origin: Vector2):
	# Verificamos si este jugador tiene una ruta activa
	if active_routes.has(player_id):
		var line = active_routes[player_id]
		# Actualizamos solo el punto 0 (el inicio)
		if line.get_point_count() > 0:
			line.set_point_position(0, new_origin)

func try_start_route(player_id: int, start_pos: Vector2) -> bool:
	if active_routes.has(player_id):
		var old_line = active_routes[player_id]
		if is_instance_valid(old_line): old_line.queue_free()
		active_routes.erase(player_id)
		if is_editing and current_player_id == player_id:
			cancel_editing()
		return false 

	if is_editing and current_player_id != player_id:
		cancel_editing()
	
	is_editing = true
	current_player_id = player_id
	current_route = [start_pos]
	update_visuals()
	return true

func handle_input(mouse_pos: Vector2):
	if not is_editing: return
	
	var closest = _get_closest_node(mouse_pos)
	if closest == Vector2.INF: return
	
	if current_route.has(closest):
		var idx = current_route.find(closest)
		current_route = current_route.slice(0, idx + 1)
		update_visuals()
		return

	if current_route.size() == 1:
		if current_route[0].distance_to(closest) > _spacing * bridge_limit_multiplier: return
	
	if not current_route.has(closest):
		if current_route.size() < max_points:
			current_route.append(closest)
			update_visuals()

func update_preview(mouse_pos: Vector2):
	if not is_editing or current_route.is_empty():
		preview_line.points = []
		return
	
	var last = current_route.back()
	
	if current_route.size() == 1:
		var closest = _get_closest_node(mouse_pos)
		if closest != Vector2.INF:
			var dist = last.distance_to(closest)
			var color = Color(1, 1, 1, 0.5)
			if dist > _spacing * bridge_limit_multiplier: color = Color(1, 0, 0, 0.5)
			preview_line.points = [last, closest]
			preview_line.default_color = color
		else:
			preview_line.points = [last, mouse_pos]
			preview_line.default_color = Color(1, 1, 1, 0.2)
	else:
		preview_line.points = [last, mouse_pos]
		preview_line.default_color = Color(1, 1, 1, 0.3)

func finish_route():
	if current_route.size() >= 2:
		var new_line = route_line.duplicate()
		new_line.points = current_route
		add_child(new_line) 
		active_routes[current_player_id] = new_line
	
	cancel_editing()

func cancel_editing():
	is_editing = false
	current_route.clear()
	route_line.points = []
	preview_line.points = []
	current_player_id = -1

func update_visuals():
	route_line.points = current_route

func _get_closest_node(pos: Vector2) -> Vector2:
	var closest = Vector2.INF
	var min_dist = _snap_distance * 1.5
	for p in _grid_points:
		var d = pos.distance_to(p)
		if d < min_dist:
			min_dist = d
			closest = p
	return closest
