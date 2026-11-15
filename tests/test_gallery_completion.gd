extends SceneTree

const Board = preload("res://scripts/board_view.gd")
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Gallery = preload("res://scripts/gallery.gd")
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(720, 1100)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.gallery.directory = "user://completion-test-%d" % Time.get_ticks_usec()
	for theme: String in Palette.THEMES:
		scene._select_theme(theme)
		for n in [9, 11]:
			scene.requested_size = n
			scene._reset()
			scene.board_view.advance_growth(100)
			var snapshot: Array = scene.game.board.duplicate(true)
			var capture = Board.new()
			capture.size = Vector2(900, 900)
			capture.complete_background = true
			capture.show_guides = false
			root.add_child(capture)
			capture.show_settled(snapshot)
			capture.advance_growth(100)
			check(capture.board == snapshot and snapshot[0][0] == 0, "capture leaves logical empty cells unchanged")
			check(capture.pattern.arrivals.size() == 1, "blank fill generates no new plants, coral or mechanisms")
			check(capture.occupied_platform.occupancy_bytes.count(255) == n * n, "saved surface covers every cell")
			check(capture.blank_ground.get_child_count() == (n * n - 1 if theme in ["clockwork", "coral_reef"] else 0), "textured themes use only plain ground in the blank cells")
			check(not scene.board_view.complete_background and not scene.board_view.occupied_platform.filled(Vector2(0.5, 0.5)), "live game retains its empty floor")
			check(not capture.occupied_platform.side_at(Vector2(0.5, 1.02)), "filled saved surface has no seams or inner sidewalls")
			if DisplayServer.get_name() != "headless":
				# Exercise the same button callback used by the player.
				scene.indicators[0].panel.pressed.emit()
				while scene.saving: await process_frame
				var records: Array = scene.gallery.entries()
				var matches: Array = records.filter(func(record): return record.theme == theme and record.board.size() == n)
				check(matches.size() == 1, "symmetry save creates one completed artwork")
				if not matches.is_empty():
					var record: Dictionary = matches[0]
					check(record.board == snapshot, "saved metadata keeps the original colored pattern")
					check(record.surface_revision.contains("complete-background-v1"), "completed captures have a distinct appearance identity")
					check(record.fingerprint != Gallery.fingerprint(snapshot, Palette.selected_index, theme, Palette.theme_version(), record.surface_revision.replace("/complete-background-v1", "")), "old partial images do not deduplicate the completed artwork")
					var picture: Image = scene.gallery.picture(record).get_image()
					var point: Vector2i = Vector2i(capture._point(Vector2(1.5, 1.5)))
					var sample: Color = picture.get_pixelv(point)
					if theme == "labyrinth":
						check(sample.is_equal_approx(Palette.platform_color()), "empty saved labyrinth cells contain plain raised ground")
					else:
						check(sample.a > 0.99, "empty saved cells contain an opaque background tile")
					check(scene.game.board == snapshot and scene.game.moves == 0, "saving does not place tiles in the live game")
					await scene._save_design()
					check(scene.gallery.entries().size() == records.size(), "completed captures still deduplicate repeated saves")
					var preview_dir := OS.get_environment("TILES_TEST_PREVIEW_DIR")
					if not preview_dir.is_empty():
						DirAccess.make_dir_recursive_absolute(preview_dir)
						picture.save_png(preview_dir.path_join("completed-%s-%d.png" % [theme, n]))
			capture.queue_free()
			await process_frame
	if DirAccess.dir_exists_absolute(scene.gallery.directory):
		for file: String in DirAccess.open(scene.gallery.directory).get_files():
			DirAccess.remove_absolute(scene.gallery.directory.path_join(file))
		DirAccess.remove_absolute(scene.gallery.directory)
	scene.queue_free()
	await process_frame
	print("Gallery completion: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
