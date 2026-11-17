class_name PatternSpriteGrowth
extends RefCounted

const Timing = preload("res://scripts/pattern/growth_schedule.gd")
const VERSION := 1
const EPSILON := 0.000001
var _events: Dictionary = {}
var _components: Dictionary = {}
var _structural_duration := 0.0
var _visual_duration := 0.0

static func event_id(placement_id: String) -> String:
	return "sprite/" + placement_id

static func _number(value: Variant, nonnegative: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and (not nonnegative or value >= 0)

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "errors": [message]}

static func _front(start: Variant, origin: Variant, seconds: Variant) -> Dictionary:
	if not _number(start) or not _number(origin) or origin < 0 or origin > 1 or not _number(seconds, true): return _fail("Front requires finite start, origin_u in [0,1], and nonnegative seconds")
	if not is_finite(float(start) + float(seconds)) or not is_finite(float(start) - float(seconds)): return _fail("Front times exceed the supported clock range")
	return {"ok": true, "front": {"start": float(start), "origin_u": float(origin), "seconds": float(seconds)}}

static func source_field(binding: Dictionary, settled: bool = false) -> Dictionary:
	for key: Variant in binding:
		if key not in ["event", "u_range", "stroke_seconds", "replay", "settled"]: return _fail("Unknown sprite timing binding field: " + str(key))
	if not binding.get("event") is Dictionary: return _fail("Sprite timing binding needs a source event")
	for key: String in ["replay", "settled"]:
		if binding.has(key) and not binding[key] is bool: return _fail(key + " must be boolean")
	var domain: Variant = binding.get("u_range", [0.0, 1.0])
	if domain is Vector2: domain = [domain.x, domain.y]
	if not domain is Array or domain.size() != 2 or not domain.all(func(n): return _number(n) and n >= 0 and n <= 1): return _fail("u_range needs two source-field coordinates in [0,1]")
	var source: Dictionary = binding.event
	if source.has("old") and not source.old is bool: return _fail("Source old flag must be boolean")
	if source.has("two_fronts") and not source.two_fronts is bool: return _fail("Source two_fronts flag must be boolean")
	if binding.has("stroke_seconds") and not _number(binding.stroke_seconds, true): return _fail("stroke_seconds must be finite and nonnegative")
	var old: bool = settled or binding.get("settled", false) or source.get("old", false)
	if old: return {"ok": true, "old": true, "fronts": [], "u_range": domain.duplicate(), "source_end": Timing.SETTLED_AT, "replay": binding.get("replay", false)}
	var fronts: Array = []
	if source.has("fronts"):
		if binding.has("stroke_seconds"): return _fail("Explicit fronts declare their own travel seconds")
		if not source.fronts is Array or source.fronts.is_empty(): return _fail("Explicit fronts must be a nonempty array")
		for item: Variant in source.fronts:
			if not item is Dictionary: return _fail("Each front must be an object")
			var normalized := _front(item.get("start"), item.get("origin_u"), item.get("seconds"))
			if not normalized.ok: return normalized
			fronts.append(normalized.front)
	else:
		var seconds: Variant = binding.get("stroke_seconds", source.get("stroke", source.get("seconds", 0.0)))
		var a: Variant = source.get("start")
		var b: Variant = null
		var two: bool = source.get("two_fronts", source.has("edge_start"))
		if source.has("start_a") or source.has("start_b"):
			if not binding.has("stroke_seconds") and not source.has("stroke") and not source.has("seconds"): return _fail("Edge source requires its full stroke_seconds; finish is not travel time")
			a = source.get("start_a")
			b = source.get("start_b")
			two = true
		elif two: b = source.get("reverse", source.get("edge_start"))
		var normalized := _front(a, 0.0, seconds)
		if not normalized.ok: return normalized
		fronts.append(normalized.front)
		if two:
			normalized = _front(b, 1.0, seconds)
			if not normalized.ok: return normalized
			fronts.append(normalized.front)
	var end := Timing.field_end(fronts)
	var supplied: Variant = source.get("end", source.get("finish", end))
	if not _number(supplied) or supplied < end - EPSILON: return _fail("Source completion must not precede the last field arrival")
	return {"ok": true, "old": false, "fronts": fronts, "u_range": domain.duplicate(), "source_end": float(supplied), "replay": binding.get("replay", false)}

