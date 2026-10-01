extends Node
## 開発用：シーンを表示してスクリーンショットを保存する
var frames := 0
var target := 120
var out := "shot.png"
var shots := []

func _ready() -> void:
	var scene := OS.get_environment("SHOT_SCENE")
	Game.course_index = int(OS.get_environment("SHOT_COURSE")) if OS.get_environment("SHOT_COURSE") != "" else 0
	Game.character_index = int(OS.get_environment("SHOT_CHAR")) if OS.get_environment("SHOT_CHAR") != "" else 0
	target = int(OS.get_environment("SHOT_FRAMES")) if OS.get_environment("SHOT_FRAMES") != "" else 120
	out = OS.get_environment("SHOT_OUT")
	for s in OS.get_environment("SHOT_AT").split(",", false):
		shots.append(int(s))
	if shots.is_empty():
		shots = [target]
	if scene.ends_with("Result.tscn"):
		Game.last_result = [
			{"name": "ライ", "time": 101.2, "player": true, "ci": 0, "ki": 1},
			{"name": "コン", "time": 102.5, "player": false, "ci": 3, "ki": 0},
			{"name": "ミミ", "time": 103.1, "player": false, "ci": 1, "ki": 2},
			{"name": "ガメロン", "time": 105.8, "player": false, "ci": 2, "ki": 0},
			{"name": "ミミJr.", "time": 107.0, "player": false, "ci": 1, "ki": 1},
			{"name": "コンJr.", "time": 109.4, "player": false, "ci": 3, "ki": 2}]
	if OS.get_environment("SHOT_GP") != "":
		# グランプリの途中の状態を作る
		GrandPrix.start(int(OS.get_environment("SHOT_CUP")) if OS.get_environment("SHOT_CUP") != "" else 0)
		GrandPrix.setup_rivals()
		var races := int(OS.get_environment("SHOT_GP"))
		var order := ["r0", "player", "r1", "r2", "r3", "r4"]
		for r in races:
			GrandPrix.race_index = r
			GrandPrix._set_course()
			var res := []
			for k in order:
				res.append({"key": k, "time": 100.0 + res.size()})
			GrandPrix.record_race(res)
			if r == 0:
				order = ["player", "r0", "r2", "r1", "r4", "r3"]
			else:
				order = ["player", "r1", "r0", "r3", "r2", "r4"]
		if scene.ends_with("Race.tscn"):
			GrandPrix.race_index = races
			GrandPrix._set_course()
		if OS.get_environment("SHOT_UNLOCK") != "":
			for c in Game.CUPS:
				Game.trophies[c.id] = [1, 0, 0]
			Game.trophies["stardust"] = [0, 0, 0]
	if OS.get_environment("SHOT_MODE") != "":
		Game.mode = OS.get_environment("SHOT_MODE")
		Game.last_laps = [38.21, 36.95, 37.40]
		Game.last_course_best = true
		Game.ta_best[Game.course().id] = 112.56
	var inst = load(scene).instantiate()
	if "auto_play" in inst:
		inst.auto_play = OS.get_environment("SHOT_AUTO") == "1"
	add_child(inst)

