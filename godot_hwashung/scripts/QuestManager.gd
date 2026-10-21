extends QuestSystem
class_name QuestManager

## [QuestManager: QuestSystem 호환 래퍼 및 퀘스트 관리자]
## 김판관 과업(6대/7대 교지) 및 난이도별 보상 분기 관리

static func get_reward_for_quest(base_reward: Dictionary) -> Dictionary:
	return DifficultyManager.get_quest_reward(base_reward)
