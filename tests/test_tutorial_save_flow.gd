extends SceneTree
const Main = preload("res://scripts/main.gd")
const Model = preload("res://scripts/tutorial_model.gd")
const Palette = preload("res://scripts/palette.gd")
const Capture = preload("res://scripts/artwork_capture.gd")
const Board = preload("res://scripts/board_view.gd")
var checks := 0
var failures := 0
var capture_results: Array = []

class TestCapture extends RefCounted:
	signal released
	var hold := false
	var invalid := false
	var calls := 0
	func render(_owner, _view, _board, _theme) -> Image:
		calls += 1
		if hold: await released
		if invalid: return null
		var image := Image.create(900,900,false,Image.FORMAT_RGBA8)
		image.fill(Color.MAGENTA)
		return image

class FlakyGallery extends "res://scripts/gallery.gd":
	var failures_left := 1
	func save_design(board: Array, palette_index: int, image: Image, theme: String = "vines", theme_version: String = "", surface_revision: String = "") -> Dictionary:
		if failures_left > 0:
			failures_left -= 1
			return {"ok":false,"error":"injected_write_failure"}
		return super.save_design(board,palette_index,image,theme,theme_version,surface_revision)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func capture_removed_owner(capture, owner, view, board) -> void:
	var image: Image = await capture.render(owner,view,board,"vines")
	capture_results.append(image)

