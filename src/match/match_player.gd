extends Node2D

@export var player_scene: PackedScene 
@onready var container = %NodesContainer
@onready var match_ui = $MatchUI 

# === BASE DE DATOS DEL EQUIPO ===
var team_roster: Array[Resource] = []
const PLAYERS_DIR = "res://data/players/"

# --- AJUSTES DE POSICIONAMIENTO ---
var scrimmage_line_y: float = 368.0
var team_colors = [Color(1,1,1), Color(1,0.5,0.5), Color(0.5,1,0.5), Color(0.5,0.5,1), Color(1,0.8,0.4)]
var is_play_ready: bool = false

func _ready():
	_load_team_roster()
	spawn_default_formation()
	
	if match_ui:
		match_ui.play_selected.connect(_on_play_icon_pressed)

func _load_team_roster():
	team_roster.clear()
	var dir = DirAccess.open(PLAYERS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path = PLAYERS_DIR + file_name
				var res = load(full_path)
				if res and ("Speed" in res or "speed" in res):
					team_roster.append(res)
			file_name = dir.get_next()
		
		team_roster.sort_custom(func(a, b): 
			var name_a = a.get("full_name") if "full_name" in a else a.resource_path
			var name_b = b.get("full_name") if "full_name" in b else b.resource_path
			return name_a < name_b
		)

func spawn_default_formation():
	for child in container.get_children():
		child.queue_free()
	
	var field_center_x = get_viewport_rect().size.x / 2
	var spacing = 80.0 
	
	for i in range(5):
		var new_player = player_scene.instantiate()
		container.add_child(new_player)
		
		# Posición inicial
		var pos_x = field_center_x + (i - 2) * spacing
		new_player.global_position = Vector2(pos_x, scrimmage_line_y)
		
		if "player_id" in new_player: 
			new_player.player_id = i
		
		if new_player.has_node("Visuals"):
			new_player.get_node("Visuals").modulate = team_colors[i % team_colors.size()]
		
		if new_player.has_node("Visuals/AnimatedSprite2D"):
			new_player.get_node("Visuals/AnimatedSprite2D").play("idabel_idle_back")
		
		if team_roster.size() > 0:
			var stats_data = team_roster[i % team_roster.size()]
			if new_player.has_method("setup_stats"):
				new_player.setup_stats(stats_data)
	
	is_play_ready = false

func _on_play_icon_pressed(file_path: String):
	if is_play_ready: return 

	if ResourceLoader.exists(file_path):
		var resource = load(file_path)
		if resource:
			var data = {
				"formations": resource.get("formations"),
				"routes": resource.get("routes")
			}
			# Bloqueamos para que no spameen clicks
			is_play_ready = true 
			load_custom_play(data)

func load_custom_play(play_data: Dictionary):
	var viewport_rect = get_viewport_rect()
	var field_center_x = viewport_rect.size.x / 2
	var match_origin = Vector2(field_center_x, scrimmage_line_y)
	
	# Usamos el origen 550 que te funcionaba bien
	var editor_origin = Vector2(640.0, 550.0) 

	var formations = play_data.get("formations", {})
	var routes = play_data.get("routes", {})
	var players = container.get_children()

	var safe_margin = 30.0
	var safe_bounds = Rect2(
		safe_margin, safe_margin, 
		viewport_rect.size.x - (safe_margin * 2), 
		viewport_rect.size.y - (safe_margin * 2)
	)

	# Tiempo que tardan en caminar (0.8 segundos)
	var walk_duration = 0.8 

	for i in range(players.size()):
		var p = players[i]
		var pid = i 
		
		# --- A. POSICIONAMIENTO ---
		if formations.has(pid):
			var data_entry = formations[pid]
			var saved_pos = Vector2.ZERO
			
			if data_entry is Dictionary and data_entry.has("position"):
				saved_pos = data_entry["position"]
			elif data_entry is Vector2:
				saved_pos = data_entry
			
			var offset = saved_pos - editor_origin
			var final_pos = match_origin + offset
			
			final_pos.x = clamp(final_pos.x, safe_bounds.position.x, safe_bounds.end.x)
			final_pos.y = clamp(final_pos.y, safe_bounds.position.y, safe_bounds.end.y)
			
			# === DEBUGGING INTENSO ===
			if p.has_method("move_to_setup"):
				print("✅ JUGADOR ", i, ": Detecté función caminar. Iniciando Tween...")
				p.move_to_setup(final_pos, walk_duration)
			else:
				print("❌ JUGADOR ", i, ": NO detecté función. TELETRANSPORTANDO.")
				p.global_position = final_pos
		
		# --- B. RUTAS ---
		if routes.has(pid):
			var global_route = []
			for point in routes[pid]:
				var route_offset = point - editor_origin
				global_route.append(match_origin + route_offset)
			p.active_route = global_route
		else:
			p.active_route = []
	
	# Esperamos a que terminen de caminar
	await get_tree().create_timer(walk_duration + 0.2).timeout
	
	# Iniciamos la cuenta regresiva
	start_auto_play_countdown()

func start_auto_play_countdown():
	if not is_play_ready: return
	print("Iniciando en 3...")
	await get_tree().create_timer(1.0).timeout
	if not is_play_ready: return
	print("Iniciando en 2...")
	await get_tree().create_timer(1.0).timeout
	if not is_play_ready: return
	print("Iniciando en 1...")
	await get_tree().create_timer(1.0).timeout
	
	if is_play_ready:
		launch_play()

func launch_play():
	print("¡Acción! (Snap en proceso...)")
	
	# 1. Iniciar rutas de los receptores (WRs) inmediatamente
	for player in container.get_children():
		if player.player_name != "Dani" and "is_running" in player: 
			player.is_running = true
			if player.has_node("Visuals/AnimatedSprite2D"):
				player.get_node("Visuals/AnimatedSprite2D").play("idabel_running_front")

	await get_tree().create_timer(0.5).timeout
	# --------------------------------------------------
	
	# 3. Entregar el balón al QB 
	var qb = _find_player_by_name("Dani") 
	if qb:
		qb.receive_snap()
	else:
		print("Error: No encontré a Dani para el snap.")

# Función auxiliar para encontrar al jugador
func _find_player_by_name(p_name: String):
	for child in container.get_children():
		if "player_name" in child and child.player_name == p_name:
			return child
	return null
