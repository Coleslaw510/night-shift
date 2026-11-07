extends CanvasLayer
## HUD: title + clock (top-left), earnings (top-right), crosshair, interact prompt,
## toast messages, pause menu and end-of-shift summary. Built in code.

signal resume_pressed
signal menu_pressed

var clock_label: Label
var money_label: Label
var prompt_label: Label
var toast_label: Label
var pause_panel: Control
var summary_panel: Control
var summary_text: Label
var _toast_t := 0.0

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var title := _label(root, "NIGHT SHIFT", 30, Color(0.75, 1.0, 0.85))
	title.position = Vector2(24, 16)
	clock_label = _label(root, "10:00 PM", 26, Color(0.9, 0.9, 0.85))
	clock_label.position = Vector2(26, 56)
	money_label = _label(root, "$0.00", 34, Color(0.5, 1.0, 0.55))
	money_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_label.offset_left = -300
	money_label.offset_right = -24
	money_label.offset_top = 16
	var cross := _label(root, "+", 24, Color(1, 1, 1, 0.8))
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.offset_left = -20; cross.offset_right = 20; cross.offset_top = -20; cross.offset_bottom = 20
	prompt_label = _label(root, "", 22, Color(1, 1, 0.8))
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.offset_left = -400; prompt_label.offset_right = 400
	prompt_label.offset_top = -140; prompt_label.offset_bottom = -100
	toast_label = _label(root, "", 22, Color(0.6, 1.0, 0.7))
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.offset_left = -400; toast_label.offset_right = 400
	toast_label.offset_top = 90; toast_label.offset_bottom = 130
	pause_panel = _panel(root, "PAUSED", [["Resume", func(): resume_pressed.emit()], ["Quit to Menu", func(): menu_pressed.emit()]])
	summary_panel = _panel(root, "SHIFT OVER", [["Back to Menu", func(): menu_pressed.emit()]])
	summary_text = _label(summary_panel.get_child(0), "", 26, Color(0.9, 0.95, 0.9))
	summary_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_panel.get_child(0).move_child(summary_text, 1)

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _panel(root: Control, title: String, buttons: Array) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	root.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	dim.add_child(box)
	var t := _label(box, title, 56, Color(0.75, 1.0, 0.85))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for spec in buttons:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(260, 50)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(spec[1])
		box.add_child(b)
	return dim

func set_clock(text: String) -> void:
	clock_label.text = text

func set_money(v: float) -> void:
	money_label.text = "$%.2f" % v

func set_prompt(text: String) -> void:
	prompt_label.text = text

func toast(text: String, secs := 2.5) -> void:
	toast_label.text = text
	_toast_t = secs

func show_pause(on: bool) -> void:
	pause_panel.visible = on

func show_summary(earned: float, served: int, walked: int) -> void:
	summary_text.text = "Earnings: $%.2f\nCustomers served: %d\nCustomers who gave up: %d" % [earned, served, walked]
	summary_panel.visible = true

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_label.text = ""
