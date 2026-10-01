class_name Gimmicks
extends Node3D
## コース上の動く障害物（道を横切るもの・道を走る車）。
## 数と速さは難易度で変わる。ぶつかったカートはくるくる回る。

var race: Node
var track: Track
var items: Array = []   # {node, kind, d, lat, amp, w, phase, speed, ext_along, ext_lat, cd}
var _t := 0.0


func setup(r: Node, t: Track, course: Dictionary, diff: Dictionary) -> void:
	race = r
	track = t
	var gm: float = diff.get("gimmick", 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# 道を横切る障害物
	var cross: Array = course.get("cross", [])
	var kind: String = course.get("cross_kind", "boulder")
	for k in cross.size():
		if gm < 0.9 and k % 2 == 1:
			continue   # やさしい：半分に減らす
		var d: float = cross[k]
		var node := _build(kind)
		add_child(node)
		var ext := _extent(kind)
		items.append({"node": node, "kind": kind, "d": d, "lat": 0.0, "amp": track.hw * 0.82,
			"w": 0.75 * gm * rng.randf_range(0.85, 1.15), "phase": rng.randf() * TAU, "speed": 0.0,
			"ext_along": ext.x, "ext_lat": ext.y, "cd": 0.0})
	# むずかしい：横切る障害物を追加
	if gm > 1.2 and cross.size() > 0:
		for k in cross.size() - 1:
			var d2: float = (float(cross[k]) + float(cross[k + 1])) * 0.5
			var node2 := _build(kind)
			add_child(node2)
			var ext2 := _extent(kind)
			items.append({"node": node2, "kind": kind, "d": d2, "lat": 0.0, "amp": track.hw * 0.82,
				"w": 0.75 * gm, "phase": rng.randf() * TAU, "speed": 0.0, "ext_along": ext2.x, "ext_lat": ext2.y, "cd": 0.0})
	# 走る車
	var traffic: int = course.get("traffic", 0)
	if traffic > 0:
		var count := traffic + (2 if gm > 1.2 else (-2 if gm < 0.9 else 0))
		for k in count:
			var node3 := _build("car")
			add_child(node3)
			var lane := (-0.5 if k % 2 == 0 else 0.5) * track.hw
			items.append({"node": node3, "kind": "car", "d": track.length * (k + 0.35) / count, "lat": lane, "amp": 0.0,
				"w": 0.0, "phase": 0.0, "speed": 16.0 * gm * rng.randf_range(0.9, 1.1), "ext_along": 2.4, "ext_lat": 1.3, "cd": 0.0})


func _extent(kind: String) -> Vector2:
	match kind:
		"log":
			return Vector2(2.6, 1.0)
		"minecart":
			return Vector2(1.3, 1.6)
		"thunder":
			return Vector2(2.0, 2.0)
		"crab":
			return Vector2(1.4, 1.6)
	return Vector2(1.6, 1.6)


## CPUがよけるための一覧
func obstacle_list() -> Array:
	var out := []
	for it in items:
		out.append({"d": it.d, "lat": it.lat})
	return out


func update(dt: float, hits := true) -> void:
	_t += dt
	for it in items:
		var node: Node3D = it.node
		it.cd = maxf(0.0, it.cd - dt)
		var prev_lat: float = it.lat
		if it.kind == "car":
			it.d = fposmod(it.d + it.speed * dt, track.length)
		else:
			it.lat = sin(_t * it.w + it.phase) * it.amp
		var pos := track.point_at(it.d, it.lat)
		var fwd := track.dir_at(it.d)
		var right := Vector3(-fwd.z, 0, fwd.x)
		var vlat: float = (it.lat - prev_lat) / maxf(dt, 0.0001)
		match it.kind:
			"orange", "boulder":
				var r := 1.3 if it.kind == "orange" else 1.6
				node.position = pos + Vector3(0, r, 0)
				node.basis = Basis.looking_at(fwd, Vector3.UP)
				var body: Node3D = node.get_child(0)
				body.rotate_z(-vlat * dt / r)
			"crab":
				node.position = pos + Vector3(0, 0.1 + absf(sin(_t * 14.0)) * 0.15, 0)
				node.basis = Basis.looking_at(fwd, Vector3.UP)
			"log":
				node.position = pos + Vector3(0, 0.75, 0)
				node.basis = Basis.looking_at(fwd, Vector3.UP)
				var lg: Node3D = node.get_child(0)
				lg.rotate_z(-vlat * dt / 0.75)
			"minecart":
				node.position = pos + Vector3(0, 0.1, 0)
				node.basis = Basis.looking_at(right if vlat >= 0.0 else -right, Vector3.UP)
			"thunder":
				node.position = pos
				node.basis = Basis.looking_at(fwd, Vector3.UP)
				var bolt: Node3D = node.get_node("Bolt")
				bolt.visible = fmod(_t * 3.0 + it.phase, 1.0) < 0.6 and fmod(_t * 23.0, 1.0) < 0.75
			"meteor":
				node.position = pos + Vector3(0, 1.5 + sin(_t * 3.0 + it.phase) * 0.3, 0)
				node.get_child(0).rotation += Vector3(dt * 1.5, dt * 2.0, 0)
			"star":
				node.position = pos + Vector3(0, 1.4, 0)
				node.rotation.y += dt * 3.0
			"car":
				node.position = pos
				node.basis = Basis.looking_at(fwd, Vector3.UP)
		if hits:
			_check_hits(it)


func _check_hits(it: Dictionary) -> void:
	if it.cd > 0.0:
		return
	for k in race.karts:
		var kk: Kart = k
		if kk.fall_timer >= 0.0:
			continue
		var dd := fposmod(kk.d - it.d + track.length * 0.5, track.length) - track.length * 0.5
		if absf(dd) < it.ext_along + 0.9 and absf(kk.lat - it.lat) < it.ext_lat + 0.9:
			if not kk.grounded and kk.position.y - kk.ground_y > 1.6 and it.kind != "thunder":
				continue   # ジャンプで飛びこえた
			it.cd = 0.4
			if kk.hit_spin():
				kk._spark_burst(Color(1, 1, 0.6))
				if kk.is_player:
					race.hud.popup("いてっ！", Color(1, 0.6, 0.4), 0.8)
					race.shake(0.3)
					Sfx.play("crash", 0.9)


# ------------------------------------------------------------------ 見た目
func _build(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"orange":
			var b := Models.sphere(root, 1.3, Color(1.0, 0.55, 0.05), Vector3.ZERO, Vector3.ONE, 14)
			Models.sphere(b, 0.4, Color(0.25, 0.6, 0.2), Vector3(0, 1.25, 0), Vector3(1.5, 0.3, 0.8), 6)
		"boulder":
			var b := Models.sphere(root, 1.6, Color(0.7, 0.6, 0.45), Vector3.ZERO, Vector3.ONE, 10)
			for k in 5:
				Models.sphere(b, 0.35, Color(0.5, 0.42, 0.3), Vector3(cos(k * 1.3), sin(k * 2.1), cos(k * 0.7)).normalized() * 1.45, Vector3(1, 1, 0.3), 6)
		"crab":
			var body := Models.sphere(root, 0.9, Color(0.95, 0.25, 0.15), Vector3(0, 0.7, 0), Vector3(1.4, 0.6, 1.0), 12)
			for sx: float in [-1.0, 1.0]:
				Models.cyl(body, 0.06, 0.06, 0.6, Color(0.95, 0.25, 0.15), Vector3(sx * 0.25, 0.9, -0.3))
				Models.sphere(body, 0.14, Color(1, 1, 1), Vector3(sx * 0.25, 1.25, -0.3), Vector3.ONE, 8)
				Models.sphere(body, 0.07, Color(0, 0, 0), Vector3(sx * 0.25, 1.27, -0.42), Vector3.ONE, 6)
				Models.sphere(root, 0.4, Color(1.0, 0.35, 0.2), Vector3(sx * 1.5, 0.9, -0.5), Vector3(1, 0.7, 0.8), 8)
				for q in 3:
					Models.cyl(root, 0.06, 0.08, 0.9, Color(0.85, 0.2, 0.1), Vector3(sx * (0.9 + q * 0.2), 0.3, 0.3 - q * 0.3), Vector3(0, 0, sx * 0.9))
		"log":
			var lg := Node3D.new()
			root.add_child(lg)
			Models.cyl(lg, 0.75, 0.75, 5.0, Color(0.55, 0.36, 0.2), Vector3.ZERO, Vector3(PI / 2, 0, 0), 12)
			for sz: float in [-1.0, 1.0]:
				Models.cyl(lg, 0.6, 0.6, 0.05, Color(0.85, 0.7, 0.45), Vector3(0, 0, sz * 2.52), Vector3(PI / 2, 0, 0), 12)
		"minecart":
			Models.box(root, Vector3(2.6, 1.3, 1.8), Color(0.45, 0.3, 0.2), Vector3(0, 1.1, 0))
			Models.box(root, Vector3(2.7, 0.15, 1.9), Color(0.55, 0.55, 0.6), Vector3(0, 1.8, 0))
			for sx: float in [-0.9, 0.9]:
				for sz: float in [-0.7, 0.7]:
					Models.cyl(root, 0.3, 0.3, 0.15, Color(0.25, 0.25, 0.3), Vector3(sx, 0.35, sz), Vector3(PI / 2, 0, 0), 10)
			for k in 4:
				var ore := Models.sphere(root, 0.4, Color(0.4, 0.9, 1.0), Vector3(-0.8 + k * 0.5, 1.9, 0), Vector3.ONE, 6)
				ore.material_override = Models.mat(Color(0.4, 0.9, 1.0), 0.2, 0.0, 1.5)
		"thunder":
			for k in 4:
				var s := Models.sphere(root, 1.2, Color(0.35, 0.35, 0.45), Vector3(-1.5 + k, 3.4 + sin(k) * 0.2, 0), Vector3(1, 0.7, 1), 10)
				s.material_override = Models.mat(Color(0.35, 0.35, 0.45), 1.0)
			var bolt := Node3D.new()
			bolt.name = "Bolt"
			root.add_child(bolt)
			var ys := [2.8, 2.0, 1.2, 0.4]
			for k in 3:
				var a := Vector3(0.3 if k % 2 == 0 else -0.3, ys[k], 0)
				var b := Vector3(-0.3 if k % 2 == 0 else 0.3, ys[k + 1], 0)
				var seg := Models.box(bolt, Vector3(0.25, (a - b).length(), 0.25), Color(1, 0.95, 0.3), (a + b) * 0.5)
				seg.rotation.z = atan2(b.x - a.x, a.y - b.y)
				seg.material_override = Models.mat(Color(1, 0.95, 0.3), 0.5, 0.0, 3.0)
		"meteor":
			var m := Models.sphere(root, 1.4, Color(0.35, 0.28, 0.25), Vector3.ZERO, Vector3.ONE, 8)
			for k in 4:
				var c := Models.sphere(m, 0.35, Color(1, 0.5, 0.1), Vector3(cos(k * 1.7), sin(k * 2.3), sin(k * 1.1)).normalized() * 1.25, Vector3(1, 1, 0.4), 6)
				c.material_override = Models.mat(Color(1, 0.5, 0.1), 0.5, 0.0, 2.5)
			var glow := Models.sphere(root, 1.9, Color(1, 0.45, 0.1, 0.25), Vector3.ZERO, Vector3.ONE, 10)
			glow.material_override = Track.unshaded(Color(1, 0.5, 0.15, 0.25))
		"star":
			for k in 2:
				var st := Models._star_mesh(1.6, Color(1, 0.85, 0.2))
				st.position.z = 0.15 if k == 0 else -0.15
				root.add_child(st)
			Models.sphere(root, 0.5, Color(1, 0.95, 0.5)).material_override = Models.mat(Color(1, 0.95, 0.5), 0.3, 0.0, 1.5)
		"car":
			var cols := [Color(0.9, 0.2, 0.2), Color(0.2, 0.45, 0.95), Color(0.95, 0.85, 0.2), Color(0.9, 0.9, 0.95), Color(0.3, 0.8, 0.5)]
			var col: Color = cols[randi() % cols.size()]
			Models.box(root, Vector3(2.2, 0.9, 4.4), col, Vector3(0, 0.8, 0))
			Models.box(root, Vector3(1.9, 0.75, 2.2), col.darkened(0.2), Vector3(0, 1.6, 0.3))
			Models.box(root, Vector3(1.85, 0.6, 0.05), Color(0.5, 0.7, 0.9), Vector3(0, 1.6, -0.82))
			for sx: float in [-0.95, 0.95]:
				for sz: float in [-1.4, 1.4]:
					Models.cyl(root, 0.42, 0.42, 0.3, Color(0.1, 0.1, 0.12), Vector3(sx * 1.05, 0.42, sz), Vector3(0, 0, PI / 2), 10)
				Models.box(root, Vector3(0.4, 0.25, 0.1), Color(1, 1, 0.85), Vector3(sx * 0.7, 0.9, -2.22)).material_override = Models.mat(Color(1, 1, 0.85), 0.3, 0.0, 3.0)
				Models.box(root, Vector3(0.4, 0.2, 0.1), Color(1, 0.1, 0.1), Vector3(sx * 0.7, 0.95, 2.22)).material_override = Models.mat(Color(1, 0.1, 0.1), 0.3, 0.0, 3.0)
	match kind:
		"orange", "boulder", "meteor", "log":
			Models.bake(root.get_child(0))
		"thunder":
			Models.bake(root, [root.get_node("Bolt")])
		_:
			Models.bake(root)
	return root
