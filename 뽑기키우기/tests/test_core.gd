extends Node
## 헤드리스 코어 로직 테스트: godot --headless --path . res://tests/test_core.tscn

var fails := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		fails += 1
		print("  FAIL ", msg)

func _ready() -> void:
	var game = get_node_or_null("/root/Game")
	check(game != null, "Game 오토로드 존재")
	game.reset_save()
	check(game.coins == Balance.START_COINS, "시작 코인 10")
	check(game.has_dragon(DragonDB.STARTER_ID), "스타터 드래곤 보유")
	check(game.active_party().size() == 1, "파티 1마리")
	# 레벨업
	game.add_gold(1000.0, false)
	var lv0: int = game.dragon_level(DragonDB.STARTER_ID)
	check(game.level_up(DragonDB.STARTER_ID), "레벨업 성공")
	check(game.dragon_level(DragonDB.STARTER_ID) == lv0 + 1, "레벨 +1")
	# 뽑기 + 천장 통계
	game.spend_coins(10)
	var res := Gacha.pull(10)
	check(res.size() == 10, "10연 결과 10개")
	var has_sr := false
	for r in res:
		if r.rarity >= 2: has_sr = true
	check(has_sr, "10연 SR 이상 확정")
	# 대량 시뮬레이션: 천장 위반 없는지
	var counts := [0, 0, 0, 0, 0]
	var since_ssr := 0
	var max_since := 0
	var since_sr := 0
	var max_since_sr := 0
	for i in 20000:
		var r2: Array = Gacha.pull(1)
		var rar: int = r2[0].rarity
		counts[rar] += 1
		since_ssr = 0 if rar >= 3 else since_ssr + 1
		since_sr = 0 if rar >= 2 else since_sr + 1
		max_since = maxi(max_since, since_ssr)
		max_since_sr = maxi(max_since_sr, since_sr)
	print("  분포(20000회, 기계 레벨 상승 포함): ", counts, " 기계Lv ", Gacha.machine_level())
	check(max_since < Balance.HARD_PITY_SSR, "SSR 하드 천장 준수 (최대 무SSR 연속 %d)" % max_since)
	check(max_since_sr < Balance.PITY_SR, "SR 천장 준수 (최대 무SR 연속 %d)" % max_since_sr)
	# 별 승급
	var any_star := false
	for id in game.dragons:
		while game.can_star_up(id):
			game.star_up(id)
			any_star = true
	check(any_star, "별 승급 동작")
	# 스테이지/환생
	game.stage = 39; game.max_stage = 39; game.best_stage = 39
	game.on_stage_cleared()
	check(game.stage == 40 and game.best_stage == 40, "스테이지 클리어 진행")
	check(game.can_prestige(), "환생 가능")
	var gain: int = game.do_prestige()
	check(gain == Balance.scales_for(40) and game.stage == 0, "환생: 비늘 +%d, 스테이지 초기화" % gain)
	check(game.party_slots() == 5, "환생 후에도 슬롯 유지")
	# 세이브/로드
	game.save_game()
	var coins_before: int = game.coins
	game.coins = -1
	check(game.load_game() and game.coins == coins_before, "세이브/로드 왕복")
	# 숫자 포맷
	check(Num.fmt(999) == "999" and Num.fmt(1234) == "1.23K" and Num.fmt(1.5e15) == "1.50aa", "큰 수 표기 %s %s %s" % [Num.fmt(999), Num.fmt(1234), Num.fmt(1.5e15)])
	check(Balance.element_mult(0, 2) == 1.3 and Balance.element_mult(2, 0) == 0.8 and Balance.element_mult(3, 4) == 1.3, "속성 상성")
	game.reset_save()
	print("결과: ", "통과" if fails == 0 else "실패 %d" % fails)
	get_tree().quit(fails)
