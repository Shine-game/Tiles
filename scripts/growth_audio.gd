class_name GrowthAudio
extends Node

const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Soundscape = preload("res://scripts/theme_soundscape.gd")
const Palette = preload("res://scripts/palette.gd")
const Workshop = preload("res://scripts/clockwork_audio.gd")
const Reef = preload("res://scripts/coral_audio.gd")
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
var reef: CoralAudio
var visual_theme := ""
var workshop: ClockworkAudio
var soundscape
var themed_soundscape: bool:
	get: return Themes.profile(Palette.theme_id()).has("soundscape")

func _ready() -> void:
	_load_sound_settings()
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
	workshop = Workshop.new()
	add_child(workshop)
	reef = Reef.new()
	add_child(reef)
	soundscape = Soundscape.new()
	add_child(soundscape)
	_setup_sound_buses()
	soundscape.route(background_bus,effects_bus)
	set_process(false)

func attach_board(board) -> void:
	board.workshop_cue.connect(func(kind):
		if not themed_soundscape: workshop.play(kind))
	board.visual_state_changed.connect(_visual_state_changed)
	board.visual_clock_advanced.connect(reef.advance)
	board.visual_clock_advanced.connect(soundscape.advance)

func _visual_state_changed(pattern, animating: bool, preserve: bool, clock: float, placement_id: int) -> void:
	var changed: bool = visual_theme != Palette.theme_id()
	visual_theme = Palette.theme_id()
	if themed_soundscape:
		_cancel_legacy()
		if reef.theme_active: reef.deactivate()
		if workshop.active: workshop.deactivate()
		soundscape.reconcile(pattern,Palette.theme_id(),animating,clock,placement_id)
		active=animating
		return
	if not soundscape.theme.is_empty():soundscape.deactivate()
	if workshop.active: workshop.deactivate()
	if Palette.coral_reef:
		_cancel_legacy()
		active = animating
		reef.reconcile(pattern, animating, preserve, clock, placement_id)
	else:
		if reef.theme_active:
			reef.deactivate()
		if changed and animating:
			begin()

func begin() -> void:
	if Palette.coral_reef or themed_soundscape:
		active = true
		return
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
	if Palette.coral_reef or themed_soundscape or not active:
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
	if themed_soundscape:
		active=false
		return
	if Palette.coral_reef:
		active = false
		reef.invalidate()
		return
	active = false
	set_process(false)
	if fade != null:
		fade.kill()
	fade = create_tween()
	fade.tween_property(whisper, "volume_db", -50.0, 0.12)
	fade.tween_callback(whisper.stop)
	# Bell tails may decay naturally; they never keep Place locked.

func cancel() -> void:
	if soundscape != null: soundscape.cancel_effects()
	_cancel_legacy()
	if workshop != null: workshop.cancel_effects()
	if reef != null and reef.is_inside_tree():
		reef.invalidate()

func _cancel_legacy() -> void:
	active = false
	set_process(false)
	if fade != null:
		fade.kill()
	if whisper != null:
		whisper.stop()
	for player: AudioStreamPlayer in bells:
		player.stop()

func _exit_tree() -> void:
	_cancel_legacy()
	for bus: String in [background_bus, effects_bus]:
		var index := AudioServer.get_bus_index(bus)
		if index > 0:
			AudioServer.remove_bus(index)

# Separate buses keep mute independent of theme fades and scheduled effects.
var settings_path := "user://sound_settings.cfg"
var background_volume := 1.0
var effects_volume := 1.0
var background_enabled := true
var effects_enabled := true
var background_bus := ""
var effects_bus := ""

func _setup_sound_buses() -> void:
	background_bus = "TilesBackground_%d" % get_instance_id()
	effects_bus = "TilesEffects_%d" % get_instance_id()
	for bus: String in [background_bus, effects_bus]:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	whisper.bus = background_bus
	workshop.ticking.bus = background_bus
	reef.ambience.bus = background_bus
	for player: AudioStreamPlayer in bells + workshop.voices:
		player.bus = effects_bus
	AudioServer.set_bus_send(AudioServer.get_bus_index(reef.bus_name), effects_bus)
	_apply_sound_levels()

func _load_sound_settings() -> void:
	var saved := ConfigFile.new()
	if saved.load(settings_path) != OK: return
	background_volume=clampf(float(saved.get_value("sound","ambience_volume",1.0)),0.0,1.0)
	effects_volume=clampf(float(saved.get_value("sound","effects_volume",1.0)),0.0,1.0)
	background_enabled=bool(saved.get_value("sound","ambience_enabled",true))
	effects_enabled=bool(saved.get_value("sound","effects_enabled",true))

func _save_sound_settings() -> void:
	var saved := ConfigFile.new()
	saved.set_value("sound","ambience_volume",background_volume)
	saved.set_value("sound","effects_volume",effects_volume)
	saved.set_value("sound","ambience_enabled",background_enabled)
	saved.set_value("sound","effects_enabled",effects_enabled)
	saved.save(settings_path)

func _apply_sound_levels() -> void:
	for channel in [[background_bus,background_volume,background_enabled],[effects_bus,effects_volume,effects_enabled]]:
		var index := AudioServer.get_bus_index(channel[0])
		if index<=0:continue
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(float(channel[1]),0.000001)))
		AudioServer.set_bus_mute(index,not channel[2] or float(channel[1])<=0.0)

func set_background_volume(value: float) -> void:
	background_volume=clampf(value,0.0,1.0)
	_apply_sound_levels()
	_save_sound_settings()

func set_effects_volume(value: float) -> void:
	effects_volume=clampf(value,0.0,1.0)
	_apply_sound_levels()
	_save_sound_settings()

func set_background_enabled(enabled: bool) -> void:
	background_enabled=enabled
	_apply_sound_levels()
	_save_sound_settings()

func set_effects_enabled(enabled: bool) -> void:
	effects_enabled=enabled
	_apply_sound_levels()
	_save_sound_settings()
