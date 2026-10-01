extends Control
## キャラクター選択・カート選択の画面（mode で切り替え）

@export_enum("character", "kart") var mode := "character"

var stage: MenuStage
var cards: Array[Button] = []
var name_label: Label
var desc_label: Label
var stats_box: VBoxContainer
var next_btn: Button
var selected := 0


func _ready() -> void:
	stage = MenuStage.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	stage.camera.position = Vector3(2.2, 2.6, 8.2)
	stage.camera.look_at(Vector3(2.2, 1.0, 0), Vector3.UP)
	stage.spin_speed = 0.45
	var title := "キャラクターをえらぼう！" if mode == "character" else "カートをえらぼう！"
	if Game.mode == "grandprix":
		title = GrandPrix.cup().name + "  ―  " + title
	elif Game.mode == "timeattack":
		title = "タイムアタック  ―  " + title
	UI.header(self, title, UI.RED if mode == "character" else UI.BLUE)

	# 右側：情報パネル
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.14, 0.4, 0.82), 28, 5))
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-520, 110)
	panel.size = Vector2(490, 330)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	name_label = UI.label("", 50, UI.YELLOW, 14)
	v.add_child(name_label)
	desc_label = UI.label("", 26, Color.WHITE, 6)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(440, 70)
	v.add_child(desc_label)
	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 0)
	v.add_child(stats_box)

	# 下：選択カード
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.add_theme_constant_override("separation", 16)
	var list: Array = Game.CHARACTERS if mode == "character" else Game.KARTS
	var cw := 230 if mode == "character" else 270
	row.position = Vector2(-(cw * list.size() + 16 * (list.size() - 1)) * 0.5, -250)
	row.size = Vector2(cw * list.size(), 110)
	add_child(row)
	for i in list.size():
		var d: Dictionary = list[i]
		var locked := mode == "kart" and not Game.is_kart_unlocked(i)
		var b := UI.button("？？？" if locked else d.name, Color(0.35, 0.35, 0.42) if locked else d.color.darkened(0.1),
			34 if mode == "character" else 26, Vector2(cw, 110))
		b.pressed.connect(_select.bind(i))
		row.add_child(b)
		cards.append(b)

	var back := UI.button("もどる", Color(0.4, 0.45, 0.6), 30, Vector2(220, 84))
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.position = Vector2(30, -110)
	back.pressed.connect(_back)
	add_child(back)
	next_btn = UI.button("けってい！", UI.GREEN, 38, Vector2(300, 96))
	next_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	next_btn.position = Vector2(-330, -120)
	next_btn.pressed.connect(_next)
	add_child(next_btn)
	if mode == "kart":
		_build_handicap()
	var start_i := Game.character_index if mode == "character" else Game.kart_index
	if mode == "kart" and not Game.is_kart_unlocked(start_i):
		start_i = 1
	_select(start_i, false)
	Sfx.play_bgm("bgm_title")


func _color_of(k: int) -> Color:
	if mode == "kart" and not Game.is_kart_unlocked(k):
		return Color(0.35, 0.35, 0.42)
	return (Game.CHARACTERS if mode == "character" else Game.KARTS)[k].color


