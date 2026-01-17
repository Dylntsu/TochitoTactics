extends CanvasLayer

# ==============================================================================
# CONFIGURACION DE ARCHIVOS
# ==============================================================================
const SAVE_DIR = "user://plays/"

# ==============================================================================
# DEPENDENCIAS Y ESTADO
# ==============================================================================
@export var editor: Node2D 
# Referencias UI nuevas 
@onready var btn_prev = %BtnPrev
@onready var btn_next = %BtnNext
@onready var preview_rect = %PreviewRect  
@onready var play_name_label = %PlayNameLabel 

# Referencias Botones Laterales
@onready var btn_new: Button = %BtnNew
@onready var btn_save: Button = %BtnSave
@onready var save_popup: AcceptDialog = %SavePlayPopup
@onready var name_input: LineEdit = %PlayNameInput
@onready var delete_confirm_popup: ConfirmationDialog = %DeleteConfirmPopup
@onready var autosave_timer = $AutosaveTimer

# Estado del Carrusel
var saved_plays: Array[Resource] = []
var current_play_index: int = 0
var _pending_play: Resource = null # Para guardar
var _selected_play: Resource = null # Jugada activa

# ==============================================================================
# CICLO DE VIDA
# ==============================================================================
func _ready() -> void:
	# Asegurar carpeta
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)
		
	# Configurar conexiones UI
	_setup_connections()
	
	await get_tree().process_frame
	
	# Conexión Editor -> UI 
	if is_instance_valid(editor):
		if editor.has_signal("content_changed"):
			if not editor.content_changed.is_connected(_on_editor_content_changed):
				editor.content_changed.connect(_on_editor_content_changed)
	
	# Carga inicial
	_load_all_plays_from_disk()
	
	if not saved_plays.is_empty():
		_select_play_by_index(0)
	else:
		_update_selector_visuals()

func _setup_connections() -> void:
	# 1. Botones del Carrusel (NUEVO)
	if is_instance_valid(btn_prev): btn_prev.pressed.connect(_on_prev_play)
	if is_instance_valid(btn_next): btn_next.pressed.connect(_on_next_play)

	# 2. Botones de Gestión
	if is_instance_valid(btn_new): btn_new.pressed.connect(_on_new_play_requested)
	if is_instance_valid(btn_save): btn_save.pressed.connect(_on_save_button_pressed)
	if is_instance_valid(save_popup): save_popup.confirmed.connect(_on_save_confirmed)
	if is_instance_valid(%BtnDelete): %BtnDelete.pressed.connect(_on_delete_button_pressed)
	if is_instance_valid(delete_confirm_popup): delete_confirm_popup.confirmed.connect(_on_delete_confirmed)
	
	# 3. Acciones de Juego
	if is_instance_valid(%BtnPlay): %BtnPlay.pressed.connect(_on_play_preview_pressed)
	if is_instance_valid(%BtnReset): %BtnReset.pressed.connect(_on_reset_button_pressed)
	
	# 4. Roles (Opcional, si los tienes en botones aparte)
	if is_instance_valid(%BtnSetQB): %BtnSetQB.pressed.connect(_on_set_qb_pressed)
	if is_instance_valid(%BtnSetCenter): %BtnSetCenter.pressed.connect(_on_set_center_pressed)
	
	# 5. Timer
	if autosave_timer: autosave_timer.timeout.connect(_on_autosave_timer_timeout)

# ==============================================================================
# LÓGICA DEL CARRUSEL (SELECTOR)
# ==============================================================================
func _on_prev_play():
	if saved_plays.is_empty(): return
	# Guardar silenciosamente antes de cambiar
	_perform_silent_save()
	
	current_play_index = (current_play_index - 1 + saved_plays.size()) % saved_plays.size()
	_select_play_by_index(current_play_index)

func _on_next_play():
	if saved_plays.is_empty(): return
	_perform_silent_save()
	
	current_play_index = (current_play_index + 1) % saved_plays.size()
	_select_play_by_index(current_play_index)

func _select_play_by_index(index: int):
	current_play_index = index
	var play_data = saved_plays[index]
	_selected_play = play_data
	
	# Cargar en el Editor
	if editor and editor.has_method("load_play_data"):
		editor.stop_all_animations()
		editor.load_play_data(play_data)
	
	_update_selector_visuals()

func _update_selector_visuals():
	if saved_plays.is_empty():
		play_name_label.text = "Sin Jugadas"
		if preview_rect: preview_rect.texture = null
		return
		
	var play = saved_plays[current_play_index]
	play_name_label.text = play.name
	
	if preview_rect:
		if play.preview_texture:
			preview_rect.texture = play.preview_texture
		else:
			preview_rect.texture = null # O poner textura "No Preview"

# ==============================================================================
# GESTIÓN DE ARCHIVOS
# ==============================================================================
func _load_all_plays_from_disk() -> void:
	saved_plays.clear()
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".res") or file_name.ends_with(".tres")):
				var full_path = SAVE_DIR + file_name
				var resource = ResourceLoader.load(full_path)
				if resource is PlayData:
					saved_plays.append(resource)
			file_name = dir.get_next()
	
	# Si no hay jugadas, creamos una por defecto vacía para no romper el carrusel
	if saved_plays.is_empty():
		pass

