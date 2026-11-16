class_name PatternComponentState
extends RefCounted

const Schedule = preload("res://scripts/pattern/growth_schedule.gd")
const WAITING := "waiting"
const APPEARING := "appearing"
const SETTLED := "settled"
const RETIRING := "retiring"
var schedule := Schedule.new()
var records: Dictionary = {}
var wave := 0
var next_order := 0
var orders: Dictionary = {}

func reset() -> void:
	schedule.cancel()
	records.clear()
	orders.clear()
	wave += 1
	next_order = 0

func reconcile(events: Dictionary, duration: float, at: float = 0.0, settled: bool = false, preserve: bool = true, restart: bool = true) -> Dictionary:
	if not preserve: reset()
	if restart: wave += 1
	var was_paused := schedule.paused
	schedule.begin(duration, at)
	if not restart: schedule.paused = was_paused
	var delta := {"added": [], "retained": [], "removed": []}
	for id: String in records.keys():
		if not events.has(id):
			delta.removed.append(id)
			records.erase(id)
	for id: String in events:
		var event: Dictionary = events[id]
		if settled and event.get("retiring", false):
			if records.has(id):
				records.erase(id)
				delta.removed.append(id)
			continue
		var existing: bool = records.has(id)
		if not existing:
			if not orders.has(id):
				orders[id] = next_order
				next_order += 1
			records[id] = {"id": id, "order": orders[id], "created_in": wave, "phase": WAITING, "progress": 0.0, "revision": event.get("revision", "")}
		var record: Dictionary = records[id]
		(delta.retained if existing else delta.added).append(id)
		var keep_settled: bool = existing and record.phase == SETTLED and record.revision == event.get("revision", "") and not event.get("replay", false)
		record.revision = event.get("revision", "")
		record.data = event.duplicate(true)
		record.updated_in = wave
		record.start = float(event.start)
		record.end = float(event.end)
		if event.get("retiring", false):
			record.phase = RETIRING
		elif settled or event.get("old", false) or keep_settled:
			record.phase = SETTLED
			record.progress = 1.0
		else:
			record.phase = WAITING
	# Explicit legacy barriers include small effects that have not become parts
	# yet; active construction and retirement also contribute their own ends.
	if not settled:
		for record: Dictionary in records.values():
			if record.phase != SETTLED and record.data.get("blocking", true): schedule.duration = maxf(schedule.duration, record.end)
	_update()
	return delta

func advance(delta: float) -> float:
	schedule.advance(delta)
	_update()
	return schedule.clock

func _update() -> void:
	for id: String in records.keys():
		var record: Dictionary = records[id]
		if record.phase == SETTLED: continue
		if record.phase == RETIRING:
			record.progress = 1.0 - Schedule.smooth(record.start, record.end - record.start, schedule.clock)
			if schedule.clock >= record.end: records.erase(id)
		elif schedule.clock >= record.end:
			record.phase = SETTLED
			record.progress = 1.0
		else:
			record.phase = WAITING if schedule.clock < record.start else APPEARING
			record.progress = Schedule.smooth(record.start, record.end - record.start, schedule.clock)

func snapshot() -> Dictionary:
	return {"records": records.duplicate(true), "wave": wave, "next_order": next_order, "orders": orders.duplicate(), "clock": schedule.clock, "duration": schedule.duration}

func copy_from(source: PatternComponentState) -> void:
	# Gallery construction is settled and carries no operating/motion clock.
	var state := source.snapshot()
	records = state.records
	wave = state.wave
	next_order = state.next_order
	orders = state.orders
	schedule.cancel()
	for id: String in records.keys():
		if records[id].phase == RETIRING:
			records.erase(id)
		else:
			records[id].phase = SETTLED
			records[id].progress = 1.0
