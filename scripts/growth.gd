class_name TileGrowth
extends RefCounted

# A deterministic event schedule in board coordinates. Rendering never changes it.
const STEP := 0.14
const CENTER_POP := 0.18
const FLOWER_POP := 0.26
const LINK_GROW := 0.18
const STAR_POP := 0.24
const RIPPLE := 0.18
const FLOWER_RADIUS := 1.0 / 3.0
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var board: Array = []
var arrivals: Dictionary = {}
var edges: Array = []
var flowers: Dictionary = {}
var links: Array = []
var duration := 0.0

static func value(grid: Array, cell: Vector2i) -> int:
	if cell.y < 0 or cell.x < 0 or cell.y >= grid.size() or cell.x >= grid.size():
		return 0
	return grid[cell.y][cell.x]

static func edge_key(a: Vector2i, b: Vector2i) -> Vector4i:
	if a.y > b.y or (a.y == b.y and a.x > b.x):
		return Vector4i(b.x, b.y, a.x, a.y)
	return Vector4i(a.x, a.y, b.x, b.y)

static func is_flower(grid: Array, corner: Vector2i, color: int) -> bool:
	for offset: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]:
		if value(grid, corner + offset) != color:
			return false
	return color != 0

func build(before: Array, after: Array) -> void:
	board = after.duplicate(true)
	arrivals.clear()
	edges.clear()
	flowers.clear()
	links.clear()
	duration = 0
	var pending: Dictionary = {}
	for y in range(board.size()):
		for x in range(board.size()):
			var cell := Vector2i(x, y)
			var color: int = board[y][x]
			if color == 0:
				continue
			if value(before, cell) == color:
				arrivals[cell] = -100.0
			else:
				pending[cell] = true
	# Find each new same-color component. Existing neighbors are simultaneous
	# sources; an independent component awakens all of its centers at t=0.
	while not pending.is_empty():
		var first: Vector2i = pending.keys()[0]
		var component: Array = [first]
		pending.erase(first)
		var cursor := 0
		while cursor < component.size():
			var cell: Vector2i = component[cursor]
			cursor += 1
			for direction: Vector2i in DIRECTIONS:
				var neighbor := cell + direction
				if pending.has(neighbor) and value(board, neighbor) == value(board, cell):
					pending.erase(neighbor)
					component.append(neighbor)
		var wave: Array = []
		for cell: Vector2i in component:
			arrivals[cell] = INF
			for direction: Vector2i in DIRECTIONS:
				if value(before, cell + direction) == value(board, cell):
					arrivals[cell] = STEP
					wave.append(cell)
					break
		if wave.is_empty():
			for cell: Vector2i in component:
				arrivals[cell] = 0.0
		else:
			cursor = 0
			while cursor < wave.size():
				var cell: Vector2i = wave[cursor]
				cursor += 1
				for direction: Vector2i in DIRECTIONS:
					var neighbor := cell + direction
					if component.has(neighbor) and float(arrivals[neighbor]) > float(arrivals[cell]) + STEP:
						arrivals[neighbor] = float(arrivals[cell]) + STEP
						wave.append(neighbor)
		for cell: Vector2i in component:
			duration = maxf(duration, float(arrivals[cell]) + CENTER_POP)
	var lookup: Dictionary = {}
	for cell: Vector2i in arrivals:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var other := cell + direction
			if value(board, other) != value(board, cell):
				continue
			var old: bool = value(before, cell) == value(board, cell) and value(before, other) == value(board, cell)
			var a: float = maxf(0, arrivals[cell])
			var b: float = maxf(0, arrivals[other])
			var finish: float = minf(a, b) + STEP if absf(a - b) >= STEP else (a + b + STEP) / 2.0
			var edge := {"a": cell, "b": other, "color": value(board, cell), "start_a": a, "start_b": b, "finish": 0.0 if old else finish, "old": old}
			edges.append(edge)
			lookup[edge_key(cell, other)] = edge
			if not old:
				duration = maxf(duration, finish + maxf(RIPPLE, STAR_POP))
	for y in range(1, board.size()):
		for x in range(1, board.size()):
			var corner := Vector2i(x, y)
			var color: int = value(board, corner)
			if not is_flower(board, corner, color):
				continue
			var old: bool = is_flower(before, corner, color)
			var around: Array = [corner + Vector2i(-1, -1), corner + Vector2i(0, -1), corner, corner + Vector2i(-1, 0)]
			var start := -100.0 if old else 0.0
			if not old:
				for i in range(4):
					start = maxf(start, lookup[edge_key(around[i], around[(i + 1) % 4])].finish)
				duration = maxf(duration, start + FLOWER_POP)
			flowers[corner] = {"color": color, "start": start, "old": old}
	for corner: Vector2i in flowers:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var other := corner + direction
			if not flowers.has(other) or flowers[corner].color != flowers[other].color:
				continue
			var old: bool = flowers[corner].old and flowers[other].old
			var start: float = -100 if old else maxf(flowers[corner].start, flowers[other].start) + FLOWER_POP * 0.45
			links.append({"a": corner, "b": other, "color": flowers[corner].color, "start": start, "old": old})
			if not old:
				duration = maxf(duration, start + LINK_GROW + STAR_POP)
