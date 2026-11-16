extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Model = preload("res://scripts/zen_growth.gd")
const Visuals = preload("res://scripts/zen_visuals.gd")
const Trees = preload("res://scripts/zen_trees.gd")
const Board = preload("res://scripts/board_view.gd")
const Palette = preload("res://scripts/palette.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func block(w: int, h: int, color: int = 1, origin := Vector2i(2, 2)) -> Array:
	var board := Rules.empty_board(9)
	for y in range(h):
		for x in range(w): board[y + origin.y][x + origin.x] = color
	return board
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	Palette.select_theme("zen_garden")
	var model := Model.new()
	var visuals := Visuals.new()
	root.add_child(visuals)
	for color in [1, 2]:
		for size in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]:
			var grid := block(size.x, size.y, color)
			model.build(grid, grid)
			visuals.reconcile(model, true)
			check(model.groves.size() == (1 if color == 1 and size != Vector2i(2, 2) else 0), "Only connected rake formations trigger trees, including both 2x3 orientations")
	var initial := block(3, 2)
	var expanded := block(4, 2)
	model.build(initial, initial)
	visuals.trees.reset(4)
	visuals.reconcile(model, true)
	var trees = visuals.trees
	check(trees.season == "spring", "Game snapshot selects spring from local month")
	check(trees.groups[0].center == Vector2(3.5, 3.0) * 256 and trees.groups[0].cells.size() == 6, "Centroid counts each occupied square once, not overlapping 2x2s twice")
	var old_trunk: Node = trees.trunks.values()[0].node
	var old_trunk_id := old_trunk.get_instance_id()
	var old_thickness: float = old_trunk.thickness
	var old_center: Vector2 = old_trunk.position
	var original: Dictionary = {}
	for id: int in trees.branches:
		var node: Sprite2D = trees.branches[id].node
		original[id] = {"id": node.get_instance_id(), "transform": node.transform, "texture": node.texture}
	var old_signature: String = trees.appearance_signature()
	model.build(initial, expanded)
	visuals.reconcile(model, false)
	check(trees.season == "spring", "Season stays frozen on expansion")
	check(trees.trunks.size() == 1 and trees.trunks.values()[0].node.get_instance_id() != old_trunk_id and old_trunk.get_parent() == null, "Expansion deletes the previous trunk")
	var trunk: Node = trees.trunks.values()[0].node
	check(trunk.position == Vector2(4, 3) * 256 and trunk.thickness > old_thickness, "Replacement trunk grows thicker at the recalculated centroid")
	check(trunk.progress == 0, "New trunk starts growing rather than appearing fully formed")
	var bridges := 0
	for spec: Dictionary in trees.groups[0].branches:
		if original.has(spec.id):
			var node: Sprite2D = trees.branches[spec.id].node
			check(node.get_instance_id() == original[spec.id].id and node.transform == original[spec.id].transform and node.texture == original[spec.id].texture, "Existing branches remain fixed, including their original artwork")
			check(node.material.get_shader_parameter("progress") == 1, "Established branches never fade or restart")
		elif spec.bridge:
			bridges += 1
			check(Vector2.RIGHT.rotated(spec.angle).dot((old_center - trunk.position).normalized()) > 0.90, "Large transition branches point toward the old trunk with an organic spread")
			check(spec.length >= 307.2 and spec.root == trunk.position, "Transition branches are larger and rooted at the new trunk")
	check(bridges in [2, 3], "Expansion adds two or three larger bridging branches")
	visuals.advance(model.duration)
	check(trunk.progress == 1 and trees.branches.values().all(func(item): return item.node.material.get_shader_parameter("progress") == 1), "Growth clock includes trunk and every new branch")
	var clone := Visuals.new()
	root.add_child(clone)
	model.build(expanded, expanded)
	clone.reconcile(model, true)
	clone.copy_landmark_order(visuals)
	check(clone.trees.appearance_signature() == trees.appearance_signature() and clone.trees.season == trees.season, "Gallery copies historical branch geometry and frozen season")
	for id: int in trees.branches:
		check(clone.trees.branches[id].node.transform == trees.branches[id].node.transform, "Gallery keeps the exact original branch transforms")
	clone.queue_free()
	model.build(initial, initial)
	visuals.reconcile(model, true)
	check(trees.appearance_signature() == old_signature and trees.trunks.values()[0].node.position == old_center, "Undo restores the original trunk and historical canopy")
	for id: int in original:
		check(trees.branches[id].node.get_instance_id() == original[id].id, "Undo preserves the surviving branch nodes")
	var erased := initial.duplicate(true)
	erased[2][2] = 0
	model.build(erased, erased)
	visuals.reconcile(model, true)
	check(trees.groups.is_empty() and trees.trunks.is_empty() and trees.branches.is_empty(), "Erase removes a tree when fewer than two rake formations remain")
	# An independent grove does not move or thicken an established trunk.
	var two := block(3, 2, 1, Vector2i(0, 0))
	for y in range(6, 8):
		for x in range(5, 8): two[y][x] = 1
	model.build(two, two)
	visuals.reconcile(model, true)
	check(trees.groups.size() == 2 and trees.trunks.size() == 2, "Independent connected rake territories have independent trees")
	var second: Dictionary = trees.groups[1]
	var steady: Node = trees.trunks[second.trunk_id].node
	var steady_id := steady.get_instance_id()
	var steady_thickness: float = steady.thickness
	var next := two.duplicate(true)
	next[0][3] = 1
	next[1][3] = 1
	model.build(two, next)
	visuals.reconcile(model, true)
	check(trees.trunks.has(second.trunk_id) and trees.trunks[second.trunk_id].node.get_instance_id() == steady_id and steady.thickness == steady_thickness, "Growing another grove leaves an independent trunk unchanged")
	# Merging territories preserves both sets of branches and replaces both hubs.
	var split := block(3, 2, 1, Vector2i(0, 2))
	for y in range(2, 4):
		for x in range(4, 7): split[y][x] = 1
	trees.reset(7)
	model.build(split, split)
	visuals.reconcile(model, true)
	var fixed: Dictionary = {}
	for id: int in trees.branches: fixed[id] = trees.branches[id].node.transform
	var former_trunks: Array = trees.trunks.keys()
	var joined := split.duplicate(true)
	joined[2][3] = 1
	joined[3][3] = 1
	model.build(split, joined)
	visuals.reconcile(model, false)
	check(trees.groups.size() == 1 and trees.trunks.size() == 1 and former_trunks.all(func(id): return not trees.trunks.has(id)), "Merging groves replaces both old trunks with one new hub")
	check(trees.groups[0].center.is_equal_approx(Vector2(3.5, 3.0) * 256), "Merged trunk uses the centroid of the entire connected territory")
	for id: int in fixed: check(trees.branches.has(id) and trees.branches[id].node.transform == fixed[id], "Merging never moves either established canopy")
	for month in range(1, 13):
		var expected: String = "winter" if month in [12, 1, 2] else ("spring" if month < 6 else ("summer" if month < 9 else "autumn"))
		check(Trees.season_for_month(month) == expected, "All local months map to the agreed seasons")
	visuals.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless": await check_game(initial, expanded)
	print("Zen trees: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func frames() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func check_game(initial: Array, expanded: Array) -> void:
	root.size = Vector2i(540, 825)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://build/zen-trees")
	for month in [4, 7, 10, 1]:
		scene._reset()
		scene.board_view.zen_visuals.trees.reset(month)
		scene.game.board = initial
		scene.board_view.show_settled(initial)
		scene._refresh()
		var before: Dictionary = scene.board_view.zen_visuals.trees.snapshot()
		await frames()
		var label: String = scene.board_view.zen_visuals.trees.season
		root.get_texture().get_image().save_png("res://build/zen-trees/%s-first.png" % label)
		scene.game.board = expanded
		scene.board_view.animate_growth(initial, expanded)
		scene.board_view.set_process(false)
		scene._refresh()
		check(scene.board_view.growing, "Actual game gates placement during tree expansion")
		var trees = scene.board_view.zen_visuals.trees
		check(trees.season == label and trees.groups[0].center == Vector2(4, 3) * 256, "Actual game keeps the season and recalculates the center")
		scene.board_view.advance_growth(100)
		await frames()
		root.get_texture().get_image().save_png("res://build/zen-trees/%s-expanded.png" % label)
		check(not scene.board_view.growing, "Actual tree growth unlocks Place when complete")
		var symmetric := block(3, 3, 1, Vector2i(3, 3))
		scene.game.board = symmetric
		scene.board_view.show_settled(symmetric)
		scene._refresh()
		scene.gallery.directory = "user://zen-trees-%s-%d" % [label, Time.get_ticks_usec()]
		var fingerprint: String = trees.appearance_signature()
		await scene._save_design()
		check(scene.gallery.entries().size() == 1 and fingerprint == trees.appearance_signature(), "Gallery save preserves the live historical tree")
		if not scene.gallery.entries().is_empty():
			var picture: Image = scene.gallery.picture(scene.gallery.entries()[0]).get_image()
			picture.save_png("res://build/zen-trees/%s-saved.png" % label)
			var reference := SubViewport.new()
			reference.size = Vector2i(900, 900)
			reference.disable_3d = true
			reference.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(reference)
			var clean := Board.new()
			clean.size = Vector2(900, 900)
			clean.complete_background = true
			clean.show_guides = false
			reference.add_child(clean)
			clean.show_settled(symmetric)
			clean.zen_visuals.copy_landmark_order(scene.board_view.zen_visuals)
			await frames()
			check(picture.get_data() == reference.get_texture().get_image().get_data(), "Saved pixels reproduce the live historical canopy and frozen season exactly")
			reference.queue_free()
		if DirAccess.dir_exists_absolute(scene.gallery.directory):
			for file: String in DirAccess.open(scene.gallery.directory).get_files(): DirAccess.remove_absolute(scene.gallery.directory.path_join(file))
			DirAccess.remove_absolute(scene.gallery.directory)
	scene._reset()
	check(scene.board_view.zen_visuals.trees.groups.is_empty() and scene.board_view.zen_visuals.trees.snapshots.is_empty(), "New game resets the canopy history")
	var before := block(3, 2)
	before[2][4] = 0
	scene.game.board = before
	scene.game.queue[scene.game.index] = "Dot"
	scene.game.current_color = 1
	scene.cells = [Vector2i.ZERO]
	scene.selected = Vector2i(4, 2)
	scene.has_hover = true
	scene.game._refresh_over()
	scene.board_view.show_settled(before)
	scene._refresh()
	scene._place()
	check(scene.game.moves == 1 and scene.board_view.growing and scene.board_view.zen_visuals.trees.groups.size() == 1, "Actual Place triggers the third-tier rake tree")
	scene.board_view.set_process(false)
	scene.board_view.advance_growth(100)
	scene._undo()
	check(scene.board_view.zen_visuals.trees.groups.is_empty(), "Actual Undo removes unsupported tree growth")
	scene.game.board = block(3, 2)
	scene.board_view.show_settled(scene.game.board)
	scene._refresh()
	scene._erase(Vector2i(2, 2))
	check(scene.board_view.zen_visuals.trees.groups.is_empty(), "Actual Erase removes unsupported tree growth")
	scene.queue_free()
	await process_frame
