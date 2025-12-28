extends Node2D

@export_group("Grid Configuration")
@export var grid_size: Vector2 = Vector2(5, 11)
@export var max_points: int = 6
@export var snap_distance: float = 40.0 # Se recalcula dinámicamente

@export_group("Playable Bounds (Percentages)")
@export_range(0.0, 0.3) var top_margin_percent: float = 0.145
@export_range(0.0, 0.3) var bottom_margin_percent: float = 0.145
@export_range(0.0, 0.2) var side_margin_percent: float = 0.03

var grid_points: Array[Vector2] = []
var node_visuals: Dictionary = {} 
var current_route: Array[Vector2] = []
var spacing: int = 0
var is_editing: bool = false 

@onready var route_line = $RouteLine
@onready var preview_line = $PreviewLine
@onready var nodes_container = $NodesContainer


func _ready():
	# Patrón Observer:  cambios de resolución
	get_viewport().size_changed.connect(_on_viewport_resized)
	
	_reset_ui_positions()
	rebuild_editor()

func _on_viewport_resized():
	rebuild_editor()

func _reset_ui_positions():
	nodes_container.position = Vector2.ZERO
	route_line.position = Vector2.ZERO
	preview_line.position = Vector2.ZERO


func rebuild_editor():
	# Limpiar estado anterior
	clear_current_state()
	
	var bounds = calculate_playable_bounds()
	var grid_data = calculate_grid_positions(bounds)
	
	# Actualizar estado interno
	grid_points = grid_data.points
	spacing = grid_data.spacing
	snap_distance = spacing * 0.55 # Ajuste del imán
	
	render_grid_visuals()

func calculate_playable_bounds() -> Rect2:
	var screen_size = get_viewport_rect().size
	
	var top = screen_size.y * top_margin_percent
	var bottom = screen_size.y * (1.0 - bottom_margin_percent)
	var left = screen_size.x * side_margin_percent
	var right = screen_size.x * (1.0 - side_margin_percent)
	
	return Rect2(left, top, right - left, bottom - top)

func calculate_grid_positions(bounds: Rect2) -> Dictionary:
	var calculated_points: Array[Vector2] = []
	
	# 1. Calcular el espaciado máximo posible sin salirse de los márgenes
	var spacing_h = bounds.size.x / (grid_size.x - 1)
	var spacing_v = bounds.size.y / (grid_size.y - 1)
	
	# Usamos el menor para mantener la rejilla cuadrada y uniforme
	var final_spacing = int(min(spacing_h, spacing_v))
	
	# 2. Calcular dimensiones reales de la rejilla
	var grid_width = (grid_size.x - 1) * final_spacing
	var grid_height = (grid_size.y - 1) * final_spacing
	
	# 3. Calcular offset para centrar exactamente en el área jugable
	var center_x = bounds.position.x + (bounds.size.x - grid_width) / 2
	var center_y = bounds.position.y + (bounds.size.y - grid_height) / 2
	var start_offset = Vector2(center_x, center_y)
	
	# 4. Generar puntos
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2(x * final_spacing, y * final_spacing) + start_offset
			calculated_points.append(pos)
			
	return { "points": calculated_points, "spacing": final_spacing }


func clear_current_state():
	grid_points.clear()
	node_visuals.clear()
	preview_line.points = []
	for n in nodes_container.get_children():
		n.queue_free()

func render_grid_visuals():
	# Tamaño visual relativo al espaciado para mantener estética
	var marker_size = clamp(spacing * 0.2, 6, 15)
	
	for pos in grid_points:
		var marker = create_marker_node(marker_size)
		# Centramos el pivote visualmente
		marker.position = pos - (marker.size / 2)
		nodes_container.add_child(marker)
		node_visuals[pos] = marker

func create_marker_node(size: float) -> Control:
	# Factory Method: para reemplazar por Sprites en el futuro
	var marker = ColorRect.new()
	marker.size = Vector2(size, size)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.color = Color(1, 1, 1, 0.4) 
	return marker

# ==============================================================================
# 8. INPUT E INTERACCIÓN 
# ==============================================================================
# Dispatcher de eventos de entrada

func _input(event):
	var mouse_pos = get_local_mouse_position()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			interact_with_node_at(mouse_pos)
	
	elif event is InputEventMouseMotion:
		update_preview(mouse_pos)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			interact_with_node_at(mouse_pos)
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		finish_route()

