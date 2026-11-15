class_name ZenGeometry
extends RefCounted

# Ordinary-cell geometry only. Bits and clockwise orientation match Coral.
const OFFSETS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const PORTS := [92.0, 116.0, 140.0, 164.0]
const SIZE := 256
const SIGMA := 3.2
static var height_cache: Dictionary = {}

static func neighbor_mask(board: Array, cell: Vector2i) -> int:
	if cell.y < 0 or cell.y >= board.size() or cell.x < 0 or cell.x >= board[cell.y].size():
		return 0
	var color: int = board[cell.y][cell.x]
	if color == 0:
		return 0
	var mask := 0
	for d in range(4):
		var other: Vector2i = cell + OFFSETS[d]
		if other.y >= 0 and other.y < board.size() and other.x >= 0 and other.x < board[other.y].size() and board[other.y][other.x] == color:
			mask |= 1 << d
	return mask

static func rotate_mask(mask: int, turns: int) -> int:
	var t := posmod(turns, 4)
	return ((mask << t) | (mask >> (4 - t))) & 15

static func canonical(mask: int) -> Dictionary:
	for source in [0, 1, 5, 3, 11, 15]:
		for turns in range(4):
			if rotate_mask(source, turns) == mask:
				return {"mask": source, "turns": turns}
	return {}

static func bezier(points: PackedVector2Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	for i in range(1, 49):
		var t := i / 48.0
		var u := 1.0 - t
		points.append(a * u * u * u + 3.0 * b * u * u * t + 3.0 * c * u * t * t + d * t * t * t)

static func arc(points: PackedVector2Array, center: Vector2, radius: float, start: float, end: float) -> void:
	for i in range(97):
		var angle := lerpf(start, end, i / 96.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

static func paths(mask: int) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if mask == 0:
		for radius in [28.0, 52.0, 76.0, 100.0]:
			var ring := PackedVector2Array()
			arc(ring, Vector2(128, 128), radius, 0, TAU)
			result.append(ring)
	elif mask == 1 or mask == 5:
		for x: float in PORTS:
			var line := PackedVector2Array()
			var finish := 156 if mask == 1 else SIZE
			for y in range(finish + 1):
				var t := clampf((y - 32.0) / 192.0, 0, 1)
				var wave := 22.0 * sin(TAU * t) * pow(sin(PI * t), 2)
				line.append(Vector2(x + wave, y))
			result.append(line)
	elif mask == 3:
		# A long bend travels around the empty center, following the supplied motif.
		for i in range(4):
			var radius := 40.0 + i * (44.0 / 3.0)
			var entry: float = PORTS[3 - i]
			var exit: float = PORTS[i]
			var line := PackedVector2Array([Vector2(entry, 0), Vector2(entry, 32)])
			bezier(line, line[-1], Vector2(entry, 64), Vector2(128 - radius, 64), Vector2(128 - radius, 128))
			# Follow the lower-left quadrant and leave it horizontally. A half
			# circle ended heading UP, reversing two exit curves into hairpins.
			# Reverse the port order at E so the four continuous rails cannot cross.
			arc(line, Vector2(128, 128), radius, PI, PI / 2)
			bezier(line, line[-1], Vector2(160, 128 + radius), Vector2(192, exit), Vector2(224, exit))
			line.append(Vector2(256, exit))
			result.append(line)
	else:
		# Review geometry: nested arches for T, nested circulation for cross.
		# Centers are intentionally empty for the next stage's stone overlays.
		for i in range(4):
			var radius := 40.0 + i * (44.0 / 3.0)
			var line := PackedVector2Array()
			if mask == 11:
				var port: float = PORTS[i]
				line.append(Vector2(0, port))
				line.append(Vector2(32, port))
				bezier(line, line[-1], Vector2(64, port), Vector2(128 - radius, 156), Vector2(128 - radius, 128))
				arc(line, Vector2(128, 128), radius, PI, TAU)
				bezier(line, line[-1], Vector2(128 + radius, 156), Vector2(192, port), Vector2(224, port))
				line.append(Vector2(256, port))
			else:
				arc(line, Vector2(128, 128), radius, 0, TAU)
			result.append(line)
		for direction in range(4):
			if not mask & (1 << direction):
				continue
			for i in range(4):
				var port: float = PORTS[i]
				# Feeders meet the outer circulation line at its first intersection.
				# Crossing the inner rings would leave a distracting ladder of cuts.
				var radius := 84.0
				var end_y := 128.0 - sqrt(radius * radius - (port - 128.0) * (port - 128.0))
				var feeder := PackedVector2Array([Vector2(port, 0), Vector2(port, 32), Vector2(port, end_y)])
				# T already has its exact E/W ports in its arches.
				if mask == 11 and direction != 0:
					continue
				for j in range(feeder.size()):
					feeder[j] = Vector2(128, 128) + (feeder[j] - Vector2(128, 128)).rotated(direction * PI / 2)
				result.append(feeder)
	return result

static func height_image(mask: int) -> Image:
	if height_cache.has(mask):
		return height_cache[mask]
	var heights := PackedFloat32Array()
	heights.resize(SIZE * SIZE)
	heights.fill(1.0)
	for line: PackedVector2Array in paths(mask):
		for i in range(1, line.size()):
			var a := line[i - 1]
			var b := line[i]
			var delta := b - a
			var length_squared := delta.length_squared()
			if length_squared < 0.00001:
				continue
			for y in range(maxi(0, floori(minf(a.y, b.y) - 10)), mini(SIZE, ceili(maxf(a.y, b.y) + 10))):
				for x in range(maxi(0, floori(minf(a.x, b.x) - 10)), mini(SIZE, ceili(maxf(a.x, b.x) + 10))):
					var p := Vector2(x + 0.5, y + 0.5)
					var closest := a + delta * clampf((p - a).dot(delta) / length_squared, 0, 1)
					var d2 := p.distance_squared_to(closest)
					var height := 1.0 - exp(-d2 / (2 * SIGMA * SIGMA))
					var index := y * SIZE + x
					heights[index] = minf(heights[index], height)
	# Freeze the last 32 px to the common cross-section. Interior construction
	# can change during review without introducing port shape or slope mismatch.
	for y in range(SIZE):
		for x in range(SIZE):
			var distance_to_port := INF
			if mask & 1 and y < 32 or mask & 4 and y >= SIZE - 32:
				for port: float in PORTS:
					distance_to_port = minf(distance_to_port, absf(x + 0.5 - port))
			if mask & 2 and x >= SIZE - 32 or mask & 8 and x < 32:
				for port: float in PORTS:
					distance_to_port = minf(distance_to_port, absf(y + 0.5 - port))
			if distance_to_port != INF:
				heights[y * SIZE + x] = 1.0 - exp(-distance_to_port * distance_to_port / (2 * SIGMA * SIGMA))
	var image := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RF, heights.to_byte_array())
	height_cache[mask] = image
	return image
