extends Node

signal changed
signal notice(message: String)

const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Entitlements = preload("res://scripts/theme_entitlements.gd")

var billing: BillingClient
var products: Dictionary = {}
var offers: Dictionary = {}
var owned: Dictionary = {}
var pending: Dictionary = {}
var acknowledgements: Dictionary = {}
var checkout := ""
var restoring_checkout := false
var entitlement_path := "user://theme_entitlements.json"

func _ready() -> void:
	for id: String in Themes.ids():
		var product := Themes.play_product(id)
		if not product.is_empty(): products[product] = id
	if not OS.has_feature("android") or not Engine.has_singleton("GodotGooglePlayBilling"): return
	owned = Entitlements.load_owned(entitlement_path, products)
	billing = BillingClient.new()
	add_child(billing)
	billing.connected.connect(_refresh_catalogue)
	billing.disconnected.connect(_disconnected)
	billing.connect_error.connect(func(_code, _message): _disconnected())
	billing.query_product_details_response.connect(_product_details)
	billing.query_purchases_response.connect(func(result: Dictionary): _purchases(result, true))
	billing.on_purchase_updated.connect(func(result: Dictionary): _purchases(result, false))
	billing.acknowledge_purchase_response.connect(_acknowledged)
	billing.start_connection()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and billing != null:
		if billing.is_ready(): _refresh_catalogue()
		elif billing.get_connection_state() != BillingClient.ConnectionState.CONNECTING: billing.start_connection()

func _exit_tree() -> void:
	if billing != null: billing.end_connection()

func can_replay(theme: String) -> bool:
	var product := Themes.play_product(theme)
	return product.is_empty() or owned.has(product)

func button_text(theme: String) -> String:
	var product := Themes.play_product(theme)
	if pending.has(product) or product in acknowledgements.values(): return "Payment pending"
	if checkout == product: return "Opening Google Play…"
	var price: String = offers.get(product, {}).get("formatted_price", "")
	return "Buy for %s" % price if not price.is_empty() else "Check price"

func can_check_out(theme: String) -> bool:
	var product := Themes.play_product(theme)
	return checkout.is_empty() and not pending.has(product) and product not in acknowledgements.values()

func purchase(theme: String) -> void:
	var product := Themes.play_product(theme)
	if not products.has(product) or can_replay(theme) or not can_check_out(theme): return
	if billing == null:
		notice.emit("Theme purchases are available through Google Play.")
		return
	if not billing.is_ready():
		if billing.get_connection_state() != BillingClient.ConnectionState.CONNECTING: billing.start_connection()
		notice.emit("Connecting to Google Play. Try again shortly.")
		return
	if not offers.has(product):
		billing.query_product_details(PackedStringArray(products.keys()), BillingClient.ProductType.INAPP)
		notice.emit("The price is unavailable. Please try again shortly.")
		return
	var offer: Dictionary = offers[product]
	var option_id: Variant = offer.get("purchase_option_id")
	var offer_id: Variant = offer.get("offer_id")
	var result := billing.purchase(product, option_id if option_id is String else "", offer_id if offer_id is String else "")
	match result.get("response_code"):
		BillingClient.BillingResponseCode.OK:
			checkout = product
			changed.emit()
		BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
			checkout = product
			_restore_checkout()
		_:
			notice.emit("Google Play checkout could not open.")

func _refresh_catalogue() -> void:
	if products.is_empty(): return
	billing.query_product_details(PackedStringArray(products.keys()), BillingClient.ProductType.INAPP)
	billing.query_purchases(BillingClient.ProductType.INAPP)

func _disconnected() -> void:
	var was_purchasing := not checkout.is_empty()
	checkout = ""
	restoring_checkout = false
	acknowledgements.clear()
	changed.emit()
	if was_purchasing: notice.emit("Google Play disconnected. Try again.")

func _product_details(result: Dictionary) -> void:
	if result.get("response_code") != BillingClient.BillingResponseCode.OK: return
	var available := {}
	for detail: Dictionary in result.get("product_details", []):
		var product: String = detail.get("product_id", "")
		if not products.has(product): continue
		for offer: Dictionary in detail.get("one_time_purchase_offer_details_list", []):
			if not str(offer.get("formatted_price", "")).is_empty():
				if not available.has(product): available[product] = offer
				if offer.get("offer_id") in [null, ""]:
					available[product] = offer
					break
	offers = available
	changed.emit()

func _purchases(result: Dictionary, full_list: bool) -> void:
	var code: int = result.get("response_code", -1)
	if not full_list and code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED and billing != null:
		_restore_checkout()
		return
	if code != BillingClient.BillingResponseCode.OK:
		if not full_list or restoring_checkout:
			checkout = ""
			restoring_checkout = false
			changed.emit()
			if code != BillingClient.BillingResponseCode.USER_CANCELED:
				notice.emit("Could not retrieve the Google Play purchase.")
		return
	if full_list and not checkout.is_empty() and not restoring_checkout:
		# Checkout has its own callback. A background catalogue refresh can
		# otherwise replace ownership with the snapshot from before payment.
		return
	var updated := {} if full_list else owned.duplicate()
	if full_list: pending.clear()
	for purchase_info: Dictionary in result.get("purchases", []):
		for product: String in purchase_info.get("product_ids", []):
			if not products.has(product): continue
			match purchase_info.get("purchase_state"):
				BillingClient.PurchaseState.PENDING:
					pending[product] = true
				BillingClient.PurchaseState.PURCHASED:
					pending.erase(product)
					if purchase_info.get("is_acknowledged", false):
						updated[product] = true
					else:
						var token: String = purchase_info.get("purchase_token", "")
						if not token.is_empty() and not acknowledgements.has(token):
							acknowledgements[token] = product
							if billing != null: billing.acknowledge_purchase(token)
	# A background restore query can finish while the checkout sheet is open.
	if not full_list or restoring_checkout:
		checkout = ""
		restoring_checkout = false
	_set_owned(updated)

func _restore_checkout() -> void:
	restoring_checkout = true
	billing.query_purchases(BillingClient.ProductType.INAPP)
	changed.emit()

func _acknowledged(result: Dictionary) -> void:
	var token: String = result.get("token", "")
	if not acknowledgements.has(token): return
	var product: String = acknowledgements[token]
	acknowledgements.erase(token)
	if result.get("response_code") == BillingClient.BillingResponseCode.OK:
		var updated := owned.duplicate()
		updated[product] = true
		_set_owned(updated)
	else:
		changed.emit()
		notice.emit("Google Play could not finish the purchase. Reopen Tiles to retry.")

func _set_owned(updated: Dictionary) -> void:
	if owned != updated:
		owned = updated
		if billing != null and not Entitlements.save_owned(entitlement_path, owned):
			push_warning("Could not cache purchased themes.")
	changed.emit()
