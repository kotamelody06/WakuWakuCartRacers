class_name Track
extends Node3D
## コース中心線からコースの見た目と当たり判定情報を作る。
## 中心線は等間隔（約2.5m）にサンプリングし、各サンプルに路面・壁・ジャンプ台などの情報を持たせる。
## 見た目はテーマ（themes.gd）で切り替え、飾りはテーマごとの _decor_* で作る。

enum Edge { SHOULDER, RAIL, FALL }
enum Surf { ROAD, BRIDGE, ICE }

const SPACING := 2.5
const DASH_HALF_W := 2.6

var course: Dictionary
var th: Dictionary          # テーマ
var theme_id := "grass"
var easy_rails := false
var n := 0
var length := 0.0
var ds := 0.0
var pts := PackedVector3Array()
var tang := PackedVector3Array()
var rightv := PackedVector3Array()
var edge := PackedInt32Array()
var surf := PackedInt32Array()
var gap := PackedByteArray()
var tunnel := PackedByteArray()
var ramp_h := PackedFloat32Array()
var ramp_launch := PackedFloat32Array()   # >0 のサンプルを通過すると発射
var dash_lat := PackedFloat32Array()      # ダッシュ板の横位置（なしは NAN）
var hw := 8.0            # 路面の半幅
var shoulder := 0.0      # 路肩（オフロード）の幅
var offroad := "grass"
var offroad_mult := 0.55
var dust_color := Color.WHITE
var floating := false    # 空に浮かぶコース
var elevated := false    # 高架のコース（柱で支える）
var base_y := -0.1       # 地面・溶岩の高さ
var miny := 0.0
var maxy := 0.0
var item_rows: Array = []   # [index, ...]
var start_index := 0
var bbox := Rect2()
var _anim_mats: Array = []   # [material, speed]
var _t := 0.0


func build(c: Dictionary, diff: Dictionary = {}) -> void:
	course = c
	theme_id = c.get("theme", c.id)
	th = Themes.get_theme(theme_id)
	hw = c.width * 0.5
	offroad = c.offroad
	floating = offroad == "void"
	elevated = theme_id == "night"
	shoulder = c.get("shoulder", 0.0)
	offroad_mult = th.get("offroad_mult", 0.6)
	dust_color = th.get("dust", Color.WHITE)
	easy_rails = diff.get("rails", false)
	_sample(c.pts)
	_assign_features()
	_build_env()
	_build_road()
	_build_dash_panels()
	_build_decor()
	_build_start_gate()
	Models.bake(self)


# ------------------------------------------------------------------ サンプリング
func _sample(ctrl: Array) -> void:
	var P: Array[Vector3] = []
	for p in ctrl:
		P.append(Vector3(p[0], p[1], p[2]))
	var fine: Array[Vector3] = []
	var m := P.size()
	for i in m:
		var p0 := P[(i - 1 + m) % m]
		var p1 := P[i]
		var p2 := P[(i + 1) % m]
		var p3 := P[(i + 2) % m]
		for k in 40:
			var t := k / 40.0
			var t2 := t * t
			var t3 := t2 * t
			fine.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	var cum := PackedFloat32Array()
	cum.append(0.0)
	var total := 0.0
	for i in fine.size():
		var a := fine[i]
		var b := fine[(i + 1) % fine.size()]
		total += Vector2(b.x - a.x, b.z - a.z).length()
		cum.append(total)
	length = total
	n = int(round(total / SPACING))
	ds = total / n
	pts.resize(n)
	var j := 0
	for i in n:
		var target := i * ds
		while cum[j + 1] < target:
			j += 1
		var seg := cum[j + 1] - cum[j]
		var f := 0.0 if seg <= 0.0 else (target - cum[j]) / seg
		pts[i] = fine[j].lerp(fine[(j + 1) % fine.size()], f)
	tang.resize(n)
	rightv.resize(n)
	for i in n:
		var d := pts[(i + 1) % n] - pts[(i - 1 + n) % n]
		var h := Vector3(d.x, 0, d.z).normalized()
		tang[i] = d.normalized()
		rightv[i] = Vector3(-h.z, 0, h.x)   # 進行方向に対して右
	for arr in [edge, surf, gap, tunnel, ramp_h, ramp_launch, dash_lat]:
		arr.resize(n)
	var def_edge: int = {"shoulder": Edge.SHOULDER, "rail": Edge.RAIL, "fall": Edge.FALL}.get(course.edge, Edge.RAIL)
	for i in n:
		edge[i] = def_edge
		surf[i] = Surf.ROAD
		gap[i] = 0
		tunnel[i] = 0
		ramp_h[i] = 0.0
		ramp_launch[i] = 0.0
		dash_lat[i] = NAN
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in pts:
		mn = mn.min(Vector2(p.x, p.z))
		mx = mx.max(Vector2(p.x, p.z))
	bbox = Rect2(mn, mx - mn)


func nearest_index_xz(x: float, z: float) -> int:
	var best := 0
	var bd := INF
	for i in n:
		var dd := Vector2(pts[i].x - x, pts[i].z - z).length_squared()
		if dd < bd:
			bd = dd
			best = i
	return best


## 位置の指定 → サンプル番号。[x, z] は座標、数字はスタートからの距離(m)。
func idx_of(v) -> int:
	if v is Array:
		return nearest_index_xz(v[0], v[1])
	return wrap_i(int(round(float(v) / ds)))


func _range(r: Array) -> Array:
	var a := idx_of(r[0])
	var b := idx_of(r[1])
	var out := []
	var i := a
	while true:
		out.append(i)
		if i == b:
			break
		i = (i + 1) % n
		if out.size() > n:
			break
	return out


func _assign_features() -> void:
	for r in course.get("falls", []):
		for i in _range(r):
			edge[i] = Edge.FALL
	if course.has("bridge"):
		var rr: Array = _range(course.bridge)
		for k in rr.size():
			var i: int = rr[k]
			surf[i] = Surf.BRIDGE
			edge[i] = Edge.RAIL
			pts[i].y += sin(PI * float(k) / float(rr.size() - 1)) * 1.6
	for r in course.get("ice", []):
		for i in _range(r):
			surf[i] = Surf.ICE
	for r in course.get("tunnels", []):
		for i in _range(r):
			tunnel[i] = 1
			edge[i] = Edge.RAIL
	# 柵のないコースでも、きついカーブには柵をつける
	if course.edge == "fall":
		var mark := PackedByteArray()
		mark.resize(n)
		for i in n:
			var a1 := tang[wrap_i(i - 2)]
			var a2 := tang[wrap_i(i + 2)]
			var ang := absf(wrapf(atan2(a2.x, a2.z) - atan2(a1.x, a1.z), -PI, PI))
			var r := (4.0 * ds) / maxf(ang, 0.0001)
			if r < 55.0:
				for k in range(-6, 7):
					mark[wrap_i(i + k)] = 1
		for i in n:
			if mark[i] == 1 and edge[i] == Edge.FALL:
				edge[i] = Edge.RAIL
	# やさしい：落ちる場所に柵をつける（ジャンプで越える穴はそのまま）
	if easy_rails:
		for i in n:
			if edge[i] == Edge.FALL:
				edge[i] = Edge.RAIL
	for r in course.get("gaps", []):
		for i in _range(r):
			gap[i] = 1
			edge[i] = Edge.FALL
	for rp in course.get("ramps", []):
		var c := idx_of(rp[0])
		var steps := 4
		for k in steps + 1:
			var i := (c - steps + k + n) % n
			ramp_h[i] = 1.4 * float(k) / steps
		ramp_launch[(c + 1) % n] = rp[1]
	for dp in course.get("dash", []):
		var c := idx_of(dp[0])
		for k in 3:
			dash_lat[wrap_i(c + k)] = dp[1]
	# アイテムボックス（指定がなければ自動で5か所）
	if course.has("items"):
		for it in course.items:
			item_rows.append(idx_of(it))
	else:
		for f in [0.09, 0.3, 0.5, 0.68, 0.86]:
			var i := wrap_i(int(n * f))
			var guard := 0
			while (gap[i] == 1 or ramp_h[i] > 0.0 or ramp_h[wrap_i(i + 3)] > 0.0 or gap[wrap_i(i + 6)] == 1 or not is_nan(dash_lat[i])) and guard < 40:
				i = wrap_i(i + 1)
				guard += 1
			item_rows.append(i)
	# 高さ
	miny = INF
	maxy = -INF
	for i in n:
		miny = min(miny, pts[i].y)
		maxy = max(maxy, pts[i].y)
	base_y = miny - course.get("base_drop", 0.08)
	if floating:
		base_y = miny - 60.0


# ------------------------------------------------------------------ 位置の問い合わせ
func wrap_i(i: int) -> int:
	return ((i % n) + n) % n


## 位置 pos に最も近いサンプルを hint の近くから探す（hint<0 なら全探索）
func locate(pos: Vector3, hint: int) -> int:
	if hint < 0:
		return nearest_index_xz(pos.x, pos.z)
	var best := hint
	var bd := INF
	for k in range(-14, 15):
		var i := wrap_i(hint + k)
		var p := pts[i]
		var dd := (p.x - pos.x) * (p.x - pos.x) + (p.z - pos.z) * (p.z - pos.z)
		if dd < bd:
			bd = dd
			best = i
	if bd > 60.0 * 60.0:
		return nearest_index_xz(pos.x, pos.z)
	return best


## 詳細情報: 区間 i→i+1 上の位置 t、横ずれ lat、スタートからの距離 d、中心の高さ y
func project(pos: Vector3, i: int) -> Dictionary:
	var p := pts[i]
	var h := Vector3(tang[i].x, 0, tang[i].z).normalized()
	var along := (pos - p).dot(h)
	var i0 := i if along >= 0.0 else wrap_i(i - 1)
	var a := pts[i0]
	var b := pts[wrap_i(i0 + 1)]
	var seg := Vector3(b.x - a.x, 0, b.z - a.z)
	var sl := seg.length()
	var t := clampf(Vector3(pos.x - a.x, 0, pos.z - a.z).dot(seg) / (sl * sl), 0.0, 1.0)
	var r := rightv[i0].lerp(rightv[wrap_i(i0 + 1)], t).normalized()
	var c := a.lerp(b, t)
	var lat := Vector3(pos.x - c.x, 0, pos.z - c.z).dot(r)
	var y := c.y + lerpf(ramp_h[i0], ramp_h[wrap_i(i0 + 1)], t)
	return {"i0": i0, "t": t, "lat": lat, "d": (i0 + t) * ds, "y": y, "right": r,
		"fwd": Vector3(seg.x, 0, seg.z) / sl, "center": c}


