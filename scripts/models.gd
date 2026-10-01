class_name Models
## キャラクター・カート・アイテムの3Dモデルを基本図形から組み立てる（外部素材なし）。

static var _mat_cache := {}


static func mat(c: Color, rough := 0.55, metal := 0.0, emissive := 0.0) -> StandardMaterial3D:
	var key := "%s_%s_%s_%s" % [c.to_html(), rough, metal, emissive]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	_mat_cache[key] = m
	return m


static func sphere(parent: Node3D, r: float, c: Color, pos := Vector3.ZERO, scl := Vector3.ONE, segs := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segs
	m.rings = segs / 2
	mi.mesh = m
	mi.material_override = mat(c)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, c: Color, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, c: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, segs := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = segs
	mi.mesh = m
	mi.material_override = mat(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func capsule(parent: Node3D, r: float, h: float, c: Color, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	mi.mesh = m
	mi.material_override = mat(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _eyes(head: Node3D, y: float, z: float, spread: float, size := 0.09) -> void:
	for sx in [-1.0, 1.0]:
		var e := sphere(head, size, Color(1, 1, 1), Vector3(sx * spread, y, z), Vector3(1, 1.25, 0.6), 10)
		sphere(e, size * 0.62, Color(0.08, 0.08, 0.12), Vector3(0, 0, -size * 0.55), Vector3.ONE, 8)
		sphere(e, size * 0.2, Color(1, 1, 1), Vector3(size * 0.2, size * 0.25, -size * 0.95), Vector3.ONE, 6)


## キャラクター（運転席に座った姿勢）。前方は -Z。
static func build_character(idx: int) -> Node3D:
	var d: Dictionary = Game.CHARACTERS[idx]
	var root := Node3D.new()
	root.name = "Driver"
	var col: Color = d.color
	var sub: Color = d.sub
	var skin := Color(1.0, 0.86, 0.72)
	# 胴体
	sphere(root, 0.36, col, Vector3(0, 0.35, 0.05), Vector3(1.0, 1.05, 0.85))
	# 腕（ハンドルへ）
	for sx in [-1.0, 1.0]:
		capsule(root, 0.09, 0.5, col, Vector3(sx * 0.3, 0.42, -0.2), Vector3(deg_to_rad(70), 0, sx * deg_to_rad(-15)))
		sphere(root, 0.1, Color(1, 1, 1), Vector3(sx * 0.24, 0.42, -0.45))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.98, 0)
	root.add_child(head)
	match d.id:
		"rai":
			sphere(head, 0.36, skin)
			# ツンツン髪
			for i in 7:
				var a := -1.2 + i * 0.4
				var spike := cyl(head, 0.0, 0.14, 0.42, sub, Vector3(sin(a) * 0.22, 0.27, 0.12 + cos(a) * 0.05), Vector3(deg_to_rad(-25) , 0, -a * 0.6), 8)
				spike.position.y += 0.02
			sphere(head, 0.37, sub, Vector3(0, 0.07, 0.07), Vector3(1.0, 0.8, 0.95))
			# ゴーグル付きバンド
			cyl(head, 0.375, 0.375, 0.1, col, Vector3(0, 0.12, 0), Vector3.ZERO, 20)
			# 胸の星
			var star := _star_mesh(0.14, Color(1, 0.9, 0.2))
			star.position = Vector3(0, 0.45, -0.28)
			root.add_child(star)
			_eyes(head, 0.0, -0.3, 0.13)
			sphere(head, 0.05, Color(1, 0.55, 0.5), Vector3(0, -0.1, -0.35))
		"mimi":
			sphere(head, 0.36, col)
			sphere(head, 0.2, Color(1, 1, 1), Vector3(0, -0.1, -0.24), Vector3(1.2, 0.8, 0.7))
			for sx in [-1.0, 1.0]:
				var ear := capsule(head, 0.1, 0.7, col, Vector3(sx * 0.15, 0.55, 0.05), Vector3(deg_to_rad(15), 0, sx * deg_to_rad(-12)))
				capsule(ear, 0.055, 0.5, Color(1, 0.82, 0.9), Vector3(0, 0, -0.06))
				sphere(head, 0.07, Color(1, 0.7, 0.8), Vector3(sx * 0.22, -0.08, -0.26), Vector3(1, 0.6, 0.4))
			_eyes(head, 0.05, -0.28, 0.14)
			sphere(head, 0.05, Color(1, 0.4, 0.55), Vector3(0, -0.06, -0.37))
			sphere(root, 0.12, Color(1, 1, 1), Vector3(0, 0.25, 0.42))  # しっぽ
		"gameron":
			sphere(head, 0.34, col, Vector3.ZERO, Vector3(1.05, 0.95, 1.1))
			sphere(head, 0.2, col.lightened(0.25), Vector3(0, -0.12, -0.24), Vector3(1.2, 0.7, 0.7))
			_eyes(head, 0.08, -0.26, 0.14, 0.1)
			# 甲羅
			var shell := sphere(root, 0.5, sub.darkened(0.25), Vector3(0, 0.42, 0.28), Vector3(1.0, 0.9, 0.6))
			for p in [Vector3(0, 0.15, 0.4), Vector3(-0.25, -0.05, 0.3), Vector3(0.25, -0.05, 0.3), Vector3(0, -0.25, 0.35)]:
				sphere(shell, 0.14, sub, p, Vector3(1, 1, 0.4), 10)
			cyl(root, 0.52, 0.52, 0.08, Color(1, 1, 1), Vector3(0, 0.1, 0.25), Vector3.ZERO, 20)
			# ヘルメット
			sphere(head, 0.35, Color(1, 0.9, 0.3), Vector3(0, 0.1, 0.05), Vector3(1.02, 0.75, 1.0))
		"kon":
			sphere(head, 0.35, col)
			var snout := sphere(head, 0.2, Color(1, 1, 1), Vector3(0, -0.12, -0.26), Vector3(1.0, 0.75, 1.2))
			sphere(snout, 0.06, Color(0.1, 0.1, 0.1), Vector3(0, 0.02, -0.2))
			for sx in [-1.0, 1.0]:
				var ear := cyl(head, 0.0, 0.16, 0.36, col, Vector3(sx * 0.2, 0.38, 0.0), Vector3(0, 0, sx * deg_to_rad(-18)), 4)
				cyl(ear, 0.0, 0.09, 0.22, Color(0.25, 0.15, 0.1), Vector3(0, -0.03, -0.06), Vector3.ZERO, 4)
			_eyes(head, 0.05, -0.27, 0.14)
			# しっぽ
			var tail := capsule(root, 0.17, 0.8, col, Vector3(0.2, 0.45, 0.55), Vector3(deg_to_rad(-50), 0, deg_to_rad(-20)))
			sphere(tail, 0.15, Color(1, 1, 1), Vector3(0, 0.35, 0))
	return root


static func _star_mesh(r: float, c: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(Vector3(cos(a) * rr, -sin(a) * rr, 0))
	for i in 10:
		st.set_normal(Vector3(0, 0, -1))
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(pts[(i + 1) % 10])
		st.add_vertex(pts[i])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := mat(c, 0.4, 0.0, 0.3).duplicate()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi


## カート本体。前方は -Z。戻り値の meta "wheels" に回転させる車輪、"front_wheels" に操舵輪。
static func build_kart(kart_idx: int, body_color: Color, char_idx: int) -> Node3D:
	var k: Dictionary = Game.KARTS[kart_idx]
	var root := Node3D.new()
	root.name = "KartModel"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var dark := Color(0.16, 0.16, 0.2)
	var trim := body_color.lightened(0.45)
	var wheels: Array = []
	var fronts: Array = []
	var wheel_r := 0.36
	var wheel_w := 0.34
	var wheel_pos := []
	match k.id:
		"speedstar":
			box(body, Vector3(1.4, 0.32, 2.9), body_color, Vector3(0, 0.42, 0))
			box(body, Vector3(1.0, 0.26, 1.0), body_color, Vector3(0, 0.52, -1.35), Vector3(deg_to_rad(-8), 0, 0))
			box(body, Vector3(1.9, 0.1, 0.5), trim, Vector3(0, 0.35, -1.75))     # フロントウィング
			box(body, Vector3(1.8, 0.1, 0.5), dark, Vector3(0, 1.05, 1.35))      # リアウィング
			for sx in [-0.55, 0.55]:
				box(body, Vector3(0.1, 0.55, 0.3), dark, Vector3(sx, 0.78, 1.35))
			box(body, Vector3(1.5, 0.16, 0.35), trim, Vector3(0, 0.62, -0.55))
			wheel_pos = [Vector3(-0.95, wheel_r, -1.1), Vector3(0.95, wheel_r, -1.1), Vector3(-1.0, wheel_r + 0.04, 1.0), Vector3(1.0, wheel_r + 0.04, 1.0)]
		"golden":
			var gold := Color(1.0, 0.78, 0.2)
			var gm := mat(gold, 0.3, 0.55)
			var parts := [
				box(body, Vector3(1.5, 0.34, 2.9), gold, Vector3(0, 0.42, 0)),
				box(body, Vector3(1.1, 0.3, 1.1), gold, Vector3(0, 0.55, -1.3), Vector3(deg_to_rad(-10), 0, 0)),
				box(body, Vector3(2.0, 0.1, 0.55), gold, Vector3(0, 0.35, -1.8)),
				box(body, Vector3(1.9, 0.12, 0.55), gold, Vector3(0, 1.1, 1.35)),
			]
			for pp in parts:
				pp.material_override = gm
			for sx in [-0.6, 0.6]:
				box(body, Vector3(0.12, 0.6, 0.35), dark, Vector3(sx, 0.8, 1.35))
				var fin := box(body, Vector3(0.1, 0.35, 1.4), Color(1, 1, 1), Vector3(sx * 1.2, 0.55, 0.2))
				fin.material_override = mat(Color(1, 1, 1), 0.2, 0.3, 0.4)
			var gem := sphere(body, 0.2, Color(0.3, 0.8, 1.0), Vector3(0, 0.72, -1.55))
			gem.material_override = mat(Color(0.3, 0.8, 1.0), 0.1, 0.0, 1.5)
			wheel_pos = [Vector3(-0.98, wheel_r, -1.1), Vector3(0.98, wheel_r, -1.1), Vector3(-1.02, wheel_r + 0.04, 1.0), Vector3(1.02, wheel_r + 0.04, 1.0)]
		"balancer":
			box(body, Vector3(1.6, 0.4, 2.5), body_color, Vector3(0, 0.45, 0))
			box(body, Vector3(1.3, 0.35, 0.8), body_color, Vector3(0, 0.62, -1.0))
			box(body, Vector3(1.8, 0.14, 0.4), trim, Vector3(0, 0.35, -1.35))
			box(body, Vector3(1.4, 0.45, 0.35), dark, Vector3(0, 0.8, 0.95))
			cyl(body, 0.13, 0.16, 0.5, Color(0.7, 0.7, 0.75), Vector3(-0.35, 0.6, 1.35), Vector3(deg_to_rad(90), 0, 0), 10)
			cyl(body, 0.13, 0.16, 0.5, Color(0.7, 0.7, 0.75), Vector3(0.35, 0.6, 1.35), Vector3(deg_to_rad(90), 0, 0), 10)
			wheel_pos = [Vector3(-0.95, wheel_r, -0.85), Vector3(0.95, wheel_r, -0.85), Vector3(-0.98, wheel_r + 0.04, 0.85), Vector3(0.98, wheel_r + 0.04, 0.85)]
		_:  # dashbug
			var shell := sphere(body, 1.0, body_color, Vector3(0, 0.55, 0.05), Vector3(0.85, 0.42, 1.25), 20)
			shell.name = "Shell"
			for p in [Vector3(-0.35, 0.95, 0.35), Vector3(0.35, 0.95, 0.35), Vector3(-0.4, 0.85, 0.85), Vector3(0.4, 0.85, 0.85), Vector3(0, 0.98, 0.7)]:
				sphere(body, 0.14, dark, p, Vector3(1, 0.4, 1), 10)
			sphere(body, 0.38, dark, Vector3(0, 0.6, -1.15), Vector3(1.1, 0.8, 0.8))
			for sx in [-1.0, 1.0]:
				var ant := cyl(body, 0.03, 0.03, 0.7, dark, Vector3(sx * 0.2, 1.0, -1.25), Vector3(deg_to_rad(-35), 0, sx * deg_to_rad(-20)), 6)
				sphere(ant, 0.09, Color(1, 0.9, 0.2), Vector3(0, 0.38, 0))
			wheel_pos = [Vector3(-0.85, wheel_r, -0.8), Vector3(0.85, wheel_r, -0.8), Vector3(-0.9, wheel_r + 0.04, 0.85), Vector3(0.9, wheel_r + 0.04, 0.85)]
	# シート
	box(body, Vector3(0.8, 0.2, 0.7), dark, Vector3(0, 0.62, 0.35))
	box(body, Vector3(0.8, 0.7, 0.18), dark, Vector3(0, 0.95, 0.72), Vector3(deg_to_rad(-12), 0, 0))
	# ハンドル
	var sw := cyl(body, 0.22, 0.22, 0.06, dark, Vector3(0, 0.95, -0.45), Vector3(deg_to_rad(60), 0, 0), 14)
	sw.name = "SteeringWheel"
	# 車輪
	for i in wheel_pos.size():
		var pivot := Node3D.new()
		pivot.position = wheel_pos[i]
		root.add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		var w_extra := 0.08 if i >= 2 else 0.0
		cyl(spin, wheel_r + w_extra * 0.5, wheel_r + w_extra * 0.5, wheel_w + w_extra, dark, Vector3.ZERO, Vector3(0, 0, deg_to_rad(90)), 14)
		cyl(spin, 0.17, 0.17, wheel_w + w_extra + 0.02, Color(0.92, 0.92, 0.95), Vector3.ZERO, Vector3(0, 0, deg_to_rad(90)), 10)
		box(spin, Vector3(wheel_w + w_extra + 0.04, 0.08, 0.3), Color(1, 0.85, 0.2), Vector3.ZERO)
		wheels.append(spin)
		if i < 2:
			fronts.append(pivot)
	# 運転手
	var drv := build_character(char_idx)
	drv.position = Vector3(0, 0.55, 0.3)
	body.add_child(drv)
	# 影（丸い簡易シャドウ）
	var shadow := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.4, 3.2)
	shadow.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0, 0, 0, 0.35)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_texture = _round_shadow_tex()
	shadow.material_override = sm
	shadow.position.y = 0.05
	shadow.name = "Shadow"
	root.add_child(shadow)
	bake(body)
	for w in wheels:
		bake(w)
	root.set_meta("wheels", wheels)
	root.set_meta("front_wheels", fronts)
	root.set_meta("body", body)
	root.set_meta("driver", drv)
	root.set_meta("shadow", shadow)
	return root


static var _shadow_tex: Texture2D
static func _round_shadow_tex() -> Texture2D:
	if _shadow_tex:
		return _shadow_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * 1.6))
	_shadow_tex = ImageTexture.create_from_image(img)
	return _shadow_tex


