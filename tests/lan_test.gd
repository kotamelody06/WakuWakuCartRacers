extends Node
## 自動テスト：親機と子機を別々に起動して、LAN対戦を最後まで走らせる（開発用）
var role := "host"
var t := 0.0
var started := false
var snaps := 0
var printed := false
var back := false
var res_t := 0.0

var persistent := false

func _ready() -> void:
	if not persistent:
		# シーンが変わっても消えないように、ルートに自分のコピーを置く
		var n := Node.new()
		n.set_script(get_script())
		n.set("persistent", true)
		get_tree().root.add_child.call_deferred(n)
		set_process(false)
		return
	role = OS.get_environment("LAN_ROLE")
	Game.test_auto = true
	Game.settings["player_name"] = "おや" if role == "host" else "こ"
	Game.character_index = 0 if role == "host" else randi() % 4
	Game.handicap = {"assist": role != "host", "fast": role != "host"}
	Game.course_index = int(OS.get_environment("LAN_COURSE")) if OS.get_environment("LAN_COURSE") != "" else 0
	call_deferred("_setup")

func _setup() -> void:
	get_tree().change_scene_to_file("res://scenes/LanLobby.tscn")
	await get_tree().create_timer(0.5).timeout
	if role == "host":
		Net.host()
	else:
		Net.join("127.0.0.1")

func _process(delta: float) -> void:
	t += delta
	var scn := get_tree().current_scene
	if int(t * 60) % 120 == 0:
		print(role, " dbg t=%.1f scene=%s active=%s host=%s players=%d status=%s" % [t, scn.name if scn else "-", Net.active, Net.is_host, Net.players.size(), Net.status])
	if role == "host" and not started and Net.players.size() >= (int(OS.get_environment("LAN_N")) if OS.get_environment("LAN_N") != "" else 2) and t > 2.0:
		started = true
		print("HOST start players=", Net.players)
		Net.start_race()
	if scn and scn.name == "Race" and int(t * 10) % 100 == 0:
		var r = scn
		var s := "%s t=%.1f state=%s race=%.1f " % [role, t, r.state, r.race_time]
		for k in r.karts:
			s += "[%s L%d d%d%s%s] " % [k.racer_name, k.lap, int(k.d), " H" if k.is_human else "", " F" if k.finished else ""]
		print(s)
	if scn and scn.name == "Result" and not printed:
		printed = true
		res_t = t
		var s2 := "%s RESULT " % role
		for r in Game.last_result:
			s2 += "%s%s:%s " % [r.name, "*" if r.player else "", Game.format_time(r.time)]
		print(s2)
	if printed and role == "host" and t > res_t + 4.0 and not back:
		back = true
		Net.back_to_lobby()
	if printed and scn and scn.name == "LanLobby":
		print(role, " BACK IN LOBBY players=", Net.players.size())
		if role == "client" or t > res_t + 8.0:
			get_tree().quit()
	if t > 600:
		print(role, " TIMEOUT")
		get_tree().quit()
