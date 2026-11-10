class_name ClockworkVisuals
extends Node2D

signal cue(kind: String)
const Model = preload("res://scripts/clockwork_growth.gd")
const RISE = preload("res://shaders/clockwork_rise.gdshader")
const REVEAL = preload("res://shaders/clockwork_reveal.gdshader")
const CHAIN = preload("res://shaders/clockwork_chain.gdshader")
const GROUND = preload("res://shaders/ground_surface.gdshader")
const OMEGA := TAU / 6.0
static var textures: Dictionary = {}
var registry: Dictionary = {}
var chain_nodes: Dictionary = {}
var grounds: Array[Sprite2D] = []
var wheel_caps: Array = []
var vent_shutters: Array = []
var settling_cores: Dictionary = {}
var ground_signature: Array = []
var model: ClockworkGrowth
var visual_clock := 0.0
var motion_clock := 0.0
var fx_clock := 0.0
var core_speed: Dictionary = {}
var cap_angles: Dictionary = {}
var gear_speed: Dictionary = {}
var operating := true # Policy hook: symmetry-gated running is deliberately deferred.
var core_angles: Dictionary = {}
var gear_angles: Dictionary = {}
var retiring: Array = []
var retire_duration := 0.0
var announced: Dictionary = {}
var puffs: Array = []
var fx: FXLayer
var shadows: FXLayer
var last_exhaust := -10.0
var last_click := -10.0
var last_clunk := -10.0

class FXLayer extends Node2D:
	var items: Array = []
	func _draw() -> void:
		for item: Dictionary in items:
			if item.has("texture"):
				draw_texture_rect(item.texture, Rect2(item.center - item.size * 0.5, item.size), false, Color(1, 1, 1, item.alpha))
			else:
				draw_circle(item.center, item.radius, Color(0.10, 0.08, 0.05, item.alpha), true, -1, true)

static func texture(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path] = load(Model.ROOT + path)
	return textures[path]

func _init() -> void:
	shadows = FXLayer.new()
	shadows.z_index = 3
	add_child(shadows)
	fx = FXLayer.new()
	fx.z_index = 9
	add_child(fx)

func clear() -> void:
	for entry: Dictionary in registry.values():
		entry.node.queue_free()
	for entry: Dictionary in chain_nodes.values():
		entry.node.queue_free()
	for entry: Dictionary in retiring:
		entry.node.queue_free()
	registry.clear()
	chain_nodes.clear()
	retiring.clear()
	grounds.clear()
	wheel_caps.clear()
	vent_shutters.clear()
	core_angles.clear()
	core_speed.clear()
	cap_angles.clear()
	gear_speed.clear()
	settling_cores.clear()
	gear_angles.clear()
	puffs.clear()
	motion_clock = 0
	fx_clock = 0
	last_click = -10
	last_clunk = -10
	last_exhaust = -10

static func layer(id: String) -> int:
	if id.begins_with("plate_"): return 0
	if id == "T01": return 1
	if id in ["C01", "T02", "T03", "pin"]: return 2
	if id in ["C02", "C03"]: return 3
	if id == "L01": return 4
	if id == "L02": return 5
	if id == "L03": return 6
	if id in ["J00_chain_junction", "H03_opaque_underlay"]: return 8
	return 9

func _remove(entry: Dictionary, animate: bool) -> void:
	if not animate or entry.event.id.begins_with("plate_") or entry.event.id == "pin":
		entry.node.queue_free()
		return
	var delay: float = float(9 - mini(9, layer(entry.event.id))) * 0.025
	if entry.event.id == "chain": delay = 0.06
	if entry.event.id == "T01":
		var ink := ShaderMaterial.new()
		ink.shader = REVEAL
		ink.set_shader_parameter("growth_field", texture("masks/T01_from_core_E.png"))
		ink.set_shader_parameter("travel_seconds", 0.20)
		entry.node.material = ink
	entry.retire_at = delay
	entry.retire_end = delay + 0.20
	entry.initial_alpha = entry.node.modulate.a
	entry.initial_rise = _progress(entry.event, visual_clock)
	retiring.append(entry)
	retire_duration = maxf(retire_duration, entry.retire_end)