func _select(i: int, sound := true) -> void:
	selected = i
	for k in cards.size():
		var on := k == i
		cards[k].scale = Vector2(1.08, 1.08) if on else Vector2.ONE
		cards[k].pivot_offset = cards[k].size * 0.5
		cards[k].add_theme_stylebox_override("normal", UI.box(_color_of(k).darkened(0.1), 26, 7 if on else 4, UI.YELLOW if on else Color.WHITE))
	for c in stats_box.get_children():
		c.queue_free()
	next_btn.disabled = false
	if mode == "character":
		Game.character_index = i
		var d: Dictionary = Game.CHARACTERS[i]
		name_label.text = d.name
		desc_label.text = d.desc
		_stat_row("スピード", d.speed)
		_stat_row("かそく", d.accel)
		_stat_row("まがり", d.handling)
		var holder := Node3D.new()
		var drv := Models.build_character(i)
		drv.scale = Vector3.ONE * 2.1
		drv.position = Vector3(0, -0.1, 0)
		holder.add_child(drv)
		holder.rotation.y = PI * 0.8
		stage.turntable.rotation.y = 0.0
		stage.show_node(holder)
	else:
		var d: Dictionary = Game.KARTS[i]
		var holder := Node3D.new()
		if not Game.is_kart_unlocked(i):
			name_label.text = "？？？"
			desc_label.text = "ひみつのカート\nすべてのカップで優勝すると手に入る！"
			next_btn.disabled = true
			var q := Label3D.new()
			q.text = "？"
			q.font_size = 200
			q.pixel_size = 0.012
			q.outline_size = 30
			q.modulate = Color(1, 0.85, 0.2)
			q.position = Vector3(0, 1.3, 0)
			q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			holder.add_child(q)
		else:
			Game.kart_index = i
			name_label.text = d.name
			desc_label.text = d.desc
			_star_row("さいこうそくど", d.speed)
			_star_row("かそく", d.accel)
			_star_row("まがりやすさ", d.handling)
			var km := Models.build_kart(i, d.color.lerp(Game.character().color, 0.55), Game.character_index)
			km.scale = Vector3.ONE * 0.95
			holder.add_child(km)
		holder.rotation.y = PI * 0.75
		stage.turntable.rotation.y = 0.0
		stage.show_node(holder)
	if sound:
		Sfx.play("item_get", 1.2, -6.0)


## ハンデ（自動ハンドル補助・少し速いカート）
var hc_box: VBoxContainer

func _build_handicap() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.14, 0.4, 0.82), 22, 4))
	p.position = Vector2(24, 104)
	p.size = Vector2(300, 200)
	add_child(p)
	hc_box = VBoxContainer.new()
	hc_box.add_theme_constant_override("separation", 6)
	p.add_child(hc_box)
	_refresh_handicap()


func _refresh_handicap() -> void:
	for c in hc_box.get_children():
		c.queue_free()
	hc_box.add_child(UI.label("ハンデ", 26, UI.YELLOW, 8))
	var items := [["assist", "ハンドル補助", "手をはなしても道なりに走る"], ["fast", "はやいカート", "最高速度と加速が少しアップ"]]
	for it in items:
		var on: bool = Game.handicap[it[0]]
		var b := UI.button(("● " if on else "○ ") + it[1], UI.GREEN if on else Color(0.35, 0.37, 0.45), 24, Vector2(270, 58))
		b.tooltip_text = it[2]
		b.pressed.connect(func():
			Game.handicap[it[0]] = not Game.handicap[it[0]]
			Game.save_data()
			_refresh_handicap())
		hc_box.add_child(b)


func _stat_row(t: String, v: int) -> void:
	var txt := "ふつう"
	var col := Color.WHITE
	if v > 0:
		txt = "とくい ▲"
		col = Color(0.5, 1.0, 0.5)
	elif v < 0:
		txt = "にがて ▼"
		col = Color(1.0, 0.6, 0.5)
	var h := HBoxContainer.new()
	var a := UI.label(t, 30, Color.WHITE, 6)
	a.custom_minimum_size = Vector2(200, 0)
	h.add_child(a)
	h.add_child(UI.label(txt, 30, col, 6))
	stats_box.add_child(h)


func _star_row(t: String, v: int) -> void:
	var h := HBoxContainer.new()
	var a := UI.label(t, 28, Color.WHITE, 6)
	a.custom_minimum_size = Vector2(230, 0)
	h.add_child(a)
	h.add_child(UI.label(UI.stars(v), 34, UI.YELLOW, 6, Color(0.5, 0.25, 0.0)))
	stats_box.add_child(h)


func _back() -> void:
	if mode == "kart":
		Game.goto_scene("res://scenes/CharacterSelect.tscn")
	elif Game.mode == "grandprix":
		Game.goto_scene("res://scenes/CupSelect.tscn")
	else:
		Game.goto_scene("res://scenes/MainMenu.tscn")


func _next() -> void:
	Game.save_data()
	if mode == "character":
		Game.goto_scene("res://scenes/KartSelect.tscn")
	elif Game.mode == "grandprix":
		GrandPrix.begin_races()
	else:
		Game.goto_scene("res://scenes/CourseSelect.tscn")
