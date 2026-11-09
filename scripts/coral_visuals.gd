class_name CoralVisuals
extends Node2D

const Model = preload("res://scripts/coral_growth.gd")
const REVEAL = preload("res://art/themes/coral_reef/growth_reveal.gdshader")
static var textures: Dictionary = {}
var registry: Dictionary = {}
var groups: Dictionary = {}
var ordinals: Dictionary = {}
var next_ordinal := 0
var active: Dictionary = {}

static func texture(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path] = load(Model.ROOT + path)
	return textures[path]

func clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	registry.clear()
	groups.clear()
	ordinals.clear()
	active.clear()
	next_ordinal = 0

func _group(event: Dictionary, restored: bool) -> Node2D:
	var identity: String
	if event.id.begins_with("colony_"):
		identity = Model.key("colony", event.color, Vector2i(event.center) - Vector2i.ONE)
	elif event.id.begins_with("union_"):
		identity = event.key
	else:
		identity = "bucket/%d" % event.bucket
	if not groups.has(identity):
		var node := Node2D.new()
		node.z_index = 4 if event.id.begins_with("colony_") else int(event.bucket / 10)
		add_child(node)
		groups[identity] = node
		if not ordinals.has(identity) or (not restored and not event.old):
			ordinals[identity] = next_ordinal
			next_ordinal += 1
	return groups[identity]

func reconcile(model, settled: bool, preserve: bool = true) -> void:
	if not preserve:
		clear()
	for identity: String in registry.keys():
		if not model.components.has(identity):
			var sprite: Sprite2D = registry[identity]
			sprite.get_parent().remove_child(sprite)
			sprite.queue_free()
			registry.erase(identity)
	active.clear()
	for identity: String in model.components:
		var event: Dictionary = model.components[identity]
		var sprite: Sprite2D
		if registry.has(identity):
			sprite = registry[identity]
		else:
			var meta: Dictionary = Model.specification().components[event.id]
			var variant: String = "salmon" if event.color == 1 else "turquoise"
			sprite = Sprite2D.new()
			sprite.texture = texture(meta.artwork[variant])
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			sprite.position = event.center * 256
			sprite.rotation = event.rotation * PI / 2
			# Child insertion order keeps each complete colony together.
			_group(event, settled).add_child(sprite)
			registry[identity] = sprite
		if settled or event.old:
			sprite.material = null
		else:
			var material := ShaderMaterial.new()
			material.shader = REVEAL
			material.set_shader_parameter("artwork", sprite.texture)
			material.set_shader_parameter("growth_mask", texture(Model.specification().components[event.id].reveal_mask))
			material.set_shader_parameter("start_at_zero", event.start)
			material.set_shader_parameter("start_at_one", event.reverse)
			material.set_shader_parameter("stroke_seconds", event.stroke)
			material.set_shader_parameter("front_one_enabled", event.two_fronts)
			sprite.material = material
			active[identity] = event
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
	for identity: String in active.keys():
		var sprite: Sprite2D = registry[identity]
		if clock >= float(active[identity].end):
			# Completed artwork is ordinary batched sprite drawing; only growing
			# components retain private mutable shader materials and CPU updates.
			sprite.material = null
			active.erase(identity)
		else:
			(sprite.material as ShaderMaterial).set_shader_parameter("clock_seconds", clock)
