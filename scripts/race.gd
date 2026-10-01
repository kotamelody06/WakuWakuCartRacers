extends Node3D
## RaceManager：コース・カート・アイテムを作り、スタート演出からゴールまでを進行する。

const ITEM_TABLE := [
	# 1〜2位
	{"slip": 40, "spin": 25, "barrier": 25, "boost": 10},
	# 3〜4位
	{"boost": 25, "spin": 30, "slip": 20, "barrier": 15, "rocket": 10},
	# 5〜6位
	{"rocket": 35, "boost": 35, "spin": 20, "barrier": 10},
]

@onready var track: Track = $Track
@onready var karts_node: Node3D = $Karts
@onready var boxes_node: Node3D = $ItemBoxes
@onready var items_node: Node3D = $Items
@onready var camera: Camera3D = $Camera3D

var hud: Hud
var karts: Array[Kart] = []
var player: Kart
var state := "intro"       # intro → countdown → race → finish
var state_t := 0.0
var race_time := 0.0
var item_boxes := []       # {node, pos, idx, lat, timer}
var spin_balls := []       # {node, owner, target, d, lat, y, life}
var hazards := []          # すべすべボール {node, pos, d, lat, owner, arm}
var finish_order: Array[Kart] = []
var _shake := 0.0
var _cd_step := 4
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _fov := 70.0
var _intro_from := Vector3.ZERO
var _paused := false
var _final_lap_shown := false
var _finish_wait := 0.0
var auto_play := false     # テスト用（全員CPU）
var respawn_count := 0
var gimmicks: Gimmicks
var obstacles := []        # CPUがよける障害物 {d, lat}
var diff: Dictionary
var lap_times := []        # プレイヤーのラップ（タイムアタック用）
var _lap_start := 0.0
# LAN対戦
var lan := false
var lan_client := false
var _remote_inputs := {}   # peer -> [steer, bits]
var _snap := []            # 子機：最新の状態
var _snap_new := false
var _snap_frame := 0
var _lan_deadline := -1.0
var _prev := {}            # 子機：前回の自分のカートの状態（効果音を出すため）
var _spin_pool: Array[Node3D] = []
var _slip_pool: Array[Node3D] = []
const STATES := ["wait", "intro", "countdown", "race", "finish"]


func _ready() -> void:
	randomize()
	lan = Game.mode == "lan" and Net.active
	lan_client = lan and Net.is_client()
	auto_play = auto_play or Game.test_auto
	diff = Game.diff() if Game.mode != "timeattack" else Game.DIFFICULTIES[1]
	track.build(Game.course(), diff)
	gimmicks = Gimmicks.new()
	add_child(gimmicks)
	gimmicks.setup(self, track, Game.course(), diff)
	_spawn_karts()
	if Game.mode != "timeattack":
		_spawn_item_boxes()
	else:
		player.item = "boost"
		player.item_count = 3
	hud = Hud.new()
	add_child(hud)
	hud.build(self)
	hud.touch.visible = false
	Sfx.play_bgm("bgm_" + Game.course().id)
	_intro_from = track.point_at(40.0, 0.0) + Vector3(0, 25, 0)
	snap_camera()
	var title: String = Game.course().name
	if Game.mode == "grandprix":
		title = "%s  第%dレース\n%s" % [GrandPrix.cup().name, GrandPrix.race_index + 1, title]
	elif Game.mode == "timeattack":
		title = "タイムアタック\n" + title
	elif lan:
		title = "みんなで対戦\n" + title
		state = "wait"
		Net.send_loaded()
	hud.message(title, 2.6, UI.YELLOW)


