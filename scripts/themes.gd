class_name Themes
## コースの見た目（空・光・路面・地面・壁・柵）のテーマ表。

const T := {
	"grass": {
		"sky": [Color(0.2, 0.5, 0.95), Color(0.7, 0.87, 1.0), Color(0.6, 0.8, 0.6), Color(0.3, 0.5, 0.3)],
		"ambient": Color(0.72, 0.74, 0.82), "sun": [1.25, Color(1, 0.97, 0.9)],
		"road": {"base": Color(0.36, 0.36, 0.39), "curb_a": Color(0.95, 0.15, 0.15), "curb_b": Color(1, 1, 1), "center": Color(0.92, 0.92, 0.92)},
		"ground": Color(0.36, 0.72, 0.28), "wall": Color(0.16, 0.48, 0.18), "rail": "wood", "skirt": Color(0.45, 0.3, 0.18),
		"dust": Color(0.55, 0.8, 0.4), "offroad_mult": 0.55,
	},
	"fruit": {
		"sky": [Color(0.3, 0.6, 1.0), Color(0.85, 0.93, 1.0), Color(0.75, 0.9, 0.6), Color(0.4, 0.6, 0.3)],
		"ambient": Color(0.78, 0.76, 0.8), "sun": [1.25, Color(1, 0.95, 0.85)],
		"road": {"base": Color(0.72, 0.58, 0.46), "curb_a": Color(1.0, 0.55, 0.1), "curb_b": Color(1, 1, 1), "center": Color(1, 0.95, 0.8), "style": "tiles"},
		"ground": Color(0.46, 0.78, 0.3), "wall": Color(0.62, 0.42, 0.25), "wall_style": "fence", "rail": "wood", "skirt": Color(0.45, 0.3, 0.18),
		"dust": Color(0.6, 0.85, 0.4), "offroad_mult": 0.55,
	},
	"beach": {
		"sky": [Color(0.1, 0.5, 1.0), Color(0.75, 0.92, 1.0), Color(0.6, 0.85, 1.0), Color(0.2, 0.5, 0.8)],
		"ambient": Color(0.7, 0.72, 0.78), "sun": [1.1, Color(1, 0.96, 0.88)],
		"road": {"base": Color(0.38, 0.4, 0.45), "curb_a": Color(0.1, 0.55, 1.0), "curb_b": Color(1, 1, 1), "center": Color(1, 1, 1)},
		"ground": Color(0.9, 0.76, 0.5), "wall": Color(0.85, 0.72, 0.46), "wall_style": "dune", "rail": "wood", "skirt": Color(0.85, 0.72, 0.45),
		"dust": Color(1, 0.92, 0.7), "offroad_mult": 0.6,
	},
	"rainbow": {
		"sky": [Color(0.55, 0.45, 0.95), Color(1.0, 0.8, 0.9), Color(1.0, 0.85, 0.95), Color(0.6, 0.55, 1.0)],
		"ambient": Color(0.7, 0.66, 0.78), "sun": [0.95, Color(1, 0.95, 1.0)],
		"road": {"base": Color(1, 1, 1), "curb_a": Color(1, 1, 1), "curb_b": Color(1.0, 0.6, 0.85), "style": "rainbow"},
		"ground": null, "rail": "candy", "skirt": Color(0.95, 0.9, 1.0),
		"dust": Color(1, 1, 1), "offroad_mult": 0.6,
	},
	"volcano": {
		"sky": [Color(0.25, 0.08, 0.1), Color(0.95, 0.4, 0.2), Color(0.6, 0.2, 0.1), Color(0.2, 0.05, 0.02)],
		"ambient": Color(0.75, 0.55, 0.5), "sun": [0.9, Color(1, 0.7, 0.5)], "fog": [Color(0.7, 0.3, 0.15), 0.003],
		"road": {"base": Color(0.26, 0.22, 0.22), "curb_a": Color(1.0, 0.5, 0.05), "curb_b": Color(0.15, 0.12, 0.12), "center": Color(0.9, 0.9, 0.9)},
		"ground": "lava", "rail": "hazard", "skirt": Color(0.18, 0.13, 0.12),
		"dust": Color(0.5, 0.4, 0.35), "offroad_mult": 0.6,
	},
	"jungle": {
		"sky": [Color(0.25, 0.55, 0.85), Color(0.75, 0.9, 0.85), Color(0.4, 0.6, 0.4), Color(0.15, 0.3, 0.15)],
		"ambient": Color(0.62, 0.72, 0.62), "sun": [1.15, Color(1, 0.95, 0.8)], "fog": [Color(0.6, 0.75, 0.6), 0.004],
		"road": {"base": Color(0.55, 0.4, 0.26), "curb_a": Color(0.42, 0.28, 0.15), "curb_b": Color(0.62, 0.45, 0.26), "style": "dirt"},
		"ground": Color(0.2, 0.38, 0.15), "wall": Color(0.12, 0.35, 0.12), "rail": "wood", "skirt": Color(0.35, 0.24, 0.14),
		"dust": Color(0.45, 0.33, 0.2), "offroad_mult": 0.5,
	},
	"desert": {
		"sky": [Color(0.3, 0.55, 0.9), Color(1.0, 0.9, 0.7), Color(0.95, 0.8, 0.55), Color(0.7, 0.55, 0.35)],
		"ambient": Color(0.7, 0.62, 0.55), "sun": [1.05, Color(1, 0.92, 0.78)], "fog": [Color(0.95, 0.85, 0.65), 0.0015],
		"road": {"base": Color(0.6, 0.5, 0.38), "curb_a": Color(0.55, 0.35, 0.2), "curb_b": Color(0.95, 0.88, 0.7), "style": "tiles"},
		"ground": Color(0.85, 0.66, 0.4), "wall": Color(0.8, 0.62, 0.38), "wall_style": "dune", "rail": "stone", "skirt": Color(0.7, 0.55, 0.36),
		"dust": Color(1, 0.88, 0.6), "offroad_mult": 0.6, "tunnel": Color(0.7, 0.58, 0.4),
	},
	"cave": {
		"bg": Color(0.02, 0.02, 0.06),
		"ambient": Color(0.45, 0.5, 0.75), "ambient_energy": 0.7, "sun": [0.45, Color(0.6, 0.7, 1.0)], "fog": [Color(0.05, 0.06, 0.15), 0.012],
		"road": {"base": Color(0.3, 0.3, 0.36), "curb_a": Color(0.2, 0.9, 1.0), "curb_b": Color(0.15, 0.15, 0.2), "glow": "curb"},
		"ground": Color(0.14, 0.13, 0.18), "rail": "stone", "skirt": Color(0.2, 0.19, 0.25),
		"dust": Color(0.5, 0.5, 0.6), "offroad_mult": 0.6, "tunnel": Color(0.25, 0.25, 0.35),
	},
	"snow": {
		"sky": [Color(0.35, 0.55, 0.9), Color(0.85, 0.9, 1.0), Color(0.85, 0.9, 1.0), Color(0.8, 0.85, 0.95)],
		"ambient": Color(0.78, 0.82, 0.92), "sun": [1.25, Color(1, 0.97, 0.9)], "fog": [Color(0.85, 0.9, 1.0), 0.004],
		"road": {"base": Color(0.5, 0.55, 0.66), "curb_a": Color(0.2, 0.45, 1.0), "curb_b": Color(1, 1, 1)},
		"ground": Color(0.93, 0.95, 1.0), "wall": Color(0.97, 0.98, 1.0), "rail": "blue", "skirt": Color(0.85, 0.88, 0.95),
		"dust": Color(1, 1, 1), "offroad_mult": 0.6, "tunnel": Color(0.35, 0.38, 0.5),
	},
	"night": {
		"sky": [Color(0.02, 0.03, 0.12), Color(0.15, 0.12, 0.35), Color(0.1, 0.08, 0.2), Color(0.02, 0.02, 0.05)], "stars": true,
		"ambient": Color(0.45, 0.48, 0.7), "ambient_energy": 0.8, "sun": [0.55, Color(0.7, 0.75, 1.0)],
		"road": {"base": Color(0.2, 0.2, 0.24), "curb_a": Color(1, 1, 1), "curb_b": Color(1, 1, 1), "center": Color(1.0, 0.8, 0.1), "style": "highway", "glow": "lines"},
		"ground": "city", "rail": "metal", "skirt": Color(0.45, 0.45, 0.5),
		"dust": Color(0.6, 0.6, 0.7), "offroad_mult": 0.6, "tunnel": Color(0.5, 0.5, 0.55),
	},
	"cloud": {
		"sky": [Color(0.2, 0.5, 1.0), Color(0.8, 0.92, 1.0), Color(0.9, 0.95, 1.0), Color(0.6, 0.8, 1.0)],
		"ambient": Color(0.72, 0.75, 0.85), "sun": [1.05, Color(1, 0.98, 0.92)],
		"road": {"base": Color(0.66, 0.7, 0.82), "curb_a": Color(1.0, 0.8, 0.2), "curb_b": Color(1, 1, 1), "center": Color(0.55, 0.75, 1.0)},
		"ground": null, "rail": "gold", "skirt": Color(0.95, 0.96, 1.0),
		"dust": Color(1, 1, 1), "offroad_mult": 0.6,
	},
	"space": {
		"sky": [Color(0.02, 0.0, 0.06), Color(0.12, 0.04, 0.25), Color(0.1, 0.03, 0.2), Color(0.01, 0.0, 0.04)], "stars": true,
		"ambient": Color(0.5, 0.45, 0.75), "ambient_energy": 0.8, "sun": [0.9, Color(0.85, 0.85, 1.0)],
		"road": {"base": Color(0.1, 0.07, 0.2), "curb_a": Color(0.2, 1.0, 1.0), "curb_b": Color(1.0, 0.3, 0.9), "style": "neon", "glow": "neon"},
		"ground": null, "rail": "neon", "skirt": Color(0.12, 0.08, 0.22),
		"dust": Color(0.6, 0.8, 1), "offroad_mult": 0.6,
	},
}


static func get_theme(name: String) -> Dictionary:
	return T.get(name, T["grass"])
