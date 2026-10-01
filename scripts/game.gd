extends Node
## ゲーム全体の状態（キャラ・カート・コース・カップの表、選択中の内容、設定、セーブ）を管理する自動読み込みノード。

const SAVE_PATH := "user://wakuwaku_save.cfg"
const TOTAL_LAPS := 3
const RACER_COUNT := 6
const STANDARD_KARTS := 3   # CPUが使うカート（ゴールデンカート以外）

# ---------------------------------------------------------------- キャラクター
# speed / accel / handling は -1〜+1 の補正値（カート性能に上乗せ）
const CHARACTERS := [
	{"id": "rai", "name": "ライ", "desc": "元気いっぱいの主人公！\nバランスのとれた走り。",
		"color": Color(1.0, 0.33, 0.22), "sub": Color(1.0, 0.85, 0.2), "speed": 0, "accel": 0, "handling": 0},
	{"id": "mimi", "name": "ミミ", "desc": "ぴょんぴょんうさぎ。\n加速と曲がりが得意。",
		"color": Color(1.0, 0.55, 0.78), "sub": Color(1, 1, 1), "speed": -1, "accel": 1, "handling": 1},
	{"id": "gameron", "name": "ガメロン", "desc": "どっしりカメさん。\n最高速度が高い！",
		"color": Color(0.25, 0.72, 0.32), "sub": Color(0.95, 0.8, 0.35), "speed": 1, "accel": -1, "handling": -1},
	{"id": "kon", "name": "コン", "desc": "すばしっこいキツネ。\nカーブが大得意。",
		"color": Color(1.0, 0.58, 0.12), "sub": Color(1, 1, 1), "speed": 0, "accel": 0, "handling": 1},
]

# ---------------------------------------------------------------- カート（星の数）
const KARTS := [
	{"id": "speedstar", "name": "スピードスター", "desc": "最高速度が高いスピードタイプ", "speed": 5, "accel": 2, "handling": 2,
		"color": Color(0.15, 0.45, 1.0)},
	{"id": "balancer", "name": "バランサー", "desc": "なんでも平均のバランスタイプ", "speed": 3, "accel": 3, "handling": 3,
		"color": Color(0.95, 0.2, 0.25)},
	{"id": "dashbug", "name": "ダッシュバグ", "desc": "加速が速い加速タイプ", "speed": 2, "accel": 5, "handling": 4,
		"color": Color(0.2, 0.8, 0.35)},
	{"id": "golden", "name": "ゴールデンカート", "desc": "ぜんぶのカップで優勝した人だけが乗れる特別なカート", "speed": 5, "accel": 4, "handling": 4,
		"color": Color(1.0, 0.78, 0.2), "locked": true},
]

