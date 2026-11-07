extends CanvasLayer
## HUD in the concept-art style: clock icon + NIGHT SHIFT/time (top-left), $X EARNINGS
## (top-right), scanner status (bottom-left), task hints, prompt, toast, pause (with
## settings), cash-drawer change panel and end-of-shift summary. All built in code.

signal resume_pressed
signal menu_pressed
signal change_confirmed(given: int)
signal change_cancelled

const GREEN := Color(0.55, 0.95, 0.45)
const WHITE := Color(0.93, 0.93, 0.9)
const AMBER := Color(1.0, 0.75, 0.3)

class Icon extends Control:
	var kind := "clock"
	func _draw() -> void:
		var c := Color(0.93, 0.93, 0.9)
		if kind == "clock":
			var ctr := size * 0.5
			draw_arc(ctr, size.x * 0.42, 0, TAU, 32, c, 3.0, true)
			draw_line(ctr, ctr + Vector2(0, -size.x * 0.27), c, 3.0, true)
			draw_line(ctr, ctr + Vector2(size.x * 0.2, 0), c, 3.0, true)
		else:  # handheld scanner
			var w := size.x
			draw_rect(Rect2(w * 0.15, 0, w * 0.7, w * 0.42), c, false, 3.0)
			draw_rect(Rect2(w * 0.32, w * 0.42, w * 0.3, w * 0.62), c, false, 3.0)
			draw_line(Vector2(w * 0.28, w * 0.13), Vector2(w * 0.72, w * 0.13), c, 2.0)

var font: SystemFont
var clock_label: Label
var money_label: Label
var status_title: Label
var status_label: Label
var tasks_label: Label
var prompt_label: Label
var toast_label: Label
var pause_panel: Control
var summary_panel: Control
var summary_text: Label
var change_panel: Control
var change_info: Label
var change_given_label: Label
var _change_given := 0
var _toast_t := 0.0

func _ready() -> void:
	layer = 10
	font = SystemFont.new()
	font.font_names = PackedStringArray(["DejaVu Sans Mono", "Menlo", "Consolas", "Courier New", "monospace"])
	font.font_weight = 700
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# top-left
	var ic := Icon.new()
	ic.kind = "clock"
	ic.position = Vector2(28, 26)
	ic.size = Vector2(40, 40)
	root.add_child(ic)
	_label(root, "NIGHT SHIFT", 22, WHITE).position = Vector2(84, 22)
	clock_label = _label(root, "10:00 PM", 22, WHITE)
	clock_label.position = Vector2(84, 50)
	_line(root, Vector2(28, 84), 230)
	tasks_label = _label(root, "", 17, AMBER)
	tasks_label.position = Vector2(28, 94)
	# top-right
	money_label = _label(root, "$0", 40, GREEN)
	money_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	money_label.offset_left = -260
	money_label.offset_right = -40
	money_label.offset_top = 12
	var earn := _label(root, "EARNINGS", 20, WHITE)
	earn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	earn.offset_left = -260
	earn.offset_right = -40
	earn.offset_top = 62
	var rl := _line(root, Vector2(0, 0), 140)
	rl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rl.offset_left = -258
	rl.offset_right = -118
	rl.offset_top = 92
	rl.offset_bottom = 94
	# bottom-left
	var si := Icon.new()
	si.kind = "scanner"
	si.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	si.offset_left = 30; si.offset_right = 64; si.offset_top = -92; si.offset_bottom = -58
	root.add_child(si)
	status_title = _label(root, "BARCODE SCANNER", 20, WHITE)
	status_title.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status_title.offset_left = 84; status_title.offset_top = -96; status_title.offset_right = 600
	status_label = _label(root, "READY", 20, GREEN)
	status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.offset_left = 84; status_label.offset_top = -68; status_label.offset_right = 600
	# center
	var cross := ColorRect.new()
	cross.color = Color(1, 1, 1, 0.75)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.offset_left = -2; cross.offset_right = 2; cross.offset_top = -2; cross.offset_bottom = 2
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)
	prompt_label = _label(root, "", 20, Color(1, 1, 0.85))
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.offset_left = -500; prompt_label.offset_right = 500
	prompt_label.offset_top = -170; prompt_label.offset_bottom = -130
	toast_label = _label(root, "", 20, GREEN)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.offset_left = -500; toast_label.offset_right = 500
	toast_label.offset_top = 110; toast_label.offset_bottom = 150
	# panels
	var pb := _panel(root, "PAUSED")
	pause_panel = pb[0]
	_button(pb[1], "Resume", func(): resume_pressed.emit())
	Settings.add_sliders(pb[1])
	_button(pb[1], "Quit to Menu", func(): menu_pressed.emit())
	var sb := _panel(root, "SHIFT OVER")
	summary_panel = sb[0]
	summary_text = _label(sb[1], "", 20, WHITE)
	summary_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(sb[1], "Back to Menu", func(): menu_pressed.emit())
	_build_change_panel(root)

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _line(parent: Node, pos: Vector2, w: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.93, 0.93, 0.9, 0.85)
	r.position = pos
	r.size = Vector2(w, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _button(parent: Node, text: String, cb: Callable, w := 260) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 46)
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _panel(root: Control, title: String) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	root.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	dim.add_child(box)
	var t := _label(box, title, 46, GREEN)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return [dim, box]

