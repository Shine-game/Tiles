class_name PatternTier1Layer
extends Node2D

const Sources = preload("res://scripts/pattern/tier1_sources.gd")
const Planner = preload("res://scripts/pattern/sprite_planner.gd")
const Timing = preload("res://scripts/pattern/sprite_growth.gd")
const Presenter = preload("res://scripts/pattern/sprite_presenter.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Palette = preload("res://scripts/palette.gd")
var planner := Planner.new()
var timeline := Timing.new()
var presenter := Presenter.new()
var plans: Dictionary = {}
var diagnostics: Array = []
var theme_id := ""
var retirements: Dictionary = {}
var retire_root: Node2D
var _treatments: Dictionary = {}

func clear() -> void:
	presenter.clear()
	planner.clear()
	timeline.reset()
	plans.clear()
	_treatments.clear()
	_clear_retirements()

func _clear_retirements() -> void:
	for entry: Dictionary in retirements.values():
		if is_instance_valid(entry.node): entry.node.queue_free()
	retirements.clear()

func _retire_removed(next_plans: Dictionary) -> void:
	if retire_root == null:
		retire_root = Node2D.new()
		add_child(retire_root)
	for id: String in plans:
		if next_plans.has(id): continue
		var group_id := Presenter.ROOT + "/" + id
		var node: Node2D = presenter.renderer.nodes.get(group_id)
		if not is_instance_valid(node): continue
		# Release the entire composed subtree without changing its current
		# materials. Partial masks freeze at the last shared-clock sample.
		for placement: Dictionary in plans[id].decorations: presenter.renderer.release(Timing.event_id(placement.id))
		presenter.renderer.release(group_id + "/base")
		presenter.renderer.release(group_id)
		node.reparent(retire_root, false)
		var key := "sprite-retire/" + id
		retirements[key] = {"node": node, "event": {"start": 0.0, "end": 0.35, "old": false, "retiring": true, "owner": id}}

# Prepare timing before the host collects construction events. Existing structural
# starts and dependencies are never moved by decoration tails.
func prepare(model, theme: String, before: Array, settled: bool, preserve: bool, at: float, restart: bool, elapsed: float, reverse: bool = false) -> bool:
	diagnostics.clear()
	if theme != theme_id or not preserve:
		clear()
		theme_id = theme
	if not Sources.active(theme):
		clear()
		return true
	var catalog := Assets.load_sprite_catalog(Themes.sprite_catalog_path(theme), "res://", theme)
	if not catalog.ok:
		diagnostics.append_array(catalog.errors)
		return false
	var next_plans: Dictionary = {}
	var bindings: Dictionary = {}
	var treatments: Dictionary = {}
	for item: Dictionary in Sources.descriptors(model, theme, before):
		item.context.include_footprints = false
		var plan := planner.plan(catalog, item.family, item.color, item.id, int(Themes.profile(theme).tier1_artwork.get("seed", 10973)), item.context)
		if not plan.ok:
			diagnostics.append_array(plan.errors)
			return false
		next_plans[item.id] = plan
		bindings[item.id] = item.binding
		if catalog.definition.get("palette", {}).get("runtime_palette_policy") == "hsv_relative_to_source_palette":
			var colors: Dictionary = catalog.definition.palette.get("source_colors", {})
			if not colors.has(str(item.color)):
				diagnostics.append("Palette catalog needs a source color for each logical color")
				return false
			var source := Color(colors[str(item.color)])
			treatments[item.id] = {"source_color": source, "target_color": Palette.pigment(item.color)}
	var result := timeline.reconcile(next_plans, bindings, {"at": at, "elapsed": elapsed, "restart": restart, "settled": settled, "preserve": preserve, "structural_duration": model.duration})
	if not result.ok:
		diagnostics.append_array(result.errors)
		return false
	if restart: _clear_retirements()
	if reverse: _retire_removed(next_plans)
	plans = next_plans
	_treatments = treatments
	model.sprite_growth_events = result.events
	model.sprite_visual_duration = result.visual_duration
	if not settled:
		for component: Dictionary in timeline.snapshot().components.values():
			if not component.field.old: model.sprite_visual_duration = maxf(model.sprite_visual_duration, component.field.source_end)
	z_index = int(Themes.profile(theme).tier1_artwork.get("layer_z_index", 1))
	return true

func retirement_events() -> Dictionary:
	var result: Dictionary = {}
	for id: String in retirements: result[id] = retirements[id].event
	return result

func present(state, view_transform: Transform2D) -> bool:
	var okay := presenter.reconcile(plans, timeline.snapshot(), state, self, view_transform, {}, _treatments)
	if not okay: diagnostics.append_array(presenter.diagnostics)
	if Themes.profile(theme_id).get("tier1_artwork", {}).has("decoration_z_index"):
		# Immediate holding motifs, links and flowers remain above ordinary vines.
		for plan: Dictionary in plans.values():
			for placement: Dictionary in plan.decorations:
				var node = presenter.renderer.nodes.get(Timing.event_id(placement.id))
				if is_instance_valid(node): node.z_index = int(Themes.profile(theme_id).tier1_artwork.decoration_z_index)
	set_view_transform(view_transform)
	advance(state)
	return okay

func set_view_transform(value: Transform2D) -> void:
	presenter.set_view_transform(value)
	if retire_root != null: retire_root.transform = value

func advance(state) -> void:
	presenter.advance(state)
	for id: String in retirements.keys():
		var entry: Dictionary = retirements[id]
		if not state.records.has(id):
			entry.node.queue_free()
			retirements.erase(id)
		else: entry.node.modulate.a = state.records[id].progress
