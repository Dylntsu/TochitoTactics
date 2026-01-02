extends CanvasLayer

# ==============================================================================
# DEPENDENCIAS Y ESTADO
# ==============================================================================

# inyeccion de dependencias
@export var editor: Node2D 

@onready var plays_grid: GridContainer = %PlaysGrid
@onready var btn_new: Button = %BtnNew
@onready var btn_save: Button = %BtnSave
@onready var save_popup: AcceptDialog = %SavePlayGroup
@onready var name_input: LineEdit = %PlayNameInput

# memoria temporal para el proceso de guardado
var _pending_snapshot: Dictionary = {}
# memoria volatil de jugadas 
var saved_plays: Array[Dictionary] = []

# ==============================================================================
# CICLO DE VIDA Y CONEXIONES
# ==============================================================================

func _ready() -> void:
	_setup_connections()

func _setup_connections() -> void:
	# verificamos existencia antes de conectar 
	if is_instance_valid(btn_new):
		btn_new.pressed.connect(_on_new_play_requested)
	
	if is_instance_valid(btn_save):
		btn_save.pressed.connect(_on_save_button_pressed)
		
	if is_instance_valid(save_popup):
		save_popup.confirmed.connect(_on_save_confirmed)

# ==============================================================================
# MANEJO DE EVENTOS (HANDLERS)
# ==============================================================================

func _on_new_play_requested() -> void:
	if _is_editor_ready():
		editor.reset_current_play()

## el usuario inicia el proceso de guardado
func _on_save_button_pressed() -> void:
	if _is_editor_ready():
		# capturamos los datos tecnicos pero esperamos al nombre
		_pending_snapshot = editor.get_play_snapshot()
		_show_save_dialog()

## el usuario confirma el nombre en el popup
func _on_save_confirmed() -> void:
	_finalize_save_process()

func _on_load_play_requested(play_data: Dictionary) -> void:
	if _is_editor_ready():
		editor.load_play_data(play_data)

# ==============================================================================
# LOGICA DE INTERFAZ 
# ==============================================================================

func _show_save_dialog() -> void:
	if is_instance_valid(name_input):
		name_input.text = ""
		save_popup.popup_centered()
		name_input.grab_focus()

func _finalize_save_process() -> void:
	var play_name = name_input.text.strip_edges()
	
	# validacion de nombre por defecto
	if play_name.is_empty():
		play_name = "jugada %d" % (saved_plays.size() + 1)
	
	# asignamos el nombre y guardamos en la lista definitiva
	_pending_snapshot["name"] = play_name
	saved_plays.append(_pending_snapshot)
	
	# limpieza y actualizacion visual
	_pending_snapshot = {}
	_update_plays_list_ui()

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
	btn.text = data.get("name", "sin nombre")
	btn.custom_minimum_size = Vector2(100, 80)
	
	# bind para pasar la referencia de datos especifica al boton
	btn.pressed.connect(_on_load_play_requested.bind(data))
	return btn

# ==============================================================================
# HELPERS
# ==============================================================================

func _is_editor_ready() -> bool:
	if not is_instance_valid(editor):
		_log_error("editor reference is missing")
		return false
	return true

func _log_error(message: String) -> void:
	push_error("[PlaybookUI Error]: %s" % message)
