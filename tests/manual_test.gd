extends Node
## 開発用：プレイヤー入力（アクション）経由で操作できるか確認する
var race
var f := 0
var max_speed := 0.0
var drift_levels := {}
var used_item := false
func _ready() -> void:
	Game.course_index = 0
	Game.kart_index = 0
	race = load("res://scenes/Race.tscn").instantiate()
	add_child(race)
func _physics_process(_dt: float) -> void:
	f += 1
	var p = race.player
	Input.action_press("accel")
	# 簡単な自動ハンドル（コースの先を向く）
	var tgt = race.track.point_at(p.d + 18.0, 0.0)
	var want = atan2(-(tgt.x - p.position.x), -(tgt.z - p.position.z))
	var diff = wrapf(want - p.yaw, -PI, PI)
	Input.action_release("left"); Input.action_release("right")
	if diff > 0.05: Input.action_press("left")
	elif diff < -0.05: Input.action_press("right")
	# ドリフト：900〜1080フレーム
	if f > 900 and f < 1080: Input.action_press("drift")
	else: Input.action_release("drift")
	if p.item != "" and f % 30 == 0:
		Input.action_press("item"); used_item = true
	else:
		Input.action_release("item")
	max_speed = max(max_speed, p.speed)
	drift_levels[p.drift_level] = true
	if f == 1500:
		print("MANUAL: lap=%d d=%d max_speed=%.1f drift_levels=%s used_item=%s rank=%d boost=%.2f" % [p.lap, int(p.d), max_speed, drift_levels.keys(), used_item, p.rank, p.boost_time])
		get_tree().quit()