func _on_new_play_requested() -> void:
	if not _is_editor_ready(): return
	
	# Guardar la actual antes de crear nueva
	_perform_silent_save()
	
	editor.unlock_all_players()
	editor.reset_current_play()
	
	var new_play = PlayData.new()
	new_play.name = "Nueva Jugada %d" % (saved_plays.size() + 1)
	
	saved_plays.append(new_play)
	current_play_index = saved_plays.size() - 1 # Ir a la última 
	
	_selected_play = new_play
	_update_selector_visuals()
	_show_toast("Nueva Jugada Creada", Color.CYAN)
	
	# Trigger autoguardado inicial para crear el archivo
	_perform_silent_save()

func _on_save_button_pressed() -> void:
	if _is_editor_ready():
		# Capturamos screenshot antes de abrir popup
		var current_res = await editor.get_play_resource()
		if _selected_play:
			_selected_play.preview_texture = current_res.preview_texture
			_selected_play.formations = current_res.formations
			_selected_play.routes = current_res.routes
			
		_pending_play = _selected_play
		_show_save_dialog()

func _on_save_confirmed() -> void:
	if not _pending_play: return

	var new_name = name_input.text.strip_edges()
	if not new_name.is_empty():
		# Si cambiamos el nombre, borramos el archivo viejo para no duplicar
		var old_safe_name = _pending_play.name.validate_filename()
		var old_path = SAVE_DIR + old_safe_name + ".res"
		if FileAccess.file_exists(old_path) and new_name != _pending_play.name:
			DirAccess.remove_absolute(old_path)
			
		_pending_play.name = new_name

	var safe_filename = _pending_play.name.validate_filename()
	var save_path = SAVE_DIR + safe_filename + ".res"
	
	var error = ResourceSaver.save(_pending_play, save_path)
	if error == OK:
		_update_selector_visuals()
		_show_toast("¡Guardado!", Color.GREEN)
	else:
		_show_toast("Error al guardar", Color.RED)

func _on_delete_button_pressed() -> void:
	if saved_plays.is_empty(): return
	delete_confirm_popup.popup_centered()

func _on_delete_confirmed() -> void:
	if saved_plays.is_empty(): return
	
	var play_to_delete = saved_plays[current_play_index]
	var safe_name = play_to_delete.name.validate_filename()
	var file_path = SAVE_DIR + safe_name + ".res"
	
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
	
	saved_plays.remove_at(current_play_index)
	
	# Ajustar índice si borramos el último
	if current_play_index >= saved_plays.size():
		current_play_index = max(0, saved_plays.size() - 1)
	
	if saved_plays.is_empty():
		# Resetear editor si no queda nada
		editor.reset_current_play()
		_update_selector_visuals()
	else:
		_select_play_by_index(current_play_index)
		
	_show_toast("Eliminado", Color.ORANGE)

# ==============================================================================
# AUTOGUARDADO & HELPERS
# ==============================================================================
func _on_editor_content_changed() -> void:
	if _selected_play:
		autosave_timer.start() # Debounce

func _on_autosave_timer_timeout() -> void:
	_perform_silent_save()

func _perform_silent_save() -> void:
	if _selected_play == null: return
	if not _is_editor_ready(): return
	
	var fresh_data = editor.get_current_state_as_data()
	
	_selected_play.formations = fresh_data.formations
	_selected_play.routes = fresh_data.routes
	
	var safe_name = _selected_play.name.validate_filename()
	var save_path = SAVE_DIR + safe_name + ".res"
	ResourceSaver.save(_selected_play, save_path)

func _show_save_dialog() -> void:
	if is_instance_valid(name_input):
		name_input.text = _selected_play.name if _selected_play else ""
		save_popup.popup_centered()
		name_input.grab_focus()

func _is_editor_ready() -> bool:
	return is_instance_valid(editor)

func _show_toast(message: String, color: Color = Color.WHITE) -> void:
	var label = %StatusLabel
	if not label: return
	
	if label.has_meta("tween"):
		var t = label.get_meta("tween")
		if t and t.is_valid(): t.kill()
	
	label.text = message
	label.modulate = color
	label.modulate.a = 1.0
	
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 2.0).set_delay(1.0)
	label.set_meta("tween", tween)

# Botones extra
func _on_play_preview_pressed():
	if _is_editor_ready():
		_perform_silent_save()
		editor.lock_editor_for_play()
		# Resetear posiciones antes de correr
		for child in editor.nodes_container.get_children():
			if child.has_method("reset_to_start"): child.reset_to_start()
		await get_tree().process_frame
		editor.play_current_play()

func _on_reset_button_pressed():
	if _is_editor_ready():
		editor.unlock_editor_for_editing()
		editor.reset_formation_state()

func _on_set_qb_pressed():
	# Implementa la lógica si tienes el botón
	pass

func _on_set_center_pressed():
	pass
