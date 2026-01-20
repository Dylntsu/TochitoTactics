extends Node2D
class_name RouteManager

# ==============================================================================
# CONFIGURACIÓN
# ==============================================================================
@export var route_line: Line2D
@export var preview_line: Line2D
@export var max_points: int = 6
@export var bridge_limit_multiplier: float = 3.0
@export var max_total_distance_pixels: float = 800.0
signal route_modified

const PLAYER_COLORS = [
	Color("#2980b9"), Color("#c0392b"), Color("#f39c12"), Color("#8e44ad"), Color("#16a085")
]

# ==============================================================================
# ESTADO
# ==============================================================================
var current_route: Array[Vector2] = []
var active_routes: Dictionary = {} 
var route_distances: Dictionary = {} 
var is_editing: bool = false
var current_player_id: int = -1
var current_dist_accumulator: float = 0.0
var is_locked: bool = false
var limit_rect: Rect2 = Rect2(0, 0, 1920, 1080) 
var margin = 10.0 # Píxeles de separación del borde
var safe_limit: Rect2 # Crea un rectángulo 10px más pequeño hacia adentro

var _grid_points: Array[Vector2]
var _spacing: int
var _snap_distance: float
var _max_step_len: float
var _dash_texture: Texture2D
var _field_bounds: Rect2 = Rect2()

#modo preciso
var is_precision_mode: bool = false
const PRECISION_SNAP_SIZE: float = 10.0 

## Bloquea o desbloquea la capacidad de editar rutas
func set_locked(value: bool):
	is_locked = value
	if is_locked:
		# Si bloqueamos mientras se editaba, cancelamos inmediatamente
		cancel_editing()
		
func set_field_limits(rect: Rect2):
	limit_rect = rect
	safe_limit = limit_rect.grow(-margin)
	
func get_snapped_position(pos: Vector2) -> Vector2:
	# --- MODO PRECISO  ---
	if is_precision_mode:
		var x = round(pos.x / PRECISION_SNAP_SIZE) * PRECISION_SNAP_SIZE
		var y = round(pos.y / PRECISION_SNAP_SIZE) * PRECISION_SNAP_SIZE
		return Vector2(x, y)

	# --- MODO SIMPLE ---
	# Solo permite seleccionar los nodos grandes predefinidos
	var closest_point = pos
	var min_dist = INF
	
	if _grid_points.size() > 0:
		for point in _grid_points:
			var dist = pos.distance_to(point)
			if dist < min_dist:
				min_dist = dist
				closest_point = point
		
		#Si estás en modo simple, siempre te atrae al nodo grande
		# a menos que se este fuera de rango de edición
		if min_dist < _snap_distance * 1.5: 
			return closest_point
			
	return pos # Fallback

func set_precision_mode(enabled: bool):
	is_precision_mode = enabled
	print("RouteManager: Modo Precisión recibido = ", enabled) 
	
func setup(grid_points: Array[Vector2], spacing: int, field_bounds: Rect2):
	_grid_points = grid_points
	_spacing = spacing
	_snap_distance = spacing * 0.55
	_max_step_len = spacing * 1.55
	_field_bounds = field_bounds
	_dash_texture = _generate_dash_texture()

# --- ANCLAJE DE RUTA ---
func update_route_origin(player_id: int, new_origin: Vector2, force: bool = false):
	if is_locked and not force: return
	
	if active_routes.has(player_id):
		var line = active_routes[player_id]
		var point_count = line.get_point_count()
		
		if point_count > 1:
			var old_origin = line.get_point_position(0)
			var first_target = line.get_point_position(1)
			
			var old_dist = old_origin.distance_to(first_target)
			var new_dist = new_origin.distance_to(first_target)
			var diff = new_dist - old_dist
			
			var last_idx = point_count - 1
			var prev_idx = point_count - 2
			var last_p = line.get_point_position(last_idx)
			var prev_p = line.get_point_position(prev_idx)
			
			var direction = (last_p - prev_p).normalized()
			var target_last_p = last_p - (direction * diff)
			
			# Si el movimiento hacia atrás colapsa el segmento, borramos el punto (Backtracking)
			if prev_p.distance_to(target_last_p) < 5.0 and point_count > 2:
				line.remove_point(last_idx)
				update_route_origin(player_id, new_origin, force)
				return

			# Clamping con CaptureFrame
			if limit_rect.has_area():
				var padding = 20.0 
				var local_min = line.to_local(limit_rect.position)
				var local_max = line.to_local(limit_rect.end)
				
				var min_x = min(local_min.x, local_max.x) + padding
				var max_x = max(local_min.x, local_max.x) - padding
				var min_y = min(local_min.y, local_max.y) + padding
				var max_y = max(local_min.y, local_max.y) - padding
				
				target_last_p.x = clamp(target_last_p.x, min_x, max_x)
				target_last_p.y = clamp(target_last_p.y, min_y, max_y)
			
			line.set_point_position(last_idx, target_last_p)
			if route_distances.has(player_id):
				route_distances[player_id] += diff
			
			line.set_point_position(0, new_origin)

