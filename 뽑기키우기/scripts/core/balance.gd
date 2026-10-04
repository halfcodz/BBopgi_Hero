class_name Balance
extends RefCounted
## 모든 수치 공식과 상수를 모아 둔 곳.
## tools/balance_sim.py 와 공식을 맞춰야 한다. (기획서 6.3, 7.2, 8.3 참고)

# ── 등급 ────────────────────────────────────────────
const RARITY_N := 0
const RARITY_R := 1
const RARITY_SR := 2
const RARITY_SSR := 3
const RARITY_UR := 4

const RARITY_NAMES := ["일반", "희귀", "영웅", "전설", "신화"]
const RARITY_CODES := ["N", "R", "SR", "SSR", "UR"]
const RARITY_COLORS := [
	Color("#9aa3ad"), Color("#4fa3ff"), Color("#b36bff"), Color("#ffc23d"), Color("#ff5fa8"),
]
const BASE_ATK := [10.0, 14.0, 21.0, 32.0, 50.0]
const BASE_HP := [60.0, 80.0, 110.0, 150.0, 220.0]

# ── 별(승급) ────────────────────────────────────────
const MAX_STAR := 6
const STAR_MULT := [1.0, 1.5, 2.2, 3.2, 4.6, 6.5]   # 인덱스 = 별 - 1
const STAR_COST := [2, 4, 8, 15, 30]                 # 별 n → n+1 에 필요한 조각

# ── 전투 ────────────────────────────────────────────
const CRIT_CHANCE := 0.10
const CRIT_MULT := 2.0
const ATTACK_INTERVAL := 1.0
const WAVES_PER_STAGE := 5          # 1~4 일반, 5 보스
const ENEMIES_PER_WAVE := 3
const STAGES_PER_CHAPTER := 10
const STAGE_BOSS_HP_MULT := 6.0
const STAGE_BOSS_TIME := 20.0
const CHAPTER_BOSS_HP_MULT := 25.0
const CHAPTER_BOSS_TIME := 30.0
const BOSS_GOLD_MULT := 8.0
const BOSS_ATK_MULT := 3.0
const WAVE_HEAL_RATIO := 0.30
const TAP_DAMAGE_RATIO := 0.05
const FEVER_PER_TAP := 0.04
const FEVER_DURATION := 10.0

# ── 원소 상성 ───────────────────────────────────────
const ADVANTAGE_MULT := 1.3
const DISADVANTAGE_MULT := 0.8

# ── 파티 슬롯 해금 (누적 스테이지 번호 s 기준) ───────
const SLOT_UNLOCK_STAGE := [0, 2, 5, 10, 20]

# ── 코인 ────────────────────────────────────────────
const COIN_STAGE_CLEAR := 1
const COIN_FIRST_CLEAR := 2
const COIN_CHAPTER_FIRST := 20
const START_COINS := 10

# ── 오프라인 ────────────────────────────────────────
const OFFLINE_MAX_SEC := 8 * 3600
const OFFLINE_GOLD_RATIO := 0.6
const OFFLINE_SEC_PER_COIN := 600

# ── 환생(둥지 이사) ─────────────────────────────────
const PRESTIGE_UNLOCK_STAGE := 30
const SCALE_BONUS := 0.05

# ── 뽑기 ────────────────────────────────────────────
const MACHINE_LEVEL_PULLS := [0, 30, 100, 250, 500, 1000, 2000]
const MACHINE_RATES := [
	[60.0, 28.0, 9.0, 2.7, 0.3],
	[57.0, 29.5, 10.0, 3.1, 0.4],
	[54.0, 31.0, 11.0, 3.5, 0.5],
	[50.0, 33.0, 12.2, 4.1, 0.7],
	[46.0, 35.0, 13.5, 4.6, 0.9],
	[42.0, 36.5, 15.0, 5.3, 1.2],
	[38.0, 38.0, 16.5, 6.0, 1.5],
]
const PITY_SR := 10            # 10회째 SR 이상 확정
const SOFT_PITY_SSR := 60      # 60회째부터 SSR 확률 증가
const SOFT_PITY_STEP := 2.5    # 회당 +2.5%p
const HARD_PITY_SSR := 90      # 90회째 SSR 이상 확정
const MILEAGE_UR := 300
const PERFECT_RANGE := 8.0


# ── 공식 ────────────────────────────────────────────
static func enemy_hp(s: int) -> float:
	return 40.0 * pow(1.21, s)

static func enemy_atk(s: int) -> float:
	return 1.5 * pow(1.20, s)

static func kill_gold(s: int) -> float:
	return 5.0 * pow(1.19, s)

static func level_cost(level: int) -> float:
	return 15.0 * pow(1.10, level - 1)

static func level_mult(level: int) -> float:
	return pow(1.07, level - 1)

static func star_mult(star: int) -> float:
	return STAR_MULT[clampi(star, 1, MAX_STAR) - 1]

static func star_cost(star: int) -> int:
	if star >= MAX_STAR:
		return -1
	return STAR_COST[star - 1]

static func scale_mult(scales: int) -> float:
	return 1.0 + SCALE_BONUS * scales

static func scales_for(max_stage: int) -> int:
	if max_stage < PRESTIGE_UNLOCK_STAGE:
		return 0
	return int(pow((max_stage - 20) / 10.0, 1.5) * 2.0)

static func party_slots(max_stage: int) -> int:
	var n := 0
	for need in SLOT_UNLOCK_STAGE:
		if max_stage >= need:
			n += 1
	return n

static func is_chapter_boss(s: int) -> bool:
	return s % STAGES_PER_CHAPTER == STAGES_PER_CHAPTER - 1

static func stage_label(s: int) -> String:
	return "%d-%d" % [s / STAGES_PER_CHAPTER + 1, s % STAGES_PER_CHAPTER + 1]

static func machine_level(total_pulls: int) -> int:
	var lv := 1
	for i in MACHINE_LEVEL_PULLS.size():
		if total_pulls >= MACHINE_LEVEL_PULLS[i]:
			lv = i + 1
	return lv

static func machine_rates(level: int) -> Array:
	return MACHINE_RATES[clampi(level, 1, MACHINE_RATES.size()) - 1]

## 원소 상성: 0 불, 1 물, 2 풀, 3 빛, 4 어둠
static func element_mult(attacker: int, defender: int) -> float:
	if attacker == 3 and defender == 4 or attacker == 4 and defender == 3:
		return ADVANTAGE_MULT
	var beats := {0: 2, 2: 1, 1: 0}   # 불>풀, 풀>물, 물>불
	if beats.get(attacker, -1) == defender:
		return ADVANTAGE_MULT
	if beats.get(defender, -1) == attacker:
		return DISADVANTAGE_MULT
	return 1.0
