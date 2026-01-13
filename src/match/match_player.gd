extends Node2D

@export var player_scene: PackedScene 

# Usamos el nombre único que ya configuraste
@onready var container = %NodesContainer

# --- LÓGICA DE POSICIONAMIENTO PRECISO ---
# Ajusta este valor a la coordenada Y exacta del borde superior de tu zona verde oscura
var scrimmage_line_y: float = 305.0
var pixels_per_yard: float = 15.0 

func _ready():
	# Esperamos un frame para que la UI y el campo estén listos
	await get_tree().process_frame
	test_spawn()

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
	
	# Aseguramos que inicie su animación de idle/espera
	if new_player.has_node("Visuals/AnimatedSprite2D"):
		new_player.get_node("Visuals/AnimatedSprite2D").play("idabel_running_front")
		new_player.get_node("Visuals/AnimatedSprite2D").stop() # Se queda en el frame 0

	print("Idabel posicionada en Línea de Scrimmage: ", new_player.global_position)

	# Ruta de prueba (ahora relativa a su posición actual)
	var start_pos = new_player.global_position
	var test_route = [
		Vector2(start_pos.x, start_pos.y - 200), # Sube 200 píxeles
		Vector2(start_pos.x + 300, start_pos.y - 200) # Dobla a la derecha 300 píxeles
	]
	new_player.active_route = test_route

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
