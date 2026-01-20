extends Area2D
class_name Ball

# Estados del balón
enum BallState { HELD, SNAP, AIR, GROUND }
var state = BallState.HELD

# Variables de movimiento
var velocity = Vector2.ZERO
var target_position = Vector2.ZERO
var speed = 600.0 # Velocidad del pase/snap
var carrier = null # Quién tiene el balón

func _physics_process(delta):
	if state == BallState.SNAP or state == BallState.AIR:
		# Mover el balón hacia el objetivo
		var direction = global_position.direction_to(target_position)
		var distance = global_position.distance_to(target_position)
		
		# Movimiento simple lineal
		global_position += direction * speed * delta
		
		# Rotación visual para efecto
		rotation += 15.0 * delta
		
		# Chequear si llegó al destino (simple)
		if distance < 10.0:
			_on_target_reached()

	elif state == BallState.HELD and carrier:
		# Pegado a la mano del jugador (offset visual)
		global_position = carrier.global_position + Vector2(0, 10)
		rotation = 0

func attach_to_player(player_node):
	state = BallState.HELD
	carrier = player_node
	# Desactivamos monitoreo para no autocolisionar inmediatamente
	monitoring = false

func snap_to(target_pos):
	state = BallState.SNAP
	carrier = null
	target_position = target_pos
	monitoring = true # Reactivar colisiones si es necesario
	
func throw_to(target_pos):
	state = BallState.AIR
	carrier = null
	target_position = target_pos
	monitoring = true

func _on_target_reached():
	# Lógica básica de llegada
	if state == BallState.SNAP:
		# En el snap, asumimos que el QB lo agarra automático por ahora
		state = BallState.HELD
		# Aquí emitiríamos señal "ball_snapped"
