class_name StoreBuilder
## Builds the store, stockroom and outside lot from primitive meshes.
## Layout (meters, +Z = front/entrance) is documented in HANDOFF.md.
## Returns refs: lights, lanes, front_door, back_door, can, dumpster, locker, crates.

const W := 40.0                        # sales floor x -20..20
const D := 46.0                        # front wall at z = 23
const H := 3.8
const SHELF_X := [-16.0, -12.6, -9.2, -5.8, -2.2, 2.2, 5.8, 9.2, 12.6, 16.0]
const SHELF_Z0 := -11.0
const SHELF_Z1 := 6.0
const AISLE_X := [-18.2, -14.3, -10.9, -7.5, -4.0, 0.0, 4.0, 7.5, 10.9, 14.3, 18.2]
const FRONT_Z := 8.2                   # cross corridor in front of the shelves
const BACK_Z := -13.2                  # cross corridor behind the shelves
const LANE_X := [3.15]                 # the one queue, just right of the center aisle
const COUNTER_X := [4.7]
const COUNTER_Z := 14.5
const QUEUE_HEAD_Z := 13.0
const QUEUE_MIN_Z := 9.0
const DOOR_X := 0.0                    # front automatic door, centered
const STOCK_DOOR_X := -14.3            # doorway into the stockroom (left aisle; the freezer blocks x=0)
const BACK_DOOR_X := 14.0              # stockroom back door to the back lot
const ZB := -16.0                      # store back wall (inner face); front wall is at +D/2
const ROOM_Z := -34.0                  # stockroom back wall (18 m deep, full width)
const FENCE := Rect2(-42, -48, 84, 96) # lot x -42..42, z -48..48
const CORRAL_POS := Vector3(-8.0, 0, 28.0)
const FUEL_POS := Vector3(32.0, 0, 31.0)

static var _mats := {}
static var _floor_shader: Shader