static var _qtex: Texture2D
## アイテムボックス（虹色の半透明キューブ＋「？」）
static func build_item_box() -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.5, 1.5, 1.5)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = false
	m.emission_enabled = true
	m.emission = Color(0.4, 0.6, 1.0)
	m.emission_energy_multiplier = 0.6
	m.roughness = 0.1
	m.rim_enabled = true
	mi.material_override = m
	mi.name = "Cube"
	root.add_child(mi)
	var q := Label3D.new()
	q.text = "?"
	q.font_size = 110
	q.outline_size = 18
	q.modulate = Color(1, 0.95, 0.3)
	q.outline_modulate = Color(0.6, 0.2, 0.0)
	q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	q.no_depth_test = false
	q.pixel_size = 0.009
	root.add_child(q)
	return root


static func build_spin_ball() -> Node3D:
	var root := Node3D.new()
	var s := sphere(root, 0.6, Color(0.2, 0.55, 1.0), Vector3.ZERO, Vector3.ONE, 16)
	s.material_override = mat(Color(0.2, 0.55, 1.0), 0.3, 0.0, 0.6)
	for i in 3:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.62
		tm.outer_radius = 0.72
		ring.mesh = tm
		ring.material_override = mat(Color(1, 1, 1), 0.3, 0.0, 0.5)
		ring.rotation = Vector3(i * 1.0, i * 0.7, 0)
		root.add_child(ring)
	return root


