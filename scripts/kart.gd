class_name Kart
extends Node3D
## カート1台分の挙動（プレイヤー・CPU共通）。入力 in_* を毎フレーム設定してから step() を呼ぶ。

const GRAVITY := 21.0
const HOP_VEL := 4.4
const DRIFT_LEVEL_TIMES := [0.75, 1.7, 2.7]            # 青・黄・赤になるまでの時間
const DRIFT_BOOST_TIMES := [0.0, 0.7, 1.15, 1.7]
const DRIFT_COLORS := [Color(1, 1, 1), Color(0.3, 0.6, 1.0), Color(1.0, 0.85, 0.1), Color(1.0, 0.2, 0.15)]

var race: Node
var track: Track
var is_player := false
var racer_name := ""
var char_idx := 0
var kart_idx := 0
var stats := {}
var brain: CpuBrain
var is_human := false       # 人が運転（このスマホ or LANの別のスマホ）
var remote_peer := 0        # LAN対戦で運転している相手のID（0=この端末かCPU）
var assist := false         # ハンデ：自動ハンドル補助
var fast := false           # ハンデ：少し速いカート

# 入力
var in_steer := 0.0
var in_accel := false
var in_brake := false
var in_drift := false
var in_item := false
var _prev_drift := false
var _prev_item := false

# 運動
var speed := 0.0
var yaw := 0.0
var move_yaw := 0.0
var vy := 0.0
var grounded := true
var air_time := 0.0
var speed_mult := 1.0
var hop_air := false

# コース上の位置
var idx := 0
var lat := 0.0
var d := 0.0
var lap := 0
var progress := 0.0
var finished := false
var finish_time := -1.0
var rank := 1
var lap_start_time := 0.0
var off_road := false
var on_ice := false
var ground_y := 0.0

# 状態
var drift_dir := 0
var drift_time := 0.0
var drift_level := 0
var boost_time := 0.0
var rocket_time := 0.0
var shield_time := 0.0
var spin_time := 0.0
var slip_time := 0.0
var invuln := 0.0
var fall_timer := -1.0
var stuck_time := 0.0
var wrong_way := 0.0
var item := ""
var item_count := 0
var gp_key := ""
var roulette := 0.0
var _pending_item := ""
var _wall_cd := 0.0
var _anim_t := 0.0
var _vis_yaw_off := 0.0
var _spin_angle := 0.0
var _roll := 0.0

# 見た目
var model: Node3D
var body: Node3D
var wheels: Array = []
var front_wheels: Array = []
var barrier: MeshInstance3D
var p_drift: Array[CPUParticles3D] = []
var p_flame: CPUParticles3D
var p_smoke: CPUParticles3D
var p_dust: CPUParticles3D
var engine_player: AudioStreamPlayer3D
var drift_player: AudioStreamPlayer3D

static var _pmat: StandardMaterial3D


func setup(r: Node, t: Track, name_: String, ci: int, ki: int, player: bool, human := player, hc: Dictionary = {}) -> void:
	race = r
	track = t
	racer_name = name_
	char_idx = ci
	kart_idx = ki
	is_player = player
	is_human = human
	assist = hc.get("assist", false)
	fast = hc.get("fast", false)
	stats = Game.compute_stats(ci, ki)
	if fast:
		stats.max_speed *= 1.07
		stats.accel *= 1.15
	model = Models.build_kart(ki, _kart_color(ci, ki), ci)
	add_child(model)
	body = model.get_meta("body")
	wheels = model.get_meta("wheels")
	front_wheels = model.get_meta("front_wheels")
	barrier = Models.build_barrier()
	barrier.visible = false
	add_child(barrier)
	_make_particles()
	if not human:
		brain = CpuBrain.new()


func _kart_color(ci: int, ki: int) -> Color:
	# キャラクターの色とカートの色を混ぜる
	return Game.KARTS[ki].color.lerp(Game.CHARACTERS[ci].color, 0.55)


static func _particle_mat() -> StandardMaterial3D:
	if _pmat:
		return _pmat
	_pmat = StandardMaterial3D.new()
	_pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pmat.vertex_color_use_as_albedo = true
	_pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var dd := Vector2(x - 15.5, y - 15.5).length() / 16.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - dd, 0.0, 1.0) ** 0.7))
	_pmat.albedo_texture = ImageTexture.create_from_image(img)
	return _pmat


