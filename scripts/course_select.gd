extends Control
## コース選択の画面（1レース・タイムアタック用）。カップのタブで12コースを切り替える。

var tabs: Array[Button] = []
var row: HBoxContainer
var cards: Array[Button] = []
var card_ids: Array[int] = []
var info: Label
var cup_i := 0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ float t = UV.y; vec3 a = vec3(0.2,0.55,1.0); vec3 b = vec3(0.65,0.9,1.0); float s = step(0.5, fract((UV.x - UV.y) * 18.0)); COLOR = vec4(mix(a,b,t) + s*0.035, 1.0);}"
	gm.shader = sh
	bg.material = gm
	add_child(bg)
	UI.header(self, "タイムアタック ― コースをえらぼう！" if Game.mode == "timeattack" else "コースをえらぼう！", UI.GREEN)
	# カップのタブ
	var tabrow := HBoxContainer.new()
	tabrow.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tabrow.position = Vector2(-(300 * 3 + 24) * 0.5, 100)
	tabrow.add_theme_constant_override("separation", 12)
	add_child(tabrow)
	for i in Game.CUPS.size():
		var b := UI.button(Game.CUPS[i].name, Game.CUPS[i].color, 24, Vector2(300, 62))
		b.pressed.connect(_show_cup.bind(i))
		tabrow.add_child(b)
		tabs.append(b)
	row = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.add_theme_constant_override("separation", 18)
	row.position = Vector2(-(280 * 4 + 54) * 0.5, -178)
	row.size = Vector2(280 * 4 + 54, 330)
	add_child(row)
	info = UI.label("", 26, Color.WHITE, 8)
	info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.position = Vector2(-400, -205)
	info.size = Vector2(800, 40)
	add_child(info)
	if Game.mode != "timeattack":
		var drow := UI.difficulty_row(func(): pass)
		drow.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		drow.position = Vector2(-300, -150)
		add_child(drow)
	var back := UI.button("もどる", Color(0.4, 0.45, 0.6), 30, Vector2(220, 84))
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.position = Vector2(30, -110)
	back.pressed.connect(func(): Game.goto_scene("res://scenes/KartSelect.tscn"))
	add_child(back)
	var go := UI.button("スタート！", UI.RED, 40, Vector2(260, 96))
	go.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	go.position = Vector2(-290, -120)
	go.pressed.connect(func():
		Game.save_data()
		Game.goto_scene("res://scenes/Race.tscn"))
	add_child(go)
	var cid: String = Game.course().id
	for i in Game.CUPS.size():
		if cid in Game.CUPS[i].courses:
			cup_i = i
	_show_cup(cup_i, false)
	Sfx.play_bgm("bgm_title")


func _show_cup(ci: int, sound := true) -> void:
	cup_i = ci
	for k in tabs.size():
		var on := k == ci
		tabs[k].add_theme_stylebox_override("normal", UI.box(Game.CUPS[k].color if on else Game.CUPS[k].color.darkened(0.45), 22, 6 if on else 3, UI.YELLOW if on else Color.WHITE))
	for c in row.get_children():
		c.queue_free()
	cards.clear()
	card_ids.clear()
	var col: Color = Game.CUPS[ci].color
	for id in Game.CUPS[ci].courses:
		var idx := Game.course_index_of(id)
		var c: Dictionary = Game.COURSES[idx]
		var b := Button.new()
		b.custom_minimum_size = Vector2(280, 330)
		UI.style_button(b, col, 28)
		b.pressed.connect(_select.bind(idx))
		row.add_child(b)
		cards.append(b)
		card_ids.append(idx)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 12
		v.offset_right = -12
		v.offset_top = 10
		v.offset_bottom = -10
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 2)
		b.add_child(v)
		var n := UI.label(c.name, 28 if c.name.length() < 9 else 22, Color.WHITE, 8, col.darkened(0.6))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
		var map := CourseMap.new()
		map.course = c
		map.custom_minimum_size = Vector2(250, 170)
		map.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(map)
		var lv := UI.label("%s  %s" % [c.level, UI.stars(c.stars, 3)], 22, UI.YELLOW, 6, col.darkened(0.6))
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lv)
		var table: Dictionary = Game.ta_best if Game.mode == "timeattack" else Game.best_times
		var best := UI.label("ベスト %s" % Game.format_time(table.get(c.id, -1.0)), 22, Color.WHITE, 6, col.darkened(0.6))
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(best)
	var sel := Game.course_index if Game.course_index in card_ids else card_ids[0]
	await get_tree().process_frame
	_select(sel, sound)


func _select(idx: int, sound := true) -> void:
	Game.course_index = idx
	var col: Color = Game.CUPS[cup_i].color
	for k in cards.size():
		var on := card_ids[k] == idx
		cards[k].pivot_offset = cards[k].size * 0.5
		cards[k].scale = Vector2(1.05, 1.05) if on else Vector2(0.95, 0.95)
		cards[k].modulate = Color.WHITE if on else Color(0.85, 0.85, 0.9)
		cards[k].add_theme_stylebox_override("normal", UI.box(col, 26, 8 if on else 4, UI.YELLOW if on else Color.WHITE))
	info.text = Game.COURSES[idx].desc
	if sound:
		Sfx.play("item_get", 1.2, -6.0)


class CourseMap extends Control:
	var course: Dictionary

	func _draw() -> void:
		var pts: Array = course.pts
		var minv := Vector2(INF, INF)
		var maxv := Vector2(-INF, -INF)
		for p in pts:
			minv = minv.min(Vector2(p[0], p[2]))
			maxv = maxv.max(Vector2(p[0], p[2]))
		var ext := maxv - minv
		var sc: float = min((size.x - 30) / ext.x, (size.y - 30) / ext.y)
		var off := (size - ext * sc) * 0.5
		var line := PackedVector2Array()
		var m := pts.size()
		for i in m:
			var p0: Array = pts[(i - 1 + m) % m]
			var p1: Array = pts[i]
			var p2: Array = pts[(i + 1) % m]
			var p3: Array = pts[(i + 2) % m]
			for k in 8:
				var t := k / 8.0
				var a := Vector2(p0[0], p0[2]); var b := Vector2(p1[0], p1[2]); var c := Vector2(p2[0], p2[2]); var d := Vector2(p3[0], p3[2])
				var q := 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t)
				line.append(off + (q - minv) * sc)
		line.append(line[0])
		draw_polyline(line, Color(0, 0, 0, 0.3), 16.0, true)
		draw_polyline(line, Color(1, 1, 1), 11.0, true)
		draw_polyline(line, Color(0.25, 0.25, 0.3), 5.0, true)
		draw_circle(line[0], 9, UI.RED)
		draw_circle(line[0], 5, Color.WHITE)
