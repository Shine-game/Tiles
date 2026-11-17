class_name PatternGrowthSchedule
extends RefCounted

const SETTLED_AT := -100.0
var clock := 0.0
var duration := 0.0
var paused := false

func begin(seconds: float, at: float = 0.0) -> void:
	duration = maxf(0.0, seconds)
	clock = clampf(at, 0.0, duration)
	paused = false

func cancel() -> void:
	clock = 0.0
	duration = 0.0
	paused = false

func advance(delta: float) -> float:
	if not paused: clock = minf(duration, clock + maxf(0.0, delta))
	return clock

func running() -> bool:
	return clock < duration

static func smooth(start: float, seconds: float, at: float, settled: bool = false) -> float:
	return 1.0 if settled else smoothstep(0, 1, clampf((at - start) / maxf(0.001, seconds), 0, 1))

static func front_arrival(start: float, reverse: float, stroke: float, two_fronts: bool, u: float) -> float:
	return minf(start + u * stroke, reverse + (1.0 - u) * stroke) if two_fronts else start + u * stroke

static func front_end(start: float, reverse: float, stroke: float, two_fronts: bool, tail: float = 0.0) -> float:
	if stroke <= 0.0: return (minf(start, reverse) if two_fronts else start) + tail
	var peak: float = clampf((reverse + stroke - start) / (2 * stroke), 0, 1) if two_fronts else 1.0
	return front_arrival(start, reverse, stroke, two_fronts, peak) + tail

static func event_arrival(event: Dictionary, u: float) -> float:
	var stroke: float = event.get("stroke", event.get("seconds", 0.0))
	var reverse: float = event.get("reverse", event.get("edge_start", 0.0))
	var two_fronts: bool = event.get("two_fronts", event.has("edge_start"))
	return front_arrival(event.start, reverse, stroke, two_fronts, u)

static func dependent_start(dependencies: Array, parents: Dictionary) -> float:
	var start := SETTLED_AT
	for dependency: Dictionary in dependencies:
		var parent: Dictionary = parents[dependency.component]
		var ready: float = parent.end if dependency.get("event", "") == "complete" else event_arrival(parent, float(dependency.at_mask_u))
		start = maxf(start, ready + float(dependency.get("delay_seconds", 0)))
	return start

static func shifted(event: Dictionary, elapsed: float, time_fields: Array = ["start", "end"]) -> Dictionary:
	# A negative rebased start can mean partially constructed, not settled.
	var result := event.duplicate()
	for field: String in time_fields:
		if result.has(field): result[field] -= elapsed
	return result

static func field_arrival(fronts: Array, u: float) -> float:
	var earliest := INF
	for front: Dictionary in fronts:
		earliest = minf(earliest, float(front.start) + absf(u - float(front.origin_u)) * float(front.seconds))
	return earliest

static func field_end(fronts: Array, from_u: float = 0.0, to_u: float = 1.0) -> float:
	# The earliest-arrival envelope is piecewise linear. Its maximum is at
	# a domain endpoint, source origin, or intersection of two valid branches.
	var low := minf(from_u, to_u)
	var high := maxf(from_u, to_u)
	var points: Array = [low, high]
	var branches: Array = []
	for front: Dictionary in fronts:
		var origin: float = front.origin_u
		var seconds: float = front.seconds
		if origin >= low and origin <= high: points.append(origin)
		branches.append({"slope": -seconds, "offset": float(front.start) + origin * seconds, "low": low, "high": minf(high, origin)})
		branches.append({"slope": seconds, "offset": float(front.start) - origin * seconds, "low": maxf(low, origin), "high": high})
	for i in range(branches.size()):
		for j in range(i):
			var a: Dictionary = branches[i]
			var b: Dictionary = branches[j]
			if is_equal_approx(a.slope, b.slope): continue
			var u: float = (b.offset - a.offset) / (a.slope - b.slope)
			if u >= maxf(a.low, b.low) and u <= minf(a.high, b.high): points.append(u)
	var finish := -INF
	for u: float in points: finish = maxf(finish, field_arrival(fronts, u))
	return finish
