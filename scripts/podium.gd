extends Control
## グランプリ：FINISH! → CHAMPION! → 表彰台 → 報酬・アンロック

var stage: MenuStage
var overlay: ColorRect
var big: Label
var sub: Label
var reward_panel: PanelContainer
var coin_label: Label
var unlock_banner: Control
var buttons: HBoxContainer
var rewards: Dictionary
var st: Array
var _t := 0.0
var _phase := -1
var _coins_shown := 0.0
var _cam_a := 0.0


func _ready() -> void:
	st = GrandPrix.standings()
	rewards = GrandPrix.finish_cup()
	stage = MenuStage.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	stage.spin_speed = 0.0
	_build_podium()

	overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.03, 0.12, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	big = UI.label("", 150, UI.YELLOW, 30, Color(0.6, 0.15, 0.0))
	big.set_anchors_preset(Control.PRESET_CENTER)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.size = Vector2(1200, 200)
	big.position = Vector2(-600, -230)
	big.pivot_offset = Vector2(600, 100)
	add_child(big)
	sub = UI.label("", 56, Color.WHITE, 14)
	sub.set_anchors_preset(Control.PRESET_CENTER)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(1200, 200)
	sub.position = Vector2(-600, -10)
	add_child(sub)

	_build_rewards()
	buttons = HBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	buttons.position = Vector2(-330, -118)
	buttons.size = Vector2(660, 96)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	buttons.visible = false
	add_child(buttons)
	var again := UI.button("もういちど", UI.RED, 32, Vector2(300, 90))
	again.pressed.connect(func():
		GrandPrix.start(GrandPrix.cup_index)
		GrandPrix.begin_races())
	buttons.add_child(again)
	var title := UI.button("タイトルへ", UI.BLUE, 32, Vector2(300, 90))
	title.pressed.connect(func():
		GrandPrix.quit()
		Game.goto_scene("res://scenes/MainMenu.tscn"))
	buttons.add_child(title)
	Sfx.stop_bgm()
	Sfx.play("drumroll")


func _build_podium() -> void:
	var root := Node3D.new()
	stage.show_node(root)
	stage.turntable.rotation.y = 0.0
	# 1位が真ん中、2位が左、3位が右
	var spots := [[Vector3(0, 0, 0), 2.2, UI.MEDAL[0]], [Vector3(-3.4, 0, 0.3), 1.5, UI.MEDAL[1]], [Vector3(3.4, 0, 0.3), 0.9, UI.MEDAL[2]]]
	for i in 3:
		var sp: Array = spots[i]
		var h: float = sp[1]
		var blk := Models.box(root, Vector3(3.2, h, 3.0), Color(1, 1, 1), sp[0] + Vector3(0, h * 0.5, 0))
		blk.material_override = Models.mat(Color(0.95, 0.95, 1.0), 0.5)
		var band := Models.box(root, Vector3(3.25, 0.35, 3.05), sp[2], sp[0] + Vector3(0, h - 0.2, 0))
		band.material_override = Models.mat(sp[2], 0.3, 0.6)
		var num := Label3D.new()
		num.text = str(i + 1)
		num.font_size = 160
		num.pixel_size = 0.008
		num.outline_size = 24
		num.modulate = sp[2]
		num.position = sp[0] + Vector3(0, h * 0.45, 1.52)
		root.add_child(num)
		if i < st.size():
			var key: String = st[i]
			var ki := GrandPrix.kart_of(key)
			var ci := GrandPrix.char_of(key)
			var km := Models.build_kart(ki, Game.KARTS[ki].color.lerp(Game.CHARACTERS[ci].color, 0.55), ci)
			km.position = sp[0] + Vector3(0, h, 0)
			km.rotation.y = PI + (0.25 if i == 1 else (-0.25 if i == 2 else 0.0))
			km.scale = Vector3.ONE * 0.8
			root.add_child(km)
			var tag := Label3D.new()
			tag.text = GrandPrix.name_of(key)
			tag.font_size = 72
			tag.pixel_size = 0.01
			tag.outline_size = 14
			tag.modulate = UI.YELLOW if key == "player" else Color.WHITE
			tag.position = sp[0] + Vector3(0, h + 2.6, 0)
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			root.add_child(tag)
	# 大きなトロフィー
	var cup := Node3D.new()
	cup.position = Vector3(0, 5.6, -1.5)
	root.add_child(cup)
	var gold := Models.mat(Color(1, 0.8, 0.2), 0.2, 0.9)
	Models.cyl(cup, 0.9, 0.35, 1.4, Color(1, 0.8, 0.2), Vector3(0, 0.7, 0), Vector3.ZERO, 20).material_override = gold
	Models.cyl(cup, 0.12, 0.12, 0.6, Color(1, 0.8, 0.2), Vector3(0, -0.2, 0)).material_override = gold
	Models.cyl(cup, 0.55, 0.6, 0.25, Color(1, 0.8, 0.2), Vector3(0, -0.55, 0)).material_override = gold
	for sx: float in [-1.0, 1.0]:
		var hd := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.25
		tm.outer_radius = 0.38
		hd.mesh = tm
		hd.material_override = gold
		hd.position = Vector3(sx * 0.95, 0.8, 0)
		hd.rotation.z = PI / 2
		cup.add_child(hd)
	cup.set_meta("spin", true)
	root.set_meta("cup", cup)
	stage.camera.position = Vector3(0, 3.5, 10.5)
	stage.camera.look_at(Vector3(0, 2.2, 0), Vector3.UP)