## 距離 d・横ずれ lat の位置（高さ込み）
func point_at(d: float, lat := 0.0) -> Vector3:
	var f := fposmod(d, length) / ds
	var i0 := int(f) % n
	var t: float = f - floor(f)
	var c := pts[i0].lerp(pts[wrap_i(i0 + 1)], t)
	var r := rightv[i0].lerp(rightv[wrap_i(i0 + 1)], t).normalized()
	c.y += lerpf(ramp_h[i0], ramp_h[wrap_i(i0 + 1)], t)
	return c + r * lat


func dir_at(d: float) -> Vector3:
	var f := fposmod(d, length) / ds
	var i0 := int(f) % n
	var t: float = f - floor(f)
	var v := tang[i0].lerp(tang[wrap_i(i0 + 1)], t)
	return Vector3(v.x, 0, v.z).normalized()


## 壁までの横幅（この外には出られない）。FALL の区間は INF。
func wall_limit(i: int) -> float:
	match edge[i]:
		Edge.SHOULDER:
			return hw + shoulder
		Edge.RAIL:
			return hw + 0.2
	return INF


func has_ground(i: int, lat: float) -> bool:
	if gap[i] == 1:
		return false
	if edge[i] == Edge.FALL and absf(lat) > hw + 0.6:
		return false
	return true


# ------------------------------------------------------------------ 共通の部品
func _process(delta: float) -> void:
	_t += delta
	for am in _anim_mats:
		var m: StandardMaterial3D = am[0]
		m.uv1_offset = Vector3(_t * am[1].x, _t * am[1].y, 0)


