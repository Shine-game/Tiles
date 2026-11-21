extends SceneTree
const Model = preload("res://scripts/tutorial_model.gd")
const Lessons = preload("res://scripts/tutorial_lessons.gd")
var failures := 0
var checks := 0
var path := "/tmp/tutorial-progress-%d.cfg" % Time.get_ticks_usec()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func write(values: Dictionary) -> void:
	var config := ConfigFile.new()
	for key: String in values: config.set_value("intro",key,values[key])
	check(config.save(path) == OK,"Fixture writes")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(Model.progress(path).lesson_id == "rotate" and not Model.progress(path).started,"Missing progress starts at Rotate")
	for stage in range(1,12):
		write({"step":stage,"started":true,"done":false,"seed_index":0})
		var old := FileAccess.get_file_as_bytes(path)
		var progress := Model.progress(path)
		check(progress.lesson_id == ["rotate","rotate","flip","color","place","vertical","horizontal","rotational","repair","repair","reveal"][stage-1] and progress.started and not progress.done,"Every old stage maps to its named lesson")
		check(FileAccess.get_file_as_bytes(path) == old,"Reading old saves does not rewrite them")
		check(Model.save_checkpoint(progress.lesson_id,progress.done,path,progress.checkpoint) == OK,"Next checkpoint migrates legacy save")
		var stored := ConfigFile.new()
		stored.load(path)
		check(stored.get_value("intro","version") == 2 and not stored.has_section_key("intro","step") and not stored.has_section_key("intro","seed_index"),"Migrated file contains versioned names rather than stage numbers")
	for lesson: String in Lessons.ORDER:
		var checkpoints: Array = Lessons.REPAIR_ORDER if lesson == "repair" else [""]
		for checkpoint: String in checkpoints:
			check(Model.save_checkpoint(lesson,false,path,checkpoint) == OK,"Named checkpoint writes")
			var progress := Model.progress(path)
			check(progress.lesson_id == lesson and progress.checkpoint == checkpoint and progress.started and not progress.done,"Every lesson and repair substep round-trips")
			check(Model.save_checkpoint(lesson,true,path,checkpoint) == OK and Model.progress(path).done,"Completion round-trips")
	for done in [false,true]:
		write({"step":9,"started":true,"done":done})
		check(Model.progress(path).lesson_id == "repair" and Model.progress(path).checkpoint == "wrong_placement" and Model.progress(path).done == done,"Removed axes card preserves completion and opens repair")
	write({"step":11,"started":true,"seed_index":4})
	check(Model.progress(path).lesson_id == "reveal" and not Model.progress(path).has("seed_index"),"Old partial final assembly resumes at atomic reveal without a runtime cursor")
	for invalid: Dictionary in [
		{"version":99}, {"version":"2"}, {"done":"false"}, {"started":1},
		{"step":"9"}, {"step":100}, {"seed_index":-1},
		{"version":2,"lesson_id":"deleted"},
		{"version":2,"lesson_id":"repair","checkpoint":"unknown"},
		{"version":2,"lesson_id":"rotate","checkpoint":"erase"}]:
		write(invalid)
		var progress := Model.progress(path)
		check(progress.lesson_id == "rotate" and not progress.started and not progress.done,"Malformed or unsupported progress safely starts at Rotate")
	check(Model.save_checkpoint("repair",false,path,"erase") == OK,"Valid save precedes rejection checks")
	var preserved := FileAccess.get_file_as_bytes(path)
	for request in [["missing",""],["repair","missing"],["rotate","erase"]]:
		check(Model.save_checkpoint(request[0],false,path,request[1]) == ERR_INVALID_PARAMETER,"Unknown checkpoint cannot be written")
		check(FileAccess.get_file_as_bytes(path) == preserved,"Rejected save preserves the previous checkpoint")
	check(Lessons.CARD_COUNT == 8,"Regrouped tutorial has eight displayed cards")
	for lesson: String in Lessons.ORDER:
		var entry: Dictionary = Lessons.LESSONS[lesson]
		check(entry.number >= 1 and entry.number <= Lessons.CARD_COUNT,"Lesson display number is in range")
		check(entry.next.is_empty() or entry.next in Lessons.ORDER,"Lesson transitions point to known IDs")
	for checkpoint: String in Lessons.REPAIR_ORDER:
		var entry: Dictionary = Lessons.REPAIR[checkpoint]
		check(entry.number == (5 if checkpoint == "wrong_placement" else (7 if checkpoint == "save" else 6)),"Repair checkpoints group into cards five, six, and seven")
		check(entry.next.is_empty() or entry.next in Lessons.REPAIR_ORDER,"Repair transitions point to known checkpoints")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path+".tmp")
	print("Tutorial progress: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
