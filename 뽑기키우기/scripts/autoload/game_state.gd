extends Node
## 저장 데이터, 재화, 드래곤 보유 현황, 세이브/로드, 오프라인 보상, 일일 미션.
## 오토로드 이름: Game

signal currency_changed
signal dragons_changed
signal party_changed
signal stage_changed
signal missions_changed
signal toast(text: String, color: Color)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const AUTOSAVE_SEC := 30.0
const DAILY_RESET_HOUR := 5

const MISSIONS := [
	{"key": "kills", "name": "적 처치", "goal": 300, "reward": 10},
	{"key": "pulls", "name": "인형뽑기", "goal": 10, "reward": 10},
	{"key": "levelups", "name": "드래곤 레벨업", "goal": 20, "reward": 5},
	{"key": "bosses", "name": "보스 처치", "goal": 5, "reward": 10},
]

# ── 저장 대상 ───────────────────────────────────────
var gold := 0.0
var coins := 0
var scales := 0
var mileage := 0
var stage := 0                 # 현재 스테이지 (누적 번호, 0 = 1-1)
var max_stage := 0             # 이번 환생 회차의 최고 도달
var best_stage := 0            # 계정 전체 최고 도달 (첫 클리어 보상 판정)
var dragons := {}              # id -> {level, star, shards}
var party: Array = ["", "", "", "", ""]
var total_pulls := 0
var pity_sr := 0
var pity_ssr := 0
var prestige_count := 0
var total_kills := 0
var gold_rate := 0.0           # 최근 측정한 초당 골드 (오프라인 보상용)
var mission_day := ""
var mission_progress := {}
var mission_claimed := []
var last_save_unix := 0

# ── 런타임 ─────────────────────────────────────────
var offline_report := {}       # 접속 시 보여 줄 오프라인 보상
var _autosave_timer := 0.0
var _gold_window := []         # [[time, amount]] 최근 60초


func _ready() -> void:
	if not load_game():
		new_game()
	_check_daily_reset()


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_SEC:
		_autosave_timer = 0.0
		_check_daily_reset()
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()


func new_game() -> void:
	gold = 0.0
	coins = Balance.START_COINS
	dragons = {}
	_add_new_dragon(DragonDB.STARTER_ID)
	party = [DragonDB.STARTER_ID, "", "", "", ""]
	last_save_unix = int(Time.get_unix_time_from_system())


# ── 재화 ────────────────────────────────────────────
func add_gold(amount: float, track_rate := true) -> void:
	gold += amount
	if track_rate:
		var now := Time.get_ticks_msec() / 1000.0
		_gold_window.append([now, amount])
		while _gold_window.size() > 0 and now - _gold_window[0][0] > 60.0:
			_gold_window.pop_front()
		var sum := 0.0
		for e in _gold_window:
			sum += e[1]
		var span := maxf(10.0, now - _gold_window[0][0])
		gold_rate = sum / span
	currency_changed.emit()


func spend_gold(amount: float) -> bool:
	if gold + 0.0001 < amount:
		return false
	gold -= amount
	currency_changed.emit()
	return true


func add_coins(amount: int) -> void:
	coins += amount
	currency_changed.emit()


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	currency_changed.emit()
	return true


# ── 드래곤 ──────────────────────────────────────────
func has_dragon(id: String) -> bool:
	return dragons.has(id)


func _add_new_dragon(id: String) -> void:
	dragons[id] = {"level": 1, "star": 1, "shards": 0}


## 뽑기 결과 반영. 반환: {"new": bool}
func grant_dragon(id: String, extra_shards := 0) -> Dictionary:
	var result := {"new": false}
	if dragons.has(id):
		dragons[id].shards += 1 + extra_shards
	else:
		_add_new_dragon(id)
		dragons[id].shards += extra_shards
		result.new = true
		_auto_fill_empty_slot(id)
	dragons_changed.emit()
	return result


func dragon_level(id: String) -> int:
	return dragons[id].level if dragons.has(id) else 1


func dragon_star(id: String) -> int:
	return dragons[id].star if dragons.has(id) else 1


func dragon_atk(id: String) -> float:
	var d := DragonDB.get_dragon(id)
	if d.is_empty() or not dragons.has(id):
		return 0.0
	return Balance.BASE_ATK[d.rarity] * Balance.level_mult(dragons[id].level) \
		* Balance.star_mult(dragons[id].star) * Balance.scale_mult(scales)


