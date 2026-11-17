extends SceneTree
const Presenter = preload("res://scripts/pattern/sprite_presenter.gd")
const Planner = preload("res://scripts/pattern/sprite_planner.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Growth = preload("res://scripts/pattern/sprite_growth.gd")
const Renderer = preload("res://scripts/pattern/component_renderer.gd")
const State = preload("res://scripts/pattern/component_state.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var parent := Node2D.new()
	root.add_child(parent)
	for theme: String in ["coral_reef", "clockwork", "vines", "zen_garden"]:
		var catalog := Assets.load_sprite_catalog(Themes.sprite_catalog_path(theme))
		var plan := Planner.new().plan(catalog, "stones" if theme == "zen_garden" else "default", 2, theme, 42)
		check(plan.ok, "Actual plan: " + theme)
		var timeline := Growth.new()
		var timed := timeline.reconcile({theme: plan}, {theme: {"event": {"start": 1.0, "stroke": 2.0, "end": 3.1}}}, {"structural_duration": 3.1})
		check(timed.ok, "Timing: " + theme)
		var state := State.new()
		state.reconcile(timed.events, timed.visual_duration)
		var presenter := Presenter.new()
		check(presenter.reconcile({theme: plan}, timeline.snapshot(), state, parent), "Presentation: " + theme + str(presenter.diagnostics))
		var base_id := Presenter.ROOT + "/" + theme + "/base"
		var base: Sprite2D = presenter.renderer.nodes[base_id]
		check(base.offset == Vector2(-0.5, -0.5) and not base.centered, "Integer source pixel centers")
		check(base.material != null, "Active base uses source arrival field")
		var view := Transform2D(Vector2(180, 30), Vector2(12, 200), Vector2(50, 80))
		check(presenter.set_view_transform(view), "Affine view accepted")
		check(base.global_transform.is_equal_approx(view * plan.base.transform), "Composed base transform")
		for placement: Dictionary in plan.decorations:
			var id := Growth.event_id(placement.id)
			var node: Sprite2D = presenter.renderer.nodes[id]
			check(not node.visible, "Waiting decoration hidden")
			check(node.global_transform.is_equal_approx(view * placement.transform), "Complete decoration transform survives reflection")
			check(node.modulate.a == 1.0, "Reveal does not double fade art")
		var old_nodes := presenter.renderer.nodes.duplicate()
		var bad := timeline.snapshot()
		if not bad.events.is_empty():
			bad.events[bad.events.keys()[0]].revision = "stale"
			check(not presenter.reconcile({theme: plan}, bad, state, parent), "Stale timing rejected")
			check(presenter.renderer.nodes == old_nodes, "Rejected replacement leaves live tree intact")
		var clock: float = state.schedule.clock
		presenter.advance(state)
		check(state.schedule.clock == clock, "Presenter never advances shared clock")
		state.advance(2.0)
		presenter.advance(state)
		check(presenter.reconcile({theme: plan}, timeline.snapshot(), state, parent, view), "Stable refresh")
		check(presenter.renderer.nodes == old_nodes, "Stable identities reuse nodes")
		check(presenter.cache_sizes().arrival_fields == 1, "Field texture reused")
		for placement: Dictionary in plan.decorations:
			var id := Growth.event_id(placement.id)
			var node: Sprite2D = presenter.renderer.nodes[id]
			if node.material != null and state.records[id].phase == "appearing":
				check(node.modulate.a == 1.0, "Partial reveal retains full artwork opacity")
				var fraction: float = node.material.get_shader_parameter("reveal_progress")
				state.records[id].phase = "retiring"
				state.records[id].progress = 0.7
				presenter.advance(state)
				check(node.material.get_shader_parameter("reveal_progress") == fraction and is_equal_approx(node.modulate.a, 0.7), "Retirement freezes reveal and fades opacity")
				state.records[id].phase = "appearing"
				state.records[id].progress = fraction
		var wrong_mask := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_R8))
		check(not presenter.reconcile({theme: plan}, timeline.snapshot(), state, parent, view, {theme: wrong_mask}), "Wrong base mask dimensions rejected")
		check(presenter.renderer.nodes == old_nodes, "Invalid mask preserves existing presentation")
		state.advance(10.0)
		presenter.advance(state)
		check(base.material == null, "Finished base releases material")
		for placement: Dictionary in plan.decorations:
			var node: Sprite2D = presenter.renderer.nodes[Growth.event_id(placement.id)]
			check(node.visible and node.material == null, "Finished decoration is full art")
		check(presenter.reconcile({}, {"version": 1, "components": {}, "events": {}}, state, parent), "Remove all components")
		check(presenter.renderer.nodes.size() == 1, "Only owned root remains")
		presenter.clear()
	check(not Presenter.new().set_view_transform(Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)), "Singular view rejected")
	check(not Renderer.validate_spec({"provider": "group", "source_transform": Transform2D.IDENTITY, "position_px": [1, 2]}).is_empty(), "Mixed placement conventions rejected")
	check(not Renderer.validate_spec({"provider": "group", "source_transform": Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)}).is_empty(), "Singular source transform rejected")
	parent.queue_free()
	print("Sprite presenter: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
