extends Node2D

@export var player_scene: PackedScene 
@onready var container = %NodesContainer
@onready var match_ui = $MatchUI 

var scrimmage_line_y: float = 368.0
var team_colors = [Color(1,1,1), Color(1,0.5,0.5), Color(0.5,1,0.5), Color(0.5,0.5,1), Color(1,0.8,0.4)]

# Variable para saber si ya hay una jugada lista para empezar
var is_play_ready: bool = false

func _ready():
	if match_ui:
		match_ui.play_selected.connect(_on_play_icon_pressed)
	
	# Instanciamos a los 5 jugadores desde el inicio en formación básica
	spawn_default_formation()

func spawn_default_formation():
	# Limpiamos por si acaso
	for child in container.get_children():
		child.queue_free()
	
	var field_center_x = get_viewport_rect().size.x / 2
	var spacing = 80.0 # Espacio entre jugadores
	
	for i in range(5):
		var new_player = player_scene.instantiate()
		container.add_child(new_player)
		
		# Posición inicial por defecto 
		var pos_x = field_center_x + (i - 2) * spacing
		new_player.global_position = Vector2(pos_x, scrimmage_line_y)
		
		# Configuración básica
		if "player_id" in new_player:
			new_player.player_id = i
		if new_player.has_node("Visuals"):
			new_player.get_node("Visuals").modulate = team_colors[i % team_colors.size()]
		if new_player.has_node("Visuals/AnimatedSprite2D"):
			new_player.get_node("Visuals/AnimatedSprite2D").play("idabel_idle_back")
	
	is_play_ready = false # No hay jugada cargada aún

func _on_play_icon_pressed(file_path: String):
	if ResourceLoader.exists(file_path):
		var resource = load(file_path)
		if resource:
			var data = {
				"formations": resource.get("formations"),
				"routes": resource.get("routes")
			}
			load_custom_play(data)
			# Ahora que se cargó una jugada, activamos el inicio
			is_play_ready = true
			start_auto_play_countdown()

func load_custom_play(play_data: Dictionary):
	var field_center_x = get_viewport_rect().size.x / 2
	var match_origin = Vector2(field_center_x, scrimmage_line_y)
	var editor_origin = Vector2(640.0, 550.0)

	var formations = play_data.get("formations", {})
	var routes = play_data.get("routes", {})

	# En lugar de borrar, buscamos a los jugadores que ya existen
	var players = container.get_children()
	
	for i in range(players.size()):
		var p = players[i]
		var pid = i # Usamos el índice como ID
		
		# 1. Actualizar posición si existe en la jugada
		if formations.has(pid):
			var offset = formations[pid] - editor_origin
			p.global_position = match_origin + offset
		
		# 2. Actualizar ruta
		if routes.has(pid):
			var global_route = []
			for point in routes[pid]:
				var route_offset = point - editor_origin
				global_route.append(match_origin + route_offset)
			p.active_route = global_route
		else:
			p.active_route = [] # Limpiar ruta si no tiene

func start_auto_play_countdown():
	# si no hay jugada, salimos
	if not is_play_ready: return
	
	print("Jugada cargada. Iniciando en 5 segundos...")
	await get_tree().create_timer(5.0).timeout
	
	# Verificamos de nuevo antes de lanzar 
	if is_play_ready:
		launch_play()

func launch_play():
	print("¡Acción!")
	for player in container.get_children():
		if "is_running" in player:
			player.is_running = true