# ---------------------------------------------------------------- コース
# pts: 中心線の制御点 (x, 高さ, z)。
# 特徴の位置は [x, z]（座標）か、数字（スタートからの距離 m）で指定する。
#   ramps: [位置, 飛び出す強さ]   gaps/falls/tunnels/ice/bridge: [始まり, 終わり]
#   dash: [位置, 横ずれ]  cross: 道を横切る障害物の位置  traffic: 走る車の台数
#   items を書かないと、アイテムボックスは自動で5か所に置かれる。
const COURSES := [
	# ---------------- グリーンカップ
	{"id": "grass", "name": "わくわく草原", "level": "初心者向け", "stars": 1, "theme": "grass",
		"desc": "草原・小さな橋・池・木・ジャンプ台",
		"width": 18.0, "edge": "shoulder", "shoulder": 9.0, "offroad": "grass",
		"pts": [[0,0,0],[0,0,90],[12,0,150],[55,0,180],[105,0,170],[135,0,130],[175,0,110],[230,0,118],[265,0,155],
			[305,0,165],[335,0,125],[335,0,40],[318,0,-25],[265,0,-55],[200,0,-40],[150,0,-75],[90,0,-95],[30,0,-75]],
		"bridge": [[168, 108], [238, 124]],
		"pond": [203, 112, 34],
		"ramps": [[[335, 70], 5.0]],
		"items": [[0, 45], [105, 170], [320, 150], [318, -25], [120, -85]],
	},
	{"id": "fruit", "name": "フルーツロード", "level": "初心者向け", "stars": 1, "theme": "fruit",
		"desc": "くだものの木・大きなフルーツ・ころがるオレンジ",
		"width": 18.0, "edge": "shoulder", "shoulder": 8.0, "offroad": "grass",
		"pts": [[0,0,0],[0,0,80],[20,0,135],[70,0,160],[120,0,140],[150,0,95],[195,0,70],[250,0,85],[285,0,130],
			[330,0,140],[360,0,100],[355,0,30],[320,0,-20],[260,0,-35],[200,0,-20],[140,0,-45],[80,0,-80],[25,0,-60]],
		"ramps": [[90, 5.0]],
		"dash": [[330, 0], [600, -3], [880, 3]],
		"cross": [190, 400, 740, 990], "cross_kind": "orange",
	},
	{"id": "beach", "name": "ひなたビーチ", "level": "初心者向け", "stars": 1, "theme": "beach",
		"desc": "砂浜・ヤシの木・海の上の橋・よこ歩きカニ",
		"width": 18.0, "edge": "shoulder", "shoulder": 7.0, "offroad": "sand",
		"pts": [[0,0,0],[0,0,70],[25,0,115],[80,0,125],[150,0,110],[220,0,125],[290,0,120],[345,0,95],[360,0,40],
			[330,0,0],[270,0,-10],[230,0,-45],[170,0,-60],[100,0,-50],[40,0,-60],[8,0,-35]],
		"bridge": [380, 430],
		"ramps": [[300, 5.5]],
		"dash": [[200, 0], [720, 0]],
		"cross": [150, 500, 610, 800], "cross_kind": "crab",
	},
	{"id": "rainbow", "name": "にじいろサーキット", "level": "初心者向け", "stars": 1, "theme": "rainbow",
		"desc": "空にうかぶ虹の道・ダッシュ板がいっぱい",
		"width": 18.0, "edge": "rail", "offroad": "void",
		"pts": [[0,20,0],[0,22,80],[15,26,140],[60,30,170],[115,32,160],[140,30,115],[125,26,70],[150,22,25],[205,20,15],
			[250,22,50],[265,26,110],[300,30,150],[350,28,130],[365,24,70],[350,20,0],[310,18,-55],[245,18,-80],[175,20,-70],
			[110,20,-90],[45,20,-70]],
		"ramps": [[790, 6.0]],
		"dash": [[100, 0], [230, -4], [230, 4], [500, 0], [760, -4], [860, 4], [1020, 0], [1150, 0]],
		"cross": [560, 950], "cross_kind": "star",
	},
	# ---------------- アドベンチャーカップ
	{"id": "volcano", "name": "ぐつぐつ火山", "level": "中級", "stars": 2, "theme": "volcano",
		"desc": "溶岩・急カーブ・ジャンプ・落下ゾーン",
		"width": 16.0, "edge": "rail", "offroad": "lava", "base_drop": 7.0,
		"pts": [[0,0,0],[0,0,110],[18,0,150],[60,0,160],[85,0,130],[72,0,90],[95,0,55],[150,0,50],[195,0,75],[205,0,125],
			[245,0,155],[295,0,145],[310,0,95],[285,0,45],[300,0,-5],[270,0,-60],[205,0,-75],[155,0,-45],[100,0,-80],[40,0,-75],[8,0,-45]],
		"ramps": [[[0, 44], 7.5]],
		"gaps": [[[0, 53], [0, 62]]],
		"falls": [[[70, 150], [82, 75]], [[300, 60], [292, 15]], [[190, -72], [160, -48]]],
		"volcano": [145, 125],
		"items": [[0, 90], [150, 50], [245, 155], [270, -60], [100, -80]],
	},
	{"id": "jungle", "name": "ジャングルロード", "level": "中級", "stars": 2, "theme": "jungle",
		"desc": "うっそうとした森・川の上の橋・谷のジャンプ・ころがる丸太",
		"width": 16.0, "edge": "shoulder", "shoulder": 6.0, "offroad": "mud", "base_drop": 3.5,
		"pts": [[0,0,0],[0,0,70],[-15,0,120],[10,0,165],[60,0,175],[95,0,145],[90,0,100],[120,0,65],[170,0,75],[190,0,125],
			[230,0,160],[285,0,150],[300,0,100],[270,0,55],[285,0,5],[270,0,-50],[220,0,-70],[165,0,-45],[115,0,-70],[60,0,-85],[15,0,-55]],
		"bridge": [478, 517],
		"rivers": [[497, 300, 18], [992, 240, 14]],
		"ramps": [[980, 7.0]],
		"gaps": [[986, 997]],
		"cross": [230, 640, 870], "cross_kind": "log",
	},
	{"id": "desert", "name": "砂漠遺跡", "level": "中級", "stars": 2, "theme": "desert",
		"desc": "砂の海・古い神殿のトンネル・ころがる石の玉",
		"width": 16.0, "edge": "shoulder", "shoulder": 7.0, "offroad": "sand",
		"pts": [[0,0,0],[0,0,110],[15,0,165],[65,0,185],[115,0,160],[120,0,110],[160,0,80],[215,0,95],[240,0,150],[290,0,175],
			[345,0,150],[355,0,90],[320,0,45],[335,0,-10],[310,0,-65],[250,0,-80],[200,0,-45],[145,0,-40],[95,0,-80],[40,0,-80],[8,0,-45]],
		"tunnels": [[560, 690]],
		"ramps": [[100, 6.5], [830, 6.0]],
		"dash": [[400, 0], [1000, 0]],
		"cross": [300, 520, 900, 1130], "cross_kind": "boulder",
		"arches": [420, 1100],
	},
	{"id": "cave", "name": "洞窟コース", "level": "中級", "stars": 2, "theme": "cave",
		"desc": "光る結晶・地底湖・がけっぷち・トロッコ",
		"width": 16.0, "edge": "rail", "offroad": "rock", "base_drop": 10.0,
		"pts": [[0,0,0],[0,-2,70],[20,-5,125],[70,-8,140],[100,-8,105],[85,-6,60],[110,-4,20],[160,-4,25],[185,-6,70],[175,-9,120],
			[205,-12,160],[260,-12,165],[290,-10,120],[270,-7,75],[295,-4,30],[285,-2,-30],[235,0,-60],[175,0,-50],[120,0,-75],[60,0,-80],[15,0,-50]],
		"falls": [[180, 330], [600, 740]],
		"tunnels": [[380, 470], [980, 1060]],
		"ramps": [[775, 7.5]],
		"gaps": [[781, 792]],
		"dash": [[1100, 0]],
		"cross": [100, 520, 900], "cross_kind": "minecart",
		"lake": [140, 60, 38],
	},
	# ---------------- スターダストカップ
	{"id": "snow", "name": "キラキラ雪山", "level": "上級", "stars": 3, "theme": "snow",
		"desc": "雪道・氷・坂道・洞窟・大ジャンプ",
		"width": 16.0, "edge": "shoulder", "shoulder": 5.0, "offroad": "snow",
		"pts": [[0,0,0],[0,2,90],[15,8,150],[60,14,185],[120,18,190],[170,20,160],[185,20,105],[160,18,60],[170,14,10],
			[215,10,-10],[260,8,20],[290,8,70],[320,6,40],[320,3,-40],[280,1,-90],[200,0,-110],[120,0,-95],[60,0,-100],[15,0,-65]],
		"ramps": [[[163, 38], 9.0], [[0, 60], 5.0]],
		"ice": [[[322, 10], [240, -104]]],
		"tunnels": [[[178, 150], [162, 72]]],
		"items": [[0, 30], [120, 190], [215, -10], [320, 0], [100, -97]],
	},
	{"id": "night", "name": "星空ハイウェイ", "level": "上級", "stars": 3, "theme": "night",
		"desc": "夜の高速道路・街の明かり・走る車をよけろ！",
		"width": 18.0, "edge": "rail", "offroad": "city", "base_drop": 12.0,
		"pts": [[0,12,0],[0,12,150],[25,14,210],[90,16,225],[250,18,225],[320,18,200],[335,16,140],[300,14,100],[310,14,50],
			[360,14,20],[400,14,-30],[385,14,-90],[320,12,-110],[200,12,-110],[80,12,-110],[20,12,-80]],
		"tunnels": [[905, 990]],
		"ramps": [[420, 6.0]],
		"dash": [[300, -4], [1000, 4], [1150, -4]],
		"traffic": 5,
	},
	{"id": "cloud", "name": "雲の上コース", "level": "上級", "stars": 3, "theme": "cloud",
		"desc": "柵のない雲の道・雲から雲への大ジャンプ・かみなり雲",
		"width": 15.0, "edge": "fall", "offroad": "void",
		"pts": [[0,40,0],[0,42,80],[20,46,140],[75,50,160],[120,50,130],[110,48,80],[140,46,40],[190,46,50],[215,50,100],[260,54,140],
			[315,54,125],[330,50,70],[300,46,25],[320,44,-30],[280,42,-80],[215,40,-85],[160,42,-55],[105,40,-85],[45,40,-80],[8,40,-45]],
		"ramps": [[100, 7.5], [800, 8.0], [1050, 7.0]],
		"gaps": [[106, 117], [806, 818], [1056, 1066]],
		"dash": [[170, 0], [495, 0], [1110, 0]],
		"cross": [190, 505, 870], "cross_kind": "thunder",
	},
	{"id": "space", "name": "スターダストサーキット", "level": "上級", "stars": 3, "theme": "space",
		"desc": "宇宙にうかぶ光の道・惑星・いん石・連続ジャンプ",
		"width": 15.0, "edge": "fall", "offroad": "void",
		"pts": [[0,60,0],[0,62,90],[25,66,150],[80,70,170],[125,70,135],[110,66,85],[135,62,45],[185,62,40],[215,66,85],[210,70,135],
			[245,74,175],[305,74,180],[345,70,140],[330,66,90],[365,62,45],[360,60,-20],[320,58,-70],[255,58,-60],[215,60,-100],
			[150,60,-110],[90,60,-85],[40,60,-90],[8,60,-50]],
		"ramps": [[110, 8.0], [880, 8.5], [1170, 7.0]],
		"gaps": [[116, 129], [886, 900], [1176, 1187]],
		"dash": [[460, 0], [615, -3], [615, 3], [960, 0], [1100, 0], [1300, 0]],
		"cross": [465, 845, 990, 1125], "cross_kind": "meteor",
	},
]