static func build_slip_ball() -> Node3D:
	var root := Node3D.new()
	var s := sphere(root, 0.55, Color(1.0, 0.85, 0.2), Vector3(0, 0.45, 0), Vector3(1, 0.85, 1), 16)
	s.material_override = mat(Color(1.0, 0.85, 0.25), 0.3, 0.0, 0.35)
	sphere(root, 0.15, Color(1, 1, 1), Vector3(-0.18, 0.72, -0.25), Vector3.ONE, 8)
	# ぬるぬるの水たまり
	var puddle := cyl(root, 1.0, 1.0, 0.04, Color(1.0, 0.9, 0.4, 0.55), Vector3(0, 0.03, 0), Vector3.ZERO, 20)
	puddle.name = "Puddle"
	return root


static func build_barrier() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.9
	sm.height = 3.2
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.9, 1.0, 0.3)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	mi.material_override = m
	mi.position.y = 1.0
	return mi


## 色だけちがう図形をまとめて1つのメッシュにする（描画を軽くするため）。
## テクスチャ・半透明・両面のものはそのまま残す。skip にあるノードの下は触らない。
static func bake(root: Node3D, skip: Array = []) -> void:
	var groups := {}   # key -> {mat, v, n, c, i}
	var victims: Array[MeshInstance3D] = []
	_bake_collect(root, root, Transform3D.IDENTITY, skip, groups, victims)
	if victims.size() < 2:
		return
	for mi in victims:
		mi.get_parent().remove_child(mi)
		mi.free()
	for key in groups:
		var g: Dictionary = groups[key]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g.v
		arr[Mesh.ARRAY_NORMAL] = g.n
		arr[Mesh.ARRAY_COLOR] = g.c
		arr[Mesh.ARRAY_INDEX] = g.i
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var out := MeshInstance3D.new()
		out.mesh = am
		out.material_override = g.mat
		out.name = "Baked"
		root.add_child(out)


