extends CanvasLayer

# Cambiamos la señal para enviar la ruta completa del archivo
signal play_selected(file_path: String)

@onready var name_label = %Label 
@onready var speed_val = %VelocityLabel
@onready var hands_val = %HandsLabel
@onready var stamina_val = %StaminaLabel
@onready var arm_val = %ArmLabel
@onready var agility_val = %AgilityLabel
@onready var sense_val = %BrainLabel
@onready var stamina_bar = %StaminaBar

# Array para almacenar las rutas de los archivos encontrados físicamente
var detected_play_paths: Array = ["", "", "", "", ""]

func _ready():
	# 1. Conectamos las imágenes como botones usando gui_input
	for i in range(1, 6):
		var suffix = str(i) if i > 1 else ""
		var icon = get_node_or_null("%PlayIcon" + suffix)
		if icon:
			icon.gui_input.connect(func(event): _on_icon_input(event, i))
	#se escanea la carpeta de jugadas
	_load_play_names_to_labels()

func _on_icon_input(event: InputEvent, slot_index: int):
	# Detectamos el clic izquierdo en la imagen
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var path_to_load = detected_play_paths[slot_index - 1]
		
		if path_to_load != "":
			play_selected.emit(path_to_load)
			print("Enviando ruta a cargar: ", path_to_load)
		else:
			print("Slot ", slot_index, " está vacío visualmente.")

func _load_play_names_to_labels():
	var dir_path = "user://plays/"
	var dir = DirAccess.open(dir_path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var slot_index = 0
		_clear_labels()
		
		while file_name != "" and slot_index < 5:
			if not dir.current_is_dir() and file_name.ends_with(".res"):
				var full_path = dir_path + file_name
				
				# se usa load() en lugar de FileAccess.get_var()
				var play_resource = load(full_path)
				
				if play_resource:
					detected_play_paths[slot_index] = full_path
					var label_suffix = str(slot_index + 1) if slot_index > 0 else ""
					var label = get_node_or_null("%PlayLabel" + label_suffix)
					
					if label:
						# Intentamos obtener el nombre guardado, si no usamos el nombre del archivo
						var d_name = play_resource.get("display_name")
						label.text = d_name if d_name else file_name.get_basename()
					
					slot_index += 1
			file_name = dir.get_next()

func _clear_labels():
	for i in range(1, 6):
		var suffix = str(i) if i > 1 else ""
		var label = get_node_or_null("%PlayLabel" + suffix)
		if label: label.text = "---"
		detected_play_paths[i-1] = ""

func update_player_stats(data: Dictionary):
	if name_label: name_label.text = data["name"]
	if speed_val: speed_val.text = str(data["speed"])
	if hands_val: hands_val.text = str(data["hands"])
	if arm_val: arm_val.text = str(data["arm"])
	if agility_val: agility_val.text = str(data["agility"])
	if sense_val: sense_val.text = str(data["game_sense"])
	
	if %StaminaLabel: 
		%StaminaLabel.text = str(int(data["stamina_display"]))

	if stamina_bar:
		stamina_bar.max_value = 100.0
		stamina_bar.value = data["stamina_current"]