# ---------------------------------------------------------------- カップ
const CUPS := [
	{"id": "green", "name": "グリーンカップ", "level": "初心者向け", "color": Color(0.25, 0.72, 0.3),
		"courses": ["grass", "fruit", "beach", "rainbow"]},
	{"id": "adventure", "name": "アドベンチャーカップ", "level": "中級", "color": Color(0.9, 0.45, 0.12),
		"courses": ["volcano", "jungle", "desert", "cave"]},
	{"id": "stardust", "name": "スターダストカップ", "level": "上級", "color": Color(0.35, 0.3, 0.85),
		"courses": ["snow", "night", "cloud", "space"]},
]

# ---------------------------------------------------------------- 難易度
# cpu_speed: CPUの速さ  rubber_*: 追いつき/手加減の強さ  item_wait: アイテムを使うまでの秒数
# mistake: CPUがミスする頻度  gimmick: コースの障害物の数・速さ  rails: 落下ゾーンに柵をつける
const DIFFICULTIES := [
	{"id": "easy", "name": "やさしい", "color": Color(0.3, 0.78, 0.35), "cpu_speed": 0.88, "rubber_up": 0.05, "rubber_down": 0.10,
		"item_wait": [2.5, 6.0], "mistake": 0.35, "gimmick": 0.7, "rails": true, "coin_mult": 1.0,
		"desc": "CPUがゆっくり。落ちる場所に柵がつく"},
	{"id": "normal", "name": "ふつう", "color": Color(1.0, 0.75, 0.1), "cpu_speed": 0.97, "rubber_up": 0.09, "rubber_down": 0.07,
		"item_wait": [0.8, 3.0], "mistake": 0.12, "gimmick": 1.0, "rails": false, "coin_mult": 1.5,
		"desc": "ちょうどいい手ごたえ"},
	{"id": "hard", "name": "むずかしい", "color": Color(0.95, 0.25, 0.25), "cpu_speed": 1.02, "rubber_up": 0.12, "rubber_down": 0.04,
		"item_wait": [0.3, 1.5], "mistake": 0.0, "gimmick": 1.35, "rails": false, "coin_mult": 2.0,
		"desc": "CPUが速くアイテムをどんどん使う。障害物も多い"},
]

