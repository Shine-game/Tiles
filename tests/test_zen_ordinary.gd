extends SceneTree

const Geometry = preload("res://scripts/zen_geometry.gd")
const Platform = preload("res://scripts/occupied_platform.gd")
const Visuals = preload("res://scripts/zen_visuals.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func edge_pixel(direction: int, along: int, inset: int = 0) -> Vector2i:
	return [Vector2i(along, inset), Vector2i(255 - inset, along), Vector2i(along, 255 - inset), Vector2i(inset, along)][direction]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var started := Time.get_ticks_msec()
	# A T has four ordered arches and four stem branches. Branches must meet
	# the outer arch along its tangent, rather than stopping perpendicular to it.
	var junction: Array[PackedVector2Array] = Geometry.paths(11)
	check(junction.size() == 8, "T contains four arches and four stem routes")
	for turn in range(4):
		var rotated: Array[PackedVector2Array] = []
		for source: PackedVector2Array in junction:
			var line := PackedVector2Array()
			for p: Vector2 in source: line.append(Vector2(128, 128) + (p - Vector2(128, 128)).rotated(turn * PI / 2))
			rotated.append(line)
		for i in range(8):
			var line := rotated[i]
			var largest_turn := 0.0
			for j in range(1, line.size() - 1):
				largest_turn = maxf(largest_turn, absf((line[j] - line[j - 1]).angle_to(line[j + 1] - line[j])))
			check(largest_turn < deg_to_rad(15), "T route %d has no sharp internal turns at rotation %d" % [i, turn])
			if i >= 4:
				var targets := [25, 40, 58, 73]
				var target: int = targets[i - 4]
				var outer := rotated[0]
				check(line[-1].distance_to(outer[target]) < 0.001, "T stem reaches an exact point on its arch")
				var along_arch: Vector2 = outer[target + (-1 if i < 6 else 1)] - outer[target]
				check(absf((line[-1] - line[-2]).angle_to(along_arch)) < deg_to_rad(5), "T stem merges along the arch tangent in every rotation")
	for i in range(4):
		var line := junction[i]
		var monotone := true
		for j in range(1, line.size()):
			if line[j].x < line[j - 1].x: monotone = false
		check(monotone, "T arch cannot double back")
		for j in range(i + 1, 4):
			var crossing := false
			for a in range(line.size() - 1):
				for b in range(junction[j].size() - 1):
					if Geometry2D.segment_intersects_segment(line[a], line[a + 1], junction[j][b], junction[j][b + 1]) != null: crossing = true
			check(not crossing, "T arches preserve groove order without crossing")
	# Edge profiles alone did not catch the original bend's interior hairpins.
	# Check the actual routes: no reversals, no self-crossings, and four separate
	# grooves all the way from the north port to the east port.
	var bends: Array[PackedVector2Array] = []
	for raw: PackedVector2Array in Geometry.paths(3):
		var line := PackedVector2Array()
		for p: Vector2 in raw:
			if line.is_empty() or line[-1].distance_to(p) > 0.001: line.append(p)
		bends.append(line)
	for i in range(bends.size()):
		var line := bends[i]
		var largest_turn := 0.0
		var self_crossing := false
		for j in range(1, line.size() - 1):
			largest_turn = maxf(largest_turn, absf((line[j] - line[j - 1]).angle_to(line[j + 1] - line[j])))
		for a in range(line.size() - 1):
			for b in range(a + 2, line.size() - 1):
				if Geometry2D.segment_intersects_segment(line[a], line[a + 1], line[b], line[b + 1]) != null: self_crossing = true
		check(largest_turn < deg_to_rad(15), "Bend groove %d has smooth internal joins without hairpins" % i)
		check(not self_crossing, "Bend groove %d never crosses itself" % i)
		check(line[0] == Vector2(Geometry.PORTS[3 - i], 0) and line[-1] == Vector2(256, Geometry.PORTS[i]), "Bend pairs opposite port orders to preserve groove ordering")
		for j in range(i + 1, bends.size()):
			var crossing := false
			var other := bends[j]
			for a in range(line.size() - 1):
				for b in range(other.size() - 1):
					if Geometry2D.segment_intersects_segment(line[a], line[a + 1], other[b], other[b + 1]) != null: crossing = true
			check(not crossing, "Bend grooves %d and %d stay separate" % [i, j])
	for mask in range(16):
		var spec: Dictionary = Geometry.canonical(mask)
		check(Geometry.rotate_mask(spec.mask, spec.turns) == mask, "Canonical rotation reproduces mask %d" % mask)
		for turns in range(4):
			check(Geometry.rotate_mask(Geometry.rotate_mask(mask, turns), 4 - turns) == mask, "Rotation is invertible")
		var image: Image = Geometry.height_image(spec.mask).duplicate()
		for i in range(spec.turns): image.rotate_90(CLOCKWISE)
		for direction in range(4):
			var expected_active: bool = mask & (1 << direction) != 0
			var max_error := 0.0
			var slope_error := 0.0
			for along in range(256):
				var distance := INF
				for port: float in Geometry.PORTS: distance = minf(distance, absf(along + 0.5 - port))
				var expected := 1.0 - exp(-distance * distance / (2 * Geometry.SIGMA * Geometry.SIGMA)) if expected_active else 1.0
				for inset in range(32):
					var p := edge_pixel(direction, along, inset)
					var value := image.get_pixelv(p).r
					if expected_active or inset == 0: max_error = maxf(max_error, absf(value - expected))
					if expected_active: slope_error = maxf(slope_error, absf(value - image.get_pixelv(edge_pixel(direction, along)).r))
			check(max_error < 0.000001, "Mask %d edge %d: exact active profile or clear inactive boundary" % [mask, direction])
			check(slope_error < 0.000001, "Mask %d edge %d: zero normal slope throughout final 32 pixels" % [mask, direction])
		for value: float in image.get_data().to_float32_array():
			if is_nan(value) or is_inf(value) or value < 0 or value > 1:
				check(false, "Height fields stay finite and normalized")
	for pair in [[0, 2], [1, 3]]:
		var a: Image = Visuals.STONES[pair[0]].get_image()
		var b: Image = Visuals.STONES[pair[1]].get_image()
		var error := 0.0
		var rgb_error := 0.0
		for along in range(256):
			var left := a.get_pixelv(edge_pixel(pair[0], along))
			var right := b.get_pixelv(edge_pixel(pair[1], along))
			error = maxf(error, absf(left.a - right.a))
			if left.a > 0.5 and right.a > 0.5:
				rgb_error = maxf(rgb_error, maxf(absf(left.r - right.r), maxf(absf(left.g - right.g), absf(left.b - right.b))))
		check(error == 0, "Supplied opposing stone halves join with identical alpha")
		check(rgb_error == 0, "Supplied opposing stone halves join with identical visible RGB")
	for d in range(4):
		var cell := Vector2i(2, 2)
		var first := Visuals.stone_sprite(cell, d)
		var other := Visuals.stone_sprite(cell + Geometry.OFFSETS[d], (d + 2) % 4)
		check(first.scale == Vector2.ONE * 0.70 and other.scale == first.scale, "Stepping-stone halves are thirty percent smaller")
		var max_gap := 0.0
		for along in range(257):
			var a: Vector2 = [Vector2(along, 0), Vector2(256, along), Vector2(along, 256), Vector2(0, along)][d]
			var b: Vector2 = [Vector2(along, 0), Vector2(256, along), Vector2(along, 256), Vector2(0, along)][(d + 2) % 4]
			var actual_a: Vector2 = first.transform * (a - Vector2.ONE * 128 + first.offset)
			var actual_b: Vector2 = other.transform * (b - Vector2.ONE * 128 + other.offset)
			max_gap = maxf(max_gap, actual_a.distance_to(actual_b))
		check(max_gap < 0.0001, "All points along both shrunken halves coincide on their shared border")
		var port: Vector2 = (Vector2(cell) + Vector2.ONE * 0.5 + Vector2(Geometry.OFFSETS[d]) * 0.5) * 256
		check(first.position.is_equal_approx(port) and other.position.is_equal_approx(port), "The seam midpoint stays anchored to the logical cell boundary")
		first.free()
		other.free()
	var isolated := Visuals.stone_sprite(Vector2i(2, 2))
	check(isolated.scale == Vector2.ONE * 0.70 and isolated.offset == Vector2.ZERO and isolated.position == Vector2(640, 640), "An isolated stone shrinks around its original center")
	isolated.free()
	check(Geometry.neighbor_mask([[1, 2], [1, 0]], Vector2i.ZERO) == 4, "Different colors touch without a decorative connection")
	check(Geometry.neighbor_mask([[0, 1], [1, 0]], Vector2i.ZERO) == 0, "An empty cell cannot connect")
	check(Geometry.neighbor_mask([[1, 0], [0, 1]], Vector2i.ZERO) == 0, "Diagonal contact cannot connect")
	var slab := Platform.new()
	root.add_child(slab)
	slab.sync([[1, 2], [0, 1]])
	slab.configure(Vector2.ZERO, 60, Color.WHITE, false, 4.0, false)
	check(slab.depth_pixels == 4.0 and slab.material.get_shader_parameter("metal_mode") == false, "Zen fixed lip has no Clockwork metal material")
	check(slab.filled(Vector2(1.5, 0.5)), "Both colors share the occupied union")
	slab.configure(Vector2.ZERO, 60, Color.WHITE, false, 4.0)
	check(slab.material.get_shader_parameter("metal_mode") == true, "Existing fixed-depth callers retain Clockwork styling")
	slab.queue_free()
	print("Zen ordinary tiles: %d checks, %d failures; geometry generated in %.2fs" % [checks, failures, (Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if failures else 0)
