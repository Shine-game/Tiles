class_name CoralAudioPlan
extends RefCounted

const Coral = preload("res://scripts/coral_growth.gd")
const VISIBLE_EPSILON := 0.001
const COALESCE := 0.120

static func stable_hash(members: Array) -> int:
	var ordered: Array = members.duplicate()
	ordered.sort()
	var hashed: int = 2166136261
	for byte: int in "\n".join(ordered).to_utf8_buffer():
		hashed = ((hashed ^ byte) * 16777619) & 0xffffffff
	return hashed

static func build(pattern, placement_id: int, from_clock: float = 0) -> Dictionary:
	var ordinary_start := INF
	var ordinary_end := -1.0
	var raw: Array = []
	var targets: Dictionary = {}
	for event: Dictionary in pattern.components.values():
		if event.old:
			continue
		if event.id == "core" or event.id.begins_with("arm_") or event.id.begins_with("fingers_") or event.id.begins_with("junction_"):
			var first: float = minf(event.start, event.reverse) if event.two_fronts else event.start
			ordinary_start = minf(ordinary_start, first + VISIBLE_EPSILON)
			ordinary_end = maxf(ordinary_end, event.end)
	for origin: Vector2i in pattern.colonies:
		var colony: Dictionary = pattern.colonies[origin]
		var identity := Coral.key("colony", colony.color, origin)
		targets[identity] = true
		if not colony.old and colony.start + VISIBLE_EPSILON >= from_clock:
			raw.append({"kind": "colony", "time": colony.start + VISIBLE_EPSILON, "key": identity})
	for join: Dictionary in pattern.unions.values():
		targets[join.feature] = true
		var old: bool = pattern.colonies[join.a].old and pattern.colonies[join.b].old
		if not old and join.start + VISIBLE_EPSILON >= from_clock:
			raw.append({"kind": "anemone", "time": join.start + VISIBLE_EPSILON, "key": join.feature})
	raw.sort_custom(func(a: Dictionary, b: Dictionary): return a.time < b.time if a.time != b.time else a.key < b.key)
	var cues: Array = []
	var last: Dictionary = {}
	# The visual timeline is already known, so grouping adds no onset delay:
	# each group plays at its first start, hashed over all sorted member keys.
	for event: Dictionary in raw:
		if last.has(event.kind) and event.time - float(last[event.kind].time) <= COALESCE + 0.000001:
			last[event.kind].members.append(event.key)
		else:
			var cue := {"kind": event.kind, "time": event.time, "members": [event.key], "placement": placement_id}
			cues.append(cue)
			last[event.kind] = cue
	for cue: Dictionary in cues:
		cue.members.sort()
		cue.hash = stable_hash(cue.members)
	cues.sort_custom(func(a: Dictionary, b: Dictionary): return a.time < b.time)
	return {"ordinary_start": ordinary_start, "ordinary_end": ordinary_end, "cues": cues, "targets": targets, "placement": placement_id}
