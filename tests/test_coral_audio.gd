extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Coral = preload("res://scripts/coral_growth.gd")
const Plan = preload("res://scripts/coral_audio_plan.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	_run.call_deferred()

func wait_seconds(seconds: float) -> void:
	# SceneTree timers consume the previous loading frame delta when created
	# before the next frame; wait for real elapsed frames when testing Tweens.
	var until := Time.get_ticks_msec() + ceili(seconds * 1000)
	while Time.get_ticks_msec() < until:
		await process_frame
	await process_frame

func _run() -> void:
	Palette.select_theme("vines")
	check(Plan.stable_hash(["a"]) == 0xe40c292c, "feature choice uses standard unsigned FNV-1a")
	check(Plan.stable_hash(["b", "a"]) == Plan.stable_hash(["a", "b"]), "feature choice is independent of discovery order")
	var empty: Array = Rules.empty_board(9)
	var block: Array = empty.duplicate(true)
	for y in range(2, 5):
		for x in range(2, 5):
			block[y][x] = 1
	var pattern = Coral.new()
	pattern.build(empty, block)
	var plan: Dictionary = Plan.build(pattern, 1)
	check(plan.cues.size() == 2, "simultaneous four-colony/four-anemone garden makes only two feature cues")
	check(plan.cues[0].kind == "colony" and plan.cues[0].members.size() == 4, "all four colony starts coalesce without delay")
	check(plan.cues[1].kind == "anemone" and plan.cues[1].members.size() == 4, "all four anemone starts coalesce without delay")
	check(is_equal_approx(plan.cues[0].time, pattern.colonies.values()[0].start + Plan.VISIBLE_EPSILON), "colony cue follows first visible body pixels")
	check(is_equal_approx(plan.cues[1].time, pattern.unions.values()[0].start + Plan.VISIBLE_EPSILON), "anemone cue follows first visible foot pixels")
	check(plan.ordinary_end < float(plan.cues[1].time), "rustle stops after ordinary construction, before later anemone growth")
	check(Plan.build(pattern, 1, plan.cues[1].time + 0.01).cues.is_empty(), "switching into mid-growth does not replay past cues")
	pattern.build(block, block)
	var settled: Dictionary = Plan.build(pattern, 1)
	check(settled.cues.is_empty() and settled.ordinary_end < 0, "loaded settled reef has ambience without construction sounds")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for frame in range(4):
		await process_frame
	var reef = scene.sounds.reef
	var private_bus: String = reef.bus_name
	check(not reef.ambience.playing and not reef.theme_active, "other themes do not start reef ambience")
	check(reef.assets.size() == 9 and reef.growth.size() == 2 and reef.features.size() == 2, "nine clips share a five-voice pool")
	for id: String in reef.assets:
		var stream: AudioStreamOggVorbis = reef.streams[id]
		check(stream.loop == bool(reef.assets[id].loop), "correct loop policy for " + id)
		check(absf(stream.get_length() - float(reef.assets[id].duration_seconds)) < 0.02, "prepared duration loaded: " + id)
	scene._select_theme("coral_reef")
	check(reef.theme_active and reef.ambience.playing, "entering coral starts supplied ambience")
	check(not scene.sounds.whisper.playing and scene.sounds.bells.all(func(player): return not player.playing), "coral does not layer legacy foliage/bells")
	# Start visual growth directly, using the same accepted-board callback as Place.
	scene.game.board = block
	scene.board_view.animate_growth(empty, block)
	scene.board_view.set_process(false)
	check(reef.pending.size() == 2, "real board exposes two coalesced feature events")
	scene.board_view.advance_growth(0.02)
	check(reef.current_growth >= 0 and reef.growth[reef.current_growth].player.playing, "growth texture starts with visible ordinary growth")
	check(reef.growth[reef.current_growth].asset == reef.specification.events.ordinary_growth.assets[scene.board_view.placement_revision % 3], "growth variant derives only from visual placement ID")
	var first_time: float = reef.pending[0].time
	scene.board_view.advance_growth(first_time - scene.board_view.clock + 0.0001)
	check(reef.event_log.filter(func(event: Dictionary): return event.kind == "colony").size() == 1, "one bubble represents four colony foundations")
	check(reef.duck_target == -2 and reef.features.any(func(voice): return voice.player.playing), "feature cue ducks ambience once")
	var active_cue: Dictionary = reef.features.filter(func(voice): return voice.kind == "colony")[0]
	var initial_members: int = active_cue.members.size()
	var erased: Array = block.duplicate(true)
	erased[2][2] = 0
	scene.game.board = erased
	scene.board_view.show_settled(erased, true)
	check(active_cue.members.size() == initial_members - 1 and active_cue.player.playing, "erasing one support preserves coalesced cue's remaining valid colonies")
	check(reef.pending.is_empty() and reef.current_growth < 0, "erasure cancels future cues and ordinary loop coverage")
	scene.game.board = Rules.empty_board(9)
	scene.board_view.show_settled(scene.game.board, true)
	check(reef.features.all(func(voice): return voice.members.is_empty()), "all invalid feature members are removed")
	await wait_seconds(0.12)
	check(reef.features.all(func(voice): return not voice.player.playing), "invalid cues fade and stop")
	check(reef.ambience.playing, "undo/erase preserve reef ambience")
	# Anemone callback is based on its actual foot start and does not use bells.
	scene.game.board = block
	scene.board_view.animate_growth(empty, block)
	scene.board_view.set_process(false)
	scene.board_view.advance_growth(0.02)
	var anemone_time: float = reef.pending.filter(func(cue): return cue.kind == "anemone")[0].time
	scene.board_view.advance_growth(anemone_time - scene.board_view.clock + 0.0001)
	await wait_seconds(0.06)
	check(reef.event_log.any(func(event: Dictionary): return event.kind == "anemone" and event.members.size() == 4), "one long bubble represents four anemone feet")
	check(reef.features.filter(func(voice): return voice.player.playing).size() <= 2 and reef.duck_target == -2, "overlapping short/long bubbles respect voice and duck caps")
	scene.board_view.advance_growth(scene.board_view.pattern.duration + 1)
	check(not scene.board_view.growing and reef.features.any(func(voice): return voice.player.playing), "bubble tails never prolong Place gate")
	# Pause must freeze dispatch, and resume must not replay already-dispatched cues.
	scene.board_view.animate_growth(empty, block)
	scene.board_view.set_process(false)
	var pending_before: int = reef.pending.size()
	paused = true
	reef.advance(10)
	check(reef.pending.size() == pending_before, "paused visual/audio clock does not dispatch cues")
	paused = false
	# Reset cancels work and can be followed immediately by a new placement.
	scene._reset()
	check(reef.pending.is_empty(), "reset invalidates pending callbacks")
	scene.game.board = block
	scene.board_view.animate_growth(empty, block)
	scene.board_view.set_process(false)
	scene.board_view.advance_growth(0.02)
	await wait_seconds(0.15)
	check(reef.theme_active and reef.growth[reef.current_growth].player.playing, "old fade cannot stop immediate post-reset growth")
	scene._select_theme("vines")
	check(not reef.theme_active and reef.pending.is_empty(), "leaving coral invalidates reef schedule")
	check(scene.sounds.whisper.playing, "other theme resumes its original growth texture")
	await wait_seconds(0.7)
	check(not reef.ambience.playing and (reef.growth + reef.features).all(func(voice): return not voice.player.playing), "leaving coral fades and stops all reef voices")
	var selected: int = AudioServer.get_bus_index(private_bus)
	check(selected > 0 and AudioServer.get_bus_send(selected) == "Master", "reef routes through a private bus without changing Master")
	scene.queue_free()
	await wait_seconds(0.15)
	check(AudioServer.get_bus_index(private_bus) == -1, "scene disposal cleans up private audio bus")
	Palette.select_theme("vines")
	print("Coral audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
