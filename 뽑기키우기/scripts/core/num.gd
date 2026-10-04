class_name Num
extends RefCounted
## 큰 수 표기: 999 → 1.00K → 1.00M → B → T → aa, ab, ... zz

const SUFFIXES := ["", "K", "M", "B", "T"]


static func fmt(value: float) -> String:
	if is_nan(value) or is_inf(value):
		return "∞"
	var neg := value < 0
	var v := absf(value)
	if v < 1000.0:
		var small := str(int(floor(v))) if v >= 10.0 or is_equal_approx(v, floor(v)) else "%.1f" % v
		return ("-" if neg else "") + small
	var tier := 0
	while v >= 1000.0:
		v /= 1000.0
		tier += 1
	var suffix := ""
	if tier < SUFFIXES.size():
		suffix = SUFFIXES[tier]
	else:
		var i := tier - SUFFIXES.size()
		suffix = char(97 + (i / 26) % 26) + char(97 + i % 26)
	var digits := "%.2f" % v if v < 10.0 else ("%.1f" % v if v < 100.0 else "%d" % int(v))
	return ("-" if neg else "") + digits + suffix


static func fmt_time(sec: float) -> String:
	var s := int(sec)
	var h := s / 3600
	var m := (s % 3600) / 60
	if h > 0:
		return "%d시간 %d분" % [h, m]
	if m > 0:
		return "%d분 %d초" % [m, s % 60]
	return "%d초" % s
