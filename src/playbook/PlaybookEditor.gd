extends Node2D

# ==============================================================================
# COMPONENTES
# ==============================================================================
@onready var route_manager = $RouteManager
@onready var nodes_container = $NodesContainer
@onready var background = $CanvasLayer/Background 


# ==============================================================================
# VARIABLES PARA EL INSPECTOR
# ==============================================================================

@export_group("Posicionamiento de Jugadores")
## Qué tan cerca del borde inferior aparecen los jugadores (multiplicador de spacing)
@export_range(0.5, 4.0) var spawn_vertical_offset: float = 1.5
## Qué tanto se adelanta el QB respecto a la línea (multiplicador de spacing)
@export_range(0.0, 2.0) var qb_advance_offset: float = 0.5

@export_group("Límites de Jugada")
## Fila de la grilla donde empieza la zona de anotación/límite superior
@export var offensive_limit_row_offset: int = 4
# ==============================================================================
# CONFIGURACIÓN
# ==============================================================================
@export_group("Assets")
@export var player_scene: PackedScene = preload("res://src/playbook/player/Player.tscn")

@export_group("Grid Configuration")
@export var grid_size: Vector2 = Vector2(5, 8) 
@export var snap_distance: float = 40.0 

@export_group("Grid Precision Margins")
@export_range(0.0, 0.8) var grid_margin_top: float = 0.5    
@export_range(0.0, 0.5) var grid_margin_bottom: float = 0.02 
@export_range(0.0, 0.5) var grid_margin_left: float = 0.418   
@export_range(0.0, 0.5) var grid_margin_right: float = 0.417  

@export_group("Formation Configuration")
@export_range(0.0, 0.5) var formation_margin_left: float = 0.30
@export_range(0.0, 0.5) var formation_margin_right: float = 0.30
@export_range(0.0, 0.5) var formation_bottom_margin: float = 0.099
@export var player_count: int = 5 

# Estado Local (Solo visuales estáticos)
var grid_points: Array[Vector2] = []
var spacing: int = 0

# ==============================================================================
# CICLO DE VIDA
# ==============================================================================
func _ready():
	get_viewport().size_changed.connect(_on_viewport_resized)
	await get_tree().process_frame
	rebuild_editor()

func _on_viewport_resized():
	rebuild_editor()

func rebuild_editor():
	var bounds = calculate_grid_bounds()
	var grid_data = GridService.calculate_grid(bounds, grid_size)
	
	grid_points = grid_data.points
	spacing = grid_data.spacing
	
	render_grid_visuals()
	render_formation() 
	
	# Usamos 'background.get_global_rect()' para los límites totales de la cancha
	route_manager.setup(grid_points, spacing, background.get_global_rect())

# ==============================================================================
# RENDERIZADO (VISUALS)
# ==============================================================================
func calculate_grid_bounds() -> Rect2:
	var field_rect = background.get_global_rect()
	var x = field_rect.position.x + (field_rect.size.x * grid_margin_left)
	var y = field_rect.position.y + (field_rect.size.y * grid_margin_top)
	var width = field_rect.size.x * (1.0 - grid_margin_left - grid_margin_right)
	var height = field_rect.size.y * (1.0 - grid_margin_top - grid_margin_bottom)
	return Rect2(x, y, width, height)

func render_grid_visuals():
	for child in nodes_container.get_children():
		if not child.name.begins_with("PlayerStart"):
			child.queue_free()
			
	var marker_size = clamp(spacing * 0.12, 4, 12)
	for pos in grid_points:
		var marker = ColorRect.new()
		marker.size = Vector2(marker_size, marker_size)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.color = Color(1, 1, 1, 0.5)
		marker.position = pos - (marker.size / 2)
		nodes_container.add_child(marker)

func render_formation():
	for child in nodes_container.get_children():
		if child.name.begins_with("PlayerStart"):
			child.queue_free()

	var field_rect = background.get_global_rect()
	
	# 1. Definimos el ANCHO correcto (restando márgenes laterales)
	# Usamos las mismas variables que ya tenías para la formación
	var formation_start_x = field_rect.position.x + (field_rect.size.x * formation_margin_left)
	var formation_end_x = field_rect.position.x + field_rect.size.x * (1.0 - formation_margin_right)
	var formation_width = formation_end_x - formation_start_x
	
	# 2. Definimos el ALTO correcto
	var limit_top_y = get_offensive_zone_limit_y()
	var limit_bottom_y = field_rect.end.y - (spacing * 0.25)
	
	# 3. CREAMOS EL LÍMITE CORRECTO (Jaula ajustada)
	var limit_rect = Rect2(
		formation_start_x,      # Empezar donde empieza el margen izquierdo
		limit_top_y, 
		formation_width,        # Ancho restringido por los márgenes
		limit_bottom_y - limit_top_y
	)

	# 1. Definimos el centro horizontal y vertical de la "jaula" para seguridad
	var cage_center_y = limit_rect.position.y + (limit_rect.size.y / 2.0)
	
	# 2. Ajustamos la formación para que use el limit_rect como referencia
	# En lugar de usar el field_rect total, usamos el límite inferior de la jaula
	var formation_y = limit_rect.end.y - (spacing * 1.5) 
	
	var player_step = 0
	if player_count > 1: 
		player_step = formation_width / (player_count - 1)
	
	var qb_index = int(player_count / 2)
	
	for i in range(player_count):
		var player = player_scene.instantiate()
		player.player_id = i
		player.limit_rect = limit_rect 
		
		# Cálculo de X 
		var pos_x = formation_start_x + (i * player_step) if player_count > 1 else limit_rect.get_center().x
		
		# Calculamos la posición Y y nos aseguramos de que esté dentro de la jaula
		var final_y = formation_y
		
		# Si es el QB (el del centro), lo adelantamos un poco pero siempre dentro de la zona
		if i == qb_index:
			final_y -= spacing * 0.5 # Lo "subimos" un poco en la pantalla
			
		# Aplicamos un clamp final de seguridad para que el spawn sea garantizado
		# Restamos un pequeño margen para que el cuerpo del jugador no toque el borde
		var margin = spacing * 0.5
		final_y = clamp(final_y, limit_rect.position.y + margin, limit_rect.end.y - margin)
		
		player.position = Vector2(pos_x, final_y)
		
		# --- CONEXIONES ---
		player.start_route_requested.connect(_on_player_start_route_requested)
		player.moved.connect(_on_player_moved)
		
		nodes_container.add_child(player)

