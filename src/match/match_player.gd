extends Node2D

@export var player_scene: PackedScene 
@onready var container = %NodesContainer

# --- LÓGICA DE POSICIONAMIENTO PRECISO ---
# Ajusta este valor a la coordenada Y exacta del borde superior de tu zona verde oscura
var scrimmage_line_y: float = 368.0
var pixels_per_yard: float = 15.0 


func _ready():
	test_spawn()
	# 2. Iniciamos la cuenta atrás de 5 segundos
	print("Preparando jugada... inicia en 5 segundos")
	start_auto_play_countdown()
	
func start_auto_play_countdown():
	# Creamos un temporizador de 5 segundos
	await get_tree().create_timer(5.0).timeout
	
	# Cuando el tiempo termina, lanzamos la jugada
	launch_play()

func launch_play():
	print("¡TIEMPO FUERA! La jugada inicia")
	for player in container.get_children():
		if "is_running" in player:
			player.is_running = true

func test_spawn():
	if player_scene == null:
		print("Error: No has asignado la escena del jugador en el Inspector")
		return
		
	var new_player = player_scene.instantiate()
	container.add_child(new_player)
	
	# POSICIONAMIENTO
	
	new_player.global_position.x = get_viewport_rect().size.x / 2
	new_player.global_position.y = scrimmage_line_y
	
	new_player.scale = Vector2(1, 1)
	
	# ANIMACIÓN INICIAL
	if new_player.has_node("Visuals/AnimatedSprite2D"):
		var anim = new_player.get_node("Visuals/AnimatedSprite2D")
		anim.play("idabel_idle_back")

	print("Idabel lista en posición inicial: ", new_player.global_position)

	# RUTA DE PRUEBA RELATIVA
	# La trayectoria se moverá automáticamente si cambias la línea de inicio
	var start_pos = new_player.global_position
	#trayectoria en forma de L
	var test_route = [
		Vector2(start_pos.x, start_pos.y - 300),     
		Vector2(start_pos.x + 200, start_pos.y - 300) 
	]
	new_player.active_route = test_route
	
	# Lanzamos la cuenta atrás apenas el jugador aparece
	start_auto_play_countdown()

func _on_play_button_pressed():
	print("¡Inicia la jugada!")
	for player in container.get_children():
		# Verificamos que sea un jugador y activamos su carrera
		if "is_running" in player:
			player.is_running = true
			if player.has_node("Visuals/AnimatedSprite2D"):
				player.get_node("Visuals/AnimatedSprite2D").play("idabel_running_front")

func update_scrimmage_from_tackle(tackle_y_position: float):
	scrimmage_line_y = tackle_y_position
	print("Nueva línea de inicio marcada en Y: ", scrimmage_line_y)