func reconcile(next: ClockworkGrowth, settled: bool, preserve: bool, reverse: bool = false) -> void:
	if not preserve:
		clear()
	for entry: Dictionary in retiring:
		entry.node.queue_free()
	retiring.clear()
	retire_duration = 0
	var previous_clock: float = visual_clock
	var previous: ClockworkGrowth = model
	if preserve and previous != null and (not settled or reverse):
		for cell: Vector2i in next.mechanisms:
			if previous.mechanisms.has(cell):
				var old: Dictionary = previous.mechanisms[cell]
				if next.mechanisms[cell].old and not old.old and previous_clock < old.ready:
					next.mechanisms[cell].old = false
					next.mechanisms[cell].start = old.start - previous_clock
					next.mechanisms[cell].ready = old.ready - previous_clock
	settling_cores.clear()
	if reverse and previous != null:
		for cell: Vector2i in previous.powered:
			if next.arrivals.has(cell) and not next.powered.has(cell): settling_cores[cell] = 1.0
		for identity: String in next.chains:
			var event: Dictionary = next.chains[identity]
			if chain_nodes.has(identity) and event.old:
				var active: Dictionary = chain_nodes[identity].event
				if not active.old and previous_clock < active.end:
					event = active.duplicate()
					event.start -= previous_clock
					event.end -= previous_clock
					next.chains[identity] = event
					next.duration = maxf(next.duration, event.end)
		for mechanism: Dictionary in next.mechanisms.values(): mechanism.chain_end = -100.0
		for chain: Dictionary in next.chains.values():
			next.mechanisms[chain.a].chain_end = maxf(next.mechanisms[chain.a].chain_end, chain.end)
			next.mechanisms[chain.b].chain_end = maxf(next.mechanisms[chain.b].chain_end, chain.end)
	var events: Dictionary = next.components.duplicate()
	for cell: Vector2i in next.arrivals:
		var ground := Model.ground_choice(cell)
		var id := "plate_%02d" % ground.variant
		events[Model.key("ground", 0, cell)] = {"key": Model.key("ground", 0, cell), "id": id, "color": 0, "center": Vector2(cell) + Vector2.ONE * 0.5, "rotation": ground.rotation * PI / 2, "old": true, "start": -100.0, "seconds": 0.0, "end": -100.0}
	for pin: Dictionary in next.pins:
		var identity := "pin/%d/%d/%d" % [pin.color, pin.corner.y, pin.corner.x]
		var inward: Vector2 = (Vector2(pin.support) + Vector2.ONE * 0.5 - pin.corner).normalized()
		events[identity] = {"key": identity, "id": "pin", "color": pin.color, "center": pin.corner + inward * 0.15, "rotation": 0.0, "old": true, "start": -100.0, "seconds": 0.0, "end": -100.0}
	for identity: String in registry.keys():
		if not events.has(identity):
			var previous_entry: Dictionary = registry[identity]
			if not settled and previous_entry.event.get("terminal", false) and next.mechanisms.has(previous_entry.event.cell) and next.mechanisms[previous_entry.event.cell].has("cap"):
				var mechanism: Dictionary = next.mechanisms[previous_entry.event.cell]
				var replacement: Dictionary = next.components[Model.key("terminal_" + mechanism.cap, mechanism.color, mechanism.origin)]
				_remove(previous_entry, true)
				retiring[-1].retire_at = maxf(0, replacement.start - 0.18)
				retiring[-1].retire_end = replacement.start + 0.02
				retire_duration = maxf(retire_duration, replacement.start + 0.02)
			else:
				_remove(previous_entry, reverse)
			registry.erase(identity)
	for identity: String in chain_nodes.keys():
		if not next.chains.has(identity):
			_remove(chain_nodes[identity], reverse)
			chain_nodes.erase(identity)
	grounds.clear()
	wheel_caps.clear()
	vent_shutters.clear()
	ground_signature.clear()
	for identity: String in events:
		var event: Dictionary = events[identity]
		var entry: Dictionary
		if registry.has(identity):
			entry = registry[identity]
			if preserve and (not settled or reverse) and event.old and not entry.event.old and previous_clock < entry.event.end:
				event = entry.event.duplicate()
				event.start -= previous_clock
				event.end -= previous_clock
				if event.has("edge_start"): event.edge_start -= previous_clock
				next.duration = maxf(next.duration, event.end)
		else:
			var sprite := Sprite2D.new()
			var variant: String = "copper" if event.color == 1 else "gunmetal"
			if event.id.begins_with("plate_"):
				sprite.texture = texture("artwork/ground/" + event.id + ".png")
			elif event.id == "pin":
				sprite.texture = texture("artwork/pins/plate_pin_" + variant + ".png")
			else:
				sprite.texture = texture(Model.specification().components[event.id].assets[variant])
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.position = event.center * 256
			sprite.z_index = layer(event.id)
			add_child(sprite)
			if reverse and event.get("terminal", false):
				event = event.duplicate()
				event.old = false
				event.start = maxf(0.12, next.mechanisms[event.cell].chain_end)
				event.end = event.start + 0.20
				next.duration = maxf(next.duration, event.end)
			entry = {"node": sprite, "event": event}
			registry[identity] = entry
		entry.event = event
		if next.components.has(identity): next.components[identity] = event
		if event.id == "H02_rotating": wheel_caps.append(entry)
		if event.id in ["H03_shutters_left", "H03_shutters_right"]: vent_shutters.append(entry)
		entry.node.rotation = event.rotation
		entry.node.modulate = Color.WHITE
		if event.id.begins_with("plate_"):
			var ink := ShaderMaterial.new()
			ink.shader = GROUND
			ink.set_shader_parameter("cell_center", event.center)
			ink.set_shader_parameter("quarter_turn", event.rotation / (PI / 2))
			entry.node.material = ink
			grounds.append(entry.node)
		elif event.id in ["C01", "C02", "L01", "L02", "L03"]:
			var ink := ShaderMaterial.new()
			ink.shader = RISE
			ink.set_shader_parameter("height_source", 18.0 if event.id == "L02" else (6.0 if event.id == "C01" else 12.0))
			entry.node.material = ink
		elif event.id == "T01" and not (settled or event.old):
			var ink := ShaderMaterial.new()
			ink.shader = REVEAL
			ink.set_shader_parameter("growth_field", texture("masks/T01_from_core_E.png"))
			ink.set_shader_parameter("start_core", event.start)
			ink.set_shader_parameter("start_edge", event.edge_start)
			ink.set_shader_parameter("edge_enabled", true)
			ink.set_shader_parameter("travel_seconds", event.seconds)
			entry.node.material = ink
		else:
			entry.node.material = null
	for identity: String in next.chains:
		var event: Dictionary = next.chains[identity]
		if not chain_nodes.has(identity):
			var parent := Node2D.new()
			parent.position = event.center * 256
			parent.rotation = event.rotation
			parent.z_index = 7
			add_child(parent)
			var strips: Array = []
			for run in range(2):
				var strip := ColorRect.new()
				strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
				strip.position = Vector2(0, (-28 if run == 0 else 28) - 32)
				strip.size = Vector2(256, 64)
				var ink := ShaderMaterial.new()
				ink.shader = CHAIN
				ink.set_shader_parameter("link_art", texture(Model.specification().components.CH01_link.assets["copper" if event.color == 1 else "gunmetal"]))
				ink.set_shader_parameter("reverse_run", run == 1)
				strip.material = ink
				parent.add_child(strip)
				strips.append(strip)
			chain_nodes[identity] = {"node": parent, "event": event, "strips": strips, "moving_since": motion_clock if settled or event.old else -1.0}
		var existing: Dictionary = chain_nodes[identity]
		if preserve and (not settled or reverse) and event.old and not existing.event.old and previous_clock < existing.event.end:
			event = existing.event.duplicate()
			event.start -= previous_clock
			event.end -= previous_clock
			next.duration = maxf(next.duration, event.end)
		existing.event = event
		next.chains[identity] = event
	for cell: Vector2i in core_angles.keys():
		if not next.arrivals.has(cell):
			core_angles.erase(cell)
			core_speed.erase(cell)
	for cell: Vector2i in gear_angles.keys():
		if not next.mechanisms.has(cell):
			gear_angles.erase(cell)
			gear_speed.erase(cell)
	for mechanism: Dictionary in next.mechanisms.values():
		if mechanism.has("cap"):
			mechanism.cap_end = next.components[Model.key("terminal_" + mechanism.cap, mechanism.color, mechanism.origin)].end
	for identity: String in cap_angles.keys():
		if not registry.has(identity): cap_angles.erase(identity)
	model = next
	visual_clock = 0
	announced.clear()
	move_child(fx, get_child_count() - 1)
	advance(0)