func get_offensive_zone_limit_y() -> float:
	if grid_points.is_empty(): return 0.0
	var limit_index = int(grid_size.y - 4) 
	if limit_index < 0: limit_index = 0
	return grid_points[limit_index].y

# ==============================================================================
# INPUT (Delegado al RouteManager)
# ==============================================================================
# En PlaybookEditor.gd

func _input(event):
	var mouse_pos = get_local_mouse_position()
	
	# 1. LOGICA DE DIBUJO STANDARD (Esto es lo que faltaba)
	if event is InputEventMouseButton:
		# Clic Izquierdo: Agregar nodo
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if route_manager.is_editing:
				route_manager.handle_input(mouse_pos)
			else:
				# Si NO estamos editando, intentamos agarrar una ruta existente
				_try_click_existing_route_end(mouse_pos)
		
		# Clic Derecho: Terminar ruta
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			route_manager.finish_route()
			
	elif event is InputEventMouseMotion:
		# Movimiento: Actualizar preview
		route_manager.update_preview(mouse_pos)
		#dibujo sosteniendo
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and route_manager.is_editing:
			route_manager.handle_input(mouse_pos)

# Función auxiliar para detectar clics en las puntas de las rutas
func _try_click_existing_route_end(mouse_pos: Vector2):
	var snap_range = route_manager._snap_distance # Usamos la misma distancia de imán
	
	for pid in route_manager.active_routes:
		var line = route_manager.active_routes[pid]
		if line.get_point_count() > 0:
			var end_point = line.points[line.get_point_count() - 1]
			
			# Si hicimos clic cerca del final de esta ruta
			if mouse_pos.distance_to(end_point) < snap_range:
				route_manager.resume_editing_route(pid)
				return # Encontramos una, dejamos de buscar

# --- CALLBACKS DE JUGADORES (CORREGIDOS) ---

# 1. Cuando el jugador pide iniciar ruta:
func _on_player_start_route_requested(player_node):
	var pid = player_node.player_id
	
	# CASO A: El jugador YA TIENE una ruta
	if route_manager.active_routes.has(pid):
		# En lugar de borrar y salir, le decimos al manager que REANUDE la edición.
		route_manager.resume_editing_route(pid)
		
		return 

	# CASO B: El jugador NO tiene ruta
	# Si estábamos dibujando a otro, guardamos esa primero
	if route_manager.is_editing and route_manager.current_player_id != pid:
		route_manager.finish_route()
	
	# Iniciamos nueva ruta desde cero
	route_manager.try_start_route(pid, player_node.get_route_anchor())

# 2. Cuando el jugador se mueve:
func _on_player_moved(player_node):
	# Avisamos al manager para que actualice el origen de la línea.
	route_manager.update_route_origin(player_node.player_id, player_node.get_route_anchor())
	

## Interface pública para resetear el estado de la jugada actual.
## Sigue el principio de Open/Closed: puede extenderse sin cambiar la llamada original.
func reset_current_play() -> void:
	_clear_routes()
	_restore_initial_formation()

func _clear_routes() -> void:
	if route_manager:
		route_manager.clear_all_routes()

func _restore_initial_formation() -> void:
	# Reusamos la lógica de reconstrucción existente
	rebuild_editor()

## Captura el estado actual de jugadores y rutas (Patrón Memento)
func get_play_snapshot() -> Dictionary:
	var snapshot = {
		"name": "Nueva Jugada", # Podríamos pedir esto con un LineEdit después
		"timestamp": Time.get_unix_time_from_system(),
		"player_positions": {},
		"routes": {}
	}
	
	# Guardar posiciones de los jugadores
	for player in nodes_container.get_children():
		if "player_id" in player:
			snapshot["player_positions"][player.player_id] = player.position
	
	# Guardar los puntos de las rutas
	for pid in route_manager.active_routes:
		var line = route_manager.active_routes[pid]
		snapshot["routes"][pid] = line.points
		
	return snapshot
