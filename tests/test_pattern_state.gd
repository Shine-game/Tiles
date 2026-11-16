extends SceneTree
const State = preload("res://scripts/pattern/component_state.gd")
const Schedule = preload("res://scripts/pattern/growth_schedule.gd")
const Palette = preload("res://scripts/palette.gd")
const Rules = preload("res://scripts/rules.gd")
const Board = preload("res://scripts/board_view.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func event(start: float, end: float, old: bool = false) -> Dictionary:
	return {"start": start, "end": end, "old": old}
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var state := State.new()
	var delta := state.reconcile({"a": event(0.2, 0.8)}, 0)
	check(delta.added == ["a"] and state.schedule.duration == 0.8, "Construction contributes its own gate duration")
	check(state.records.a.phase == State.WAITING and state.records.a.progress == 0, "A dependent part stays hidden before its start")
	state.advance(0.5)
	check(state.records.a.phase == State.APPEARING and is_equal_approx(state.records.a.progress, 0.5), "A part advances through its own interval")
	state.schedule.paused = true
	state.advance(100)
	check(state.schedule.clock == 0.5, "Pausing the construction clock freezes progress")
	state.schedule.paused = false
	state.advance(100)
	check(state.records.a.phase == State.SETTLED and not state.schedule.running(), "Completed construction settles and unlocks placement")
	var order: int = state.records.a.order
	var identity: Dictionary = state.records.a
	state.reconcile({"a": event(0.2, 0.8), "b": event(0, 0.1)}, 0.1)
	check(is_same(identity, state.records.a) and state.records.a.order == order, "A surviving component keeps its record and painter ordinal")
	check(state.records.a.phase == State.SETTLED and state.records.a.progress == 1, "Resetting the clock cannot roll back settled parts")
	check(state.schedule.duration == 0.1, "Old construction does not prolong a later short placement")
	state.advance(-4)
	check(state.schedule.clock == 0, "Negative elapsed time cannot rewind construction")
	state.advance(0.1)
	delta = state.reconcile({"b": event(0, 0.1, true)}, 0, 0, true)
	check(delta.removed == ["a"] and not state.records.has("a"), "Unsupported parts are removed without clearing survivors")
	state.reconcile({"a": event(0, 0.4), "b": event(0, 0.1, true)}, 0.4)
	check(state.records.a.order == order and state.records.a.phase == State.APPEARING, "Undo/rebuild restores stable ownership and starts only the re-created part")
	var retiring := event(0.1, 0.3)
	retiring.retiring = true
	state.reconcile({"a": retiring, "b": event(0, 0, true)}, 0)
	check(state.records.a.phase == State.RETIRING and state.schedule.duration == 0.3, "Retirement contributes to the shared gate")
	state.advance(0.2)
	check(is_equal_approx(state.records.a.progress, 0.5) and state.records.b.phase == State.SETTLED, "Removal fades only unsupported artwork")
	state.advance(100)
	check(not state.records.has("a") and state.records.has("b"), "Finished retirement releases only its own component")
	var restored := State.new()
	restored.copy_from(state)
	check(restored.records.b.order == state.records.b.order and restored.records.b.phase == State.SETTLED and not restored.schedule.running(), "Capture copies identities/order and freezes construction")
	restored.records.b.progress = 0
	check(state.records.b.progress == 1, "Capture state is independent of the live state")
	state.reconcile({"a": retiring}, 0.0, 0.0, true)
	check(state.records.is_empty(), "Settled reconstruction discards unsupported retiring artwork immediately")
	state.reset()
	check(state.records.is_empty() and state.orders.is_empty() and not state.schedule.running(), "New game/reset cancels construction and clears identity history")
	state.reconcile({"partial": event(-0.2, 0.2)}, 0.2)
	check(state.records.partial.phase == State.APPEARING and is_equal_approx(state.records.partial.progress, 0.5), "A negative rebased start is partial construction, not a settled sentinel")
	var shifted := Schedule.shifted({"start": 0.1, "end": 0.8, "edge_start": 0.3, "seconds": 0.7}, 0.4, ["start", "end", "edge_start"])
	check(is_equal_approx(shifted.start, -0.3) and is_equal_approx(shifted.end, 0.4) and is_equal_approx(shifted.edge_start, -0.1) and shifted.seconds == 0.7, "Partial construction rebases timestamps while preserving travel duration")
	for u in [0.0, 0.2, 0.7, 1.0]:
		check(is_equal_approx(Schedule.front_arrival(0.1, 0.3, 0.4, true, u), minf(0.1 + u * 0.4, 0.3 + (1 - u) * 0.4)), "Bidirectional fields use earliest pixel arrival")
	check(is_equal_approx(Schedule.front_end(0.1, 0.3, 0.4, true, 0.035), 0.435), "Two-front completion includes the reveal tail")
	var parent := {"start": 0.1, "reverse": 0.3, "stroke": 0.4, "two_fronts": true, "end": 0.435}
	check(is_equal_approx(Schedule.dependent_start([{"component": "a", "event": "complete", "delay_seconds": 0.2}], {"a": parent}), 0.635), "Parts can depend on parent completion plus delay")
	check(is_equal_approx(Schedule.dependent_start([{"component": "a", "at_mask_u": 0.5}], {"a": parent}), 0.3), "Parts can depend on a named field threshold")
	check(Schedule.event_arrival({"start": 0.2, "seconds": 0.4}, 0.5) == 0.4, "Single-front dependencies need no unused reverse field")
	check(Schedule.front_end(0.2, 0.1, 0.0, true) == 0.1, "Zero-duration two-front construction completes at its first instant")
	state.schedule.paused = true
	var wave: int = state.wave
	state.reconcile({"partial": event(-0.2, 0.2)}, 0.2, state.schedule.clock, false, true, false)
	check(state.schedule.paused and state.wave == wave, "A layout refresh preserves pause and does not start a new placement")
	await check_boards()
	print("Pattern state: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func check_boards() -> void:
	for theme: String in Palette.THEMES:
		Palette.select_theme(theme)
		var view := Board.new()
		view.size = Vector2(540, 540)
		root.add_child(view)
		var initial := Rules.empty_board(9)
		for y in range(2, 4):
			for x in range(2, 5): initial[y][x] = 1
		view.show_settled(Rules.empty_board(9))
		view.animate_growth(Rules.empty_board(9), initial)
		view.set_process(false)
		check(view.growing and is_equal_approx(view.construction_state.schedule.duration, view.pattern.duration), "All theme gates preserve their existing construction duration: " + theme)
		check(not view.construction_state.records.is_empty(), "All themes register persistent components: " + theme)
		view.advance_growth(view.pattern.duration * 0.25)
		var clock_before: float = view.clock
		var wave_before: int = view.construction_state.wave
		view._restyle()
		view.set_process(false)
		check(view.clock <= clock_before and view.construction_state.wave == wave_before, "Layout refresh preserves the construction wave: " + theme)
		view.advance_growth(100)
		check(not view.growing and view.construction_state.records.values().all(func(item): return item.phase == State.SETTLED), "Every theme settles its construction records: " + theme)
		var before: Dictionary = view.construction_state.records.duplicate()
		var following := initial.duplicate(true)
		following[6][6] = 2
		view.animate_growth(initial, following)
		view.set_process(false)
		for id: String in before:
			if view.construction_state.records.has(id): check(view.construction_state.records[id].phase == State.SETTLED, "Old components stay settled across unrelated placements: " + theme)
		view.advance_growth(100)
		var capture := Board.new()
		capture.size = view.size
		root.add_child(capture)
		capture.show_settled(following)
		capture.construction_state.copy_from(view.construction_state)
		check(capture.construction_state.snapshot().records == view.construction_state.snapshot().records, "Settled capture state preserves live identities: " + theme)
		capture.queue_free()
		# Undo/Erase rebuilds a supported subset. Clockwork may retire its old
		# parts; all other themes perform their established immediate restore.
		var reduced := initial.duplicate(true)
		reduced[2][4] = 0
		view.show_settled(reduced, true)
		view.set_process(false)
		check(is_equal_approx(view.construction_state.schedule.duration, view.pattern.duration if theme == "clockwork" else 0.0), "Helper restoration retains the existing removal gate: " + theme)
		view.advance_growth(100)
		check(not view.growing and view.construction_state.records.values().all(func(item): return item.phase == State.SETTLED), "Helpers remove invalid parts and settle supported survivors: " + theme)
		if theme == "clockwork":
			view.show_settled(Rules.empty_board(9))
			view.animate_growth(Rules.empty_board(9), initial)
			view.set_process(false)
			view.advance_growth(0.1)
			var core_id := "clockwork/part/C01/1/2/2"
			var partial: float = view.construction_state.records[core_id].progress
			view.show_settled(reduced, true)
			view.set_process(false)
			check(view.construction_state.records[core_id].phase == State.APPEARING and is_equal_approx(view.construction_state.records[core_id].progress, partial), "Actual Clockwork helper preserves partial surviving construction")
			view.advance_growth(100)
			check(view.construction_state.records.values().all(func(item): return item.phase == State.SETTLED), "Partial restoration finishes surviving parts and retires invalid ones")
		view.show_settled(Rules.empty_board(9))
		check(view.construction_state.records.is_empty() and not view.growing, "Reset clears every theme's shared construction state: " + theme)
		view.queue_free()
		await process_frame
