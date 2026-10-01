class_name Hud
extends CanvasLayer
## レース画面の表示：LAP・順位・アイテム枠・タイム・カウントダウン・ブースト演出・一時停止。

var race: Node
var touch: TouchControls
var lap_label: Label
var time_label: Label
var rank_label: Label
var rank_of_label: Label
var item_slot: Control
var popup_label: Label
var msg_label: Label
var countdown: Control
var speed_lines: Control
var pause_btn: Button
var pause_panel: Control
var _popup_t := 0.0
var _msg_t := 0.0
var _cd_value := -1       # 3,2,1,0(GO) / -1 非表示
var _cd_t := 0.0
var _roulette_i := 0
var _roulette_tick := 0.0
var _speed_amt := 0.0
var _rank_scale := 1.0
var _last_rank := 0


func build(r: Node) -> void:
	race = r
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	speed_lines = SpeedLines.new()
	speed_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(speed_lines)

	# 左上: LAP
	lap_label = UI.label("LAP 1/3", 54, Color.WHITE, 14, Color(0.08, 0.12, 0.35))
	lap_label.position = Vector2(28, 14)
	root.add_child(lap_label)
	time_label = UI.label("0:00.00", 30, Color(1, 1, 0.85), 10, Color(0.08, 0.12, 0.35))
	time_label.position = Vector2(34, 84)
	root.add_child(time_label)

	# 右上: 順位
	var rank_box := Control.new()
	rank_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rank_box.position = Vector2(-250, 6)
	rank_box.size = Vector2(230, 120)
	rank_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rank_box)
	rank_label = UI.label("1", 104, UI.YELLOW, 18, Color(0.45, 0.2, 0.0))
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_label.size = Vector2(120, 120)
	rank_label.position = Vector2(0, -12)
	rank_label.pivot_offset = Vector2(90, 70)
	rank_box.add_child(rank_label)
	rank_of_label = UI.label("/ 6", 50, Color.WHITE, 12, Color(0.08, 0.12, 0.35))
	rank_of_label.position = Vector2(128, 40)
	rank_box.add_child(rank_of_label)
	rank_box.visible = Game.mode != "timeattack"
	# モード表示
	var mode_txt := ""
	if Game.mode == "grandprix":
		mode_txt = "%s  %d/%d" % [GrandPrix.cup().name, GrandPrix.race_index + 1, GrandPrix.race_count()]
	elif Game.mode == "timeattack":
		mode_txt = "BEST  " + Game.format_time(Game.ta_best.get(Game.course().id, -1.0))
	elif Game.mode == "lan":
		mode_txt = "みんなで対戦（%d人）" % Net.roster.size()
	if mode_txt != "":
		var ml := UI.label(mode_txt, 24, Color(0.85, 0.95, 1.0), 8, Color(0.08, 0.12, 0.35))
		ml.position = Vector2(34, 124)
		root.add_child(ml)

	# 上中央: アイテム枠
	item_slot = ItemSlot.new()
	item_slot.hud = self
	item_slot.set_anchors_preset(Control.PRESET_CENTER_TOP)
	item_slot.size = Vector2(118, 118)
	item_slot.position = Vector2(-59 - 90, 12)
	item_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(item_slot)

	# 一時停止ボタン
	pause_btn = UI.button("II", Color(0.1, 0.15, 0.35, 0.75), 30, Vector2(84, 70))
	pause_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pause_btn.position = Vector2(40, 22)
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(func(): race.set_paused(true))
	root.add_child(pause_btn)

	# タッチ操作
	touch = TouchControls.new()
	touch.hud = self
	root.add_child(touch)

	# 画面中央の文字
	msg_label = UI.label("", 76, Color.WHITE, 18, Color(0.85, 0.2, 0.15))
	msg_label.set_anchors_preset(Control.PRESET_CENTER)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.size = Vector2(1000, 120)
	msg_label.position = Vector2(-500, -200)
	msg_label.pivot_offset = Vector2(500, 60)
	root.add_child(msg_label)
	popup_label = UI.label("", 64, Color.WHITE, 16, Color(0.1, 0.2, 0.5))
	popup_label.set_anchors_preset(Control.PRESET_CENTER)
	popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_label.size = Vector2(800, 100)
	popup_label.position = Vector2(-400, 40)
	popup_label.pivot_offset = Vector2(400, 50)
	root.add_child(popup_label)

	countdown = CountdownView.new()
	countdown.hud = self
	countdown.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(countdown)

	_build_pause_panel(root)