func _particles(amount: int, life: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	p.mesh = q
	p.material_override = _particle_mat()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = curve
	model.add_child(p)
	return p


func _make_particles() -> void:
	for sx in [-0.9, 0.9]:
		var p := _particles(24, 0.35, 0.35)
		p.position = Vector3(sx, 0.2, 1.1)
		p.direction = Vector3(sx, 1.2, 1.0)
		p.spread = 35.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 6.0
		p.gravity = Vector3(0, -8, 0)
		p_drift.append(p)
	p_flame = _particles(40, 0.28, 0.7)
	p_flame.position = Vector3(0, 0.6, 1.5)
	p_flame.direction = Vector3(0, 0.2, 1)
	p_flame.spread = 12.0
	p_flame.initial_velocity_min = 6.0
	p_flame.initial_velocity_max = 9.0
	p_flame.gravity = Vector3.ZERO
	p_flame.color = Color(1, 0.6, 0.15, 0.9)
	p_smoke = _particles(30, 0.9, 1.1)
	p_smoke.position = Vector3(0, 0.3, 1.2)
	p_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p_smoke.emission_box_extents = Vector3(1.0, 0.1, 0.2)
	p_smoke.direction = Vector3(0, 1, 1)
	p_smoke.spread = 40.0
	p_smoke.initial_velocity_min = 1.5
	p_smoke.initial_velocity_max = 3.5
	p_smoke.gravity = Vector3(0, 1.0, 0)
	p_smoke.color = Color(1, 1, 1, 0.6)
	p_dust = _particles(20, 0.6, 0.8)
	p_dust.position = Vector3(0, 0.2, 1.0)
	p_dust.direction = Vector3(0, 1, 1)
	p_dust.spread = 40.0
	p_dust.initial_velocity_min = 1.0
	p_dust.initial_velocity_max = 3.0
	p_dust.gravity = Vector3(0, -2, 0)


func setup_audio() -> void:
	engine_player = AudioStreamPlayer3D.new()
	engine_player.stream = Sfx.load_loop("engine")
	engine_player.unit_size = 8.0 if not is_player else 40.0
	engine_player.max_db = -4.0 if not is_player else 0.0
	engine_player.volume_db = linear_to_db(max(Game.settings.se, 0.001)) - (14.0 if not is_player else 6.0)
	add_child(engine_player)
	drift_player = AudioStreamPlayer3D.new()
	drift_player.stream = Sfx.load_loop("drift")
	drift_player.unit_size = 8.0 if not is_player else 40.0
	drift_player.volume_db = linear_to_db(max(Game.settings.se, 0.001)) - (12.0 if not is_player else 4.0)
	add_child(drift_player)


func place(pos: Vector3, facing: float) -> void:
	position = pos
	yaw = facing
	move_yaw = facing
	idx = track.locate(pos, -1)
	var info := track.project(pos, idx)
	d = info.d
	ground_y = info.y
	position.y = ground_y
	lap = 0
	progress = d - track.length
	_update_visual(0.0)


# ------------------------------------------------------------------ 状態変化
func add_boost(t: float) -> void:
	boost_time = max(boost_time, t)
	speed = max(speed, stats.max_speed * 1.1)
	if is_player:
		Sfx.play("boost")
		race.on_player_boost()


func end_drift(give_boost := true) -> void:
	if drift_dir != 0 and give_boost and drift_level > 0:
		add_boost(DRIFT_BOOST_TIMES[drift_level])
		if is_player:
			race.hud.popup("ブースト！", DRIFT_COLORS[drift_level])
	drift_dir = 0
	drift_time = 0.0
	drift_level = 0


func is_protected() -> bool:
	return shield_time > 0.0 or invuln > 0.0 or rocket_time > 0.0 or fall_timer >= 0.0


func hit_spin() -> bool:
	if is_protected():
		if shield_time > 0.0:
			_spark_burst()
		return false
	spin_time = 1.3
	slip_time = 0.0
	boost_time = 0.0
	end_drift(false)
	invuln = 1.9
	vy = 4.0
	grounded = false
	_play_near("spin")
	return true


func hit_slip() -> bool:
	if is_protected():
		return false
	slip_time = 1.3
	boost_time = 0.0
	end_drift(false)
	invuln = 1.7
	_play_near("spin", 1.3)
	return true


func give_item(it: String) -> void:
	if item != "" or roulette > 0.0:
		return
	_pending_item = it
	roulette = 1.2 if is_player else 0.9
	if is_player:
		Sfx.play("item_get")


func _play_near(snd: String, pitch := 1.0) -> void:
	if is_player:
		Sfx.play(snd, pitch)
	elif race.player and position.distance_to(race.player.position) < 25.0:
		Sfx.play(snd, pitch, -8.0)


func _spark_burst(col := Color(1, 0.85, 0.3)) -> void:
	burst(col, 0.22, 16, 0.35, 5.0, 10.0, 80.0, Vector3(0, -15, 0), Vector3(0, 0.5, 0))


## その場で一回だけ出る煙や火花（使いおわったら消える）
func burst(col: Color, size: float, amount: int, life: float, vmin: float, vmax: float, spread: float, grav: Vector3, offset := Vector3.ZERO) -> void:
	if not is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	p.mesh = q
	p.material_override = _particle_mat()
	p.direction = Vector3(0, 1, 0)
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = grav
	p.color = col
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(p)
	p.global_position = global_position + global_basis * offset
	p.emitting = true
	get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)