func _spawn_karts() -> void:
	var order := []
	if Game.mode == "grandprix":
		# グランプリ：4レースを通して同じライバル。並び順は合計ポイントで決まる
		for key in GrandPrix.grid_keys():
			order.append({"name": Game.character().name if key == "player" else GrandPrix.name_of(key),
				"ci": GrandPrix.char_of(key), "ki": GrandPrix.kart_of(key), "player": key == "player", "key": key})
	elif Game.mode == "timeattack":
		order.append({"name": Game.character().name, "ci": Game.character_index, "ki": Game.kart_index, "player": true, "key": "player",
			"human": true, "hc": Game.handicap})
	elif lan:
		# LAN対戦：CPUが前、人は後ろからスタート（どの端末でも同じ並びになるように）
		var rng := RandomNumberGenerator.new()
		rng.seed = Game.course_index * 31 + Net.roster.size()
		var cpu_count := (Game.RACER_COUNT - Net.roster.size()) if Net.room.cpu else 0
		var used := []
		for r in Net.roster:
			used.append(r.ci)
		for c in cpu_count:
			var ci := c % Game.CHARACTERS.size()
			order.append({"name": Game.CHARACTERS[ci].name + ("Jr." if ci in used else ""), "ci": ci, "ki": rng.randi() % Game.STANDARD_KARTS,
				"player": false, "key": "c%d" % c, "human": false, "peer": 0})
		for r in Net.roster:
			order.append({"name": r.name, "ci": r.ci, "ki": r.ki, "player": r.peer == Net.my_id, "key": "p%d" % r.peer,
				"human": true, "peer": r.peer, "hc": {"assist": r.assist, "fast": r.fast}})
	else:
		# CPUキャラクター：プレイヤー以外の3人＋色違い
		var roster := []
		for i in Game.CHARACTERS.size():
			if i != Game.character_index:
				roster.append([Game.CHARACTERS[i].name, i])
		var extra := 0
		while roster.size() < Game.RACER_COUNT - 1:
			var ci := (Game.character_index + 1 + extra) % Game.CHARACTERS.size()
			roster.append([Game.CHARACTERS[ci].name + "Jr.", ci])
			extra += 1
		roster.shuffle()
		for r in roster:
			order.append({"name": r[0], "ci": r[1], "ki": randi() % Game.STANDARD_KARTS, "player": false, "key": ""})
		order.append({"name": Game.character().name, "ci": Game.character_index, "ki": Game.kart_index, "player": true, "key": "player",
			"human": true, "hc": Game.handicap})
	for g in order.size():
		var row := g / 2
		var col := g % 2
		var dist := track.length - 8.0 - row * 9.0
		var lat := (-1 if col == 0 else 1) * track.hw * 0.4
		var p := track.point_at(dist, lat)
		var fwd := track.dir_at(dist)
		var k := Kart.new()
		k.name = "Player" if order[g].player else "CPU%d" % g
		karts_node.add_child(k)
		var o: Dictionary = order[g]
		var hc: Dictionary = o.get("hc", Game.handicap if o.player else {})
		k.setup(self, track, o.name, o.ci, o.ki, o.player, o.get("human", o.player), hc)
		if lan and o.get("human", false) and not o.player:
			k.remote_peer = o.peer
		k.place(p, atan2(-fwd.x, -fwd.z))
		k.setup_audio()
		k.gp_key = order[g].key
		if k.brain:
			k.brain.configure(diff)
		if order[g].player:
			player = k
			if auto_play:
				k.brain = CpuBrain.new()
				k.brain.configure(Game.DIFFICULTIES[1])
		karts.append(k)
	_update_ranks()


func _spawn_item_boxes() -> void:
	for row_i: int in track.item_rows:
		var d := row_i * track.ds
		for k in 4:
			var lat := (-0.66 + k * 0.44) * track.hw
			var pos := track.point_at(d, lat) + Vector3(0, 1.3, 0)
			var b := Models.build_item_box()
			b.position = pos
			boxes_node.add_child(b)
			item_boxes.append({"node": b, "pos": pos, "timer": 0.0})


