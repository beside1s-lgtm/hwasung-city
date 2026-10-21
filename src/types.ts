export type TerrainType = 'plain' | 'mountain' | 'water';

export interface TileData {
  x: number;
  y: number;
  elevation: number;
  terrain: TerrainType;
  building: string | null;
  zone: 'res' | 'com' | 'agr' | null;
  level: number;
  smokeOffset: number;
  cornerElev: [number, number, number, number];
  underConstruction?: boolean; // 국책 대역사 공사 진행 중 여부
  isRoadConnected?: boolean;   // 도로 연결 여부
  roadDist?: number;           // 도로망과의 최단 거리
  isWalkway?: boolean;         // 보행로/순찰로 겸용 여부
}

export interface TroopRoster {
  total: number;
  posu: number;
  sasu: number;
  salsu: number;
  gipo: number;
}

export interface CitizenAgent {
  id: number;
  x: number;
  y: number;
  targetX: number;
  targetY: number;
  type: 'carrier' | 'merchant' | 'guard' | 'farmer' | 'posu' | 'sasu' | 'salsu' | 'gipo' | 'militia' | 'supply_carrier' | 'traitor';
  action: 'walk' | 'work' | 'patrol' | 'combat';
  speed: number;
  animFrame: number;
  militaryUnit?: boolean;
  btype?: 'posu' | 'sasu' | 'salsu' | 'gipo';
  peaceAnchor?: { x: number; y: number };
  bubbleText?: string;
  bubbleTimer?: number;
  reloadTimer?: number;
  drawTimer?: number;
  fireTimer?: number;
}

export interface Retainers {
  jeong: boolean; // 정약용 (거중기, 공기 단축 35%)
  chae: boolean;  // 채제공 (총리대신, 공사비 25% 절감)
  park: boolean;  // 박제가 (상업 +40%)
  baek: boolean;  // 백동수 (장용영 정예화, 도적 차단)
  kim: boolean;   // 김홍도 (민심 안정)
  seo: boolean;   // 서유구 (농학 생산 +25%)
  guk: boolean;   // 홍국영 (왕권 강화)
  gu: boolean;    // 구선복 (군사 급증, 반란 리스크)
  hong: boolean;  // 홍인한 (위험한 비자금 지원)
}

export interface ResearchTech {
  goguma: boolean;    // 조엄의 감저(고구마)
  gwanong: boolean;   // 박지원 과농소초
  seed: boolean;      // 서유구 우량 벼 품종
  fertilizer: boolean;// 녹비·퇴비 시비법
  reservoir: boolean; // 만석거 관개 정비
}

export interface TaxRates {
  landTax: number;   // 지세 (0 ~ 20%, 기본 7%)
  marketTax: number; // 시전세 (0 ~ 20%, 기본 7%)
  militaryTax: number; // 결포/호포세 (0 ~ 20%, 기본 7%)
}

export interface MegaProject {
  id: string;
  name: string;
  category: 'water' | 'fortress' | 'agriculture';
  desc: string;
  baseTurns: number;
  costPerTurn: { gold: number; rice: number };
  progressTurns: number;
  totalTurns: number;
  isStarted: boolean;
  isCompleted: boolean;
  targetTiles: Array<{ x: number; y: number; building: string }>;
  rewardMsg: string;
}

export interface GameState {
  turn: number;
  year: number;
  seasonIndex: number;
  seasons: string[];
  seasonIcons: string[];
  gold: number;
  rice: number;
  pop: number;
  loyalty: number;
  authority: number;
  military: number;
  fortressProgress: number;
  floodDefense: number; // 치수 및 제방 안전율 (0 ~ 100%)
  reservoirCount: number; // 만석거/저수지 축조 수
  megaProjects: MegaProject[]; // 국책 대역사 목록
  retainers: Retainers;
  research: ResearchTech;
  soundEnabled: boolean;
  currentTool: string;
  isPanMode: boolean;
  rotation: number;
  demandRes: number;
  demandCom: number;
  demandAgr: number;
  taxRates: TaxRates;
  trade: {
    autoBuyRice: boolean;
    totalImportedRice: number;
    isConnected: boolean;      // 지도 밖으로 삼남로 연결 여부
    hasBorderGate: boolean;    // 교역로 길목 성문/관문 존재 여부
    activeMerchants: number;   // 대외 보부상 활동 수
  };
  crownPrince: {
    invested: boolean;         // 세자 책봉 여부
    educationLevel: number;    // 서연(제왕학 교육) 진척도 (0 ~ 100%)
    tutor: string;             // 시강원 담당 스승 ('jeong' | 'chae' | 'classic' | '')
    friction: number;          // 노론 벽파 견제 지수
  };
  tigerCrisis: {
    active: boolean;           // 호환(호랑이 출몰) 상태
    threatLevel: number;       // 위협 단계 (1 ~ 3)
    solved: boolean;           // 포호령 완료 여부
  };
  hyoryungwon: {
    visited: boolean;          // 화산 현륭원 친림 참배 여부
    blessingActive: boolean;   // 효심 가호(민심/왕권 보너스) 활성화 여부
  };
  eulmyoEvent: {
    active: boolean;
    step: 'bridge' | 'gyeokjaeng' | 'banquet' | 'done';
    gyeokjaengSolved: number;  // 해결한 백성 격쟁/상언 탄원 수
  };
  milestones: {
    wonhaeng1789: boolean;
    eulmyo1795: boolean;
  };
  defensePower?: number; // 방호력 데이터 (0 ~ 1000)
  repairState?: RepairState; // 보수 상태 객체
  isWartimeMobilized?: boolean; // 전시 총동원 모드 플래그
  troopRoster?: TroopRoster; // 조선 후기 삼수병·기포병 편제 데이터
}

export interface RepairState {
  isRepairing: boolean;
  repairType: 'emergency' | 'grand' | 'none';
  turnsLeft: number;
}

export interface Quest {
  id: string;
  title: string;
  desc: string;
  tool: string;
  btnText: string;
  check: (grid: TileData[][], state: GameState) => boolean;
  reward: {
    gold?: number;
    rice?: number;
    loyalty?: number;
    authority?: number;
    msg: string;
  };
}

export interface NewspaperArticle {
  headline: string;
  subhead: string;
  body: string;
  editorial: string;
  dateStr: string;
}
