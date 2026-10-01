extends Control
## グランプリ：カップと難易度をえらぶ画面

var cards: Array[Button] = []
var selected := 0
var diff_desc: Label


func _ready() -> void:
	Game.mode = "grandprix"
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ float t = UV.y; vec3 a = vec3(0.95,0.4,0.25); vec3 b = vec3(1.0,0.78,0.35); float s = step(0.5, fract((UV.x + UV.y) * 16.0)); COLOR = vec4(mix(a,b,t) + s*0.035, 1.0);}"
	gm.shader = sh
	bg.material = gm
	add_child(bg)
	UI.header(self, "グランプリ ― カップをえらぼう！", UI.RED)
	UI.coin_badge(self).position = Vector2(-260, 100)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.add_theme_constant_override("separation", 24)
	row.position = Vector2(-(370 * 3 + 48) * 0.5, -250)
	row.size = Vector2(370 * 3 + 48, 380)
	add_child(row)
	for i in Game.CUPS.size():
		var c: Dictionary = Game.CUPS[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(370, 380)
		UI.style_button(b, c.color, 30)
		b.pressed.connect(_select.bind(i))
		row.add_child(b)
		cards.append(b)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 18
		v.offset_right = -18
		v.offset_top = 14
		v.offset_bottom = -14
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 2)
		b.add_child(v)
		var badge := CupBadge.new()
		badge.cup = i
		badge.custom_minimum_size = Vector2(0, 90)
		v.add_child(badge)
		var n := UI.label(c.name, 32, Color.WHITE, 10, c.color.darkened(0.6))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
		var lv := UI.label(c.level, 24, UI.YELLOW, 8, c.color.darkened(0.6))
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lv)
		for k in c.courses.size():
			var cn: String = Game.COURSES[Game.course_index_of(c.courses[k])].name
			var cl := UI.label("%d  %s" % [k + 1, cn], 22, Color.WHITE, 6, c.color.darkened(0.6))
			v.add_child(cl)
		# 難易度ごとのトロフィー
		var tr := HBoxContainer.new()
		tr.alignment = BoxContainer.ALIGNMENT_CENTER
		tr.add_theme_constant_override("separation", 14)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tr)
		for d in Game.DIFFICULTIES.size():
			var col := VBoxContainer.new()
			col.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_theme_constant_override("separation", -4)
			col.add_child(UI.Icon.new("trophy", Game.trophy(c.id, d), Vector2(46, 46)))
			var dl := UI.label(Game.DIFFICULTIES[d].name, 14, Color.WHITE, 4, c.color.darkened(0.6))
			dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(dl)
			tr.add_child(col)

	# 難易度
	var dbox := VBoxContainer.new()
	dbox.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dbox.position = Vector2(-300, -225)
	dbox.size = Vector2(600, 110)
	dbox.add_theme_constant_override("separation", 4)
	add_child(dbox)
	var drow := UI.difficulty_row(_diff_changed)
	drow.alignment = BoxContainer.ALIGNMENT_CENTER
	dbox.add_child(drow)
	diff_desc = UI.label("", 22, Color.WHITE, 8)
	diff_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dbox.add_child(diff_desc)

	var back := UI.button("もどる", Color(0.4, 0.45, 0.6), 30, Vector2(220, 84))
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.position = Vector2(30, -110)
	back.pressed.connect(func(): Game.goto_scene("res://scenes/MainMenu.tscn"))
	add_child(back)
	var go := UI.button("けってい！", UI.GREEN, 38, Vector2(300, 96))
	go.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	go.position = Vector2(-330, -120)
	go.pressed.connect(_go)
	add_child(go)
	_select(GrandPrix.cup_index, false)
	_diff_changed()
	Sfx.play_bgm("bgm_title")


func _diff_changed() -> void:
	diff_desc.text = Game.diff().desc


func _select(i: int, sound := true) -> void:
	selected = i
	for k in cards.size():
		cards[k].pivot_offset = cards[k].size * 0.5
		cards[k].scale = Vector2(1.05, 1.05) if k == i else Vector2(0.95, 0.95)
		cards[k].modulate = Color.WHITE if k == i else Color(0.85, 0.85, 0.9)
		var col: Color = Game.CUPS[k].color
		cards[k].add_theme_stylebox_override("normal", UI.box(col, 26, 8 if k == i else 4, UI.YELLOW if k == i else Color.WHITE))
	if sound:
		Sfx.play("item_get", 1.2, -6.0)


func _go() -> void:
	GrandPrix.start(selected)
	Game.save_data()
	Game.goto_scene("res://scenes/CharacterSelect.tscn")


## カップのマーク
class CupBadge extends Control:
	var cup := 0

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		draw_circle(c, 42, Color(1, 1, 1, 0.9))
		match cup:
			0:  # 葉っぱ
				var pts := PackedVector2Array()
				for k in 21:
					var t := k / 20.0
					pts.append(c + Vector2(lerpf(-24, 24, t), -sin(t * PI) * 18 + 4))
				for k in 21:
					var t := 1.0 - k / 20.0
					pts.append(c + Vector2(lerpf(-24, 24, t), sin(t * PI) * 14 + 4))
				draw_colored_polygon(pts, Color(0.25, 0.7, 0.3))
				draw_line(c + Vector2(-26, 4), c + Vector2(24, 4), Color(0.1, 0.4, 0.15), 3.0)
			1:  # 山と炎
				draw_colored_polygon(PackedVector2Array([c + Vector2(-30, 24), c + Vector2(0, -22), c + Vector2(30, 24)]), Color(0.55, 0.3, 0.2))
				draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -8), c + Vector2(0, -30), c + Vector2(9, -8)]), Color(1, 0.5, 0.1))
			2:  # 星
				var st := PackedVector2Array()
				for k in 10:
					var a := -PI / 2 + k * PI / 5
					var r := 30.0 if k % 2 == 0 else 13.0
					st.append(c + Vector2(cos(a), sin(a)) * r)
				draw_colored_polygon(st, Color(1, 0.8, 0.15))
