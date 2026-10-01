extends Control
## リザルト画面：順位表とプレイヤーのカート

var stage: MenuStage


func _ready() -> void:
	stage = MenuStage.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	stage.camera.position = Vector3(3.2, 3.0, 8.5)
	stage.camera.look_at(Vector3(3.2, 1.8, 0), Vector3.UP)
	stage.spin_speed = 0.4
	var res: Array = Game.last_result
	var my_rank := 6
	for i in res.size():
		if res[i].player:
			my_rank = i + 1
	var holder := Node3D.new()
	var km := Models.build_kart(Game.kart_index, Game.kart().color.lerp(Game.character().color, 0.55), Game.character_index)
	km.scale = Vector3.ONE * 1.1
	holder.add_child(km)
	holder.rotation.y = PI * 0.75
	stage.show_node(holder)
	var ta := Game.mode == "timeattack"
	if my_rank <= 3 and not ta or ta and Game.last_course_best:
		stage.confetti.emitting = true
	UI.header(self, ("タイムアタック  ―  " if ta else "レースけっか  ―  ") + Game.course().name, UI.YELLOW.darkened(0.1))
	if ta:
		_time_attack()
		return

	var big := UI.label("%d位" % my_rank, 120, [UI.YELLOW, Color(0.85, 0.9, 1.0), Color(1, 0.62, 0.3), Color.WHITE, Color.WHITE, Color.WHITE][my_rank - 1], 24, Color(0.3, 0.15, 0.0))
	big.position = Vector2(60, 110)
	add_child(big)
	var msg: String = ["やったね！ ゆうしょう！", "おしい！ 2位！", "3位 入賞！", "がんばった！", "つぎはがんばろう！", "つぎはがんばろう！"][my_rank - 1]
	var ml := UI.label(msg, 36, Color.WHITE, 10)
	ml.position = Vector2(66, 260)
	add_child(ml)
	if Game.last_course_best:
		var nb := UI.label("ベストタイム こうしん！", 32, Color(1, 0.5, 0.6), 10, Color(0.4, 0.0, 0.1))
		nb.position = Vector2(66, 310)
		add_child(nb)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.14, 0.4, 0.85), 28, 5))
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-560, 108)
	panel.size = Vector2(530, 420)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	for i in res.size():
		var r: Dictionary = res[i]
		var h := HBoxContainer.new()
		var col := UI.YELLOW if r.player else Color.WHITE
		var a := UI.label("%d" % (i + 1), 38, col, 8)
		a.custom_minimum_size = Vector2(56, 0)
		h.add_child(a)
		var sw := ColorRect.new()
		sw.color = Game.CHARACTERS[r.ci].color
		sw.custom_minimum_size = Vector2(22, 22)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
		var tag := "（あなた）" if r.player else ("（CPU）" if Game.mode == "lan" and not r.get("human", false) else "")
		var nm := UI.label("  " + r.name + tag, 30, col, 8)
		nm.custom_minimum_size = Vector2(270, 0)
		h.add_child(nm)
		h.add_child(UI.label(Game.format_time(r.time), 30, col, 8))
		v.add_child(h)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.add_theme_constant_override("separation", 20)
	row.position = Vector2(-450, -130)
	row.size = Vector2(900, 96)
	add_child(row)
	if Game.mode == "lan":
		_lan_buttons(row)
		return
	var b1 := UI.button("もういちど", UI.RED, 34, Vector2(280, 96))
	b1.pressed.connect(func(): Game.goto_scene("res://scenes/Race.tscn"))
	row.add_child(b1)
	var b2 := UI.button("コースをえらぶ", UI.GREEN, 30, Vector2(300, 96))
	b2.pressed.connect(func(): Game.goto_scene("res://scenes/CourseSelect.tscn"))
	row.add_child(b2)
	var b3 := UI.button("タイトルへ", UI.BLUE, 32, Vector2(260, 96))
	b3.pressed.connect(func(): Game.goto_scene("res://scenes/MainMenu.tscn"))
	row.add_child(b3)
	Sfx.play_bgm("bgm_result")
	if my_rank <= 3:
		Sfx.play("goal")


func _time_attack() -> void:
	var t: float = Game.last_result[0].time
	var big := UI.label(Game.format_time(t), 110, UI.YELLOW, 24, Color(0.3, 0.15, 0.0))
	big.position = Vector2(50, 110)
	add_child(big)
	var msg := "ベストタイム こうしん！" if Game.last_course_best else "ベスト  " + Game.format_time(Game.ta_best.get(Game.course().id, -1.0))
	var ml := UI.label(msg, 36, Color(1, 0.55, 0.65) if Game.last_course_best else Color.WHITE, 10)
	ml.position = Vector2(60, 250)
	add_child(ml)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.14, 0.4, 0.85), 28, 5))
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-460, 120)
	panel.size = Vector2(430, 300)
	add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UI.label("ラップタイム", 32, UI.YELLOW, 8))
	var laps: Array = Game.last_laps
	var fastest := INF
	for l in laps:
		fastest = minf(fastest, l)
	for i in laps.size():
		var col := Color(0.5, 1.0, 0.6) if laps[i] == fastest else Color.WHITE
		v.add_child(UI.label("LAP %d    %s" % [i + 1, Game.format_time(laps[i])], 32, col, 8))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.add_theme_constant_override("separation", 20)
	row.position = Vector2(-450, -130)
	row.size = Vector2(900, 96)
	add_child(row)
	var b1 := UI.button("もういちど", UI.RED, 34, Vector2(280, 96))
	b1.pressed.connect(func(): Game.goto_scene("res://scenes/Race.tscn"))
	row.add_child(b1)
	var b2 := UI.button("コースをえらぶ", UI.GREEN, 30, Vector2(300, 96))
	b2.pressed.connect(func(): Game.goto_scene("res://scenes/CourseSelect.tscn"))
	row.add_child(b2)
	var b3 := UI.button("タイトルへ", UI.BLUE, 32, Vector2(260, 96))
	b3.pressed.connect(func(): Game.goto_scene("res://scenes/MainMenu.tscn"))
	row.add_child(b3)
	Sfx.play_bgm("bgm_result")
	if Game.last_course_best:
		Sfx.play("goal")


## LAN対戦の結果：親機は「もういちど」で全員を部屋にもどす
func _lan_buttons(row: HBoxContainer) -> void:
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	Sfx.play_bgm("bgm_result")
	if not Net.active:
		var t := UI.button("タイトルへ", UI.BLUE, 32, Vector2(300, 96))
		t.pressed.connect(func(): Game.goto_scene("res://scenes/MainMenu.tscn"))
		row.add_child(t)
		return
	if Net.is_host:
		var b := UI.button("もういちど（部屋へ）", UI.RED, 30, Vector2(380, 96))
		b.pressed.connect(func(): Net.back_to_lobby())
		row.add_child(b)
	else:
		var w := UI.label("親機がつぎを決めるのを待っています", 26, Color.WHITE, 8)
		w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(w)
	var q := UI.button("ぬける", Color(0.4, 0.45, 0.6), 30, Vector2(200, 96))
	q.pressed.connect(func():
		Net.leave()
		Game.goto_scene("res://scenes/MainMenu.tscn"))
	row.add_child(q)
