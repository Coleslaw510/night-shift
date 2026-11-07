class_name StoreBuilder
## Builds the store, stockroom and outside lot from primitive meshes.
## Layout (meters, +Z = front/entrance) is documented in HANDOFF.md.
## Returns refs: lights, lanes, front_door, back_door, can, dumpster, locker, crates.

const W := 24.0
const D := 30.0
const H := 3.6
const SHELF_X := [-9.5, -6.5, -3.0, 3.0, 6.5, 9.5]
const SHELF_Z0 := -9.0
const SHELF_Z1 := 0.5
const LANE_X := [-3.0, 3.0]          # customer side of each checkout lane
const COUNTER_X := [-2.0, 2.0]       # counters; cashier stands between them (x ~ 0)
const DOOR_X := 7.0                  # front automatic door
const STOCK_DOOR_X := 7.0            # doorway from store into stockroom (back wall)
const BACK_DOOR_X := 9.7             # stockroom back door to the back lot
const ROOM_Z := -22.0                # stockroom back wall
const FENCE := Rect2(-26, -33, 52, 64)

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
	env.ambient_light_energy = 0.22
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
	var fm := tiled_floor(0.6, Color(0.24, 0.235, 0.225), Color(0.2, 0.195, 0.19), Color(0.1, 0.1, 0.1))
	# Floor split in 4x5 m tiles so each mesh gets few lights (Compatibility renderer limit).
	var x := -hw
	while x < hw - 0.01:
		var z := -hd
		while z < hd - 0.01:
			box(store, Vector3(4, 0.1, 5), Vector3(x + 2, -0.05, z + 2.5), fm)
			z += 5
		x += 4
	# Stockroom floor (concrete)
	var cm := tiled_floor(1.5, Color(0.3, 0.3, 0.29), Color(0.28, 0.28, 0.27), Color(0.18, 0.18, 0.18))
	box(store, Vector3(10, 0.1, 7), Vector3(7, -0.05, -18.5), cm)
	# Ceiling: dark panels + grid
	var ceil_m := mat(Color(0.13, 0.13, 0.13), 0.0, 0.95)
	var grid_m := mat(Color(0.06, 0.06, 0.06))
	box(store, Vector3(W, 0.12, D), Vector3(0, H + 0.06, 0), ceil_m)
	box(store, Vector3(10, 0.12, 7), Vector3(7, H + 0.06, -18.5), ceil_m)
	var gx := -hw + 1.2
	while gx < hw:
		box(store, Vector3(0.04, 0.03, D), Vector3(gx, H - 0.01, 0), grid_m)
		gx += 1.2
	var gz := -hd + 1.2
	while gz < hd:
		box(store, Vector3(W, 0.03, 0.04), Vector3(0, H - 0.01, gz), grid_m)
		gz += 1.2
	# Roof (seen from outside)
	box(store, Vector3(W + 0.6, 0.3, D + 0.6), Vector3(0, H + 0.27, 0), mat(Color(0.12, 0.11, 0.1)))
	box(store, Vector3(10.6, 0.3, 7.6), Vector3(7, H + 0.27, -18.5), mat(Color(0.12, 0.11, 0.1)))

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
	_wall_seg(store, Vector3(hw + 0.1, 0, -hd), Vector3(hw + 0.1, 0, hd), wall)
	# Left wall: windows like the concept (kick wall + glass band + header)
	_wall_seg(store, Vector3(-hw - 0.1, 0, -hd), Vector3(-hw - 0.1, 0, hd), wall, 0.9)
	_wall_seg(store, Vector3(-hw - 0.1, 0, -hd), Vector3(-hw - 0.1, 0, hd), wall, H - 2.8, 2.8)
	_wall_seg(store, Vector3(-hw - 0.1, 0, -hd + 1), Vector3(-hw - 0.1, 0, hd - 1), glass, 1.9, 0.9, 0.04, false)
	add_collider(store, Vector3(0.3, H, D), Vector3(-hw - 0.1, H * 0.5, 0))
	var z := -hd
	while z <= hd + 0.01:
		box(store, Vector3(0.24, 1.9, 0.14), Vector3(-hw - 0.1, 1.85, z), frame)
		z += 3.0
	# Back wall with stockroom doorway (gap STOCK_DOOR_X +- 1.0)
	_wall_seg(store, Vector3(-hw, 0, -hd - 0.1), Vector3(STOCK_DOOR_X - 1.0, 0, -hd - 0.1), wall)
	_wall_seg(store, Vector3(STOCK_DOOR_X + 1.0, 0, -hd - 0.1), Vector3(hw, 0, -hd - 0.1), wall)
	_wall_seg(store, Vector3(STOCK_DOOR_X - 1.0, 0, -hd - 0.1), Vector3(STOCK_DOOR_X + 1.0, 0, -hd - 0.1), wall, H - 2.6, 2.6)
	box(store, Vector3(1.6, 0.25, 0.05), Vector3(STOCK_DOOR_X, 2.9, -hd + 0.02), mat(Color(0.75, 0.1, 0.08), 1.2))
	label(store, "EMPLOYEES ONLY", Vector3(STOCK_DOOR_X, 2.9, -hd + 0.05), 40, Color(1, 0.95, 0.9))
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
		box(store, Vector3(0.04, 0.12, D), Vector3(s * (hw - 0.01), 0.06, 0), trim)
	box(store, Vector3(W, 0.12, 0.04), Vector3(0, 0.06, -hd + 0.01), trim)
	# Exterior skin on the solid walls + the store sign
	box(store, Vector3(0.05, H, D + 0.4), Vector3(hw + 0.23, H * 0.5, 0), ext)
	box(store, Vector3(W + 0.4, H, 0.05), Vector3(0, H * 0.5, -hd - 0.23), ext)
	box(store, Vector3(9, 0.9, 0.2), Vector3(-2, H + 0.75, hd + 0.05), mat(Color(0.1, 0.1, 0.1)))
	label(store, "NIGHT SHIFT MART", Vector3(-2, H + 0.75, hd + 0.17), 120, Color(1.0, 0.25, 0.2), 0.0, 0.007)
	label(store, "OPEN 24 HOURS", Vector3(-8.5, 2.6, hd + 0.05), 48, Color(0.3, 1.0, 0.5), 0.0, 0.006)

