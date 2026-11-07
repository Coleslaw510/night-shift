class_name Hud
extends CanvasLayer
## HUD in the concept-art style: clock icon + NIGHT SHIFT/time (top-left), $X EARNINGS
## (top-right), scanner status (bottom-left), task hints, prompt, toast, pause (with
## settings), cash-drawer change panel and end-of-shift summary. All built in code.

signal resume_pressed
signal menu_pressed
signal change_confirmed(given: int)
signal change_cancelled
signal shop_buy(id: String)
signal shop_eat
signal shop_closed

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
var fps_label: Label
var inventory_label: Label
var pause_panel: Control
var summary_panel: Control
var summary_text: Label
var change_panel: Control
var change_info: Label
var change_given_label: Label
var _change_given := 0
var _toast_t := 0.0
var root: Control
var touch_mode := false

## Safe area (notch / home bar) in viewport coordinates, with a small inset.
static func safe_rect(v: Viewport) -> Rect2:
	var vp := v.get_visible_rect().size
	if OS.has_feature("mobile"):
		var sa := DisplayServer.get_display_safe_area()
		var ws := Vector2(DisplayServer.window_get_size())
		if ws.x > 0 and sa.size.x > 0:
			var k := vp / ws
			return Rect2(Vector2(sa.position) * k, Vector2(sa.size) * k).grow(-10)
	return Rect2(Vector2(0, 0), vp)

func _apply_safe_area() -> void:
	var r := safe_rect(get_viewport())
	var vp := get_viewport().get_visible_rect().size
	root.offset_left = r.position.x
	root.offset_top = r.position.y
	root.offset_right = r.end.x - vp.x
	root.offset_bottom = r.end.y - vp.y

func _ready() -> void:
	layer = 10
	font = SystemFont.new()
	font.font_names = PackedStringArray(["DejaVu Sans Mono", "Menlo", "Consolas", "Courier New", "monospace"])
	font.font_weight = 700
	root = Control.new()
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
	fps_label = _label(root, "", 16, GREEN)
	fps_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_label.offset_left = -80
	fps_label.offset_right = 80
	fps_label.offset_top = 4
	fps_label.offset_bottom = 24
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
	si.visible = false
	root.add_child(si)
	status_title = _label(root, "", 20, WHITE)
	status_title.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status_title.offset_left = 84; status_title.offset_top = -96; status_title.offset_right = 600
	status_label = _label(root, "", 20, GREEN)
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
	_button(pb[1], "Save", func():
		var g := get_parent()
		if g and g.has_method("save_progress"):
			g.save_progress()
			toast("Saved"))
	_button(pb[1], "Shop", func():
		var g := get_parent()
		if g and g.has_method("open_shop"):
			g.open_shop(true))
	Settings.add_sliders(pb[1])
	_button(pb[1], "Quit to Menu", func(): menu_pressed.emit())
	var sb := _panel(root, "SHIFT OVER")
	summary_panel = sb[0]
	summary_text = _label(sb[1], "", 20, WHITE)
	summary_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(sb[1], "Back to Menu", func(): menu_pressed.emit())
	_build_change_panel(root)
	_build_fuel_meter(root)
	_build_shop(root)
	_build_stamina(root)
	if touch_mode:
		# Joystick lives bottom-left on touch screens: move the scanner status to the top center.
		for l in [status_title, status_label]:
			l.set_anchors_preset(Control.PRESET_CENTER_TOP)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.offset_left = -300; l.offset_right = 300
		status_title.offset_top = 6
		status_label.offset_top = 32
		toast_label.offset_top = 70; toast_label.offset_bottom = 110
		prompt_label.offset_top = -110; prompt_label.offset_bottom = -70
		prompt_label.offset_left = -330; prompt_label.offset_right = 330
		prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		si.visible = false
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)

func set_inventory(slot_one: String, slot_two: String) -> void:
	if inventory_label:
		inventory_label.text = "[ %s ]   [ %s ]" % [slot_one, slot_two]

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

var fuel_panel: PanelContainer
var fuel_fill: ColorRect
var fuel_mark: ColorRect
var fuel_readout: Label

func _build_fuel_meter(root: Control) -> void:
	fuel_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.04, 0.88)
	sb.border_color = AMBER
	sb.set_border_width_all(2)
	sb.set_content_margin_all(12)
	fuel_panel.add_theme_stylebox_override("panel", sb)
	fuel_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	fuel_panel.offset_left = -210
	fuel_panel.offset_right = 210
	fuel_panel.offset_top = -250
	fuel_panel.offset_bottom = -160
	fuel_panel.visible = false
	fuel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fuel_panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fuel_panel.add_child(v)
	fuel_readout = _label(v, "PUMP", 18, AMBER)
	fuel_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(380, 28)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar)
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.15)
	bg.size = Vector2(380, 18)
	bg.position = Vector2(0, 5)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bg)
	fuel_fill = ColorRect.new()
	fuel_fill.color = Color(0.95, 0.55, 0.1)
	fuel_fill.size = Vector2(4, 18)
	fuel_fill.position = Vector2(0, 5)
	fuel_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(fuel_fill)
	fuel_mark = ColorRect.new()
	fuel_mark.color = Color(0.6, 1, 0.5)
	fuel_mark.size = Vector2(3, 26)
	fuel_mark.position = Vector2(0, 1)
	fuel_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(fuel_mark)

