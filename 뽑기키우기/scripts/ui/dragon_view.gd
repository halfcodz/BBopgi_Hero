class_name DragonView
extends Control
## 드래곤 한 마리를 컨트롤 영역 안에 그린다 (카드, 상세, 결과 화면 공용).

var dragon_id := ""
var silhouette := false
var star_override := -1
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	t = randf() * 10.0


func _process(delta: float) -> void:
	if is_visible_in_tree():
		t += delta
		queue_redraw()


func _draw() -> void:
	if dragon_id == "":
		return
	var d := DragonDB.get_dragon(dragon_id)
	if d.is_empty():
		return
	var star := star_override if star_override > 0 else Game.dragon_star(dragon_id)
	var r := minf(size.x, size.y) * 0.3
	DragonArt.draw_dragon(self, size / 2.0 + Vector2(r * 0.15, r * 0.05), r, d.element, d.rarity, star, t, 1.0, 0.0, silhouette)