## 白いけむり（スタート・着地）
func smoke_puff() -> void:
	burst(Color(1, 1, 1, 0.8), 1.2, 14, 0.8, 1.5, 3.5, 60.0, Vector3(0, 1.0, 0), Vector3(0, 0.3, 1.0))


# ------------------------------------------------------------------ 1フレーム
func step(dt: float, racing: bool) -> void:
	_anim_t += dt
	_wall_cd = max(0.0, _wall_cd - dt)
	# 落下中
	if fall_timer >= 0.0:
		fall_timer -= dt
		vy -= GRAVITY * dt
		position.y = max(position.y + vy * dt, track.base_y - 3.0)
		if fall_timer < 0.0:
			respawn()
		_update_visual(dt)
		return
	boost_time = max(0.0, boost_time - dt)
	rocket_time = max(0.0, rocket_time - dt)
	shield_time = max(0.0, shield_time - dt)
	spin_time = max(0.0, spin_time - dt)
	slip_time = max(0.0, slip_time - dt)
	invuln = max(0.0, invuln - dt)
	if roulette > 0.0:
		roulette -= dt
		if roulette <= 0.0:
			item = _pending_item
			item_count = 1
			_pending_item = ""
			if is_player:
				Sfx.play("item_get", 1.3)
	var disabled := spin_time > 0.0 or slip_time > 0.0 or not racing
	var steer := 0.0 if disabled else clampf(in_steer, -1.0, 1.0)
	var drift_pressed := in_drift and not _prev_drift
	var item_pressed := in_item and not _prev_item
	_prev_drift = in_drift
	_prev_item = in_item
	if item_pressed and racing and not disabled and item != "" and roulette <= 0.0:
		var it := item
		item_count -= 1
		if item_count <= 0:
			item = ""
			item_count = 0
		race.use_item(self, it)

	# ---- 速度
	var top: float = stats.max_speed * speed_mult
	if drift_dir != 0:
		top *= 0.97
	if off_road and boost_time <= 0.0 and rocket_time <= 0.0:
		top *= track.offroad_mult
	if rocket_time > 0.0:
		top *= 1.6
	elif boost_time > 0.0:
		top *= 1.33
	var acc: float = stats.accel
	if not racing:
		speed = move_toward(speed, 0.0, 20.0 * dt)
	elif spin_time > 0.0:
		speed = move_toward(speed, 0.0, 26.0 * dt)
	elif slip_time > 0.0:
		speed = move_toward(speed, top * 0.35, 22.0 * dt)
	elif boost_time > 0.0 or rocket_time > 0.0:
		speed = move_toward(speed, top, 45.0 * dt)
	elif not grounded:
		pass
	elif in_accel:
		if speed < top:
			# 速度が上がるほど加速はゆるやかに
			var f := 1.0 - 0.55 * clampf(speed / top, 0.0, 1.0)
			speed = min(top, speed + acc * f * dt * (2.0 if speed < 0.0 else 1.0))
		else:
			speed = move_toward(speed, top, 20.0 * dt)
	elif in_brake:
		if speed > 0.5:
			speed = move_toward(speed, 0.0, 28.0 * dt)
		else:
			speed = move_toward(speed, -9.0, 10.0 * dt)
	else:
		speed = move_toward(speed, 0.0, 7.0 * dt)
		if speed > top:
			speed = move_toward(speed, top, 15.0 * dt)

	# ---- ホップ → ドリフト
	if drift_pressed and grounded and racing and not disabled and speed > 9.0:
		vy = HOP_VEL
		grounded = false
		hop_air = true
	if drift_dir != 0:
		if not in_drift or speed < 8.0 or disabled:
			end_drift(not disabled)
		else:
			var s := steer * drift_dir
			yaw -= drift_dir * stats.turn * (1.02 + 0.5 * s) * dt
			drift_time += dt * (1.0 + 0.4 * maxf(s, 0.0))
			var lv := 0
			for k in 3:
				if drift_time >= DRIFT_LEVEL_TIMES[k]:
					lv = k + 1
			if lv != drift_level:
				drift_level = lv
				if is_player and lv > 0:
					Sfx.play("roulette", 0.8 + lv * 0.25)
	elif rocket_time <= 0.0:
		var k := clampf(absf(speed) / 7.0, 0.0, 1.0)
		var hi := 1.0 - 0.18 * clampf(speed / stats.max_speed, 0.0, 1.2)
		var air := 0.5 if not grounded else 1.0
		yaw -= steer * stats.turn * k * hi * air * dt * signf(speed if absf(speed) > 0.1 else 1.0)

	# ロケット中は自動でコースに沿って進む
	if rocket_time > 0.0:
		var tgt := track.point_at(d + 22.0, 0.0)
		var want := atan2(-(tgt.x - position.x), -(tgt.z - position.z))
		yaw = lerp_angle(yaw, want, 1.0 - exp(-6.0 * dt))

	# ---- グリップ
	var grip := 11.0
	if drift_dir != 0:
		grip = 3.2
	if on_ice:
		grip = 1.4 if drift_dir == 0 else 1.1
	if not grounded:
		grip = 1.2
	if rocket_time > 0.0:
		grip = 12.0
	move_yaw = lerp_angle(move_yaw, yaw, 1.0 - exp(-grip * dt))
	var dir := Vector3(-sin(move_yaw), 0.0, -cos(move_yaw))
	var prev_i := idx
	position += dir * speed * dt

	# ---- コース上の位置
	idx = track.locate(position, idx)
	var info := track.project(position, idx)
	lat = info.lat
	var i0: int = info.i0
	var prev_d := d
	d = info.d
	var L := track.length
	if prev_d > L * 0.75 and d < L * 0.25:
		lap += 1
		race.on_lap(self)
	elif prev_d < L * 0.25 and d > L * 0.75:
		lap -= 1
	progress = (lap - 1) * L + d
	var hw := track.hw
	off_road = absf(lat) > hw + 0.4 and track.edge[i0] == Track.Edge.SHOULDER
	on_ice = track.surf[i0] == Track.Surf.ICE and absf(lat) <= hw + 0.2

	# ---- 壁
	var limit := track.wall_limit(i0) - 0.9
	if absf(lat) > limit:
		var side := signf(lat)
		var r: Vector3 = info.right
		position -= r * (absf(lat) - limit) * side
		lat = limit * side
		var outward := dir.dot(r) * side
		if outward > 0.1:
			var fwd: Vector3 = info.fwd
			var tyaw := atan2(-fwd.x, -fwd.z)
			if speed < 0.0:
				tyaw += PI
			yaw = lerp_angle(yaw, tyaw, 0.35)
			move_yaw = lerp_angle(move_yaw, tyaw, 0.6)
			if outward > 0.35 and _wall_cd <= 0.0:
				speed *= 0.72
				_wall_cd = 0.4
				_spark_burst()
				_play_near("crash", 1.2)
				if is_player:
					race.shake(0.25)

	# ---- 高さ・ジャンプ
	var has_ground := track.has_ground(i0, lat)
	ground_y = info.y
	if grounded:
		if has_ground:
			# ジャンプ台の端を越えたら発射
			var launch := 0.0
			var dash := false
			if prev_i != idx:
				var k := prev_i
				var guard := 0
				while k != idx and guard < 6:
					k = track.wrap_i(k + 1)
					launch = max(launch, track.ramp_launch[k])
					if not is_nan(track.dash_lat[k]) and absf(lat - track.dash_lat[k]) < Track.DASH_HALF_W + 0.4:
						dash = true
					guard += 1
			if dash and speed > 0.0:
				add_boost(1.1)
				if is_player:
					race.hud.popup("ダッシュ！", Color(0.4, 0.9, 1.0), 0.6)
			if launch > 0.0 and speed > 5.0:
				vy = launch * clampf(speed / stats.max_speed, 0.6, 1.15)
				speed = max(speed, stats.max_speed * 0.9)
				grounded = false
				hop_air = false
				air_time = 0.0
				if is_player:
					Sfx.play("throw", 0.6)
			else:
				position.y = ground_y
		else:
			grounded = false
			hop_air = false
			vy = 0.0
			air_time = 0.0
	if not grounded:
		vy -= GRAVITY * dt
		position.y += vy * dt
		air_time += dt
		if has_ground and position.y <= ground_y and vy <= 0.0:
			_land()
		elif not has_ground and position.y < ground_y - 3.5:
			_start_fall()
		elif position.y < track.base_y - 5.0:
			_start_fall()

	# ---- CPU: 動けなくなった・逆走 → コース復帰
	if racing:
		if absf(speed) < 2.0 and spin_time <= 0.0 and slip_time <= 0.0:
			stuck_time += dt
		else:
			stuck_time = 0.0
		var fwd2: Vector3 = info.fwd
		if dir.dot(fwd2) < -0.3 and absf(speed) > 3.0:
			wrong_way += dt
		else:
			wrong_way = max(0.0, wrong_way - dt * 2.0)
		if (not is_player or brain) and (stuck_time > 2.5 or wrong_way > 2.5):
			if OS.has_environment("KART_DEBUG"):
				print("RESPAWN %s stuck=%.1f wrong=%.1f d=%d lat=%.1f yaw=%.2f edge=%d" % [racer_name, stuck_time, wrong_way, int(d), lat, yaw, track.edge[idx]])
			respawn()

	_effects(racing, dt)


