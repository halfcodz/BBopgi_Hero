class_name Widgets
extends RefCounted
## 작은 그리기 위젯 생성 함수 모음.


## 재화 아이콘 Control
static func currency_icon(kind: String, size := 32.0) -> Control:
	var c := IconView.new()
	c.kind = kind
	c.custom_minimum_size = Vector2(size, size)
	return c


## 드래곤 그림 Control (id 가 비어 있으면 아무것도 그리지 않음)
static func dragon_view(id: String, size := 96.0, silhouette := false) -> DragonView:
	var v := DragonView.new()
	v.dragon_id = id
	v.silhouette = silhouette
	v.custom_minimum_size = Vector2(size, size)
	return v


class IconView extends Control:
	var kind := "gold"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.42
		DragonArt.draw_currency(self, size / 2.0, r, kind)
