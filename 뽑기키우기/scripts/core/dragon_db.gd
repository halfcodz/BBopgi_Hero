class_name DragonDB
extends RefCounted
## 드래곤·적·챕터 정적 데이터 (기획서 6.2, 7.3)

const ELEMENT_NAMES := ["불", "물", "풀", "빛", "어둠"]
const ELEMENT_COLORS := [
	Color("#ff7a59"), Color("#5ab8ff"), Color("#7ed37a"), Color("#ffe066"), Color("#8e7cc3"),
]
const ELEMENT_ICONS := ["🔥", "💧", "🌿", "✨", "🌙"]

## 스킬 type
## single: 단일 대상 power배 / aoe: 전체 power배 / heal: 파티 최대체력 power 비율 회복
## buff_atk: dur초 동안 공격력 +power / buff_gold: dur초 동안 골드 +power
const DRAGONS := [
	{"id": "bulssi", "name": "불씨", "rarity": 0, "element": 0},
	{"id": "mulbang", "name": "물방울", "rarity": 0, "element": 1},
	{"id": "saessak", "name": "새싹", "rarity": 0, "element": 2},
	{"id": "banjjak", "name": "반짝이", "rarity": 0, "element": 3},
	{"id": "geurimja", "name": "그림자콩", "rarity": 0, "element": 4},
	{"id": "modak", "name": "모닥불", "rarity": 1, "element": 0,
		"skill": {"name": "불꽃 콧김", "type": "single", "cd": 8.0, "power": 3.0}},
	{"id": "padoring", "name": "파도링", "rarity": 1, "element": 1,
		"skill": {"name": "물총", "type": "single", "cd": 8.0, "power": 3.0}},
	{"id": "dotori", "name": "도토리", "rarity": 1, "element": 2,
		"skill": {"name": "도토리 던지기", "type": "single", "cd": 8.0, "power": 3.0}},
	{"id": "haetsal", "name": "햇살콩", "rarity": 1, "element": 3,
		"skill": {"name": "반짝 응원", "type": "buff_atk", "cd": 12.0, "power": 0.15, "dur": 5.0}},
	{"id": "bamtol", "name": "밤톨", "rarity": 1, "element": 4,
		"skill": {"name": "밤송이 굴리기", "type": "aoe", "cd": 10.0, "power": 1.5}},
	{"id": "hwasan", "name": "화산이", "rarity": 2, "element": 0,
		"skill": {"name": "화산 분출", "type": "aoe", "cd": 10.0, "power": 2.5}},
	{"id": "sanho", "name": "산호", "rarity": 2, "element": 1,
		"skill": {"name": "산호 방패", "type": "heal", "cd": 12.0, "power": 0.15}},
	{"id": "danpung", "name": "단풍이", "rarity": 2, "element": 2,
		"skill": {"name": "낙엽 폭풍", "type": "aoe", "cd": 10.0, "power": 2.5}},
	{"id": "byeolsatang", "name": "별사탕", "rarity": 2, "element": 3,
		"skill": {"name": "별사탕 비", "type": "buff_gold", "cd": 15.0, "power": 0.5, "dur": 8.0}},
	{"id": "ignis", "name": "이그니스", "rarity": 3, "element": 0,
		"skill": {"name": "용염 브레스", "type": "aoe", "cd": 9.0, "power": 4.0}},
	{"id": "marin", "name": "마린", "rarity": 3, "element": 1,
		"skill": {"name": "해일", "type": "aoe", "cd": 9.0, "power": 3.5, "stun": 1.5}},
	{"id": "silva", "name": "실바", "rarity": 3, "element": 2,
		"skill": {"name": "세계수의 축복", "type": "buff_atk", "cd": 12.0, "power": 0.4, "dur": 6.0}},
	{"id": "luna", "name": "루나", "rarity": 3, "element": 4,
		"skill": {"name": "월식", "type": "single", "cd": 10.0, "power": 12.0}},
	{"id": "solaris", "name": "솔라리스", "rarity": 4, "element": 3,
		"skill": {"name": "태양 강림", "type": "aoe", "cd": 8.0, "power": 7.0, "gold": 1.0, "dur": 5.0}},
	{"id": "nox", "name": "녹스", "rarity": 4, "element": 4,
		"skill": {"name": "영원한 밤", "type": "single", "cd": 8.0, "power": 25.0}},
]