static func _noise_img(w: int, h: int, base: Color, var_amt: float, seed_v: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var v := rng.randf_range(-var_amt, var_amt)
			img.set_pixel(x, y, Color(base.r + v, base.g + v, base.b + v))
	return img


func _tex_mat(img: Image, rough := 0.9, filter_nearest := false) -> StandardMaterial3D:
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS if filter_nearest else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_fog = true
	return m


## たくさんの同じ形をまとめて描く
func _mm(mesh: Mesh, mat: Material, xforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


static func _sphere_mesh(r: float, segs := 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(segs / 2, 3)
	return s


static func _cyl_mesh(rt: float, rb: float, h: float, segs := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


static func _box_mesh(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _far_from_track(p: Vector3, min_d: float) -> bool:
	var md := min_d * min_d
	for i in range(0, n, 2):
		var dd := Vector2(pts[i].x - p.x, pts[i].z - p.z).length_squared()
		if dd < md:
			return false
	return true


## コースから min_d 以上はなれた場所を count 個さがす
func _scatter(rng: RandomNumberGenerator, count: int, min_d: float, margin: float, y := INF, max_d := INF) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var tries := 0
	while out.size() < count and tries < count * 30:
		tries += 1
		var p := Vector3(rng.randf_range(bbox.position.x - margin, bbox.end.x + margin), base_y if y == INF else y,
			rng.randf_range(bbox.position.y - margin, bbox.end.y + margin))
		if not _far_from_track(p, min_d):
			continue
		if max_d < INF and _far_from_track(p, max_d):
			continue
		out.append(p)
	return out


## コースわきの位置（d: 距離, side: -1/1, off: 道の端からの距離）
func _roadside(d: float, side: float, off: float, y_off := 0.0) -> Vector3:
	var p := point_at(d, (hw + off) * side)
	p.y += y_off
	return p


func _center() -> Vector3:
	return Vector3(bbox.get_center().x, base_y, bbox.get_center().y)


# ------------------------------------------------------------------ 空・光・地面
func _build_env() -> void:
	var env := Environment.new()
	if th.has("bg"):
		env.background_mode = Environment.BG_COLOR
		env.background_color = th.bg
	else:
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		var sc: Array = th.sky
		sm.sky_top_color = sc[0]
		sm.sky_horizon_color = sc[1]
		sm.ground_horizon_color = sc[2]
		sm.ground_bottom_color = sc[3]
		if theme_id == "volcano":
			sm.sun_angle_max = 5.0
		if th.get("stars", false):
			sm.sun_angle_max = 1.0
		sky.sky_material = sm
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = th.ambient
	env.ambient_light_energy = th.get("ambient_energy", 0.62)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.06
	if th.has("fog"):
		env.fog_enabled = true
		env.fog_light_color = th.fog[0]
		env.fog_density = th.fog[1]
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	sun.light_energy = th.sun[0]
	sun.light_color = th.sun[1]
	# スマホで軽く動くように、影はカートの丸い影だけにする
	sun.shadow_enabled = false
	add_child(sun)
	if th.get("stars", false):
		_stars(theme_id == "space")
	# 地面
	var g = th.get("ground")
	if g == null:
		return
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var gsize := 1400.0
	if theme_id == "beach":
		gsize = maxf(bbox.size.x, bbox.size.y) + 150.0
	pm.size = Vector2(gsize, gsize)
	ground.mesh = pm
	ground.position = Vector3(bbox.get_center().x, base_y, bbox.get_center().y)
	ground.name = "Ground"
	if g is String and g == "lava":
		var lava := StandardMaterial3D.new()
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var v := 0.5 + 0.25 * sin(x * 0.35 + sin(y * 0.2) * 2.0) + 0.25 * sin(y * 0.3 + x * 0.1)
				img.set_pixel(x, y, Color(0.85 + v * 0.15, 0.12 + v * 0.42, 0.02 + v * 0.05))
		img.generate_mipmaps()
		lava.albedo_texture = ImageTexture.create_from_image(img)
		lava.emission_enabled = true
		lava.emission_texture = lava.albedo_texture
		lava.emission_energy_multiplier = 0.75
		lava.uv1_scale = Vector3(60, 60, 1)
		ground.material_override = lava
		_anim_mats.append([lava, Vector2(0.03, 0.015)])
	elif g is String and g == "city":
		var img := _noise_img(64, 64, Color(0.07, 0.08, 0.12), 0.02, 7)
		var glow := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		glow.fill(Color.BLACK)
		for y in 64:
			for x in 64:
				if x % 32 < 3 or y % 32 < 3:
					img.set_pixel(x, y, Color(0.25, 0.25, 0.3))
					if (x + y) % 6 == 0:
						glow.set_pixel(x, y, Color(1.0, 0.8, 0.4))
		var cm := _tex_mat(img, 0.9)
		glow.generate_mipmaps()
		cm.emission_enabled = true
		cm.emission_texture = ImageTexture.create_from_image(glow)
		cm.emission_energy_multiplier = 1.5
		cm.uv1_scale = Vector3(30, 30, 1)
		ground.material_override = cm
	else:
		var gm := _tex_mat(_noise_img(64, 64, g, 0.05, 7), 0.95)
		gm.uv1_scale = Vector3(gsize / 10.0, gsize / 10.0, 1)
		ground.material_override = gm
	add_child(ground)
	if theme_id == "beach":
		_sea()


func _stars(full_sphere: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var xf := []
	var c := _center()
	for k in (900 if full_sphere else 500):
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.05 if not full_sphere else -1.0, 1), rng.randf_range(-1, 1)).normalized()
		var s := rng.randf_range(0.8, 2.6)
		xf.append(Transform3D(Basis().scaled(Vector3.ONE * s), Vector3(c.x, maxy, c.z) + v * 900.0))
	_mm(_sphere_mesh(1.0, 4), unshaded(Color(1, 1, 0.95)), xf)


func _sea() -> void:
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2400, 2400)
	sea.mesh = pm
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var v := 0.5 + 0.5 * sin(x * 0.2 + sin(y * 0.3) * 1.5)
			img.set_pixel(x, y, Color(0.05 + v * 0.15, 0.45 + v * 0.2, 0.85 + v * 0.1))
	var m := _tex_mat(img, 0.1)
	m.metallic_specular = 1.0
	m.uv1_scale = Vector3(120, 120, 1)
	sea.material_override = m
	_anim_mats.append([m, Vector2(0.01, 0.006)])
	sea.position = Vector3(bbox.get_center().x, base_y - 0.6, bbox.get_center().y)
	add_child(sea)


# ------------------------------------------------------------------ 路面の見た目
func _road_material() -> StandardMaterial3D:
	var rd: Dictionary = th.road
	var style: String = rd.get("style", "normal")
	var base: Color = rd.base
	var curb_a: Color = rd.curb_a
	var curb_b: Color = rd.curb_b
	var center = rd.get("center")
	var glow_mode: String = rd.get("glow", "")
	var img := _noise_img(128, 128, base, 0.035 if style != "neon" else 0.015, 11)
	var glow := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	glow.fill(Color.BLACK)
	var rainbow := [Color(1, 0.35, 0.4), Color(1, 0.6, 0.3), Color(1, 0.9, 0.35), Color(0.45, 0.9, 0.45),
		Color(0.35, 0.75, 1.0), Color(0.5, 0.5, 1.0), Color(0.8, 0.5, 1.0)]
	for y in 128:
		var stripe := (y / 16) % 2 == 0
		for x in 128:
			var c := img.get_pixel(x, y)
			var gl := Color.BLACK
			match style:
				"rainbow":
					if x >= 8 and x <= 119:
						c = rainbow[clampi((x - 8) * 7 / 112, 0, 6)]
						gl = c * 0.18
				"tiles":
					if x % 16 == 0 or y % 16 == 0:
						c = c.darkened(0.25)
				"dirt":
					if (x * 7 + y * 3) % 23 == 0:
						c = c.darkened(0.2)
				"neon":
					if x % 16 == 8 or y % 16 == 0:
						c = Color(0.35, 0.2, 0.7)
						gl = Color(0.35, 0.2, 0.7) * 0.8
			if x < 7 or x > 120:
				if style == "highway":
					c = base
				elif style == "dirt":
					c = curb_a if (y % 8) < 6 else curb_b
				else:
					c = curb_a if stripe else curb_b
				if glow_mode == "curb" and stripe:
					gl = curb_a
				if style == "neon":
					c = curb_a if x < 7 else curb_b
					gl = c
			elif x == 7 or x == 120:
				if style != "dirt":
					c = Color(1, 1, 1)
				if style == "highway":
					gl = Color(0.6, 0.6, 0.6)
			elif center != null and absi(x - 64) <= 1 and ((y / 32) % 2 == 0 or style == "highway"):
				c = center
				if glow_mode == "lines":
					gl = center * 0.8
			if style == "highway" and (x == 34 or x == 94) and (y / 16) % 2 == 0:
				c = Color(0.9, 0.9, 0.9)
			img.set_pixel(x, y, c)
			glow.set_pixel(x, y, gl)
	var m := _tex_mat(img, 0.85 if style != "neon" else 0.3)
	if glow_mode != "" or style == "rainbow":
		glow.generate_mipmaps()
		m.emission_enabled = true
		m.emission_texture = ImageTexture.create_from_image(glow)
		m.emission_energy_multiplier = 1.6 if style == "neon" else 1.0
	return m


func _bridge_material() -> StandardMaterial3D:
	var img := _noise_img(64, 64, Color(0.62, 0.42, 0.24), 0.04, 3)
	for y in 64:
		for x in 64:
			if y % 8 == 0:
				img.set_pixel(x, y, Color(0.35, 0.22, 0.12))
	return _tex_mat(img, 0.8)


func _ice_material() -> StandardMaterial3D:
	var img := _noise_img(64, 64, Color(0.62, 0.86, 1.0), 0.05, 5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for k in 30:
		var x := rng.randi_range(0, 63)
		var y := rng.randi_range(0, 63)
		for l in 8:
			img.set_pixel((x + l) % 64, (y + l / 2) % 64, Color(0.95, 1, 1))
	var m := _tex_mat(img, 0.08)
	m.metallic = 0.2
	m.metallic_specular = 1.0
	return m


func _shoulder_material() -> StandardMaterial3D:
	var g = th.get("ground")
	var col: Color = g if g is Color else Color(0.4, 0.4, 0.4)
	var m := _tex_mat(_noise_img(64, 64, col, 0.06, 7), 0.95)
	m.uv1_scale = Vector3(2, 1, 1)
	return m


func _wall_material() -> StandardMaterial3D:
	var col: Color = th.get("wall", Color(0.5, 0.5, 0.5))
	var img := _noise_img(32, 16, col, 0.08, 21)
	match th.get("wall_style", ""):
		"fence":
			for y in 16:
				for x in 32:
					if x % 8 < 2:
						img.set_pixel(x, y, col.darkened(0.3))
					elif y in [3, 4, 11, 12]:
						img.set_pixel(x, y, col.lightened(0.2))
					else:
						img.set_pixel(x, y, Color(0.35, 0.7, 0.3))
		"dune":
			img = _noise_img(32, 16, col, 0.03, 21)
	return _tex_mat(img, 0.9)


func _rail_material() -> StandardMaterial3D:
	var style: String = th.get("rail", "metal")
	var rimg := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	var glow := false
	for y in 16:
		for x in 32:
			var c := Color(0.85, 0.85, 0.9)
			match style:
				"hazard":
					c = Color(1, 0.8, 0.1) if ((x + y) / 6) % 2 == 0 else Color(0.12, 0.1, 0.1)
				"wood":
					c = Color(0.7, 0.5, 0.3) if y % 5 != 0 else Color(0.45, 0.3, 0.15)
				"blue":
					c = Color(0.3, 0.55, 1.0) if (x / 8) % 2 == 0 else Color(1, 1, 1)
				"candy":
					c = Color(1.0, 0.55, 0.8) if ((x + y) / 5) % 2 == 0 else Color(1, 1, 1)
				"stone":
					c = Color(0.55, 0.5, 0.45) if (x % 16 != 0 and y % 8 != 0) else Color(0.35, 0.32, 0.3)
				"metal":
					c = Color(0.75, 0.77, 0.82) if y > 3 and y < 12 else Color(0.45, 0.47, 0.52)
				"gold":
					c = Color(1.0, 0.82, 0.3) if y > 3 and y < 12 else Color(1, 1, 1)
				"neon":
					c = Color(0.2, 1.0, 1.0) if y < 3 or y > 12 else Color(0.1, 0.05, 0.25)
					glow = true
			if style != "neon" and (y < 2 or y > 13):
				c = c.darkened(0.3)
			rimg.set_pixel(x, y, c)
	var m := _tex_mat(rimg, 0.6)
	if glow:
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = 1.5
	if style == "metal" or style == "gold":
		m.metallic = 0.5
	return m


# ------------------------------------------------------------------ 路面・壁・柵
func _build_road() -> void:
	var road_st := SurfaceTool.new()
	var bridge_st := SurfaceTool.new()
	var ice_st := SurfaceTool.new()
	var shoulder_st := SurfaceTool.new()
	var skirt_st := SurfaceTool.new()
	var wall_st := SurfaceTool.new()
	var rail_st := SurfaceTool.new()
	var ramp_st := SurfaceTool.new()
	for st in [road_st, bridge_st, ice_st, shoulder_st, skirt_st, wall_st, rail_st, ramp_st]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slab := floating or elevated
	for i in n:
		var j := wrap_i(i + 1)
		if gap[i] == 1 or gap[j] == 1:
			continue
		var a := pts[i]
		var b := pts[j]
		var ra := rightv[i]
		var rb := rightv[j]
		var ya := ramp_h[i]
		var yb := ramp_h[j]
		var va := i * ds / 10.0
		var vb := (i + 1) * ds / 10.0
		var st: SurfaceTool = road_st
		if surf[i] == Surf.BRIDGE:
			st = bridge_st
		elif surf[i] == Surf.ICE:
			st = ice_st
		# 路面
		_quad(st, a - ra * hw, a + ra * hw, b + rb * hw, b - rb * hw, Vector2(0, va), Vector2(1, va), Vector2(1, vb), Vector2(0, vb))
		# ジャンプ台
		if ya > 0.0 or yb > 0.0:
			var up_a := Vector3(0, ya, 0)
			var up_b := Vector3(0, yb, 0)
			_quad(ramp_st, a - ra * hw + up_a + Vector3(0, 0.03, 0), a + ra * hw + up_a + Vector3(0, 0.03, 0), b + rb * hw + up_b + Vector3(0, 0.03, 0), b - rb * hw + up_b + Vector3(0, 0.03, 0),
				Vector2(0, va * 4), Vector2(1, va * 4), Vector2(1, vb * 4), Vector2(0, vb * 4))
			if ramp_launch[j] > 0.0 or yb > 0.0 and ramp_h[wrap_i(j + 1)] == 0.0:
				_quad(ramp_st, b - rb * hw + up_b, b + rb * hw + up_b, b + rb * hw, b - rb * hw, Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.3), Vector2(0, 0.3))
		# 浮かぶ道の裏側
		if slab:
			var dn := Vector3(0, -1.8, 0)
			_quad(skirt_st, a + ra * hw + dn, a - ra * hw + dn, b - rb * hw + dn, b + rb * hw + dn, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
		# 穴の手前と奥の断面
		if slab or base_y < a.y - 0.3:
			var depth_y := -1.8 if slab else base_y - a.y - 0.5
			if gap[wrap_i(i - 1)] == 1:
				_quad(skirt_st, a - ra * hw, a + ra * hw, a + ra * hw + Vector3(0, depth_y, 0), a - ra * hw + Vector3(0, depth_y, 0), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
			if gap[wrap_i(j + 1)] == 1:
				_quad(skirt_st, b + rb * hw, b - rb * hw, b - rb * hw + Vector3(0, depth_y, 0), b + rb * hw + Vector3(0, depth_y, 0), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
		# 路肩・壁
		var e := edge[i]
		for side: float in [-1.0, 1.0]:
			var ia := a + ra * hw * side
			var ib := b + rb * hw * side
			if e == Edge.SHOULDER and edge[j] == Edge.SHOULDER:
				var oa := a + ra * (hw + shoulder) * side
				var ob := b + rb * (hw + shoulder) * side
				var lo := Vector3(0, -0.02, 0)
				_quad(shoulder_st, ia + lo, oa + lo, ob + lo, ib + lo, Vector2(0, va), Vector2(1, va), Vector2(1, vb), Vector2(0, vb))
				var wh := Vector3(0, 1.1, 0)
				_quad(wall_st, oa, ob, ob + wh, oa + wh, Vector2(va, 0), Vector2(vb, 0), Vector2(vb, 1), Vector2(va, 1))
				var ra2 := ra * 0.9 * side
				var rb2 := rb * 0.9 * side
				_quad(wall_st, oa + wh, ob + wh, ob + wh + rb2, oa + wh + ra2, Vector2(va, 1), Vector2(vb, 1), Vector2(vb, 1), Vector2(va, 1))
				_quad(wall_st, oa + ra2 + wh, ob + rb2 + wh, ob + rb2, oa + ra2, Vector2(va, 1), Vector2(vb, 1), Vector2(vb, 0), Vector2(va, 0))
				if base_y < a.y - 0.5:
					_quad(skirt_st, oa + ra2, ob + rb2, Vector3(ob.x, base_y - 0.5, ob.z) + rb2, Vector3(oa.x, base_y - 0.5, oa.z) + ra2, Vector2(va, 0), Vector2(vb, 0), Vector2(vb, 1), Vector2(va, 1))
			else:
				if e == Edge.RAIL:
					var rh := Vector3(0, 0.95, 0)
					var ka := ia + ra * 0.25 * side
					var kb := ib + rb * 0.25 * side
					_quad(rail_st, ka, kb, kb + rh, ka + rh, Vector2(va * 2, 0), Vector2(vb * 2, 0), Vector2(vb * 2, 1), Vector2(va * 2, 1))
				if slab:
					var dn := Vector3(0, -1.8, 0)
					_quad(skirt_st, ia, ib, ib + dn, ia + dn, Vector2(va, 0), Vector2(vb, 0), Vector2(vb, 1), Vector2(va, 1))
				elif base_y < a.y - 0.3 and tunnel[i] == 0:
					_quad(skirt_st, ia, ib, Vector3(ib.x, base_y - 0.5, ib.z), Vector3(ia.x, base_y - 0.5, ia.z), Vector2(va, 0), Vector2(vb, 0), Vector2(vb, 1), Vector2(va, 1))
		# 橋の下面
		if surf[i] == Surf.BRIDGE and not slab:
			var dn := Vector3(0, -0.6, 0)
			_quad(skirt_st, a - ra * hw + dn, a + ra * hw + dn, b + rb * hw + dn, b - rb * hw + dn, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
			for side: float in [-1.0, 1.0]:
				_quad(skirt_st, a + ra * hw * side, b + rb * hw * side, b + rb * hw * side + dn, a + ra * hw * side + dn, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	_commit(road_st, _road_material(), "Road")
	_commit(bridge_st, _bridge_material(), "BridgeDeck")
	var ice_mat := _ice_material()
	ice_mat.uv1_scale = Vector3(1, 2, 1)
	_commit(ice_st, ice_mat, "Ice")
	_commit(shoulder_st, _shoulder_material(), "Shoulder")
	_commit(wall_st, _wall_material(), "Walls")
	_commit(rail_st, _rail_material(), "Rails")
	var skirt_mat := _tex_mat(_noise_img(32, 32, th.skirt, 0.05, 31), 0.9)
	if theme_id == "space":
		skirt_mat.emission_enabled = true
		skirt_mat.emission = Color(0.3, 0.1, 0.6)
		skirt_mat.emission_energy_multiplier = 0.4
	_commit(skirt_st, skirt_mat, "Skirt")
	# ジャンプ台（黄色と橙のしましま）
	var jimg := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var arrow := absi(x - 16) < 12 and (y % 16) > absi(x - 16) * 0.6 and (y % 16) < absi(x - 16) * 0.6 + 5
			jimg.set_pixel(x, y, Color(1, 1, 1) if arrow else (Color(1, 0.55, 0.05) if (y / 4) % 2 == 0 else Color(1, 0.8, 0.1)))
	var jm := _tex_mat(jimg, 0.6)
	jm.emission_enabled = true
	jm.emission = Color(1, 0.6, 0.1)
	jm.emission_energy_multiplier = 0.25
	_commit(ramp_st, jm, "Ramps")
	if course.has("bridge"):
		_build_bridge_pillars()
	_build_tunnels()


func _commit(st: SurfaceTool, m: Material, nm: String) -> void:
	st.generate_normals()
	var mesh := st.commit()
	if mesh.get_surface_count() == 0:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.name = nm
	if nm in ["Road", "Shoulder", "Skirt", "Ice", "BridgeDeck"]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	st.set_uv(ua); st.add_vertex(a)
	st.set_uv(uc); st.add_vertex(c)
	st.set_uv(ub); st.add_vertex(b)
	st.set_uv(ua); st.add_vertex(a)
	st.set_uv(ud); st.add_vertex(d)
	st.set_uv(uc); st.add_vertex(c)


func _build_bridge_pillars() -> void:
	var idxs := []
	for i in n:
		if surf[i] == Surf.BRIDGE:
			idxs.append(i)
	for k in range(0, idxs.size(), 5):
		var i: int = idxs[k]
		for side: float in [-1.0, 1.0]:
			var p := pts[i] + rightv[i] * (hw - 1.0) * side
			var h := p.y - base_y + 1.0
			Models.cyl(self, 0.4, 0.45, h, Color(0.5, 0.33, 0.18), Vector3(p.x, base_y + h * 0.5 - 1.0, p.z))


func _build_tunnels() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 12
	var rw := hw + 1.5
	var rh := 8.0
	var any := false
	var deco_xf := []
	for i in n:
		var j := wrap_i(i + 1)
		if tunnel[i] == 0 or tunnel[j] == 0:
			continue
		any = true
		for s in segs:
			var a0 := PI * s / segs
			var a1 := PI * (s + 1) / segs
			var pa0 := pts[i] + rightv[i] * cos(a0) * rw + Vector3(0, sin(a0) * rh, 0)
			var pa1 := pts[i] + rightv[i] * cos(a1) * rw + Vector3(0, sin(a1) * rh, 0)
			var pb0 := pts[j] + rightv[j] * cos(a0) * rw + Vector3(0, sin(a0) * rh, 0)
			var pb1 := pts[j] + rightv[j] * cos(a1) * rw + Vector3(0, sin(a1) * rh, 0)
			_quad(st, pa0, pa1, pb1, pb0, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
		if i % 4 == 0:
			var fwd := Vector3(tang[i].x, 0, tang[i].z).normalized()
			if theme_id in ["night"]:
				# 天井のライン照明
				deco_xf.append(Transform3D(Basis.looking_at(fwd, Vector3.UP), pts[i] + Vector3(0, rh - 0.4, 0)))
			elif theme_id == "desert":
				# 壁のたいまつ
				var side := 1.0 if (i / 4) % 2 == 0 else -1.0
				deco_xf.append(Transform3D(Basis(), pts[i] + rightv[i] * (rw - 0.6) * side + Vector3(0, 3.0, 0)))
			else:
				var side := 1.0 if (i / 4) % 2 == 0 else -1.0
				var ang := 0.35 + fmod(i * 0.37, 0.9)
				var cp := pts[i] + rightv[i] * cos(ang) * rw * side * 0.95 + Vector3(0, sin(ang) * rh * 0.95, 0)
				deco_xf.append(Transform3D(Basis.from_euler(Vector3(fmod(i * 0.7, 0.8), fmod(i * 1.3, 3.0), fmod(i * 0.3, 0.8))), cp))
	if not any:
		return
	var tcol: Color = th.get("tunnel", Color(0.35, 0.38, 0.5))
	var m := _tex_mat(_noise_img(32, 32, tcol, 0.08, 41), 0.95)
	m.uv1_scale = Vector3(3, 3, 1)
	_commit(st, m, "Cave")
	if theme_id == "night":
		_mm(_box_mesh(Vector3(0.6, 0.15, 6.0)), unshaded(Color(1, 0.95, 0.8)), deco_xf)
	elif theme_id == "desert":
		_mm(_sphere_mesh(0.3, 6), Models.mat(Color(1, 0.6, 0.15), 0.5, 0.0, 3.0), deco_xf)
	else:
		_mm(_cyl_mesh(0.0, 0.45, 1.6, 6), Models.mat(Color(0.55, 0.9, 1.0), 0.1, 0.0, 1.8), deco_xf)
	# 入口の飾り
	for r in course.tunnels:
		for k in 2:
			var i := idx_of(r[k])
			if theme_id == "snow":
				var s := Models.sphere(self, 1.0, Color(0.93, 0.95, 1.0), pts[i] + Vector3(0, 6.0, 0), Vector3(rw * 1.3, 4.0, 3.0), 10)
				s.material_override = Models.mat(Color(0.93, 0.95, 1.0), 0.8)
			else:
				var fwd := Vector3(tang[i].x, 0, tang[i].z).normalized()
				var gate := Node3D.new()
				gate.position = pts[i]
				gate.basis = Basis.looking_at(fwd, Vector3.UP)
				add_child(gate)
				var col: Color = tcol.lightened(0.15)
				for side: float in [-1.0, 1.0]:
					Models.box(gate, Vector3(2.2, 10.0, 2.2), col, Vector3(side * (rw + 1.0), 5.0, 0))
				Models.box(gate, Vector3(rw * 2.0 + 4.4, 2.4, 2.4), col, Vector3(0, 9.2, 0))


func _build_dash_panels() -> void:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var yy := (y + 32 - absi(x - 16)) % 16
			img.set_pixel(x, y, Color(1, 1, 1) if yy < 5 else Color(0.1, 0.7, 1.0))
	var m := _tex_mat(img, 0.3)
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission_energy_multiplier = 1.2
	m.uv1_scale = Vector3(1, 2, 1)
	_anim_mats.append([m, Vector2(0, -1.2)])
	for dp in course.get("dash", []):
		var c := idx_of(dp[0])
		var i := wrap_i(c + 1)
		var fwd := Vector3(tang[i].x, 0, tang[i].z).normalized()
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(DASH_HALF_W * 2.0, 6.5)
		mi.mesh = pm
		mi.material_override = m
		mi.position = pts[i] + rightv[i] * float(dp[1]) + Vector3(0, 0.05, 0)
		mi.basis = Basis.looking_at(fwd, Vector3.UP)
		add_child(mi)


func _build_start_gate() -> void:
	start_index = 0
	var p := pts[0]
	var t := Vector3(tang[0].x, 0, tang[0].z).normalized()
	var line := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(hw * 2.0, 2.4)
	line.mesh = pm
	var img := Image.create(16, 2, false, Image.FORMAT_RGBA8)
	for y in 2:
		for x in 16:
			img.set_pixel(x, y, Color.WHITE if (x + y) % 2 == 0 else Color(0.05, 0.05, 0.05))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	line.material_override = m
	line.position = p + Vector3(0, 0.04, 0)
	line.basis = Basis.looking_at(t, Vector3.UP)
	add_child(line)
	var gate := Node3D.new()
	gate.position = p
	gate.basis = Basis.looking_at(t, Vector3.UP)
	add_child(gate)
	var gw := hw + 1.5
	for side: float in [-1.0, 1.0]:
		Models.cyl(gate, 0.35, 0.35, 7.0, Color(0.95, 0.95, 1.0), Vector3(side * gw, 3.5, 0))
	Models.box(gate, Vector3(gw * 2.0 + 1.0, 1.8, 0.5), Color(0.15, 0.4, 1.0), Vector3(0, 7.2, 0))
	for k in 2:
		var lbl := Label3D.new()
		lbl.text = "わくわくGP  START / GOAL"
		lbl.font_size = 64
		lbl.pixel_size = 0.018
		lbl.outline_size = 10
		lbl.modulate = Color(1, 0.95, 0.3)
		lbl.position = Vector3(0, 7.2, 0.3 if k == 0 else -0.3)
		lbl.rotation.y = 0.0 if k == 0 else PI
		gate.add_child(lbl)
	var cols := [Color(1, 0.3, 0.3), Color(1, 0.85, 0.2), Color(0.3, 0.8, 0.4), Color(0.3, 0.6, 1.0)]
	for k in 8:
		var x := -gw + (gw * 2.0) * (k + 0.5) / 8.0
		Models.cyl(gate, 0.0, 0.45, 0.9, cols[k % 4], Vector3(x, 5.8, 0), Vector3(PI, 0, 0), 3)


# ------------------------------------------------------------------ 飾り（テーマごと）
func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var fn := "_decor_" + theme_id
	if has_method(fn):
		call(fn, rng)


func _decor_grass(rng: RandomNumberGenerator) -> void:
	var pond: Array = course.pond
	var trees := _scatter(rng, 110, hw + shoulder + 5.0, 90)
	trees = trees.filter(func(p): return Vector2(p.x - pond[0], p.z - pond[1]).length() > pond[2] + 4)
	_round_trees(trees, rng, Color(0.2, 0.62, 0.25), Color(0.3, 0.75, 0.3))
	_flowers(rng, [Vector3(pond[0], 0, pond[1])], pond[2] + 1)
	_water_disc(Vector3(pond[0], base_y + 0.06, pond[1]), pond[2])
	for k in 10:
		var a := k * TAU / 10.0
		Models.sphere(self, rng.randf_range(1.2, 2.2), Color(0.6, 0.6, 0.62), Vector3(pond[0], base_y + 0.06, pond[1]) + Vector3(cos(a), 0, sin(a)) * (pond[2] + 0.5), Vector3(1, 0.6, 1), 8)
	_hills(rng, Color(0.3, 0.62, 0.3))
	_clouds(rng)


func _decor_snow(rng: RandomNumberGenerator) -> void:
	_pine_trees(_scatter(rng, 70, hw + shoulder + 5.0, 90), rng)
	for k in 10:
		var a := k * TAU / 10.0
		var c := _center() + Vector3(cos(a), 0, sin(a)) * rng.randf_range(350, 450)
		var h := rng.randf_range(120, 200)
		var mtn := Models.cyl(self, 0.0, h * 0.8, h, Color(0.55, 0.6, 0.75), c + Vector3(0, h * 0.5, 0), Vector3.ZERO, 7)
		Models.cyl(mtn, 0.0, h * 0.8 * 0.4, h * 0.4, Color(0.97, 0.98, 1.0), Vector3(0, h * 0.3 + 0.5, 0), Vector3.ZERO, 7)
	for k in 6:
		var i := (k * n / 6 + 7) % n
		if edge[i] != Edge.SHOULDER:
			continue
		var p := pts[i] + rightv[i] * (hw + shoulder + 3.0) * (1 if k % 2 == 0 else -1)
		var sm := Node3D.new()
		sm.position = p
		add_child(sm)
		Models.sphere(sm, 1.2, Color(1, 1, 1), Vector3(0, 1.1, 0))
		Models.sphere(sm, 0.8, Color(1, 1, 1), Vector3(0, 2.7, 0))
		Models.cyl(sm, 0.0, 0.15, 0.6, Color(1, 0.5, 0.1), Vector3(0, 2.7, -0.9), Vector3(-PI / 2, 0, 0), 8)
		Models.cyl(sm, 0.5, 0.5, 0.6, Color(0.1, 0.1, 0.15), Vector3(0, 3.6, 0))
	_clouds(rng)


func _decor_volcano(rng: RandomNumberGenerator) -> void:
	var vp := Vector3(course.volcano[0], base_y, course.volcano[1])
	var cone := Models.cyl(self, 14.0, 48.0, 55.0, Color(0.3, 0.18, 0.14), vp + Vector3(0, 27.5, 0), Vector3.ZERO, 14)
	cone.name = "Volcano"
	var crater := Models.cyl(self, 12.0, 12.0, 1.0, Color(1, 0.4, 0.05), vp + Vector3(0, 55.2, 0), Vector3.ZERO, 14)
	crater.material_override = Models.mat(Color(1, 0.45, 0.05), 0.5, 0.0, 3.0)
	for k in 5:
		var a := k * TAU / 5.0
		var flow := Models.box(self, Vector3(3, 0.5, 30), Color(1, 0.4, 0.05), vp + Vector3(cos(a) * 22, 38, sin(a) * 22), Vector3(0, -a + PI / 2, 0))
		flow.look_at_from_position(vp + Vector3(cos(a) * 24, 36, sin(a) * 24), vp + Vector3(cos(a) * 60, base_y, sin(a) * 60))
		flow.material_override = Models.mat(Color(1, 0.45, 0.05), 0.5, 0.0, 2.2)
	var smoke := _particles_box(vp + Vector3(0, 57, 0), Vector3(2, 1, 2), 40, 6.0, Color(0.25, 0.22, 0.22, 0.6), 0.5, Vector3(1.0, 0.5, 0), 6.0, 10.0)
	smoke.scale_amount_min = 6.0
	smoke.scale_amount_max = 12.0
	var rocks := []
	for p in _scatter(rng, 50, hw + 6.0, 60):
		rocks.append(Transform3D(Basis().scaled(Vector3(1, rng.randf_range(0.5, 1.4), 1) * rng.randf_range(2.0, 6.0)), p))
	_mm(_sphere_mesh(1.0, 7), Models.mat(Color(0.22, 0.17, 0.15)), rocks)
	for k in 9:
		var a := k * TAU / 9.0
		var c := _center() + Vector3(cos(a), 0, sin(a)) * rng.randf_range(330, 420)
		var h := rng.randf_range(80, 150)
		Models.cyl(self, 6.0, h * 0.9, h, Color(0.2, 0.12, 0.1), c + Vector3(0, h * 0.5, 0), Vector3.ZERO, 8)
	var cc := _center()
	_particles_box(cc + Vector3(0, 1, 0), Vector3(bbox.size.x * 0.6, 1, bbox.size.y * 0.6), 60, 4.0, Color(1, 0.6, 0.1), 0.15, Vector3(0, 0.5, 0), 2.0, 5.0, 3.0)


func _decor_fruit(rng: RandomNumberGenerator) -> void:
	var trees := _scatter(rng, 120, hw + shoulder + 5.0, 90)
	var scales := _round_trees(trees, rng, Color(0.22, 0.6, 0.25), Color(0.35, 0.75, 0.3))
	# 木になっている果物
	var red := []
	var orange := []
	for k in trees.size():
		var s: float = scales[k]
		var top: Vector3 = trees[k] + Vector3(0, 5.0 * s, 0)
		for q in 6:
			var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.8), rng.randf_range(-1, 1)).normalized()
			var p := top + Vector3(v.x * 2.6, v.y * 2.4, v.z * 2.6) * s * 0.95
			(red if k % 2 == 0 else orange).append(Transform3D(Basis().scaled(Vector3.ONE * s), p))
	_mm(_sphere_mesh(0.4, 8), Models.mat(Color(0.95, 0.15, 0.15), 0.35), red)
	_mm(_sphere_mesh(0.4, 8), Models.mat(Color(1.0, 0.6, 0.1), 0.45), orange)
	# 大きなフルーツ
	for k in 12:
		var d := length * (k + 0.5) / 12.0
		var side := 1.0 if k % 2 == 0 else -1.0
		var i := idx_of(d)
		if edge[i] != Edge.SHOULDER:
			continue
		var p := _roadside(d, side, shoulder + rng.randf_range(7.0, 12.0))
		p.y = base_y
		_giant_fruit(k % 4, p, rng)
	_flowers(rng, [], 0.0)
	_hills(rng, Color(0.45, 0.75, 0.35))
	_clouds(rng)


func _giant_fruit(kind: int, p: Vector3, rng: RandomNumberGenerator) -> void:
	var node := Node3D.new()
	node.position = p
	node.rotation.y = rng.randf() * TAU
	add_child(node)
	var s := rng.randf_range(0.9, 1.3)
	node.scale = Vector3.ONE * s
	match kind:
		0:  # りんご
			Models.sphere(node, 3.5, Color(0.9, 0.1, 0.12), Vector3(0, 3.3, 0), Vector3(1, 0.92, 1), 16)
			Models.cyl(node, 0.2, 0.25, 1.6, Color(0.4, 0.25, 0.1), Vector3(0, 7.0, 0))
			Models.sphere(node, 1.0, Color(0.3, 0.7, 0.2), Vector3(0.9, 7.2, 0), Vector3(1.4, 0.2, 0.7), 8)
		1:  # オレンジ
			Models.sphere(node, 3.3, Color(1.0, 0.55, 0.05), Vector3(0, 3.2, 0), Vector3.ONE, 16)
			Models.sphere(node, 0.9, Color(0.25, 0.6, 0.2), Vector3(0.6, 6.4, 0), Vector3(1.4, 0.25, 0.8), 8)
		2:  # ぶどう
			var r := 1.05
			for layer in 4:
				var cnt := 5 - layer
				for q in cnt:
					var a := q * TAU / cnt + layer
					Models.sphere(node, r, Color(0.5, 0.2, 0.7), Vector3(cos(a) * (cnt - 1) * 0.55, 7.5 - layer * 1.6, sin(a) * (cnt - 1) * 0.55), Vector3.ONE, 10)
			Models.cyl(node, 0.15, 0.2, 1.6, Color(0.4, 0.3, 0.1), Vector3(0, 9.2, 0))
			Models.cyl(node, 0.2, 0.25, 3.5, Color(0.45, 0.35, 0.2), Vector3(0, 1.7, 0))
		3:  # いちご
			Models.sphere(node, 3.0, Color(0.95, 0.12, 0.25), Vector3(0, 3.0, 0), Vector3(1, 1.2, 1), 14)
			for q in 6:
				var a := q * TAU / 6.0
				Models.sphere(node, 1.0, Color(0.2, 0.65, 0.2), Vector3(cos(a) * 1.0, 6.4, sin(a) * 1.0), Vector3(1.5, 0.25, 0.6), 6).rotation.y = -a
			for q in 14:
				var a := q * 2.4
				var yy := 1.5 + fmod(q * 0.37, 1.0) * 3.0
				var rr := 3.0 * sin(acos(clampf((yy - 3.0) / 3.6, -1, 1))) + 0.02
				Models.sphere(node, 0.15, Color(1, 0.9, 0.4), Vector3(cos(a) * rr, yy, sin(a) * rr), Vector3.ONE, 4)


func _decor_beach(rng: RandomNumberGenerator) -> void:
	# 橋の下の入り江
	if course.has("bridge"):
		var rr := _range(course.bridge)
		var mid: Vector3 = pts[rr[rr.size() / 2]]
		_water_disc(Vector3(mid.x, base_y + 0.08, mid.z), 26.0, Color(0.15, 0.65, 0.95, 0.9))
	# ヤシの木
	var palms := _scatter(rng, 70, hw + shoulder + 4.0, 40)
	var trunk := []
	var leaves := []
	var nuts := []
	for p in palms:
		var dir := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		var bend := rng.randf_range(0.08, 0.2)
		var h := 0.0
		var top := p
		for k in 6:
			var off := dir * bend * k * k
			var pos := p + off + Vector3(0, k * 1.5 + 0.75, 0)
			trunk.append(Transform3D(Basis(Vector3.UP.cross(dir).normalized(), bend * k * 0.5), pos))
			top = pos
			h += 1.5
		top += Vector3(0, 0.8, 0)
		for q in 7:
			var a := q * TAU / 7.0 + rng.randf()
			var ld := Vector3(cos(a), 0, sin(a))
			var b := Basis.looking_at(ld, Vector3.UP).rotated(ld.cross(Vector3.UP).normalized(), -0.45)
			leaves.append(Transform3D(b, top + ld * 1.8 + Vector3(0, -0.4, 0)))
		for q in 3:
			var a := q * TAU / 3.0
			nuts.append(Transform3D(Basis(), top + Vector3(cos(a) * 0.45, -0.5, sin(a) * 0.45)))
	_mm(_cyl_mesh(0.3, 0.38, 1.6, 7), Models.mat(Color(0.6, 0.45, 0.28)), trunk)
	_mm(_box_mesh(Vector3(0.9, 0.08, 4.0)), Models.mat(Color(0.2, 0.65, 0.25)), leaves)
	_mm(_sphere_mesh(0.28, 6), Models.mat(Color(0.4, 0.28, 0.12)), nuts)
	# パラソル・ビーチボール
	var cols := [Color(1, 0.3, 0.3), Color(0.2, 0.6, 1.0), Color(1, 0.85, 0.2), Color(0.3, 0.8, 0.4)]
	for k in 16:
		var d := length * (k + 0.3) / 16.0
		var i := idx_of(d)
		if edge[i] != Edge.SHOULDER:
			continue
		var side := 1.0 if k % 2 == 0 else -1.0
		var p := _roadside(d, side, shoulder + rng.randf_range(4.0, 9.0))
		p.y = base_y
		Models.cyl(self, 0.08, 0.08, 3.2, Color(0.95, 0.95, 0.95), p + Vector3(0, 1.6, 0))
		Models.cyl(self, 0.0, 2.2, 0.9, cols[k % 4], p + Vector3(0, 3.3, 0), Vector3.ZERO, 12)
		Models.box(self, Vector3(1.2, 0.05, 2.2), cols[(k + 1) % 4], p + Vector3(1.6, 0.05, 0.5))
		if k % 3 == 0:
			Models.sphere(self, 0.6, cols[(k + 2) % 4], p + Vector3(-1.5, 0.6, 1.0), Vector3.ONE, 10)
	# 灯台
	var lp := Vector3(bbox.end.x + 45, base_y, bbox.position.y - 20)
	for k in 6:
		Models.cyl(self, 3.0 - k * 0.2, 3.2 - k * 0.2, 4.0, Color(1, 1, 1) if k % 2 == 0 else Color(0.9, 0.15, 0.15), lp + Vector3(0, 2.0 + k * 4.0, 0), Vector3.ZERO, 14)
	var light := Models.sphere(self, 1.6, Color(1, 0.95, 0.6), lp + Vector3(0, 26.0, 0))
	light.material_override = Models.mat(Color(1, 0.95, 0.6), 0.3, 0.0, 2.5)
	Models.cyl(self, 0.0, 2.6, 2.0, Color(0.9, 0.15, 0.15), lp + Vector3(0, 28.5, 0), Vector3.ZERO, 12)
	_clouds(rng)


func _decor_rainbow(rng: RandomNumberGenerator) -> void:
	# 下に広がるパステルの雲
	var puffs := []
	for p in _scatter(rng, 90, 0.0, 200, miny - 35.0):
		puffs.append(Transform3D(Basis().scaled(Vector3(rng.randf_range(12, 26), rng.randf_range(5, 9), rng.randf_range(12, 26))), p))
	_mm(_sphere_mesh(1.0, 10), Models.mat(Color(1.0, 0.9, 0.97), 1.0, 0.0, 0.35), puffs)
	# 虹のアーチ
	_rainbow_arches([60.0, 420.0, 700.0, 1080.0], hw + 3.0)
	# 星と風船
	for p in _scatter(rng, 26, hw + 10.0, 60, maxy + 10.0, 80.0):
		var st := Models._star_mesh(2.2, Color(1, 0.9, 0.3))
		st.position = p + Vector3(0, rng.randf_range(-15, 15), 0)
		st.rotation.y = rng.randf() * TAU
		add_child(st)
	var cols := [Color(1, 0.4, 0.5), Color(0.4, 0.7, 1), Color(1, 0.9, 0.3), Color(0.6, 0.9, 0.5), Color(0.8, 0.55, 1)]
	var balloons := []
	for p in _scatter(rng, 40, hw + 6.0, 40, 0.0, 45.0):
		var i := nearest_index_xz(p.x, p.z)
		balloons.append(Transform3D(Basis(), Vector3(p.x, pts[i].y + rng.randf_range(4, 16), p.z)))
	for c in 5:
		var sub := []
		for k in range(c, balloons.size(), 5):
			sub.append(balloons[k])
		_mm(_sphere_mesh(1.2, 10), Models.mat(cols[c], 0.3), sub)


func _rainbow_arches(ds_list: Array, radius: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := [Color(1, 0.3, 0.35), Color(1, 0.6, 0.25), Color(1, 0.92, 0.3), Color(0.4, 0.9, 0.4), Color(0.3, 0.7, 1.0), Color(0.45, 0.45, 1.0), Color(0.75, 0.45, 1.0)]
	for d in ds_list:
		var c := point_at(d, 0.0)
		var r := rightv[idx_of(d)]
		for b in 7:
			var r0 := radius + (6 - b) * 0.7
			var r1 := r0 + 0.7
			st.set_color(cols[b])
			for s in 24:
				var a0 := PI * s / 24.0
				var a1 := PI * (s + 1) / 24.0
				var p00 := c + r * cos(a0) * r0 + Vector3(0, sin(a0) * r0, 0)
				var p01 := c + r * cos(a1) * r0 + Vector3(0, sin(a1) * r0, 0)
				var p10 := c + r * cos(a0) * r1 + Vector3(0, sin(a0) * r1, 0)
				var p11 := c + r * cos(a1) * r1 + Vector3(0, sin(a1) * r1, 0)
				for v in [p00, p10, p11, p00, p11, p01]:
					st.set_color(cols[b])
					st.add_vertex(v)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)


func _decor_jungle(rng: RandomNumberGenerator) -> void:
	# 川
	for rv in course.get("rivers", []):
		var i := idx_of(rv[0])
		var c := pts[i]
		var fwd := Vector3(tang[i].x, 0, tang[i].z).normalized()
		var w := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(rv[1], rv[2])
		w.mesh = pm
		var wm := _water_mat(Color(0.2, 0.55, 0.45, 0.92))
		w.material_override = wm
		w.position = Vector3(c.x, base_y + 0.15, c.z)
		w.basis = Basis.looking_at(fwd, Vector3.UP)
		add_child(w)
	# 大きな木
	var trees := _scatter(rng, 170, hw + shoulder + 4.0, 90)
	var trunks := []
	var can1 := []
	var can2 := []
	for p in trees:
		var s := rng.randf_range(0.9, 1.6)
		trunks.append(Transform3D(Basis().scaled(Vector3(s, s, s)), p + Vector3(0, 5.0 * s, 0)))
		can1.append(Transform3D(Basis().scaled(Vector3(1.6, 0.6, 1.6) * s), p + Vector3(0, 10.0 * s, 0)))
		can2.append(Transform3D(Basis().scaled(Vector3(1.1, 0.5, 1.1) * s), p + Vector3(rng.randf_range(-1, 1), 11.8 * s, rng.randf_range(-1, 1))))
	_mm(_cyl_mesh(0.5, 0.8, 10.0, 7), Models.mat(Color(0.4, 0.28, 0.18)), trunks)
	_mm(_sphere_mesh(4.0, 10), Models.mat(Color(0.1, 0.4, 0.15)), can1)
	_mm(_sphere_mesh(4.0, 10), Models.mat(Color(0.2, 0.55, 0.2)), can2)
	# 大きな葉っぱの草むら
	var bushes := []
	for p in _scatter(rng, 160, hw + shoulder + 1.5, 20, INF, hw + shoulder + 14.0):
		var s := rng.randf_range(1.0, 2.2)
		bushes.append(Transform3D(Basis().scaled(Vector3(1.4, 0.7, 1.4) * s), p + Vector3(0, 0.6 * s, 0)))
	_mm(_sphere_mesh(1.5, 8), Models.mat(Color(0.3, 0.65, 0.2)), bushes)
	var rocks := []
	for p in _scatter(rng, 40, hw + shoulder + 3.0, 60):
		rocks.append(Transform3D(Basis().scaled(Vector3(1, 0.7, 1) * rng.randf_range(1.5, 3.5)), p))
	_mm(_sphere_mesh(1.0, 7), Models.mat(Color(0.4, 0.45, 0.35)), rocks)
	_hills(rng, Color(0.15, 0.4, 0.18))


func _decor_desert(rng: RandomNumberGenerator) -> void:
	# 砂丘
	var dunes := []
	for p in _scatter(rng, 40, hw + shoulder + 25.0, 200):
		dunes.append(Transform3D(Basis().scaled(Vector3(rng.randf_range(20, 45), rng.randf_range(4, 12), rng.randf_range(20, 45))), p))
	_mm(_sphere_mesh(1.0, 12), Models.mat(Color(0.95, 0.8, 0.52)), dunes)
	# サボテン
	var body := []
	var arms := []
	for p in _scatter(rng, 60, hw + shoulder + 4.0, 80):
		var s := rng.randf_range(0.8, 1.4)
		body.append(Transform3D(Basis().scaled(Vector3.ONE * s), p + Vector3(0, 2.2 * s, 0)))
		for side: float in [-1.0, 1.0]:
			if rng.randf() < 0.7:
				arms.append(Transform3D(Basis().scaled(Vector3.ONE * s * 0.6), p + Vector3(side * 1.0 * s, rng.randf_range(2.0, 3.2) * s, 0)))
	_mm(_capsule_mesh(0.55, 4.4), Models.mat(Color(0.25, 0.6, 0.3)), body)
	_mm(_capsule_mesh(0.55, 2.8), Models.mat(Color(0.3, 0.65, 0.32)), arms)
	# 遺跡の柱
	var cols := []
	var broken := []
	for k in 30:
		var d := length * (k + 0.2) / 30.0
		var i := idx_of(d)
		if tunnel[i] == 1:
			continue
		var side := 1.0 if k % 2 == 0 else -1.0
		var p := _roadside(d, side, shoulder + rng.randf_range(4.0, 8.0))
		p.y = base_y
		if rng.randf() < 0.6:
			var h := rng.randf_range(6, 10)
			cols.append(Transform3D(Basis().scaled(Vector3(1, h / 8.0, 1)), p + Vector3(0, h * 0.5, 0)))
		else:
			broken.append(Transform3D(Basis(Vector3(0, 0, 1), PI / 2).rotated(Vector3.UP, rng.randf() * TAU), p + Vector3(0, 0.9, 0)))
	var stone := Models.mat(Color(0.85, 0.75, 0.55))
	_mm(_cyl_mesh(0.9, 1.0, 8.0, 10), stone, cols)
	_mm(_cyl_mesh(0.9, 0.9, 4.0, 10), stone, broken)
	# 神殿（トンネルの上）
	for r in course.get("tunnels", []):
		var rr := _range(r)
		for k in range(0, rr.size(), 3):
			var i: int = rr[k]
			var fwd := Vector3(tang[i].x, 0, tang[i].z).normalized()
			for layer in 3:
				var w := (hw + 6.0) * 2.0 - layer * 7.0
				var b := Models.box(self, Vector3(w, 4.5, 8.0), Color(0.82, 0.68, 0.45).darkened(layer * 0.05), pts[i] + Vector3(0, 8.5 + layer * 4.5, 0))
				b.basis = Basis.looking_at(fwd, Vector3.UP)
	# 石のアーチ
	for d in course.get("arches", []):
		var i := idx_of(d)
		var fwd := Vector3(tang[i].x, 0, tang[i].z).normalized()
		var g := Node3D.new()
		g.position = pts[i]
		g.basis = Basis.looking_at(fwd, Vector3.UP)
		add_child(g)
		for side: float in [-1.0, 1.0]:
			Models.box(g, Vector3(2.4, 9.0, 2.4), Color(0.8, 0.66, 0.45), Vector3(side * (hw + shoulder * 0.5 + 1.5), 4.5, 0))
		Models.box(g, Vector3((hw + shoulder * 0.5 + 1.5) * 2.0 + 3.0, 2.2, 3.0), Color(0.75, 0.6, 0.4), Vector3(0, 10.0, 0))
	# 遠くのピラミッド
	for k in 3:
		var a := 0.6 + k * 1.9
		var c := _center() + Vector3(cos(a), 0, sin(a)) * rng.randf_range(280, 340)
		var h := rng.randf_range(50, 80)
		var pyr := Models.cyl(self, 0.0, h * 1.1, h, Color(0.9, 0.76, 0.5), c + Vector3(0, h * 0.5, 0), Vector3(0, PI / 4, 0), 4)
		pyr.name = "Pyramid"


func _decor_cave(rng: RandomNumberGenerator) -> void:
	var cave_top := maxy + 26.0
	# 石筍（下）と鍾乳石（上）
	var mites := []
	for p in _scatter(rng, 140, hw + 3.0, 80):
		var h := rng.randf_range(5, 18)
		mites.append(Transform3D(Basis().scaled(Vector3(1, h, 1) * Vector3(rng.randf_range(1.2, 2.5), 1, rng.randf_range(1.2, 2.5))), p + Vector3(0, h * 0.5, 0)))
	var rockm := Models.mat(Color(0.28, 0.26, 0.32))
	_mm(_cyl_mesh(0.0, 1.0, 1.0, 7), rockm, mites)
	var tites := []
	for p in _scatter(rng, 120, 0.0, 80, cave_top):
		var h := rng.randf_range(6, 20)
		tites.append(Transform3D(Basis(Vector3.RIGHT, PI).scaled(Vector3(rng.randf_range(1.5, 3), h, rng.randf_range(1.5, 3))), p - Vector3(0, h * 0.5, 0)))
	_mm(_cyl_mesh(0.0, 1.0, 1.0, 7), rockm, tites)
	# 天井
	var ceil := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400, 1400)
	ceil.mesh = pm
	ceil.material_override = Models.mat(Color(0.1, 0.1, 0.14))
	ceil.position = Vector3(bbox.get_center().x, cave_top, bbox.get_center().y)
	ceil.rotation.x = PI
	add_child(ceil)
	# 光る結晶
	var crystal_cols := [Color(0.3, 0.9, 1.0), Color(0.8, 0.4, 1.0), Color(1.0, 0.45, 0.8)]
	var groups := [[], [], []]
	for p in _scatter(rng, 50, hw + 2.5, 50, INF, hw + 30.0):
		var gi := rng.randi() % 3
		for q in rng.randi_range(3, 5):
			var h := rng.randf_range(3.0, 9.0)
			var b := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))).scaled(Vector3(1.8, h, 1.8))
			var base := Vector3(p.x, base_y, p.z) + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
			groups[gi].append(Transform3D(b, base + Vector3(0, h * 0.4, 0)))
	for gi in 3:
		_mm(_cyl_mesh(0.0, 0.5, 1.0, 6), Models.mat(crystal_cols[gi], 0.1, 0.0, 2.2), groups[gi])
	# 光るキノコ
	var stems := []
	var caps := []
	for p in _scatter(rng, 50, hw + 4.0, 60):
		var s := rng.randf_range(0.8, 2.5)
		stems.append(Transform3D(Basis().scaled(Vector3.ONE * s), p + Vector3(0, 1.0 * s, 0)))
		caps.append(Transform3D(Basis().scaled(Vector3(1.4, 0.55, 1.4) * s), p + Vector3(0, 2.1 * s, 0)))
	_mm(_cyl_mesh(0.25, 0.35, 2.0, 6), Models.mat(Color(0.85, 0.85, 0.75)), stems)
	_mm(_sphere_mesh(1.0, 10), Models.mat(Color(0.2, 1.0, 0.7), 0.4, 0.0, 1.6), caps)
	# 地底湖
	if course.has("lake"):
		var lk: Array = course.lake
		var w := _water_disc(Vector3(lk[0], base_y + 0.2, lk[1]), lk[2], Color(0.1, 0.5, 0.9, 0.9))
		var wm: StandardMaterial3D = w.material_override
		wm.emission_enabled = true
		wm.emission = Color(0.1, 0.4, 0.9)
		wm.emission_energy_multiplier = 0.8
	# 柵の上のランタン
	var lamps := []
	for i in range(0, n, 12):
		if edge[i] != Edge.RAIL or tunnel[i] == 1:
			continue
		var side := 1.0 if (i / 12) % 2 == 0 else -1.0
		lamps.append(Transform3D(Basis(), pts[i] + rightv[i] * (hw + 0.3) * side + Vector3(0, 1.4, 0)))
	_mm(_box_mesh(Vector3(0.4, 0.55, 0.4)), Models.mat(Color(1, 0.7, 0.3), 0.5, 0.0, 3.0), lamps)
	# トロッコの線路
	if course.get("cross_kind", "") == "minecart":
		var rails := []
		var ties := []
		for d in course.cross:
			var i := idx_of(d)
			var fwd := Vector3(tang[i].x, 0, tang[i].z).normalized()
			var r := rightv[i]
			var b := Basis(r, Vector3.UP, r.cross(Vector3.UP))
			for o: float in [-0.7, 0.7]:
				rails.append(Transform3D(b.scaled(Vector3(hw * 2.0 + 16.0, 1, 1)), pts[i] + fwd * o + Vector3(0, 0.08, 0)))
			for q in range(-9, 10):
				ties.append(Transform3D(b, pts[i] + r * q * 1.2 + Vector3(0, 0.04, 0)))
		_mm(_box_mesh(Vector3(1.0, 0.12, 0.12)), Models.mat(Color(0.6, 0.6, 0.65), 0.3, 0.7), rails)
		_mm(_box_mesh(Vector3(0.3, 0.08, 2.2)), Models.mat(Color(0.4, 0.28, 0.16)), ties)
	_particles_box(_center() + Vector3(0, maxy - base_y, 0), Vector3(bbox.size.x * 0.5, 8, bbox.size.y * 0.5), 60, 6.0, Color(0.5, 0.9, 1.0), 0.12, Vector3(0, 0.3, 0), 0.2, 0.8, 2.0)


func _decor_night(rng: RandomNumberGenerator) -> void:
	# ビル（窓が光る）
	var win := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var wglow := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var is_win := x % 4 != 0 and y % 4 >= 1 and y % 4 <= 2
			var lit := is_win and ((x / 4) * 7 + (y / 4) * 3) % 5 != 0
			win.set_pixel(x, y, Color(0.12, 0.13, 0.2) if not is_win else Color(0.2, 0.22, 0.3))
			wglow.set_pixel(x, y, Color(1.0, 0.85, 0.5) if lit else Color.BLACK)
	var bm := _tex_mat(win, 0.6, true)
	bm.uv1_triplanar = true
	bm.uv1_world_triplanar = true
	bm.uv1_scale = Vector3(0.12, 0.12, 0.12)
	bm.emission_enabled = true
	wglow.generate_mipmaps()
	bm.emission_texture = ImageTexture.create_from_image(wglow)
	bm.emission_energy_multiplier = 1.6
	var bxf := []
	for p in _scatter(rng, 170, hw + 18.0, 160):
		var h := rng.randf_range(15, 70)
		var w := rng.randf_range(10, 22)
		bxf.append(Transform3D(Basis().scaled(Vector3(w, h, rng.randf_range(10, 22))), p + Vector3(0, h * 0.5, 0)))
	for k in 60:
		var a := k * TAU / 60.0
		var p := _center() + Vector3(cos(a), 0, sin(a)) * rng.randf_range(430, 560)
		var h := rng.randf_range(60, 160)
		bxf.append(Transform3D(Basis().scaled(Vector3(rng.randf_range(20, 40), h, rng.randf_range(20, 40))), p + Vector3(0, h * 0.5, 0)))
	_mm(_box_mesh(Vector3.ONE), bm, bxf)
	# 高架の柱
	var cols := []
	for i in range(0, n, 10):
		var h := pts[i].y - 1.8 - base_y
		cols.append(Transform3D(Basis().scaled(Vector3(1, h, 1)), Vector3(pts[i].x, base_y + h * 0.5, pts[i].z)))
	_mm(_cyl_mesh(1.4, 1.6, 1.0, 10), Models.mat(Color(0.5, 0.5, 0.55)), cols)
	# 街灯
	var poles := []
	var bulbs := []
	for i in range(0, n, 10):
		if tunnel[i] == 1:
			continue
		var side := 1.0 if (i / 10) % 2 == 0 else -1.0
		var p := pts[i] + rightv[i] * (hw + 0.9) * side
		poles.append(Transform3D(Basis(), p + Vector3(0, 3.8, 0)))
		bulbs.append(Transform3D(Basis(), p - rightv[i] * 1.6 * side + Vector3(0, 7.4, 0)))
	_mm(_cyl_mesh(0.12, 0.16, 7.6, 6), Models.mat(Color(0.6, 0.6, 0.65), 0.4, 0.6), poles)
	_mm(_sphere_mesh(0.45, 8), unshaded(Color(1, 0.92, 0.7)), bulbs)
	# 月
	var moon := MeshInstance3D.new()
	moon.mesh = _sphere_mesh(40.0, 20)
	moon.material_override = unshaded(Color(1, 0.97, 0.85))
	moon.position = _center() + Vector3(-400, 330, -500)
	add_child(moon)


func _decor_cloud(rng: RandomNumberGenerator) -> void:
	# 道の下の雲
	var puffs := []
	for i in range(0, n, 4):
		if gap[i] == 1:
			continue
		var s := rng.randf_range(5, 8)
		puffs.append(Transform3D(Basis().scaled(Vector3(s * 1.6, s * 0.6, s * 1.6)), pts[i] + rightv[i] * rng.randf_range(-3, 3) + Vector3(0, -2.4 - s * 0.6, 0)))
	var cm := Models.mat(Color(1, 1, 1), 1.0, 0.0, 0.3)
	_mm(_sphere_mesh(1.0, 10), cm, puffs)
	# 雲の海
	var sea := []
	for p in _scatter(rng, 140, 0.0, 300, miny - 40.0):
		sea.append(Transform3D(Basis().scaled(Vector3(rng.randf_range(20, 40), rng.randf_range(6, 12), rng.randf_range(20, 40))), p))
	_mm(_sphere_mesh(1.0, 10), cm, sea)
	# 空に浮かぶ島
	for p in _scatter(rng, 8, hw + 25.0, 90, 0.0, 120.0):
		var y := miny + rng.randf_range(-10, 20)
		var s := rng.randf_range(8, 14)
		var isl := Node3D.new()
		isl.position = Vector3(p.x, y, p.z)
		add_child(isl)
		Models.cyl(isl, s, s * 0.95, 2.0, Color(0.4, 0.75, 0.35), Vector3.ZERO, Vector3.ZERO, 12)
		Models.cyl(isl, s * 0.9, 0.5, s * 1.2, Color(0.55, 0.42, 0.3), Vector3(0, -s * 0.6 - 1.0, 0), Vector3.ZERO, 10)
		for q in 3:
			var a := q * 2.1
			Models.cyl(isl, 0.3, 0.4, 3.0, Color(0.5, 0.33, 0.2), Vector3(cos(a) * s * 0.5, 2.5, sin(a) * s * 0.5))
			Models.sphere(isl, 2.2, Color(0.25, 0.65, 0.3), Vector3(cos(a) * s * 0.5, 5.0, sin(a) * s * 0.5))
	_clouds(rng)


func _decor_space(rng: RandomNumberGenerator) -> void:
	# 惑星
	var planets := [[Color(0.9, 0.5, 0.3), 60.0, Vector3(-350, 80, -420)], [Color(0.4, 0.6, 1.0), 35.0, Vector3(500, 150, 100)],
		[Color(0.6, 0.9, 0.6), 22.0, Vector3(150, -120, 450)], [Color(1.0, 0.85, 0.5), 90.0, Vector3(300, -250, -600)]]
	for k in planets.size():
		var pl: Array = planets[k]
		var mi := MeshInstance3D.new()
		mi.mesh = _sphere_mesh(pl[1], 24)
		mi.material_override = Models.mat(pl[0], 0.8, 0.0, 0.25)
		mi.position = _center() + pl[2]
		add_child(mi)
		if k == 0:
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = pl[1] * 1.3
			tm.outer_radius = pl[1] * 1.9
			ring.mesh = tm
			ring.scale = Vector3(1, 0.05, 1)
			ring.rotation = Vector3(0.4, 0, 0.3)
			ring.material_override = Models.mat(Color(0.95, 0.8, 0.6, 0.8), 0.8, 0.0, 0.3)
			mi.add_child(ring)
	# 小惑星
	var rocks := []
	for p in _scatter(rng, 90, hw + 12.0, 150, miny):
		rocks.append(Transform3D(Basis.from_euler(Vector3(rng.randf() * 3, rng.randf() * 3, 0)).scaled(Vector3(rng.randf_range(1.5, 6), rng.randf_range(1.2, 4), rng.randf_range(1.5, 6))),
			p + Vector3(0, rng.randf_range(-40, 40), 0)))
	_mm(_sphere_mesh(1.0, 6), Models.mat(Color(0.45, 0.4, 0.5)), rocks)
	# 光のリング
	var rings := []
	for k in 7:
		var d := length * (k + 0.5) / 7.0
		var i := idx_of(d)
		if gap[i] == 1 or ramp_h[i] > 0.0:
			continue
		var fwd := Vector3(tang[i].x, 0, tang[i].z).normalized()
		rings.append(Transform3D(Basis.looking_at(fwd, Vector3.UP).rotated(Basis.looking_at(fwd, Vector3.UP).x, PI / 2), pts[i]))
	var tm2 := TorusMesh.new()
	tm2.inner_radius = hw + 2.0
	tm2.outer_radius = hw + 2.8
	tm2.rings = 32
	tm2.ring_segments = 6
	_mm(tm2, unshaded(Color(0.4, 1.0, 1.0)), rings)
	# 星雲
	for k in 2:
		var neb := MeshInstance3D.new()
		neb.mesh = _sphere_mesh(160.0, 16)
		neb.material_override = unshaded(Color(0.7, 0.2, 0.9, 0.12) if k == 0 else Color(0.2, 0.5, 1.0, 0.1))
		neb.position = _center() + Vector3(-500 + k * 900, 100, 350 - k * 800)
		add_child(neb)


# ------------------------------------------------------------------ 飾りの部品
static func _capsule_mesh(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 3
	return c


func _water_mat(col: Color) -> StandardMaterial3D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var v := 0.5 + 0.5 * sin(x * 0.4 + sin(y * 0.5) * 1.5)
			img.set_pixel(x, y, Color(col.r + v * 0.12, col.g + v * 0.12, col.b + v * 0.1, col.a))
	var m := _tex_mat(img, 0.05)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic_specular = 1.0
	m.uv1_scale = Vector3(8, 8, 1)
	m.cull_mode = BaseMaterial3D.CULL_BACK
	_anim_mats.append([m, Vector2(0.03, 0.02)])
	return m


func _water_disc(pos: Vector3, r: float, col := Color(0.2, 0.6, 1.0, 0.85)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.1
	cm.radial_segments = 40
	mi.mesh = cm
	mi.material_override = _water_mat(col)
	mi.position = pos
	add_child(mi)
	return mi


func _particles_box(pos: Vector3, ext: Vector3, amount: int, life: float, col: Color, size: float, grav: Vector3, vmin: float, vmax: float, emissive := 0.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = ext
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = grav
	p.mesh = _sphere_mesh(size, 4)
	p.material_override = Models.mat(col, 0.5, 0.0, emissive)
	add_child(p)
	return p


func _round_trees(pos: Array[Vector3], rng: RandomNumberGenerator, c1: Color, c2: Color) -> Array:
	var trunks := []
	var l1 := []
	var l2 := []
	var scales := []
	for p in pos:
		var s := rng.randf_range(0.8, 1.5)
		scales.append(s)
		trunks.append(Transform3D(Basis().scaled(Vector3.ONE * s), p + Vector3(0, 1.5 * s, 0)))
		l1.append(Transform3D(Basis().scaled(Vector3.ONE * s), p + Vector3(0, 5.0 * s, 0)))
		l2.append(Transform3D(Basis().scaled(Vector3.ONE * s * 0.7), p + Vector3(0, 6.6 * s, 0)))
	var leaf := SphereMesh.new()
	leaf.radius = 2.6
	leaf.height = 4.8
	leaf.radial_segments = 10
	leaf.rings = 6
	_mm(_cyl_mesh(0.35, 0.5, 3.0, 6), Models.mat(Color(0.5, 0.33, 0.2), 0.9), trunks)
	_mm(leaf, Models.mat(c1, 0.9), l1)
	_mm(leaf, Models.mat(c2, 0.9), l2)
	return scales


func _pine_trees(pos: Array[Vector3], rng: RandomNumberGenerator) -> void:
	var trunks := []
	var l1 := []
	var l2 := []
	for p in pos:
		var s := rng.randf_range(0.8, 1.5)
		trunks.append(Transform3D(Basis().scaled(Vector3.ONE * s), p + Vector3(0, 1.5 * s, 0)))
		l1.append(Transform3D(Basis().scaled(Vector3.ONE * s), p + Vector3(0, 5.0 * s, 0)))
		l2.append(Transform3D(Basis().scaled(Vector3.ONE * s * 0.55), p + Vector3(0, 7.6 * s, 0)))
	var cone := _cyl_mesh(0.0, 2.8, 6.0, 8)
	_mm(_cyl_mesh(0.35, 0.5, 3.0, 6), Models.mat(Color(0.5, 0.33, 0.2), 0.9), trunks)
	_mm(cone, Models.mat(Color(0.15, 0.42, 0.28), 0.9), l1)
	_mm(cone, Models.mat(Color(0.95, 0.97, 1.0), 0.9), l2)


func _flowers(rng: RandomNumberGenerator, avoid: Array, avoid_r: float) -> void:
	var cols := [Color(1, 0.4, 0.5), Color(1, 0.95, 0.3), Color(1, 1, 1), Color(0.7, 0.5, 1.0)]
	for c in cols:
		var xf := []
		for p in _scatter(rng, 90, hw + 1.0, 40, base_y + 0.15):
			var ok := true
			for a in avoid:
				if Vector2(p.x - a.x, p.z - a.z).length() < avoid_r:
					ok = false
			if ok:
				xf.append(Transform3D(Basis(), p))
		_mm(_sphere_mesh(0.35, 6), Models.mat(c, 0.8), xf)


func _hills(rng: RandomNumberGenerator, col: Color) -> void:
	var xf := []
	for k in 12:
		var a := k * TAU / 12.0 + 0.2
		var c := _center() + Vector3(cos(a), 0, sin(a)) * rng.randf_range(330, 420)
		xf.append(Transform3D(Basis().scaled(Vector3(1.4, 0.45, 1.0) * rng.randf_range(60, 110)), c))
	_mm(_sphere_mesh(1.0, 16), Models.mat(col), xf)


func _clouds(rng: RandomNumberGenerator) -> void:
	var xf := []
	for k in 14:
		var c := Vector3(rng.randf_range(bbox.position.x - 150, bbox.end.x + 150), maxy + rng.randf_range(70, 110), rng.randf_range(bbox.position.y - 150, bbox.end.y + 150))
		for q in 4:
			var r := rng.randf_range(6, 11)
			xf.append(Transform3D(Basis().scaled(Vector3(r, r * 0.6, r)), c + Vector3(q * 7 - 10, rng.randf_range(-2, 2), rng.randf_range(-3, 3))))
	_mm(_sphere_mesh(1.0, 10), Models.mat(Color(1, 1, 1), 1.0, 0.0, 0.35), xf)