func run() -> void:
	root.size = Vector2i(540,825)
	var folder := "/tmp/tutorial-save-flow-%d" % Time.get_ticks_usec()
	var game = Main.new()
	root.add_child(game)
	game.intro_progress_path = folder+".cfg"
	var capture := TestCapture.new()
	game.artwork_capture = capture
	game.gallery = FlakyGallery.new()
	game.gallery.directory = folder
	var results: Array = []
	game.design_save_finished.connect(func(result):results.append(result))
	# An old interrupted assembly must rebuild the full design, without reviving
	# the retired partial replay renderer or persisting its cursor again.
	var old_save := ConfigFile.new()
	old_save.set_value("intro","step",11)
	old_save.set_value("intro","started",true)
	old_save.set_value("intro","seed_index",4)
	check(old_save.save(game.intro_progress_path) == OK,"Old partial assembly fixture writes")
	game._maybe_introduction(true)
	var intro = game.introduction
	check(game.game.board == Model.final_board() and game.game.moves == Model.final_steps().size(),"Old partial assembly resumes as the complete canonical playable design")
	var migrated := ConfigFile.new()
	migrated.load(game.intro_progress_path)
	check(migrated.get_value("intro","lesson_id") == "reveal" and not migrated.has_section_key("intro","seed_index"),"Resuming removes the obsolete assembly cursor from saved progress")
	check(intro.reveal_save_state == "failed" and not game.saving,"Storage failure leaves a retryable reveal")
	check(game.gallery.entries().is_empty() and not Model.progress(game.intro_progress_path).done,"Failed save creates no gallery entry or tutorial completion")
	check(intro.forward.disabled and not intro.hint.disabled and intro.hint in intro.pulsing,"Failure highlights Save and blocks Settings")
	check(intro.text.get_parsed_text() == intro.SAVE_FAILED_TEXT,"Failure has visible retry guidance")
	intro.choose_theme("coral_reef")
	check(Palette.theme_id() == "vines" and game.introduction == intro,"A failed save cannot hand off to theme selection")
	game.design_save_finished.emit({"ok":true,"fingerprint":"unrelated","session_id":0})
	check(intro.reveal_save_state == "failed","Unrelated save results cannot unlock the reveal")
	intro.hint.pressed.emit()
	check(intro.reveal_save_state == "saved" and not intro.forward.disabled,"Existing Save button retries and unlocks Settings on success")
	var entries: Array = game.gallery.entries()
	check(entries.size() == 1 and entries[0].board == Model.repair_board("save") and entries[0].theme == "vines","Successful retry writes the exact revealed board and theme")
	var image := Image.load_from_file(game.gallery.image_path(entries[0]))
	check(image != null and image.get_size() == Vector2i(900,900),"Retry writes a readable full-size PNG")
	check(game.saved_fingerprint == game._design_fingerprint() and game.indicators[0].icon.saved,"Save indicator reflects confirmed persistence")
	check(not Model.progress(game.intro_progress_path).done,"Confirmed save still waits for theme choice")
	intro.open_settings()
	game._show_menu("Themes")
	intro.choose_theme("coral_reef")
	await process_frame
	check(game.introduction == null and Palette.theme_id() == "coral_reef" and Model.progress(game.intro_progress_path).done,"Successful save followed by theme choice completes the tutorial")
	capture.invalid = true
	var failed: Dictionary = await game.save_current_design()
	check(not failed.ok and failed.status == "capture_failed" and not game.saving,"Normal capture failures return a result and release the busy state")
	check(game.save_error_dialog != null and game.save_error_dialog.visible,"Normal-game failure has visible feedback")
	game.save_error_dialog.hide()
	capture.invalid = false
	var blocked := FileAccess.open(folder+".blocked",FileAccess.WRITE)
	blocked.store_string("not a directory")
	blocked.close()
	game.gallery.directory = folder+".blocked"
	var storage: Dictionary = await game.save_current_design()
	check(not storage.ok and storage.status == "storage_failed" and not game.saving,"Actual filesystem failure returns a retryable storage result")
	game.gallery.directory = folder
	game.save_error_dialog.hide()
	var saved: Dictionary = await game.save_current_design()
	check(saved.ok and saved.status == "saved" and saved.fingerprint == game._design_fingerprint(),"Normal game uses the same successful save result")
	check(game.gallery.entries().size() == 2,"Chosen-theme save is separate from the tutorial Vines image")
	capture.hold = true
	game.save_current_design()
	var count := results.size()
	var calls := capture.calls
	var busy: Dictionary = await game.save_current_design()
	check(not busy.ok and busy.status == "busy" and game.saving and capture.calls == calls and results.size() == count,"Duplicate save requests do not cancel or duplicate an in-flight job")
	capture.hold = false
	capture.released.emit()
	check(not game.saving and results.back().ok and game.gallery.entries().size() == 2,"In-flight save finishes normally and deduplicates")
	capture.hold = true
	game.save_current_design()
	game._reset()
	capture.hold = false
	capture.released.emit()
	check(not game.saving and results.back().status == "cancelled" and game.saved_fingerprint != game._design_fingerprint(),"Late capture cannot mark a replacement game as saved")
	check(game.gallery.entries().size() == 2,"Cancelled capture does not write incorrect artwork")
	capture.hold = true
	game.save_current_design()
	game._start_introduction("reveal")
	intro = game.introduction
	check(intro.reveal_save_state == "waiting" and intro.forward.disabled,"Reveal waits for an older capture instead of starting a second job")
	capture.hold = false
	capture.released.emit()
	check(intro.reveal_save_state == "saved" and not game.saving,"Reveal requests its own capture after the previous job ends")
	intro.finish(true)
	await process_frame
	capture.hold = true
	game._start_introduction("reveal")
	intro = game.introduction
	check(game.saving and intro.reveal_save_state == "saving","Reveal can be exited while capture is pending")
	intro.finish(true)
	await process_frame
	capture.hold = false
	capture.released.emit()
	check(game.introduction == null and not game.saving and results.back().ok,"A late save cannot resurrect exited guidance")
	if DisplayServer.get_name() != "headless":
		Palette.select_theme("vines")
		var owner := Control.new()
		root.add_child(owner)
		var view = Board.new()
		owner.add_child(view)
		view.show_settled(Model.repair_board("save"))
		capture_removed_owner(Capture.new(),owner,view,Model.repair_board("save"))
		owner.queue_free()
		for frame in range(10):
			if not capture_results.is_empty(): break
			await process_frame
		check(capture_results.size() == 1 and capture_results[0] == null,"Removing a real capture owner cancels its viewport safely")
		game.artwork_capture = Capture.new()
		game.save_current_design()
		game.queue_free()
		await process_frame
		await process_frame
		check(not is_instance_valid(game),"Deleting the main game during a real capture exits safely")
	if is_instance_valid(game): game.queue_free()
	await process_frame
	var directory := DirAccess.open(folder)
	if directory != null:
		for file: String in directory.get_files(): DirAccess.remove_absolute(folder.path_join(file))
		DirAccess.remove_absolute(folder)
	DirAccess.remove_absolute(folder+".cfg")
	DirAccess.remove_absolute(folder+".blocked")
	print("Tutorial save flow: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