## パーティクル・エンジン音・見た目（LANの子機でも使う）
func _effects(racing: bool, dt: float) -> void:
	var drifting := drift_dir != 0 and grounded
	for p in p_drift:
		p.emitting = drifting and drift_level > 0
		p.color = DRIFT_COLORS[drift_level]
	p_flame.emitting = boost_time > 0.0 or rocket_time > 0.0
	p_flame.scale_amount_min = 1.6 if rocket_time > 0.0 else 1.0
	p_dust.emitting = off_road and grounded and absf(speed) > 6.0
	p_dust.color = track.dust_color
	p_smoke.emitting = drifting and drift_level == 0 or (grounded and on_ice and absf(wrapf(yaw - move_yaw, -PI, PI)) > 0.25)
	if engine_player:
		engine_player.pitch_scale = 0.7 + clampf(absf(speed) / stats.max_speed, 0.0, 1.6) * 1.0
		if racing and not engine_player.playing:
			engine_player.play()
	if drift_player:
		if drifting and not drift_player.playing:
			drift_player.play()
		elif not drifting and drift_player.playing:
			drift_player.stop()
	_update_visual(dt)


func _land() -> void:
	position.y = ground_y
	var was_air := air_time
	grounded = true
	vy = 0.0
	# ホップ着地時にハンドルを切っていればドリフト開始
	if hop_air and in_drift and absf(in_steer) > 0.3 and drift_dir == 0 and spin_time <= 0.0:
		drift_dir = int(signf(in_steer))
		drift_time = 0.0
		drift_level = 0
	hop_air = false
	if was_air > 0.35:
		smoke_puff()
		_play_near("land")
		if is_player:
			race.shake(0.35)
			race.hud.popup("ドン！", Color(1, 1, 1), 0.6)
	air_time = 0.0


