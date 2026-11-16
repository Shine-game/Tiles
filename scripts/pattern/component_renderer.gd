class_name PatternComponentRenderer
extends RefCounted

const Assets = preload("res://scripts/pattern/asset_library.gd")
static var node_providers: Dictionary = {}
static var draw_providers: Dictionary = {}
static var material_providers: Dictionary = {}
var nodes: Dictionary = {}
var active: Dictionary = {}
var reveal_bindings: Dictionary = {}
var diagnostics: Array = []
var kinds: Dictionary = {}
var state_bindings: Dictionary = {}
var external_lifecycle: Dictionary = {}

static func register_node_provider(id: String, factory: Callable) -> void:
	node_providers[id] = factory
	Assets.node_kinds[id] = true

static func register_draw_provider(id: String, draw: Callable) -> void:
	draw_providers[id] = draw

static func register_material_provider(id: String, factory: Callable) -> void:
	material_providers[id] = factory
	Assets.material_kinds[id] = true

static func draw(id: String, view) -> bool:
	if not draw_providers.has(id): return false
	draw_providers[id].call(view)
	return true

static func vector(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2: return value
	if value is Array and value.size() == 2: return Vector2(float(value[0]), float(value[1]))
	return fallback

static func material(shader: Shader, uniforms: Dictionary = {}) -> ShaderMaterial:
	var ink := ShaderMaterial.new()
	ink.shader = shader
	for name: String in uniforms: ink.set_shader_parameter(name, uniforms[name])
	return ink

static func configure_sprite(sprite: Sprite2D, spec: Dictionary) -> void:
	if spec.has("asset"): sprite.texture = Assets.resolve(spec.asset, spec.get("asset_root", "res://"))
	var pixels: float = spec.get("pixels_per_cell", 256.0)
	if spec.has("position_cells"): sprite.position = vector(spec.position_cells) * pixels
	if spec.has("position_px"): sprite.position = vector(spec.position_px)
	if spec.has("centered"): sprite.centered = spec.centered
	if spec.has("pivot_px") and sprite.texture != null:
		var pivot := vector(spec.pivot_px)
		sprite.offset = sprite.texture.get_size() * 0.5 - pivot if sprite.centered else -pivot
	if spec.has("offset_px"): sprite.offset = vector(spec.offset_px)
	if spec.has("scale"): sprite.scale = vector(spec.scale, Vector2.ONE)
	if spec.has("size_cells") and sprite.texture != null: sprite.scale = vector(spec.size_cells) * pixels / sprite.texture.get_size()
	if spec.has("rotation_radians"): sprite.rotation = spec.rotation_radians
	if spec.has("quarter_turns"): sprite.rotation = float(spec.quarter_turns) * PI / 2
	if spec.has("texture_filter"): sprite.texture_filter = spec.texture_filter
	if spec.has("z_index"): sprite.z_index = spec.z_index
	if spec.has("flip_h"): sprite.flip_h = spec.flip_h
	if spec.has("flip_v"): sprite.flip_v = spec.flip_v

static func sprite(spec: Dictionary) -> Sprite2D:
	var result := Sprite2D.new()
	configure_sprite(result, spec)
	return result

static func validate_spec(spec: Dictionary) -> Array:
	var errors: Array = []
	var provider: String = str(spec.get("provider", "sprite"))
	if not Assets.node_kinds.has(provider): errors.append("Unknown node provider: " + provider)
	if provider == "sprite": errors.append_array(Assets.validate(spec.get("asset"), spec.get("asset_root", "res://")))
	errors.append_array(Assets.validate_placement(spec))
	errors.append_array(Assets.validate_masks(spec, spec.get("asset_root", "res://")))
	if spec.has("material") and spec.material != null and not spec.material is ShaderMaterial:
		if not spec.material is Dictionary or not material_providers.has(spec.material.get("provider", "")): errors.append("Unknown material provider")
	return errors

func ensure(id: String, spec: Dictionary, parent: Node) -> CanvasItem:
	var errors := validate_spec(spec)
	if not errors.is_empty():
		diagnostics.append_array(errors)
		return null
	var provider: String = str(spec.get("provider", "sprite"))
	if provider == "sprite" and spec.asset is Dictionary and spec.asset.get("status", "available") != "available":
		remove(id)
		return null
	var placement: Dictionary = spec.duplicate()
	if provider == "sprite":
		placement.asset = Assets.resolve(spec.asset, spec.get("asset_root", "res://"), diagnostics)
		if placement.asset == null: return null
	if nodes.has(id) and kinds[id] != provider: remove(id)
	if not nodes.has(id):
		var node: CanvasItem
		if provider == "sprite": node = sprite(placement)
		elif provider == "group": node = Node2D.new()
		else:
			var candidate: Variant = node_providers[provider].call(spec)
			if not candidate is CanvasItem:
				diagnostics.append("Node provider did not return CanvasItem: " + provider)
				return null
			node = candidate
		if node == null:
			diagnostics.append("Node provider returned no CanvasItem: " + provider)
			return null
		parent.add_child(node)
		nodes[id] = node
		kinds[id] = provider
	external_lifecycle[id] = spec.get("lifecycle", "fade") == "external"
	var result: CanvasItem = nodes[id]
	if result.get_parent() != parent: result.reparent(parent, false)
	if result is Sprite2D: configure_sprite(result, placement)
	elif result is Node2D or result is Control:
		if spec.has("position_cells"): result.position = vector(spec.position_cells) * float(spec.get("pixels_per_cell", 256.0))
		if spec.has("position_px"): result.position = vector(spec.position_px)
		if spec.has("rotation_radians"): result.rotation = spec.rotation_radians
		if spec.has("quarter_turns"): result.rotation = float(spec.quarter_turns) * PI / 2
		if spec.has("scale"): result.scale = vector(spec.scale, Vector2.ONE)
		if result is Control and spec.has("size_cells"): result.size = vector(spec.size_cells) * float(spec.get("pixels_per_cell", 256.0))
		if spec.has("texture_filter"): result.texture_filter = spec.texture_filter
		if spec.has("z_index"): result.z_index = spec.z_index
	if spec.has("material"):
		if spec.material is ShaderMaterial: result.material = spec.material
		elif spec.material == null: result.material = null
		elif spec.material is Dictionary:
			var factory: String = spec.material.get("provider", "")
			if material_providers.has(factory): result.material = material_providers[factory].call(spec.material.get("params", {}))
			else: diagnostics.append("Unknown material provider: " + factory)
	return result

func reveal(id: String, event: Dictionary, clock_uniform: String, clear_on_settled: bool = true) -> void:
	active[id] = event
	reveal_bindings[id] = {"clock_uniform": clock_uniform, "clear_on_settled": clear_on_settled}

func advance(clock: float, state = null) -> void:
	for id: String in active.keys():
		if not nodes.has(id):
			active.erase(id)
			reveal_bindings.erase(id)
			continue
		var node: CanvasItem = nodes[id]
		if clock >= float(active[id].end):
			if reveal_bindings[id].clear_on_settled: node.material = null
			elif node.material != null: node.material.set_shader_parameter(reveal_bindings[id].clock_uniform, clock)
			active.erase(id)
			reveal_bindings.erase(id)
		elif node.material != null: node.material.set_shader_parameter(reveal_bindings[id].clock_uniform, clock)
	if state != null:
		for id: String in nodes.keys():
			if external_lifecycle.get(id, false): continue
			if state.records.has(id):
				state_bindings[id] = true
				nodes[id].modulate.a = state.records[id].progress
			elif state_bindings.has(id): remove(id)

func sync(parts: Dictionary, parent: Node, state = null) -> bool:
	for id: String in parts:
		if not parts[id] is Dictionary:
			diagnostics.append("Part must be a descriptor: " + id)
			return false
		var issues := validate_spec(parts[id])
		if not issues.is_empty():
			diagnostics.append_array(issues)
			return false
	remove_missing(parts.keys())
	for id: String in parts:
		var node := ensure(id, parts[id], parent)
		var absent: bool = parts[id].get("asset") is Dictionary and parts[id].asset.get("status", "available") != "available"
		if node == null and not absent: return false
	if state != null: advance(state.schedule.clock, state)
	return true

func compose(loaded: Dictionary, composition: String, parent: Node, state = null, owner_prefix: String = "", treatment: String = "") -> bool:
	if not loaded.get("ok", false):
		diagnostics.append_array(loaded.get("errors", ["Invalid set"]))
		return false
	if not loaded.definition.compositions.has(composition):
		diagnostics.append("Unknown composition: " + composition)
		return false
	var prefix: String = loaded.definition.id + "/" + composition if owner_prefix.is_empty() else owner_prefix
	var parts: Dictionary = {}
	for id: String in loaded.definition.compositions[composition].parts:
		var bound := Assets.bind_part(loaded.definition.compositions[composition].parts[id], treatment)
		if not bound.ok:
			diagnostics.append_array(bound.errors)
			return false
		var spec: Dictionary = bound.part
		spec.asset_root = loaded.root
		parts[prefix + "/" + id] = spec
	return sync(parts, parent, state)

func release(id: String) -> CanvasItem:
	# A theme retirement hook can keep drawing a removed node without the
	# common owner mistaking it for a surviving construction component.
	var node: CanvasItem = nodes.get(id)
	nodes.erase(id)
	kinds.erase(id)
	active.erase(id)
	reveal_bindings.erase(id)
	state_bindings.erase(id)
	external_lifecycle.erase(id)
	return node

func remove(id: String) -> void:
	var node := release(id)
	if node != null:
		if node.get_parent() != null: node.get_parent().remove_child(node)
		node.queue_free()

func remove_missing(ids: Array) -> void:
	for id: String in nodes.keys():
		if not id in ids: remove(id)

func clear() -> void:
	remove_missing([])
	diagnostics.clear()
