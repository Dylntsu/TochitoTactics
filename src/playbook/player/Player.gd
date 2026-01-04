extends Area2D

# ==============================================================================
# SEÑALES
# ==============================================================================
signal start_route_requested(player_node)
signal moved(player_node)

# ==============================================================================
# PROPIEDADES EXPORTADAS Y VARIABLES
# ==============================================================================
@export var player_id: int = 0

# Variable para guardar la ruta que se cargó desde el archivo
# Usamos PackedVector2Array para coincidir con el tipo de dato de guardado
var current_route: PackedVector2Array = []

# Variables de estado para el arrastre manual
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
# Rectángulo límite para la "jaula" de movimiento
var limit_rect: Rect2 = Rect2()

# Referencia al nodo visual (debe llamarse "Panel" en tu escena Player.tscn)
@onready var visual_panel = $Panel

# ==============================================================================
# CICLO DE VIDA (ESTILO Y MOVIMIENTO MANUAL)
# ==============================================================================
func _ready():
	# Configura el estilo visual: azul y redondo
	if visual_panel:
		# Aseguramos que el panel no bloquee los clics al Area2D
		visual_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.0, 0.4, 0.8, 1.0) # Azul
		style.set_corner_radius_all(20) # Redondo
		style.anti_aliasing = true
		visual_panel.add_theme_stylebox_override("panel", style)

func _process(_delta):
	# Maneja el movimiento cuando se está arrastrando con el mouse
	if is_dragging:
		var target_pos = get_global_mouse_position() - drag_offset
		
		# --- LÓGICA DE LÍMITES (JAULA PERFECTA) ---
		if limit_rect.has_area():
			# Obtenemos el tamaño visual para el radio
			var size_x = visual_panel.size.x if visual_panel else 64.0
			var size_y = visual_panel.size.y if visual_panel else 64.0
				
			var radius_x = (size_x * scale.x) / 2.0
			var radius_y = (size_y * scale.y) / 2.0
			
			# Calculamos los límites internos
			var min_x = limit_rect.position.x + radius_x
			var max_x = limit_rect.end.x - radius_x
			var min_y = limit_rect.position.y + radius_y
			var max_y = limit_rect.end.y - radius_y
			
			# Aplicamos el clamp (restricción)
			if min_x > max_x: target_pos.x = limit_rect.get_center().x
			else: target_pos.x = clamp(target_pos.x, min_x, max_x)
				
			if min_y > max_y: target_pos.y = limit_rect.get_center().y
			else: target_pos.y = clamp(target_pos.y, min_y, max_y)
		
		# Aplicamos la posición final y emitimos la señal
		global_position = target_pos
		moved.emit(self)

# ==============================================================================
# LÓGICA DE ANIMACIÓN (NUEVO)
# ==============================================================================

## Ejecuta la trayectoria guardada en current_route
func play_route():
	if current_route.is_empty():
		return
		
	# Si se está arrastrando, cancelamos el arrastre para iniciar la animación
	if is_dragging:
		stop_dragging()
		
	var tween = create_tween()
	# Velocidad: 0.2 segundos por cada punto de la ruta
	var duration_per_point = 0.2
	
	for point in current_route:
		# Calculamos el centro del objetivo
		var center_offset = (visual_panel.size / 2.0) if visual_panel else Vector2.ZERO
		var target_pos = point - center_offset
		
		tween.tween_property(self, "position", target_pos, duration_per_point)\
			.set_trans(Tween.TRANS_LINEAR)

## Devuelve el centro visual del jugador para el RouteManager
func get_route_anchor() -> Vector2:
	var center_offset = (visual_panel.size / 2.0) if visual_panel else Vector2.ZERO
	return position + center_offset * scale

# ==============================================================================
# MANEJO DE ENTRADA (CLICS)
# ==============================================================================
func _input_event(_viewport, event, _shape_idx):
	# Clic izquierdo: Solicitar dibujar ruta
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		start_route_requested.emit(self)
	# Clic derecho: Iniciar arrastre
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		start_dragging()

func _input(event):
	# Soltar clic derecho: Detener arrastre
	if is_dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		stop_dragging()

func start_dragging():
	is_dragging = true
	drag_offset = get_global_mouse_position() - global_position
	# Feedback visual al arrastrar
	modulate.a = 0.7
	scale = Vector2(1.2, 1.2)
	z_index = 50 # Asegura que se dibuje por encima de otros

func stop_dragging():
	is_dragging = false
	# Restaurar feedback visual
	modulate.a = 1.0
	scale = Vector2(1.0, 1.0)
	z_index = 20
