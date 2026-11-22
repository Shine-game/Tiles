extends SceneTree
const SpriteGrowth = preload("res://scripts/pattern/sprite_growth.gd")
const Timing = preload("res://scripts/pattern/growth_schedule.gd")
const State = preload("res://scripts/pattern/component_state.gd")
const Growth = preload("res://scripts/growth.gd")
const Coral = preload("res://scripts/coral_growth.gd")
const Clock = preload("res://scripts/clockwork_growth.gd")
const Vines = preload("res://scripts/vines_growth.gd")
const Events = preload("res://scripts/pattern/theme_events.gd")
const Planner = preload("res://scripts/pattern/sprite_planner.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func near(a: float, b: float, message: String) -> void:
	check(absf(a - b) < 0.00001, message)
func reject(result: Dictionary, message: String) -> void:
	check(not result.ok and not result.get("errors", []).is_empty(), message)
func plan(component: String = "part", mode: String = "progressive", duration: float = 0.4) -> Dictionary:
	var decorations: Array = []
	for i in range(5):
		decorations.append({"id": component + "/anchor/a%d" % i, "metadata_path": "res://fixture/leaf.json", "local_transform": Transform2D.IDENTITY, "transform": Transform2D.IDENTITY, "growth_at": i * 0.25, "rules": {"animation": {"mode": mode, "duration_sec": duration}}})
	return {"ok": true, "component_id": component, "planner_version": 1, "base": {"metadata_path": "res://fixture/base.json"}, "decorations": decorations}
func id(index: int, component: String = "part") -> String:
	return SpriteGrowth.event_id(component + "/anchor/a%d" % index)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var layout := plan()
	for source: Dictionary in [
		{"start": 1.0, "stroke": 2.0, "end": 3.1},
		{"start": 1.0, "reverse": 1.5, "stroke": 2.0, "two_fronts": true, "end": 2.3},
		{"start": 1.0, "edge_start": 1.5, "seconds": 2.0, "end": 2.3}]:
		var compiled := SpriteGrowth.compile(layout, {"event": source})
		check(compiled.ok, "Canonical/legacy source normalizes")
		if not compiled.ok: continue
		for i in range(5):
			var event: Dictionary = compiled.events[id(i)]
			near(event.start, Timing.event_arrival(source, i * 0.25), "Anchor activation agrees with the existing field scheduler")
			near(event.end - event.start, 0.4, "Every progressive decoration retains its full duration")
	var late := SpriteGrowth.compile(layout, {"event": {"start": 1.0, "stroke": 2.0, "end": 3.0}})
	near(late.events[id(4)].end, 3.4, "Last anchor reveal can complete after the base")
	var direct := SpriteGrowth.compile(plan("part", "direct"), {"event": {"start": 1.0, "stroke": 2.0, "end": 3.0}})
	near(direct.events[id(4)].start, direct.events[id(4)].end, "Direct placement has no phantom reveal duration")
	check(SpriteGrowth.progress(direct.events[id(4)], 2.99) == 0 and SpriteGrowth.progress(direct.events[id(4)], 3.0) == 1, "Direct placement switches visibility exactly at arrival")
	var reverse := SpriteGrowth.compile(layout, {"event": {"start": 1.0, "stroke": 2.0, "end": 3.0}, "u_range": [1.0, 0.0]})
	near(reverse.events[id(0)].start, 3.0, "Reverse-only mapping reaches native root last")
	near(reverse.events[id(4)].start, 1.0, "Reverse-only mapping reaches native tip first")
	var edge := {"start_a": 0.1, "start_b": 0.3, "finish": 0.5}
	var left := SpriteGrowth.compile(layout, {"event": edge, "stroke_seconds": 0.4, "u_range": [0.0, 0.5]})
	var right := SpriteGrowth.compile(layout, {"event": edge, "stroke_seconds": 0.4, "u_range": [1.0, 0.5]})
	check(left.ok and right.ok, "Both native half-arms bind to one full edge field")
	near(left.events[id(0)].start, 0.1, "A half starts at source endpoint A")
	near(right.events[id(0)].start, 0.3, "B half starts at source endpoint B")
	near(left.events[id(4)].start, right.events[id(4)].start, "Both half-arm tips meet at the same edge midpoint")
	reject(SpriteGrowth.compile(layout, {"event": edge}), "Vine finish is not incorrectly treated as full travel time")
	var multiple := {"fronts": [{"start": 0.0, "origin_u": 0.0, "seconds": 1.0}, {"start": 0.0, "origin_u": 0.5, "seconds": 1.0}, {"start": 0.0, "origin_u": 1.0, "seconds": 1.0}]}
	var many := SpriteGrowth.compile(layout, {"event": multiple})
	check(many.ok, "Arbitrary simultaneous fronts are supported")
	near(many.events[id(1)].start, 0.25, "First meeting activates at earliest front")
	near(many.events[id(2)].start, 0.0, "Interior source activates its own anchor immediately")
	near(Timing.field_end(multiple.fronts), 0.25, "Multi-front completion is the peak of the earliest-arrival envelope")
	var different := [{"start": 1.0, "origin_u": 0.0, "seconds": 2.0}, {"start": 1.0, "origin_u": 1.0, "seconds": 4.0}]
	near(Timing.field_end(different), 7.0 / 3, "Different front speeds meet at the actual intersection")
	# Independently sample the continuous field: exact completion must bracket
	# the sampled maximum within one sample's possible travel error.
	var sample_peak := -INF
	for i in range(1001): sample_peak = maxf(sample_peak, Timing.field_arrival(different, i / 1000.0))
	check(Timing.field_end(different) >= sample_peak - 0.00001 and Timing.field_end(different) - sample_peak < 0.0041, "Exact field completion agrees with dense independent sampling")
	var instant := SpriteGrowth.compile(layout, {"event": {"start": 0.2, "end": 0.4}})
	near(instant.events[id(4)].start, 0.2, "A stage without a travel field activates at its declared start")
	var force_line := SpriteGrowth.new()
	force_line.reconcile({"part": layout}, {"part": {"event": {"start": 0.0, "stroke": 1.0, "end": 1.0}}})
	var forced := force_line.reconcile({"part": layout}, {"part": {"event": {"old": true}, "settled": true}}, {"elapsed": 0.2})
	check(forced.ok and forced.events.values().all(func(e): return e.old) and forced.visual_duration == 0, "Explicit per-component settled restoration overrides partial-parent history")
	var old := SpriteGrowth.compile(layout, {"event": {"old": true}})
	check(old.ok and old.events.values().all(func(e): return e.old and e.start == Timing.SETTLED_AT and e.end == Timing.SETTLED_AT), "Explicit old parents restore decorations fully settled")
	var restored := SpriteGrowth.compile(layout, {"event": {}}, true)
	check(restored.ok and SpriteGrowth.progress(restored.events[id(4)], 0) == 1, "Settled captures do not need a running source field")
	var partial := SpriteGrowth.compile(layout, {"event": {"start": -0.2, "stroke": 0.4, "end": 0.2}})
	check(partial.ok and not partial.events[id(0)].old, "Negative rebased timestamps are not a settled sentinel")
	near(SpriteGrowth.progress(partial.events[id(0)], 0), 0.5, "Partial decoration retains its progress after rebase")
	var negative_sentinel := SpriteGrowth.compile(plan("long", "progressive", 200.0), {"event": {"start": -100.0, "stroke": 0.4, "end": -99.6}})
	check(negative_sentinel.ok and not negative_sentinel.events[id(0, "long")].old, "Even the legacy sentinel timestamp is not settled without an explicit old flag")
	near(SpriteGrowth.progress(negative_sentinel.events[id(0, "long")], 0), 0.5, "Explicitly active long reveal remains partial at negative source time")
	var fixed_point := SpriteGrowth.compile(layout, {"event": {"start": 1.0, "stroke": 2.0, "end": 3.0}, "u_range": Vector2(0.5, 0.5)})
	check(fixed_point.ok and fixed_point.events.values().all(func(e): return is_equal_approx(e.start, 2.0)), "A constant source-field mapping activates every anchor at one declared threshold")
	var line := SpriteGrowth.new()
	var binding := {"event": {"start": 0.0, "stroke": 1.0, "end": 1.0}}
	var scheduled := line.reconcile({"part": layout}, {"part": binding}, {"structural_duration": 1.0})
	check(scheduled.ok, "Planner output becomes shared lifecycle events")
	near(scheduled.structural_duration, 1.0, "Structural barrier remains distinct")
	near(scheduled.visual_duration, 1.4, "Visual lifetime includes the last full reveal")
	var interned_plans := {}; interned_plans.part = layout
	var interned_bindings := {}; interned_bindings.part = binding
	check(SpriteGrowth.new().reconcile(interned_plans, interned_bindings).ok, "Godot property-assigned StringName map keys bind the same stable identities")
	var state := State.new()
	state.reconcile(scheduled.events, scheduled.structural_duration)
	near(state.schedule.duration, 1.4, "Existing component clock includes decorative tails")
	state.advance(0.2)
	near(state.records[id(0)].progress, 0.5, "Shared state advances a progressive decoration")
	check(state.records[id(4)].phase == State.WAITING, "Unreached anchor remains hidden")
	var refreshed := line.reconcile({"part": layout}, {"part": binding}, {"at": 0.2, "restart": false, "structural_duration": 1.0})
	near(refreshed.events[id(0)].start, 0.0, "Same-clock refresh does not rebase again")
	state.schedule.paused = true
	state.reconcile(refreshed.events, refreshed.structural_duration, 0.2, false, true, false)
	state.advance(10)
	near(state.schedule.clock, 0.2, "Existing paused clock freezes decoration progress")
	state.schedule.paused = false
	# Parent is now board-old but its construction was only 0.2s complete.
	var continued := line.reconcile({"part": layout}, {"part": {"event": {"old": true}}}, {"elapsed": 0.2})
	near(continued.events[id(0)].start, -0.2, "Active reveal rebases into the new placement clock")
	near(continued.events[id(0)].end, 0.2, "Active reveal keeps its remaining lifetime")
	near(continued.events[id(4)].start, 0.8, "Waiting anchors retain a partial parent field despite board-old status")
	check(not continued.events[id(4)].old, "Waiting anchor cannot become instantly settled")
	state.reconcile(continued.events, 0)
	near(state.records[id(0)].progress, 0.5, "Clock restart preserves the visible partial reveal")
	var new_layout := layout.duplicate(true)
	new_layout.decorations.append({"id": "part/anchor/new", "metadata_path": "res://fixture/leaf.json", "local_transform": Transform2D.IDENTITY, "growth_at": 0.9, "rules": {"animation": {"mode": "progressive", "duration_sec": 0.4}}})
	var expanded := line.reconcile({"part": new_layout}, {"part": {"event": {"old": true}}}, {"restart": false})
	near(expanded.events[SpriteGrowth.event_id("part/anchor/new")].start, 0.7, "A newly selected anchor uses the surviving partial field")
	# New incoming fronts may advance a waiting anchor, never restart a visible one.
	var incoming := line.reconcile({"part": layout}, {"part": {"event": {"start": 0.0, "reverse": 0.1, "stroke": 1.0, "two_fronts": true, "end": 0.55}}}, {"restart": false})
	near(incoming.events[id(4)].start, 0.1, "Incoming reverse front advances a waiting tip")
	near(incoming.events[id(0)].start, -0.2, "Visible decoration retains its original activation")
	var moved := layout.duplicate(true)
	moved.decorations[0].transform = Transform2D(0, Vector2(10, 20))
	var translated := line.reconcile({"part": moved}, {"part": binding}, {"at": 0.1, "restart": false})
	check(translated.events[id(0)].layout.transform.origin == Vector2(10, 20), "Survivor retains timing while adopting current placement geometry")
	near(translated.events[id(0)].start, -0.2, "View transform change does not replay growth")
	var atomic := line.snapshot()
	reject(line.reconcile({"part": moved}, {"part": {"event": {"start": NAN}}}), "Malformed source is diagnosed")
	check(var_to_bytes(atomic) == var_to_bytes(line.snapshot()), "Invalid replacement leaves active timing intact")
	var second := plan("second")
	reject(line.reconcile({"part": moved, "second": second}, {"part": binding, "second": {"event": {"start": INF}}}), "One invalid component rejects the entire replacement")
	check(var_to_bytes(atomic) == var_to_bytes(line.snapshot()), "Earlier valid components cannot partially commit a rejected reconciliation")
	var replacement := line.reconcile({}, {}, {"elapsed": 0.1})
	check(replacement.events.is_empty() and replacement.delta.removed.size() == 5, "Cancellation removes pending and active decorations")
	state.reconcile(replacement.events, 0)
	check(state.records.is_empty() and not state.schedule.running(), "Shared lifecycle releases removed decoration records")
	var rebuilt := line.reconcile({"part": layout}, {"part": binding})
	near(rebuilt.events[id(0)].start, 0.0, "A removed and recreated component starts fresh")
	line.reconcile({"part": layout}, {"part": binding}, {"at": 1.5, "restart": false})
	var survived := line.reconcile({"part": layout}, {"part": binding}, {"elapsed": 1.5})
	check(survived.events.values().all(func(e): return e.old), "Completed survivors never replay on a later placement")
	near(survived.visual_duration, 0.0, "Settled artwork does not prolong a new placement")
	state.reconcile(survived.events, 0)
	var replayed := line.reconcile({"part": layout}, {"part": {"event": binding.event, "replay": true}})
	state.reconcile(replayed.events, 0)
	check(not replayed.events[id(0)].old and state.records[id(0)].phase == State.APPEARING, "Explicit replay reaches the existing state lifecycle")
	var after_replay := line.reconcile({"part": layout}, {"part": {"event": {"old": true}}}, {"elapsed": 0.1})
	check(not after_replay.events[id(0)].replay and not after_replay.events[id(0)].old, "Replay is a one-shot action, not a persistent history flag")
	var capture := line.reconcile({"part": layout}, {"part": {"event": {}}}, {"settled": true})
	state.reconcile(capture.events, 0, 0, true)
	check(state.records.values().all(func(e): return e.phase == State.SETTLED) and capture.visual_duration == 0, "Gallery/restore settles every reveal silently")
	capture.events.clear()
	check(line.snapshot().events.size() == 5, "Returned timing dictionaries do not expose private history")
	line.reset()
	check(line.snapshot().events.is_empty() and line.snapshot().components.is_empty(), "Reset drops all timing history")
	for malformed: Dictionary in [
		{"event": {"start": 0, "stroke": -1}},
		{"event": {"start": 0, "stroke": 1, "end": 0.5}},
		{"event": {"start": 0, "two_fronts": true, "stroke": 1}},
		{"event": {"start": 0, "old": "yes"}},
		{"event": {"fronts": []}},
		{"event": {"fronts": [{"start": 0, "origin_u": 2, "seconds": 1}]}},
		{"event": binding.event, "u_range": [-0.1, 1]},
		{"event": binding.event, "unknown": 1},
		{"event": binding.event, "stroke_seconds": INF}]: reject(SpriteGrowth.compile(layout, malformed), "Malformed timing binding is rejected: " + str(malformed))
	reject(line.reconcile({"part": layout}, {}), "Each plan needs a source binding")
	reject(line.reconcile({"wrong": layout}, {"wrong": binding}), "Plan identity must match source owner")
	reject(line.reconcile({"part": layout}, {"part": binding}, {"restart": false, "elapsed": 0.1}), "Refresh cannot double-rebase clocks")
	var duplicate := layout.duplicate(true); duplicate.decorations.append(duplicate.decorations[0])
	reject(SpriteGrowth.compile(duplicate, binding), "Duplicate anchor timing IDs are rejected")
	var invalid := layout.duplicate(true); invalid.decorations[0].growth_at = 1.1
	reject(SpriteGrowth.compile(invalid, binding), "Out-of-range activation threshold is rejected")
	check_actual_models()
	print("Sprite growth: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func check_actual_models() -> void:
	var empty := Rules.empty_board(5)
	var board := empty.duplicate(true)
	board[1][1] = 2; board[1][2] = 2; board[2][1] = 2; board[2][2] = 2
	var models := {"coral_reef": Coral, "clockwork": Clock, "vines": Vines}
	for theme: String in models:
		var model = models[theme].new()
		model.build(empty, board)
		var structural_duration: float = model.duration
		var structural_events := Events.collect(model, theme)
		var features := var_to_bytes(model.tier2_records())
		var source := {}
		var mapping := {}
		if theme in ["coral_reef", "clockwork"]:
			for part: Dictionary in model.components.values():
				if (theme == "coral_reef" and part.id.begins_with("arm_")) or (theme == "clockwork" and part.id == "T01"): source = part; break
		elif theme == "vines": source = model.edges[0]; mapping.stroke_seconds = Growth.STEP; mapping.u_range = [0.0, 0.5]
		else: source = {"start": model.arrivals[Vector2i(1, 1)], "end": model.arrivals[Vector2i(1, 1)] + 0.3}
		mapping.event = source
		var catalog := Assets.load_sprite_catalog(Themes.sprite_catalog_path(theme))
		var family := "default"
		var actual_plan := Planner.new().plan(catalog, family, 2, theme + "/actual", 42)
		var compiled := SpriteGrowth.compile(actual_plan, mapping)
		check(compiled.ok and compiled.events.size() == actual_plan.decorations.size(), "Actual theme planner and growth source compile: " + theme)
		if compiled.ok:
			var field := SpriteGrowth.source_field(mapping)
			for event: Dictionary in compiled.events.values():
				near(event.start, SpriteGrowth.arrival(field, event.growth_at), "Actual anchor uses its source wave: " + theme)
			var model_line := SpriteGrowth.new()
			var attached: Dictionary = model.schedule_sprite_growth({actual_plan.component_id: actual_plan}, {actual_plan.component_id: mapping}, model_line)
			check(attached.ok and model.sprite_growth_events.size() == compiled.events.size(), "Every theme inherits the common scheduling bridge: " + theme)
		# A deliberately long decoration makes visual lifetime exceed every
		# structural prerequisite, without changing the precomputed formation.
		var long_plan := plan(theme + "/tail", "progressive", structural_duration + 1)
		var tail_line := SpriteGrowth.new()
		var attached: Dictionary = model.schedule_sprite_growth({long_plan.component_id: long_plan}, {long_plan.component_id: mapping}, tail_line)
		check(attached.ok, "Long decoration schedules: " + theme)
		near(model.duration, structural_duration, "Model structural duration remains unchanged: " + theme)
		check(var_to_bytes(model.tier2_records()) == features, "Higher-tier prerequisites remain unchanged: " + theme)
		var collected := Events.collect(model, theme)
		for key: String in structural_events: check(collected.has(key) and collected[key] == structural_events[key], "Structural event unchanged after decoration scheduling: " + theme)
		check(collected.size() == structural_events.size() + 5, "Collector adds decoration events to the existing lifecycle: " + theme)
		var state := State.new(); state.reconcile(collected, model.duration)
		near(state.schedule.duration, model.sprite_visual_duration, "Existing shared clock includes the whole decoration tail: " + theme)
		var before_events: Dictionary = model.sprite_growth_events.duplicate(true)
		var bad: Dictionary = model.schedule_sprite_growth({long_plan.component_id: long_plan}, {}, tail_line)
		check(not bad.ok and model.sprite_growth_events == before_events, "Bad replacement leaves model decoration timing intact: " + theme)
		model.build(board, board)
		check(model.sprite_growth_events.is_empty(), "A fresh model build clears stale attached events: " + theme)
