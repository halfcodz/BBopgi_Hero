class_name Gacha
extends RefCounted
## 인형뽑기 확률 추첨 (기획서 5장).
## 결과는 [내리기] 순간 이 확률표로 결정되고, 집게 위치는 확률에 개입하지 않는다.

const PULL_COST := 1


static func machine_level() -> int:
	return Balance.machine_level(Game.total_pulls)


static func current_rates() -> Array:
	return Balance.machine_rates(machine_level())


static func pulls_to_next_level() -> int:
	var lv := machine_level()
	if lv >= Balance.MACHINE_LEVEL_PULLS.size():
		return -1
	return Balance.MACHINE_LEVEL_PULLS[lv] - Game.total_pulls


## SSR 이상 확률(%) — 소프트 천장 반영
static func ssr_plus_rate() -> float:
	var rates := current_rates()
	var base: float = rates[3] + rates[4]
	var n := Game.pity_ssr + 1
	if n >= Balance.SOFT_PITY_SSR:
		base += (n - Balance.SOFT_PITY_SSR + 1) * Balance.SOFT_PITY_STEP
	return minf(base, 100.0)


static func roll_rarity(rng: RandomNumberGenerator) -> int:
	var rates := current_rates()
	var ssr_plus := ssr_plus_rate()
	var base_ssr_plus: float = rates[3] + rates[4]
	var x := rng.randf() * 100.0
	var rarity := 0
	if Game.pity_ssr + 1 >= Balance.HARD_PITY_SSR or x < ssr_plus:
		# SSR 이상 확정 구간: SSR:UR 비율은 기본표를 따른다
		rarity = Balance.RARITY_UR if rng.randf() * base_ssr_plus < rates[4] else Balance.RARITY_SSR
	else:
		# SSR 미만 구간을 기본 비율로 다시 나눈다
		var rest: float = rates[0] + rates[1] + rates[2]
		var y := rng.randf() * rest
		if y < rates[0]:
			rarity = Balance.RARITY_N
		elif y < rates[0] + rates[1]:
			rarity = Balance.RARITY_R
		else:
			rarity = Balance.RARITY_SR
		if rarity < Balance.RARITY_SR and Game.pity_sr + 1 >= Balance.PITY_SR:
			rarity = Balance.RARITY_SR
	Game.pity_sr = 0 if rarity >= Balance.RARITY_SR else Game.pity_sr + 1
	Game.pity_ssr = 0 if rarity >= Balance.RARITY_SSR else Game.pity_ssr + 1
	return rarity


## 뽑기 n회 실행. 코인은 호출 전에 차감되어 있어야 한다.
## 반환: [{id, rarity, new, perfect}]
static func pull(n: int, perfect := false) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var results := []
	var level_before := machine_level()
	for i in n:
		var rarity := roll_rarity(rng)
		var pool := DragonDB.ids_of_rarity(rarity)
		var id: String = pool[rng.randi() % pool.size()]
		var extra := 1 if perfect and n == 1 else 0
		var r := Game.grant_dragon(id, extra)
		Game.total_pulls += 1
		Game.mileage += 1
		results.append({"id": id, "rarity": rarity, "new": r.new, "perfect": extra > 0})
	Game.add_mission_progress("pulls", n)
	if machine_level() > level_before:
		Game.toast.emit("뽑기 기계 Lv.%d! 상위 등급 확률 UP" % machine_level(), Color("#ff9be0"))
	Game.currency_changed.emit()
	return results


static func can_exchange_mileage() -> bool:
	return Game.mileage >= Balance.MILEAGE_UR


static func exchange_mileage(id: String) -> bool:
	if not can_exchange_mileage():
		return false
	Game.mileage -= Balance.MILEAGE_UR
	Game.grant_dragon(id)
	Game.currency_changed.emit()
	return true


## 확률 공시 문구
static func rates_text() -> String:
	var lines := ["[뽑기 기계 Lv.%d 확률]" % machine_level()]
	var rates := current_rates()
	for i in 5:
		var ids := DragonDB.ids_of_rarity(i)
		lines.append("%s %s: %.1f%% (드래곤 %d종, 각 %.2f%%)" % [
			Balance.RARITY_CODES[i], Balance.RARITY_NAMES[i], rates[i], ids.size(),
			rates[i] / ids.size()])
	lines.append("")
	lines.append("· %d회째 뽑기는 영웅(SR) 이상 확정" % Balance.PITY_SR)
	lines.append("· %d회째부터 전설 이상 확률이 회당 +%.1f%%p" % [Balance.SOFT_PITY_SSR, Balance.SOFT_PITY_STEP])
	lines.append("· %d회째 뽑기는 전설(SSR) 이상 확정" % Balance.HARD_PITY_SSR)
	lines.append("· 마일리지 %d로 신화 드래곤 1종 선택 교환" % Balance.MILEAGE_UR)
	lines.append("· 집게 조작은 확률에 영향을 주지 않습니다 (퍼펙트 시 조각 +1)")
	lines.append("")
	lines.append("기계 레벨별 확률 (N / R / SR / SSR / UR)")
	for lv in Balance.MACHINE_RATES.size():
		var r: Array = Balance.MACHINE_RATES[lv]
		lines.append("Lv.%d (누적 %d회): %.1f / %.1f / %.1f / %.1f / %.1f" % [
			lv + 1, Balance.MACHINE_LEVEL_PULLS[lv], r[0], r[1], r[2], r[3], r[4]])
	return "\n".join(lines)
