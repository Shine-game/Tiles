extends SceneTree

const Growth = preload("res://scripts/growth.gd")
const Rules = preload("res://scripts/rules.gd")
const BoardView = preload("res://scripts/board_view.gd")
const Palette = preload("res://scripts/palette.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.00001

func _initialize() -> void:
	var before: Array = Rules.empty_board(9)
	before[2][0] = Rules.BLUE
	var after: Array = before.duplicate(true)
	for x in range(1, 5):
		after[2][x] = Rules.BLUE
	var growth = Growth.new()
	growth.build(before, after)
	for x in range(1, 5):
		check(near(growth.arrivals[Vector2i(x, 2)], x * Growth.STEP), "growth reaches each chain square in sequence")
	check(growth.edges.size() == 4, "chain has only side connections")
	check(growth.flowers.is_empty(), "open chain cannot bloom")
	check(growth.duration >= 4 * Growth.STEP + Growth.CENTER_POP, "resolution includes the last center pop")
	before = Rules.empty_board(9)
	before[2][0] = Rules.BLUE
	before[2][4] = Rules.BLUE
	after = before.duplicate(true)
	for x in range(1, 4):
		after[2][x] = Rules.BLUE
	growth.build(before, after)
	check(near(growth.arrivals[Vector2i(1, 2)], Growth.STEP), "left contact launches a front")
	check(near(growth.arrivals[Vector2i(3, 2)], Growth.STEP), "right contact launches a simultaneous front")
	check(near(growth.arrivals[Vector2i(2, 2)], 2 * Growth.STEP), "fronts meet at the central square")
	# Different-color contact and corner-only contact never supply a growth source.
	before = Rules.empty_board(9)
	before[2][0] = Rules.CORAL
	after = before.duplicate(true)
	after[2][1] = Rules.BLUE
	after[2][2] = Rules.BLUE
	growth.build(before, after)
	check(near(growth.arrivals[Vector2i(1, 2)], 0) and near(growth.arrivals[Vector2i(2, 2)], 0), "independent centers awaken together")
	check(growth.edges.size() == 1, "different colors do not connect")
	check(near(growth.edges[0].finish, Growth.STEP / 2), "opposite fronts meet at the shared side midpoint")
	before = Rules.empty_board(9)
	before[0][0] = Rules.BLUE
	after = before.duplicate(true)
	after[1][1] = Rules.BLUE
	growth.build(before, after)
	check(near(growth.arrivals[Vector2i(1, 1)], 0) and growth.edges.is_empty(), "corner-only contact remains independent")
	for color: int in [Rules.BLUE, Rules.CORAL]:
		before = Rules.empty_board(9)
		after = before.duplicate(true)
		for y in range(2):
			for x in range(2):
				after[y][x] = color
		growth.build(before, after)
		check(growth.flowers.size() == 1, "2 by 2 produces exactly one corner flower")
		check(growth.flowers.has(Vector2i(1, 1)), "flower occupies the shared corner")
		check(near(growth.flowers[Vector2i(1, 1)].start, Growth.STEP / 2), "flower waits for the last loop connection")
		check(Palette.accent(color) == Palette.tile(3 - color), "flowers invert the two network colors")
		after[0][0] = 3 - color
		growth.build(before, after)
		check(growth.flowers.is_empty(), "mixed-color 2 by 2 does not flower")
	before = Rules.empty_board(9)
	after = before.duplicate(true)
	for y in range(3):
		for x in range(3):
			after[y][x] = Rules.BLUE
	growth.build(before, after)
	check(growth.flowers.size() == 4, "3 by 3 creates four flowers")
	check(growth.links.size() == 4, "four flowers establish a closed ring of blooming vines")
	for corner: Vector2i in growth.flowers:
		var degree := 0
		for link: Dictionary in growth.links:
			if link.a == corner or link.b == corner:
				degree += 1
		check(degree == 2, "each ring flower connects to its two neighbors")
	for link: Dictionary in growth.links:
		check(link.start >= growth.flowers[link.a].start and link.start >= growth.flowers[link.b].start, "blooming vine waits for both flowers")
		check(growth.duration >= link.start + Growth.LINK_GROW + Growth.STAR_POP, "resolution includes vine stars")
	check(Growth.FLOWER_RADIUS <= 1.0 / 3.0, "flowers have a maximum radius of one third of a square")
	check(2 * Growth.FLOWER_RADIUS < 1, "neighboring flowers cannot overlap")
	# Expand an established square with a domino: preserve the old flower,
	# open the second, and decorate their connecting vine only once.
	before = Rules.empty_board(9)
	for y in range(2):
		for x in range(2):
			before[y][x] = Rules.BLUE
	after = before.duplicate(true)
	after[0][2] = Rules.BLUE
	after[1][2] = Rules.BLUE
	growth.build(before, after)
	check(growth.flowers.size() == 2 and growth.links.size() == 1, "domino beside a square creates two connected blooms")
	check(growth.flowers[Vector2i(1, 1)].old, "established flower never restarts")
	check(not growth.flowers[Vector2i(2, 1)].old, "new flower gets an opening animation")
	for edge: Dictionary in growth.edges:
		if edge.old:
			check(near(edge.finish, 0), "existing vines never restart")
	var settled = Growth.new()
	settled.build(after, after)
	check(settled.edges.size() == growth.edges.size() and settled.flowers.size() == growth.flowers.size() and settled.links.size() == growth.links.size(), "settled structure is independent of placement order")
	check(near(settled.duration, 0), "restoring a board does not create new growth")
	# Resolution is based on elapsed time, not rendered frames; cancellation
	# leaves no timer callbacks that could modify a restored board later.
	var view = BoardView.new()
	view.animate_growth(before, after)
	check(view.growing, "accepted placement starts growth immediately")
	view.advance_growth(view.pattern.duration / 2)
	check(view.growing, "growth remains busy midway through blooming")
	view.advance_growth(100)
	check(not view.growing, "all scheduled growth eventually resolves")
	view.animate_growth(before, after)
	view.show_settled(before)
	view.advance_growth(100)
	check(not view.growing and view.pattern.board == before, "undo cancels all pending growth")
	# Leaf tips must follow growth even when it travels left/up, and old vines
	# must retain that direction when another piece is added or Back is used.
	before = Rules.empty_board(9)
	before[2][4] = Rules.BLUE
	after = before.duplicate(true)
	after[2][3] = Rules.BLUE
	after[2][2] = Rules.BLUE
	growth.build(before, after)
	for edge: Dictionary in growth.edges:
		check(edge.flow == -1, "reverse growth points leaves toward the newly reached cells")
		for sprout: Dictionary in Growth.leaf_sprouts(edge):
			check(sprout.direction == -1, "every leaf on reverse growth keeps the same forward direction")
			check(growth.duration >= sprout.start + Growth.LEAF_POP, "Place gate includes every unfolding leaf")
	view.animate_growth(before, after)
	var original_key: Vector4i = Growth.edge_key(Vector2i(3, 2), Vector2i(4, 2))
	var extended: Array = after.duplicate(true)
	extended[2][1] = Rules.BLUE
	view.animate_growth(after, extended)
	check(view.direction_by_edge[original_key].flow == -1, "later placements preserve established leaf direction")
	view.show_settled(after, true)
	check(view.direction_by_edge[original_key].flow == -1, "Back preserves direction on surviving vines")
	view.show_settled(Rules.create_board())
	check(view.direction_by_edge.is_empty(), "new game clears old growth directions")
	before = Rules.empty_board(9)
	after = before.duplicate(true)
	after[1][1] = Rules.BLUE
	after[1][2] = Rules.BLUE
	growth.build(before, after)
	var opposed: Array = Growth.leaf_sprouts(growth.edges[0])
	check(opposed.any(func(sprout: Dictionary): return sprout.direction == 1) and opposed.any(func(sprout: Dictionary): return sprout.direction == -1), "meeting fronts sprout leaves forward from both ends")
	# Placement guides disappear locally, only after a real vine crosses them.
	before = Rules.empty_board(9)
	before[2][0] = Rules.BLUE
	after = before.duplicate(true)
	after[2][1] = Rules.BLUE
	growth.build(before, after)
	var a := Vector2i(0, 2)
	var b := Vector2i(1, 2)
	var crossing: float = Growth.STEP / 2
	check(near(growth.grid_visibility(a, b, 0), 1), "guide remains visible before growth reaches boundary")
	check(near(growth.grid_visibility(a, b, crossing + Growth.GRID_FADE / 2), 0.5), "guide fades progressively after crossing")
	check(near(growth.grid_visibility(a, b, growth.duration), 0), "crossed guide disappears once pattern resolves")
	check(near(growth.grid_visibility(b, a, growth.duration), 0), "guide crossing is independent of lookup direction")
	check(near(growth.grid_visibility(b, Vector2i(2, 2), growth.duration), 1), "empty neighboring cells retain their guides")
	check(near(growth.grid_visibility(a, Vector2i(-1, 2), growth.duration), 1), "outer field border remains visible")
	after[2][2] = Rules.CORAL
	growth.build(before, after)
	check(near(growth.grid_visibility(b, Vector2i(2, 2), growth.duration), 0), "filled different-color cells merge without separation guides")
	growth.build(after, after)
	check(near(growth.grid_visibility(a, b, 0), 0), "established vines do not flash grid lines back on")
	growth.build(before, before)
	check(near(growth.grid_visibility(a, b, 0), 1), "undo restores guides in the cleared space")
	view.free()
	print("Growth: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
