@tool
extends Control

# --- CONFIGURACIÓN VISUAL ---
@export var radius: float = 80.0 # Qué tan grande es el gráfico
@export var line_width: float = 2.0
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.5) # Gris oscuro fondo
@export var fill_color: Color = Color(1.0, 0.5, 0.0, 0.4) # Naranja semitransparente 
@export var border_color: Color = Color(1.0, 0.8, 0.0, 1.0) # Borde dorado/amarillo

# --- NOMBRES DE LOS STATS (Orden del reloj, empezando arriba) ---
# Ajusta el orden para que coincida con tu diseño deseado
var stat_names = ["Speed", "Hands", "Stamina", "Arm", "Agility", "Game Sense"]

# --- VALORES ACTUALES (Normalizados de 0.0 a 1.0) ---
# Por defecto todo a la mitad
var values: Array[float] = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5] 

# Valor máximo de un stat
const MAX_STAT_VALUE = 100.0 

func _ready():
	# Si estamos en el juego, actualizamos una vez.
	queue_redraw()

func setup_data(stats_resource: Resource):
	if not stats_resource: return

	values = [
		float(stats_resource.get("speed")) / MAX_STAT_VALUE,
		float(stats_resource.get("hands")) / MAX_STAT_VALUE,
		float(stats_resource.get("stamina")) / MAX_STAT_VALUE,
		float(stats_resource.get("arm")) / MAX_STAT_VALUE,
		float(stats_resource.get("agility")) / MAX_STAT_VALUE,
		float(stats_resource.get("game_sense")) / MAX_STAT_VALUE
	]
	
	# Forzar redibujado
	queue_redraw()
func _draw():
	var center = size / 2.0 # El centro del Control
	var angle_step = TAU / 6.0 # 360 grados divididos entre 6 lados (TAU es 2*PI)
	var start_angle = -PI / 2.0 # Empezar arriba (12 en punto)
	
	# DIBUJAR FONDO 
	var bg_points = PackedVector2Array()
	for i in range(6):
		var angle = start_angle + (i * angle_step)
		var point = center + Vector2(cos(angle), sin(angle)) * radius
		bg_points.append(point)
	
	# Cerramos el polígono repitiendo el primer punto al final para el borde
	var bg_border = bg_points.duplicate()
	bg_border.append(bg_points[0])
	
	draw_colored_polygon(bg_points, background_color)
	draw_polyline(bg_border, Color.GRAY, 1.0)
	
	# lineas guia
	for point in bg_points:
		draw_line(center, point, Color(1, 1, 1, 0.1), 1.0)

	# El polígono naranja
	var stat_points = PackedVector2Array()
	for i in range(6):
		var angle = start_angle + (i * angle_step)
		# La magia: Multiplicamos el radio por el valor (0.0 a 1.0)
		# Clamp para asegurar que no se salga del hexágono
		var val = clamp(values[i], 0.0, 1.0)
		var point = center + Vector2(cos(angle), sin(angle)) * (radius * val)
		stat_points.append(point)
	
	# Dibujar relleno
	draw_colored_polygon(stat_points, fill_color)
	
	# Dibujar borde brillante
	var stat_border = stat_points.duplicate()
	stat_border.append(stat_points[0]) # Cerrar loop
	draw_polyline(stat_border, border_color, line_width)

func _process(_delta):
	if Engine.is_editor_hint():
		place_labels()

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
		place_labels()

func place_labels():
	var center = size / 2.0
	var angle_step = TAU / 6.0
	var start_angle = -PI / 2.0
	var label_offset = 20.0 # Distancia extra desde la punta
	
	var labels = [
		$LabelSpeed, $LabelHands, $LabelStamina, 
		$LabelArm, $LabelAgility, $LabelGameSense
	]
	
	for i in range(labels.size()):
		var label = labels[i]
		if not label: continue
		
		var angle = start_angle + (i * angle_step)
		# Calculamos posición en la punta del hexágono + un extra
		var point = center + Vector2(cos(angle), sin(angle)) * (radius + label_offset)
		
		# Centramos el label en esa posición
		label.position = point - (label.size / 2.0)
