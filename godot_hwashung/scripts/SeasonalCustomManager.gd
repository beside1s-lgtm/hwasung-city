extends RefCounted
class_name SeasonalCustomManager

## [세시풍속(歲時風俗) 및 민속축제 특수 엔티티 관리자]
## 단오 씨름, 줄다리기, 농악대, 지신밟기 풍물패 등 계절 축제 참여 엔티티에
## is_special_entity / is_always_visible 플래그를 부여하고
## 줌아웃 상태(>400칸)에서도 상시 노출(Zoom Culling 완전 면제)되도록 보장합니다.

const CUSTOM_TYPES: Array[String] = [
	"pungmul", "pungmul_band", "taekkyeon", "ssireum", "talchum",
	"seokjeon", "ganggang", "juldagi", "kites", "paengi", "jwibul",
	"bull_parade", "stretcher"
]

## 활동명이나 엔티티 타입이 세시풍속 활동인지 검사
static func is_seasonal_custom(activity_kind: String) -> bool:
	if activity_kind in CUSTOM_TYPES:
		return true
	for ct_type: String in CUSTOM_TYPES:
		if activity_kind.begins_with(ct_type):
			return true
	return false

## 세시풍속 엔티티에 상시 표시 특수 개체 플래그 부여
static func apply_custom_flags(target: Variant) -> void:
	if target is Dictionary:
		target["festival"] = true
		target["is_custom"] = true
		target["is_special_entity"] = true
		target["is_always_visible"] = true
		SpecialEntityManager.register_special(target)
	elif target is Object and is_instance_valid(target):
		if "is_special_entity" in target:
			target.set("is_special_entity", true)
		if "is_always_visible" in target:
			target.set("is_always_visible", true)
		if "is_participating_custom" in target:
			target.set("is_participating_custom", true)
		if target.has_method("set_custom_participation"):
			target.call("set_custom_participation", true)
		SpecialEntityManager.register_special(target)

static func tag_custom_actor(target: Variant, _kind: String = "") -> void:
	apply_custom_flags(target)
