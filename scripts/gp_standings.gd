extends Control
## グランプリ：レースごとの順位画面（「第2レース終了」→ 合計ポイントが動いて順位が入れかわる）

const ROW_H := 62.0

var rows := {}          # key -> {node, pts_label, bar, rank_label}
var panel_rows: Control
var _t := 0.0
var _phase := 0
var _max_pts := 1.0


func _ready() -> void:
	var cup: Dictionary = GrandPrix.cup()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform vec3 c1; uniform vec3 c2;\nvoid fragment(){ float s = step(0.5, fract((UV.x - UV.y) * 14.0)); COLOR = vec4(mix(c1, c2, UV.y) + s*0.03, 1.0);}"
	gm.shader = sh
	var cc: Color = cup.color
	gm.set_shader_parameter("c1", Vector3(cc.r * 0.5, cc.g * 0.5, cc.b * 0.6))
	gm.set_shader_parameter("c2", Vector3(0.08, 0.1, 0.25))
	bg.material = gm
	add_child(bg)
	var last := GrandPrix.is_last_race()
	var title := "%s  第%dレース終了" % [cup.name, GrandPrix.race_index + 1]
	if last:
		title = "%s  最終レース終了！" % cup.name
	UI.header(self, title, cup.color)

	# 左：このレースの結果
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", UI.box(Color(0.06, 0.1, 0.3, 0.85), 24, 4))
	lp.position = Vector2(40, 115)
	lp.size = Vector2(430, 470)
	add_child(lp)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	lp.add_child(lv)
	var cname: String = Game.course().name
	lv.add_child(UI.label(cname, 30, UI.YELLOW, 8))
	var entry: Array = GrandPrix.history.back()
	for e in entry:
		var h := HBoxContainer.new()
		var is_p: bool = e.key == "player"
		var col := UI.YELLOW if is_p else Color.WHITE
		var pl := UI.label("%d位" % e.place, 28, col, 6)
		pl.custom_minimum_size = Vector2(80, 0)
		h.add_child(pl)
		var nm := UI.label(GrandPrix.name_of(e.key), 28, col, 6)
		nm.custom_minimum_size = Vector2(190, 0)
		h.add_child(nm)
		h.add_child(UI.label("+%dpt" % e.pts, 28, Color(0.5, 1.0, 0.6), 6))
		lv.add_child(h)

	# 右：合計ポイント
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", UI.box(Color(0.06, 0.1, 0.3, 0.85), 24, 4))
	rp.position = Vector2(500, 115)
	rp.size = Vector2(740, 470)
	add_child(rp)
	var rv := VBoxContainer.new()
	rp.add_child(rv)
	var hl := UI.label("順位       合計ポイント", 30, UI.YELLOW, 8)
	rv.add_child(hl)
	panel_rows = Control.new()
	panel_rows.custom_minimum_size = Vector2(700, ROW_H * 6 + 10)
	rv.add_child(panel_rows)
	for k in GrandPrix.points:
		_max_pts = maxf(_max_pts, GrandPrix.points[k])
	_max_pts = maxf(_max_pts, 10.0 * (GrandPrix.race_index + 1) * 0.8)
	# 前回までの合計で並べる
	var prev: Dictionary = GrandPrix.prev_points
	var order := prev.keys()
	order.sort_custom(func(a, b): return prev[a] > prev[b])
	for i in order.size():
		var key: String = order[i]
		_make_row(key, i, prev[key])

	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position = Vector2(-500, -118)
	bottom.size = Vector2(1000, 96)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 24)
	add_child(bottom)
	var quit := UI.button("やめる", Color(0.4, 0.45, 0.6), 26, Vector2(180, 80))
	quit.pressed.connect(func():
		GrandPrix.quit()
		Game.goto_scene("res://scenes/MainMenu.tscn"))
	bottom.add_child(quit)
	if not last:
		var next_id: String = cup.courses[GrandPrix.race_index + 1]
		var nl := UI.label("つぎは  " + Game.COURSES[Game.course_index_of(next_id)].name, 28, Color.WHITE, 8)
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bottom.add_child(nl)
	var go := UI.button("表彰式へ ▶" if last else "次のレースへ ▶", UI.RED if last else UI.GREEN, 36, Vector2(340, 96))
	go.pressed.connect(func():
		if last:
			Game.goto_scene("res://scenes/Podium.tscn")
		else:
			GrandPrix.next_race())
	bottom.add_child(go)
	go.grab_focus()
	Sfx.play_bgm("bgm_result")


