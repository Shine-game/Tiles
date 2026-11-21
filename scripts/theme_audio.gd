class_name ThemeAudio
extends Node

const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Palette = preload("res://scripts/palette.gd")
signal placement_clicked(theme_id: String)
var ambience := AudioStreamPlayer.new()
var place_click := AudioStreamPlayer.new()
var theme := ""
var ambience_fade: Tween
var settings_path := "user://sound_settings.cfg"
var background_volume := 1.0
var effects_volume := 1.0
var background_enabled := true
var effects_enabled := true
var background_bus := ""
var effects_bus := ""

func _ready() -> void:
	_load_sound_settings()
	background_bus = "TilesBackground_%d" % get_instance_id()
	effects_bus = "TilesEffects_%d" % get_instance_id()
	for bus: String in [background_bus,effects_bus]:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
	add_child(ambience)
	add_child(place_click)
	ambience.bus = background_bus
	place_click.bus = effects_bus
	_apply_sound_levels()
	activate_theme(Palette.theme_id())

func attach_board(board) -> void:
	board.visual_state_changed.connect(_visual_state_changed)

func _visual_state_changed(_pattern, _animating: bool, _preserve: bool, _clock: float, _placement_id: int) -> void:
	activate_theme(Palette.theme_id())

func activate_theme(next: String) -> void:
	if theme == next: return
	deactivate()
	theme = next
	var config: Dictionary = Themes.profile(theme).soundscape
	var stream := (load(config.ambience.path) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
	stream.loop = true
	ambience.stream = stream
	var click := (load(config.place.path) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
	click.loop = false
	place_click.stream = click
	place_click.volume_db = float(config.place.gain_db)
	var gain: float = config.ambience.gain_db
	var fade: float = config.ambience.get("fade_in_seconds",0.0)
	ambience.volume_db = -65.0 if fade > 0 else gain
	ambience.play()
	if fade > 0:
		ambience_fade = create_tween()
		ambience_fade.tween_property(ambience,"volume_db",gain,fade)

# Only an accepted player placement clicks: never growth, helpers, restore,
# failed attempts, or scripted tutorial assembly.
func action_completed(action: String, result: Dictionary) -> void:
	if action != "place" or not result.get("ok",false) or result.get("source","") != "player": return
	activate_theme(Palette.theme_id())
	place_click.play()
	placement_clicked.emit(theme)

func deactivate() -> void:
	if ambience_fade != null and ambience_fade.is_valid(): ambience_fade.kill()
	ambience.stop()
	place_click.stop()
	ambience.stream = null
	place_click.stream = null
	theme = ""

func _exit_tree() -> void:
	deactivate()
	for bus: String in [background_bus,effects_bus]:
		var index := AudioServer.get_bus_index(bus)
		if index > 0: AudioServer.remove_bus(index)

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