func _start_fall() -> void:
	if fall_timer >= 0.0:
		return
	fall_timer = 1.3
	if OS.has_environment("KART_DEBUG"):
		print("FALL %s d=%d lat=%.1f gap=%d edge=%d speed=%.1f air=%.2f spin=%.1f" % [racer_name, int(d), lat, track.gap[idx], track.edge[idx], speed, air_time, spin_time])
	end_drift(false)
	if is_player:
		Sfx.play("crash", 0.7)
		race.hud.popup("コースアウト！", Color(1, 0.5, 0.3), 1.2)


## 最寄りの安全な位置へ戻る（コース復帰）
func respawn() -> void:
	fall_timer = -1.0
	race.respawn_count += 1
	var i := track.wrap_i(idx - 3)
	var guard := 0
	var in_gap := false
	for k in range(-2, 7):
		if track.gap[track.wrap_i(idx + k)] == 1:
			in_gap = true
	if in_gap:
		# ジャンプの穴に落ちたときは向こう岸に戻す
		i = idx
		while track.gap[i] == 0 and guard < 8:
			i = track.wrap_i(i + 1)
			guard += 1
		while track.gap[i] == 1 and guard < 40:
			i = track.wrap_i(i + 1)
			guard += 1
		i = track.wrap_i(i + 3)
	else:
		while (track.gap[i] == 1 or track.ramp_h[i] > 0.0 or track.ramp_launch[i] > 0.0) and guard < 40:
			i = track.wrap_i(i - 1)
			guard += 1
	var p := track.pts[i]
	var t := track.tang[i]
	var fwd := Vector3(t.x, 0, t.z).normalized()
	position = p + track.rightv[i] * clampf(lat, -track.hw * 0.4, track.hw * 0.4)
	position.y = p.y
	yaw = atan2(-fwd.x, -fwd.z)
	move_yaw = yaw
	idx = i
	var info := track.project(position, idx)
	var nd: float = info.d
	# 周回数が戻らないように調整
	if d < track.length * 0.25 and nd > track.length * 0.75:
		lap -= 1
	var crossed := d > track.length * 0.75 and nd < track.length * 0.25
	d = nd
	if crossed:
		lap += 1
		race.on_lap(self)
	progress = (lap - 1) * track.length + d
	speed = 0.0
	vy = 0.0
	grounded = true
	spin_time = 0.0
	slip_time = 0.0
	stuck_time = 0.0
	wrong_way = 0.0
	invuln = 2.0
	end_drift(false)
	if is_player:
		race.snap_camera()