func handle_input(mouse_pos: Vector2):
	if is_locked or not is_editing: return
	
	if _field_bounds.has_area() and not _field_bounds.has_point(to_global(mouse_pos)):
		return

	var target_pos = get_snapped_position(mouse_pos)
	
	# Validación de límites
	if _field_bounds.has_area() and not _field_bounds.has_point(to_global(target_pos)):
		return

	# Lógica Deshacer
	if current_route.has(target_pos):
		var idx = current_route.find(target_pos)
		_recalculate_current_distance(idx)
		current_route = current_route.slice(0, idx + 1)
		update_visuals()
		return

	var last_node = current_route.back()
	var step_dist = last_node.distance_to(target_pos)

	# ======================================================================
	# DIFURCACIÓN DE LÓGICA POR MODO
	# ======================================================================
	
	if is_precision_mode:
		# --- LÓGICA MODO PRECISO ---
		# Permite saltos libres, ángulos cualquiera, sin nodos intermedios forzados.
		# Solo se valida la estamina total
		if current_dist_accumulator + step_dist > max_total_distance_pixels: 
			return
			
		current_route.append(target_pos)
		current_dist_accumulator += step_dist
		
	else:
		# --- LÓGICA MODO SIMPLE---
		# Valida saltos máximos entre nodos grandes y genera puntos intermedios.
		
		# 1. Validación de salto (No puedes saltarte 3 nodos de golpe)
		if step_dist > _spacing * bridge_limit_multiplier: 
			return
			
		# 2. Generación de puntos intermedios (si pasaste por encima de uno sin hacer click)
		var points_to_add = _get_intermediate_points(last_node, target_pos)
		var dist_cost = 0.0
		var temp_last = last_node
		for p in points_to_add:
			dist_cost += temp_last.distance_to(p)
			temp_last = p
			
		if current_dist_accumulator + dist_cost > max_total_distance_pixels: 
			return
			
		for p in points_to_add:
			if not current_route.has(p):
				current_route.append(p)
				current_dist_accumulator += last_node.distance_to(p)
				last_node = p

	# ======================================================================
	
	update_visuals()


func update_preview(mouse_pos: Vector2):
	if is_locked or not is_editing or current_route.is_empty():
		preview_line.points = []
		return
		
	if _field_bounds.has_area() and not _field_bounds.has_point(mouse_pos):
		preview_line.points = []
		return

	var last = current_route.back()
	var target = get_snapped_position(mouse_pos)
	# Coloreado de advertencia
	var color = Color(1, 1, 1, 0.5)
	# En modo normal, avisamos si el salto es muy largo
	if not is_precision_mode and last.distance_to(target) > _max_step_len:
		color = Color(1, 0, 0, 0.2)
	# Avisamos si nos quedamos sin estamina (distancia total)
	elif current_dist_accumulator + last.distance_to(target) > max_total_distance_pixels: 
		color = Color(1, 0.5, 0, 0.8)
	
	preview_line.points = [last, target]
	preview_line.default_color = color

func finish_route():
	if current_route.size() >= 2:
		var new_line = Line2D.new()
		new_line.points = current_route
		new_line.width = 4.0 # Aseguramos un ancho visible
		
		# 2. Esquinas redondeadas
		new_line.joint_mode = Line2D.LINE_JOINT_ROUND
		new_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		new_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		
		# 3. Color
		var color_idx = current_player_id % PLAYER_COLORS.size()
		new_line.default_color = PLAYER_COLORS[color_idx]
		new_line.default_color.a = 1.0 # Opacidad total
		
		# 5. Orden de dibujado
		new_line.z_as_relative = false 
		new_line.z_index = 5 + current_player_id # Para que se dibuje sobre el pasto
		new_line.visible = true
		
		add_child(new_line) 
		active_routes[current_player_id] = new_line
		route_distances[current_player_id] = current_dist_accumulator
		
	route_modified.emit()
	cancel_editing()

func cancel_editing():
	is_editing = false
	current_route.clear()
	current_dist_accumulator = 0.0
	route_line.points = []
	preview_line.points = []
	current_player_id = -1

func update_visuals():
	route_line.points = current_route
	var ratio = current_dist_accumulator / max_total_distance_pixels
	if ratio < 0.5: route_line.default_color = Color.GREEN
	elif ratio < 0.85: route_line.default_color = Color.YELLOW
	else: route_line.default_color = Color(1, 0.5, 0)