func configure_surface(platform) -> void:
	var signature: Array = [platform.mask_texture, platform.mask_revision, platform.cell_pixels]
	if signature == ground_signature:
		return
	ground_signature = signature
	for sprite: Sprite2D in grounds:
		sprite.material.set_shader_parameter("occupancy_mask", platform.mask_texture)
		sprite.material.set_shader_parameter("grid_size", platform.grid_size)
		sprite.material.set_shader_parameter("metal_surface", true)
		sprite.material.set_shader_parameter("metal_lip", texture("artwork/ground/edge_lip_2ui.png"))
		sprite.material.set_shader_parameter("cell_pixels", 256.0)
		sprite.material.set_shader_parameter("screen_pixel", 256.0 / platform.cell_pixels)

func _progress(event: Dictionary, clock: float) -> float:
	return 1.0 if event.old else smoothstep(0, 1, clampf((clock - float(event.start)) / maxf(0.001, event.seconds), 0, 1))

func advance(clock: float) -> void:
	visual_clock = clock
	if model == null:
		return
	var disks: Array = []
	for entry: Dictionary in registry.values():
		var event: Dictionary = entry.event
		var sprite: Sprite2D = entry.node
		var progress := _progress(event, clock)
		if event.id == "T01":
			# An incoming front can finish before this cell emits its own front.
			# The reveal shader owns tube visibility; generic start-time fading
			# would hide a completed incoming tube until that later emission.
			sprite.modulate.a = 1.0
			if sprite.material != null:
				if clock >= event.end:
					sprite.material = null
				else:
					sprite.material.set_shader_parameter("visual_clock", clock)
		elif event.id in ["C01", "C02", "L01", "L02", "L03"]:
			sprite.material.set_shader_parameter("rise", progress)
			if event.id == "C02":
				var lift := 0.0
				for support: Vector2i in model.powered.get(event.cell, []):
					var mechanism: Dictionary = model.mechanisms[support]
					lift = maxf(lift, 1.0 if mechanism.old else smoothstep(0, 0.40, clock - mechanism.start))
				if settling_cores.has(event.cell): lift = 1.0 - smoothstep(0, 0.35, clock)
				sprite.material.set_shader_parameter("height_source", 6.0 + 12.0 * lift)
		elif not event.id.begins_with("plate_"):
			sprite.modulate.a = progress
		if event.id in ["C02", "L01", "L03", "L02"] and progress > 0:
			var radius: float = {"C02": 80.0, "L01": 112.0, "L03": 118.0, "L02": 28.0}[event.id]
			disks.append({"center": sprite.position + Vector2(3, 6 + 8 * progress), "radius": radius, "alpha": 0.10 * progress})
		if event.id == "H00_plain_hatch" and not event.get("terminal", false) and model.mechanisms.has(event.cell) and model.mechanisms[event.cell].has("cap"):
			var cap: Dictionary = model.components[Model.key("terminal_" + model.mechanisms[event.cell].cap, event.color, event.cell)]
			var old_cover := false
			for retired: Dictionary in retiring:
				old_cover = old_cover or (retired.event.get("terminal", false) and retired.event.cell == event.cell and clock < retired.retire_end)
			if _progress(cap, clock) >= 0.5 or old_cover:
				sprite.modulate.a = 0
		if not event.old and clock >= event.end and not announced.has(event.key):
			announced[event.key] = true
			if event.id == "T03":
				puff(event.center, true)
			if (event.id in ["T02", "T03", "H00_plain_hatch"] or event.get("terminal", false)) and fx_clock - last_click > 0.075:
				last_click = fx_clock
				cue.emit("click")
			if event.id in ["L01", "L03"] and fx_clock - last_clunk > 0.10:
				last_clunk = fx_clock
				cue.emit("clunk")
	for entry: Dictionary in chain_nodes.values():
		var progress: float = _progress(entry.event, clock)
		if progress >= 0.999 and entry.moving_since < 0:
			entry.moving_since = motion_clock
		for strip: ColorRect in entry.strips:
			strip.material.set_shader_parameter("progress", progress)
			strip.material.set_shader_parameter("travel", maxf(0, motion_clock - entry.moving_since) * 29.32 if entry.moving_since >= 0 else 0.0)
	for entry: Dictionary in retiring:
		var amount: float = 1.0 - smoothstep(entry.retire_at, entry.retire_end, clock)
		entry.node.modulate.a = entry.initial_alpha * amount
		if entry.event.id in ["C01", "C02", "L01", "L02", "L03"]:
			entry.node.material.set_shader_parameter("rise", entry.initial_rise * amount)
		if entry.event.id == "T01":
			entry.node.material.set_shader_parameter("visual_clock", amount * 0.235)
		if entry.event.id == "chain":
			for strip: ColorRect in entry.strips:
				strip.material.set_shader_parameter("progress", amount)
				strip.material.set_shader_parameter("visibility", amount)
		if clock >= entry.retire_end:
			entry.node.hide()
	shadows.items = disks
	shadows.queue_redraw()
	_update_angles(0)

