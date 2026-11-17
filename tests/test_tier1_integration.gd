extends SceneTree
const Coral = preload("res://scripts/coral_growth.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const State = preload("res://scripts/pattern/component_state.gd")
const Layer = preload("res://scripts/pattern/tier1_layer.gd")
const Board = preload("res://scripts/board_view.gd")
const Palette = preload("res://scripts/palette.gd")
const Rules = preload("res://scripts/rules.gd")
const Sources = preload("res://scripts/pattern/tier1_sources.gd")
const Timing = preload("res://scripts/pattern/sprite_growth.gd")
const Presenter = preload("res://scripts/pattern/sprite_presenter.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for theme: String in Palette.THEMES:
		Palette.select_theme(theme)
		check(Sources.active(theme), "Theme activated: " + theme)
		var board := Board.new()
		board.size = Vector2(640, 640)
		root.add_child(board)
		var empty := Rules.empty_board(7)
		var grid := empty.duplicate(true)
		for color in [1, 2]:
			var y: int = 1 if color == 1 else 4
			for p: Vector2i in [Vector2i(1, y), Vector2i(2, y), Vector2i(3, y), Vector2i(2, y + 1)]: grid[p.y][p.x] = color
		board.show_settled(empty)
		board.animate_growth(empty, grid)
		board.set_process(false)
		var layer = board.tier1_layer
		check(layer.diagnostics.is_empty(), "Live preparation/presentation succeeds: " + theme + str(layer.diagnostics))
		check(not layer.plans.is_empty() and not board.pattern.sprite_growth_events.is_empty(), "Live plans and decoration events: " + theme)
		check(board.construction_state.schedule.duration >= board.pattern.sprite_visual_duration, "Gate includes decoration tails: " + theme)
		var expected := Sources.descriptors(board.pattern, theme, empty)
		check(layer.plans.size() == expected.size(), "Every structural attachment is presented exactly once: " + theme)
		for item: Dictionary in expected:
			var plan: Dictionary = layer.plans[item.id]
			check(plan.base.transform * Vector2(plan.base.origin[0], plan.base.origin[1]) == item.context.origin_cells, "Source origin maps to board anchor: " + theme)
			if item.context.has("target_forward"):
				var native: Vector2 = Vector2.UP if theme == "coral_reef" else Vector2.RIGHT
				check(plan.base.transform.basis_xform(native).normalized().is_equal_approx(item.context.target_forward.normalized()), "Lighting preserves connected direction: " + theme)
			for deco: Dictionary in plan.decorations:
				var id := Timing.event_id(deco.id)
				check(board.construction_state.records.has(id) and layer.presenter.renderer.nodes.has(id), "Common state owns every generated overlay")
		if theme == "coral_reef":
			check(board.coral_visuals.registry.keys().all(func(id): return not board.pattern.components[id].id.begins_with("arm_")), "Legacy coral arms are replaced")
		elif theme == "clockwork":
			check(board.clockwork_visuals.registry.values().all(func(entry): return entry.event.id not in ["T01", "T03"]), "Legacy tubes and oversized boundary rings are replaced")
			check(board.construction_state.records.keys().any(func(id): return id.begins_with("clockwork/part/T01_")), "Tube structural events remain available")
		elif theme == "zen_garden":
			check(layer.plans.size() == 3, "Zen shared edges have one stone each")
			check(not board.zen_visuals.centerpieces.is_empty(), "Rake centerpieces retained")
		board.advance_growth(0.04)
		var prior_clock: float = board.clock
		var prior_nodes: Dictionary = layer.presenter.renderer.nodes.duplicate()
		var fingerprints := {}
		for id: String in layer.plans: fingerprints[id] = layer.plans[id].fingerprint
		board.size = Vector2(800, 730)
		board.update_geometry()
		check(board.clock == prior_clock and prior_nodes == layer.presenter.renderer.nodes, "Resize preserves nodes and shared clock: " + theme)
		board._restyle()
		board.set_process(false)
		check(is_equal_approx(board.clock, prior_clock), "Restyle preserves partial clock: " + theme)
		check(layer.presenter.renderer.nodes == prior_nodes, "Restyle retains source identities: " + theme)
		board.construction_state.schedule.paused = true
		board.advance_growth(1.0)
		check(board.clock == prior_clock, "Pause freezes new presentation: " + theme)
		board.construction_state.schedule.paused = false
		board.advance_growth(100)
		check(not board.growing, "All reveals complete: " + theme)
		var following := grid.duplicate(true)
		following[6][6] = 1
		board.animate_growth(grid, following)
		board.set_process(false)
		for id: String in fingerprints: check(layer.plans[id].fingerprint == fingerprints[id], "Unrelated placement preserves generated artwork: " + theme)
		board.advance_growth(100)
		var capture := Board.new()
		capture.size = Vector2(900, 900)
		capture.complete_background = true
		root.add_child(capture)
		capture.show_settled(following)
		for id: String in layer.plans: check(capture.tier1_layer.plans[id].fingerprint == layer.plans[id].fingerprint, "Gallery rebuild matches board artwork: " + theme)
		capture.queue_free()
		var reduced := following.duplicate(true)
		reduced[4][3] = 0
		board.show_settled(reduced, true)
		board.set_process(false)
		if theme == "clockwork": check(not layer.retirements.is_empty(), "Removed tube subtrees retire with frozen masks")
		board.advance_growth(100)
		check(layer.retirements.is_empty(), "Retired sprite trees release: " + theme)
		board.show_settled(empty)
		check(layer.plans.is_empty() and board.construction_state.records.is_empty(), "Reset removes generated state: " + theme)
		board.queue_free()
		await process_frame
	# A palette change updates shader treatment without changing geometry.
	Palette.select_theme("vines")
	var view := Board.new()
	view.size = Vector2(600, 600)
	root.add_child(view)
	var pair := Rules.empty_board(5)
	pair[2][2] = 1
	pair[2][3] = 1
	Palette.select(0)
	view.show_settled(pair)
	var sample: Dictionary = view.tier1_layer.plans.values()[0]
	var base: Sprite2D = view.tier1_layer.presenter.renderer.nodes[Presenter.ROOT + "/" + sample.component_id + "/base"]
	var geometry: String = sample.fingerprint
	Palette.select(1)
	view._restyle()
	check(base.material.get_shader_parameter("palette_target") == Palette.pigment(1), "Settled artwork follows selected palette")
	check(view.tier1_layer.plans[sample.component_id].fingerprint == geometry, "Palette changes preserve generated layout")
	view.queue_free()
	Palette.select(0)
	check_future_theme(pair)
	print("Tier 1 integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check_future_theme(pair: Array) -> void:
	# Export packs are immutable; synthetic authoring fixtures run in source checks.
	if OS.get_cmdline_user_args().has("--production-only"): return
	# A new theme identity uses only data and an existing structural model.
	var saved_registry := Themes.definition.duplicate(true)
	var profile: Dictionary = Themes.profile("coral_reef").duplicate(true)
	var catalog := Assets.load_sprite_catalog(Themes.sprite_catalog_path("coral_reef"))
	var definition: Dictionary = catalog.definition.duplicate(true)
	definition.theme_id = "future_theme"
	definition.id = "future-theme-tier1"
	for family: String in definition.families:
		for collection: String in ["bases", "decorations"]:
			definition.families[family][collection] = catalog.families[family][collection].map(func(record): return record.path)
	DirAccess.make_dir_recursive_absolute("res://build")
	var fixture := "res://build/future-theme-tier1.json"
	var file := FileAccess.open(fixture, FileAccess.WRITE)
	file.store_string(JSON.stringify(definition))
	file.close()
	profile.tier1_artwork.catalog = fixture
	Themes.definition.themes.future_theme = profile
	var model := Coral.new()
	model.build(pair, pair)
	var future_layer := Layer.new()
	root.add_child(future_layer)
	check(future_layer.prepare(model, "future_theme", pair, true, false, 0, true, 0), "Future theme binds through JSON without a theme-specific code branch")
	var future_state := State.new()
	future_state.reconcile(model.sprite_growth_events, model.duration, 0, true)
	check(not future_layer.plans.is_empty() and future_layer.present(future_state, Transform2D.IDENTITY), "Future theme uses the same renderer and timing")
	# A custom base fade can outlast both structural timing and its overlays.
	Themes.definition.themes.future_theme.tier1_artwork.merge({"source_layout": "shared_edges", "logical_color": 1, "family": "default", "duration_sec": 2.0}, true)
	check(future_layer.prepare(model, "future_theme", Rules.empty_board(5), false, false, 0, true, 0), "Custom shared-edge source binds")
	check(future_layer.plans.size() == 1 and future_layer.timeline.snapshot().visual_duration < model.sprite_visual_duration and is_equal_approx(model.sprite_visual_duration, 2.0), "Base reveal tail contributes to visual gate without changing structural duration")
	future_layer.queue_free()
	Themes.definition = saved_registry
	DirAccess.remove_absolute(fixture)
	for overrides: Dictionary in [{"source_layout": "unknown"}, {"source_layout": "components", "component_ports": {}}, {"size_cells": [0, 1]}, {"duration_sec": -1}, {"logical_color": 3}]:
		var invalid := saved_registry.duplicate(true)
		invalid.themes.coral_reef.tier1_artwork.merge(overrides, true)
		check(not Themes.validate(invalid).is_empty(), "Malformed runtime binding is rejected")