# ------------------------------------------------------------------ 見た目
func _update_visual(dt: float) -> void:
	var target_off := 0.0
	if drift_dir != 0:
		target_off = drift_dir * -0.38
	_vis_yaw_off = lerpf(_vis_yaw_off, target_off, 1.0 - exp(-10.0 * dt)) if dt > 0.0 else target_off
	if spin_time > 0.0:
		_spin_angle += dt * 13.0
	else:
		_spin_angle = lerp_angle(_spin_angle, 0.0, 1.0 - exp(-8.0 * dt)) if dt > 0.0 else 0.0
		if absf(wrapf(_spin_angle, -PI, PI)) < 0.01:
			_spin_angle = 0.0
	var wob := sin(_anim_t * 20.0) * 0.55 * clampf(slip_time / 0.5, 0.0, 1.0)
	var y := yaw + _vis_yaw_off + _spin_angle + wob
	# 坂に合わせた傾き
	var t := track.tang[idx]
	var pitch := atan2(t.y, Vector2(t.x, t.z).length())
	if not grounded:
		pitch = clampf(vy * 0.03, -0.35, 0.35)
	var steer_roll := -in_steer * 0.06 if spin_time <= 0.0 else 0.0
	if drift_dir != 0:
		steer_roll = drift_dir * 0.12
	_roll = lerpf(_roll, steer_roll, 1.0 - exp(-8.0 * dt)) if dt > 0.0 else steer_roll
	model.basis = Basis.from_euler(Vector3(pitch, y, _roll), EULER_ORDER_YXZ)
	# ボディの揺れ
	body.position.y = sin(_anim_t * 30.0) * 0.015 * clampf(absf(speed) / 20.0, 0.0, 1.0)
	for w in wheels:
		(w as Node3D).rotate_x(-speed * dt / 0.36)
	for fw in front_wheels:
		(fw as Node3D).rotation.y = -in_steer * 0.45
	barrier.visible = shield_time > 0.0
	if barrier.visible:
		barrier.rotation.y += dt * 2.0
		var s := 1.0 + sin(_anim_t * 8.0) * 0.04
		barrier.scale = Vector3(s, s, s)
		if shield_time < 1.5:
			barrier.visible = fmod(_anim_t, 0.2) < 0.12
	# 無敵中は点滅
	model.visible = invuln <= 0.0 or spin_time > 0.0 or fmod(_anim_t, 0.16) < 0.1
	var sh: Node3D = model.get_meta("shadow")
	sh.visible = grounded


