extends SceneTree
const Palette = preload("res://scripts/palette.gd")
const Rules = preload("res://scripts/rules.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var buses := AudioServer.bus_count
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var sound = scene.sounds
	var settings := "/tmp/placement-audio-%d.cfg" % Time.get_ticks_usec()
	sound.settings_path = settings
	var clicks: Array = []
	sound.placement_clicked.connect(func(theme_id):clicks.append(theme_id))
	for theme_id: String in Palette.THEMES:
		scene._select_theme(theme_id)
		var config: Dictionary = Themes.profile(theme_id).soundscape
		check(config.size() == 2 and config.has("ambience") and config.has("place"),"Theme has only ambience and placement audio")
		check(sound.theme == theme_id and sound.ambience.playing and sound.ambience.stream.loop,"Unchanged ambience loops while idle")
		check(sound.get_child_count() == 2,"No growth, tier, fallback or structure sound players are allocated")
		check(sound.ambience.bus == sound.background_bus and sound.place_click.bus == sound.effects_bus,"Ambience and click have independent volume buses")
		check(sound.place_click.stream is AudioStreamOggVorbis and not sound.place_click.stream.loop and sound.place_click.stream.get_length() < 1.0,"Supplied click is a short non-looping OGG")
		var before_count := clicks.size()
		check(scene.game.offer_piece("I3",1),"Prepare a multi-square piece through the game API")
		var move := Rules.first_legal_move(scene.game.board,scene.game.piece(),false,false)
		scene.cells = move.cells
		scene.selected = move.anchor
		scene.has_hover = true
		scene._preview()
		scene._place()
		check(scene.game.moves == 1 and clicks.size() == before_count+1 and clicks.back() == theme_id,"One accepted multi-square tile produces exactly one themed click")
		check(sound.place_click.playing,"The supplied placement recording actually starts")
		scene.board_view.set_process(false)
		scene.board_view.advance_growth(100)
		check(clicks.size() == before_count+1 and sound.ambience.playing,"Finishing any tier is silent and leaves ambience running")
		scene.player_actions.execute("place",scene.game,{"cells":[Vector2i.ZERO],"anchor":Vector2i(-1,-1)})
		scene.player_actions.execute("rotate",scene.game,{"cells":scene.cells})
		scene.player_actions.execute("undo",scene.game)
		check(clicks.size() == before_count+1,"Invalid placement, manipulation, and helpers produce no sound")
		scene.game.offer_piece("Dot",1)
		var scripted: Dictionary = scene.player_actions.execute("place",scene.game,{"cells":[Vector2i.ZERO],"anchor":Vector2i(3,4),"source":"scenario"})
		check(scripted.ok and clicks.size() == before_count+1,"Scripted tutorial assembly is silent")
		scene.board_view.show_settled(scene.game.board)
		check(clicks.size() == before_count+1,"Restoring a board never replays placement clicks")
		var ambience_stream: AudioStream = sound.ambience.stream
		scene.board_view.show_settled(scene.game.board)
		check(sound.ambience.stream == ambience_stream and sound.ambience.playing,"Ordinary redraws retain the active ambience stream")
		sound.set_background_volume(0.31)
		sound.set_effects_volume(0.67)
		check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(sound.background_bus))),0.31) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(sound.effects_bus))),0.67),"Both volume controls still reach their real audio buses")
		sound.set_effects_volume(0)
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index(sound.effects_bus)),"Zero effects volume silences placement clicks")
		sound.set_effects_volume(1)
		scene._reset()
		check(not sound.place_click.playing or clicks.size() == before_count+1,"Reset does not create a new click")
	for theme_id: String in Palette.THEMES:
		var soundscape: Dictionary = Themes.profile(theme_id).soundscape
		var ambience: String = soundscape.ambience.path
		var place: String = soundscape.place.path
		var folder := DirAccess.open(ambience.get_base_dir())
		var recordings: Array = []
		for name: String in folder.get_files():
			if name.get_extension() in ["ogg","wav","mp3"]: recordings.append(name)
		recordings.sort()
		check(recordings == [ambience.get_file(), place.get_file()],"Only the two authorized recordings remain for "+theme_id)
	scene.queue_free()
	await process_frame
	check(AudioServer.bus_count == buses,"Audio cleanup removes both owned buses")
	DirAccess.remove_absolute(settings)
	print("Placement audio: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
