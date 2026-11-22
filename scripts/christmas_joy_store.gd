extends Node

signal changed
signal notice(message: String)

const PRODUCT := "christmas_joy_test"
const TEST_PACKAGE := '{"product":"christmas_joy_test","version":1,"preview":true}'
const INSTALL_PATH := "user://christmas_joy_preview.json"

var owned := false
var entitled := false
var busy := false
var billing: BillingClient
var pending_token := ""
var restore_after_launch := false

func _ready() -> void:
	if not OS.has_feature("android"):
		_set_owned(FileAccess.get_file_as_string(INSTALL_PATH) == TEST_PACKAGE)
		return
	if not OS.is_debug_build() or not ProjectSettings.get_setting("tiles/store/play_billing_test_enabled", false):
		return
	if not Engine.has_singleton("GodotGooglePlayBilling"):
		return
	billing = BillingClient.new()
	add_child(billing)
	billing.connected.connect(func(): billing.query_purchases(BillingClient.ProductType.INAPP))
	billing.disconnected.connect(func(): _finished("Google Play disconnected. Try again."))
	billing.connect_error.connect(func(_code, _message): _finished("Could not connect to Google Play."))
	billing.query_product_details_response.connect(_product_details)
	billing.query_purchases_response.connect(func(result: Dictionary):
		if not busy or restore_after_launch:
			restore_after_launch = false
			_purchases(result))
	billing.on_purchase_updated.connect(_purchases)
	billing.acknowledge_purchase_response.connect(_acknowledged)
	billing.start_connection()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and billing != null and billing.is_ready() and not busy:
		billing.query_purchases(BillingClient.ProductType.INAPP)

func _exit_tree() -> void:
	if billing != null:
		billing.end_connection()

func activate() -> void:
	if busy:
		return
	if owned:
		notice.emit("Christmas joy is in your library. The artwork is coming soon.")
		return
	if entitled or not OS.has_feature("android"):
		_deliver()
		return
	if billing == null:
		notice.emit("Google Play checkout is available in an enabled Android test build.")
		return
	if not billing.is_ready():
		if billing.get_connection_state() != BillingClient.ConnectionState.CONNECTING:
			billing.start_connection()
		notice.emit("Connecting to Google Play. Try again shortly.")
		return
	busy = true
	billing.query_product_details([PRODUCT], BillingClient.ProductType.INAPP)

func _product_details(result: Dictionary) -> void:
	if result.get("response_code") != BillingClient.BillingResponseCode.OK or result.get("product_details", []).is_empty():
		_finished("Christmas joy is unavailable. Check the test product in Play Console.")
		return
	var launched := billing.purchase(PRODUCT)
	match launched.get("response_code"):
		BillingClient.BillingResponseCode.OK:
			pass
		BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
			restore_after_launch = true
			billing.query_purchases(BillingClient.ProductType.INAPP)
		_:
			_finished("Google Play checkout could not open.")

func _purchases(result: Dictionary) -> void:
	match result.get("response_code"):
		BillingClient.BillingResponseCode.USER_CANCELED:
			_finished("")
			return
		BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
			restore_after_launch = true
			billing.query_purchases(BillingClient.ProductType.INAPP)
			return
		BillingClient.BillingResponseCode.OK:
			pass
		_:
			_finished("Could not retrieve the Google Play purchase.")
			return
	for purchase: Dictionary in result.get("purchases", []):
		if PRODUCT not in purchase.get("product_ids", []):
			continue
		match purchase.get("purchase_state"):
			BillingClient.PurchaseState.PENDING:
				_finished("The Google Play purchase is pending.")
			BillingClient.PurchaseState.PURCHASED:
				if purchase.get("is_acknowledged", false):
					_deliver()
				else:
					var token: String = purchase.get("purchase_token", "")
					if token.is_empty():
						_finished("Google Play did not return a purchase token.")
					elif token != pending_token:
						busy = true
						pending_token = token
						billing.acknowledge_purchase(token)
		return
	entitled = false
	_set_owned(false)
	_finished("")

func _acknowledged(result: Dictionary) -> void:
	if pending_token.is_empty() or result.get("token") != pending_token:
		return
	pending_token = ""
	if result.get("response_code") == BillingClient.BillingResponseCode.OK:
		_deliver()
	else:
		_finished("Could not acknowledge the test purchase. Reopen Tiles to retry.")

func _deliver() -> void:
	entitled = true
	if FileAccess.get_file_as_string(INSTALL_PATH) == TEST_PACKAGE:
		_set_owned(true)
		_finished("")
		return
	busy = true
	var url: String = ProjectSettings.get_setting("tiles/store/christmas_preview_url", "")
	if url.is_empty():
		_install(TEST_PACKAGE)
		return
	if not url.begins_with("https://"):
		_finished("The test package URL must use HTTPS.")
		return
	var request := HTTPRequest.new()
	request.timeout = 20
	request.body_size_limit = 4096
	request.max_redirects = 0
	add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		request.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			_install(body.get_string_from_utf8().strip_edges())
		else:
			_finished("Download failed. Press Christmas joy to retry."), CONNECT_ONE_SHOT)
	if request.request(url) != OK:
		request.queue_free()
		_finished("Could not start the download.")

func _install(package: String) -> void:
	if package != TEST_PACKAGE:
		_finished("The downloaded preview package is invalid.")
		return
	var file := FileAccess.open(INSTALL_PATH, FileAccess.WRITE)
	if file == null:
		_finished("Could not save the preview package.")
		return
	file.store_string(package)
	file.close()
	if FileAccess.get_file_as_string(INSTALL_PATH) != TEST_PACKAGE:
		_finished("Could not save the preview package.")
		return
	_set_owned(true)
	_finished("Christmas joy was added to your library. The artwork is coming soon.")

func _set_owned(value: bool) -> void:
	if owned == value:
		return
	owned = value
	changed.emit()

func _finished(message: String) -> void:
	restore_after_launch = false
	busy = false
	if not message.is_empty():
		notice.emit(message)
