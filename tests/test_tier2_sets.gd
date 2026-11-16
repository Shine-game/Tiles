extends SceneTree
const Formations = preload("res://scripts/pattern/formation_assembly.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Components = preload("res://scripts/pattern/component_renderer.gd")
const Board = preload("res://scripts/board_view.gd")
const Clock = preload("res://scripts/clockwork_sets.gd")
const Coral = preload("res://scripts/coral_sets.gd")
const Zen = preload("res://scripts/zen_sets.gd")
const Vines = preload("res://scripts/vines_sets.gd")
const Palette = preload("res://scripts/palette.gd")
const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: _run.call_deferred()
func emit(_id: String, _spec: Dictionary, _record: Dictionary, at: float, seconds: float) -> Dictionary:
	return {"start": at, "stroke": seconds, "reverse": 0.0, "two_fronts": false, "end": at + seconds}
func _run() -> void:
	Clock.install()
	Coral.install()
	Zen.install()
	Vines.install()
	for loaded: Dictionary in [Clock.tier2, Coral.tier2, Zen.families.rakes[2], Zen.families.stones[2], Vines.tier2]:
		check(loaded.ok and loaded.definition.tier == 2, "Every active family has a validated live Tier 2 set")
		check(Formations.validate_schedule(Formations.parts(loaded)).is_empty(), "All production formation schedules have valid durations and dependency order")
	var sequence := {"base": {"animation": {"offset_seconds": 0.2, "duration_seconds": 0.5}}, "top": {"animation": {"duration_seconds": 0.3, "dependencies": [{"component": "base", "event": "complete", "delay_seconds": 0.1}]}}}
	var events := Formations.assemble({}, sequence, 1.0, emit)
	check(is_equal_approx(events.base.start, 1.2) and is_equal_approx(events.top.start, 1.8) and is_equal_approx(Formations.ready(events), 2.1), "The common assembly honors relative offsets and predecessor-completion dependencies")
	var invalid := sequence.duplicate(true)
	invalid.top.animation.dependencies[0].component = "missing"
	check(not Formations.validate_schedule(invalid).is_empty(), "Missing/forward dependencies fail validation before enabling a set")
	invalid = sequence.duplicate(true)
	invalid.base.animation.duration_seconds = -1
	check(not Formations.validate_schedule(invalid).is_empty(), "Negative formation durations fail validation")
	for color in [1, 2]:
		for n in [9, 11]:
			for extent: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)]:
				var grid := Rules.empty_board(n)
				for y in range(extent.y):
					for x in range(extent.x): grid[y + 3][x + 3] = color
				var records := Formations.collect(Rules.empty_board(n), grid)
				check(records.size() == (extent.x - 1) * (extent.y - 1), "Every overlapping same-color 2x2 is eligible in both board sizes")
				for origin: Vector2i in records:
					var record: Dictionary = records[origin]
					check(record.cells.size() == 4 and record.center == Vector2(origin) + Vector2.ONE and record.color == color and not record.old, "The shared record supplies exact supports, center and new/old status")
					check(record.id == Formations.identity(origin, color), "Canonical identity depends on logical color and top-left origin")
	var mixed := [[1, 1, 2], [1, 2, 2], [1, 1, 1]]
	check(Formations.collect(mixed, mixed).is_empty(), "Mixed colors cannot complete a 2x2")
	var lantern := Zen.landmark_spec(Vector2i(3, 4), 1)
	var sprite := Components.sprite(lantern)
	check(sprite.position == Vector2(4, 5) * 256 and sprite.offset == sprite.texture.get_size() * 0.5 - Vector2(627, 1090), "Lantern attachment stays on its original pedestal pivot")
	check(is_equal_approx(maxf(sprite.texture.get_width(), sprite.texture.get_height()) * sprite.scale.x, 256), "The lantern stays half-size")
	sprite.free()
	for origin: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(3, 3), Vector2i(8, 5)]:
		var spec := Zen.landmark_spec(origin, 2)
		var rock := Components.sprite(spec)
		check(is_equal_approx(rock.scale.x, rock.scale.y) and is_equal_approx(maxf(rock.texture.get_width(), rock.texture.get_height()) * rock.scale.x, 512), "Every rock variant fits a two-cell maximum extent without aspect distortion")
		rock.free()
	var bad_extent := lantern.duplicate(true)
	bad_extent.max_extent_cells = 0
	check(not Assets.validate_placement(bad_extent).is_empty(), "A nonpositive aspect-preserving extent is rejected")
	for theme: String in Palette.THEMES:
		Palette.select_theme(theme)
		for color in [1, 2]:
			for n in [9, 11]:
				var view := Board.new()
				root.add_child(view)
				view.size = Vector2(540, 540)
				var grid := Rules.empty_board(n)
				for y in range(3, 6):
					for x in range(3, 6): grid[y][x] = color
				view.show_settled(Rules.empty_board(n))
				view.animate_growth(Rules.empty_board(n), grid)
				view.set_process(false)
				var records: Dictionary = view.pattern.tier2_records()
				check(records.size() == 4 and is_equal_approx(view.construction_state.schedule.duration, view.pattern.duration), "Every real theme publishes four formations without changing its growth gate")
				var orders: Dictionary = {}
				for origin: Vector2i in records:
					var id: String = theme + "/" + records[origin].id
					var shared: Dictionary = view.construction_state.records[id]
					orders[id] = shared.order
					check(shared.data.owner == origin and shared.data.supports == records[origin].cells and shared.end == records[origin].end, "Common construction state owns the canonical formation lifecycle and supports")
				view.advance_growth(100)
				check(not view.growing, "Tier 2 and existing Tier 3 resolve before placement unlocks")
				var following := grid.duplicate(true)
				following[0][0] = 3 - color
				view.animate_growth(grid, following)
				view.set_process(false)
				for id: String in orders: check(view.construction_state.records[id].phase == "settled" and view.construction_state.records[id].order == orders[id], "Unrelated moves retain established formation state and ordering")
				view.advance_growth(100)
				var reduced := grid.duplicate(true)
				reduced[3][3] = 0
				view.show_settled(reduced, true)
				view.set_process(false)
				check(view.pattern.tier2_records().size() == 3 and not view.construction_state.records.has(theme + "/" + Formations.identity(Vector2i(3, 3), color)), "Removing one corner retires only its unsupported formation")
				view.advance_growth(100)
				view.show_settled(grid, true)
				view.set_process(false)
				view.advance_growth(100)
				for id: String in orders: check(view.construction_state.records[id].phase == "settled" and view.construction_state.records[id].order == orders[id], "Helper restoration restores supported formation identities")
				view.queue_free()
				await process_frame
	Palette.select_theme("clockwork")
	var partial := Board.new()
	root.add_child(partial)
	partial.size = Vector2(540, 540)
	var before := Rules.empty_board(9)
	for y in range(3, 6):
		for x in range(3, 6): before[y][x] = 1
	partial.show_settled(Rules.empty_board(9))
	partial.animate_growth(Rules.empty_board(9), before)
	partial.set_process(false)
	partial.advance_growth(0.65)
	var erased := before.duplicate(true)
	erased[5][5] = 0
	partial.show_settled(erased, true)
	partial.set_process(false)
	var surviving: Dictionary = partial.construction_state.records["clockwork/" + Formations.identity(Vector2i(3, 3), 1)]
	check(surviving.phase != "settled" and surviving.end > 0, "Canonical lifecycle honors surviving partial construction instead of settling because its board cells are old")
	partial.advance_growth(100)
	check(surviving.phase == "settled" and not partial.growing, "Preserved partial formation and retiring parts eventually release the gate")
	partial.queue_free()
	await process_frame
	check(Clock.formation_parts().L03.swap_treatment and Clock.tier2.definition.schedule.completion_offset_seconds == 1.95, "The upper gear keeps its opposite metal and complete mechanism readiness")
	check(is_equal_approx(Vines.flower().animation.duration_seconds, 0.36) and is_equal_approx(Vines.tier2.definition.schedule.link_overlap_fraction, 0.45), "Vines keeps its flower/link overlap rather than postponing links")
	print("Tier 2 sets: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
