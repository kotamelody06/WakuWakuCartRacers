class_name UI
## メニュー画面用の共通スタイル（丸くてカラフルなボタンなど）。

const YELLOW := Color(1.0, 0.82, 0.15)
const RED := Color(1.0, 0.3, 0.25)
const BLUE := Color(0.18, 0.5, 1.0)
const GREEN := Color(0.25, 0.78, 0.35)
const NAVY := Color(0.08, 0.12, 0.3)


static func box(bg: Color, radius := 26, border := 5, border_col := Color(1, 1, 1), shadow := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_col
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = shadow
	s.shadow_offset = Vector2(0, 5)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 12
	s.anti_aliasing = true
	return s


static func style_button(b: Button, col: Color, font_size := 34) -> void:
	b.add_theme_stylebox_override("normal", box(col))
	b.add_theme_stylebox_override("hover", box(col.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", box(col.darkened(0.15), 26, 5, YELLOW))
	b.add_theme_stylebox_override("focus", box(col, 26, 6, YELLOW))
	b.add_theme_stylebox_override("disabled", box(col.darkened(0.4)))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", col.darkened(0.55))
	b.add_theme_constant_override("outline_size", 8)
	b.pressed.connect(func(): Sfx.play("click"))


static func button(text: String, col: Color, font_size := 34, min_size := Vector2(260, 84)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	style_button(b, col, font_size)
	return b


static func label(text: String, size := 32, col := Color.WHITE, outline := 10, outline_col := NAVY) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = col
	ls.outline_size = outline
	ls.outline_color = outline_col
	ls.shadow_size = 0
	ls.shadow_color = Color(0, 0, 0, 0.35)
	ls.shadow_offset = Vector2(0, 4)
	l.label_settings = ls
	return l


static func stars(n: int, of := 5) -> String:
	var s := ""
	for i in of:
		s += "★" if i < n else "☆"
	return s


## 画面上部の見出し帯
static func header(parent: Control, text: String, col := BLUE) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(col, 0, 0, Color.WHITE, 10))
	p.set_anchors_preset(Control.PRESET_TOP_WIDE)
	p.offset_bottom = 90
	var l := label(text, 44, Color.WHITE, 12, col.darkened(0.6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	parent.add_child(p)
	return p


const MEDAL := [Color(1.0, 0.8, 0.15), Color(0.82, 0.86, 0.95), Color(0.9, 0.55, 0.3)]


## トロフィーの絵（place: 1=金 2=銀 3=銅, 0=まだ）
static func draw_trophy(ci: CanvasItem, c: Vector2, s: float, place: int) -> void:
	var col: Color = MEDAL[place - 1] if place >= 1 and place <= 3 else Color(1, 1, 1, 0.18)
	var dark := col.darkened(0.35)
	if place == 0:
		dark = Color(1, 1, 1, 0.25)
	# 取っ手
	ci.draw_arc(c + Vector2(-0.55, -0.45) * s, 0.28 * s, PI * 0.5, PI * 1.5, 12, col, 0.12 * s, true)
	ci.draw_arc(c + Vector2(0.55, -0.45) * s, 0.28 * s, -PI * 0.5, PI * 0.5, 12, col, 0.12 * s, true)
	# 杯
	var cup := PackedVector2Array()
	for k in 13:
		var a := PI * k / 12.0
		cup.append(c + Vector2(-cos(a) * 0.62, -0.85 + sin(a) * 0.75) * s)
	ci.draw_colored_polygon(cup, col)
	ci.draw_rect(Rect2(c + Vector2(-0.12, -0.12) * s, Vector2(0.24, 0.45) * s), dark)
	ci.draw_rect(Rect2(c + Vector2(-0.45, 0.3) * s, Vector2(0.9, 0.22) * s), col)
	ci.draw_rect(Rect2(c + Vector2(-0.55, 0.5) * s, Vector2(1.1, 0.3) * s), dark)
	if place >= 1:
		ci.draw_circle(c + Vector2(-0.22, -0.62) * s, 0.09 * s, Color(1, 1, 1, 0.8))


static func draw_coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Color(0.85, 0.55, 0.05))
	ci.draw_circle(c, r * 0.82, Color(1.0, 0.82, 0.2))
	ci.draw_rect(Rect2(c + Vector2(-0.12, -0.45) * r, Vector2(0.24, 0.9) * r), Color(0.85, 0.55, 0.05))


## 絵を描くだけの小さなコントロール
class Icon extends Control:
	var kind := "coin"
	var place := 0

	func _init(k := "coin", p := 0, sz := Vector2(48, 48)) -> void:
		kind = k
		place = p
		custom_minimum_size = sz
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var s := minf(size.x, size.y) * 0.5
		if kind == "coin":
			UI.draw_coin(self, c, s * 0.9)
		else:
			UI.draw_trophy(self, c + Vector2(0, s * 0.1), s * 0.95, place)


## コインの数を表示する帯
static func coin_badge(parent: Control) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(0.08, 0.12, 0.3, 0.75), 30, 4, Color(1, 0.85, 0.3), 4))
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.position = Vector2(-260, 14)
	p.custom_minimum_size = Vector2(230, 64)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	h.add_child(Icon.new("coin", 0, Vector2(40, 40)))
	var l := label(str(Game.coins), 34, YELLOW, 8)
	l.name = "Count"
	h.add_child(l)
	parent.add_child(p)
	return p


## 難易度ボタンの列
static func difficulty_row(on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var btns: Array[Button] = []
	for i in Game.DIFFICULTIES.size():
		var d: Dictionary = Game.DIFFICULTIES[i]
		var b := button(d.name, d.color.darkened(0.15), 28, Vector2(190, 70))
		btns.append(b)
		row.add_child(b)
	var refresh := func():
		for i in btns.size():
			var on := i == Game.difficulty
			var d: Dictionary = Game.DIFFICULTIES[i]
			btns[i].add_theme_stylebox_override("normal", box(d.color.darkened(0.15) if on else Color(0.3, 0.32, 0.4), 26, 7 if on else 4, YELLOW if on else Color.WHITE))
			btns[i].modulate = Color.WHITE if on else Color(0.85, 0.85, 0.9)
	for i in btns.size():
		btns[i].pressed.connect(func():
			Game.difficulty = i
			refresh.call()
			on_change.call())
	refresh.call()
	return row
