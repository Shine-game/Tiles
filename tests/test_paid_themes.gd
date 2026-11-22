extends SceneTree

const Palette = preload("res://scripts/palette.gd")
const Session = preload("res://scripts/game_session.gd")
const THEME := "christmas_joy"
const SAVE := "user://paid_theme_test_state.json"
const TRIAL_DIRECTORY := "user://paid_theme_test_games"
const TRIAL := TRIAL_DIRECTORY + "/christmas_joy.json"
var failures := 0

class TestBilling extends BillingClient:
	var launched: Array = []
	func is_ready() -> bool:
		return true
	func purchase(product_id: String, purchase_option_id: String = "", offer_id: String = "", _personalized: bool = false) -> Dictionary:
		launched = [product_id, purchase_option_id, offer_id]
		return {"response_code": BillingResponseCode.OK}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	Palette.select_theme("vines")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.session_enabled = true
	game.session_store.path = SAVE
	game.theme_game_directory = TRIAL_DIRECTORY
	game._show_menu("Themes")
	var christmas_row: Button
	for row: Button in game.theme_options:
		if row.get_meta("theme_id") == THEME: christmas_row = row
	check(christmas_row.position.y > game.palette_menu.paid_heading.position.y and game.palette_menu.paid_divider.visible, "Unowned theme is below the paid-theme divider")
	christmas_row.pressed.emit()
	check(Palette.theme_id() == THEME and not game.palette_menu.visible and not game.game.over, "The paid theme starts a playable trial")
	check(game.board_view.board_frame.theme_id == THEME, "The trial displays the bundled frame")
	var original = game.game
	game._replay_game()
	game._ask_reset(11)
	game._reset()
	check(game.game == original and not game.confirmation.visible, "Trial reset entry points preserve the same game")
	game._start_introduction()
	check(game.introduction == null and game.game == original, "Starting the tutorial cannot replace the trial")
	game.store_dialog.get_ok_button().pressed.emit()
	game._skip()
	var queue_index: int = game.game.index
	var board: Array = game.game.board.duplicate(true)
	game._request_theme("vines")
	check(Palette.theme_id() == "vines" and not game.confirmation.visible, "Leaving the trial preserves it")
	game._request_theme(THEME)
	check(game.game.index == queue_index and game.game.board == board, "Returning resumes the trial")

	game.game.lost = true
	game.game._refresh_over()
	game.cells = game._offered_cells()
	game._clear_selection()
	game._refresh_and_save()
	var finished := Session.pack(game.game)
	check(game.buy_theme_button.visible and game.replay_button.disabled and game.piece_view.cells.is_empty(), "The buy button replaces the next piece on the finished board")
	check(not game._request_player_action("undo").ok and not game._request_player_action("erase", {"cell": Vector2i(4, 4)}).ok, "Jokers cannot reopen a completed trial")
	game._show_menu("Themes")
	christmas_row.pressed.emit()
	check(not game.palette_menu.visible and Session.pack(game.game) == finished, "Selecting the same theme returns to its finished board")
	game._request_theme("vines")
	game._request_theme(THEME)
	check(game.buy_theme_button.visible and Session.pack(game.game) == finished, "Switching themes preserves the completed trial")
	game.queue_free()
	await process_frame

	Palette.select_theme("vines")
	game = load("res://main.tscn").instantiate()
	game.session_enabled = true
	game.session_store.path = SAVE
	game.theme_game_directory = TRIAL_DIRECTORY
	root.add_child(game)
	await process_frame
	check(Palette.theme_id() == THEME and Session.pack(game.game) == finished and game.buy_theme_button.visible, "Relaunch restores the completed board and buy button")

	var store = game.theme_store
	var billing := TestBilling.new()
	store.add_child(billing)
	store.billing = billing
	store.entitlement_path = "user://paid_theme_test_entitlements.json"
	store._product_details({"response_code": 0, "product_details": [{"product_id": THEME, "one_time_purchase_offer_details_list": [{"formatted_price": "1,49 €", "purchase_option_id": "standard"}]}]})
	check(game.buy_theme_button.text == "Buy for 1,49 €", "The buy button displays the localized Google Play price")
	game.buy_theme_button.pressed.emit()
	check(billing.launched == [THEME, "standard", ""], "Checkout uses the offer displayed on the buy button")
	store._purchases({"response_code": BillingClient.BillingResponseCode.USER_CANCELED}, false)
	check(game.buy_theme_button.visible and not game.buy_theme_button.disabled and Session.pack(game.game) == finished, "Canceling checkout keeps the finished trial available")
	store._purchases({"response_code": 0, "purchases": [{"product_ids": [THEME], "purchase_state": BillingClient.PurchaseState.PENDING}]}, false)
	check(game.buy_theme_button.disabled and game.replay_button.disabled, "A pending payment keeps the finished trial locked")
	store._purchases({"response_code": 0, "purchases": [{"product_ids": [THEME], "purchase_state": BillingClient.PurchaseState.PURCHASED, "purchase_token": "trial-test-token", "is_acknowledged": false}]}, false)
	check(game.replay_button.disabled, "An unacknowledged payment stays locked")
	store._acknowledged({"response_code": 0, "token": "trial-test-token"})
	check(not game.buy_theme_button.visible and not game.replay_button.disabled and Session.pack(game.game) == finished, "Successful acknowledgement unlocks replay and keeps the board")
	check(store.Entitlements.load_owned(store.entitlement_path, store.products).has(THEME), "Acknowledged ownership is cached for offline startup")
	game._show_menu("Themes")
	check(not game.palette_menu.paid_divider.visible, "An unlocked theme moves into the owned section")
	game._close_menu()
	game._replay_game()
	check(game.confirmation.visible, "An unlocked theme can restart")
	game.confirmation.get_ok_button().pressed.emit()
	check(not game.game.over and game.game.moves == 0, "Restart creates a full new game")
	store._purchases({"response_code": 0, "purchases": [{"product_ids": [THEME], "purchase_state": BillingClient.PurchaseState.PURCHASED, "is_acknowledged": true}]}, true)
	check(store.can_replay(THEME), "Google Play can restore an acknowledged purchase")

	game.queue_free()
	await process_frame
	for path: String in [SAVE, SAVE + ".bak", TRIAL, TRIAL + ".bak", "user://paid_theme_test_entitlements.json"]:
		DirAccess.remove_absolute(path)
	print("Paid theme trial and purchase: %d failures" % failures)
	quit(1 if failures else 0)