static func _lights(store: Node3D, out: Dictionary) -> void:
	var housing := mat(Color(0.2, 0.2, 0.2), 0.0, 0.5, 0.3)
	var tube := mat(Color(1.0, 0.96, 0.86), 5.0)
	for fx in [-6.0, 0.0, 6.0]:
		for fz in [-11.0, -4.0, 3.0, 10.0]:
			var f := Node3D.new()
			f.position = Vector3(fx, H - 0.08, fz)
			store.add_child(f)
			box(f, Vector3(0.62, 0.1, 2.5), Vector3.ZERO, housing)
			for tx in [-0.15, 0.15]:
				box(f, Vector3(0.12, 0.04, 2.36), Vector3(tx, -0.06, 0), tube)
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.9, 0.74)
			l.light_energy = 0.75
			l.omni_range = 9.0
			l.omni_attenuation = 1.4
			l.position = Vector3(fx, H - 0.45, fz)
			store.add_child(l)
			l.set_meta("fixture", f)
			l.set_meta("base", l.light_energy)
			out.lights.append(l)

static func _freezer(store: Node3D) -> void:
	var z := -D * 0.5 + 0.6
	var body := mat(Color(0.22, 0.22, 0.24), 0.0, 0.5, 0.4)
	var glow := mat(Color(0.75, 0.9, 1.0), 1.6)
	var glass := mat(Color(0.7, 0.88, 1.0, 0.2), 0.3, 0.05)
	var frame := mat(Color(0.75, 0.78, 0.8), 0.0, 0.3, 0.7)
	box(store, Vector3(8.4, 2.5, 1.2), Vector3(0, 1.25, z), body)
	add_collider(store, Vector3(8.4, 2.5, 1.3), Vector3(0, 1.25, z))
	box(store, Vector3(8.0, 2.0, 0.04), Vector3(0, 1.2, z - 0.1), glow)   # glowing back
	# shelves + frozen goods inside
	var xf: Array = []
	var cols: Array = []
	for lv in [0.35, 0.8, 1.25, 1.7]:
		box(store, Vector3(8.0, 0.02, 0.5), Vector3(0, lv, z + 0.2), mat(Color(0.85, 0.9, 0.95), 0.4))
		var x := -3.85
		while x < 3.85:
			var p: Dictionary = Products.CATALOG[Products.FROZEN_ITEMS[randi() % Products.FROZEN_ITEMS.size()]]
			var s: Vector3 = p.size
			xf.append(Transform3D(Basis.from_scale(Vector3(s.x, s.y, 0.3)), Vector3(x + s.x * 0.5, lv + 0.01 + s.y * 0.5, z + 0.2)))
			cols.append(p.color.lerp(Color.WHITE, 0.25))
			x += s.x + 0.04
	_multimesh(store, xf, cols, 0.3)
	# glass doors with chrome frames
	for i in 5:
		var dx := -3.2 + i * 1.6
		box(store, Vector3(1.55, 2.2, 0.03), Vector3(dx, 1.2, z + 0.62), glass)
		box(store, Vector3(1.6, 0.06, 0.06), Vector3(dx, 0.1, z + 0.63), frame)
		box(store, Vector3(1.6, 0.06, 0.06), Vector3(dx, 2.3, z + 0.63), frame)
		box(store, Vector3(0.05, 2.25, 0.06), Vector3(dx - 0.78, 1.2, z + 0.63), frame)
		box(store, Vector3(0.03, 0.7, 0.05), Vector3(dx + 0.65, 1.3, z + 0.68), frame)
	box(store, Vector3(8.4, 0.5, 1.2), Vector3(0, 2.75, z), body)
	var fl := OmniLight3D.new()
	fl.light_color = Color(0.6, 0.85, 1.0)
	fl.light_energy = 1.4
	fl.omni_range = 6.5
	fl.position = Vector3(0, 1.3, z + 1.4)
	store.add_child(fl)
	# "FREEZER AISLE ->" sign (dark plate, light text)
	box(store, Vector3(3.4, 0.5, 0.06), Vector3(0, 3.15, z + 0.4), mat(Color(0.12, 0.13, 0.15), 0.0, 0.6))
	label(store, "FREEZER AISLE ->", Vector3(0, 3.15, z + 0.44), 64, Color(0.85, 0.88, 0.9), 0.0, 0.0045)

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
	var counter_m := mat(Color(0.3, 0.3, 0.31), 0.0, 0.6, 0.2)
	for i in LANE_X.size():
		var lx: float = LANE_X[i]
		var cx: float = COUNTER_X[i]
		var face := 1.0 if lx < cx else -1.0     # +1: customer on -X side, cashier on +X side
		var cash_x := cx + face * 0.85           # cashier side
		var root := Node3D.new()
		root.name = "Lane%d" % (i + 1)
		store.add_child(root)
		box(root, Vector3(1.0, 0.86, 4.2), Vector3(cx, 0.43, 7.0), counter_m, true)
		box(root, Vector3(1.06, 0.05, 4.26), Vector3(cx, 0.885, 7.0), steel)
		box(root, Vector3(1.06, 0.12, 0.08), Vector3(cx, 0.93, 4.92), steel)
		box(root, Vector3(0.8, 0.03, 2.8), Vector3(cx, 0.92, 6.15), belt_m)
		for sx in [-0.43, 0.43]:
			box(root, Vector3(0.06, 0.06, 2.9), Vector3(cx + sx, 0.94, 6.15), steel)
		# belt slats for texture
		var bz := 4.85
		while bz < 7.5:
			box(root, Vector3(0.78, 0.005, 0.02), Vector3(cx, 0.937, bz), mat(Color(0.12, 0.12, 0.13)))
			bz += 0.12
		# scanner glass
		box(root, Vector3(0.5, 0.02, 0.36), Vector3(cx, 0.92, 7.9), mat(Color(0.3, 0.05, 0.05), 1.0))
		# Beige boxy register near the cashier end: base, keypad, CRT monitor facing cashier
		var rz := 8.5
		box(root, Vector3(0.62, 0.22, 0.5), Vector3(cx, 1.02, rz), beige)            # cash drawer
		box(root, Vector3(0.5, 0.1, 0.42), Vector3(cx + face * 0.02, 1.17, rz), beige_d)
		var kp := box(root, Vector3(0.3, 0.05, 0.3), Vector3(cx + face * 0.12, 1.24, rz), mat(Color(0.2, 0.2, 0.22)))
		kp.rotation.z = face * 0.25
		box(root, Vector3(0.08, 0.28, 0.08), Vector3(cx - face * 0.12, 1.36, rz), beige_d)   # stand
		var mon := Node3D.new()
		mon.position = Vector3(cx - face * 0.12, 1.62, rz)
		root.add_child(mon)
		box(mon, Vector3(0.36, 0.32, 0.4), Vector3.ZERO, beige)
		var scr := box(mon, Vector3(0.02, 0.24, 0.32), Vector3(face * 0.181, 0, 0), mat(Color(0.05, 0.2, 0.08), 1.4))
		var lab := label(mon, "", Vector3(face * 0.193, 0, 0), 32, Color(0.55, 1.0, 0.55), face * PI * 0.5, 0.0016)
		box(root, Vector3(0.06, 0.04, 0.04), Vector3(cx + face * 0.3, 1.1, rz + 0.18), mat(Color(0.1, 1.0, 0.3), 3.0))
		# bagging area + lane pole
		box(root, Vector3(0.9, 0.05, 0.6), Vector3(cx, 0.9, 9.45), steel)
		box(root, Vector3(0.05, 1.5, 0.05), Vector3(cx + face * 0.4, 1.6, 9.0), mat(Color(0.15, 0.15, 0.15)))
		box(root, Vector3(0.14, 0.2, 0.14), Vector3(cx + face * 0.4, 2.4, 9.0), mat(Color(0.2, 0.9, 0.4), 2.0))
		label(root, str(i + 1), Vector3(cx + face * 0.4, 2.7, 9.0), 64, Color(0.9, 1, 0.9), 0.0, 0.004).billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		# interact collider around register (target = register script, set by game)
		var it := Interact.make(root, Vector3(0.7, 0.75, 0.6), Vector3(cx, 1.35, rz), null, {"kind": "register", "lane": i})
		out.lanes.append({"index": i, "lane_x": lx, "counter_x": cx, "cash_x": cash_x, "face": face, "root": root, "label": lab, "screen": scr, "terminal": it})

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