static func arrival(field: Dictionary, growth_at: float) -> float:
	if field.old: return Timing.SETTLED_AT
	var u := lerpf(float(field.u_range[0]), float(field.u_range[1]), growth_at)
	return Timing.field_arrival(field.fronts, u)

static func _shift_field(field: Dictionary, elapsed: float) -> Dictionary:
	var result := field.duplicate(true)
	if not result.old:
		for front: Dictionary in result.fronts: front.start -= elapsed
		result.source_end -= elapsed
	return result

static func placement_revision(plan: Dictionary, placement: Dictionary) -> String:
	# Color treatment and view transforms do not replay an existing reveal.
	return var_to_bytes([plan.get("planner_version", 1), plan.base.metadata_path, placement.metadata_path, placement.get("local_transform", Transform2D.IDENTITY), placement.growth_at, placement.rules.animation]).hex_encode().sha256_text()

static func _compile(plan: Dictionary, field: Dictionary) -> Dictionary:
	if not plan.get("ok", false) or not plan.get("component_id") is String or plan.component_id.is_empty() or not plan.get("base") is Dictionary or not plan.base.get("metadata_path") is String or not plan.get("decorations") is Array: return _fail("Expected a successful placement plan with stable component and base identities")
	var events: Dictionary = {}
	for placement: Variant in plan.decorations:
		if not placement is Dictionary or not placement.get("id") is String or not placement.get("metadata_path") is String or not placement.get("rules") is Dictionary or not placement.rules.get("animation") is Dictionary: return _fail("Malformed decoration placement")
		if not placement.id.begins_with(plan.component_id + "/anchor/"): return _fail("Decoration identity does not belong to its component")
		if not _number(placement.get("growth_at")) or placement.growth_at < 0 or placement.growth_at > 1: return _fail("Decoration growth_at must be in [0,1]")
		var animation: Dictionary = placement.rules.animation
		if animation.get("mode") not in ["direct", "progressive"]: return _fail("Unknown decoration animation mode")
		if not _number(animation.get("duration_sec"), true) or animation.duration_sec <= 0: return _fail("Decoration needs a positive reveal duration")
		var duration: float = animation.duration_sec if animation.mode == "progressive" else 0.0
		var start := arrival(field, float(placement.growth_at))
		var end := Timing.SETTLED_AT if field.old else start + duration
		if not is_finite(start) or not is_finite(end): return _fail("Decoration times exceed the supported clock range")
		var id := event_id(placement.id)
		if events.has(id): return _fail("Duplicate decoration timing identity: " + id)
		events[id] = {"start": start, "end": end, "old": field.old, "blocking": true, "replay": field.replay, "owner": plan.component_id, "parent_id": plan.component_id, "placement_id": placement.id, "kind": "sprite_decoration", "mode": animation.mode, "duration_sec": duration, "growth_at": placement.growth_at, "revision": placement_revision(plan, placement), "layout": placement.duplicate(true)}
	return {"ok": true, "events": events}

static func compile(plan: Dictionary, binding: Dictionary, settled: bool = false) -> Dictionary:
	var field := source_field(binding, settled)
	if not field.ok: return field
	return _compile(plan, field)

static func progress(event: Dictionary, clock: float) -> float:
	if event.old: return 1.0
	if event.mode == "direct": return 1.0 if clock >= event.start else 0.0
	return Timing.smooth(event.start, event.duration_sec, clock)

func reset() -> void:
	_events.clear()
	_components.clear()
	_structural_duration = 0.0
	_visual_duration = 0.0