# ------------------------------------------------------------------ 進行
func _physics_process(dt: float) -> void:
	if _paused or not is_inside_tree():
		return
	if lan_client:
		_client_process(dt)
		return
	state_t += dt
	match state:
		"wait":
			if Net.all_loaded() or state_t > 12.0:
				_set_state("intro")
		"intro":
			if state_t > 2.6 or Input.is_action_just_pressed("accel") and state_t > 0.5:
				_set_state("countdown")
				hud.touch.visible = true
		"countdown":
			var step := 3 - int(state_t)
			if step != _cd_step and step >= 1:
				_cd_step = step
				hud.set_countdown(step)
				Sfx.play("beep")
			if state_t >= 3.0:
				_set_state("race")
				hud.set_countdown(0)
				Sfx.play("go")
				shake(0.6)
				for k in karts:
					k.smoke_puff()
					if k.engine_player:
						k.engine_player.play()
				hud.set_speed_effect(1.0)
				get_tree().create_timer(0.8).timeout.connect(func(): if player.boost_time <= 0.0: hud.set_speed_effect(0.0))
		"race":
			race_time += dt
			if lan and _lan_deadline > 0.0 and race_time > _lan_deadline:
				_set_state("finish")
		"finish":
			race_time += dt
			_finish_wait += dt
			if _finish_wait > 5.0:
				_go_result()
				return
	var racing := state == "race" or state == "finish"
	var lead := player.progress
	if lan:
		for k in karts:
			if k.is_human:
				lead = maxf(lead, k.progress)
	# 入力
	for k in karts:
		if k.brain and (not k.is_human or k.finished or auto_play):
			k.brain.think(k, dt)
			if k.is_human and not auto_play and k.finished:
				k.in_item = false
		elif k.is_player:
			_player_input(k)
			k.apply_assist()
		elif k.remote_peer != 0:
			var inp: Array = _remote_inputs.get(k.remote_peer, [0.0, 0])
			k.in_steer = inp[0]
			k.in_accel = inp[1] & 1 != 0
			k.in_brake = inp[1] & 2 != 0
			k.in_drift = inp[1] & 4 != 0
			k.in_item = inp[1] & 8 != 0
			k.apply_assist()
		# プレイヤー追跡（ラバーバンド）
		if not k.is_human:
			var gap := lead - k.progress
			k.speed_mult = k.brain.skill * float(diff.cpu_speed) * (1.0 + clampf(gap / 400.0, -float(diff.rubber_down), float(diff.rubber_up)))
		else:
			k.speed_mult = 1.0
	gimmicks.update(dt)
	obstacles = gimmicks.obstacle_list()
	for k in karts:
		k.step(dt, racing)
	_kart_collisions()
	_update_item_boxes(dt)
	_update_spin_balls(dt)
	_update_hazards(dt)
	_update_ranks()
	_update_camera(dt)
	if player.boost_time > 0.0 or player.rocket_time > 0.0:
		hud.set_speed_effect(1.0)
	elif state == "race" and state_t > 0.8:
		hud.set_speed_effect(0.0)
	if lan:
		_snap_frame += 1
		if _snap_frame % 2 == 0:
			Net.send_snapshot(_make_snapshot())


func _player_input(k: Kart) -> void:
	var s := 0.0
	if Input.is_action_pressed("left"):
		s -= 1.0
	if Input.is_action_pressed("right"):
		s += 1.0
	k.in_steer = s
	k.in_accel = Input.is_action_pressed("accel") or (Game.settings.auto_accel and not Input.is_action_pressed("brake"))
	k.in_brake = Input.is_action_pressed("brake")
	k.in_drift = Input.is_action_pressed("drift")
	k.in_item = Input.is_action_pressed("item")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(not _paused)


func set_paused(on: bool) -> void:
	if state == "finish" and on:
		return
	if lan:
		# LAN対戦ではレースは止めない（メニューだけ出す）
		hud.show_pause(on)
		return
	_paused = on
	get_tree().paused = on
	hud.show_pause(on)


func _set_state(s: String) -> void:
	state = s
	state_t = 0.0


func on_lap(k: Kart) -> void:
	if k.finished:
		return
	if k == player and k.lap >= 2:
		lap_times.append(race_time - _lap_start)
		_lap_start = race_time
		if Game.mode == "timeattack":
			hud.popup("LAP %d  %s" % [k.lap - 1, Game.format_time(lap_times.back())], Color(1, 1, 0.7), 1.5)
	if k.lap > Game.TOTAL_LAPS:
		k.finished = true
		k.finish_time = race_time
		finish_order.append(k)
		if lan:
			_lan_finished(k)
		elif k == player:
			_player_finished()
	elif k == player and k.lap == Game.TOTAL_LAPS and not _final_lap_shown and state == "race":
		_final_lap_shown = true
		hud.message("ファイナルラップ！", 2.0, UI.YELLOW)
		Sfx.play("item_get", 0.8)
	elif k == player and k.lap >= 2 and state == "race":
		hud.message("LAP %d" % k.lap, 1.2, Color.WHITE)


