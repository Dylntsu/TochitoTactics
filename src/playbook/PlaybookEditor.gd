extends Node2D

# ==============================================================================
# COMPONENTES
# ==============================================================================
@onready var route_manager = $RouteManager
@onready var nodes_container = $NodesContainer
@onready var background = $CanvasLayer/Background 

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
	
	route_manager.setup(grid_points, spacing)

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
	var limit_top_y = get_offensive_zone_limit_y()
	var limit_bottom_y = field_rect.position.y + field_rect.size.y + (spacing * 2)
	var limit_rect = Rect2(field_rect.position.x, limit_top_y, field_rect.size.x, limit_bottom_y - limit_top_y)

	var formation_start_x = field_rect.position.x + (field_rect.size.x * formation_margin_left)
	var formation_end_x = field_rect.position.x + field_rect.size.x * (1.0 - formation_margin_right)
	var total_width = formation_end_x - formation_start_x
	var formation_y = (field_rect.position.y + field_rect.size.y) - (field_rect.size.y * formation_bottom_margin)
	
	var player_step = 0
	if player_count > 1: player_step = total_width / (player_count - 1)
	var qb_index = int(player_count / 2)
	
	for i in range(player_count):
		var player = player_scene.instantiate()
		player.player_id = i
		player.name = "PlayerStart_" + str(i)
		player.limit_rect = limit_rect
		
		var pos_x = 0
		if player_count > 1: pos_x = formation_start_x + (i * player_step)
		else: pos_x = field_rect.position.x + field_rect.size.x / 2
		
		var pos_y = formation_y
		if i == qb_index: pos_y += spacing * 0.8
		
		player.position = Vector2(pos_x, pos_y)
		
		# --- CONEXIONES ---
		player.start_route_requested.connect(_on_player_start_route_requested)
		player.moved.connect(_on_player_moved) # Conectamos la señal de movimiento
		
		nodes_container.add_child(player)

func get_offensive_zone_limit_y() -> float:
	if grid_points.is_empty(): return 0.0
	var limit_index = int(grid_size.y - 3) 
	if limit_index < 0: limit_index = 0
	return grid_points[limit_index].y

# ==============================================================================
# INPUT (Delegado al RouteManager)
# ==============================================================================
func _input(event):
	var mouse_pos = get_local_mouse_position()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		route_manager.handle_input(mouse_pos)
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		route_manager.finish_route()
		
	elif event is InputEventMouseMotion:
		route_manager.update_preview(mouse_pos)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			route_manager.handle_input(mouse_pos)

# --- CALLBACKS DE JUGADORES (CORREGIDOS) ---

# 1. Cuando el jugador pide iniciar ruta:
func _on_player_start_route_requested(player_node):
	# Delegamos al manager. Le pasamos el ID y el CENTRO (anchor) del jugador.
	route_manager.try_start_route(player_node.player_id, player_node.get_route_anchor())

# 2. Cuando el jugador se mueve:
func _on_player_moved(player_node):
	# Avisamos al manager para que actualice el origen de la línea.
	route_manager.update_route_origin(player_node.player_id, player_node.get_route_anchor())
