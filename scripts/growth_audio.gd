class_name GrowthAudio
extends Node

const FOLIAGE = preload("res://assets/audio/foliage.wav")
const BELL = preload("res://assets/audio/flower_bell.wav")
# C, D, E, G, A: overlapping blossoms remain in one gentle pentatonic palette.
const PITCHES := [1.0, 1.122462, 1.259921, 1.498307, 1.681793]
const WHISPER_DB := -18.0
const BELL_DB := -14.0
var whisper: AudioStreamPlayer
var bells: Array = []
var last_note: Array = [-100.0, -100.0, -100.0, -100.0, -100.0]
var fade: Tween
var elapsed := 0.0
var active := false
var note_count := 0

func _ready() -> void:
	whisper = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = FOLIAGE.duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	whisper.stream = stream
	whisper.volume_db = WHISPER_DB
	add_child(whisper)
	for ratio: float in PITCHES:
		var player := AudioStreamPlayer.new()
		player.stream = BELL
		player.pitch_scale = ratio
		player.volume_db = BELL_DB
		player.max_polyphony = 2
		add_child(player)
		bells.append(player)
	set_process(false)

func begin() -> void:
	if fade != null:
		fade.kill()
	active = true
	elapsed = 0
	last_note.fill(-100.0)
	note_count = 0
	whisper.volume_db = -50
	if not whisper.playing:
		whisper.play()
	fade = create_tween()
	fade.tween_property(whisper, "volume_db", WHISPER_DB, 0.06)
	set_process(true)

func bloom(corner: Vector2i, _color: int) -> void:
	if not active:
		return
	var slot: int = posmod(corner.x + corner.y * 3, PITCHES.size())
	if elapsed - float(last_note[slot]) < 0.085:
		return
	last_note[slot] = elapsed
	bells[slot].play()
	note_count += 1

func _process(delta: float) -> void:
	elapsed += delta

func finish() -> void:
	active = false
	set_process(false)
	if fade != null:
		fade.kill()
	fade = create_tween()
	fade.tween_property(whisper, "volume_db", -50.0, 0.12)
	fade.tween_callback(whisper.stop)
	# Bell tails may decay naturally; they never keep Place locked.

func cancel() -> void:
	active = false
	set_process(false)
	if fade != null:
		fade.kill()
	if whisper != null:
		whisper.stop()
	for player: AudioStreamPlayer in bells:
		player.stop()

func _exit_tree() -> void:
	cancel()
