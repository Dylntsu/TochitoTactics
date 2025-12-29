extends RefCounted
class_name GridService

# Esta clase solo hace cálculos, no dibuja nada
static func calculate_grid(bounds: Rect2, size: Vector2) -> Dictionary:
	var points: Array[Vector2] = []
	var spacing_h = bounds.size.x / max(1, size.x - 1)
	var spacing_v = bounds.size.y / max(1, size.y - 1)
	
	for x in range(size.x):
		for y in range(size.y):
			var pos = Vector2(
				bounds.position.x + (x * spacing_h),
				bounds.position.y + (y * spacing_v)
			)
			points.append(pos)
			
	return {
		"points": points,
		"spacing": int(min(spacing_h, spacing_v))
	}
