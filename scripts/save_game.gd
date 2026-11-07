class_name SaveGame
## Versioned save at user://save.json with two backups.
## A 1.1.1 install has no game save; if a version-1 file shows up
## (money / earnings only) it is migrated instead of discarded.

const VERSION := 2
const PATH := "user://save.json"
const BAK := "user://save.bak.json"
const BAK2 := "user://save.bak2.json"
const PREV := "user://save.prev.json"
const LEGACY := ["user://nightshift_save.json", "user://save_v1.json"]

static var boot_mode := ""

static func has_save() -> bool:
	if FileAccess.file_exists(PATH) or FileAccess.file_exists(BAK):
		return true
	for p in LEGACY:
		if FileAccess.file_exists(p):
			return true
	return false

static func write(data: Dictionary) -> bool:
	data["version"] = VERSION
	_copy(BAK, BAK2)
	_copy(PATH, BAK)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true

static func read() -> Dictionary:
	for p in [PATH, BAK, BAK2]:
		var d := _read_file(p)
		if not d.is_empty():
			return migrate(d)
	for p in LEGACY:
		var d2 := _read_file(p)
		if not d2.is_empty():
			return migrate(d2)
	return {}

static func wipe() -> void:
	_copy(PATH, PREV)
	for p in [PATH, BAK, BAK2]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

static func migrate(d: Dictionary) -> Dictionary:
	var version := int(d.get("version", 1))
	if version >= VERSION and d.has("money") and d.has("owned"):
		return d
	var stats = d.get("stats", {})
	if typeof(stats) != TYPE_DICTIONARY:
		stats = {}
	var owned = d.get("owned", {})
	if typeof(owned) != TYPE_DICTIONARY:
		owned = {}
	return {
		"version": VERSION,
		"money": int(d.get("money", d.get("earnings", 0))),
		"owned": owned,
		"ammo": int(d.get("ammo", 0)),
		"snacks": int(d.get("snacks", 0)),
		"vest": str(d.get("vest", "")),
		"mag": int(d.get("mag", 0)),
		"shifts_done": int(d.get("shifts_done", 0)),
		"play_seconds": float(d.get("play_seconds", 0.0)),
		"shift_active": bool(d.get("shift_active", false)),
		"shift_elapsed": float(d.get("shift_elapsed", 0.0)),
		"stats": stats,
		"cart_pay_mult": float(d.get("cart_pay_mult", 1.0)),
	}

static func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

static func _copy(src: String, dst: String) -> void:
	if not FileAccess.file_exists(src):
		return
	var f := FileAccess.open(dst, FileAccess.WRITE)
	if f:
		f.store_string(FileAccess.get_file_as_string(src))