var _t0 := 0
func _process(_d: float) -> void:
	frames += 1
	if OS.get_environment("SHOT_PERF") != "" and frames in [20, 40]:
		if frames == 20:
			_t0 = Time.get_ticks_msec()
		else:
			print("PERF draw=%d prims=%d objs=%d ms/frame=%.0f" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), (Time.get_ticks_msec() - _t0) / 20.0])
	if OS.get_environment("SHOT_LANHOST") != "" and frames == 3:
		Game.settings["player_name"] = "パパ"
		get_child(0)._do_host()
		Net.players[1200] = {"name": "ママ", "ci": 1, "ki": 2, "assist": false, "fast": false}
		Net.players[1300] = {"name": "ゆうと", "ci": 3, "ki": 0, "assist": true, "fast": true}
		Net.players[1400] = {"name": "さくら", "ci": 2, "ki": 1, "assist": true, "fast": false}
		Net.lobby_changed.emit()
	if OS.get_environment("SHOT_OBJ") != "" and frames == 95:
		var r = get_child(0)
		var a := Models.build_slip_ball()
		a.position = r.track.point_at(r.player.d + 9.0, -2.0)
		r.items_node.add_child(a)
		var b := Models.build_spin_ball()
		b.position = r.track.point_at(r.player.d + 9.0, 3.0) + Vector3(0, 0.8, 0)
		r.items_node.add_child(b)
	if OS.get_environment("SHOT_SHIELD") != "" and frames == 90 and get_child(0).player:
		get_child(0).player.shield_time = 30.0
	if OS.get_environment("SHOT_BOOST") != "" and frames >= 80 and frames % 3 == 0 and get_child(0).player:
		get_child(0).player.add_boost(0.4)
	if OS.get_environment("SHOT_PFX") != "" and frames >= 80 and get_child(0).player:
		var pl = get_child(0).player
		for nm in ["p_flame", "p_smoke", "p_dust"]:
			pl.get(nm).emitting = nm == OS.get_environment("SHOT_PFX")
		pl.p_smoke.emitting = OS.get_environment("SHOT_PFX") == "p_smoke"
	if frames in shots and get_child_count() > 0 and "player" in get_child(0) and get_child(0).player:
		var pl = get_child(0).player
		print("SHOTSTATE fall=%.2f inv=%.2f gr=%s y=%.2f gy=%.2f spin=%.2f vis=%s shadow=%s d=%d lat=%.1f" % [pl.fall_timer, pl.invuln, pl.grounded, pl.position.y, pl.ground_y, pl.spin_time, pl.model.visible, pl.model.get_meta("shadow").visible, int(pl.d), pl.lat])
	if (frames + 2) in shots and OS.get_environment("SHOT_HIDE") != "":
		var pl2 = get_child(0).player
		var what := OS.get_environment("SHOT_HIDE")
		if what == "shadow":
			pl2.model.get_meta("shadow").visible = false
		elif what == "particles":
			for ch in pl2.model.get_children():
				if ch is CPUParticles3D:
					ch.visible = false
		elif what == "hud":
			get_child(0).hud.visible = false
		elif what == "noshadow":
			for n in _all(get_tree().root):
				if n is DirectionalLight3D:
					n.shadow_enabled = false
		elif what.begins_with("keep"):
			var keep := int(what.substr(4))
			var idx := 0
			for ch in pl2.model.get_children():
				if ch is CPUParticles3D:
					ch.visible = idx == keep
					if idx == keep:
						print("KEEP ", idx, " emitting=", ch.emitting, " color=", ch.color, " ramp=", ch.color_ramp != null, " amount=", ch.amount)
					idx += 1
		elif what == "player":
			pl2.visible = false
		elif what == "allkarts":
			for k in get_child(0).karts:
				k.visible = false
		elif what == "body":
			pl2.body.visible = false
		print("HIDDEN ", what, " grounded=", pl2.grounded, " vis=", pl2.model.visible, " kart=", pl2.kart_idx)
	if frames in shots and OS.get_environment("SHOT_PROJ") != "":
		var cam: Camera3D = get_viewport().get_camera_3d()
		var target := Vector2(640, 480)
		for n in _all(get_tree().root):
			if n is GeometryInstance3D and n.is_visible_in_tree():
				var gp: Vector3 = n.global_position
				if cam.is_position_behind(gp):
					continue
				var sp := cam.unproject_position(gp)
				if sp.distance_to(target) < 90 and gp.distance_to(cam.global_position) < 14:
					print("PROJ ", n.get_class(), " ", str(n.get_path()).replace("/root/Shot/", ""), " sp=", sp, " dist=%.1f" % gp.distance_to(cam.global_position))
	if frames in shots and OS.get_environment("SHOT_DUMP") != "":
		var r = get_child(0)
		var pl = r.player
		var back := Vector3(sin(pl.yaw), 0, cos(pl.yaw))
		var c: Vector3 = pl.global_position + back * 3.0
		for n in _all(get_tree().root):
			if n is GeometryInstance3D and n.is_visible_in_tree():
				var gp: Vector3 = n.global_position
				if gp.distance_to(c) < 3.5:
					var path := str(n.get_path()).replace("/root/Shot/", "")
					print("NEAR ", n.get_class(), " ", path, " d=%.1f" % gp.distance_to(c))
	if frames in shots:
		var img := get_viewport().get_texture().get_image()
		img.save_png(out.replace(".png", "_%d.png" % frames))
	if frames >= shots.max():
		get_tree().quit()


func _all(n: Node) -> Array:
	var out := [n]
	for ch in n.get_children():
		out.append_array(_all(ch))
	return out
