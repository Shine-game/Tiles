extends SceneTree
const Audio=preload("res://scripts/theme_audio.gd")
const Palette=preload("res://scripts/palette.gd")
func _initialize():run.call_deferred()
func run():
 var path="/tmp/tiles-test-volume.cfg"
 DirAccess.remove_absolute(path)
 var a=Audio.new()
 a.settings_path=path
 root.add_child(a)
 a.set_background_volume(0.25)
 a.set_effects_volume(0.6)
 assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(a.background_bus))),0.25))
 assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(a.effects_bus))),0.6))
 a.set_background_enabled(false)
 a.set_background_volume(0.4)
 assert(AudioServer.is_bus_mute(AudioServer.get_bus_index(a.background_bus)))
 a.set_background_enabled(true)
 assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index(a.background_bus)))
 a.set_effects_volume(0)
 assert(AudioServer.is_bus_mute(AudioServer.get_bus_index(a.effects_bus)))
 a.set_effects_volume(0.6)
 var b=Audio.new()
 b.settings_path=path
 root.add_child(b)
 assert(b.background_volume==0.4 and b.effects_volume==0.6)
 a.queue_free()
 b.queue_free()
 DirAccess.remove_absolute(path)
 Palette.select_theme("vines")
 var scene=load("res://main.tscn").instantiate()
 root.add_child(scene)
 var previous_background:float=scene.sounds.background_volume
 var previous_effects:float=scene.sounds.effects_volume
 scene._show_menu("Audio")
 assert(scene.ambience_volume_row.visible and scene.effects_volume_row.visible)
 scene.ambience_volume_slider.value=37
 scene.effects_volume_slider.value=62
 assert(is_equal_approx(scene.sounds.background_volume,0.37) and is_equal_approx(scene.sounds.effects_volume,0.62))
 assert("37%" in scene.ambience_volume_row.get_child(0).text)
 assert("62%" in scene.effects_volume_row.get_child(0).text)
 scene._show_menu("New Game")
 assert(not scene.ambience_volume_row.visible)
 scene.sounds.set_background_volume(previous_background)
 scene.sounds.set_effects_volume(previous_effects)
 scene.sounds.deactivate()
 await create_timer(0.1).timeout
 scene.queue_free()
 await create_timer(0.15).timeout
 print("Sound volume: independent bus gain, zero-volume silence, mute retention, persistence and live settings sliders pass")
 quit()
