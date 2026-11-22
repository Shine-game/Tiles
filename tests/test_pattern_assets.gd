extends SceneTree
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Renderer = preload("res://scripts/pattern/component_renderer.gd")
const State = preload("res://scripts/pattern/component_state.gd")
const Coral = preload("res://scripts/coral_growth.gd")
const Clock = preload("res://scripts/clockwork_growth.gd")
const PATH := "res://assets/themes/clockwork/sprites/tier0/clockwork_tier0_core_component_color1_01.png"
var checks := 0
var failures := 0
var builds := 0
class Dot extends Node2D:
	func _draw() -> void: draw_circle(Vector2.ZERO, 8, Color.GREEN)
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	_run.call_deferred()
func _generated(params: Dictionary) -> Texture2D:
	builds += 1
	var image := Image.create(params.size, params.size, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)
func _dot(_spec: Dictionary) -> CanvasItem: return Dot.new()
func _material(_params: Dictionary) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform vec4 tint = vec4(1.0); uniform float clock_seconds = 0.0; void fragment() { COLOR *= tint; }"
	return Renderer.material(shader)
func _draw_probe(view) -> void: view.set_meta("draw_called", true)
func _run() -> void:
	check(Assets.validate(PATH).is_empty(), "Valid original textures pass validation")
	check(Assets.texture(PATH) == Assets.texture("clockwork_tier0_core_component_color1_01.png", "res://assets/themes/clockwork/sprites/tier0/"), "One canonical resource is cached across relative and absolute paths")
	check(not Assets.validate("res://missing.png").is_empty(), "Missing required texture paths are diagnosed")
	check(not Assets.validate({"status": "invented"}).is_empty(), "Unknown availability is rejected")
	check(Assets.resolve({"status": "missing"}) == null and Assets.resolve({"status": "unused"}) == null, "Explicitly absent optional art draws nothing without substitution")
	check(not Assets.validate({"status": "missing", "required": true}).is_empty(), "A required missing slot prevents enabling its set")
	check(not Assets.validate("res://scripts/main.gd").is_empty() and not Assets.validate("user://image.png").is_empty(), "Artwork data cannot load code or external storage")
	check(not Assets.validate({"provider": "unregistered.script", "params": {}}).is_empty(), "Data cannot execute an unregistered provider")
	var atlas := {"provider": "atlas", "path": PATH, "region_px": [10, 20, 70, 80]}
	var region := Assets.resolve(atlas)
	check(region is AtlasTexture and region.get_size() == Vector2(70, 80) and region.filter_clip, "Atlas regions use original source pixels and clipped filtering")
	check(region == Assets.resolve(atlas), "Identical atlas regions share an immutable cached resource")
	check(not Assets.validate({"provider": "atlas", "path": PATH, "region_px": [250, 250, 30, 30]}).is_empty(), "Out-of-bounds atlas selections fail validation")
	Assets.register_provider("test.generated", _generated, func(params): return [] if params.get("size",0) > 0 else ["Positive size required"])
	var generated := {"provider": "test.generated", "params": {"size": 12}}
	check(Assets.resolve(generated) == Assets.resolve(generated) and builds == 1, "Registered procedural textures are cached by parameters")
	check(not Assets.validate({"provider":"test.generated","params":{"size":0}}).is_empty(), "Procedural parameters are validated before generation")
	var sample := Assets.load_set("res://docs/shared-pattern-engine/examples/clockwork-tier0.example.json")
	check(sample.ok, "The documented versioned multipart set loads using actual project assets")
	var parent := Node2D.new()
	root.add_child(parent)
	var renderer := Renderer.new()
	check(renderer.compose(sample, "isolated", parent), "The common renderer instantiates a multipart composition")
	check(renderer.nodes.size() == 3, "The example creates exactly its socket, wheel and axle")
	var key := "clockwork-copper-tier0-example/isolated/wheel"
	var wheel: Sprite2D = renderer.nodes[key]
	var id := wheel.get_instance_id()
	check(wheel.position == Vector2(128, 128) and wheel.offset == Vector2.ZERO, "Cell placement and explicit source-pixel pivots agree")
	check(renderer.compose(sample, "isolated", parent) and renderer.nodes[key].get_instance_id() == id, "Reconciliation keeps surviving component nodes")
	var malformed: Dictionary = sample.definition.duplicate(true)
	malformed.compositions.isolated.parts.wheel.asset.path = "res://missing.png"
	check(not Assets.load_set(malformed).ok, "Set validation reports missing required artwork before activation")
	malformed = sample.definition.duplicate(true)
	malformed.id = 12
	check(not Assets.load_set(malformed).ok, "Set identity types are validated before composition")
	malformed = sample.definition.duplicate(true)
	malformed.compositions.isolated.parts.wheel.asset.provider = 12
	check(not Assets.load_set(malformed).ok, "Malformed provider IDs produce diagnostics instead of executing code")
	malformed = sample.definition.duplicate(true)
	malformed.compositions.isolated.parts.wheel.position_cells = ["bad"]
	check(not Assets.load_set(malformed).ok, "Set validation diagnoses malformed placement vectors")
	malformed = sample.definition.duplicate(true)
	malformed.compositions.isolated.parts.wheel.provider = "unregistered.node"
	check(not Assets.load_set(malformed).ok, "Set data cannot select an unknown node provider")
	check(not renderer.sync({"bad": {"asset": "res://missing.png"}}, parent) and renderer.nodes.size() == 3, "An invalid replacement leaves the existing composition intact")
	renderer.clear()
	var spec := {"asset": atlas, "position_cells": [2, 3], "pixels_per_cell": 100, "pivot_px": [5, 6], "quarter_turns": 1, "size_cells": [0.7, 0.8]}
	var placed: Sprite2D = renderer.ensure("placed", spec, parent)
	check(placed.position == Vector2(200, 300) and placed.offset == Vector2(30, 34), "Atlas pivots are region-relative and scale independently of placement")
	check(placed.scale == Vector2.ONE and is_equal_approx(placed.rotation, PI / 2), "Quarter turns and cell-sized artwork normalize without editing pixels")
	Renderer.register_node_provider("test.dot", _dot)
	var dot: Node2D = renderer.ensure("dot", {"provider": "test.dot", "position_px": [7, 9], "scale": [2, 3]}, parent)
	check(dot is Dot and dot.position == Vector2(7, 9) and dot.scale == Vector2(2, 3), "Registered procedural component nodes receive common placement")
	check(Renderer.draw("test.unknown", parent) == false, "Unknown immediate-mode providers are not executed")
	Renderer.register_draw_provider("test.draw", _draw_probe)
	check(Renderer.draw("test.draw", parent) and parent.get_meta("draw_called"), "Registered draw providers keep the host's drawing context")
	Renderer.register_material_provider("test.material", _material)
	var a: Sprite2D = renderer.ensure("a", {"asset": PATH, "material": {"provider": "test.material"}}, parent)
	var b: Sprite2D = renderer.ensure("b", {"asset": PATH, "material": {"provider": "test.material"}}, parent)
	check(a.material != b.material, "Mutable shader materials are private to their components")
	var state := State.new()
	state.reconcile({"a": {"start": 0.0, "end": 1.0, "old": false}}, 1.0)
	state.advance(0.5)
	renderer.advance(state.schedule.clock, state)
	check(is_equal_approx(a.modulate.a, 0.5), "The common renderer can draw shared lifecycle progress")
	state.advance(100)
	renderer.advance(state.schedule.clock, state)
	check(a.modulate.a == 1, "Settled shared-state components draw fully")
	renderer.reveal("a", {"end": 1.0}, "tint", true)
	renderer.advance(1.0)
	check(a.material == null and renderer.active.is_empty(), "Completed reveal shaders are released without deleting the sprite")
	renderer.reveal("b", {"end": 1.0}, "clock_seconds", false)
	renderer.advance(1.0)
	check(b.material != null and b.material.get_shader_parameter("clock_seconds") == 1.0, "A retained reveal material receives its final clock sample")
	state.reconcile({"a": {"start": 0.0, "end": 0.2, "old": false, "retiring": true}}, 0.2)
	state.advance(100)
	renderer.advance(state.schedule.clock, state)
	check(not renderer.nodes.has("a"), "Completed shared-state retirement removes its bound render node")
	var masks := {"masks": {"reveal": {"asset": "res://assets/themes/clockwork/sprites/tier1/masks/clockwork_tier1_mask_from_core_e_color0_01.png", "purpose": "reveal", "channel": "r", "encoding": "linear", "zero": "core", "one": "edge"}}}
	check(Assets.validate_masks(masks).is_empty(), "Masks keep explicit purpose, channel, encoding and zero/one semantics")
	masks.masks.reveal.purpose = "lighting"
	check(not Assets.validate_masks(masks).is_empty(), "The deferred lighting contract is not silently enabled")

	check(renderer.ensure("absent", {"asset": {"status": "missing"}}, parent) == null, "Missing optional parts do not allocate blank substitute nodes")
	renderer.clear()
	parent.queue_free()
	# Release test-owned Callables; production providers are static project code.
	Assets.providers.erase("test.generated")
	Assets.provider_validators.erase("test.generated")
	Renderer.node_providers.erase("test.dot")
	Assets.node_kinds.erase("test.dot")
	Renderer.draw_providers.erase("test.draw")
	Renderer.material_providers.erase("test.material")
	Assets.material_kinds.erase("test.material")
	await process_frame
	print("Pattern assets: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
