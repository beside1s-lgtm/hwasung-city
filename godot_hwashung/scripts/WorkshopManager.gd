extends RefCounted
class_name WorkshopManager

## [공방(수공업·대장간) 경제·군사 복합 시너지 엔진]
## 1. 저잣거리 세수 매칭 버프 (+2%):
##    - 공방 1개소당 저잣거리 상점 최대 10개소까지 상품 조달 버프 부여 (세수 +2% 증가)
##    - covered_shops = min(total_shops, total_workshops * 10)
## 2. 공방 부재 시 군사력 -50% 페널티 (무기/군수품 결핍):
##    - 도시 내 가동 중인 공방이 0개일 때 기본 군사력의 50% 삭감
##    - 단, 초기 1년(4턴) 동안은 유예 (계수 1.0)
## 3. 공방 수 비례 군사력 점진 버프 (최대 +5% 상한):
##    - 공방 1개소당 +0.25% 증가, 20개소 이상 시 최대 +5.0% 상한 고정

const SHOPS_PER_WORKSHOP: int = 10
const MARKET_TAX_BUFF_RATE: float = 0.02 # +2%
const MILITARY_NO_WORKSHOP_PENALTY: float = 0.50 # -50%
const MILITARY_BUFF_PER_WORKSHOP: float = 0.0025 # +0.25%
const MILITARY_MAX_BUFF: float = 0.05 # +5.0%
const MAX_BUFF_WORKSHOPS: int = 20
const GRACE_PERIOD_TURNS: int = 4 # 초기 1년(4턴) 유예

## 1. 저잣거리 상점 세수 버프 정산 (O(1) 수식 정산)
## 공식: (covered_shops * base_shop_tax * 1.02) + (uncovered_shops * base_shop_tax)
static func calculate_market_tax(total_shops: int, total_workshops: int, base_shop_tax: int) -> Dictionary:
	var covered_shops: int = mini(total_shops, total_workshops * SHOPS_PER_WORKSHOP)
	var uncovered_shops: int = maxi(0, total_shops - covered_shops)

	var covered_tax: float = float(covered_shops) * float(base_shop_tax) * (1.0 + MARKET_TAX_BUFF_RATE)
	var uncovered_tax: float = float(uncovered_shops) * float(base_shop_tax)
	var total_tax: int = int(round(covered_tax + uncovered_tax))

	var base_total: int = total_shops * base_shop_tax
	var buff_amount: int = maxi(0, total_tax - base_total)

	return {
		"total_tax": total_tax,
		"covered_shops": covered_shops,
		"uncovered_shops": uncovered_shops,
		"total_shops": total_shops,
		"total_workshops": total_workshops,
		"buff_amount": buff_amount,
		"base_tax": base_total,
		"buff_applied": covered_shops > 0
	}

## 2. 공방 수량에 따른 군사력 승수(Multiplier) 산출
## - 공방 0개 (4턴 초과): 0.50 (-50%)
## - 공방 0개 (4턴 이하): 1.00 (초기 건립 유예)
## - 공방 1개 이상: 1.0 + min(0.05, total_workshops * 0.0025)
static func get_military_multiplier(workshop_count: int, turn: int = 1) -> float:
	if workshop_count <= 0:
		if turn <= GRACE_PERIOD_TURNS:
			return 1.0
		return MILITARY_NO_WORKSHOP_PENALTY

	var buff_rate: float = minf(MILITARY_MAX_BUFF, float(workshop_count) * MILITARY_BUFF_PER_WORKSHOP)
	return 1.0 + buff_rate

## 3. 공방 군사력 버프/페널티 퍼센트 반환 (-50.0 ~ +5.0%)
static func get_military_buff_percent(workshop_count: int, turn: int = 1) -> float:
	var mult: float = get_military_multiplier(workshop_count, turn)
	return (mult - 1.0) * 100.0

## 4. 공방 완전 부재 페널티 활성화 여부
static func is_penalty_active(workshop_count: int, turn: int = 1) -> bool:
	return workshop_count <= 0 and turn > GRACE_PERIOD_TURNS

## 5. 공방 군사력 종합 상태 정보 딕셔너리
static func get_military_status_info(workshop_count: int, turn: int = 1) -> Dictionary:
	var mult: float = get_military_multiplier(workshop_count, turn)
	var penalized: bool = is_penalty_active(workshop_count, turn)
	var in_grace: bool = (workshop_count <= 0 and turn <= GRACE_PERIOD_TURNS)
	var buff_pct: float = (mult - 1.0) * 100.0

	var warning_msg: String = ""
	if penalized:
		warning_msg = "⚠️ [군수품 부족] 공방이 전무하여 군사들의 무기 보급이 마비되었습니다! (군사력 -50%)"

	return {
		"multiplier": mult,
		"workshop_count": workshop_count,
		"turn": turn,
		"is_penalized": penalized,
		"is_grace_period": in_grace,
		"buff_percent": buff_pct,
		"warning_message": warning_msg
	}

## 6. 저잣거리 살피기 및 조세 창용 UI 피드백 문자열
static func get_market_buff_tooltip_text(covered_shops: int, total_shops: int) -> String:
	return "[공방 공급 효과: %d / %d개 상점 적용 중 (+2%%)]" % [covered_shops, total_shops]