func _player_finished() -> void:
	_set_state("finish")
	Sfx.play("goal")
	hud.message("GOAL!!", 4.0, UI.YELLOW)
	hud.touch.visible = false
	player.brain = CpuBrain.new()
	player.brain.configure(Game.DIFFICULTIES[1])
	Sfx.play_bgm("bgm_result")


func _go_result() -> void:
	# 残りのカートは今の位置から予想タイムを出す
	var res := []
	for k in finish_order:
		res.append({"name": k.racer_name, "time": k.finish_time, "player": k.is_player, "ci": k.char_idx, "ki": k.kart_idx, "key": k.gp_key,
			"human": k.is_human, "peer": int(k.gp_key.substr(1)) if k.gp_key.begins_with("p") else 0})
	var rest: Array[Kart] = []
	for k in karts:
		if not k.finished:
			rest.append(k)
	rest.sort_custom(func(a, b): return a.progress > b.progress)
	for k in rest:
		var remain: float = Game.TOTAL_LAPS * track.length - k.progress
		var est: float = race_time + remain / max(k.stats.max_speed * 0.85, 1.0)
		res.append({"name": k.racer_name, "time": est, "player": k.is_player, "ci": k.char_idx, "ki": k.kart_idx, "key": k.gp_key,
			"human": k.is_human, "peer": int(k.gp_key.substr(1)) if k.gp_key.begins_with("p") else 0})
	# 予想タイムの矛盾をなくす
	for i in range(1, res.size()):
		if res[i].time <= res[i - 1].time:
			res[i].time = res[i - 1].time + randf_range(0.3, 1.5)
	Game.last_result = res
	Game.last_laps = lap_times.duplicate()
	var cid: String = Game.course().id
	Game.last_course_best = false
	if player.finished:
		var table: Dictionary = Game.ta_best if Game.mode == "timeattack" else Game.best_times
		var best: float = table.get(cid, INF)
		if player.finish_time < best:
			table[cid] = player.finish_time
			Game.last_course_best = true
		Game.save_data()
	if lan:
		Net.send_results(res)
		return
	if Game.mode == "grandprix" and GrandPrix.active:
		GrandPrix.record_race(res)
		Game.goto_scene("res://scenes/GPStandings.tscn")
	else:
		Game.goto_scene("res://scenes/Result.tscn")


func _update_ranks() -> void:
	var list := karts.duplicate()
	list.sort_custom(func(a: Kart, b: Kart):
		if a.finished and b.finished:
			return a.finish_time < b.finish_time
		if a.finished != b.finished:
			return a.finished
		return a.progress > b.progress)
	for i in list.size():
		list[i].rank = i + 1


# ------------------------------------------------------------------ 衝突
func _kart_collisions() -> void:
	for i in karts.size():
		var a := karts[i]
		if a.fall_timer >= 0.0:
			continue
		for j in range(i + 1, karts.size()):
			var b := karts[j]
			if b.fall_timer >= 0.0:
				continue
			var dv := Vector3(b.position.x - a.position.x, 0, b.position.z - a.position.z)
			var dist := dv.length()
			if dist < 2.1 and absf(a.position.y - b.position.y) < 1.6 and dist > 0.001:
				var nrm := dv / dist
				var push := (2.1 - dist) * 0.5 + 0.02
				a.position -= nrm * push
				b.position += nrm * push
				# ぶつかる勢い（お互いに近づく速さ）
				var va := Vector3(-sin(a.move_yaw), 0, -cos(a.move_yaw)) * a.speed
				var vb := Vector3(-sin(b.move_yaw), 0, -cos(b.move_yaw)) * b.speed
				var closing := (va - vb).dot(nrm)
				# ロケット中は相手をはじく
				if a.rocket_time > 0.0 and b.rocket_time <= 0.0:
					b.hit_spin()
				elif b.rocket_time > 0.0 and a.rocket_time <= 0.0:
					a.hit_spin()
				elif closing > 3.0 and a._wall_cd <= 0.0 and b._wall_cd <= 0.0:
					# 追突：速度を少し分け合う（重さの差は最高速度で近似）
					var sa := a.speed
					a.speed = lerpf(sa, b.speed, 0.3)
					b.speed = lerpf(b.speed, sa, 0.3)
					a._wall_cd = 0.35
					b._wall_cd = 0.35
					if a.is_player or b.is_player:
						a._spark_burst()
						Sfx.play("crash", 1.4, -3.0)
						if a.is_player or b.is_player:
							shake(0.15)


