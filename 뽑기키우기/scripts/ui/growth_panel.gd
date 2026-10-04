extends Control
## 성장 탭: 둥지 이사(환생) + 통계 (기획서 8.3)

var scales_label: Label
var gain_label: Label
var req_label: Label
var btn_prestige: Button
var stats_label: Label
var _t := 0.0


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var v := UIKit.vbox(12)
	var m := UIKit.margin(v, 20, 16, 20, 12)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(m)

	var card := UIKit.card(Color("#e3f7f1"), 22)
	v.add_child(card)
	var cv := UIKit.vbox(8)
	card.add_child(UIKit.margin(cv, 8, 8, 8, 8))
	var title := UIKit.hbox(10)
	title.add_child(Widgets.currency_icon("scale", 40))
	title.add_child(UIKit.label("둥지 이사 (환생)", 28))
	cv.add_child(title)
	var desc := UIKit.label("새 둥지로 이사하면 스테이지·골드·드래곤 레벨이 처음으로 돌아가지만, 용의 비늘을 얻어 공격력과 골드가 영구히 올라가요. 드래곤·별·코인·기계 레벨은 그대로예요.", 19, UIKit.TEXT_SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(desc)
	scales_label = UIKit.label("", 22)
	cv.add_child(scales_label)
	gain_label = UIKit.label("", 26, Color("#2e9c84"))
	cv.add_child(gain_label)
	req_label = UIKit.label("", 19, UIKit.TEXT_SOFT)
	req_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(req_label)
	btn_prestige = UIKit.button("둥지 이사하기", Color("#3fbf9f"), 26, Vector2(0, 76))
	btn_prestige.pressed.connect(_confirm)
	cv.add_child(btn_prestige)

	var stats_card := UIKit.card(UIKit.PANEL_DARK, 22)
	v.add_child(stats_card)
	var sv := UIKit.vbox(6)
	stats_card.add_child(UIKit.margin(sv, 8, 8, 8, 8))
	sv.add_child(UIKit.label("기록", 24))
	stats_label = UIKit.label("", 19, UIKit.TEXT_SOFT)
	sv.add_child(stats_label)

	var reset := UIKit.button("세이브 초기화", UIKit.GRAY, 18, Vector2(0, 48))
	reset.pressed.connect(_confirm_reset)
	v.add_child(reset)
	_refresh()


func on_shown() -> void:
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	if _t > 0.5 and is_visible_in_tree():
		_t = 0.0
		_refresh()
	if btn_prestige and not btn_prestige.disabled and Game.prestige_gain() >= maxi(2, Game.scales):
		btn_prestige.modulate = Color(1, 1, 1).lerp(Color(1.3, 1.3, 1.1), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0))
	elif btn_prestige:
		btn_prestige.modulate = Color.WHITE


func _refresh() -> void:
	var bonus := int(Game.scales * Balance.SCALE_BONUS * 100)
	scales_label.text = "보유 비늘 %d개 → 공격력·골드 +%d%%" % [Game.scales, bonus]
	var gain := Game.prestige_gain()
	if Game.max_stage < Balance.PRESTIGE_UNLOCK_STAGE:
		gain_label.text = "아직 이사할 수 없어요"
		req_label.text = "이번 회차에서 %s 스테이지에 도달하면 해금 (현재 최고 %s)" % [
			Balance.stage_label(Balance.PRESTIGE_UNLOCK_STAGE), Balance.stage_label(Game.max_stage)]
	else:
		gain_label.text = "지금 이사하면 비늘 +%d (보너스 +%d%% → +%d%%)" % [gain, bonus, int((Game.scales + gain) * Balance.SCALE_BONUS * 100)]
		var next_gain_stage := Game.max_stage
		while Balance.scales_for(next_gain_stage) <= gain and next_gain_stage < Game.max_stage + 200:
			next_gain_stage += 1
		req_label.text = "%s까지 가면 +%d. 더 깊이 갈수록 비늘이 많아져요." % [Balance.stage_label(next_gain_stage), Balance.scales_for(next_gain_stage)]
	btn_prestige.disabled = not Game.can_prestige()
	stats_label.text = "\n".join(PackedStringArray([
		"계정 최고 스테이지  %s" % Balance.stage_label(Game.best_stage),
		"이번 회차 최고  %s" % Balance.stage_label(Game.max_stage),
		"둥지 이사  %d회" % Game.prestige_count,
		"누적 처치  %s마리" % Num.fmt(Game.total_kills),
		"누적 뽑기  %d회 (기계 Lv.%d)" % [Game.total_pulls, Gacha.machine_level()],
		"초당 골드  %s" % Num.fmt(Game.gold_rate),
		"보유 드래곤  %d / %d종" % [Game.dragons.size(), DragonDB.DRAGONS.size()],
	]))


func _main() -> Node:
	var n: Node = get_parent()
	while n != null and not n.has_method("show_modal"):
		n = n.get_parent()
	return n


func _confirm() -> void:
	if not Game.can_prestige():
		return
	var l := UIKit.label("스테이지 %s → 1-1\n비늘 +%d 를 받고 새 둥지로 이사할까요?" % [Balance.stage_label(Game.stage), Game.prestige_gain()], 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_main().show_modal("둥지 이사", l, [["이사하기", _do_prestige, Color("#3fbf9f")], ["취소", Callable(), UIKit.GRAY]])


func _do_prestige() -> void:
	var gain := Game.do_prestige()
	if gain > 0:
		Game.toast.emit("새 둥지로 이사 완료! 비늘 +%d" % gain, Color("#9ff0dc"))
	_refresh()


func _confirm_reset() -> void:
	var l := UIKit.label("모든 진행 상황이 지워져요. 정말 초기화할까요?", 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main().show_modal("세이브 초기화", l, [["초기화", func(): Game.reset_save(), Color("#ff6b81")], ["취소", Callable(), UIKit.GRAY]])