func _build_change_panel(root: Control) -> void:
	change_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.05, 0.92)
	sb.border_color = GREEN
	sb.set_border_width_all(2)
	sb.set_content_margin_all(18)
	change_panel.add_theme_stylebox_override("panel", sb)
	change_panel.set_anchors_preset(Control.PRESET_CENTER)
	change_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	change_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	change_panel.visible = false
	root.add_child(change_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	change_panel.add_child(v)
	var t := _label(v, "CASH DRAWER", 30, GREEN)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	change_info = _label(v, "", 22, WHITE)
	change_given_label = _label(v, "", 26, AMBER)
	change_given_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for d in [2000, 1000, 500, 100, 25, 10, 5, 1]:
		var txt := ("$%d" % (d / 100)) if d >= 100 else ("%d¢" % d)
		var b := _button(grid, txt, func(): _add_change(d), 110)
		b.custom_minimum_size = Vector2(110, 56)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.22, 0.4, 0.22) if d >= 100 else Color(0.45, 0.42, 0.35)
		st.set_corner_radius_all(4)
		b.add_theme_stylebox_override("normal", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	_button(h, "Clear", _clear_change, 140)
	_button(h, "GIVE CHANGE", func(): change_confirmed.emit(_change_given), 200)
	_button(h, "Close", func(): change_cancelled.emit(), 120)

var _due := 0
func open_change(total: int, cash: int) -> void:
	_change_given = 0
	_due = cash - total
	change_info.text = "TOTAL       $%7.2f\nCASH GIVEN  $%7.2f\nCHANGE DUE  $%7.2f" % [total / 100.0, cash / 100.0, _due / 100.0]
	_refresh_change()
	change_panel.visible = true

func close_change() -> void:
	change_panel.visible = false

func _clear_change() -> void:
	_change_given = 0
	_refresh_change()

func _add_change(d: int) -> void:
	_change_given += d
	_refresh_change()
	var g := get_parent()
	if g and g.has_method("play_sfx"):
		g.play_sfx("click")

func _refresh_change() -> void:
	change_given_label.text = "COUNTED: $%.2f" % (_change_given / 100.0)
	change_given_label.add_theme_color_override("font_color", GREEN if _change_given == _due else AMBER)

func set_clock(text: String) -> void:
	clock_label.text = text

func set_money(cents: int) -> void:
	money_label.text = ("$%d" % (cents / 100)) if cents % 100 == 0 else "$%.2f" % (cents / 100.0)

func set_prompt(text: String) -> void:
	prompt_label.text = text

func set_status(title: String, text: String, ok := true) -> void:
	status_title.text = title
	status_label.text = text
	status_label.add_theme_color_override("font_color", GREEN if ok else AMBER)

func set_tasks(lines: Array) -> void:
	tasks_label.text = "\n".join(lines)

func toast(text: String, secs := 2.5) -> void:
	toast_label.text = text
	_toast_t = secs

func show_pause(on: bool) -> void:
	pause_panel.visible = on

func show_summary(stats: Dictionary) -> void:
	summary_text.text = "Earnings:            $%.2f\nTips:                $%.2f\nCustomers served:    %d\nCustomers who left:  %d\nItems stocked:       %d\nOut-of-stock misses: %d\nCorrect change:      %d / %d\nTrash bags out:      %d" % [
		stats.earnings / 100.0, stats.tips / 100.0, stats.served, stats.walked, stats.stocked,
		stats.oos, stats.change_ok, stats.change_ok + stats.change_bad, stats.trash]
	summary_panel.visible = true

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_label.text = ""
