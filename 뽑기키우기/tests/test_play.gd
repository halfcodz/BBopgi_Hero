extends Node
## 가속 자동 플레이 테스트 (실제 전투 코드 사용).
## godot --headless --fixed-fps 60 --path . res://tests/test_play.tscn -- minutes=120
## 봇: 1초마다 골드를 가장 싼 레벨업에 쓰고, 코인은 전부 뽑기, 자동 편성·승급, 막히면 둥지 이사.

const TIME_SCALE := 10.0

var main
var game_time := 0.0
var tick := 0.0
var last_progress := 0.0
var last_best := 0
var limit_min := 120.0
var marks := []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("minutes="):
			limit_min = float(a.substr(8))
	Game.reset_save()
	Game.offline_report = {}
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	Engine.time_scale = TIME_SCALE
	print("[자동 플레이] %d분 (게임 시간)" % int(limit_min))


func _process(delta: float) -> void:
	game_time += delta
	tick += delta
	if tick >= 1.0:
		tick = 0.0
		_bot()
	if Game.best_stage > last_best:
		last_best = Game.best_stage
		last_progress = game_time
		if Game.best_stage % 10 == 0:
			var line := "  %6.1f분  %s 첫 도달 · 드래곤 %d종 · 뽑기 %d회 · 비늘 %d" % [game_time / 60.0, Balance.stage_label(Game.best_stage), Game.dragons.size(), Game.total_pulls, Game.scales]
			print(line)
	if game_time >= limit_min * 60.0:
		print("  종료: 현재 %s · 계정 최고 %s · 이사 %d회 · 골드 %s · 처치 %d" % [Balance.stage_label(Game.stage), Balance.stage_label(Game.best_stage), Game.prestige_count, Num.fmt(Game.gold), Game.total_kills])
		Engine.time_scale = 1.0
		Game.reset_save()
		get_tree().quit()


var _run_best := 0
var _run_progress_t := 0.0

func _bot() -> void:
	# 뽑기
	while Game.coins >= 10:
		Game.spend_coins(10)
		Gacha.pull(10)
	while Game.coins >= 1:
		Game.spend_coins(1)
		Gacha.pull(1)
	for id in Game.dragons.keys():
		while Game.can_star_up(id):
			Game.star_up(id)
	Game.auto_party()
	# 레벨업
	var party := Game.active_party()
	while true:
		var best := ""
		var best_cost := INF
		for id in party:
			var c := Game.level_up_cost(id)
			if c < best_cost:
				best_cost = c
				best = id
		if best == "" or not Game.level_up(best):
			break
	for m in Game.MISSIONS:
		Game.claim_mission(m)
	# 환생: 이번 회차 진행이 15분 멈추면
	if Game.max_stage > _run_best:
		_run_best = Game.max_stage
		_run_progress_t = game_time
	if game_time - _run_progress_t > 15 * 60 and Game.can_prestige() and Game.prestige_gain() >= maxi(2, Game.scales / 2):
		var s := Game.max_stage
		var g := Game.do_prestige()
		print("  %6.1f분  둥지 이사 (최고 %s, 비늘 +%d → %d)" % [game_time / 60.0, Balance.stage_label(s), g, Game.scales])
		_run_best = 0
		_run_progress_t = game_time
