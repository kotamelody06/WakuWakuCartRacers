extends Node
## 自動テスト：グランプリを1カップ最後まで自動で走らせる（開発用）
func _ready() -> void:
	Game.test_auto = true
	Game.difficulty = int(OS.get_environment("KART_DIFF")) if OS.get_environment("KART_DIFF") != "" else 1
	Game.character_index = 0
	Game.kart_index = 1
	GrandPrix.start(int(OS.get_environment("KART_CUP")) if OS.get_environment("KART_CUP") != "" else 0)
	GrandPrix.call_deferred("begin_races")
