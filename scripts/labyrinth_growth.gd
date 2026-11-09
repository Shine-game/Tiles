class_name LabyrinthGrowth
extends "res://scripts/growth.gd"

const WALL_RECEDE := 0.18
const BENCH_POP := 0.22
var openings: Dictionary = {}

# Trees occupy the former 2x2 flower corners. Neighboring enclosures share
# an existing center-to-center hedge, perpendicular to the tree pair.
static func shared_wall(a: Vector2i, b: Vector2i) -> Vector4i:
	if a.y == b.y:
		var left := a if a.x < b.x else b
		return edge_key(left + Vector2i.UP, left)
	var top := a if a.y < b.y else b
	return edge_key(top + Vector2i.LEFT, top)

func build(before: Array, after: Array) -> void:
	super.build(before, after)
	openings.clear()
	for link: Dictionary in links:
		# Both trees finish rising before their common wall recedes.
		link.start = -100.0 if link.old else maxf(flowers[link.a].start, flowers[link.b].start) + FLOWER_POP
		openings[shared_wall(link.a, link.b)] = link
		if not link.old:
			duration = maxf(duration, link.start + WALL_RECEDE + BENCH_POP)

func wall_visibility(key: Vector4i, time: float) -> float:
	if not openings.has(key):
		return 1.0
	var start: float = openings[key].start
	return 1.0 - smoothstep(start, start + WALL_RECEDE, time)

static func bench_progress(link: Dictionary, time: float) -> float:
	return smoothstep(link.start + WALL_RECEDE, link.start + WALL_RECEDE + BENCH_POP, time)