func _build_rewards() -> void:
	reward_panel = PanelContainer.new()
	reward_panel.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.12, 0.35, 0.9), 26, 5, UI.YELLOW))
	reward_panel.position = Vector2(30, 150)
	reward_panel.size = Vector2(450, 380)
	reward_panel.visible = false
	add_child(reward_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	reward_panel.add_child(v)
	var place: int = rewards.place
	var pts: int = GrandPrix.points["player"]
	v.add_child(UI.label("けっか  %d位  %dpt" % [place, pts], 34, UI.YELLOW, 8))
	v.add_child(UI.label(GrandPrix.cup().name + "（%s）" % Game.diff().name, 22, Color.WHITE, 6))
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 12)
	th.add_child(UI.Icon.new("trophy", rewards.trophy, Vector2(90, 90)))
	var tt := "トロフィー\nゲット！" if rewards.trophy > 0 else "トロフィーは\n3位まで"
	if rewards.trophy > 0 and not rewards.new_trophy:
		tt = "トロフィー\n（もう持っている）"
	var tl := UI.label(tt, 28, Color.WHITE, 8)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(tl)
	v.add_child(th)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 12)
	ch.add_child(UI.Icon.new("coin", 0, Vector2(56, 56)))
	coin_label = UI.label("+0", 42, UI.YELLOW, 10)
	ch.add_child(coin_label)
	v.add_child(ch)
	v.add_child(UI.label("もっているコイン  %d" % Game.coins, 24, Color.WHITE, 6))
	# ゴールデンカート解放
	unlock_banner = PanelContainer.new()
	(unlock_banner as PanelContainer).add_theme_stylebox_override("panel", UI.box(Color(0.9, 0.6, 0.05), 24, 6, Color.WHITE))
	unlock_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	unlock_banner.position = Vector2(-330, 18)
	unlock_banner.size = Vector2(660, 110)
	unlock_banner.visible = false
	var ul := UI.label("ゴールデンカートを手に入れた！", 40, Color.WHITE, 12, Color(0.5, 0.25, 0.0))
	ul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock_banner.add_child(ul)
	add_child(unlock_banner)


func _process(delta: float) -> void:
	_t += delta
	if Game.test_auto and _t > 9.0:
		print("PODIUM place=%d rewards=%s coins_total=%d trophies=%s golden=%s" % [rewards.place, rewards, Game.coins, Game.trophies, Game.golden_unlocked])
		get_tree().quit()
		return
	var root: Node3D = stage.turntable.get_child(0) if stage.turntable.get_child_count() > 0 else null
	if root and root.has_meta("cup"):
		(root.get_meta("cup") as Node3D).rotation.y += delta * 1.2
	var place: int = rewards.place
	if _phase < 0:
		_phase = 0
		big.text = "FINISH!"
		big.scale = Vector2(0.2, 0.2)
	if _phase == 0:
		big.scale = big.scale.lerp(Vector2.ONE, 1.0 - exp(-8.0 * delta))
		if _t > 2.0:
			_phase = 1
			Sfx.play("champion")
			big.scale = Vector2(0.3, 0.3)
			var champ: String = st[0]
			if champ == "player":
				big.text = "CHAMPION!"
				sub.text = "あなた   %d POINT" % GrandPrix.points["player"]
			else:
				big.text = "CHAMPION!"
				sub.text = "%s   %d POINT\nあなたは %d位（%d POINT）" % [GrandPrix.name_of(champ), GrandPrix.points[champ], place, GrandPrix.points["player"]]
	elif _phase == 1:
		big.scale = big.scale.lerp(Vector2.ONE, 1.0 - exp(-8.0 * delta))
		big.rotation = sin(_t * 3.0) * 0.03
		if _t > 5.0:
			_phase = 2
			Sfx.play_bgm("bgm_podium")
			stage.confetti.emitting = true
			var tw := create_tween()
			tw.tween_property(overlay, "color:a", 0.0, 0.8)
			tw.parallel().tween_property(big, "modulate:a", 0.0, 0.5)
			tw.parallel().tween_property(sub, "modulate:a", 0.0, 0.5)
	elif _phase == 2:
		_cam_a += delta * 0.25
		stage.camera.position = Vector3(sin(_cam_a) * 3.0, 3.5, 10.5)
		stage.camera.look_at(Vector3(0, 2.4, 0), Vector3.UP)
		if _t > 6.5:
			_phase = 3
			reward_panel.visible = true
			buttons.visible = true
	elif _phase == 3:
		_cam_a += delta * 0.25
		stage.camera.position = Vector3(sin(_cam_a) * 1.5 - 2.4, 3.8, 13.0)
		stage.camera.look_at(Vector3(-2.4, 2.5, 0), Vector3.UP)
		var target: float = rewards.coins
		if _coins_shown < target:
			var before := int(_coins_shown)
			_coins_shown = minf(target, _coins_shown + delta * maxf(target, 60.0) * 0.8)
			if int(_coins_shown / 25.0) != int(before / 25.0):
				Sfx.play("coin", 1.0, -8.0)
		coin_label.text = "+%d" % int(_coins_shown)
		if rewards.unlocked and _t > 8.0:
			unlock_banner.visible = true
			unlock_banner.modulate = Color(1, 1, 1, 0.75 + 0.25 * sin(_t * 6.0))
			if not unlock_banner.has_meta("played"):
				unlock_banner.set_meta("played", true)
				Sfx.play("champion", 1.2)