func interact_with_node_at(mouse_pos: Vector2):
	var closest = get_closest_node(mouse_pos)
	if closest == Vector2.INF: return

	# Caso A: Iniciar nueva ruta
	if current_route.is_empty():
		start_new_route(closest)
		return

	# Caso B: Deshacer 
	if current_route.has(closest):
		var index = current_route.find(closest)
		# Cortamos la ruta hasta ese punto
		current_route = current_route.slice(0, index + 1)
		update_visuals()
		animate_node_interaction(closest)
		return

	# Caso C: Avanzar (Smart Step)
	var last_node = current_route.back()
	var step_vector = get_smart_step(last_node, mouse_pos)
	
	if step_vector != Vector2.ZERO:
		var dist_to_mouse = last_node.distance_to(mouse_pos)
		var step_length = step_vector.length()
		# Cuántos pasos caben hasta el mouse 
		var steps_wanted = clampi(int(round(dist_to_mouse / step_length)), 1, 3)
		
		for i in range(1, steps_wanted + 1):
			var next_target = last_node + (step_vector * i)
			var neighbor = get_closest_node(next_target)
			
			if neighbor != Vector2.INF and not current_route.has(neighbor):
				if current_route.size() < max_points:
					current_route.append(neighbor)
					animate_node_interaction(neighbor)
		update_visuals()

# ==============================================================================
# 9. UTILIDADES DE CÁLCULO DE JUEGO
# ==============================================================================

func get_smart_step(from_pos: Vector2, mouse_pos: Vector2) -> Vector2:
	var dir = (mouse_pos - from_pos)
	# Si no se ha alejado lo suficiente (zona muerta), no hacemos nada
	if dir.length() < spacing * 0.5: return Vector2.ZERO
	
	# Detecta las 8 direcciones (Ortogonal y 45°) normalizadas
	var step_direction = Vector2(round(dir.normalized().x), round(dir.normalized().y))
	return step_direction * spacing

func get_closest_node(pos: Vector2) -> Vector2:
	var closest = Vector2.INF
	var min_dist = snap_distance
	for point in grid_points:
		var dist = pos.distance_to(point)
		if dist < min_dist:
			min_dist = dist
			closest = point
	return closest

# ==============================================================================
# 10. FEEDBACK VISUAL
# ==============================================================================

func update_visuals():
	route_line.points = current_route
	
	# 1. LÓGICA DE SEMÁFORO
	var connections_count = current_route.size() - 1
	var current_color = Color.GREEN # Color por defecto
	
	if connections_count <= 2:
		current_color = Color.GREEN
	elif connections_count == 3:
		current_color = Color.YELLOW
	else:
		current_color = Color.RED
	
	# 2. APLICAR A LA LÍNEA
	route_line.default_color = current_color

	# 3. APLICAR A LOS NODOS
	for pos in node_visuals:
		var node = node_visuals[pos]
		
		# Verificamos si este nodo es la cabeeza de la ruta
		if not current_route.is_empty() and pos == current_route.back():
			node.color = current_color # se iguala el color
			node.scale = Vector2(1.4, 1.4) # Escalamos para destacar
			node.z_index = 1 # asegura que se dibuje encima de la línea
		else:
			# Nodos inactivos o pasados
			node.color = Color(1, 1, 1, 0.4)
			node.scale = Vector2(1, 1)
			node.z_index = 0

func update_preview(mouse_pos: Vector2):
	if not is_editing or current_route.is_empty():
		preview_line.points = []
		return
		
	var last_node = current_route.back()
	var step_vector = get_smart_step(last_node, mouse_pos)
	
	if step_vector == Vector2.ZERO:
		preview_line.points = []
		return

	# Proyección simple de 1 paso
	var projected_points = [last_node]
	var next_target = last_node + step_vector
	var real_node = get_closest_node(next_target)
	
	if real_node != Vector2.INF and not current_route.has(real_node):
		projected_points.append(real_node)
			
	preview_line.points = projected_points if projected_points.size() > 1 else []
	preview_line.default_color = Color(1, 1, 1, 0.3)

func animate_node_interaction(node_pos: Vector2):
	if node_visuals.has(node_pos):
		var tween = create_tween()
		tween.tween_property(node_visuals[node_pos], "scale", Vector2(1.8, 1.8), 0.1)
		tween.tween_property(node_visuals[node_pos], "scale", Vector2(1.0, 1.0), 0.1)

# ==============================================================================
# 11. GESTIÓN DE RUTAS
# ==============================================================================

func start_new_route(start_pos: Vector2):
	is_editing = true
	current_route = [start_pos]
	update_visuals()
	animate_node_interaction(start_pos)

func finish_route():
	if current_route.size() >= 2:
		bake_route_visuals()
		# futura routed_created
	
	is_editing = false
	current_route.clear()
	route_line.points = []
	preview_line.points = []
	update_visuals()

func bake_route_visuals():
	var permanent_line = Line2D.new()
	permanent_line.width = 4.0
	permanent_line.default_color = route_line.default_color
	permanent_line.points = current_route.duplicate()
	permanent_line.joint_mode = Line2D.LINE_JOINT_ROUND
	permanent_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	
	# Añadimos la línea permanente detrás de la ruta activa pero sobre el fondo
	add_child(permanent_line)
	move_child(permanent_line, 0)