func resume_editing_route(player_id: int):
	# Si está bloqueado, no permitimos retomar edición
	if is_locked or not active_routes.has(player_id): return
	
	var existing_line = active_routes[player_id]
	current_route = [] 
	current_route.append_array(existing_line.points)
	current_player_id = player_id
	is_editing = true
	current_dist_accumulator = _calculate_path_distance(current_route)
	existing_line.queue_free()
	active_routes.erase(player_id)
	update_visuals()

# --- HELPERS ---
func _recalculate_current_distance(up_to_index: int):
	current_dist_accumulator = 0.0
	for i in range(up_to_index):
		if i + 1 < current_route.size():
			current_dist_accumulator += current_route[i].distance_to(current_route[i+1])

func _get_closest_node(pos: Vector2) -> Vector2:
	var closest = Vector2.INF
	var min_dist = _snap_distance * 1.5
	for p in _grid_points:
		var d = pos.distance_to(p)
		if d < min_dist: min_dist = d; closest = p
	return closest

func _calculate_path_distance(points: Array) -> float:
	var d = 0.0
	for i in range(points.size() - 1): d += points[i].distance_to(points[i+1])
	return d

func _get_intermediate_points(from: Vector2, to: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var total_dist = from.distance_to(to)
	if total_dist <= _max_step_len: return [to]
	
	var safe_spacing = max(1, _spacing)
	var steps = int(floor(total_dist / safe_spacing))
	var current_check = from
	
	for i in range(1, steps + 2): 
		var target_pos = from + ((to - from).normalized() * (safe_spacing * i))
		var candidate = _get_closest_node(target_pos)
		if candidate == to: result.append(to); break
		if candidate != from and not result.has(candidate) and candidate != Vector2.INF:
			if candidate.distance_to(to) < current_check.distance_to(to):
				result.append(candidate); current_check = candidate
	if result.is_empty(): result.append(to)
	return result

func _generate_dash_texture() -> GradientTexture2D:
	var grad = Gradient.new()
	grad.set_color(0, Color.WHITE); grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.5, Color.WHITE); grad.add_point(0.501, Color(1, 1, 1, 0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.width = 32; tex.height = 4
	return tex

func clear_all_routes() -> void:
	_abort_active_editing()
	_destroy_visual_lines()
	_clear_internal_data()

func _abort_active_editing() -> void:
	if is_editing:
		cancel_editing()

func _destroy_visual_lines() -> void:
	for child in get_children():
		if _is_removable_line(child):
			child.queue_free()

func _is_removable_line(node: Node) -> bool:
	return node is Line2D and node != route_line and node != preview_line

func _clear_internal_data() -> void:
	active_routes.clear()
	route_distances.clear()
	
func clear_for_load() -> void:
	clear_all_routes()

func load_routes_from_data(routes_data: Dictionary) -> void:
	for player_id in routes_data:
		var points = routes_data[player_id]
		if points.size() < 2: 
			continue
			
		_reconstruct_saved_route(player_id, points)

func _reconstruct_saved_route(id: int, points: Array) -> void:
	current_player_id = id
	current_route = []
	current_route.append_array(points)
	current_dist_accumulator = _calculate_path_distance(current_route)
	finish_route()

func get_all_routes() -> Dictionary:
	var routes_dict = {}
	for p_id in active_routes.keys():
		routes_dict[p_id] = active_routes[p_id].get_points() 
	return routes_dict

func try_start_route(player_id: int, start_pos: Vector2) -> bool:
	#  Verificación de bloqueo global
	if is_locked: 
		return false 

	# Si el jugador ya tiene una ruta, la borramos para iniciar una nueva
	if active_routes.has(player_id):
		var old_line = active_routes[player_id]
		if is_instance_valid(old_line): 
			old_line.queue_free()
		active_routes.erase(player_id)
		route_distances.erase(player_id)
		
		# Si estábamos justo editando esta ruta, cancelamos el estado actual
		if is_editing and current_player_id == player_id: 
			cancel_editing()
		return false 

	# Si estábamos editando a OTRO jugador guardamos su ruta antes de empezar la nueva
	if is_editing and current_player_id != player_id: 
		finish_route()
	
	# Inicializamos el estado de edición para el nuevo jugador
	is_editing = true
	current_player_id = player_id
	current_route = [start_pos]
	current_dist_accumulator = 0.0
	
	# se actualizan los visuales
	update_visuals()
	return true
	
func create_fixed_route(player_id: int, points: PackedVector2Array, color: Color):
	var line: Line2D
	if active_routes.has(player_id):
		line = active_routes[player_id]
	else:
		line = Line2D.new()
		line.width = 4.0
		line.default_color = color
		line.texture_mode = Line2D.LINE_TEXTURE_TILE
		# Hacerla punteada si tienes el asset, si no, déjala sólida
		add_child(line)
		active_routes[player_id] = line
	
	line.points = points
