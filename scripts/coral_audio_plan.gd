class_name CoralAudioPlan
extends RefCounted

const Themes = preload("res://scripts/pattern/theme_registry.gd")
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
			raw.append({"kind": "colony", "time": colony.start + VISIBLE_EPSILON, "key": identity,"end":colony.end})
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
			last[event.kind].end=maxf(last[event.kind].get("end",event.time),event.get("end",event.time))
		else:
			var cue := {"kind": event.kind, "time": event.time, "members": [event.key], "placement": placement_id,"end":event.get("end",event.time)}
			cues.append(cue)
			last[event.kind] = cue
	for cue: Dictionary in cues:
		cue.members.sort()
		cue.hash = stable_hash(cue.members)
		if cue.kind == "colony":
			var spec: Dictionary=Themes.profile("coral_reef").audio.events.colony
			var rng:=RandomNumberGenerator.new()
			rng.seed=cue.hash+placement_id
			var count:=rng.randi_range(spec.burst.count[0],spec.burst.count[1])
			var span:float=maxf(0.0,cue.end-cue.time)
			var last_start:float=maxf(0.0,span-minf(0.2,span/3))
			cue.bubbles=[]
			var previous:=-1
			for i in range(count):
				var slot:=rng.randi_range(0,spec.assets.size()-1)
				if slot==previous:slot=(slot+1)%spec.assets.size()
				previous=slot
				var fraction:float=0.0 if i==0 else clampf((i+rng.randf_range(-0.3,0.3))/(count-1),0.0,1.0)
				cue.bubbles.append({"asset":spec.assets[slot],"time":cue.time+fraction*last_start})
	cues.sort_custom(func(a: Dictionary, b: Dictionary): return a.time < b.time)
	return {"ordinary_start": ordinary_start, "ordinary_end": ordinary_end, "cues": cues, "targets": targets, "placement": placement_id}