const STARTER_ID := "modak"

const CHAPTERS := [
	{"name": "말랑 버섯숲", "bg_top": Color("#c9f2c7"), "bg_bottom": Color("#8fd18b"),
		"enemies": [{"name": "슬라임", "color": Color("#7fd6a8"), "element": 2},
			{"name": "버섯돌이", "color": Color("#e8836b"), "element": 2}]},
	{"name": "사탕 해변", "bg_top": Color("#d4fbf3"), "bg_bottom": Color("#f7e3b5"),
		"enemies": [{"name": "젤리게", "color": Color("#8fd3ff"), "element": 1},
			{"name": "솜사탕", "color": Color("#ffb3d9"), "element": 1}]},
	{"name": "구름 산맥", "bg_top": Color("#dcecff"), "bg_bottom": Color("#a9c8ef"),
		"enemies": [{"name": "구름양", "color": Color("#f4f6fb"), "element": 3},
			{"name": "번개새", "color": Color("#ffe27a"), "element": 3}]},
	{"name": "용암 동굴", "bg_top": Color("#ffcf9e"), "bg_bottom": Color("#b8573b"),
		"enemies": [{"name": "마그마볼", "color": Color("#ff6a3d"), "element": 0},
			{"name": "동굴박쥐", "color": Color("#7c5a8c"), "element": 4}]},
	{"name": "얼음 성", "bg_top": Color("#eaf8ff"), "bg_bottom": Color("#9fd6ee"),
		"enemies": [{"name": "눈덩이", "color": Color("#ffffff"), "element": 1},
			{"name": "얼음기사", "color": Color("#86c5e8"), "element": 1}]},
	{"name": "별하늘 신전", "bg_top": Color("#3b3f8f"), "bg_bottom": Color("#1d1f4a"),
		"enemies": [{"name": "별요정", "color": Color("#ffe98a"), "element": 3},
			{"name": "수호상", "color": Color("#9a8fd1"), "element": 4}]},
]

static var _by_id := {}


static func get_dragon(id: String) -> Dictionary:
	if _by_id.is_empty():
		for d in DRAGONS:
			_by_id[d.id] = d
	return _by_id.get(id, {})

static func ids_of_rarity(rarity: int) -> Array:
	var out := []
	for d in DRAGONS:
		if d.rarity == rarity:
			out.append(d.id)
	return out

static func chapter(s: int) -> Dictionary:
	var c := s / Balance.STAGES_PER_CHAPTER
	return CHAPTERS[c % CHAPTERS.size()]

## 7챕터부터는 테마가 순환하며 "어려움 n단계" 로 표기한다.
static func chapter_title(s: int) -> String:
	var c := s / Balance.STAGES_PER_CHAPTER
	var title: String = CHAPTERS[c % CHAPTERS.size()].name
	var tier := c / CHAPTERS.size()
	if tier > 0:
		title += " · 어려움 %d" % tier
	return title

static func skill_text(skill: Dictionary) -> String:
	if skill.is_empty():
		return "스킬 없음"
	var t: String = skill.type
	var cd := "%d초마다 " % int(skill.cd)
	match t:
		"single":
			return cd + "단일 대상 공격력 %d%%" % int(skill.power * 100)
		"aoe":
			var s := cd + "전체 공격력 %d%%" % int(skill.power * 100)
			if skill.has("stun"):
				s += " + 적 공격 지연"
			if skill.has("gold"):
				s += " + %d초간 골드 +%d%%" % [int(skill.dur), int(skill.gold * 100)]
			return s
		"heal":
			return cd + "파티 체력 %d%% 회복" % int(skill.power * 100)
		"buff_atk":
			return cd + "%d초간 파티 공격력 +%d%%" % [int(skill.dur), int(skill.power * 100)]
		"buff_gold":
			return cd + "%d초간 골드 +%d%%" % [int(skill.dur), int(skill.power * 100)]
	return ""
