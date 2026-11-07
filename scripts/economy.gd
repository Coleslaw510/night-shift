class_name Economy
## Prices and payouts live in data/economy.json so they can be edited without code.

static var data: Dictionary = {}
static var _loaded := false

static func load_data() -> void:
	if _loaded:
		return
	_loaded = true
	var res = load("res://data/economy.json")
	if res and res.data is Dictionary:
		data = res.data

static func items() -> Array:
	load_data()
	return data.get("items", [])

static func item(id: String) -> Dictionary:
	for it in items():
		if str(it.get("id", "")) == id:
			return it
	return {}

static func payout(key: String, fallback := 0) -> int:
	load_data()
	return int(data.get("payouts", {}).get(key, fallback))

static func payout_f(key: String, fallback := 0.0) -> float:
	load_data()
	return float(data.get("payouts", {}).get(key, fallback))