static func mat(c: Color, emission: float = 0.0, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [c, emission, rough, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m

static func unshaded(c: Color) -> StandardMaterial3D:
	var m := mat(c).duplicate()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func box(parent: Node, size: Vector3, pos: Vector3, m: Material, collide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	if collide:
		add_collider(parent, size, pos)
	return mi

static func cyl(parent: Node, r: float, h: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 0.92
	cm.height = h
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

static func add_collider(parent: Node, size: Vector3, pos: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	parent.add_child(sb)
	return sb

static func label(parent: Node, text: String, pos: Vector3, size: int, color: Color, rot_y := 0.0, px := 0.004) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.rotation.y = rot_y
	parent.add_child(l)
	return l

static func tiled_floor(tile: float, a: Color, b: Color, grout: Color) -> ShaderMaterial:
	if _floor_shader == null:
		_floor_shader = Shader.new()
		_floor_shader.code = """
shader_type spatial;
uniform vec4 col_a : source_color;
uniform vec4 col_b : source_color;
uniform vec4 grout : source_color;
uniform float tile = 0.6;
uniform float rough = 0.55;
varying vec3 wpos;
float hash(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment(){
	vec2 g = wpos.xz / tile;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 c = mix(col_a.rgb, col_b.rgb, checker);
	c *= 0.9 + 0.2 * hash(cell);
	c *= 0.93 + 0.07 * hash(floor(wpos.xz * 40.0));
	float e = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	c = mix(grout.rgb, c, smoothstep(0.0, 0.03, e));
	ALBEDO = c;
	ROUGHNESS = rough;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _floor_shader
	m.set_shader_parameter("col_a", a)
	m.set_shader_parameter("col_b", b)
	m.set_shader_parameter("grout", grout)
	m.set_shader_parameter("tile", tile)
	return m

static func build(root: Node3D, target: Object) -> Dictionary:
	var store := Node3D.new()
	store.name = "Store"
	root.add_child(store)
	var out := {"lights": [], "lanes": [], "crates": []}
	_environment(root)
	_floor_and_ceiling(store)
	_walls(store, out)
	_lights(store, out)
	_freezer(store)
	_checkouts(store, out, target)
	_stockroom(store, out, target)
	_outside(store, out, target)
	_props(store, out, target)
	return out

static func _environment(root: Node3D) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.01, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.45, 0.38)
	env.ambient_light_energy = 0.24
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.1
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.055, 0.05)
	env.fog_density = 0.02
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.05
	we.environment = env
	root.add_child(we)

static func _floor_and_ceiling(store: Node3D) -> void:
	var hw := W * 0.5
	var hd := D * 0.5
	var fm := tiled_floor(0.6, Color(0.31, 0.3, 0.28), Color(0.28, 0.27, 0.26), Color(0.18, 0.18, 0.17))
	# Floor split in 4x5 m tiles so each mesh gets few lights (Compatibility renderer limit).
	var depth := hd - ZB
	var zc := (hd + ZB) * 0.5
	var x := -hw
	while x < hw - 0.01:
		var z := ZB
		while z < hd - 0.01:
			box(store, Vector3(4, 0.1, depth / 4.0), Vector3(x + 2, -0.05, z + depth / 8.0), fm)
			z += depth / 4.0
		x += 4
	# Stockroom floor (concrete), full width and much deeper than the sales floor
	var cm := tiled_floor(1.5, Color(0.26, 0.26, 0.25), Color(0.22, 0.22, 0.21), Color(0.14, 0.14, 0.14))
	var room_d := ZB - ROOM_Z
	box(store, Vector3(W, 0.1, room_d), Vector3(0, -0.05, (ZB + ROOM_Z) * 0.5), cm)
	# Ceiling: dark panels + grid
	var ceil_m := mat(Color(0.13, 0.13, 0.13), 0.0, 0.95)
	var grid_m := mat(Color(0.06, 0.06, 0.06))
	box(store, Vector3(W, 0.12, depth), Vector3(0, H + 0.06, zc), ceil_m)
	box(store, Vector3(W, 0.12, ZB - ROOM_Z), Vector3(0, H + 0.06, (ZB + ROOM_Z) * 0.5), ceil_m)
	var gx := -hw + 1.2
	while gx < hw:
		box(store, Vector3(0.04, 0.03, depth), Vector3(gx, H - 0.01, zc), grid_m)
		gx += 1.2
	var gz := ZB + 1.2
	while gz < hd:
		box(store, Vector3(W, 0.03, 0.04), Vector3(0, H - 0.01, gz), grid_m)
		gz += 1.2
	# Roof (seen from outside)
	box(store, Vector3(W + 0.6, 0.3, depth + 0.6), Vector3(0, H + 0.27, zc), mat(Color(0.12, 0.11, 0.1)))
	box(store, Vector3(W + 0.6, 0.3, ZB - ROOM_Z + 0.6), Vector3(0, H + 0.27, (ZB + ROOM_Z) * 0.5), mat(Color(0.12, 0.11, 0.1)))

static func _wall_seg(store: Node3D, a: Vector3, b: Vector3, m: Material, h := H, y0 := 0.0, thick := 0.2, collide := true) -> void:
	# Axis-aligned wall from a to b (x or z aligned).
	var c := (a + b) * 0.5
	var size := Vector3(absf(b.x - a.x) + thick, h, absf(b.z - a.z) + thick)
	if absf(b.x - a.x) < 0.01:
		size.x = thick
	else:
		size.z = thick
	box(store, size, Vector3(c.x, y0 + h * 0.5, c.z), m, collide)

static func _walls(store: Node3D, out: Dictionary) -> void:
	var hw := W * 0.5
	var hd := D * 0.5
	var wall := mat(Color(0.36, 0.34, 0.3), 0.0, 0.9)
	var trim := mat(Color(0.16, 0.15, 0.14), 0.0, 0.7)
	var ext := mat(Color(0.3, 0.22, 0.18), 0.0, 0.95)    # brick-ish outside skin
	var frame := mat(Color(0.12, 0.12, 0.13), 0.0, 0.4, 0.6)
	var glass := mat(Color(0.55, 0.65, 0.75, 0.16), 0.0, 0.05, 0.2)
	# Right wall (solid)
	_wall_seg(store, Vector3(hw + 0.1, 0, ZB), Vector3(hw + 0.1, 0, hd), wall)
	# Left wall: windows like the concept (kick wall + glass band + header)
	_wall_seg(store, Vector3(-hw - 0.1, 0, ZB), Vector3(-hw - 0.1, 0, hd), wall, 0.9)
	_wall_seg(store, Vector3(-hw - 0.1, 0, ZB), Vector3(-hw - 0.1, 0, hd), wall, H - 2.8, 2.8)
	_wall_seg(store, Vector3(-hw - 0.1, 0, ZB + 1), Vector3(-hw - 0.1, 0, hd - 1), glass, 1.9, 0.9, 0.04, false)
	add_collider(store, Vector3(0.3, H, hd - ZB), Vector3(-hw - 0.1, H * 0.5, (hd + ZB) * 0.5))
	var z := ZB
	while z <= hd + 0.01:
		box(store, Vector3(0.24, 1.9, 0.14), Vector3(-hw - 0.1, 1.85, z), frame)
		z += 3.0
	# Back wall. The opening is in the left aisle, clear of the freezer (which sits on x=0).
	var door_half := 1.05
	_wall_seg(store, Vector3(-hw, 0, ZB - 0.1), Vector3(STOCK_DOOR_X - door_half, 0, ZB - 0.1), wall)
	_wall_seg(store, Vector3(STOCK_DOOR_X + door_half, 0, ZB - 0.1), Vector3(hw, 0, ZB - 0.1), wall)
	_wall_seg(store, Vector3(STOCK_DOOR_X - door_half, 0, ZB - 0.1), Vector3(STOCK_DOOR_X + door_half, 0, ZB - 0.1), wall, H - 2.35, 2.35)
	box(store, Vector3(door_half * 2.0 + 0.3, 0.22, 0.08), Vector3(STOCK_DOOR_X, 2.5, ZB - 0.05), mat(Color(0.22, 0.2, 0.16)))
	# Strip curtain: visible, no collider, so the player and customers walk straight through.
	var strip := mat(Color(0.45, 0.42, 0.18, 0.55), 0.0, 0.4)
	var sx := STOCK_DOOR_X - door_half + 0.18
	while sx < STOCK_DOOR_X + door_half - 0.05:
		box(store, Vector3(0.1, 2.15, 0.02), Vector3(sx, 1.15, ZB - 0.02), strip)
		sx += 0.28
	box(store, Vector3(2.0, 0.22, 0.05), Vector3(STOCK_DOOR_X, 2.85, ZB + 0.04), mat(Color(0.75, 0.1, 0.08), 1.2))
	label(store, "EMPLOYEES ONLY", Vector3(STOCK_DOOR_X, 2.85, ZB + 0.08), 40, Color(1, 0.95, 0.9))
	# Front storefront: real glass both sides of the door gap
	var g0 := DOOR_X - 1.15
	var g1 := DOOR_X + 1.15
	for seg in [[-hw, g0], [g1, hw]]:
		var sw: float = seg[1] - seg[0]
		var sc: float = (seg[0] + seg[1]) * 0.5
		box(store, Vector3(sw, 0.5, 0.25), Vector3(sc, 0.25, hd), frame, true)
		box(store, Vector3(sw, H - 3.0 + 0.5, 0.05), Vector3(sc, 0.5 + (H - 3.0 + 0.5) * 0.5, hd), glass)
		add_collider(store, Vector3(sw, H, 0.3), Vector3(sc, H * 0.5, hd))
	box(store, Vector3(W, H - 3.0 + 0.0, 0.25), Vector3(0, 3.0 + (H - 3.0) * 0.5, hd), frame)
	var px := -hw
	while px <= hw + 0.01:
		if absf(px - DOOR_X) > 1.3:
			box(store, Vector3(0.12, 3.0, 0.27), Vector3(px, 1.5, hd), frame)
		px += 3.0
	for e in [g0, g1]:
		box(store, Vector3(0.14, 3.0, 0.3), Vector3(e, 1.5, hd), frame)
	# Automatic sliding door panels (moved by game.gd)
	var panels: Array = []
	for i in 2:
		var p := Node3D.new()
		p.position = Vector3(DOOR_X + (i * 2 - 1) * 0.575, 0, hd)
		store.add_child(p)
		box(p, Vector3(1.15, 2.6, 0.05), Vector3(0, 1.3, 0), glass)
		box(p, Vector3(1.15, 0.08, 0.08), Vector3(0, 2.6, 0), frame)
		box(p, Vector3(0.06, 2.6, 0.08), Vector3((1 - i * 2) * -0.55, 1.3, 0), frame)
		add_collider(p, Vector3(1.15, 2.6, 0.12), Vector3(0, 1.3, 0))
		panels.append(p)
	out.front_door = {"panels": panels, "closed_x": [DOOR_X - 0.575, DOOR_X + 0.575], "open_x": [DOOR_X - 1.65, DOOR_X + 1.65]}
	box(store, Vector3(2.4, 0.02, 1.4), Vector3(DOOR_X, 0.005, hd - 0.9), mat(Color(0.07, 0.07, 0.08)))
	# Inner wall trim stripe
	for s in [-1, 1]:
		box(store, Vector3(0.04, 0.12, hd - ZB), Vector3(s * (hw - 0.01), 0.06, (hd + ZB) * 0.5), trim)
	box(store, Vector3(W, 0.12, 0.04), Vector3(0, 0.06, ZB + 0.01), trim)
	# Exterior skin on the sales-floor side walls + the store sign (back skin is on the stockroom)
	box(store, Vector3(0.05, H, hd - ZB + 0.4), Vector3(hw + 0.23, H * 0.5, (hd + ZB) * 0.5), ext)
	box(store, Vector3(11, 0.9, 0.2), Vector3(-8, H + 0.75, hd + 0.05), mat(Color(0.1, 0.1, 0.1)))
	label(store, "NIGHT SHIFT MART", Vector3(-8, H + 0.75, hd + 0.17), 120, Color(1.0, 0.25, 0.2), 0.0, 0.007)
	label(store, "OPEN 24 HOURS", Vector3(8.5, 2.6, hd + 0.05), 48, Color(0.3, 1.0, 0.5), 0.0, 0.006)

static func _lights(store: Node3D, out: Dictionary) -> void:
	var housing := mat(Color(0.2, 0.2, 0.2), 0.0, 0.5, 0.3)
	var tube := mat(Color(1.0, 0.96, 0.86), 5.0)
	for fx in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		for fz in [-12.0, -4.0, 4.0, 12.0, 20.0]:
			var f := Node3D.new()
			f.position = Vector3(fx, H - 0.08, fz)
			store.add_child(f)
			box(f, Vector3(0.62, 0.1, 2.5), Vector3.ZERO, housing)
			for tx in [-0.15, 0.15]:
				box(f, Vector3(0.12, 0.04, 2.36), Vector3(tx, -0.06, 0), tube)
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.9, 0.74)
			l.light_energy = 1.0
			l.omni_range = 10.5
			l.omni_attenuation = 1.0
			l.position = Vector3(fx, H - 0.45, fz)
			store.add_child(l)
			l.set_meta("fixture", f)
			l.set_meta("base", l.light_energy)
			out.lights.append(l)

static func _freezer(store: Node3D) -> void:
	var z := ZB + 0.6
	var body := mat(Color(0.22, 0.22, 0.24), 0.0, 0.5, 0.4)
	var glow := mat(Color(0.75, 0.9, 1.0), 2.2)
	var glass := mat(Color(0.7, 0.88, 1.0, 0.2), 0.3, 0.05)
	var frame := mat(Color(0.75, 0.78, 0.8), 0.0, 0.3, 0.7)
	box(store, Vector3(12.4, 2.5, 1.2), Vector3(0, 1.25, z), body)
	add_collider(store, Vector3(12.4, 2.5, 1.3), Vector3(0, 1.25, z))
	box(store, Vector3(12.0, 2.0, 0.04), Vector3(0, 1.2, z - 0.1), glow)
	box(store, Vector3(12.0, 0.06, 0.5), Vector3(0, 2.28, z + 0.2), mat(Color(0.9, 0.97, 1.0), 4.0))  # top light strip   # glowing back
	# shelves + frozen goods inside
	var xf: Array = []
	var cols: Array = []
	for lv in [0.35, 0.8, 1.25, 1.7]:
		box(store, Vector3(12.0, 0.02, 0.5), Vector3(0, lv, z + 0.2), mat(Color(0.85, 0.9, 0.95), 0.4))
		var x := -5.85
		while x < 5.85:
			var p: Dictionary = Products.CATALOG[Products.FROZEN_ITEMS[randi() % Products.FROZEN_ITEMS.size()]]
			var s: Vector3 = p.size
			xf.append(Transform3D(Basis.from_scale(Vector3(s.x, s.y, 0.3)), Vector3(x + s.x * 0.5, lv + 0.01 + s.y * 0.5, z + 0.2)))
			cols.append(p.color.lerp(Color.WHITE, 0.25))
			x += s.x + 0.04
	_multimesh(store, xf, cols, 0.3)
	# glass doors with chrome frames
	for i in 7:
		var dx := -4.8 + i * 1.6
		box(store, Vector3(1.55, 2.2, 0.03), Vector3(dx, 1.2, z + 0.62), glass)
		box(store, Vector3(1.6, 0.06, 0.06), Vector3(dx, 0.1, z + 0.63), frame)
		box(store, Vector3(1.6, 0.06, 0.06), Vector3(dx, 2.3, z + 0.63), frame)
		box(store, Vector3(0.05, 2.25, 0.06), Vector3(dx - 0.78, 1.2, z + 0.63), frame)
		box(store, Vector3(0.03, 0.7, 0.05), Vector3(dx + 0.65, 1.3, z + 0.68), frame)
	box(store, Vector3(12.4, 0.5, 1.2), Vector3(0, 2.75, z), body)
	var fl := OmniLight3D.new()
	fl.light_color = Color(0.6, 0.85, 1.0)
	fl.light_energy = 1.4
	fl.omni_range = 6.5
	fl.position = Vector3(0, 1.3, z + 1.4)
	store.add_child(fl)
	# "FREEZER AISLE ->" sign (dark plate, light text)
	box(store, Vector3(6.2, 0.62, 0.06), Vector3(0, 3.12, z + 0.4), mat(Color(0.12, 0.13, 0.15), 0.0, 0.6))
	label(store, "FREEZER AISLE ->", Vector3(0, 3.12, z + 0.44), 96, Color(0.85, 0.88, 0.9), 0.0, 0.0045)

static func _multimesh(parent: Node, xf: Array, cols: Array, emission := 0.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mm.mesh = bm
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.7
	if emission > 0.0:
		m.emission_enabled = true
		m.emission_energy_multiplier = emission
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission = Color(1, 1, 1)
	mmi.material_override = m
	parent.add_child(mmi)
	return mmi

static func _checkouts(store: Node3D, out: Dictionary, target: Object) -> void:
	var beige := mat(Color(0.66, 0.62, 0.54), 0.0, 0.7)
	var beige_d := mat(Color(0.5, 0.47, 0.41), 0.0, 0.7)
	var steel := mat(Color(0.42, 0.43, 0.44), 0.0, 0.35, 0.6)
	var belt_m := mat(Color(0.06, 0.06, 0.065), 0.0, 0.85)
	var counter_m := mat(Color(0.4, 0.4, 0.4), 0.0, 0.6, 0.2)
	for i in LANE_X.size():
		var lx: float = LANE_X[i]
		var cx: float = COUNTER_X[i]
		var face := 1.0 if lx < cx else -1.0     # +1: customer on -X side, cashier on +X side
		var cash_x := cx + face * 0.85           # cashier side
		var root := Node3D.new()
		root.name = "Lane%d" % (i + 1)
		store.add_child(root)
		box(root, Vector3(1.0, 0.86, 5.0), Vector3(cx, 0.43, COUNTER_Z), counter_m, true)
		box(root, Vector3(1.06, 0.05, 5.06), Vector3(cx, 0.885, COUNTER_Z), steel)
		box(root, Vector3(1.06, 0.12, 0.08), Vector3(cx, 0.93, COUNTER_Z - 2.45), steel)
		box(root, Vector3(0.8, 0.03, 3.2), Vector3(cx, 0.92, COUNTER_Z - 0.7), belt_m)
		for sx in [-0.43, 0.43]:
			box(root, Vector3(0.06, 0.06, 3.3), Vector3(cx + sx, 0.94, COUNTER_Z - 0.7), steel)
		# belt slats for texture
		var bz := COUNTER_Z - 2.2
		while bz < COUNTER_Z + 1.0:
			box(root, Vector3(0.78, 0.005, 0.02), Vector3(cx, 0.937, bz), mat(Color(0.12, 0.12, 0.13)))
			bz += 0.12
		# scanner glass (built into the counter — the hand scanner is gone)
		box(root, Vector3(0.5, 0.02, 0.36), Vector3(cx, 0.92, COUNTER_Z + 0.85), mat(Color(0.3, 0.05, 0.05), 1.0))
		# Beige boxy register near the cashier end: base, keypad, CRT monitor facing cashier
		var rz := COUNTER_Z + 1.55
		box(root, Vector3(0.62, 0.22, 0.5), Vector3(cx, 1.02, rz), beige)            # cash drawer
		box(root, Vector3(0.5, 0.1, 0.42), Vector3(cx + face * 0.02, 1.17, rz), beige_d)
		var kp := box(root, Vector3(0.3, 0.05, 0.3), Vector3(cx + face * 0.12, 1.24, rz), mat(Color(0.2, 0.2, 0.22)))
		kp.rotation.z = face * 0.25
		box(root, Vector3(0.08, 0.28, 0.08), Vector3(cx - face * 0.12, 1.36, rz), beige_d)   # stand
		var mon := Node3D.new()
		mon.position = Vector3(cx - face * 0.12, 1.62, rz)
		mon.rotation.y = -face * PI * 0.25
		root.add_child(mon)
		box(mon, Vector3(0.36, 0.32, 0.4), Vector3.ZERO, beige)
		var scr := box(mon, Vector3(0.02, 0.24, 0.32), Vector3(face * 0.181, 0, 0), mat(Color(0.05, 0.2, 0.08), 1.4))
		var lab := label(mon, "", Vector3(face * 0.193, 0, 0), 32, Color(0.55, 1.0, 0.55), face * PI * 0.5, 0.0016)
		box(root, Vector3(0.06, 0.04, 0.04), Vector3(cx + face * 0.3, 1.1, rz + 0.18), mat(Color(0.1, 1.0, 0.3), 3.0))
		# bagging area + lane pole
		box(root, Vector3(0.9, 0.05, 0.6), Vector3(cx, 0.9, COUNTER_Z + 2.55), steel)
		var lnum := label(root, "LANE %d" % (i + 1), Vector3(cx, 0.7, COUNTER_Z + 2.2), 28, Color(0.7, 0.7, 0.65), 0.0, 0.0025)
		lnum.modulate.a = 0.8
		# interact collider around register (target = register script, set by game)
		var it := Interact.make(root, Vector3(0.7, 0.75, 0.6), Vector3(cx, 1.35, rz), null, {"kind": "register", "lane": i})
		out.lanes.append({"index": i, "lane_x": lx, "counter_x": cx, "cash_x": cash_x, "face": face, "root": root, "label": lab, "screen": scr, "terminal": it, "head_z": QUEUE_HEAD_Z, "queue_min_z": QUEUE_MIN_Z})

static func _crate(parent: Node, pos: Vector3, p: Dictionary, rot := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot
	parent.add_child(n)
	box(n, Vector3(0.6, 0.42, 0.45), Vector3(0, 0.21, 0), mat(Color(0.56, 0.42, 0.26), 0.0, 0.95))
	box(n, Vector3(0.61, 0.05, 0.1), Vector3(0, 0.42, 0), mat(Color(0.7, 0.6, 0.42), 0.0, 0.6))
	box(n, Vector3(0.4, 0.14, 0.01), Vector3(0, 0.24, 0.23), mat(p.color))
	label(n, String(p.name).to_upper(), Vector3(0, 0.24, 0.236), 24, Products.label_color(p), 0.0, 0.0018)
	return n

static func _down_spot(store: Node3D, pos: Vector3, energy: float, rng: float) -> void:
	var sl := SpotLight3D.new()
	sl.light_color = Color(1.0, 0.82, 0.55)
	sl.light_energy = energy
	sl.spot_range = rng
	sl.spot_angle = 38.0
	sl.position = pos
	sl.rotation.x = -PI * 0.5
	store.add_child(sl)
	box(store, Vector3(0.4, 0.08, 0.4), pos + Vector3(0, 0.1, 0), mat(Color(1.0, 0.85, 0.6), 2.5))

static func _stockroom(store: Node3D, out: Dictionary, target: Object) -> void:
	var wall := mat(Color(0.28, 0.28, 0.27), 0.0, 0.95)
	var ext := mat(Color(0.3, 0.22, 0.18), 0.0, 0.95)
	var hw := W * 0.5
	# Full-width stockroom. Only the middle is lit; the far corners stay dark.
	_wall_seg(store, Vector3(-hw - 0.1, 0, ZB), Vector3(-hw - 0.1, 0, ROOM_Z), wall)
	_wall_seg(store, Vector3(hw + 0.1, 0, ZB), Vector3(hw + 0.1, 0, ROOM_Z), wall)
	_wall_seg(store, Vector3(-hw, 0, ROOM_Z - 0.1), Vector3(BACK_DOOR_X - 0.7, 0, ROOM_Z - 0.1), wall)
	_wall_seg(store, Vector3(BACK_DOOR_X + 0.7, 0, ROOM_Z - 0.1), Vector3(hw, 0, ROOM_Z - 0.1), wall)
	_wall_seg(store, Vector3(BACK_DOOR_X - 0.7, 0, ROOM_Z - 0.1), Vector3(BACK_DOOR_X + 0.7, 0, ROOM_Z - 0.1), wall, H - 2.4, 2.4)
	box(store, Vector3(0.08, H, ZB - ROOM_Z), Vector3(-hw - 0.2, H * 0.5, (ZB + ROOM_Z) * 0.5), ext)
	box(store, Vector3(0.08, H, ZB - ROOM_Z), Vector3(hw + 0.2, H * 0.5, (ZB + ROOM_Z) * 0.5), ext)
	box(store, Vector3(W + 0.5, H, 0.08), Vector3(0, H * 0.5, ROOM_Z - 0.22), ext)
	# Two pools of light down the middle. Corners get none.
	_down_spot(store, Vector3(0, H - 0.35, -21.5), 4.0, 11.0)
	_down_spot(store, Vector3(1.5, H - 0.35, -27.0), 2.4, 9.0)
	for pil in [Vector3(-12, -23, 0), Vector3(12, -23, 0), Vector3(-12, -30, 0), Vector3(12, -30, 0)]:
		box(store, Vector3(0.45, H, 0.45), Vector3(pil.x, H * 0.5, pil.y), mat(Color(0.35, 0.34, 0.32)), true)
	# Pallet rack just inside the employee door: one crate per shelf product
	var steel := mat(Color(0.2, 0.35, 0.6), 0.0, 0.5, 0.4)
	var orange := mat(Color(0.85, 0.45, 0.1), 0.0, 0.5, 0.4)
	var items: Array = Products.SHELF_ITEMS
	var per_level := int(ceil(items.size() / 2.0))
	var rack_x0 := -6.0
	var rack_w := 12.0
	var rack_z := -19.2
	for lv in [0.0, 1.1]:
		box(store, Vector3(rack_w, 0.06, 0.8), Vector3(rack_x0 + rack_w * 0.5, lv + 0.12, rack_z), orange)
	for k in 5:
		box(store, Vector3(0.08, 2.2, 0.8), Vector3(rack_x0 + k * rack_w / 4.0, 1.1, rack_z), steel)
	for j in items.size():
		var lv := 0 if j < per_level else 1
		var col := j % per_level
		var p: Dictionary = Products.CATALOG[items[j]]
		var pos := Vector3(rack_x0 + 0.7 + col * (rack_w - 1.4) / maxf(1, per_level - 1), 0.15 + lv * 1.1, rack_z)
		_crate(store, pos, p)
		var it := Interact.make(store, Vector3(0.62, 0.45, 0.5), pos + Vector3(0, 0.21, 0), target, {"kind": "crate", "product": items[j]})
		out.crates.append(it)
	label(store, "STOCK - grab a box (E)", Vector3(0, 2.55, rack_z + 0.5), 48, Color(1, 0.9, 0.6))
	# Empty racks in the dark corners (somewhere for a monster to stand later)
	for corner in [Vector3(-16.5, 0, -31.5), Vector3(16.5, 0, -31.0)]:
		box(store, Vector3(3.2, 0.08, 0.9), corner + Vector3(0, 1.3, 0), orange)
		box(store, Vector3(3.2, 0.08, 0.9), corner + Vector3(0, 0.3, 0), orange)
		for ux in [-1.5, 1.5]:
			box(store, Vector3(0.08, 2.4, 0.9), corner + Vector3(ux, 1.2, 0), steel)
	# Back-office desk (the shop terminal gets wired to this collider)
	var desk := Vector3(-4.6, 0, ZB - 1.8)
	box(store, Vector3(1.5, 0.08, 0.7), desk + Vector3(0, 0.78, 0), mat(Color(0.35, 0.28, 0.2)))
	for leg in [Vector3(-0.65, 0, -0.25), Vector3(0.65, 0, -0.25), Vector3(-0.65, 0, 0.25), Vector3(0.65, 0, 0.25)]:
		box(store, Vector3(0.08, 0.78, 0.08), desk + leg + Vector3(0, 0.39, 0), mat(Color(0.2, 0.2, 0.2)))
	box(store, Vector3(0.42, 0.32, 0.06), desk + Vector3(0, 1.15, -0.2), mat(Color(0.08, 0.12, 0.1)))
	box(store, Vector3(0.36, 0.24, 0.02), desk + Vector3(0, 1.15, -0.16), mat(Color(0.25, 0.85, 0.45), 1.6))
	add_collider(store, Vector3(1.5, 0.8, 0.7), desk + Vector3(0, 0.4, 0))
	out.terminal = Interact.make(store, Vector3(0.5, 0.4, 0.3), desk + Vector3(0, 1.15, -0.15), target, {"kind": "terminal"})
	label(store, "BACK OFFICE", Vector3(desk.x, 1.7, desk.z + 0.4), 36, Color(0.7, 1, 0.75))
	# Swinging back door (hinge on -X side), toggled with E
	var hinge := Node3D.new()
	hinge.position = Vector3(BACK_DOOR_X - 0.6, 0, ROOM_Z - 0.1)
	store.add_child(hinge)
	var dm := mat(Color(0.45, 0.5, 0.52), 0.0, 0.5, 0.5)
	box(hinge, Vector3(1.2, 2.35, 0.06), Vector3(0.6, 1.175, 0), dm)
	box(hinge, Vector3(0.9, 0.08, 0.06), Vector3(0.6, 1.0, 0.05), mat(Color(0.75, 0.75, 0.75), 0.0, 0.3, 0.8))  # push bar
	box(hinge, Vector3(0.6, 0.2, 0.01), Vector3(0.6, 1.8, 0.035), mat(Color(0.8, 0.1, 0.1)))
	var door_it := Interact.make(hinge, Vector3(1.2, 2.35, 0.12), Vector3(0.6, 1.175, 0), target, {"kind": "back_door"})
	out.back_door = {"hinge": hinge, "body": door_it}
	box(store, Vector3(0.3, 0.3, 0.1), Vector3(BACK_DOOR_X, 2.65, ROOM_Z - 0.2), mat(Color(0.2, 1.0, 0.4), 2.0))  # exit light
	label(store, "EXIT", Vector3(BACK_DOOR_X, 2.65, ROOM_Z + 0.02), 40, Color(0.7, 1, 0.7))
	# Wall-pack lamps outside (back door + front corners)
	for wp in [Vector3(BACK_DOOR_X, 2.9, ROOM_Z - 0.35), Vector3(-W * 0.5 + 0.5, 3.0, D * 0.5 + 0.4), Vector3(W * 0.5 - 0.5, 3.0, D * 0.5 + 0.4)]:
		box(store, Vector3(0.35, 0.22, 0.25), wp, mat(Color(1.0, 0.75, 0.45), 3.0))
		var wl := OmniLight3D.new()
		wl.light_color = Color(1.0, 0.72, 0.42)
		wl.light_energy = 2.2
		wl.omni_range = 9.0
		wl.position = wp + Vector3(0, -0.3, -0.5 if wp.z < 0 else 0.5)
		store.add_child(wl)
	# Gun locker on the stockroom's west wall (placeholder for the monster update)
	var lk := Node3D.new()
	lk.position = Vector3(-hw + 0.45, 0, -30.5)
	store.add_child(lk)
	var green := mat(Color(0.18, 0.26, 0.2), 0.0, 0.5, 0.5)
	box(lk, Vector3(0.45, 1.7, 0.9), Vector3(0, 1.05, 0), green)
	box(lk, Vector3(0.02, 1.5, 0.75), Vector3(0.235, 1.05, 0), mat(Color(0.05, 0.05, 0.06)))   # dark inside
	var wood := mat(Color(0.42, 0.24, 0.1), 0.0, 0.6)
	var gunmetal := mat(Color(0.12, 0.12, 0.13), 0.0, 0.3, 0.8)
	box(lk, Vector3(0.06, 0.38, 0.1), Vector3(0.2, 0.55, 0), wood)          # stock
	box(lk, Vector3(0.06, 0.2, 0.07), Vector3(0.2, 0.83, 0), gunmetal)      # receiver
	box(lk, Vector3(0.04, 0.72, 0.04), Vector3(0.2, 1.28, -0.012), gunmetal) # barrel
	box(lk, Vector3(0.035, 0.6, 0.035), Vector3(0.2, 1.2, 0.03), gunmetal)  # mag tube
	box(lk, Vector3(0.07, 0.18, 0.08), Vector3(0.2, 1.12, 0.02), wood)      # pump
	box(lk, Vector3(0.02, 1.5, 0.75), Vector3(0.26, 1.05, 0), mat(Color(0.7, 0.85, 0.9, 0.18), 0.0, 0.05))  # glass
	box(lk, Vector3(0.05, 0.08, 0.06), Vector3(0.28, 1.05, 0.33), mat(Color(0.85, 0.7, 0.2), 0.0, 0.3, 0.8))  # padlock
	box(lk, Vector3(0.02, 0.18, 0.7), Vector3(0.24, 2.05, 0), mat(Color(0.7, 0.08, 0.06), 0.8))
	label(lk, "EMERGENCY ONLY", Vector3(0.255, 2.05, 0), 36, Color(1, 0.95, 0.9), PI * 0.5, 0.003)
	out.locker = Interact.make(lk, Vector3(0.5, 1.8, 0.95), Vector3(0.05, 1.05, 0), target, {"kind": "locker"})
	# Cardboard clutter in the stockroom
	for c in [Vector3(17.5, 0, -18.5), Vector3(17.6, 0.42, -18.2), Vector3(-17.4, 0, -18.4), Vector3(17.2, 0, -32.4)]:
		_clutter_box(store, c, Vector3(0.7, 0.42, 0.55))

static func _clutter_box(parent: Node, pos: Vector3, s: Vector3, rot := 0.0) -> void:
	var b := box(parent, s, pos + Vector3(0, s.y * 0.5, 0), mat(Color(0.55, 0.41, 0.26), 0.0, 0.95))
	b.rotation.y = rot
	var t := box(b, Vector3(s.x + 0.005, 0.01, 0.08), Vector3(0, s.y * 0.5, 0), mat(Color(0.68, 0.58, 0.4), 0.0, 0.5))
	t.rotation.y = 0.0
	add_collider(parent, s, pos + Vector3(0, s.y * 0.5, 0)).rotation.y = rot

static func _outside(store: Node3D, out: Dictionary, target: Object) -> void:
	var f: Rect2 = FENCE
	var asphalt := tiled_floor(4.0, Color(0.17, 0.17, 0.175), Color(0.16, 0.16, 0.165), Color(0.12, 0.12, 0.12))
	var cx := f.position.x + f.size.x * 0.5
	var cz := f.position.y + f.size.y * 0.5
	# ground in strips around the building (avoids z-fighting with store floor)
	box(store, Vector3(f.size.x, 0.1, f.end.y - D * 0.5), Vector3(cx, -0.07, (D * 0.5 + f.end.y) * 0.5), asphalt)
	box(store, Vector3(f.size.x, 0.1, ZB - f.position.y), Vector3(cx, -0.07, (f.position.y + ZB) * 0.5), asphalt)
	box(store, Vector3(f.size.x, 0.1, D * 0.5 - ZB), Vector3(cx, -0.08, (D * 0.5 + ZB) * 0.5), asphalt)
	add_collider(store, Vector3(f.size.x + 4, 0.2, f.size.y + 4), Vector3(cx, -0.1, cz))
	# sidewalk
	box(store, Vector3(W + 2, 0.12, 2.5), Vector3(0, -0.02, D * 0.5 + 1.35), mat(Color(0.32, 0.31, 0.3), 0.0, 0.9))
	# Two parking rows in front of the store. Cars face the entrance (yaw PI, nose toward -Z).
	var line := mat(Color(0.7, 0.68, 0.55), 0.0, 0.8)
	out.parking = []
	var spot_x := [-18.0, -13.0, -8.0, 8.0, 13.0, 18.0]
	for row_z in [32.0, 39.5]:
		var xs: Array = spot_x if row_z < 36.0 else [-18.0, -8.0, 10.0, 18.0]
		for x in xs:
			box(store, Vector3(0.1, 0.01, 4.6), Vector3(x, -0.015, row_z), line)
			out.parking.append({"pos": Vector3(x, 0, row_z), "yaw": PI})
	_fuel_station(store, out)
	_corral(store, out)
	# street lamps — none in the fuel bay, so that corner stays dark except the pumps
	for lp in [Vector3(-16, 0, 30), Vector3(6, 0, 36), Vector3(-20, 0, -40), Vector3(6, 0, -42), Vector3(-30, 0, 10)]:
		box(store, Vector3(0.18, 6.0, 0.18), lp + Vector3(0, 3, 0), mat(Color(0.18, 0.18, 0.18)))
		box(store, Vector3(1.0, 0.18, 0.45), lp + Vector3(0, 6.0, 0), mat(Color(1.0, 0.65, 0.3), 4.0))
		add_collider(store, Vector3(0.2, 6, 0.2), lp + Vector3(0, 3, 0))
		var sl := OmniLight3D.new()
		sl.light_color = Color(1.0, 0.6, 0.28)
		sl.omni_range = 13.0
		sl.light_energy = 4.0
		sl.omni_attenuation = 1.3
		sl.position = lp + Vector3(0, 5.6, 0)
		store.add_child(sl)
	# chain-link fence around the lot
	var post_m := mat(Color(0.35, 0.36, 0.37), 0.0, 0.4, 0.7)
	var mesh_m := mat(Color(0.5, 0.52, 0.55, 0.28), 0.0, 0.5, 0.3)
	var fh := 2.2
	# Front fence (+Z) has a driveway gap at x -5..5.
	var front_y: float = f.end.y
	for side in [[Vector2(f.position.x, f.position.y), Vector2(f.end.x, f.position.y)], [Vector2(f.position.x, front_y), Vector2(-5, front_y)], [Vector2(5, front_y), Vector2(f.end.x, front_y)], [Vector2(f.position.x, f.position.y), Vector2(f.position.x, f.end.y)], [Vector2(f.end.x, f.position.y), Vector2(f.end.x, f.end.y)]]:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var along_x := absf(b.x - a.x) > 0.1
		var length := a.distance_to(b)
		var c := (a + b) * 0.5
		var size := Vector3(length, fh, 0.03) if along_x else Vector3(0.03, fh, length)
		box(store, size, Vector3(c.x, fh * 0.5, c.y), mesh_m)
		box(store, Vector3(length if along_x else 0.05, 0.05, 0.05 if along_x else length), Vector3(c.x, fh, c.y), post_m)
		add_collider(store, Vector3(maxf(size.x, 0.3), 3.0, maxf(size.z, 0.3)), Vector3(c.x, 1.5, c.y))
		var t := 0.0
		while t <= length + 0.01:
			var p := a.lerp(b, t / length)
			box(store, Vector3(0.07, fh + 0.1, 0.07), Vector3(p.x, (fh + 0.1) * 0.5, p.y), post_m)
			t += 3.0
	# Dumpster in the back lot
	var dpos := Vector3(BACK_DOOR_X - 3.0, 0, ROOM_Z - 4.5)
	var dg := mat(Color(0.12, 0.3, 0.18), 0.0, 0.7, 0.3)
	var dn := Node3D.new()
	dn.position = dpos
	store.add_child(dn)
	box(dn, Vector3(2.4, 1.3, 1.4), Vector3(0, 0.75, 0), dg)
	var lid := box(dn, Vector3(2.45, 0.08, 1.5), Vector3(0, 1.45, 0.05), mat(Color(0.1, 0.1, 0.1), 0.0, 0.6))
	lid.rotation.x = -0.25
	for wx in [-1.0, 1.0]:
		for wz in [-0.55, 0.55]:
			cyl(dn, 0.08, 0.06, Vector3(wx, 0.08, wz), mat(Color(0.05, 0.05, 0.05))).rotation.z = PI * 0.5
	label(dn, "TRASH", Vector3(0, 0.9, 0.71), 64, Color(0.95, 0.95, 0.85), 0.0, 0.004)
	out.dumpster = Interact.make(dn, Vector3(2.5, 1.6, 1.5), Vector3(0, 0.8, 0), target, {"kind": "dumpster"})
	for bag in [Vector3(1.6, 0, 0.5), Vector3(1.9, 0, -0.2)]:
		var bm := box(dn, Vector3(0.45, 0.5, 0.4), bag + Vector3(0, 0.25, 0), mat(Color(0.05, 0.05, 0.06), 0.0, 0.3))
		bm.rotation.y = 0.5

static func _fuel_station(store: Node3D, out: Dictionary) -> void:
	# Dark corner of the lot. The only real light is on the pumps.
	var pad := mat(Color(0.1, 0.1, 0.11), 0.0, 0.9)
	box(store, Vector3(14, 0.04, 16), FUEL_POS + Vector3(0, 0.02, 0), pad)
	var canopy := mat(Color(0.15, 0.16, 0.18), 0.0, 0.6)
	box(store, Vector3(10, 0.18, 7), FUEL_POS + Vector3(0, 3.3, 0), canopy)
	for col in [Vector3(-4.2, 0, -2.8), Vector3(4.2, 0, -2.8), Vector3(-4.2, 0, 2.8), Vector3(4.2, 0, 2.8)]:
		box(store, Vector3(0.28, 3.3, 0.28), FUEL_POS + col + Vector3(0, 1.65, 0), mat(Color(0.2, 0.2, 0.22)), true)
	out.pumps = []
	for i in 2:
		var p := FUEL_POS + Vector3(-1.6 + i * 3.2, 0, 0)
		var pump := Node3D.new()
		pump.position = p
		store.add_child(pump)
		box(pump, Vector3(0.55, 1.5, 0.35), Vector3(0, 0.75, 0), mat(Color(0.75, 0.12, 0.1)), true)
		box(pump, Vector3(0.35, 0.2, 0.05), Vector3(0, 1.15, 0.18), mat(Color(0.05, 0.05, 0.05)))
		box(pump, Vector3(0.28, 0.12, 0.02), Vector3(0, 1.15, 0.21), mat(Color(0.2, 1.0, 0.45), 2.2))
		box(pump, Vector3(0.7, 0.06, 0.7), Vector3(0, 3.05, 0), mat(Color(1.0, 0.85, 0.45), 3.5))
		var pl := OmniLight3D.new()
		pl.light_color = Color(1.0, 0.8, 0.4)
		pl.light_energy = 2.4
		pl.omni_range = 6.5
		pl.position = Vector3(0, 2.7, 0)
		pump.add_child(pl)
		label(pump, "FUEL", Vector3(0, 1.7, 0.2), 42, Color(1, 0.95, 0.8))
		out.pumps.append({"pos": p, "yaw": PI * 0.5, "index": i})
	label(store, "NIGHT FUEL", FUEL_POS + Vector3(0, 3.7, 3.6), 64, Color(1.0, 0.85, 0.3))

static func _corral(store: Node3D, out: Dictionary) -> void:
	var rail := mat(Color(0.62, 0.64, 0.66), 0.0, 0.35, 0.6)
	var origin := CORRAL_POS
	# A 4.2 x 7 m pen, open on the store side (+Z is open? store is -Z from here).
	# Open toward the store (-Z) so carts roll in from the lot.
	for end_x in [-2.1, 2.1]:
		box(store, Vector3(0.08, 1.0, 7.0), origin + Vector3(end_x, 0.5, 0), rail)
	box(store, Vector3(4.2, 1.0, 0.08), origin + Vector3(0, 0.5, -3.5), rail)
	for post in [Vector3(-2.1, 0, -3.5), Vector3(2.1, 0, -3.5), Vector3(-2.1, 0, 3.5), Vector3(2.1, 0, 3.5)]:
		box(store, Vector3(0.1, 1.15, 0.1), origin + post + Vector3(0, 0.55, 0), rail)
	label(store, "CARTS", origin + Vector3(0, 1.35, -3.5), 48, Color(0.9, 0.95, 1))
	var slots: Array = []
	for i in 8:
		var col := i % 2
		var row := int(i / 2)
		slots.append(origin + Vector3(-0.7 + col * 1.4, 0, -2.2 + row * 1.5))
	out.corral = {"pos": origin, "slots": slots, "half": Vector3(2.3, 1.0, 3.7)}

static func _car(parent: Node, pos: Vector3, c: Color, yaw := 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	var paint := mat(c, 0.0, 0.35, 0.5)
	box(n, Vector3(1.8, 0.7, 4.2), Vector3(0, 0.6, 0), paint)
	box(n, Vector3(1.6, 0.6, 2.2), Vector3(0, 1.25, -0.2), paint)
	box(n, Vector3(1.62, 0.45, 2.0), Vector3(0, 1.25, -0.2), mat(Color(0.05, 0.07, 0.1, 0.9), 0.0, 0.1))
	for wx in [-0.85, 0.85]:
		for wz in [-1.3, 1.4]:
			cyl(n, 0.33, 0.25, Vector3(wx, 0.33, wz), mat(Color(0.04, 0.04, 0.04))).rotation.z = PI * 0.5
	for lx in [-0.6, 0.6]:
		box(n, Vector3(0.3, 0.12, 0.03), Vector3(lx, 0.72, 2.11), mat(Color(1, 0.95, 0.8), 0.6))
	add_collider(n, Vector3(1.8, 1.6, 4.2), Vector3(0, 0.8, 0))

static func _props(store: Node3D, out: Dictionary, target: Object) -> void:
	# Trash can behind the checkout lanes (fills up over time)
	var cpos := Vector3(8.6, 0, 19.2)
	var can := Node3D.new()
	can.position = cpos
	store.add_child(can)
	cyl(can, 0.3, 0.85, Vector3(0, 0.425, 0), mat(Color(0.22, 0.24, 0.25), 0.0, 0.5, 0.5))
	var bag := cyl(can, 0.27, 0.3, Vector3(0, 0.85, 0), mat(Color(0.04, 0.04, 0.05), 0.0, 0.3))
	box(can, Vector3(0.3, 0.003, 0.15), Vector3(0, 0.6, 0.3), mat(Color(0.2, 0.4, 0.8)))
	out.can = {"node": can, "bag": bag, "body": Interact.make(can, Vector3(0.65, 1.0, 0.65), Vector3(0, 0.5, 0), target, {"kind": "can"})}
	# Cardboard clutter in the store (out of customer paths)
	_clutter_box(store, Vector3(-19.2, 0, 21.2), Vector3(0.8, 0.5, 0.6), 0.2)
	_clutter_box(store, Vector3(-19.0, 0.5, 20.9), Vector3(0.6, 0.4, 0.5), -0.3)
	_clutter_box(store, Vector3(19.1, 0, 21.0), Vector3(0.55, 0.38, 0.5), 0.6)
	_clutter_box(store, Vector3(19.0, 0, ZB + 1.2), Vector3(0.8, 0.5, 0.6), 0.1)
	_clutter_box(store, Vector3(-19.1, 0, ZB + 1.3), Vector3(0.6, 0.6, 0.6), -0.2)
	# Wet floor sign
	var ws := Node3D.new()
	ws.position = Vector3(18.4, 0, 20.2)
	ws.rotation.y = 0.6
	store.add_child(ws)
	for s in [-1, 1]:
		var pnl := box(ws, Vector3(0.35, 0.65, 0.02), Vector3(0, 0.32, s * 0.08), mat(Color(0.95, 0.8, 0.1)))
		pnl.rotation.x = s * 0.22
