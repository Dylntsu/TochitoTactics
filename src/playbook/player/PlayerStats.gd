extends Resource
class_name PlayerStats

@export var full_name: String = "Nuevo Jugador"
@export var portrait: Texture2D

@export_group("Atributos")
@export_range(0, 100) var stamina: float = 70
@export_range(0, 100) var speed: float = 70
@export_range(0, 100) var hands: float = 70
@export_range(0, 100) var arm: float = 70
@export_range(0, 100) var game_sense: float = 70
@export_range(0, 100) var agility: float = 70

@export_group("Configuración")
@export var default_role: String = "WR"
