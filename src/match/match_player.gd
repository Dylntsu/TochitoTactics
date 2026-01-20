extends Node2D

@export var player_scene: PackedScene 
@export var ball_scene: PackedScene
@onready var container = %NodesContainer
@onready var match_ui = $MatchUI 

var scrimmage_line_y: float = 368.0
var team_colors = [Color(1,1,1), Color(1,0.5,0.5), Color(0.5,1,0.5), Color(0.5,0.5,1), Color(1,0.8,0.4)]
# Referencias directas para lógica de juego
var ball_instance: Ball = null
var center_player = null
var qb_player = null

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
	
	# IMPORTANTE: Asegúrate que este origen coincida con el centro de tu editor
	# Si tu editor es de 1280x720, el centro visual suele ser 640, 360 (o donde esté tu frame)
	var editor_origin = Vector2(640.0, 360.0) 

	var formations = play_data.get("formations", {})
	var routes = play_data.get("routes", {})

	var players = container.get_children()
	
	for i in range(players.size()):
		var p = players[i]
		var pid = i 
		
		# 1. Actualizar posición si existe en la jugada
		if formations.has(pid):
			var data_entry = formations[pid]
			var target_pos = Vector2.ZERO
			
			# --- CORRECCIÓN AQUÍ ---
			# Verificamos si es el Diccionario nuevo o un Vector2 antiguo
			if data_entry is Dictionary and data_entry.has("position"):
				target_pos = data_entry["position"]
			elif data_entry is Vector2:
				target_pos = data_entry
			
			# Ahora sí, Vector2 - Vector2 es una operación válida
			var offset = target_pos - editor_origin
			p.global_position = match_origin + offset
		
		# 2. Actualizar ruta (Esto se mantiene igual porque las rutas son Arrays de Vectors)
		if routes.has(pid):
			var global_route = []
			for point in routes[pid]:
				var route_offset = point - editor_origin
				global_route.append(match_origin + route_offset)
			p.active_route = global_route
		else:
			p.active_route = []
			
	# Al terminar de cargar posiciones, hacemos el spawn de la pelota y asignación de roles
	_assign_roles_logic()
	_spawn_ball()
	
func _assign_roles_logic():
	# Lógica simple: El jugador más cercano al centro del campo (X) y a la línea (Y) es el Centro
	# El jugador más cercano al Centro pero "atrás" es el QB
	var players = container.get_children()
	var viewport_center_x = get_viewport_rect().size.x / 2
	
	var closest_dist = 99999.0
	
	# 1. Encontrar al Centro
	for p in players:
		var dist = p.global_position.distance_to(Vector2(viewport_center_x, scrimmage_line_y))
		if dist < closest_dist:
			closest_dist = dist
			center_player = p
			
	# 2. Encontrar al QB (El más cercano al centro, excluyendo al centro mismo)
	closest_dist = 99999.0
	for p in players:
		if p == center_player: continue
		var dist = p.global_position.distance_to(center_player.global_position)
		if dist < closest_dist:
			closest_dist = dist
			qb_player = p

	print("Roles asignados -> Centro: ", center_player.name, " | QB: ", qb_player.name)

func _spawn_ball():
	if ball_instance:
		ball_instance.queue_free()
	
	if ball_scene and center_player:
		ball_instance = ball_scene.instantiate()
		add_child(ball_instance)
		ball_instance.attach_to_player(center_player)

func start_auto_play_countdown():
	if not is_play_ready: return
	print("Snap en 3...")
	await get_tree().create_timer(1.0).timeout
	print("Snap en 2...")
	await get_tree().create_timer(1.0).timeout
	print("Snap en 1...")
	await get_tree().create_timer(1.0).timeout
	
	perform_snap()

func perform_snap():
	if not ball_instance or not qb_player: 
		launch_runners() # Fallback por si algo falla
		return
		
	print("¡SNAP!")
	# El balón viaja del Centro al QB
	ball_instance.snap_to(qb_player.global_position)
	
	# Esperamos a que el balón llegue (calculado o por señal)
	# Por simplicidad, esperamos el tiempo que le toma viajar
	var dist = center_player.global_position.distance_to(qb_player.global_position)
	var travel_time = dist / ball_instance.speed
	
	await get_tree().create_timer(travel_time).timeout
	
	# El QB atrapa el balón
	ball_instance.attach_to_player(qb_player)
	print("QB tiene el balón -> ¡WRs salen!")
	
	# AHORA sí salen los corredores
	launch_runners()

func launch_runners():
	for player in container.get_children():
		# El Centro y el QB usualmente no corren rutas inmediatas en formación básica
		# pero por ahora dejamos que todos corran si tienen ruta
		if "is_running" in player and not player.active_route.is_empty():
			player.is_running = true
