extends CanvasLayer

# ==============================================================================
# DEPENDENCIAS Y ESTADO
# ==============================================================================

# Inyección de dependencias
@export var editor: Node2D 

@onready var plays_grid: GridContainer = %PlaysGrid
@onready var btn_new: Button = %BtnNew
@onready var btn_save: Button = %BtnSave

# Memoria volátil de jugadas 
var saved_plays: Array[Dictionary] = []

# ==============================================================================
# CICLO DE VIDA Y CONEXIONES
# ==============================================================================

func _ready() -> void:
	_setup_connections()

func _setup_connections() -> void:
	# Verificamos existencia antes de conectar 
	if is_instance_valid(btn_new):
		btn_new.pressed.connect(_on_new_play_requested)
	
	if is_instance_valid(btn_save):
		btn_save.pressed.connect(_on_save_requested)

# ==============================================================================
# MANEJO DE EVENTOS
# ==============================================================================

func _on_new_play_requested() -> void:
	if _is_editor_ready():
		editor.reset_current_play()

func _on_save_requested() -> void:
	if _is_editor_ready():
		var new_snapshot = editor.get_play_snapshot()
		saved_plays.append(new_snapshot)
		_update_plays_list_ui()

func _on_load_play_requested(play_data: Dictionary) -> void:
	if _is_editor_ready():
		editor.load_play_data(play_data)

# ==============================================================================
# LÓGICA DE INTERFAZ 
# ==============================================================================

## refresca visualmente la lista de jugadas
func _update_plays_list_ui() -> void:
	_clear_plays_grid()
	_populate_plays_grid()

func _clear_plays_grid() -> void:
	for child in plays_grid.get_children():
		child.queue_free()

func _populate_plays_grid() -> void:
	for play_data in saved_plays:
		var play_button = _create_play_button(play_data)
		plays_grid.add_child(play_button)

## factory method para crear los botones de jugada
func _create_play_button(data: Dictionary) -> Button:
	var btn = Button.new()
	btn.text = data.get("name", "Jugada %d" % (saved_plays.find(data) + 1))
	btn.custom_minimum_size = Vector2(100, 80)
	
	# bind para pasar la referencia de datos específica al botón
	btn.pressed.connect(_on_load_play_requested.bind(data))
	return btn

# ==============================================================================
# HELPERS
# ==============================================================================

func _is_editor_ready() -> bool:
	if not is_instance_valid(editor):
		_log_error("Editor reference is missing")
		return false
	return true

func _log_error(message: String) -> void:
	push_error("[PlaybookUI Error]: %s" % message)