func _build_pause_panel(root: Control) -> void:
	pause_panel = ColorRect.new()
	(pause_panel as ColorRect).color = Color(0, 0, 0.1, 0.55)
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(pause_panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.add_theme_constant_override("separation", 22)
	v.position = Vector2(-170, -210)
	v.size = Vector2(340, 420)
	pause_panel.add_child(v)
	var t := UI.label("ポーズ", 64, Color.WHITE, 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b1 := UI.button("さいかい", UI.GREEN)
	b1.pressed.connect(func(): race.set_paused(false))
	v.add_child(b1)
	var b2 := UI.button("やりなおす", UI.BLUE)
	b2.pressed.connect(func(): Game.goto_scene("res://scenes/Race.tscn"))
	v.add_child(b2)
	b2.visible = Game.mode != "lan"
	var b3 := UI.button("レースをぬける" if Game.mode == "lan" else "タイトルへ", UI.RED)
	b3.pressed.connect(func():
		GrandPrix.quit()
		Game.goto_scene("res://scenes/MainMenu.tscn"))
	v.add_child(b3)


func show_pause(on: bool) -> void:
	pause_panel.visible = on
	touch.release_all()


func item_to_show() -> String:
	var p: Kart = race.player
	if p == null:
		return ""
	if p.roulette > 0.0:
		return ItemArt.ORDER[_roulette_i]
	return p.item


func set_countdown(v: int) -> void:
	_cd_value = v
	_cd_t = 0.0


func popup(text: String, col: Color, dur := 0.9) -> void:
	popup_label.text = text
	popup_label.label_settings.font_color = col
	popup_label.label_settings.outline_color = col.darkened(0.7)
	_popup_t = dur
	popup_label.scale = Vector2(1.6, 1.6)


func message(text: String, dur := 2.0, col := Color.WHITE) -> void:
	msg_label.text = text
	msg_label.label_settings.font_color = col
	_msg_t = dur
	msg_label.scale = Vector2(0.3, 0.3)


func set_speed_effect(amount: float) -> void:
	_speed_amt = amount


func _process(delta: float) -> void:
	var p: Kart = race.player
	if p == null:
		return
	var total := Game.TOTAL_LAPS
	lap_label.text = "LAP %d/%d" % [clampi(p.lap, 1, total), total]
	time_label.text = Game.format_time(race.race_time)
	rank_label.text = str(p.rank)
	var rc := [UI.YELLOW, Color(0.85, 0.9, 1.0), Color(1.0, 0.6, 0.3), Color.WHITE, Color.WHITE, Color.WHITE]
	rank_label.label_settings.font_color = rc[clampi(p.rank - 1, 0, 5)]
	if p.rank != _last_rank:
		_last_rank = p.rank
		_rank_scale = 1.45
	_rank_scale = lerpf(_rank_scale, 1.0, 1.0 - exp(-8.0 * delta))
	rank_label.scale = Vector2(_rank_scale, _rank_scale)
	# ルーレット
	if p.roulette > 0.0:
		_roulette_tick -= delta
		if _roulette_tick <= 0.0:
			_roulette_tick = 0.07
			_roulette_i = (_roulette_i + 1) % ItemArt.ORDER.size()
			Sfx.play("roulette")
	item_slot.queue_redraw()
	# ポップアップ
	if _popup_t > 0.0:
		_popup_t -= delta
		popup_label.visible = true
		popup_label.scale = popup_label.scale.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))
		popup_label.modulate.a = clampf(_popup_t / 0.25, 0.0, 1.0)
	else:
		popup_label.visible = false
	if _msg_t > 0.0:
		_msg_t -= delta
		msg_label.visible = true
		msg_label.scale = msg_label.scale.lerp(Vector2.ONE, 1.0 - exp(-10.0 * delta))
		msg_label.modulate.a = clampf(_msg_t / 0.3, 0.0, 1.0)
	else:
		msg_label.visible = false
	# 逆走
	if race.state == "race" and p.wrong_way > 1.2 and not p.finished:
		if _msg_t <= 0.05:
			message("ぎゃくそう中！", 0.4, Color(1, 0.4, 0.3))
	_cd_t += delta
	(speed_lines as SpeedLines).amount = lerpf((speed_lines as SpeedLines).amount, _speed_amt, 1.0 - exp(-6.0 * delta))
	countdown.queue_redraw()