func dragon_hp(id: String) -> float:
	var d := DragonDB.get_dragon(id)
	if d.is_empty() or not dragons.has(id):
		return 0.0
	return Balance.BASE_HP[d.rarity] * Balance.level_mult(dragons[id].level) \
		* Balance.star_mult(dragons[id].star)


func dragon_power(id: String) -> float:
	return dragon_atk(id) * 10.0 + dragon_hp(id)


func level_up_cost(id: String) -> float:
	return Balance.level_cost(dragon_level(id))


func level_up(id: String) -> bool:
	if not dragons.has(id):
		return false
	if not spend_gold(level_up_cost(id)):
		return false
	dragons[id].level += 1
	add_mission_progress("levelups", 1)
	dragons_changed.emit()
	return true


func can_star_up(id: String) -> bool:
	if not dragons.has(id):
		return false
	var cost := Balance.star_cost(dragons[id].star)
	return cost > 0 and dragons[id].shards >= cost


func star_up(id: String) -> bool:
	if not can_star_up(id):
		return false
	dragons[id].shards -= Balance.star_cost(dragons[id].star)
	dragons[id].star += 1
	dragons_changed.emit()
	return true


# ── 파티 ────────────────────────────────────────────
func party_slots() -> int:
	return Balance.party_slots(best_stage)


func active_party() -> Array:
	var out := []
	for i in party_slots():
		if party[i] != "" and dragons.has(party[i]):
			out.append(party[i])
	return out


func party_atk_sum() -> float:
	var sum := 0.0
	for id in active_party():
		sum += dragon_atk(id)
	return sum


func party_max_hp() -> float:
	var sum := 0.0
	for id in active_party():
		sum += dragon_hp(id)
	return maxf(sum, 1.0)


func is_in_party(id: String) -> bool:
	return party.slice(0, party_slots()).has(id)


func toggle_party(id: String) -> void:
	var idx := party.find(id)
	if idx >= 0:
		if active_party().size() <= 1:
			toast.emit("파티에 최소 1마리는 있어야 해요", Color.ORANGE)
			return
		party[idx] = ""
	else:
		var empty := -1
		for i in party_slots():
			if party[i] == "":
				empty = i
				break
		if empty < 0:
			toast.emit("빈 슬롯이 없어요. 먼저 한 마리를 빼 주세요", Color.ORANGE)
			return
		party[empty] = id
	party_changed.emit()


func auto_party() -> void:
	var ids := dragons.keys()
	ids.sort_custom(func(a, b): return dragon_power(a) > dragon_power(b))
	party = ["", "", "", "", ""]
	for i in mini(party_slots(), ids.size()):
		party[i] = ids[i]
	party_changed.emit()


func _auto_fill_empty_slot(id: String) -> void:
	for i in party_slots():
		if party[i] == "":
			party[i] = id
			party_changed.emit()
			return


# ── 스테이지 ────────────────────────────────────────
func on_stage_cleared() -> void:
	var reward := Balance.COIN_STAGE_CLEAR
	var first := stage >= best_stage
	if first:
		reward += Balance.COIN_FIRST_CLEAR
		if Balance.is_chapter_boss(stage):
			reward += Balance.COIN_CHAPTER_FIRST
	var slots_before := party_slots()
	stage += 1
	max_stage = maxi(max_stage, stage)
	best_stage = maxi(best_stage, stage)
	add_coins(reward)
	if first:
		toast.emit("첫 클리어! 코인 +%d" % reward, Color("#ffd35c"))
	if party_slots() > slots_before:
		toast.emit("파티 슬롯 %d칸 해금!" % party_slots(), Color("#7ef0c0"))
		party_changed.emit()
	stage_changed.emit()


func on_kill(count := 1) -> void:
	total_kills += count
	add_mission_progress("kills", count)


# ── 환생 ────────────────────────────────────────────
func prestige_gain() -> int:
	return Balance.scales_for(max_stage)


func can_prestige() -> bool:
	return max_stage >= Balance.PRESTIGE_UNLOCK_STAGE and prestige_gain() > 0


func do_prestige() -> int:
	if not can_prestige():
		return 0
	var gain := prestige_gain()
	scales += gain
	prestige_count += 1
	stage = 0
	max_stage = 0
	gold = 0.0
	for id in dragons:
		dragons[id].level = 1
	currency_changed.emit()
	dragons_changed.emit()
	stage_changed.emit()
	save_game()
	return gain


# ── 일일 미션 ───────────────────────────────────────
func _today_key() -> String:
	var t: float = Time.get_unix_time_from_system() - DAILY_RESET_HOUR * 3600 \
		+ Time.get_time_zone_from_system().bias * 60
	var d := Time.get_date_dict_from_unix_time(int(t))
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


