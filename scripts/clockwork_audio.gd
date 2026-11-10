class_name ClockworkAudio
extends Node

const ROOT := "res://assets/audio/clockwork/"
var ticking: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}
var active := false
var fade: Tween
var generation := 0
var last := {"click": -10000, "clunk": -10000, "steam": -10000}
var cue_count := 0

func _ready() -> void:
	for id: String in ["tick", "click", "clunk", "steam"]:
		clips[id] = load(ROOT + id + ".wav")
	ticking = AudioStreamPlayer.new()
	var loop: AudioStreamWAV = clips.tick.duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = loop.mix_rate
	ticking.stream = loop
	ticking.volume_db = -24
	add_child(ticking)
	for i in range(4):
		var player := AudioStreamPlayer.new()
		player.max_polyphony = 1
		add_child(player)
		voices.append(player)

func activate() -> void:
	if active: return
	active = true
	generation += 1
	if fade != null: fade.kill()
	if not ticking.playing:
		ticking.volume_db = -60
		ticking.play()
	fade = create_tween()
	fade.tween_property(ticking, "volume_db", -24.0, 0.40)

func deactivate() -> void:
	if not active: return
	active = false
	generation += 1
	var token: int = generation
	if fade != null: fade.kill()
	for player: AudioStreamPlayer in voices: player.stop()
	fade = create_tween()
	fade.tween_property(ticking, "volume_db", -60.0, 0.25)
	fade.tween_callback(func():
		if token == generation: ticking.stop())

func play(kind: String) -> void:
	if not active or not clips.has(kind): return
	var now := Time.get_ticks_msec()
	if now - int(last[kind]) < (150 if kind == "steam" else 85): return
	last[kind] = now
	for player: AudioStreamPlayer in voices:
		if not player.playing:
			player.stream = clips[kind]
			player.volume_db = -16 if kind == "clunk" else (-23 if kind == "steam" else -18)
			player.play()
			cue_count += 1
			return

func cancel_effects() -> void:
	for player: AudioStreamPlayer in voices: player.stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		if ticking != null: ticking.stream_paused = what == NOTIFICATION_PAUSED
		for player: AudioStreamPlayer in voices: player.stream_paused = what == NOTIFICATION_PAUSED

func _exit_tree() -> void:
	generation += 1
	if fade != null: fade.kill()
	if ticking != null: ticking.stop()
	cancel_effects()
