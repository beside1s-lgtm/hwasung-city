export interface RetainerInfo {
  id: string;
  name: string;
  role: string;
  cost: number;
  icon: string;
  desc: string;
}

export const RETAINER_LIST: RetainerInfo[] = [
  { id: 'jeong', name: "다산 정약용", role: "실학·설계 총괄", cost: 200, icon: "📐", desc: "거중기·유형거 발명으로 성곽 완공 진행률 +80% 가속" },
  { id: 'chae', name: "번암 채제공", role: "성역 총리대동", cost: 150, icon: "📜", desc: "예산 집행 절감 20%, 관료 부정부패 누수 방지" },
  { id: 'park', name: "초정 박제가", role: "북학·상업 진흥", cost: 180, icon: "⛵", desc: "신해통공 상업 세수 +40% 증가, 대외 쌀 수입 우대" },
  { id: 'baek', name: "야뇌 백동수", role: "장용영 무예 총관", cost: 200, icon: "⚔️", desc: "매 턴 국방력 +10, 군사 훈련 가속, 도적 침투 완벽 차단" },
  { id: 'kim', name: "단원 김홍도", role: "도화서 화원", cost: 120, icon: "🎨", desc: "풍속화 기록으로 매 턴 백성 충성도 +2% 상승" },
  { id: 'seo', name: "풍석 서유구", role: "농학·임원경제지", cost: 160, icon: "🌾", desc: "대유둔전 농업 생산량 +25% 영구 증산 및 가뭄 극복" },
  { id: 'guk', name: "도승지 홍국영", role: "측근·숙위소 대장", cost: 220, icon: "👑", desc: "왕권 +15 즉시 상승 (부작용: 매 턴 충성도 -2%)" },
  { id: 'gu', name: "어영대장 구선복", role: "군부 실세", cost: 250, icon: "🛡️", desc: "매 턴 국방력 +25 급증 (부작용: 군량 -20 추가 소모)" },
  { id: 'hong', name: "좌의정 홍인한", role: "노론 벽파 수괴", cost: 0, icon: "💰", desc: "매 턴 비자금 +350 헌납 (부작용: 매 턴 민심 -3% 급락)" }
];