# ------------------------------------------------------------------ アイテム
func roll_item(k: Kart) -> String:
	var tbl: Dictionary = ITEM_TABLE[0 if k.rank <= 2 else (1 if k.rank <= 4 else 2)]
	var total := 0
	for key in tbl:
		total += tbl[key]
	var r := randi() % total
	for key in tbl:
		r -= tbl[key]
		if r < 0:
			return key
	return "boost"


func _update_item_boxes(dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for b in item_boxes:
		var node: Node3D = b.node
		if b.timer > 0.0:
			b.timer -= dt
			if b.timer <= 0.0:
				node.visible = true
				node.scale = Vector3(0.1, 0.1, 0.1)
			continue
		node.scale = node.scale.lerp(Vector3.ONE, 1.0 - exp(-6.0 * dt))
		node.position = b.pos + Vector3(0, sin(t * 2.5 + b.pos.x) * 0.25, 0)
		var cube: Node3D = node.get_node("Cube")
		cube.rotation = Vector3(t * 0.9, t * 1.4, t * 0.5)
		var m: StandardMaterial3D = cube.material_override
		m.emission = Color.from_hsv(fmod(t * 0.25, 1.0), 0.6, 1.0)
		for k in karts:
			if k.fall_timer >= 0.0:
				continue
			if k.position.distance_to(node.position - Vector3(0, 0.9, 0)) < 2.3:
				node.visible = false
				b.timer = 2.5
				_box_burst(node.position)
				if k.item == "" and k.roulette <= 0.0:
					k.give_item(roll_item(k))
				break


func _box_burst(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 16
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -10, 0)
	var q := BoxMesh.new()
	q.size = Vector3(0.25, 0.25, 0.25)
	p.mesh = q
	p.color = Color(0.6, 0.85, 1.0)
	p.material_override = Kart._particle_mat()
	p.position = pos
	items_node.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func use_item(k: Kart, it: String) -> void:
	match it:
		"boost":
			k.add_boost(1.8)
		"rocket":
			k.rocket_time = 2.4
			k.end_drift(false)
			if k.is_player:
				Sfx.play("boost", 0.8)
				hud.popup("ロケットダッシュ！", Color(1, 0.45, 0.3))
		"barrier":
			k.shield_time = 7.0
			if k.is_player or k.position.distance_to(player.position) < 25.0:
				Sfx.play("shield", 1.0, 0.0 if k.is_player else -8.0)
		"spin":
			var target: Kart = null
			for o in karts:
				if o != k and o.rank == k.rank - 1 and not o.finished:
					target = o
			var n := Models.build_spin_ball()
			items_node.add_child(n)
			spin_balls.append({"node": n, "owner": k, "target": target, "d": k.d + 3.0, "lat": k.lat,
				"y": k.position.y + 0.8, "life": 6.0})
			if k.is_player or k.position.distance_to(player.position) < 25.0:
				Sfx.play("throw", 1.0, 0.0 if k.is_player else -6.0)
		"slip":
			var back := Vector3(sin(k.yaw), 0, cos(k.yaw)) * 2.8
			var pos := k.position + back
			var n2 := Models.build_slip_ball()
			n2.position = pos
			items_node.add_child(n2)
			var i := track.locate(pos, k.idx)
			var info := track.project(pos, i)
			hazards.append({"node": n2, "pos": pos, "d": info.d, "lat": info.lat, "owner": k, "arm": 0.6})
			if k.is_player:
				Sfx.play("throw", 0.7)


func _update_spin_balls(dt: float) -> void:
	for sb in spin_balls.duplicate():
		sb.life -= dt
		var node: Node3D = sb.node
		var target: Kart = sb.target
		sb.d += 48.0 * dt
		if target and is_instance_valid(target):
			var dd: float = fposmod(target.d - sb.d, track.length)
			var close := dd < 40.0 or dd > track.length - 5.0
			sb.lat = lerpf(sb.lat, target.lat, 1.0 - exp(-(4.0 if close else 1.0) * dt))
		var pos := track.point_at(sb.d, sb.lat)
		pos.y += 0.8 + absf(sin(sb.life * 10.0)) * 0.4
		node.position = pos
		node.rotation.y += dt * 12.0
		var hit := false
		for o in karts:
			if o == sb.owner and sb.life > 5.5:
				continue
			if o.position.distance_to(pos) < 2.2:
				if o.hit_spin():
					if o == player:
						hud.popup("くるくる～！", Color(0.4, 0.7, 1.0))
					elif sb.owner == player:
						hud.popup("ヒット！", UI.YELLOW, 0.8)
				hit = true
				break
		if hit or sb.life <= 0.0:
			_box_burst(node.position)
			node.queue_free()
			spin_balls.erase(sb)


func _update_hazards(dt: float) -> void:
	for h in hazards.duplicate():
		h.arm -= dt
		var node: Node3D = h.node
		node.rotation.y += dt
		for o in karts:
			if o == h.owner and h.arm > 0.0:
				continue
			var dv: Vector3 = o.position - h.pos
			if Vector2(dv.x, dv.z).length() < 1.8 and absf(dv.y) < 1.5:
				if o.hit_slip():
					if o == player:
						hud.popup("つるっ！", UI.YELLOW)
				node.queue_free()
				hazards.erase(h)
				break


# ------------------------------------------------------------------ カメラ
func shake(amount: float) -> void:
	if Game.settings.cam_shake:
		_shake = max(_shake, amount)


func on_player_boost() -> void:
	hud.set_speed_effect(1.0)
	shake(0.15)


func snap_camera() -> void:
	_cam_pos = _cam_target_pos()
	_cam_look = player.position + Vector3(0, 1.2, 0)
	camera.position = _cam_pos
	camera.look_at(_cam_look, Vector3.UP)


func _cam_target_pos() -> Vector3:
	var yaw := lerp_angle(player.move_yaw, player.yaw, 0.4)
	var back := Vector3(sin(yaw), 0, cos(yaw))
	return player.position + back * 7.2 + Vector3(0, 3.1, 0)


func _update_camera(dt: float) -> void:
	if state == "intro" or state == "wait":
		# スタート前にコースを見せる
		# 運転手の顔の前から、ぐるっと回ってカートの後ろへ
		var t := clampf(state_t / 2.6, 0.0, 1.0) if state == "intro" else 0.0
		var e := t * t * (3.0 - 2.0 * t)
		var ang := player.yaw + PI * (1.0 - e) * 0.92
		var rad := lerpf(5.5, 7.2, e)
		var hgt := lerpf(1.6, 3.1, e)
		camera.position = player.position + Vector3(sin(ang), 0, cos(ang)) * rad + Vector3(0, hgt, 0)
		camera.look_at(player.position + Vector3(0, lerpf(1.3, 1.2, e), 0), Vector3.UP)
		_cam_pos = camera.position
		_cam_look = player.position + Vector3(0, 1.2, 0)
		return
	var target := _cam_target_pos()
	if player.fall_timer >= 0.0:
		target = _cam_pos
	_cam_pos = _cam_pos.lerp(target, 1.0 - exp(-9.0 * dt))
	# 地面にめり込まない
	_cam_pos.y = max(_cam_pos.y, player.ground_y + 1.5)
	var look := player.position + Vector3(0, 1.3, 0) + Vector3(-sin(player.yaw), 0, -cos(player.yaw)) * 3.0
	_cam_look = _cam_look.lerp(look, 1.0 - exp(-12.0 * dt))
	var shake_off := Vector3.ZERO
	if _shake > 0.0:
		_shake = max(0.0, _shake - dt * 1.4)
		shake_off = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.5
	camera.position = _cam_pos + shake_off
	camera.look_at(_cam_look, Vector3.UP)
	var ratio := clampf(absf(player.speed) / player.stats.max_speed, 0.0, 1.6)
	var want := 68.0 + ratio * 8.0 + (10.0 if player.boost_time > 0.0 or player.rocket_time > 0.0 else 0.0)
	_fov = lerpf(_fov, want, 1.0 - exp(-4.0 * dt))
	camera.fov = _fov


# ------------------------------------------------------------------ LAN対戦（親機）
func _lan_finished(k: Kart) -> void:
	if k.is_human:
		# ゴールした人のカートはCPUが運転を続ける
		k.brain = CpuBrain.new()
		k.brain.configure(Game.DIFFICULTIES[1])
		if _lan_deadline < 0.0:
			_lan_deadline = race_time + 45.0
	if k == player:
		Sfx.play("goal")
		hud.message("GOAL!!", 4.0, UI.YELLOW)
		hud.touch.visible = false
		Sfx.play_bgm("bgm_result")
	var all_done := true
	for o in karts:
		if o.is_human and not o.finished:
			all_done = false
	if all_done and state == "race":
		_set_state("finish")


func remote_input(peer: int, steer: float, bits: int) -> void:
	_remote_inputs[peer] = [steer, bits]


## 子機がぬけた：そのカートはCPUにまかせる
func on_peer_left(peer: int) -> void:
	for k in karts:
		if k.remote_peer == peer:
			k.remote_peer = 0
			k.brain = CpuBrain.new()
			k.brain.configure(diff)
			hud.popup("%s がぬけました" % k.racer_name, Color(1, 0.7, 0.5), 2.0)


func _make_snapshot() -> Array:
	var ks := []
	for k in karts:
		ks.append(k.pack())
	var mask := 0
	for i in item_boxes.size():
		if item_boxes[i].timer > 0.0:
			mask |= 1 << i
	var objs := PackedFloat32Array()
	for sb in spin_balls:
		var p: Vector3 = sb.node.position
		objs.append_array([0.0, p.x, p.y, p.z])
	for h in hazards:
		var p2: Vector3 = h.pos
		objs.append_array([1.0, p2.x, p2.y, p2.z])
	return [STATES.find(state), state_t, race_time, ks, mask, objs, gimmicks._t]


# ------------------------------------------------------------------ LAN対戦（子機）
func apply_snapshot(data: Array) -> void:
	_snap = data
	_snap_new = true


func _client_process(dt: float) -> void:
	if _snap_new and _snap.size() >= 7:
		_snap_new = false
		var new_state: String = STATES[clampi(int(_snap[0]), 0, STATES.size() - 1)]
		if new_state != state:
			_client_state_changed(state, new_state)
			state = new_state
		state_t = _snap[1]
		race_time = _snap[2]
		var ks: Array = _snap[3]
		for i in mini(ks.size(), karts.size()):
			karts[i].unpack(ks[i])
		var mask: int = _snap[4]
		for i in item_boxes.size():
			var hidden := mask & (1 << i) != 0
			if item_boxes[i].node.visible == hidden:
				if hidden and player.position.distance_to(item_boxes[i].node.position) < 25.0:
					_box_burst(item_boxes[i].node.position)
				item_boxes[i].node.visible = not hidden
		_client_objects(_snap[5])
		if absf(gimmicks._t - float(_snap[6])) > 0.25:
			gimmicks._t = _snap[6]
	else:
		state_t += dt
		if state == "race" or state == "finish":
			race_time += dt
	if state == "countdown":
		var step := 3 - int(state_t)
		if step != _cd_step and step >= 1:
			_cd_step = step
			hud.set_countdown(step)
			Sfx.play("beep")
	var racing := state == "race" or state == "finish"
	# 自分の操作を親機へ
	if not player.finished:
		if auto_play and player.brain:
			player.brain.think(player, dt)
		else:
			_player_input(player)
		Net.send_input(player.in_steer, player.in_accel, player.in_brake, player.in_drift, player.in_item)
	for k in karts:
		k.puppet_update(dt, racing)
	gimmicks.update(dt, false)
	_client_box_anim()
	_client_events()
	_update_camera(dt)
	if player.boost_time > 0.0 or player.rocket_time > 0.0:
		hud.set_speed_effect(1.0)
	elif state == "race" and state_t > 0.8:
		hud.set_speed_effect(0.0)


func _client_state_changed(old: String, new: String) -> void:
	if new == "intro" or new == "countdown":
		hud.touch.visible = true
	if new == "race":
		hud.set_countdown(0)
		Sfx.play("go")
		shake(0.6)
		for k in karts:
			k.smoke_puff()
		hud.set_speed_effect(1.0)


func _client_box_anim() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for b in item_boxes:
		var node: Node3D = b.node
		if not node.visible:
			continue
		node.position = b.pos + Vector3(0, sin(t * 2.5 + b.pos.x) * 0.25, 0)
		var cube: Node3D = node.get_node("Cube")
		cube.rotation = Vector3(t * 0.9, t * 1.4, t * 0.5)


func _client_objects(objs: PackedFloat32Array) -> void:
	var ns := 0
	var nh := 0
	var i := 0
	while i + 3 < objs.size():
		var p := Vector3(objs[i + 1], objs[i + 2], objs[i + 3])
		if objs[i] < 0.5:
			if ns >= _spin_pool.size():
				var n := Models.build_spin_ball()
				items_node.add_child(n)
				_spin_pool.append(n)
			_spin_pool[ns].position = p
			_spin_pool[ns].rotation.y += 0.4
			_spin_pool[ns].visible = true
			ns += 1
		else:
			if nh >= _slip_pool.size():
				var n2 := Models.build_slip_ball()
				items_node.add_child(n2)
				_slip_pool.append(n2)
			_slip_pool[nh].position = p
			_slip_pool[nh].visible = true
			nh += 1
		i += 4
	for k in range(ns, _spin_pool.size()):
		_spin_pool[k].visible = false
	for k in range(nh, _slip_pool.size()):
		_slip_pool[k].visible = false


## 子機：自分のカートの変化から効果音や文字を出す
func _client_events() -> void:
	var p := player
	var pv: Dictionary = _prev
	if not pv.is_empty():
		if p.roulette > 0.0 and pv.roulette <= 0.0:
			Sfx.play("item_get")
		if p.item != "" and pv.item == "" and p.roulette <= 0.0:
			Sfx.play("item_get", 1.3)
		if p.item_count < pv.item_count and pv.item in ["spin", "slip"]:
			Sfx.play("throw")
		if p.boost_time > pv.boost_time + 0.2:
			Sfx.play("boost")
			on_player_boost()
		if p.rocket_time > pv.rocket_time + 0.2:
			Sfx.play("boost", 0.8)
			hud.popup("ロケットダッシュ！", Color(1, 0.45, 0.3))
		if p.shield_time > pv.shield_time + 0.2:
			Sfx.play("shield")
		if p.spin_time > pv.spin_time + 0.2:
			Sfx.play("spin")
			hud.popup("くるくる～！", Color(0.4, 0.7, 1.0))
		if p.slip_time > pv.slip_time + 0.2:
			Sfx.play("spin", 1.3)
			hud.popup("つるっ！", UI.YELLOW)
		if p.fall_timer >= 0.0 and pv.fall_timer < 0.0:
			Sfx.play("crash", 0.7)
			hud.popup("コースアウト！", Color(1, 0.5, 0.3), 1.2)
		if p.drift_level > pv.drift_level and p.drift_level > 0:
			Sfx.play("roulette", 0.8 + p.drift_level * 0.25)
		if p.lap > pv.lap and p.lap >= 2 and not p.finished:
			if p.lap == Game.TOTAL_LAPS:
				hud.message("ファイナルラップ！", 2.0, UI.YELLOW)
				Sfx.play("item_get", 0.8)
			else:
				hud.message("LAP %d" % p.lap, 1.2, Color.WHITE)
		if p.finished and not pv.finished:
			Sfx.play("goal")
			hud.message("GOAL!!", 4.0, UI.YELLOW)
			hud.touch.visible = false
			Sfx.play_bgm("bgm_result")
	_prev = {"roulette": p.roulette, "item": p.item, "item_count": p.item_count, "boost_time": p.boost_time, "rocket_time": p.rocket_time,
		"shield_time": p.shield_time, "spin_time": p.spin_time, "slip_time": p.slip_time, "fall_timer": p.fall_timer,
		"drift_level": p.drift_level, "lap": p.lap, "finished": p.finished}
