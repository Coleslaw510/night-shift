class_name Settings
## Persistent settings (user://settings.cfg): mouse sensitivity + volume.

const PATH := "user://settings.cfg"
static var mouse_sens := 1.0
static var volume := 0.8
static var gfx_preset := ""
static var gfx_scale := 1.0
static var fps_cap := 0
static var show_fps := false
static var host: Node = null
static var _loaded := false
static var _scale_slider: HSlider
static var _preset_buttons: Array = []
static var _cap_buttons: Array = []

static func bind(n: Node) -> void:
	host = n

static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var mobile := OS.has_feature("mobile")
	gfx_preset = "low" if mobile else "high"
	gfx_scale = 0.7 if mobile else 1.0
	fps_cap = 60 if mobile else 0
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		mouse_sens = cf.get_value("input", "mouse_sens", 1.0)
		volume = cf.get_value("audio", "volume", 0.8)
		gfx_preset = str(cf.get_value("graphics", "preset", gfx_preset))
		gfx_scale = float(cf.get_value("graphics", "scale", gfx_scale))
		fps_cap = int(cf.get_value("graphics", "fps_cap", fps_cap))
		show_fps = bool(cf.get_value("graphics", "show_fps", false))
	apply()

static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("input", "mouse_sens", mouse_sens)
	cf.set_value("audio", "volume", volume)
	cf.set_value("graphics", "preset", gfx_preset)
	cf.set_value("graphics", "scale", gfx_scale)
	cf.set_value("graphics", "fps_cap", fps_cap)
	cf.set_value("graphics", "show_fps", show_fps)
	cf.save(PATH)

static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	if host and host.has_method("apply_graphics"):
		host.apply_graphics()

static func preset_scale(key: String) -> float:
	match key:
		"low":
			return 0.7
		"medium":
			return 0.85
		_:
			return 1.0

## Adds two labelled sliders (mouse sensitivity, volume) to a container.
static func add_sliders(box: Container) -> void:
	load_settings()
	for spec in [["Look sensitivity", 0.2, 3.0, mouse_sens, "mouse_sens"], ["Volume", 0.0, 1.0, volume, "volume"]]:
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
	add_graphics(box)

static func add_graphics(box: Container) -> void:
	load_settings()
	var title := Label.new()
	title.text = "Graphics"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	_preset_buttons.clear()
	for name in ["Low", "Medium", "High", "Ultra"]:
		var b := Button.new()
		var key: String = str(name).to_lower()
		b.text = name
		b.toggle_mode = true
		b.button_pressed = gfx_preset == key
		b.pressed.connect(_pick_preset.bind(key))
		row.add_child(b)
		_preset_buttons.append(b)
	var scale_l := Label.new()
	scale_l.text = "Render scale"
	scale_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(scale_l)
	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.5
	_scale_slider.max_value = 1.0
	_scale_slider.step = 0.05
	_scale_slider.value = gfx_scale
	_scale_slider.custom_minimum_size = Vector2(320, 24)
	_scale_slider.value_changed.connect(func(v: float):
		gfx_scale = v
		apply()
		save_settings())
	box.add_child(_scale_slider)
	var cap_l := Label.new()
	cap_l.text = "FPS cap"
	cap_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap_l)
	var caps := HBoxContainer.new()
	caps.alignment = BoxContainer.ALIGNMENT_CENTER
	caps.add_theme_constant_override("separation", 6)
	box.add_child(caps)
	_cap_buttons.clear()
	for spec in [["30", 30], ["60", 60], ["Max", 0]]:
		var b2 := Button.new()
		b2.text = spec[0]
		b2.toggle_mode = true
		var cap := int(spec[1])
		b2.button_pressed = fps_cap == cap
		b2.pressed.connect(_set_cap.bind(cap))
		caps.add_child(b2)
		_cap_buttons.append(b2)
	var fps := CheckButton.new()
	fps.text = "FPS counter"
	fps.button_pressed = show_fps
	fps.toggled.connect(func(on: bool):
		show_fps = on
		apply()
		save_settings())
	box.add_child(fps)

static func _set_cap(cap: int) -> void:
	fps_cap = cap
	apply()
	save_settings()
	_mark_caps()

static func _pick_preset(key: String) -> void:
	gfx_preset = key
	gfx_scale = preset_scale(key)
	if _scale_slider:
		_scale_slider.set_value_no_signal(gfx_scale)
	_mark_presets()
	apply()
	save_settings()

static func _mark_presets() -> void:
	for b in _preset_buttons:
		if b is Button:
			b.button_pressed = str(b.text).to_lower() == gfx_preset

static func _mark_caps() -> void:
	for b in _cap_buttons:
		if b is Button:
			var cap := 60 if b.text == "60" else (30 if b.text == "30" else 0)
			b.button_pressed = cap == fps_cap
