extends "res://scripts/coral_growth.gd"

# Reuse Coral's same-color waves and formation detection. Unfinished landmarks
# have no borrowed artwork, bloom events or extra animation delay.
func build(before: Array, after: Array) -> void:
	super.build(before, after)
	components.clear()
	flowers.clear()
	links.clear()
	duration = 0.0
	for cell: Vector2i in arrivals:
		if float(arrivals[cell]) >= 0:
			duration = maxf(duration, float(arrivals[cell]) + 0.30)