# ------------------------------------------------------------------ 部品
class ItemSlot extends Control:
	var hud: Hud

	func _draw() -> void:
		var s := size
		var r := Rect2(Vector2.ZERO, s)
		var sb := UI.box(Color(0.08, 0.12, 0.35, 0.7), 22, 6, Color(1, 1, 1, 0.95), 6)
		draw_style_box(sb, r)
		var it := hud.item_to_show()
		if it != "":
			ItemArt.draw(self, it, s * 0.5, s.x * 0.36)
			var p: Kart = hud.race.player
			if p and p.item_count > 1 and p.roulette <= 0.0:
				var font := get_theme_default_font()
				draw_string_outline(font, Vector2(s.x - 44, s.y - 10), "×%d" % p.item_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, Color(0.08, 0.12, 0.35))
				draw_string(font, Vector2(s.x - 44, s.y - 10), "×%d" % p.item_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)


class SpeedLines extends Control:
	var amount := 0.0
	var _seed := 0.0

	func _process(delta: float) -> void:
		_seed += delta
		if amount > 0.02:
			queue_redraw()
		elif amount <= 0.02 and _seed > 0.0:
			queue_redraw()

	func _draw() -> void:
		if amount < 0.03:
			return
		var s := size
		var c := s * Vector2(0.5, 0.45)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_seed * 30.0)
		for i in int(40 * amount):
			var a := rng.randf() * TAU
			var r0 := s.x * rng.randf_range(0.28, 0.4)
			var r1 := r0 + s.x * rng.randf_range(0.12, 0.3)
			var dir := Vector2(cos(a), sin(a) * 0.62)
			draw_line(c + dir * r0, c + dir * r1, Color(1, 1, 1, 0.55 * amount), rng.randf_range(2.0, 5.0), true)


class CountdownView extends Control:
	var hud: Hud

	func _draw() -> void:
		var v := hud._cd_value
		if v < 0:
			return
		var t := hud._cd_t
		var s := size
		var c := Vector2(s.x * 0.5, s.y * 0.27)
		var font := get_theme_default_font()
		if v > 0 or t < 1.0:
			# 信号機
			var box := Rect2(c + Vector2(-190, -70), Vector2(380, 140))
			draw_style_box(UI.box(Color(0.12, 0.12, 0.16, 0.92), 60, 6, Color.WHITE, 8), box)
			var cols := [Color(1, 0.2, 0.2), Color(1, 0.85, 0.1), Color(0.2, 0.95, 0.35)]
			for k in 3:
				var lit := (v == 3 and k == 0) or (v == 2 and k <= 1) or (v == 1 and k <= 2) or v == 0
				var col: Color = cols[k] if lit else cols[k].darkened(0.75)
				if v == 0:
					col = cols[2]
				var p := c + Vector2(-120 + k * 120, 0)
				if lit:
					draw_circle(p, 56, Color(col.r, col.g, col.b, 0.3))
				draw_circle(p, 44, col)
				draw_circle(p + Vector2(-12, -14), 10, Color(1, 1, 1, 0.5 if lit else 0.1))
		var txt := str(v) if v > 0 else "GO!!"
		var fs := 170 if v > 0 else 190
		var sc := 1.0 + maxf(0.0, 0.5 - t) * 1.5
		var alpha := 1.0 if v > 0 else clampf(1.6 - t, 0.0, 1.0)
		if alpha <= 0.0:
			return
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, int(fs * sc))
		var p2 := Vector2(s.x * 0.5 - ts.x * 0.5, s.y * 0.27 + 130 + ts.y * 0.3)
		var col2: Color = [Color(0.2, 0.95, 0.35), Color(0.2, 0.95, 0.35), Color(1, 0.85, 0.1), Color(1, 0.25, 0.2)][clampi(v, 0, 3)]
		col2.a = alpha
		draw_string_outline(font, p2, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * sc), 26, Color(0.08, 0.1, 0.3, alpha))
		draw_string(font, p2, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * sc), col2)