static func _stockroom(store: Node3D, out: Dictionary, target: Object) -> void:
	var wall := mat(Color(0.33, 0.33, 0.31), 0.0, 0.95)
	var x0 := 2.0
	var x1 := W * 0.5
	var hd := D * 0.5
	_wall_seg(store, Vector3(x0, 0, -hd), Vector3(x0, 0, ROOM_Z), wall)
	_wall_seg(store, Vector3(x1 + 0.1, 0, -hd), Vector3(x1 + 0.1, 0, ROOM_Z), wall)
	_wall_seg(store, Vector3(x0, 0, ROOM_Z - 0.1), Vector3(BACK_DOOR_X - 0.65, 0, ROOM_Z - 0.1), wall)
	_wall_seg(store, Vector3(BACK_DOOR_X + 0.65, 0, ROOM_Z - 0.1), Vector3(x1, 0, ROOM_Z - 0.1), wall)
	_wall_seg(store, Vector3(BACK_DOOR_X - 0.65, 0, ROOM_Z - 0.1), Vector3(BACK_DOOR_X + 0.65, 0, ROOM_Z - 0.1), wall, H - 2.4, 2.4)
	# bare bulb light
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.82, 0.55)
	l.light_energy = 1.0
	l.omni_range = 8.0
	l.position = Vector3(7, H - 0.6, -18.5)
	store.add_child(l)
	box(store, Vector3(0.15, 0.15, 0.15), Vector3(7, H - 0.4, -18.5), mat(Color(1.0, 0.85, 0.6), 4.0))
	# Pallet rack along the back wall: one stock crate per shelf product (2 levels)
	var steel := mat(Color(0.2, 0.35, 0.6), 0.0, 0.5, 0.4)
	var orange := mat(Color(0.85, 0.45, 0.1), 0.0, 0.5, 0.4)
	var items: Array = Products.SHELF_ITEMS
	var per_level := int(ceil(items.size() / 2.0))
	var rack_x0 := 2.6
	var rack_w := 6.0
	for lv in [0.0, 1.1]:
		box(store, Vector3(rack_w, 0.06, 0.8), Vector3(rack_x0 + rack_w * 0.5, lv + 0.12, ROOM_Z + 0.55), orange)
	for k in 4:
		box(store, Vector3(0.08, 2.2, 0.8), Vector3(rack_x0 + k * rack_w / 3.0, 1.1, ROOM_Z + 0.55), steel)
	for j in items.size():
		var lv := 0 if j < per_level else 1
		var col := j % per_level
		var p: Dictionary = Products.CATALOG[items[j]]
		var pos := Vector3(rack_x0 + 0.45 + col * (rack_w - 0.9) / maxf(1, per_level - 1), 0.15 + lv * 1.1, ROOM_Z + 0.5)
		_crate(store, pos, p)
		var it := Interact.make(store, Vector3(0.62, 0.45, 0.5), pos + Vector3(0, 0.21, 0), target, {"kind": "crate", "product": items[j]})
		out.crates.append(it)
	label(store, "STOCK - grab a box (E)", Vector3(rack_x0 + rack_w * 0.5, 2.5, ROOM_Z + 0.06), 40, Color(1, 0.9, 0.6))
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
	# Gun locker on the stockroom's west wall (placeholder for the monster update)
	var lk := Node3D.new()
	lk.position = Vector3(x0 + 0.3, 0, -17.5)
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
	for c in [Vector3(11.3, 0, -16.0), Vector3(11.3, 0.42, -16.1), Vector3(10.6, 0, -16.2), Vector3(11.2, 0, -20.8)]:
		_clutter_box(store, c, Vector3(0.7, 0.42, 0.55))