# ------------------------------------------------------------------ ハンデ：自動ハンドル補助
## 人の入力 in_steer にコースに沿うハンドル操作を足す。手をはなしていても道なりに走る。
func apply_assist() -> void:
	if not assist or fall_timer >= 0.0:
		return
	var look := 9.0 + absf(speed) * 0.4
	var want_lat := clampf(lat, -track.hw * 0.55, track.hw * 0.55) * 0.7
	var tgt := track.point_at(d + look, want_lat)
	var to := tgt - position
	var diff := wrapf(atan2(-to.x, -to.z) - yaw, -PI, PI)
	var auto := clampf(-diff * 2.4, -1.0, 1.0)
	if drift_dir != 0:
		# ドリフト中は外側にふくらみすぎないように少しだけ助ける
		in_steer = clampf(in_steer + auto * 0.35, -1.0, 1.0)
	elif absf(in_steer) < 0.1:
		in_steer = auto
	else:
		in_steer = clampf(in_steer + auto * 0.45, -1.0, 1.0)


# ------------------------------------------------------------------ LAN対戦：状態の送受信
const PACK_SIZE := 24

func pack() -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(PACK_SIZE)
	a[0] = position.x; a[1] = position.y; a[2] = position.z
	a[3] = yaw; a[4] = move_yaw; a[5] = speed; a[6] = in_steer
	a[7] = d; a[8] = lap; a[9] = rank
	a[10] = drift_dir; a[11] = drift_level
	a[12] = boost_time; a[13] = rocket_time; a[14] = shield_time; a[15] = spin_time; a[16] = slip_time
	a[17] = invuln; a[18] = fall_timer; a[19] = roulette
	a[20] = ItemArt.ORDER.find(item) + 1
	a[21] = item_count
	a[22] = (1 if grounded else 0) + (2 if finished else 0) + (4 if off_road else 0) + (8 if on_ice else 0)
	a[23] = finish_time
	return a


var _net_target := Vector3.ZERO
var _net_time := 0.0

func unpack(a: PackedFloat32Array) -> void:
	_net_target = Vector3(a[0], a[1], a[2])
	if position.distance_to(_net_target) > 12.0:
		position = _net_target   # ワープ（コース復帰など）
	yaw = a[3]; move_yaw = a[4]; speed = a[5]; in_steer = a[6]
	d = a[7]; lap = int(a[8]); rank = int(a[9])
	drift_dir = int(a[10]); drift_level = int(a[11])
	boost_time = a[12]; rocket_time = a[13]; shield_time = a[14]; spin_time = a[15]; slip_time = a[16]
	invuln = a[17]; fall_timer = a[18]; roulette = a[19]
	var ii := int(a[20])
	item = ItemArt.ORDER[ii - 1] if ii > 0 else ""
	item_count = int(a[21])
	var f := int(a[22])
	grounded = f & 1 != 0
	finished = f & 2 != 0
	off_road = f & 4 != 0
	on_ice = f & 8 != 0
	finish_time = a[23]
	progress = (lap - 1) * track.length + d
	_net_time = 0.0


## 子機：受け取った状態から少し先読みしてなめらかに動かす
func puppet_update(dt: float, racing: bool) -> void:
	_anim_t += dt
	_net_time += dt
	var dir := Vector3(-sin(move_yaw), 0.0, -cos(move_yaw))
	var predicted := _net_target + dir * speed * minf(_net_time, 0.15)
	position = position.lerp(predicted, 1.0 - exp(-18.0 * dt))
	idx = track.locate(position, idx)
	var info := track.project(position, idx)
	lat = info.lat
	ground_y = info.y
	if fall_timer >= 0.0:
		_update_visual(dt)
		return
	_effects(racing, dt)
