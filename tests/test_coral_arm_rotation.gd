extends SceneTree

const Coral = preload("res://scripts/coral_growth.gd")
const Visuals = preload("res://scripts/coral_visuals.gd")
const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func viewport() -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(512, 512)
	view.transparent_bg = true
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	return view

func rotated_texture(source: Texture2D, turns: int) -> Texture2D:
	var pixels: Image = source.get_image()
	for i in range(turns): pixels.rotate_90(CLOCKWISE)
	return ImageTexture.create_from_image(pixels)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var spec: Dictionary = Coral.specification()
	var center := Vector2i(4, 4)
	for family: String in ["arm", "junction"]:
		var canonical: String = "arm_n" if family == "arm" else "junction_ne"
		var directions: Array = Coral.DIR_NAMES if family == "arm" else ["ne", "es", "sw", "wn"]
		for color in [1, 2]:
			var variant: String = "salmon" if color == 1 else "turquoise"
			var grid: Array = Rules.empty_board(9)
			grid[4][4] = color
			for delta: Vector2i in Coral.OFFSETS:
				grid[4 + delta.y][4 + delta.x] = color
			for turns in range(4):
				var id: String = family + "_" + str(directions[turns])
				var meta: Dictionary = spec.components[id]
				check(meta.artwork[variant] == "artwork/%s/%s.png" % [variant, canonical], "every direction uses the one canonical image for its color")
				check(meta.reveal_mask == "masks/%s.png" % (canonical if family == "arm" else id) and meta.animation.mask == meta.reveal_mask, "arms share a field while junctions retain their original directional fields")
				check(meta.artwork_rotation_clockwise == turns * 90, "manifest supplies the correct clockwise orientation")
				var model = Coral.new()
				model.build(Rules.empty_board(9), grid)
				var layer = Visuals.new()
				var current: SubViewport
				if DisplayServer.get_name() == "headless": root.add_child(layer)
				else:
					current = viewport()
					current.add_child(layer)
				layer.reconcile(model, false, false)
				var identity: String = Coral.key(id, color, center)
				var event: Dictionary = model.components[identity]
				var sprite: Sprite2D = layer.registry[identity]
				check(sprite.texture == Visuals.texture(spec.components[canonical].artwork[variant]), "all directional sprites share the same loaded texture resource")
				check(is_equal_approx(sprite.rotation, turns * PI / 2), "sprite rotates artwork and growth mask together")
				check(sprite.material.get_shader_parameter("growth_mask") == Visuals.texture(meta.reveal_mask), "animated sprites use the declared shared or directional mask")
				check(is_equal_approx(event.stroke, 0.1 if family == "arm" else 0.12) and event.two_fronts == (family == "arm"), "original growth timing and front count are preserved")
				if DisplayServer.get_name() != "headless":
					for item: Sprite2D in layer.registry.values(): item.visible = item == sprite
					layer.position = Vector2(256, 256) - event.center * 256
					var reference := viewport()
					var expected := Sprite2D.new()
					expected.position = Vector2(256, 256)
					expected.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
					expected.texture = rotated_texture(sprite.texture, turns)
					var mask: Texture2D = rotated_texture(Visuals.texture(meta.reveal_mask), turns) if family == "arm" else Visuals.texture(meta.reveal_mask)
					reference.add_child(expected)
					for clock: float in [event.start + 0.02, event.start + 0.06, event.end + 0.01]:
						layer.advance(clock)
						expected.material = null if sprite.material == null else sprite.material.duplicate()
						if expected.material != null:
							expected.material.set_shader_parameter("artwork", expected.texture)
							expected.material.set_shader_parameter("growth_mask", mask)
							expected.material.set_shader_parameter("growth_mask_rotation_radians", 0.0)
						await process_frame
						await RenderingServer.frame_post_draw
						var actual_pixels: PackedByteArray = current.get_texture().get_image().get_data()
						var expected_pixels: PackedByteArray = reference.get_texture().get_image().get_data()
						var difference := 0
						if actual_pixels != expected_pixels:
							for i in range(actual_pixels.size()):
								difference = maxi(difference, absi(int(actual_pixels[i]) - int(expected_pixels[i])))
						check(difference <= 1, "runtime rotation matches pre-rotated artwork/mask within one 8-bit level: %s/%s at %.3f (max %d)" % [variant, id, clock, difference])
					current.queue_free()
					reference.queue_free()
				else: layer.queue_free()
				await process_frame
	print("Coral arm/junction rotation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
