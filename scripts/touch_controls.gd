class_name TouchControls
extends Control
## 画面タップ操作。マルチタッチ対応で、指を滑らせて ◀▶ を切り替えることもできる。
## ボタンを押すと対応する入力アクション（accel / left など）が押された状態になる。

var hud: Node   # アイテムアイコン表示用
var buttons := []          # [{name, action, center, r, label, sym}]
var _touch := {}           # touch index -> button index
var _held := {}            # button index -> 押している指の数
var _pulse := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s := get_viewport_rect().size
	var W := s.x
	var H := s.y
	var u := H / 720.0
	buttons = [
		{"action": "left", "center": Vector2(118, H - 150 * u), "r": 92 * u, "sym": "◀", "label": ""},
		{"action": "right", "center": Vector2(118 + 205 * u, H - 150 * u), "r": 92 * u, "sym": "▶", "label": ""},
		{"action": "accel", "center": Vector2(W - 112 * u, H - 250 * u), "r": 96 * u, "sym": "▲", "label": "アクセル"},
		{"action": "brake", "center": Vector2(W - 112 * u, H - 70 * u), "r": 58 * u, "sym": "▼", "label": "ブレーキ"},
		{"action": "drift", "center": Vector2(W - 300 * u, H - 125 * u), "r": 88 * u, "sym": "", "label": "ドリフト"},
		{"action": "item", "center": Vector2(W - 480 * u, H - 95 * u), "r": 70 * u, "sym": "", "label": "アイテム"},
	]
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _hit(pos: Vector2) -> int:
	var best := -1
	var bd := INF
	for i in buttons.size():
		var b: Dictionary = buttons[i]
		var dd := pos.distance_to(b.center)
		if dd < b.r * 1.25 and dd < bd:
			bd = dd
			best = i
	return best


func _press(i: int) -> void:
	if i < 0:
		return
	_held[i] = _held.get(i, 0) + 1
	Input.action_press(buttons[i].action)


func _release(i: int) -> void:
	if i < 0 or not _held.has(i):
		return
	_held[i] -= 1
	if _held[i] <= 0:
		_held.erase(i)
		Input.action_release(buttons[i].action)


func release_all() -> void:
	for i in _held.keys():
		Input.action_release(buttons[i].action)
	_held.clear()
	_touch.clear()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var i := _hit(event.position)
			if i >= 0:
				_touch[event.index] = i
				_press(i)
		else:
			if _touch.has(event.index):
				_release(_touch[event.index])
				_touch.erase(event.index)
	elif event is InputEventScreenDrag:
		var i := _hit(event.position)
		var old: int = _touch.get(event.index, -1)
		if i != old:
			# ◀ ⇔ ▶ の間で指を滑らせたときだけ切り替える（他のボタンは離すまで保持）
			var steer_old: bool = old >= 0 and buttons[old].action in ["left", "right"]
			var steer_new: bool = i >= 0 and buttons[i].action in ["left", "right"]
			if steer_old and (steer_new or i < 0):
				_release(old)
				_touch.erase(event.index)
				if i >= 0:
					_touch[event.index] = i
					_press(i)


func _draw() -> void:
	var font := get_theme_default_font()
	for i in buttons.size():
		var b: Dictionary = buttons[i]
		var held := _held.has(i) or Input.is_action_pressed(b.action)
		var c: Vector2 = b.center
		var r: float = b.r * (0.93 if held else 1.0)
		var fill := Color(1, 1, 1, 0.28)
		var ring := Color(1, 1, 1, 0.85)
		match b.action:
			"accel":
				fill = Color(0.2, 0.85, 0.35, 0.45)
			"brake":
				fill = Color(1, 0.35, 0.3, 0.4)
			"drift":
				fill = Color(0.25, 0.55, 1.0, 0.45)
			"item":
				fill = Color(1, 0.8, 0.15, 0.45)
		if held:
			fill = Color(1, 0.9, 0.3, 0.75)
		draw_circle(c + Vector2(0, 6), r, Color(0, 0, 0, 0.18))
		draw_circle(c, r, fill)
		draw_arc(c, r, 0, TAU, 48, ring, 5.0, true)
		var sym: String = b.sym
		if b.action == "item":
			var it: String = hud.item_to_show() if hud else ""
			if it != "":
				ItemArt.draw(self, it, c - Vector2(0, 8), r * 0.55)
			else:
				_draw_gift(c - Vector2(0, 8), r * 0.45)
		elif b.action == "drift":
			# 💨 風のマーク
			for k in 3:
				var y := -r * 0.3 + k * r * 0.2
				var w := r * (0.7 - absf(k - 1) * 0.15)
				draw_line(c + Vector2(-w * 0.6, y - 6), c + Vector2(w * 0.5, y - 6), Color(1, 1, 1, 0.95), 7.0 * r / 90.0, true)
				draw_arc(c + Vector2(w * 0.5, y - 6 - r * 0.07), r * 0.07, -PI / 2, PI / 2, 8, Color(1, 1, 1, 0.95), 5.0, true)
		if sym != "":
			var fs := int(r * (0.9 if b.label == "" else 0.7))
			var ts := font.get_string_size(sym, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
			var y_off := -r * 0.12 if b.label != "" else 0.0
			draw_string_outline(font, c + Vector2(-ts.x * 0.5, ts.y * 0.32 + y_off), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.08, 0.12, 0.3, 0.8))
			draw_string(font, c + Vector2(-ts.x * 0.5, ts.y * 0.32 + y_off), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		if b.label != "":
			var lfs := int(max(18.0, r * 0.26))
			var ls := font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, lfs)
			var p := c + Vector2(-ls.x * 0.5, r * 0.62)
			draw_string_outline(font, p, b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, 6, Color(0.08, 0.12, 0.3, 0.9))
			draw_string(font, p, b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color.WHITE)


func _draw_gift(c: Vector2, s: float) -> void:
	draw_rect(Rect2(c + Vector2(-0.8, -0.35) * s, Vector2(1.6, 1.15) * s), Color(1, 0.35, 0.4))
	draw_rect(Rect2(c + Vector2(-0.9, -0.7) * s, Vector2(1.8, 0.4) * s), Color(1, 0.45, 0.5))
	draw_rect(Rect2(c + Vector2(-0.15, -0.7) * s, Vector2(0.3, 1.5) * s), Color(1, 0.9, 0.3))
	draw_circle(c + Vector2(-0.3, -0.85) * s, s * 0.25, Color(1, 0.9, 0.3))
	draw_circle(c + Vector2(0.3, -0.85) * s, s * 0.25, Color(1, 0.9, 0.3))