func snapshot() -> Dictionary:
	return {"version": VERSION, "events": _events.duplicate(true), "components": _components.duplicate(true), "structural_duration": _structural_duration, "visual_duration": _visual_duration}

func reconcile(plans: Dictionary, bindings: Dictionary, options: Dictionary = {}) -> Dictionary:
	for key: Variant in options:
		if key not in ["at", "elapsed", "restart", "settled", "preserve", "structural_duration"]: return _fail("Unknown sprite reconciliation option: " + str(key))
	for key: String in ["at", "elapsed", "structural_duration"]:
		if not _number(options.get(key, 0.0), true): return _fail(key + " must be finite and nonnegative")
	for key: String in ["restart", "settled", "preserve"]:
		if options.has(key) and not options[key] is bool: return _fail(key + " must be boolean")
	var at: float = options.get("at", 0.0)
	var elapsed: float = options.get("elapsed", 0.0)
	if not options.get("restart", true) and elapsed != 0: return _fail("A same-clock refresh cannot rebase elapsed time")
	var previous_at := at + elapsed
	if not is_finite(previous_at): return _fail("Reconciliation clock exceeds the supported range")
	var preserve: bool = options.get("preserve", true)
	var settled: bool = options.get("settled", false)
	var next_events: Dictionary = {}
	var next_components: Dictionary = {}
	var delta := {"added": [], "retained": [], "removed": []}
	for id: Variant in plans:
		if (not id is String and not id is StringName) or not plans[id] is Dictionary or plans[id].get("component_id") != id or not bindings.get(id) is Dictionary: return _fail("Each plan needs a matching component ID and source binding")
		var plan: Dictionary = plans[id]
		var component_settled: bool = settled or bindings[id].get("settled", false) == true
		var field := source_field(bindings[id], component_settled)
		if not field.ok: return _fail(id + ": " + str(field.errors))
		var previous: Dictionary = _components.get(id, {}) if preserve else {}
		if not component_settled and not field.replay and field.old and not previous.is_empty() and previous.base_path == plan.get("base", {}).get("metadata_path") and not previous.field.old and previous.field.source_end > previous_at:
			# Board-old is not construction-settled: continue the prior field for
			# waiting anchors and new selections on a surviving partial parent.
			field = _shift_field(previous.field, elapsed)
			field.replay = bindings[id].get("replay", false)
		var compiled := _compile(plan, field)
		if not compiled.ok: return _fail(id + ": " + str(compiled.errors))
		next_components[id] = {"base_path": plan.base.metadata_path, "field": field.duplicate(true)}
		for key: String in compiled.events:
			if next_events.has(key): return _fail("Duplicate sprite event across components: " + key)
			var event: Dictionary = compiled.events[key]
			var old_event: Dictionary = _events.get(key, {}) if preserve else {}
			if not old_event.is_empty() and old_event.revision == event.revision and not field.replay and not component_settled:
				delta.retained.append(key)
				if old_event.old or old_event.end <= previous_at:
					event.old = true
					event.start = Timing.SETTLED_AT
					event.end = Timing.SETTLED_AT
				else:
					var keep := Timing.shifted(old_event, elapsed)
					# A newly valid incoming front can advance a waiting anchor.
					# Once visible, a decoration always completes its own interval.
					if old_event.start <= previous_at or field.old or event.start >= keep.start:
						event.start = keep.start
						event.end = keep.end
						event.old = false
			else: delta.added.append(key)
			next_events[key] = event
	for key: String in _events:
		if not next_events.has(key): delta.removed.append(key)
	var structural: float = options.get("structural_duration", 0.0)
	var duration := structural
	if not settled:
		for event: Dictionary in next_events.values():
			if not event.old: duration = maxf(duration, event.end)
	else: duration = 0.0
	_events = next_events.duplicate(true)
	_components = next_components.duplicate(true)
	_structural_duration = structural
	_visual_duration = duration
	for list: Array in delta.values(): list.sort()
	return {"ok": true, "errors": [], "events": next_events, "delta": delta, "structural_duration": structural, "visual_duration": duration}
