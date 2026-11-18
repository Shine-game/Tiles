class_name CoralVisuals
extends Node2D

const Junctions = preload("res://scripts/pattern/junction_layer.gd")
const Topology = preload("res://scripts/pattern/topology.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Components = preload("res://scripts/pattern/component_renderer.gd")
const Ordinary = preload("res://scripts/coral_sets.gd")
const Model = preload("res://scripts/coral_growth.gd")
const GROUND_SURFACE = preload("res://shaders/ground_surface.gdshader")
static var textures: Dictionary = {}
var generative_tier1 := false
var components := Components.new()
var registry: Dictionary = components.nodes
var groups: Dictionary = {}
var ordinals: Dictionary = {}
var next_ordinal := 0
var active: Dictionary = components.active
var ground_sprites: Array[Sprite2D] = []
var surface_signature: Array = []

static func texture(path: Variant) -> Texture2D:
	if not path is String: return Assets.resolve(path, Model.ROOT)
	if not textures.has(path):
		textures[path] = Assets.texture(path, Model.ROOT)
	return textures[path]

func clear() -> void:
	components.clear()
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	registry.clear()
	ground_sprites.clear()
	surface_signature.clear()
	groups.clear()
	ordinals.clear()
	active.clear()
	next_ordinal = 0

func _group(event: Dictionary, restored: bool) -> Node2D:
	var identity: String
	if event.id.begins_with("colony_"):
		identity = Model.key("colony", event.color, Vector2i(event.center) - Vector2i.ONE)
	elif event.id.begins_with("anemone_"):
		identity = event.feature
	else:
		identity = "bucket/%d" % event.bucket
	if not groups.has(identity):
		var node := Node2D.new()
		node.z_index = int(Ordinary.part(event.id).group_z_index) if Ordinary.owns(event.id) else (int(Ordinary.special_part(event.id).group_z_index) if event.id.begins_with("anemone_") else int(event.bucket / 10))
		add_child(node)
		groups[identity] = node
		if not ordinals.has(identity) or (not restored and not event.old):
			ordinals[identity] = next_ordinal
			next_ordinal += 1
	return groups[identity]

func reconcile(model, settled: bool, preserve: bool = true) -> void:
	if not preserve:
		clear()
	components.remove_missing(model.components.keys())
	active.clear()
	components.reveal_bindings.clear()
	ground_sprites.clear()
	surface_signature.clear()
	for identity: String in model.components:
		var event: Dictionary = model.components[identity]
		if generative_tier1 and event.id.begins_with("arm_"):
			components.remove(identity)
			continue
		var ordinary: bool = Ordinary.owns(event.id)
		var cell := Vector2i(event.center - Vector2.ONE * 0.5)
		if ordinary and Ordinary.centers(Topology.neighbor_mask(model.board, cell)).has(event.id) and Junctions.handles("coral_reef", Topology.shape(Topology.neighbor_mask(model.board, cell))):
			components.remove(identity)
			continue
		var placement: Dictionary
		placement = Ordinary.render_spec(event, settled) if ordinary else Ordinary.special_render_spec(event, settled)
		var sprite: Sprite2D = components.ensure(identity, placement, _group(event, settled))
		if ordinary:
			if not (settled or event.old): components.reveal(identity, event, "clock_seconds")
		elif event.id.begins_with("ground_"):
			ground_sprites.append(sprite)
			if sprite.material == null:
				var surface := Components.material(GROUND_SURFACE)
				sprite.material = surface
			sprite.material.set_shader_parameter("cell_center", event.center)
			sprite.material.set_shader_parameter("quarter_turn", float(event.rotation))
		elif not (settled or event.old):
			components.reveal(identity, event, "clock_seconds")
	for identity: String in groups.keys():
		if groups[identity].get_child_count() == 0:
			var group: Node2D = groups[identity]
			remove_child(group)
			group.queue_free()
			groups.erase(identity)
	_sort_groups()

func _sort_groups() -> void:
	var identities: Array = groups.keys()
	identities.sort_custom(func(a: String, b: String): return int(ordinals[a]) < int(ordinals[b]))
	for i in range(identities.size()):
		move_child(groups[identities[i]], i)

func copy_order(source: CoralVisuals) -> void:
	ordinals = source.ordinals.duplicate()
	next_ordinal = source.next_ordinal
	_sort_groups()

func advance(clock: float) -> void:
	components.advance(clock)

func configure_surface(platform) -> void:
	var signature: Array = [platform.mask_texture, platform.mask_revision, platform.grid_size, platform.cell_pixels]
	if signature == surface_signature:
		return
	surface_signature = signature
	for sprite: Sprite2D in ground_sprites:
		sprite.material.set_shader_parameter("occupancy_mask", platform.mask_texture)
		sprite.material.set_shader_parameter("grid_size", platform.grid_size)
		sprite.material.set_shader_parameter("cell_pixels", 256.0)
		sprite.material.set_shader_parameter("submerged", true)
		sprite.material.set_shader_parameter("screen_pixel", 256.0 / platform.cell_pixels)
