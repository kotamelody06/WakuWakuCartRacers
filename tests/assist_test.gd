extends Node
## 自動テスト：ハンドル補助ONで、アクセルだけ押して走れるか（開発用）
var race
var f := 0
func _ready() -> void:
	Game.mode = "single"
	Game.course_index = int(OS.get_environment("KART_COURSE")) if OS.get_environment("KART_COURSE") != "" else 0
	Game.handicap = {"assist": true, "fast": OS.get_environment("KART_FAST") != ""}
	race = load("res://scenes/Race.tscn").instantiate()
	add_child(race)
func _physics_process(_dt: float) -> void:
	f += 1
	Input.action_press("accel")
	if f % 600 == 0 or race.player.finished:
		print("ASSIST t=%.1f lap=%d d=%d falls=%d finished=%s rank=%d" % [race.race_time, race.player.lap, int(race.player.d), race.respawn_count, race.player.finished, race.player.rank])
	if race.player.finished or f > 60 * 300:
		get_tree().quit()
