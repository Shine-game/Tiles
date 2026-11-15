extends SceneTree

const Geometry = preload("res://scripts/zen_geometry.gd")
const Platform = preload("res://scripts/occupied_platform.gd")
const Prototype = preload("res://prototypes/zen_garden/ordinary_tiles.gd")
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
		var a: Image = Prototype.STONES[pair[0]].get_image()
		var b: Image = Prototype.STONES[pair[1]].get_image()
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