static func _clutter_box(parent: Node, pos: Vector3, s: Vector3, rot := 0.0) -> void:
	var b := box(parent, s, pos + Vector3(0, s.y * 0.5, 0), mat(Color(0.55, 0.41, 0.26), 0.0, 0.95))
	b.rotation.y = rot
	var t := box(b, Vector3(s.x + 0.005, 0.01, 0.08), Vector3(0, s.y * 0.5, 0), mat(Color(0.68, 0.58, 0.4), 0.0, 0.5))
	t.rotation.y = 0.0
	add_collider(parent, s, pos + Vector3(0, s.y * 0.5, 0)).rotation.y = rot

static func _outside(store: Node3D, out: Dictionary, target: Object) -> void:
	var f: Rect2 = FENCE
	var asphalt := tiled_floor(4.0, Color(0.075, 0.075, 0.08), Color(0.07, 0.07, 0.075), Color(0.06, 0.06, 0.065))
	var cx := f.position.x + f.size.x * 0.5
	var cz := f.position.y + f.size.y * 0.5
	# ground in strips around the building (avoids z-fighting with store floor)
	box(store, Vector3(f.size.x, 0.1, f.end.y - D * 0.5), Vector3(cx, -0.07, (D * 0.5 + f.end.y) * 0.5), asphalt)
	box(store, Vector3(f.size.x, 0.1, -D * 0.5 - f.position.y), Vector3(cx, -0.07, (f.position.y - D * 0.5) * 0.5), asphalt)
	box(store, Vector3(f.size.x, 0.1, D), Vector3(cx, -0.08, 0), asphalt)
	add_collider(store, Vector3(f.size.x + 4, 0.2, f.size.y + 4), Vector3(cx, -0.1, cz))
	# sidewalk
	box(store, Vector3(W + 2, 0.12, 2.5), Vector3(0, -0.02, D * 0.5 + 1.35), mat(Color(0.32, 0.31, 0.3), 0.0, 0.9))
	# parking lines
	var line := mat(Color(0.7, 0.68, 0.55), 0.0, 0.8)
	for i in 9:
		box(store, Vector3(0.1, 0.01, 4.5), Vector3(-10 + i * 3.0, -0.015, 22.5), line)
	# blocky cars
	_car(store, Vector3(-5.5, 0, 22.5), Color(0.5, 0.08, 0.08))
	_car(store, Vector3(3.5, 0, 22.5), Color(0.18, 0.25, 0.35))
	# street lamps (warm sodium)
	for lp in [Vector3(-8, 0, 25.5), Vector3(13, 0, 25.5), Vector3(3, 0, -27), Vector3(-18, 0, 5)]:
		box(store, Vector3(0.18, 6.0, 0.18), lp + Vector3(0, 3, 0), mat(Color(0.18, 0.18, 0.18)))
		box(store, Vector3(1.0, 0.18, 0.45), lp + Vector3(0, 6.0, 0), mat(Color(1.0, 0.65, 0.3), 4.0))
		add_collider(store, Vector3(0.2, 6, 0.2), lp + Vector3(0, 3, 0))
		var sl := OmniLight3D.new()
		sl.light_color = Color(1.0, 0.6, 0.28)
		sl.omni_range = 13.0
		sl.light_energy = 1.6
		sl.omni_attenuation = 1.3
		sl.position = lp + Vector3(0, 5.6, 0)
		store.add_child(sl)
	# chain-link fence around the lot
	var post_m := mat(Color(0.35, 0.36, 0.37), 0.0, 0.4, 0.7)
	var mesh_m := mat(Color(0.5, 0.52, 0.55, 0.28), 0.0, 0.5, 0.3)
	var fh := 2.2
	for side in [[Vector2(f.position.x, f.position.y), Vector2(f.end.x, f.position.y)], [Vector2(f.position.x, f.end.y), Vector2(f.end.x, f.end.y)], [Vector2(f.position.x, f.position.y), Vector2(f.position.x, f.end.y)], [Vector2(f.end.x, f.position.y), Vector2(f.end.x, f.end.y)]]:
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

