class_name Settings
## Persistent settings (user://settings.cfg): mouse sensitivity + volume.

const PATH := "user://settings.cfg"
static var mouse_sens := 1.0
static var volume := 0.8
static var _loaded := false

static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		mouse_sens = cf.get_value("input", "mouse_sens", 1.0)
		volume = cf.get_value("audio", "volume", 0.8)
	apply()

static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("input", "mouse_sens", mouse_sens)
	cf.set_value("audio", "volume", volume)
	cf.save(PATH)

static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))

## Adds two labelled sliders (mouse sensitivity, volume) to a container.
static func add_sliders(box: Container) -> void:
	load_settings()
	for spec in [["Mouse sensitivity", 0.2, 3.0, mouse_sens, "mouse_sens"], ["Volume", 0.0, 1.0, volume, "volume"]]:
		var l := Label.new()
		l.text = spec[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
		var s := HSlider.new()
		s.min_value = spec[1]
		s.max_value = spec[2]
		s.step = 0.05
		s.value = spec[3]
		s.custom_minimum_size = Vector2(320, 24)
		var key: String = spec[4]
		s.value_changed.connect(func(v: float):
			if key == "mouse_sens":
				mouse_sens = v
			else:
				volume = v
				apply()
			save_settings())
		box.add_child(s)