func _update_angles(delta: float) -> void:
	if model == null:
		return
	for cell: Vector2i in model.mechanisms:
		var mechanism: Dictionary = model.mechanisms[cell]
		var awake: bool = mechanism.old or visual_clock >= mechanism.start + 0.40
		if not gear_angles.has(cell): gear_angles[cell] = 0.0
		gear_speed[cell] = move_toward(float(gear_speed.get(cell, 0)), 1.0 if awake and operating else 0.0, delta * 3.0)
		gear_angles[cell] += OMEGA * delta * gear_speed[cell]
		for id: String in ["L01", "L03"]:
			var identity := Model.key(id, mechanism.color, cell)
			if registry.has(identity):
				registry[identity].node.rotation = gear_angles[cell]
				registry[identity].node.material.set_shader_parameter("turn_angle", gear_angles[cell])
	for cell: Vector2i in model.arrivals:
		var awake := false
		for support: Vector2i in model.powered.get(cell, []):
			var mechanism: Dictionary = model.mechanisms[support]
			awake = awake or mechanism.old or visual_clock >= mechanism.start + 0.40
		if not core_angles.has(cell): core_angles[cell] = 0.0
		core_speed[cell] = move_toward(float(core_speed.get(cell, 0)), 1.0 if awake and operating else 0.0, delta * 3.0)
		core_angles[cell] -= OMEGA * 1.4 * delta * core_speed[cell]
		var identity := Model.key("C02", Model.value(model.board, cell), cell)
		if registry.has(identity):
			registry[identity].node.rotation = core_angles[cell]
			registry[identity].node.material.set_shader_parameter("turn_angle", core_angles[cell])
	for entry: Dictionary in wheel_caps:
		if entry.event.id == "H02_rotating" and _progress(entry.event, visual_clock) >= 0.99:
			var identity: String = entry.event.key
			if not cap_angles.has(identity): cap_angles[identity] = 0.0
			if operating: cap_angles[identity] += delta * TAU / 20
			entry.node.rotation = cap_angles[identity]