func show_fuel_meter(on: bool) -> void:
	fuel_panel.visible = on

func set_fuel_meter(value: float, target: float, maxc: float) -> void:
	var w := 380.0
	var f := clampf(value / maxf(maxc, 1.0), 0.0, 1.0)
	fuel_fill.size.x = maxf(2.0, w * f)
	fuel_mark.position.x = w * clampf(target / maxf(maxc, 1.0), 0.0, 1.0)
	fuel_readout.text = "PUMP $%.2f    STOP NEAR $%.2f" % [value / 100.0, target / 100.0]

var shop_panel: Control
var shop_list: VBoxContainer
var stamina_bar: ColorRect
var stamina_back: ColorRect

func _build_stamina(root: Control) -> void:
	stamina_back = ColorRect.new()
	stamina_back.color = Color(0, 0, 0, 0.45)
	stamina_back.position = Vector2(84, 78)
	stamina_back.size = Vector2(140, 6)
	stamina_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_back.visible = false
	root.add_child(stamina_back)
	stamina_bar = ColorRect.new()
	stamina_bar.color = Color(0.45, 0.85, 1)
	stamina_bar.position = Vector2(84, 78)
	stamina_bar.size = Vector2(140, 6)
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_bar.visible = false
	root.add_child(stamina_bar)

func set_stamina(frac: float, boosted: bool) -> void:
	var show := frac < 0.98 or boosted
	stamina_back.visible = show
	stamina_bar.visible = show
	stamina_bar.size.x = 140.0 * clampf(frac, 0.0, 1.0)
	stamina_bar.color = Color(1, 0.8, 0.3) if boosted else Color(0.45, 0.85, 1)

func _build_shop(root: Control) -> void:
	shop_panel = ColorRect.new()
	shop_panel.color = Color(0, 0, 0, 0.78)
	shop_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_panel.visible = false
	root.add_child(shop_panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(460, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_panel.add_child(box)
	var title := _label(box, "BACK OFFICE", 32, GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 340)
	box.add_child(scroll)
	shop_list = VBoxContainer.new()
	shop_list.custom_minimum_size = Vector2(440, 0)
	shop_list.add_theme_constant_override("separation", 6)
	scroll.add_child(shop_list)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_button(row, "Eat snack", func(): shop_eat.emit(), 180)
	_button(row, "Close", func(): shop_closed.emit(), 140)

func show_shop(rows: Array) -> void:
	for c in shop_list.get_children():
		c.queue_free()
	for row in rows:
		var b := Button.new()
		b.text = row.label
		b.disabled = row.disabled
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(430, 36)
		var id: String = row.id
		b.pressed.connect(func(): shop_buy.emit(id))
		shop_list.add_child(b)
	shop_panel.visible = true
	# Re-center after the list exists.
	var box := shop_panel.get_child(0)
	box.position = (shop_panel.size - box.size) * 0.5

func hide_shop() -> void:
	shop_panel.visible = false

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
	status_title.visible = title != ""
	status_label.visible = text != ""
	status_label.add_theme_color_override("font_color", GREEN if ok else AMBER)

func set_tasks(lines: Array) -> void:
	tasks_label.text = "\n".join(lines)

func toast(text: String, secs := 2.5) -> void:
	toast_label.text = text
	_toast_t = secs

func show_pause(on: bool) -> void:
	pause_panel.visible = on

func show_summary(stats: Dictionary) -> void:
	summary_text.text = "Earnings:            $%.2f\nTips:                $%.2f\nCustomers served:    %d\nCustomers who left:  %d\nItems stocked:       %d\nOut-of-stock misses: %d\nCorrect change:      %d / %d\nTrash bags out:      %d\nCarts returned:      %d\nFuel jobs:           %d" % [
		stats.earnings / 100.0, stats.tips / 100.0, stats.served, stats.walked, stats.stocked,
		stats.oos, stats.change_ok, stats.change_ok + stats.change_bad, stats.trash, stats.get("carts", 0), stats.get("fuel", 0)]
	summary_panel.visible = true

func _process(delta: float) -> void:
	if fps_label:
		fps_label.visible = Settings.show_fps
		if Settings.show_fps:
			fps_label.text = "%d FPS" % int(Engine.get_frames_per_second())
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_label.text = ""
