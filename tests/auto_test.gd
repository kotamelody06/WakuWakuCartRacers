extends Node
## 自動テスト：全員CPUでレースを走らせ、周回・順位・スタックを記録する（開発用）
var race
var frames := 0
var course := 0
var log_t := 0.0

func _ready() -> void:
	course = int(OS.get_environment("KART_COURSE")) if OS.get_environment("KART_COURSE") != "" else 0
	Game.course_index = course
	Game.character_index = int(OS.get_environment("KART_CHAR")) if OS.get_environment("KART_CHAR") != "" else 0
	Game.difficulty = int(OS.get_environment("KART_DIFF")) if OS.get_environment("KART_DIFF") != "" else 1
	Game.mode = OS.get_environment("KART_MODE") if OS.get_environment("KART_MODE") != "" else "single"
	var scn: PackedScene = load("res://scenes/Race.tscn")
	race = scn.instantiate()
	race.auto_play = true
	add_child(race)

func _physics_process(dt: float) -> void:
	frames += 1
	log_t += dt
	if log_t >= 10.0:
		log_t = 0.0
		var s := "t=%5.1f state=%s " % [race.race_time, race.state]
		for k in race.karts:
			s += "[%s L%d d%4d r%d sp%2d%s%s] " % [k.racer_name.substr(0,3), k.lap, int(k.d), k.rank, int(k.speed), " F" if k.finished else "", " P" if k.is_player else ""]
		print(s)
	if race.state == "finish" or frames > 60 * 420:
		var s2 := "END course=%d time=%.1f " % [course, race.race_time]
		for k in race.karts:
			s2 += "%s:%s " % [k.racer_name, Game.format_time(k.finish_time)]
		print(s2)
		print("respawn/fall stats: ", race.respawn_count, " laps=", race.lap_times, " item=", race.player.item, race.player.item_count, " karts=", race.karts.size())
		get_tree().quit()