static func _bake_collect(root: Node3D, node: Node, xf: Transform3D, skip: Array, groups: Dictionary, victims: Array[MeshInstance3D]) -> void:
	for ch in node.get_children():
		if ch in skip or not (ch is Node3D):
			continue
		var cxf: Transform3D = xf * (ch as Node3D).transform
		if ch is MeshInstance3D and ch.name != "Baked":
			var mi := ch as MeshInstance3D
			var m := mi.material_override as StandardMaterial3D
			if m and mi.mesh and m.albedo_texture == null and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
					and m.cull_mode == BaseMaterial3D.CULL_BACK and not m.vertex_color_use_as_albedo and mi.get_child_count() == 0:
				var key := "%.2f_%.2f_%s_%.2f" % [m.roughness, m.metallic, m.emission.to_html() if m.emission_enabled else "-", m.emission_energy_multiplier if m.emission_enabled else 0.0]
				if not groups.has(key):
					var gm := StandardMaterial3D.new()
					gm.vertex_color_use_as_albedo = true
					gm.vertex_color_is_srgb = true
					gm.roughness = m.roughness
					gm.metallic = m.metallic
					if m.emission_enabled:
						gm.emission_enabled = true
						gm.emission = m.emission
						gm.emission_energy_multiplier = m.emission_energy_multiplier
					groups[key] = {"mat": gm, "v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
				var g: Dictionary = groups[key]
				for s in mi.mesh.get_surface_count():
					var a := mi.mesh.surface_get_arrays(s)
					var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
					var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
					var idx = a[Mesh.ARRAY_INDEX]
					var base: int = g.v.size()
					var nb := cxf.basis.inverse().transposed()
					for k in verts.size():
						g.v.append(cxf * verts[k])
						g.n.append((nb * norms[k]).normalized() if k < norms.size() else Vector3.UP)
						g.c.append(m.albedo_color)
					if idx is PackedInt32Array and idx.size() > 0:
						for q in idx:
							g.i.append(base + q)
					else:
						for q in verts.size():
							g.i.append(base + q)
				victims.append(mi)
				continue
		_bake_collect(root, ch, cxf, skip, groups, victims)
