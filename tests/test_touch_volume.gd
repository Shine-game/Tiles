extends SceneTree
const Palette = preload("res://scripts/palette.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func point(slider: HSlider, fraction: float) -> Vector2:
	var thumb := float(slider.get_theme_icon("grabber").get_width())
	return slider.get_global_rect().position+Vector2(thumb/2+(slider.size.x-thumb)*fraction,slider.size.y/2)

func touch(slider: HSlider, fraction: float, index: int, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point(slider,fraction)
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event,true)

func drag(slider: HSlider, fraction: float, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point(slider,fraction)
	event.index = index
	root.push_input(event,true)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(540,825)
	check(not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"),"Regression uses raw touch events without mouse emulation")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var original_background: float = scene.sounds.background_volume
	var original_effects: float = scene.sounds.effects_volume
	var original_background_enabled: bool = scene.sounds.background_enabled
	var original_effects_enabled: bool = scene.sounds.effects_enabled
	scene.sounds.set_background_enabled(true)
	scene.sounds.set_effects_enabled(true)
	for theme_id: String in Palette.THEMES:
		scene._select_theme(theme_id)
		scene._show_menu("Audio")
		for frame in range(3): await process_frame
		var sliders: Array = [scene.ambience_volume_slider,scene.effects_volume_slider]
		for slider: HSlider in sliders:
			var other: HSlider = sliders[1] if slider == sliders[0] else sliders[0]
			var other_value: float = other.value
			var bus: String = scene.sounds.background_bus if slider == sliders[0] else scene.sounds.effects_bus
			var bus_index := AudioServer.get_bus_index(bus)
			var starts: Array = []
			var endings: Array = []
			var started := func(): starts.append(true)
			var ended := func(changed): endings.append(changed)
			slider.drag_started.connect(started)
			slider.drag_ended.connect(ended)
			slider.value = 50
			touch(slider,0.25,3,true)
			check(is_equal_approx(slider.value,25),"Touching either track sets its volume: "+theme_id)
			drag(slider,0.75,3)
			check(is_equal_approx(slider.value,75),"Dragging a finger adjusts the volume continuously")
			check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus_index)),0.75),"Touch reaches the actual audio bus gain")
			touch(slider,0.1,7,true)
			drag(slider,0.1,7)
			touch(slider,0.1,7,false)
			check(is_equal_approx(slider.value,75),"Another finger cannot hijack or end the captured drag")
			drag(slider,1.3,3)
			check(is_equal_approx(slider.value,100),"Captured drag outside the track clamps to maximum")
			drag(slider,-0.1,3)
			check(slider.value == 0 and AudioServer.is_bus_mute(bus_index),"Dragging to zero mutes the channel")
			drag(slider,0.4,3)
			touch(slider,0.4,3,false)
			check(is_equal_approx(slider.value,40) and not AudioServer.is_bus_mute(bus_index),"Moving above zero restores audible volume")
			check(other.value == other_value,"Ambience and effects remain independent")
			check(starts.size() == 1 and endings == [true],"Touch emits one normal Slider drag lifecycle")
			touch(slider,0.3,4,true)
			touch(slider,0.9,4,false,true)
			drag(slider,0.9,4)
			check(is_equal_approx(slider.value,30),"System cancellation releases capture without a final jump")
			touch(slider,0.6,5,true)
			scene._close_menu()
			scene._show_menu("Audio")
			for frame in range(2): await process_frame
			touch(slider,0.2,6,true)
			touch(slider,0.2,6,false)
			check(is_equal_approx(slider.value,20),"Closing the menu releases touch capture before reopening")
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.position = point(slider,0.8)
			mouse.pressed = true
			root.push_input(mouse,true)
			mouse.pressed = false
			root.push_input(mouse,true)
			check(is_equal_approx(slider.value,80),"Native desktop mouse handling remains intact")
			check(slider.get_parent().get_child(0).text.contains("80%"),"Visible percentage follows pointer input")
			slider.grab_focus()
			var key := InputEventAction.new()
			key.action = "ui_left"
			key.pressed = true
			root.push_input(key,true)
			key.pressed = false
			root.push_input(key,true)
			check(slider.value < 80,"Native keyboard adjustment remains available")
			slider.value = 80
			touch(slider,0.45,9,true)
			slider.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			drag(slider,0.9,9)
			check(is_equal_approx(slider.value,45),"Switching away from the app releases the captured finger")
			slider.value = 80

			slider.drag_started.disconnect(started)
			slider.drag_ended.disconnect(ended)
			slider.editable = false
			touch(slider,0.1,8,true)
			touch(slider,0.1,8,false)
			check(is_equal_approx(slider.value,80),"Non-editable sliders reject touch")
			slider.editable = true
	scene.sounds.set_background_volume(original_background)
	scene.sounds.set_effects_volume(original_effects)
	scene.sounds.set_background_enabled(original_background_enabled)
	scene.sounds.set_effects_enabled(original_effects_enabled)
	scene.queue_free()
	await process_frame
	print("Touch volume: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