func puff(center: Vector2, seal: bool = false) -> void:
	if puffs.size() >= 2:
		return
	puffs.append({"center": center * 256, "born": fx_clock, "seal": seal})
	cue.emit("steam")

func _process(delta: float) -> void:
	if not is_visible_in_tree() or model == null:
		return
	fx_clock += delta
	if operating: motion_clock += delta
	_update_angles(delta)
	for entry: Dictionary in chain_nodes.values():
		if entry.moving_since >= 0:
			for strip: ColorRect in entry.strips:
				strip.material.set_shader_parameter("travel", (motion_clock - entry.moving_since) * 29.32)
	if operating and motion_clock - last_exhaust > 3.2:
		var vents: Array = []
		for mechanism: Dictionary in model.mechanisms.values():
			if mechanism.get("cap", "") == "H03_exhaust" and (mechanism.old or visual_clock >= mechanism.get("cap_end", INF)):
				vents.append(mechanism)
		if not vents.is_empty():
			var slot: int = int(motion_clock / 3.2) % vents.size()
			puff(vents[slot].center)
			last_exhaust = motion_clock
	puffs = puffs.filter(func(item: Dictionary): return fx_clock - item.born < (0.28 if item.seal else 1.1))
	var particles: Array = []
	for item: Dictionary in puffs:
		var life: float = clampf((fx_clock - item.born) / (0.28 if item.seal else 1.1), 0, 1)
		var width: float = lerpf(28, 55, life) if item.seal else lerpf(52, 90, life)
		particles.append({"texture": texture("artwork/ground/steam_%d.png" % mini(2, int(life * 3))), "center": item.center - Vector2(0, life * (28 if item.seal else 50)), "size": Vector2.ONE * width, "alpha": sin(life * PI) * (0.32 if item.seal else 0.22)})
	for entry: Dictionary in vent_shutters:
		if entry.event.id in ["H03_shutters_left", "H03_shutters_right"]:
			var opening := 0.0
			for puff_event: Dictionary in puffs:
				if not puff_event.seal and puff_event.center.is_equal_approx(entry.event.center * 256):
					var age: float = fx_clock - puff_event.born
					opening = smoothstep(0, 0.15, age) * (1.0 - smoothstep(0.75, 1.1, age))
			entry.node.position = entry.event.center * 256 + Vector2((-12 if entry.event.id.ends_with("left") else 12) * opening, 0)
	fx.items = particles
	fx.queue_redraw()

# Gallery art shares the exact phase of the live mechanism, then remains still.
func copy_motion(source: ClockworkVisuals) -> void:
	motion_clock = source.motion_clock
	fx_clock = source.fx_clock
	core_angles = source.core_angles.duplicate()
	gear_angles = source.gear_angles.duplicate()
	cap_angles = source.cap_angles.duplicate()
	core_speed = source.core_speed.duplicate()
	gear_speed = source.gear_speed.duplicate()
	for identity: String in chain_nodes:
		if source.chain_nodes.has(identity): chain_nodes[identity].moving_since = source.chain_nodes[identity].moving_since
	advance(visual_clock)
	set_process(false)
