extends Control
## ガレージ：コイン・トロフィー・カートのコレクション

var stage: MenuStage
var kart_btns: Array[Button] = []
var info_name: Label
var info_desc: Label
var info_stats: Label


func _ready() -> void:
	stage = MenuStage.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	stage.camera.position = Vector3(-3.0, 2.8, 8.4)
	stage.camera.look_at(Vector3(-3.0, 0.9, 0), Vector3.UP)
	stage.spin_speed = 0.5
	UI.header(self, "ガレージ", UI.GREEN)
	UI.coin_badge(self).position = Vector2(-260, 100)

	# トロフィー棚
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.12, 0.35, 0.85), 24, 4))
	tp.position = Vector2(30, 110)
	tp.size = Vector2(560, 360)
	add_child(tp)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	tp.add_child(tv)
	var won := 0
	for c in Game.CUPS:
		var t: Array = Game.trophies.get(c.id, [0, 0, 0])
		if 1 in t:
			won += 1
	tv.add_child(UI.label("トロフィー", 32, UI.YELLOW, 8))
	var head := HBoxContainer.new()
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(250, 0)
	head.add_child(sp)
	for d in Game.DIFFICULTIES:
		var dl := UI.label(d.name, 18, d.color, 6)
		dl.custom_minimum_size = Vector2(96, 0)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(dl)
	tv.add_child(head)
	for c in Game.CUPS:
		var h := HBoxContainer.new()
		var n := UI.label(c.name, 24, Color.WHITE, 6)
		n.custom_minimum_size = Vector2(250, 0)
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(n)
		for d in Game.DIFFICULTIES.size():
			var ic := UI.Icon.new("trophy", Game.trophy(c.id, d), Vector2(96, 70))
			h.add_child(ic)
		tv.add_child(h)
	tv.add_child(UI.label("優勝したカップ  %d / %d" % [won, Game.CUPS.size()], 24, Color(0.6, 1.0, 0.6), 6))

	# カート情報
	var ip := PanelContainer.new()
	ip.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.12, 0.35, 0.85), 24, 4))
	ip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ip.position = Vector2(-560, 180)
	ip.size = Vector2(530, 260)
	add_child(ip)
	var iv := VBoxContainer.new()
	ip.add_child(iv)
	info_name = UI.label("", 40, UI.YELLOW, 10)
	iv.add_child(info_name)
	info_desc = UI.label("", 22, Color.WHITE, 6)
	info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_desc.custom_minimum_size = Vector2(490, 60)
	iv.add_child(info_desc)
	info_stats = UI.label("", 26, Color.WHITE, 6)
	iv.add_child(info_stats)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.add_theme_constant_override("separation", 14)
	row.position = Vector2(-(250 * 4 + 42) * 0.5, -225)
	add_child(row)
	for i in Game.KARTS.size():
		var locked := not Game.is_kart_unlocked(i)
		var b := UI.button("？？？" if locked else Game.KARTS[i].name, Color(0.35, 0.35, 0.42) if locked else Game.KARTS[i].color.darkened(0.1), 24, Vector2(250, 90))
		b.pressed.connect(_show_kart.bind(i))
		row.add_child(b)
		kart_btns.append(b)
	var back := UI.button("もどる", Color(0.4, 0.45, 0.6), 30, Vector2(220, 84))
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.position = Vector2(30, -110)
	back.pressed.connect(func(): Game.goto_scene("res://scenes/MainMenu.tscn"))
	add_child(back)
	_show_kart(3 if Game.golden_unlocked else Game.kart_index, false)
	Sfx.play_bgm("bgm_title")


func _show_kart(i: int, sound := true) -> void:
	var d: Dictionary = Game.KARTS[i]
	var holder := Node3D.new()
	if Game.is_kart_unlocked(i):
		info_name.text = d.name
		info_desc.text = d.desc
		info_stats.text = "さいこうそくど %s\nかそく         %s\nまがりやすさ   %s" % [UI.stars(d.speed), UI.stars(d.accel), UI.stars(d.handling)]
		var km := Models.build_kart(i, d.color.lerp(Game.character().color, 0.55), Game.character_index)
		holder.add_child(km)
	else:
		info_name.text = "？？？"
		info_desc.text = "ひみつのカート。\nすべてのカップで優勝すると手に入る！"
		info_stats.text = ""
		var q := Label3D.new()
		q.text = "？"
		q.font_size = 200
		q.pixel_size = 0.012
		q.outline_size = 30
		q.modulate = Color(1, 0.85, 0.2)
		q.position = Vector3(0, 1.3, 0)
		q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		holder.add_child(q)
	stage.show_node(holder)
	for k in kart_btns.size():
		kart_btns[k].scale = Vector2(1.06, 1.06) if k == i else Vector2.ONE
		kart_btns[k].pivot_offset = kart_btns[k].size * 0.5
	if sound:
		Sfx.play("item_get", 1.2, -6.0)
