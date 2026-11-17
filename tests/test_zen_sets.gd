extends SceneTree
const Sets = preload("res://scripts/zen_sets.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Renderer = preload("res://scripts/pattern/component_renderer.gd")
const Geometry = preload("res://scripts/zen_geometry.gd")
const Visuals = preload("res://scripts/zen_visuals.gd")
const Model = preload("res://scripts/zen_growth.gd")
const Rules = preload("res://scripts/rules.gd")
const ART := "res://art/themes/zen_garden/artwork/"
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	Sets.install()
	for family: Array in Sets.families.values():
		for tier in [0, 1]: check(family[tier].ok and family[tier].definition.tier == tier, "Both families load their own real Tier 0/1 sets")
	var core := Assets.texture(ART + "cores/raked_sand_core_relief_256.res")
	var endpoint := Assets.texture(ART + "centers/raked_sand_endpoint_relief_256.res")
	check(core != endpoint and core.get_image().get_data() == endpoint.get_image().get_data(), "Endpoint rake core is a separately editable exact Tier 0 copy")
	check(core.get_image().get_data() == Geometry.height_image(0).get_data(), "Serialized Tier 0 relief preserves every original float without quantization")
	check(FileAccess.get_file_as_bytes(ART + "cores/stepping_stone_core_256.png") == FileAccess.get_file_as_bytes(ART + "centers/stepping_stone_endpoint_core_256.png"), "Endpoint stone PNG is an exact source-file copy")
	var not_a_texture := Resource.new()
	DirAccess.make_dir_recursive_absolute("res://build/zen-sets")
	ResourceSaver.save(not_a_texture, "res://build/zen-sets/not-a-texture.res")
	check(not Assets.validate("res://build/zen-sets/not-a-texture.res").is_empty(), "Texture loading rejects a serialized non-texture resource")
	DirAccess.remove_absolute("res://build/zen-sets/not-a-texture.res")
	var visuals := Visuals.new()
	root.add_child(visuals)
	var model := Model.new()
	for color in [1, 2]:
		for mask in range(16):
			var grid := Rules.empty_board(9)
			grid[4][4] = color
			for d in range(4):
				if mask & (1 << d):
					var p: Vector2i = Vector2i(4, 4) + Geometry.OFFSETS[d]
					grid[p.y][p.x] = color
			model.build(grid, grid)
			visuals.reconcile(model, true)
			var group: Node = visuals.registry[Vector2i(4, 4)]
			var shape: String = Geometry.Topology.shape(mask)
			if color == 1:
				var sprite: Sprite2D = group.get_child(1)
				var canonical := Geometry.canonical(mask)
				var image: Image = sprite.texture.get_image().duplicate()
				check(is_equal_approx(sprite.rotation, canonical.turns * PI / 2) and sprite.position == Vector2(4.5, 4.5) * 256 and group.get_child_count() == 2, "Rakes use one canonical relief and the correct rotation")
				if shape != "endpoint":
					check(image.get_data() == Geometry.height_image(canonical.mask).get_data(), "Non-endpoint rake geometry remains unchanged")
				else:
					var core_values := core.get_image().get_data().to_float32_array()
					var ending_values := Geometry.height_image(1).get_data().to_float32_array()
					var values := image.get_data().to_float32_array()
					var correct := true
					for i in range(values.size()):
						var expected: float = ending_values[i] if i < 32 * 256 else minf(core_values[i], ending_values[i])
						if values[i] != expected: correct = false
					check(correct, "Endpoint overlaps the copied core and ending without erasing either relief")
					for i in range(canonical.turns): image.rotate_90(CLOCKWISE)
					var d: int = [1, 2, 4, 8].find(mask)
					var edge_ok := true
					for inset in range(32):
						for along in range(256):
							var p: Vector2i = [Vector2i(along, inset), Vector2i(255 - inset, along), Vector2i(along, 255 - inset), Vector2i(inset, along)][d]
							if image.get_pixelv(p).r != Geometry.height_image(1).get_pixel(along, inset).r: edge_ok = false
					check(edge_ok, "Every rotated endpoint retains the exact incoming groove profile and normal slope")
				var center := Sets.center_spec(Vector2i(4, 4), mask)
				check(visuals.centerpieces.has(Vector2i(4, 4)) == not center.is_empty(), "Only configured branching rake roles receive the stone/cairn/bamboo node")
				if not center.is_empty(): check(visuals.ordinary_components.nodes["center/4/4"] == visuals.centerpieces[Vector2i(4, 4)], "Common renderer owns the persistent staged centerpiece")
			else:
				var bits := 0
				for d in range(4):
					if mask & (1 << d): bits += 1
				check(group.get_child_count() == 1 + maxi(1, bits) + int(shape == "endpoint"), "Stone endpoints layer their extra core below the one path ending")
				if shape == "endpoint":
					var below: Sprite2D = group.get_child(1)
					var above: Sprite2D = group.get_child(2)
					check(below.texture == Assets.texture(ART + "centers/stepping_stone_endpoint_core_256.png"), "The live endpoint uses its new independently named PNG")
					check(below.position == Vector2(4.5, 4.5) * 256 and below.scale == Vector2.ONE * 0.70, "Endpoint core matches isolated core size and center")
					var d: int = [1, 2, 4, 8].find(mask)
					var opposite := Visuals.stone_sprite(Vector2i(4, 4) + Geometry.OFFSETS[d], (d + 2) % 4)
					check(above.position == opposite.position and above.scale == opposite.scale and above.offset == opposite.offset and above.flip_h != opposite.flip_h, "Both path halves still share their boundary anchor")
					opposite.free()
	var before := Rules.empty_board(9)
	before[4][4] = 2
	before[4][3] = 2
	var after := before.duplicate(true)
	after[4][5] = 2
	model.build(before, after)
	visuals.reconcile(model, false)
	check(visuals.registry[Vector2i(4, 4)].get_child_count() == 3, "Extending an endpoint into a straight removes its copied core")
	model.build(after, before)
	visuals.reconcile(model, false)
	check(visuals.registry[Vector2i(4, 4)].get_child(1).texture == Assets.texture(ART + "centers/stepping_stone_endpoint_core_256.png"), "Helper restoration selects the endpoint file again")
	var added := Rules.empty_board(9)
	model.build(added, before)
	visuals.reconcile(model, false)
	var group: Node = visuals.registry[Vector2i(4, 4)]
	check(group.get_child(1).modulate.a == 0 and group.get_child(2).modulate.a == 0, "New core and ending share the ordinary arrival fade")
	visuals.advance(100)
	check(group.get_child(1).modulate.a == 1 and group.get_child(2).modulate.a == 1 and visuals.pending.is_empty(), "Endpoint layers settle together and release the growth gate")
	var exports := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(exports.contains("art/themes/zen_garden/sets/*.json"), "Production Zen sets are packaged for Android")
	check(preload("res://scripts/palette.gd").theme_version() == "0.12", "The new endpoint appearance has a distinct gallery version")
	visuals.clear()
	check(visuals.ordinary_components.nodes.is_empty(), "Full reset clears shared centerpiece ownership")
	visuals.queue_free()
	await process_frame
	print("Zen sets: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
