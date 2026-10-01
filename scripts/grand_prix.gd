extends Node
## GrandPrixManager：カップ・レース番号・ポイント・ライバルを管理する自動読み込みノード。

const POINTS := [10, 8, 6, 5, 4, 3]
const COINS := [300, 200, 100, 30, 30, 30]

var active := false
var cup_index := 0          # CurrentCup
var race_index := 0         # CurrentRace（0〜3）
var rivals: Array = []      # [{key, name, ci, ki}]  4レースを通して同じライバル
var points := {}            # key -> 合計ポイント（player もふくむ）
var history: Array = []     # レースごと [{key, place, pts}]
var prev_points := {}       # 直前のレース前の合計（順位画面のアニメ用）
var last_rewards := {}      # 表彰台で表示する報酬


func cup() -> Dictionary:
	return Game.CUPS[cup_index]


func race_count() -> int:
	return cup().courses.size()


func is_last_race() -> bool:
	return race_index >= race_count() - 1


func start(ci: int) -> void:
	active = true
	cup_index = ci
	race_index = 0
	history.clear()
	points.clear()
	prev_points.clear()
	last_rewards.clear()
	Game.mode = "grandprix"


## キャラクター・カートが決まってから呼ぶ。ライバル5人を決めてレース1へ。
func begin_races() -> void:
	setup_rivals()
	_set_course()
	Game.goto_scene("res://scenes/Race.tscn")


func setup_rivals() -> void:
	rivals.clear()
	var others := []
	for i in Game.CHARACTERS.size():
		if i != Game.character_index:
			others.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = cup_index * 101 + Game.character_index * 7 + Game.difficulty
	var k := 0
	for ci in others:
		rivals.append({"key": "r%d" % k, "name": Game.CHARACTERS[ci].name, "ci": ci, "ki": rng.randi() % Game.STANDARD_KARTS})
		k += 1
	var extra := 0
	while rivals.size() < Game.RACER_COUNT - 1:
		var ci2: int = others[extra % others.size()]
		rivals.append({"key": "r%d" % k, "name": Game.CHARACTERS[ci2].name + "Jr.", "ci": ci2, "ki": rng.randi() % Game.STANDARD_KARTS})
		k += 1
		extra += 1
	points["player"] = 0
	for r in rivals:
		points[r.key] = 0


func _set_course() -> void:
	Game.course_index = Game.course_index_of(cup().courses[race_index])


func name_of(key: String) -> String:
	if key == "player":
		return "あなた"
	for r in rivals:
		if r.key == key:
			return r.name
	return key


func char_of(key: String) -> int:
	if key == "player":
		return Game.character_index
	for r in rivals:
		if r.key == key:
			return r.ci
	return 0


func kart_of(key: String) -> int:
	if key == "player":
		return Game.kart_index
	for r in rivals:
		if r.key == key:
			return r.ki
	return 0


## スタート位置の順番（1レース目はプレイヤーが最後。2レース目からは合計ポイントの少ない順に後ろ）
func grid_keys() -> Array:
	if race_index == 0:
		var keys := []
		for r in rivals:
			keys.append(r.key)
		keys.append("player")
		return keys
	return standings()


## 合計ポイントの順位（同点なら直前のレースの順位）
func standings() -> Array:
	var keys := points.keys()
	var last := {}
	if not history.is_empty():
		for e in history.back():
			last[e.key] = e.place
	keys.sort_custom(func(a, b):
		if points[a] != points[b]:
			return points[a] > points[b]
		return last.get(a, 9) < last.get(b, 9))
	return keys


## レース結果（順番に並んだ [{key,...}]）を記録する
func record_race(res: Array) -> void:
	prev_points = points.duplicate()
	var entry := []
	for i in res.size():
		var key: String = res[i].key
		var pts: int = POINTS[mini(i, POINTS.size() - 1)]
		points[key] = points.get(key, 0) + pts
		entry.append({"key": key, "place": i + 1, "pts": pts, "time": res[i].time})
	history.append(entry)


func next_race() -> void:
	race_index += 1
	_set_course()
	Game.goto_scene("res://scenes/Race.tscn")


func player_place() -> int:
	return standings().find("player") + 1


## カップ終了：コイン・トロフィー・アンロックを反映して保存する
func finish_cup() -> Dictionary:
	var place := player_place()
	var d: Dictionary = Game.diff()
	var coins := int(COINS[place - 1] * float(d.coin_mult))
	Game.coins += coins
	var cid: String = cup().id
	var t: Array = Game.trophies.get(cid, [0, 0, 0]).duplicate()
	var new_trophy := false
	if place <= 3 and (t[Game.difficulty] == 0 or place < t[Game.difficulty]):
		t[Game.difficulty] = place
		new_trophy = true
	Game.trophies[cid] = t
	var unlocked := false
	if not Game.golden_unlocked and Game.all_cups_won():
		Game.golden_unlocked = true
		unlocked = true
	Game.save_data()
	last_rewards = {"place": place, "coins": coins, "trophy": place if place <= 3 else 0, "new_trophy": new_trophy, "unlocked": unlocked}
	return last_rewards


func quit() -> void:
	active = false
	if Game.mode == "grandprix":
		Game.mode = "single"