static func _car(parent: Node, pos: Vector3, c: Color) -> void:
	var n := Node3D.new()
	n.position = pos
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
	var cpos := Vector3(-4.6, 0, 12.6)
	var can := Node3D.new()
	can.position = cpos
	store.add_child(can)
	cyl(can, 0.3, 0.85, Vector3(0, 0.425, 0), mat(Color(0.22, 0.24, 0.25), 0.0, 0.5, 0.5))
	var bag := cyl(can, 0.27, 0.3, Vector3(0, 0.85, 0), mat(Color(0.04, 0.04, 0.05), 0.0, 0.3))
	box(can, Vector3(0.3, 0.003, 0.15), Vector3(0, 0.6, 0.3), mat(Color(0.2, 0.4, 0.8)))
	out.can = {"node": can, "bag": bag, "body": Interact.make(can, Vector3(0.65, 1.0, 0.65), Vector3(0, 0.5, 0), target, {"kind": "can"})}
	# Cardboard clutter in the store (out of customer paths)
	_clutter_box(store, Vector3(-11.3, 0, 13.6), Vector3(0.8, 0.5, 0.6), 0.2)
	_clutter_box(store, Vector3(-11.4, 0.5, 13.5), Vector3(0.6, 0.4, 0.5), -0.3)
	_clutter_box(store, Vector3(-10.9, 0, 12.6), Vector3(0.55, 0.38, 0.5), 0.6)
	_clutter_box(store, Vector3(10.2, 0, -13.9), Vector3(0.8, 0.5, 0.6), 0.1)
	_clutter_box(store, Vector3(11.2, 0, -13.6), Vector3(0.6, 0.6, 0.6), -0.2)
	_clutter_box(store, Vector3(-6.0, 0, -14.1), Vector3(0.7, 0.45, 0.55), 0.15)
	# Wet floor sign
	var ws := Node3D.new()
	ws.position = Vector3(11.3, 0, 12.5)
	ws.rotation.y = 0.6
	store.add_child(ws)
	for s in [-1, 1]:
		var pnl := box(ws, Vector3(0.35, 0.65, 0.02), Vector3(0, 0.32, s * 0.08), mat(Color(0.95, 0.8, 0.1)))
		pnl.rotation.x = s * 0.22
