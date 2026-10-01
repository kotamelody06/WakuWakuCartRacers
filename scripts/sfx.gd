extends Node
## 効果音とBGMの再生を担当する自動読み込みノード。
## 音源はすべてこのゲーム用に合成したオリジナル音源（audio/*.wav）。

const SOUNDS := ["beep", "go", "click", "item_get", "roulette", "goal", "boost", "crash", "land", "spin", "throw", "shield", "drumroll", "champion", "coin"]

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _bgm: AudioStreamPlayer
var _bgm_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for s in SOUNDS:
		_streams[s] = load("res://audio/%s.wav" % s)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_bgm = AudioStreamPlayer.new()
	add_child(_bgm)


## ループ用のWAVを読み込む（ループ設定を付ける）
static func load_loop(name: String) -> AudioStream:
	var s = load("res://audio/%s.wav" % name)
	if s is AudioStreamWAV:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	return s


func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not _streams.has(name):
		return
	var se: float = Game.settings.se
	if se <= 0.01:
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[name]
			p.pitch_scale = pitch
			p.volume_db = vol_db + linear_to_db(se)
			p.play()
			return


func play_bgm(name: String) -> void:
	if _bgm_name == name and _bgm.playing:
		return
	_bgm_name = name
	_bgm.stream = load_loop(name)
	update_volume()
	_bgm.play()


func stop_bgm() -> void:
	_bgm_name = ""
	_bgm.stop()


func update_volume() -> void:
	var v: float = Game.settings.bgm
	_bgm.volume_db = linear_to_db(max(v, 0.0001)) - 6.0