# ---------------------------------------------------------------- 選択状態
var mode := "single"          # grandprix / single / timeattack / lan
var difficulty := 1
var character_index := 0
var kart_index := 1
var course_index := 0
var last_result: Array = []   # [{name, time, player, ci, ki, key}]
var last_course_best := false
var last_laps: Array = []     # タイムアタックのラップタイム
var test_auto := false        # 自動テスト用（プレイヤーもCPUが運転）

# ---------------------------------------------------------------- 設定・セーブ
var settings := {"bgm": 0.7, "se": 0.9, "auto_accel": false, "cam_shake": true, "player_name": "プレイヤー"}
var handicap := {"assist": false, "fast": false}   # ハンデ（自動ハンドル補助・少し速いカート）
var best_times := {}   # course_id -> 秒（1レース）
var ta_best := {}      # course_id -> 秒（タイムアタック）
var coins := 0
var trophies := {}     # cup_id -> [やさしい, ふつう, むずかしい] の最高順位（0=なし, 1〜3）
var golden_unlocked := false


func _ready() -> void:
	_setup_input()
	load_data()


func _setup_input() -> void:
	var map := {
		"accel": [KEY_UP, KEY_W],
		"brake": [KEY_DOWN, KEY_S],
		"left": [KEY_LEFT, KEY_A],
		"right": [KEY_RIGHT, KEY_D],
		"drift": [KEY_SPACE, KEY_SHIFT],
		"item": [KEY_E, KEY_X, KEY_CTRL],
		"pause": [KEY_ESCAPE, KEY_P],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func character() -> Dictionary:
	return CHARACTERS[character_index]


func kart() -> Dictionary:
	return KARTS[kart_index]


func course() -> Dictionary:
	return COURSES[course_index]


func diff() -> Dictionary:
	return DIFFICULTIES[difficulty]


func course_index_of(id: String) -> int:
	for i in COURSES.size():
		if COURSES[i].id == id:
			return i
	return 0


func is_kart_unlocked(i: int) -> bool:
	if KARTS[i].get("locked", false):
		return golden_unlocked
	return true


func trophy(cup_id: String, diff_i: int) -> int:
	var t: Array = trophies.get(cup_id, [0, 0, 0])
	return t[diff_i]


## すべてのカップで優勝しているか（難易度は問わない）
func all_cups_won() -> bool:
	for c in CUPS:
		var t: Array = trophies.get(c.id, [0, 0, 0])
		if not 1 in t:
			return false
	return true


## カートとキャラの補正から実際の走行性能を計算する
func compute_stats(char_idx: int, kart_idx: int) -> Dictionary:
	var c: Dictionary = CHARACTERS[char_idx]
	var k: Dictionary = KARTS[kart_idx]
	var sp: float = k.speed + c.speed * 0.5
	var ac: float = k.accel + c.accel * 0.5
	var hd: float = k.handling + c.handling * 0.5
	return {
		"max_speed": 29.0 + sp * 1.6,     # m/s
		"accel": 7.0 + ac * 2.6,          # m/s^2
		"turn": 1.25 + hd * 0.17,         # rad/s
	}


func goto_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func save_data() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	for k in best_times:
		cfg.set_value("best", k, best_times[k])
	for k in ta_best:
		cfg.set_value("ta_best", k, ta_best[k])
	for k in trophies:
		cfg.set_value("trophies", k, trophies[k])
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("handicap", "assist", handicap.assist)
	cfg.set_value("handicap", "fast", handicap.fast)
	cfg.set_value("progress", "golden", golden_unlocked)
	cfg.set_value("select", "character", character_index)
	cfg.set_value("select", "kart", kart_index)
	cfg.set_value("select", "course", course_index)
	cfg.set_value("select", "difficulty", difficulty)
	cfg.save(SAVE_PATH)


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for k in settings:
		settings[k] = cfg.get_value("settings", k, settings[k])
	for sec in ["best", "ta_best", "trophies"]:
		if cfg.has_section(sec):
			var target: Dictionary = {"best": best_times, "ta_best": ta_best, "trophies": trophies}[sec]
			for k in cfg.get_section_keys(sec):
				target[k] = cfg.get_value(sec, k)
	coins = cfg.get_value("progress", "coins", 0)
	handicap.assist = cfg.get_value("handicap", "assist", false)
	handicap.fast = cfg.get_value("handicap", "fast", false)
	golden_unlocked = cfg.get_value("progress", "golden", false)
	character_index = clampi(cfg.get_value("select", "character", 0), 0, CHARACTERS.size() - 1)
	kart_index = clampi(cfg.get_value("select", "kart", 1), 0, KARTS.size() - 1)
	if not is_kart_unlocked(kart_index):
		kart_index = 1
	course_index = clampi(cfg.get_value("select", "course", 0), 0, COURSES.size() - 1)
	difficulty = clampi(cfg.get_value("select", "difficulty", 1), 0, DIFFICULTIES.size() - 1)


static func format_time(t: float) -> String:
	if t < 0.0 or t == INF:
		return "--:--.--"
	var m := int(t / 60.0)
	var s := fmod(t, 60.0)
	return "%d:%05.2f" % [m, s]
