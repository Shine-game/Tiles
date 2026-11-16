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