func _make_row(key: String, i: int, pts: int) -> void:
	var is_p := key == "player"
	var r := Control.new()
	r.position = Vector2(0, i * ROW_H)
	r.size = Vector2(700, ROW_H - 6)
	panel_rows.add_child(r)
	var bgc := ColorRect.new()
	bgc.color = Color(1, 0.85, 0.2, 0.25) if is_p else Color(1, 1, 1, 0.06)
	bgc.size = r.size
	r.add_child(bgc)
	var rank := UI.label(str(i + 1), 36, Color.WHITE, 8)
	rank.position = Vector2(10, 2)
	r.add_child(rank)
	var sw := ColorRect.new()
	sw.color = Game.CHARACTERS[GrandPrix.char_of(key)].color
	sw.position = Vector2(62, 16)
	sw.size = Vector2(24, 24)
	r.add_child(sw)
	var nm := UI.label(GrandPrix.name_of(key), 30, UI.YELLOW if is_p else Color.WHITE, 8)
	nm.position = Vector2(96, 6)
	r.add_child(nm)
	var bar := ColorRect.new()
	bar.color = UI.YELLOW if is_p else Color(0.4, 0.75, 1.0)
	bar.position = Vector2(300, 18)
	bar.size = Vector2(_bar_w(pts), 22)
	r.add_child(bar)
	var pl := UI.label("%d" % pts, 34, Color.WHITE, 8)
	pl.position = Vector2(620, 2)
	r.add_child(pl)
	rows[key] = {"node": r, "pts": pl, "bar": bar, "rank": rank, "shown": float(pts)}
	_color_rank(rank, i + 1)


func _bar_w(p: float) -> float:
	return maxf(4.0, 300.0 * p / _max_pts)


func _color_rank(l: Label, place: int) -> void:
	l.label_settings = l.label_settings.duplicate()
	l.label_settings.font_color = UI.MEDAL[place - 1] if place <= 3 else Color.WHITE


func _process(delta: float) -> void:
	_t += delta
	if Game.test_auto and _t > 3.0 and _phase >= 0:
		_phase = -9
		var line := "STANDINGS race=%d " % (GrandPrix.race_index + 1)
		for k in GrandPrix.standings():
			line += "%s:%d " % [GrandPrix.name_of(k), GrandPrix.points[k]]
		print(line)
		if GrandPrix.is_last_race():
			Game.goto_scene("res://scenes/Podium.tscn")
		else:
			GrandPrix.next_race()
		return
	if _phase < 0:
		return
	if _phase == 0 and _t > 0.8:
		_phase = 1
		Sfx.play("coin")
	if _phase == 1:
		# ポイントを数え上げる
		var done := true
		for key in rows:
			var row: Dictionary = rows[key]
			var target: float = GrandPrix.points[key]
			row.shown = move_toward(row.shown, target, delta * 14.0)
			if row.shown < target:
				done = false
			(row.pts as Label).text = "%d" % int(round(row.shown))
			(row.bar as ColorRect).size.x = _bar_w(row.shown)
		if done:
			_phase = 2
			_reorder()


func _reorder() -> void:
	var st := GrandPrix.standings()
	for i in st.size():
		var row: Dictionary = rows[st[i]]
		var node: Control = row.node
		var tw := create_tween()
		tw.tween_property(node, "position:y", i * ROW_H, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		(row.rank as Label).text = str(i + 1)
		_color_rank(row.rank, i + 1)
	Sfx.play("item_get", 1.0, -4.0)
