extends Resource
class_name PlayData

# Nombre de la jugada
@export var name: String = "Nueva Jugada"

# Imagen previa
@export var preview_texture: Texture2D

# Posiciones de los jugadores 
@export var formations: Dictionary = {} 

# Rutas dibujadas
@export var routes: Dictionary = {}

# Fecha y hora de creación/modificación
@export var timestamp: float = 0.0