func _check_daily_reset() -> void:
	var key := _today_key()
	if key != mission_day:
		mission_day = key
		mission_progress = {}
		mission_claimed = []
		missions_changed.emit()


func add_mission_progress(key: String, amount: int) -> void:
	mission_progress[key] = int(mission_progress.get(key, 0)) + amount
	missions_changed.emit()


func mission_value(key: String) -> int:
	return int(mission_progress.get(key, 0))


func can_claim_mission(m: Dictionary) -> bool:
	return not mission_claimed.has(m.key) and mission_value(m.key) >= m.goal


func claim_mission(m: Dictionary) -> bool:
	if not can_claim_mission(m):
		return false
	mission_claimed.append(m.key)
	add_coins(m.reward)
	missions_changed.emit()
	return true


func any_mission_claimable() -> bool:
	for m in MISSIONS:
		if can_claim_mission(m):
			return true
	return false


# ── 세이브 / 로드 ───────────────────────────────────
func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"gold": gold, "coins": coins, "scales": scales, "mileage": mileage,
		"stage": stage, "max_stage": max_stage, "best_stage": best_stage,
		"dragons": dragons, "party": party,
		"total_pulls": total_pulls, "pity_sr": pity_sr, "pity_ssr": pity_ssr,
		"prestige_count": prestige_count, "total_kills": total_kills,
		"gold_rate": gold_rate,
		"mission_day": mission_day, "mission_progress": mission_progress,
		"mission_claimed": mission_claimed,
		"last_save_unix": int(Time.get_unix_time_from_system()),
	}


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("세이브 실패: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(to_dict()))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("세이브 파일을 읽을 수 없어 새로 시작합니다")
		return false
	gold = float(data.get("gold", 0.0))
	coins = int(data.get("coins", 0))
	scales = int(data.get("scales", 0))
	mileage = int(data.get("mileage", 0))
	stage = int(data.get("stage", 0))
	max_stage = int(data.get("max_stage", 0))
	best_stage = int(data.get("best_stage", 0))
	dragons = {}
	var raw: Dictionary = data.get("dragons", {})
	for id in raw:
		if DragonDB.get_dragon(id).is_empty():
			continue
		dragons[id] = {
			"level": int(raw[id].get("level", 1)),
			"star": int(raw[id].get("star", 1)),
			"shards": int(raw[id].get("shards", 0)),
		}
	if dragons.is_empty():
		_add_new_dragon(DragonDB.STARTER_ID)
	party = ["", "", "", "", ""]
	var raw_party: Array = data.get("party", [])
	for i in mini(5, raw_party.size()):
		if dragons.has(str(raw_party[i])):
			party[i] = str(raw_party[i])
	if active_party().is_empty():
		auto_party()
	total_pulls = int(data.get("total_pulls", 0))
	pity_sr = int(data.get("pity_sr", 0))
	pity_ssr = int(data.get("pity_ssr", 0))
	prestige_count = int(data.get("prestige_count", 0))
	total_kills = int(data.get("total_kills", 0))
	gold_rate = float(data.get("gold_rate", 0.0))
	mission_day = str(data.get("mission_day", ""))
	mission_progress = data.get("mission_progress", {})
	mission_claimed = data.get("mission_claimed", [])
	last_save_unix = int(data.get("last_save_unix", 0))
	_apply_offline()
	return true


func _apply_offline() -> void:
	var now := int(Time.get_unix_time_from_system())
	var elapsed := clampi(now - last_save_unix, 0, Balance.OFFLINE_MAX_SEC)
	if elapsed < 60:
		return
	var rate := gold_rate
	if rate <= 0.0:
		rate = Balance.kill_gold(stage) * 0.5 * Balance.scale_mult(scales)
	var g := rate * elapsed * Balance.OFFLINE_GOLD_RATIO
	var c := elapsed / Balance.OFFLINE_SEC_PER_COIN
	gold += g
	coins += c
	offline_report = {"seconds": elapsed, "gold": g, "coins": c}


func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	scales = 0; mileage = 0; stage = 0; max_stage = 0; best_stage = 0
	total_pulls = 0; pity_sr = 0; pity_ssr = 0; prestige_count = 0; total_kills = 0
	gold_rate = 0.0; mission_progress = {}; mission_claimed = []
	new_game()
	currency_changed.emit(); dragons_changed.emit(); party_changed.emit(); stage_changed.emit()
	missions_changed.emit()
