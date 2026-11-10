extends SceneTree

const Gallery = preload("res://scripts/gallery.gd")
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Palette.select_theme("vines")
	var gallery = Gallery.new()
	gallery.directory = "user://gallery-test-%d" % Time.get_ticks_usec()
	check(gallery.entries().is_empty(), "missing gallery is empty")
	var board: Array = Rules.create_board(9)
	check(not gallery.save_design(board, 0, null).ok, "failed capture does not save a broken entry")
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color("ff3988"))
	var saved: Dictionary = gallery.save_design(board, 0, image)
	check(saved.ok and gallery.entries().size() == 1, "clean PNG and metadata are saved together")
	var reopened = Gallery.new()
	reopened.directory = gallery.directory
	var records: Array = reopened.entries()
	check(records.size() == 1 and records[0].board == board and records[0].palette == 0, "saved designs persist across gallery instances")
	check(reopened.picture(records[0]).get_image().get_pixel(0, 0).is_equal_approx(Color("ff3988")), "saved PNG can be viewed again")
	check(reopened.save_design(board, 0, image).id == saved.id and reopened.entries().size() == 1, "repeated save does not duplicate design")
	check(reopened.save_design(board, 1, image).ok and reopened.entries().size() == 2, "same pattern with different palette is a separate design")
	board[3][4] = Rules.BLUE
	check(reopened.save_design(board, 0, image).ok and reopened.entries().size() == 3, "changed design creates another entry")
	# Interrupted or corrupt records must not prevent opening the gallery.
	var invalid := FileAccess.open(gallery.directory.path_join("broken.json"), FileAccess.WRITE)
	invalid.store_string("null")
	invalid.close()
	var orphan := FileAccess.open(gallery.directory.path_join("orphan.json"), FileAccess.WRITE)
	orphan.store_string('{"id":"missing-image"}')
	orphan.close()
	check(reopened.entries().size() == 3, "broken and incomplete records are ignored")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(720, 1100)
		var scene = load("res://main.tscn").instantiate()
		root.add_child(scene)
		scene.gallery.directory = gallery.directory
		for i in range(4):
			await process_frame
		var design: Array = Rules.empty_board(9)
		for y in range(1, 8):
			for x in range(1, 8):
				if x in [1, 2, 6, 7] or y in [3, 4, 5]:
					design[y][x] = Rules.BLUE if x in [1, 2, 6, 7] else Rules.CORAL
		scene.game.board = design
		scene.board_view.show_settled(design)
		scene._refresh()
		check(scene._can_save() and scene.indicators[0].icon.complete[0], "partial garden is truly symmetric before capture")
		var save_touch := InputEventScreenTouch.new()
		save_touch.position = scene.indicators[0].panel.get_global_rect().get_center()
		save_touch.pressed = true
		root.push_input(save_touch, true)
		save_touch = save_touch.duplicate()
		save_touch.pressed = false
		root.push_input(save_touch, true)
		for frame in range(120):
			if not scene.saving:
				break
			await process_frame
		check(not scene.saving and scene.saved_fingerprint == scene._design_fingerprint(), "symmetry button completes real artwork capture")
		check(scene.gallery.entries().size() == 4, "capture adds a persistent local gallery entry")
		var picture: Image = scene.gallery.picture(scene.gallery.entries()[0]).get_image()
		check(picture.get_size() == Vector2i(900, 900), "saved image contains square artwork without screen controls")
		DirAccess.make_dir_recursive_absolute("res://build")
		picture.save_png("res://build/gallery-artwork-preview.png")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/helpers-preview.png")
		await scene._save_design()
		check(scene.gallery.entries().size() == 4, "real capture deduplicates repeated save")
		scene._open_gallery()
		check(scene.gallery_image.texture != null and scene.gallery_page.text == "1 / 4", "gallery opens on newest saved artwork")
		scene._turn_gallery(1)
		check(scene.gallery_page.text == "2 / 4", "gallery browses saved designs without scrolling")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/gallery-browser-preview.png")
		scene.gallery_panel.hide()
		for row: Array in design:
			row.fill(Rules.BLUE)
		scene.game.board = design
		scene.game.queue[scene.game.index] = ""
		scene.game._refresh_over()
		scene._refresh()
		await scene._save_design()
		check(scene.game.over and scene.gallery.entries().size() == 5, "100 percent filled garden can still be saved")
		scene.queue_free()
		await create_timer(0.12).timeout
	var previous_count: int = gallery.entries().size()
	var maze_record: Dictionary = gallery.save_design(board, 0, image, "labyrinth")
	check(maze_record.ok and gallery.entries().size() == previous_count + 1, "same board can be saved separately as labyrinth artwork")
	check(gallery.entries().any(func(record: Dictionary): return record.id == maze_record.id and record.theme == "labyrinth"), "gallery persists visual theme metadata")
	check(gallery.save_design(board, 0, image, "labyrinth").id == maze_record.id and gallery.entries().size() == previous_count + 1, "labyrinth saves also deduplicate")
	check(Gallery.fingerprint(board, 0) == JSON.stringify([board, 0]).sha256_text(), "legacy vine save identity remains compatible")
	var pre_redesign: int = gallery.entries().size()
	var redesigned: Dictionary = gallery.save_design(board, 0, image, "coral_reef", "2.0")
	check(redesigned.ok and gallery.entries().size() == pre_redesign + 1, "redesigned reef saves separately from previous artwork")
	check(gallery.entries().any(func(record: Dictionary): return record.id == redesigned.id and record.theme_version == "2.0"), "gallery records visual version")
	check(gallery.save_design(board, 0, image, "coral_reef", "2.0").id == redesigned.id and gallery.entries().size() == pre_redesign + 1, "redesigned reef deduplicates its own version")
	var before_raised: int = gallery.entries().size()
	var raised: Dictionary = gallery.save_design(board, 0, image, "coral_reef", "2.0", "raised24-v1")
	check(raised.ok and gallery.entries().size() == before_raised + 1, "raised appearance saves separately from old flat artwork")
	check(gallery.save_design(board, 0, image, "coral_reef", "2.0", "raised24-v1").id == raised.id, "raised appearance deduplicates repeated captures")
	check(gallery.entries().any(func(record: Dictionary): return record.id == raised.id and record.get("surface_revision", "") == "raised24-v1"), "surface revision is persisted without changing art version")
	# Delete only this runner's isolated test directory.
	var folder := DirAccess.open(gallery.directory)
	for name: String in folder.get_files():
		DirAccess.remove_absolute(gallery.directory.path_join(name))
	DirAccess.remove_absolute(gallery.directory)
	print("Gallery: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
