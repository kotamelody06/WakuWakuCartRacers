class_name ItemArt
## アイテムのアイコン（2D）を図形で描く。

const NAMES := {
	"boost": "スピードブースト",
	"spin": "スピンボール",
	"barrier": "バリア",
	"rocket": "ロケットダッシュ",
	"slip": "すべすべボール",
}
const ORDER := ["boost", "spin", "barrier", "rocket", "slip"]


static func draw(ci: CanvasItem, it: String, c: Vector2, s: float) -> void:
	match it:
		"boost":
			var pts := PackedVector2Array([
				Vector2(0.15, -0.95), Vector2(-0.55, 0.1), Vector2(-0.05, 0.1), Vector2(-0.2, 0.95),
				Vector2(0.55, -0.15), Vector2(0.05, -0.15), Vector2(0.3, -0.95)])
			var o := PackedVector2Array()
			for p in pts:
				o.append(c + p * s)
			ci.draw_colored_polygon(o, Color(1, 0.85, 0.1))
			o.append(o[0])
			ci.draw_polyline(o, Color(0.7, 0.35, 0.0), s * 0.08, true)
		"spin":
			ci.draw_circle(c, s * 0.8, Color(0.2, 0.55, 1.0))
			ci.draw_arc(c, s * 0.8, 0, TAU, 32, Color(0.05, 0.2, 0.6), s * 0.08, true)
			var sp := PackedVector2Array()
			for k in 40:
				var a := k * 0.35
				var r := s * 0.05 + k * s * 0.016
				sp.append(c + Vector2(cos(a), sin(a)) * r)
			ci.draw_polyline(sp, Color(1, 1, 1), s * 0.1, true)
		"barrier":
			var pts := PackedVector2Array()
			for k in 13:
				var a := PI + k * PI / 12.0
				pts.append(c + Vector2(cos(a) * 0.75, sin(a) * 0.3 - 0.35) * s)
			pts.append(c + Vector2(0.75, 0.1) * s)
			pts.append(c + Vector2(0, 0.95) * s)
			pts.append(c + Vector2(-0.75, 0.1) * s)
			ci.draw_colored_polygon(pts, Color(0.3, 0.85, 1.0))
			pts.append(pts[0])
			ci.draw_polyline(pts, Color(0.05, 0.35, 0.6), s * 0.08, true)
			ci.draw_line(c + Vector2(0, -0.55) * s, c + Vector2(0, 0.75) * s, Color(1, 1, 1, 0.8), s * 0.12)
			ci.draw_line(c + Vector2(-0.55, -0.05) * s, c + Vector2(0.55, -0.05) * s, Color(1, 1, 1, 0.8), s * 0.12)
		"rocket":
			var body := PackedVector2Array([c + Vector2(0, -0.95) * s, c + Vector2(0.32, -0.45) * s, c + Vector2(0.32, 0.45) * s,
				c + Vector2(-0.32, 0.45) * s, c + Vector2(-0.32, -0.45) * s])
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.32, 0.1) * s, c + Vector2(-0.65, 0.6) * s, c + Vector2(-0.32, 0.45) * s]), Color(0.2, 0.4, 1))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.32, 0.1) * s, c + Vector2(0.65, 0.6) * s, c + Vector2(0.32, 0.45) * s]), Color(0.2, 0.4, 1))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.22, 0.45) * s, c + Vector2(0, 0.98) * s, c + Vector2(0.22, 0.45) * s]), Color(1, 0.6, 0.1))
			ci.draw_colored_polygon(body, Color(1, 0.3, 0.25))
			ci.draw_circle(c + Vector2(0, -0.2) * s, s * 0.16, Color(0.8, 0.95, 1))
		"slip":
			var pud := PackedVector2Array()
			for k in 24:
				var a := k * TAU / 24.0
				pud.append(c + Vector2(cos(a) * 0.9, 0.55 + sin(a) * 0.25) * s)
			ci.draw_colored_polygon(pud, Color(1, 0.9, 0.4, 0.6))
			ci.draw_circle(c, s * 0.62, Color(1, 0.82, 0.2))
			ci.draw_arc(c, s * 0.62, 0, TAU, 32, Color(0.75, 0.45, 0.0), s * 0.07, true)
			ci.draw_circle(c + Vector2(-0.22, -0.22) * s, s * 0.14, Color(1, 1, 1, 0.9))
			ci.draw_circle(c + Vector2(0.1, -0.35) * s, s * 0.06, Color(1, 1, 1, 0.9))
