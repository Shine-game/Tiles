class_name CoralAudio
extends Node

const Plan = preload("res://scripts/coral_audio_plan.gd")
const Coral = preload("res://scripts/coral_growth.gd")
const SILENT_DB := -60.0
var specification: Dictionary
var assets: Dictionary = {}
var streams: Dictionary = {}
var ambience: AudioStreamPlayer
var growth: Array = []
var features: Array = []
var bus_name := ""
var theme_active := false
var generation := 0
var ambience_fade_db := SILENT_DB
var duck_db := 0.0
var duck_target := 0.0
var ambience_tween: Tween
var duck_tween: Tween
var timeline: Dictionary = {}
var targets: Dictionary = {}
var pending: Array = []
var last_variant := {"colony": -1, "anemone": -1}
var current_growth := -1
var visual_clock := 0.0
var event_log: Array = []

func _ready() -> void:
	specification = Coral.specification().audio
	bus_name = "CoralReef_%d" % get_instance_id()
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
	var already_limited := false
	for effect in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0, effect).get_class() in ["AudioEffectHardLimiter", "AudioEffectLimiter"]:
			already_limited = true
	if not already_limited:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(index, limiter)
	for meta: Dictionary in specification.assets:
		assets[meta.id] = meta
		var stream := (load(meta.path) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		stream.loop = meta.loop
		stream.loop_offset = 0
		streams[meta.id] = stream
	ambience = _player()
	ambience.stream = streams.reef_ambience
	for slot in range(2):
		growth.append({"player": _player(), "fade": null, "asset": ""})
		features.append({"player": _player(), "fade": null, "asset": "", "kind": "", "members": [], "pending": {}})
	set_process(false)

func _player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	player.max_polyphony = 1
	add_child(player)
	return player

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()

func activate() -> void:
	if theme_active:
		return
	theme_active = true
	generation += 1
	_kill(ambience_tween)
	for voice: Dictionary in growth + features:
		_kill(voice.fade)
		voice.player.stop()
	if not ambience.playing:
		ambience_fade_db = SILENT_DB
		ambience.volume_db = float(assets.reef_ambience.gain_db) + ambience_fade_db + duck_db
		ambience.play()
	ambience_tween = create_tween()
	ambience_tween.tween_property(self, "ambience_fade_db", 0.0, float(specification.events.ambience.fade_in_seconds))
	set_process(true)

func _fade_voice(voice: Dictionary, seconds: float) -> void:
	_kill(voice.fade)
	voice.fade = create_tween()
	voice.fade.tween_property(voice.player, "volume_db", SILENT_DB, seconds)
	voice.fade.tween_callback(voice.player.stop)

func invalidate() -> void:
	# Helpers settle surviving visuals; cancel ordinary construction and future
	# callbacks now, then reconcile ongoing feature tails against the new target.
	pending.clear()
	timeline.clear()
	current_growth = -1
	for voice: Dictionary in growth:
		if voice.player.playing:
			_fade_voice(voice, 0.08)

func deactivate(restart: bool = false) -> void:
	generation += 1
	var token: int = generation
	theme_active = false
	invalidate()
	for voice: Dictionary in features:
		voice.pending = {}
		voice.members = []
		_fade_voice(voice, 0.08)
	_kill(ambience_tween)
	ambience_tween = create_tween()
	ambience_tween.tween_property(self, "ambience_fade_db", SILENT_DB, 0.6)
	ambience_tween.tween_callback(func():
		if token == generation:
			ambience.stop()
			if restart:
				activate())
	set_process(true)

func reconcile(pattern, animating: bool, preserve: bool, clock: float, placement_id: int) -> void:
	var was_active: bool = theme_active
	activate()
	var plan: Dictionary = Plan.build(pattern, placement_id, clock)
	targets = plan.targets
	for voice: Dictionary in features:
		voice.members = voice.members.filter(func(identity): return targets.has(identity))
		if not voice.pending.is_empty():
			voice.pending.members = voice.pending.members.filter(func(identity): return targets.has(identity))
			if voice.pending.members.is_empty():
				voice.pending = {}
				if not voice.members.is_empty() and voice.player.playing:
					_kill(voice.fade)
					voice.fade = create_tween()
					voice.fade.tween_property(voice.player, "volume_db", float(assets[voice.asset].gain_db), 0.04)
		if voice.members.is_empty() and voice.pending.is_empty() and voice.player.playing:
			_fade_voice(voice, 0.08)
	if not animating:
		invalidate()
		if not preserve and was_active:
			deactivate(true)
		return
	timeline = plan
	pending = plan.cues.duplicate(true)
	current_growth = -1
	visual_clock = clock
	advance(clock)

func _start_growth() -> void:
	var slot := -1
	for i in range(growth.size()):
		if not growth[i].player.playing:
			slot = i
			break
	if slot < 0:
		slot = 0 # Place is gated, so only a preceding fade can occupy this slot.
	var voice: Dictionary = growth[slot]
	_kill(voice.fade)
	voice.player.stop()
	var ids: Array = specification.events.ordinary_growth.assets
	var id: String = ids[int(timeline.placement) % ids.size()]
	voice.asset = id
	voice.player.stream = streams[id]
	voice.player.volume_db = SILENT_DB
	voice.player.play()
	voice.fade = create_tween()
	voice.fade.tween_property(voice.player, "volume_db", float(assets[id].gain_db), 0.025)
	current_growth = slot
	_log({"kind": "growth", "asset": id, "clock": visual_clock, "placement": timeline.placement})

func advance(clock: float) -> void:
	if not theme_active or timeline.is_empty() or get_tree().paused:
		return
	visual_clock = clock
	if current_growth < 0 and clock >= float(timeline.ordinary_start) and clock < float(timeline.ordinary_end):
		_start_growth()
	if current_growth >= 0 and clock >= float(timeline.ordinary_end):
		_fade_voice(growth[current_growth], 0.08)
		_log({"kind": "growth_end", "clock": clock})
		current_growth = -1
	while not pending.is_empty() and float(pending[0].time) <= clock:
		var cue: Dictionary = pending.pop_front()
		_play_feature(cue)

func _variant(cue: Dictionary) -> String:
	var ids: Array = specification.events[cue.kind].assets
	var slot: int = Plan.stable_hash(cue.members) % ids.size()
	if slot == int(last_variant[cue.kind]) and ids.size() > 1:
		slot = (slot + 1) % ids.size()
	last_variant[cue.kind] = slot
	return ids[slot]

func _play_feature(cue: Dictionary) -> void:
	cue.members = cue.members.filter(func(identity): return targets.has(identity))
	if cue.members.is_empty():
		return
	for voice: Dictionary in features:
		if not voice.player.playing and voice.pending.is_empty():
			_start_feature(voice, cue)
			return
	if cue.kind == "anemone":
		for voice: Dictionary in features:
			if voice.kind == "colony" and voice.pending.is_empty():
				voice.pending = cue
				_kill(voice.fade)
				voice.fade = create_tween()
				voice.fade.tween_property(voice.player, "volume_db", SILENT_DB, 0.03)
				var token: int = generation
				voice.fade.tween_callback(func():
					if token == generation and theme_active and not voice.pending.is_empty():
						var replacement: Dictionary = voice.pending
						voice.pending = {}
						replacement.members = replacement.members.filter(func(identity): return targets.has(identity))
						if not replacement.members.is_empty():
							_start_feature(voice, replacement))
				return
	_log({"kind": "dropped", "type": cue.kind, "clock": visual_clock})

func _start_feature(voice: Dictionary, cue: Dictionary) -> void:
	_kill(voice.fade)
	voice.player.stop()
	var id := _variant(cue)
	voice.asset = id
	voice.kind = cue.kind
	voice.members = cue.members.duplicate()
	voice.pending = {}
	voice.player.stream = streams[id]
	voice.player.volume_db = float(assets[id].gain_db)
	voice.player.play()
	_log({"kind": cue.kind, "asset": id, "members": cue.members.duplicate(), "clock": visual_clock, "scheduled": cue.time})
	_update_duck()

func _update_duck() -> void:
	var target: float = -2 if features.any(func(voice: Dictionary): return voice.player.playing or not voice.pending.is_empty()) else 0
	if is_equal_approx(target, duck_target):
		return
	duck_target = target
	_kill(duck_tween)
	duck_tween = create_tween()
	duck_tween.tween_property(self, "duck_db", target, 0.04 if target < 0 else 0.25)

func _process(_delta: float) -> void:
	_update_duck()
	ambience.volume_db = float(assets.reef_ambience.gain_db) + ambience_fade_db + duck_db
	if not theme_active and not ambience.playing and not (growth + features).any(func(voice: Dictionary): return voice.player.playing):
		set_process(false)

func _log(event: Dictionary) -> void:
	event_log.append(event)
	if event_log.size() > 128:
		event_log.pop_front()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		for voice: Dictionary in growth + features:
			voice.player.stream_paused = what == NOTIFICATION_PAUSED
		if ambience != null:
			ambience.stream_paused = what == NOTIFICATION_PAUSED

func _exit_tree() -> void:
	generation += 1
	_kill(ambience_tween)
	_kill(duck_tween)
	for voice: Dictionary in growth + features:
		_kill(voice.fade)
		voice.fade = null
		voice.player.stop()
	if ambience != null:
		ambience.stop()
	var bus: int = AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.remove_bus(bus)
