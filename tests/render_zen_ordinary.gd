extends SceneTree

const SCENE = preload("res://prototypes/zen_garden/ordinary_tiles.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(720, 1100)
	var scene = SCENE.instantiate()
	root.add_child(scene)
	# Exercise the actual review controls, not just the drawing methods.
	var buttons: Dictionary = {}
	for child: Node in scene.get_children():
		if child is Button: buttons[child.text] = child
	buttons["Stepping stones"].pressed.emit()
	assert(scene.family == 1)
	buttons["Mixed"].pressed.emit()
	assert(scene.family == 2)
	buttons["Raked sand"].pressed.emit()
	assert(scene.family == 0)
	buttons["Rotate layout"].pressed.emit()
	assert(scene.turn == 1)
	buttons["Move light"].pressed.emit()
	assert(scene.light_turn == 1)
	buttons["9 × 9 / 11 × 11"].pressed.emit()
	assert(scene.board_size == 11)
	buttons["All 16 shapes / field"].pressed.emit()
	assert(scene.atlas)
	buttons["Lighting on / off"].pressed.emit()
	assert(not scene.lighting)
	scene.turn = 0
	scene.light_turn = 0
	scene.board_size = 9
	scene.lighting = true
	DirAccess.make_dir_recursive_absolute("res://build/zen-review")
	for mode in range(3):
		scene.family = mode
		scene.atlas = false
		scene.rebuild()
		await capture("field-%d" % mode)
		scene.atlas = true
		scene.rebuild()
		await capture("shapes-%d" % mode)
	scene.family = 0
	scene.atlas = false
	scene.board_size = 11
	scene.rebuild()
	await capture("sand-11")
	scene.board_size = 9
	for rotation in range(4):
		scene.turn = rotation
		scene.atlas = false
		scene.rebuild()
		await capture("sand-turn-%d" % rotation)
		scene.atlas = true
		scene.rebuild()
		await capture("shapes-turn-%d" % rotation)
	scene.atlas = false
	scene.rebuild()
	for light in range(4):
		scene.light_turn = light
		scene.update_light()
		await capture("light-%d" % light)
	scene.lighting = false
	scene.update_light()
	await capture("unlit")
	scene.family = 2
	scene.turn = 0
	scene.light_turn = 0
	scene.lighting = true
	scene.rebuild()
	root.content_scale_size = Vector2i(720, 1100)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(540, 825)
	await capture("phone-mixed")
	print("Zen review: fields, 16 shapes, 9/11 sizes, rotations and lighting rendered")
	quit()

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://build/zen-review/%s.png" % name)
	if error != OK:
		push_error("Could not write Zen review " + name)
		quit(1)
