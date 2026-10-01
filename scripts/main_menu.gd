extends Control
## タイトル画面：グランプリ / 1レース / タイムアタック / ガレージ / オプション

var stage: MenuStage
var settings_panel: Control
var _t := 0.0
var title_box: Control


func _ready() -> void:
	GrandPrix.quit()
	Net.leave()
	stage = MenuStage.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	stage.camera.position = Vector3(3.2, 4.2, 11.5)
	stage.camera.look_at(Vector3(3.2, 0.6, 0), Vector3.UP)
	stage.spin_speed = 0.35
	var group := Node3D.new()
	for i in Game.CHARACTERS.size():
		var a := i * TAU / Game.CHARACTERS.size()
		var ki := i % Game.STANDARD_KARTS
		if i == 3 and Game.golden_unlocked:
			ki = 3
		var k := Models.build_kart(ki, Game.KARTS[ki].color.lerp(Game.CHARACTERS[i].color, 0.55), i)
		k.position = Vector3(sin(a), 0, cos(a)) * 2.9
		k.rotation.y = a + PI * 0.5
		k.scale = Vector3.ONE * 0.9
		group.add_child(k)
	stage.show_node(group)

	# タイトルロゴ（左上）
	title_box = VBoxContainer.new()
	title_box.position = Vector2(30, 20)
	title_box.size = Vector2(760, 220)
	title_box.add_theme_constant_override("separation", -18)
	add_child(title_box)
	var l1 := UI.label("わくわく", 84, UI.YELLOW, 22, Color(0.85, 0.25, 0.1))
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(l1)
	var l2 := UI.label("カートレーサーズ", 90, Color.WHITE, 24, Color(0.1, 0.25, 0.75))
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(l2)
	title_box.pivot_offset = Vector2(380, 110)

	# メニュー（右側）
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	v.position = Vector2(-400, -250)
	v.size = Vector2(370, 520)
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var gp := UI.button("グランプリ", UI.RED, 40, Vector2(370, 92))
	gp.pressed.connect(func(): Game.goto_scene("res://scenes/CupSelect.tscn"))
	v.add_child(gp)
	gp.grab_focus()
	var items := [
		["みんなで対戦（LAN）", Color(0.1, 0.6, 0.5), _go_lan],
		["1レース", UI.BLUE, _go_single],
		["タイムアタック", Color(0.55, 0.3, 0.85), _go_ta],
		["ガレージ", UI.GREEN, _go_garage],
		["オプション", Color(0.4, 0.45, 0.6), _open_settings],
	]
	for it in items:
		var b := UI.button(it[0], it[1], 28 if it[0].length() > 8 else 32, Vector2(370, 74))
		b.pressed.connect(it[2])
		v.add_child(b)

	UI.coin_badge(self)
	var ver := UI.label("Godot 4 / Android", 18, Color(1, 1, 1, 0.8), 6)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(20, -40)
	add_child(ver)
	_build_settings()
	Sfx.play_bgm("bgm_title")
	if Net.leave_reason != "":
		var msg := UI.label(Net.leave_reason, 30, Color(1, 0.6, 0.5), 10)
		msg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		msg.position = Vector2(-600, -80)
		msg.size = Vector2(800, 50)
		add_child(msg)
		Net.leave_reason = ""


func _go_lan() -> void:
	Game.mode = "lan"
	Game.goto_scene("res://scenes/LanLobby.tscn")


func _go_single() -> void:
	Game.mode = "single"
	Game.goto_scene("res://scenes/CharacterSelect.tscn")


func _go_ta() -> void:
	Game.mode = "timeattack"
	Game.goto_scene("res://scenes/CharacterSelect.tscn")


func _go_garage() -> void:
	Game.goto_scene("res://scenes/Garage.tscn")


func _open_settings() -> void:
	settings_panel.visible = true


func _process(delta: float) -> void:
	_t += delta
	var sc := 1.0 + sin(_t * 2.2) * 0.025
	title_box.scale = Vector2(sc, sc)


func _build_settings() -> void:
	settings_panel = ColorRect.new()
	(settings_panel as ColorRect).color = Color(0, 0, 0.1, 0.6)
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.visible = false
	add_child(settings_panel)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.12, 0.3, 0.75), 30, 6))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-330, -270)
	panel.size = Vector2(660, 540)
	settings_panel.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var t := UI.label("オプション", 48, UI.YELLOW, 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_slider_row("BGM", "bgm"))
	v.add_child(_slider_row("こうかおん", "se"))
	v.add_child(_check_row("オートアクセル（▲をおさなくても進む）", "auto_accel"))
	v.add_child(_check_row("カメラのゆれ", "cam_shake"))
	var close := UI.button("とじる", UI.GREEN, 32, Vector2(260, 76))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func():
		settings_panel.visible = false
		Game.save_data())
	v.add_child(close)


func _slider_row(text: String, key: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var l := UI.label(text, 30, Color.WHITE, 8)
	l.custom_minimum_size = Vector2(200, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Game.settings[key]
	s.custom_minimum_size = Vector2(360, 50)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var grab := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	for y in 40:
		for x in 40:
			var dd := Vector2(x - 19.5, y - 19.5).length()
			grab.set_pixel(x, y, Color(1, 0.85, 0.2) if dd < 17 else (Color(1, 1, 1) if dd < 20 else Color(0, 0, 0, 0)))
	s.add_theme_icon_override("grabber", ImageTexture.create_from_image(grab))
	s.add_theme_icon_override("grabber_highlight", ImageTexture.create_from_image(grab))
	var track_sb := StyleBoxFlat.new()
	track_sb.bg_color = Color(1, 1, 1, 0.35)
	track_sb.set_corner_radius_all(8)
	track_sb.content_margin_top = 8
	track_sb.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", track_sb)
	var fill := track_sb.duplicate()
	fill.bg_color = UI.YELLOW
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.value_changed.connect(func(val):
		Game.settings[key] = val
		Sfx.update_volume()
		if key == "se":
			Sfx.play("click"))
	h.add_child(s)
	return h


func _check_row(text: String, key: String) -> Control:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = Game.settings[key]
	c.add_theme_font_size_override("font_size", 28)
	c.add_theme_color_override("font_color", Color.WHITE)
	c.add_theme_color_override("font_pressed_color", UI.YELLOW)
	c.toggled.connect(func(on):
		Game.settings[key] = on
		Sfx.play("click"))
	return c
