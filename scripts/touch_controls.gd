class_name TouchControls
extends CanvasLayer
## On-screen touch controls (only created on mobile / with `-- --touch`).
## Left: a smaller virtual joystick. Right side: drag to look.
## USE, a small RUN, and pause (they do not overlap). Contextual buttons
## (cart, gun, fire, light) appear only when they apply. No jump, no put-back.

var game: Node
var player: Node
var overlay: Control
var safe := Rect2()            # safe area in viewport coordinates
var joy_center := Vector2.ZERO
var joy_radius := 62.0
var _sig := ""
var joy_knob := Vector2.ZERO
var joy_idx := -1
var look_idx := -1
var buttons: Array = []        # {name, label, center, radius, action, toggle}
var pressed := {}              # touch index -> button
const LOOK_SPEED := 0.0045

class Overlay extends Control:
	var tc
	func _draw() -> void:
		tc._draw_controls(self)

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = Overlay.new()
	overlay.tc = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	safe = Hud.safe_rect(get_viewport())
	joy_center = Vector2(safe.position.x + 84, safe.end.y - 84)
	var use_c := Vector2(safe.end.x - 70, safe.end.y - 70)
	buttons = [
		{"name": "use", "label": "USE", "center": use_c, "radius": 48.0, "action": "interact"},
		{"name": "run", "label": "RUN", "center": Vector2(safe.position.x + 28, safe.position.y + 26), "radius": 20.0, "action": "", "toggle": true},
		{"name": "pause", "label": "II", "center": Vector2(safe.end.x - 28, safe.position.y + 26), "radius": 24.0, "action": "ui_cancel"},
	]
	var extra: Array = []
	if player:
		if player.holding_cart or player.near_cart:
			extra.append({"name": "cart", "label": "DROP" if player.holding_cart else "CART", "action": "cart"})
		if player.has_gun:
			extra.append({"name": "gun", "label": "ARM" if not player.gun_out else "AWAY", "action": "gun"})
		if player.gun_out:
			extra.append({"name": "fire", "label": "FIRE", "action": "fire"})
			extra.append({"name": "reload", "label": "LOAD", "action": "reload"})
		if game and game.has_flashlight():
			extra.append({"name": "light", "label": "LIGHT", "action": "flashlight"})
		if game and int(game.snacks) > 0:
			extra.append({"name": "snack", "label": "EAT", "action": "snack"})
	var x := use_c.x - 78.0
	var y := use_c.y
	for spec in extra:
		buttons.append({"name": spec.name, "label": spec.label, "center": Vector2(x, y), "radius": 26.0, "action": spec.action})
		y -= 60.0
		if y < safe.position.y + 70.0:
			y = use_c.y
			x -= 62.0
	overlay.queue_redraw()

func _context_sig() -> String:
	if player == null or game == null:
		return ""
	return "%s|%s|%s|%s|%s|%s" % [player.holding_cart != null, player.near_cart != null, player.has_gun, player.gun_out, game.has_flashlight(), game.snacks]

func _active() -> bool:
	return visible and game and not get_tree().paused and not game.shift_over and game._change_reg == null

func _process(_d: float) -> void:
	var sig := _context_sig()
	if sig != _sig and visible:
		_sig = sig
		_layout()
	var want: bool = game != null and not get_tree().paused and not game.shift_over and game._change_reg == null and not game.hud.shop_panel.visible
	if want != visible:
		visible = want
		if not want:
			_release_all()

func _button_at(p: Vector2) -> Dictionary:
	for b in buttons:
		if p.distance_to(b.center) <= b.radius * 1.15:
			return b
	return {}

func _send(action: String, down: bool) -> void:
	if action == "":
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = down
	Input.parse_input_event(ev)

func _input(event: InputEvent) -> void:
	if not _active():
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			var b := _button_at(p)
			if not b.is_empty():
				pressed[event.index] = b
				if b.get("toggle", false):
					player.sprint_toggle = not player.sprint_toggle
				else:
					_send(b.action, true)
			elif p.x < get_viewport().get_visible_rect().size.x * 0.42 and joy_idx < 0:
				joy_idx = event.index
				var home := Vector2(safe.position.x + 84, safe.end.y - 84)
				joy_center = p if p.distance_to(home) > joy_radius * 1.5 else home
				_update_joy(p)
			elif look_idx < 0:
				look_idx = event.index
			get_viewport().set_input_as_handled()
		else:
			if pressed.has(event.index):
				var b: Dictionary = pressed[event.index]
				pressed.erase(event.index)
				_send(b.action, false)
			if event.index == joy_idx:
				joy_idx = -1
				joy_center = Vector2(safe.position.x + 84, safe.end.y - 84)
				_update_joy(joy_center)
			if event.index == look_idx:
				look_idx = -1
		overlay.queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == joy_idx:
			_update_joy(event.position)
			overlay.queue_redraw()
			get_viewport().set_input_as_handled()
		elif event.index == look_idx:
			player.touch_look(event.relative * LOOK_SPEED * Settings.mouse_sens)
			get_viewport().set_input_as_handled()

func _update_joy(p: Vector2) -> void:
	var d := p - joy_center
	if d.length() > joy_radius:
		d = d.normalized() * joy_radius
	joy_knob = d
	var v := d / joy_radius
	player.touch_move = v if v.length() > 0.12 else Vector2.ZERO

func _release_all() -> void:
	for idx in pressed:
		_send(pressed[idx].action, false)
	pressed.clear()
	joy_idx = -1
	look_idx = -1
	if player:
		player.touch_move = Vector2.ZERO
	joy_knob = Vector2.ZERO

func _draw_controls(c: Control) -> void:
	var font := ThemeDB.fallback_font
	c.draw_circle(joy_center, joy_radius, Color(0, 0, 0, 0.28))
	c.draw_arc(joy_center, joy_radius, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	c.draw_circle(joy_center + joy_knob, 26, Color(1, 1, 1, 0.35 if joy_idx < 0 else 0.6))
	for b in buttons:
		var on: bool = pressed.values().has(b) or (b.name == "run" and player and player.sprint_toggle)
		var col := Color(0.55, 0.95, 0.45, 0.55) if on else Color(0, 0, 0, 0.32)
		if b.name == "use":
			col = Color(0.55, 0.95, 0.45, 0.6) if on else Color(0.1, 0.3, 0.1, 0.45)
		c.draw_circle(b.center, b.radius, col)
		c.draw_arc(b.center, b.radius, 0, TAU, 40, Color(1, 1, 1, 0.55), 3.0, true)
		var fs := 18 if b.name == "use" else 13
		var lines: PackedStringArray = String(b.label).split("\n")
		for i in lines.size():
			var w := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var y: float = b.center.y + fs * 0.35 + (i - (lines.size() - 1) * 0.5) * fs * 1.05
			c.draw_string(font, Vector2(b.center.x - w * 0.5, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
