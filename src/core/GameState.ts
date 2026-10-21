import { GameState, TileData, Quest, NewspaperArticle, CitizenAgent } from '../types';
import { WallManager } from './WallManager';
import { DefenseSystem } from './DefenseSystem';
import { CitizenManager } from './CitizenManager';

export class GameStateManager {
  public static readonly MAP_SIZE = 16;
  public static readonly TILE_W = 64;
  public static readonly TILE_H = 32;
  public static readonly ELEV_STEP = 16; // 부드러운 단차 스텝

  public state: GameState;
  public grid: TileData[][];
  public cornerHeights: number[][] = []; // 17x17 부드러운 정점 높이맵
  public citizens: CitizenAgent[] = [];
  public currentQuestIndex = 0;
  public wallManager = new WallManager();
  public defenseSystem = new DefenseSystem();
  public citizenManager = new CitizenManager();

  public quests: Quest[] = [
    {
      id: 'office',
      title: "제1교지: 행정 사령탑(동헌) 설치",
      desc: "개혁 신도시의 기틀이 될 수원유수부 동헌을 평지에 지으십시오.",
      tool: 'office',
      btnText: "동헌 터 잡기",
      check: (grid) => grid.some(row => row.some(t => t.building === 'office')),
      reward: { gold: 200, rice: 100, msg: "동헌이 완공되어 행정 체계가 수립되었습니다! (+🪙200, +🌾100)" }
    },
    {
      id: 'road',
      title: "제2교지: 삼남대로 5칸 개설",
      desc: "동헌과 이어지는 큰길(삼남대로)을 드래그하여 물류망을 뚫으십시오.",
      tool: 'road',
      btnText: "도로 닦기",
      check: (grid) => {
        let count = 0;
        grid.forEach(row => row.forEach(t => { if (t.building === 'road') count++; }));
        return count >= 5;
      },
      reward: { gold: 150, rice: 50, msg: "삼남대로가 뚫려 보부상과 유민들이 모여듭니다! (+🪙150)" }
    },
    {
      id: 'seojangdae',
      title: "제3교지: 팔달산 서장대(西將臺) 축조",
      desc: "팔달산 정상에 군사 총지휘소 [서장대]를 축조하십시오.",
      tool: 'seojangdae',
      btnText: "서장대 축조",
      check: (grid) => grid.some(row => row.some(t => t.building === 'seojangdae')),
      reward: { gold: 150, loyalty: 5, msg: "서장대가 세워져 팔달산 정상에서 사방을 감제합니다! (+🪙150, ❤️+5%)" }
    },
    {
      id: 'bongdon',
      title: "제4교지: 화성 봉돈(烽墩) 축조",
      desc: "팔달산 능선에 위급을 알리는 5연 굴뚝 [봉돈]을 축조하십시오.",
      tool: 'bongdon',
      btnText: "봉돈 축조",
      check: (grid) => grid.some(row => row.some(t => t.building === 'bongdon')),
      reward: { gold: 150, loyalty: 5, msg: "봉돈이 축조되어 주야간 군사 통신망이 완비되었습니다! (+🪙150, ❤️+5%)" }
    },
    {
      id: 'civil_zoning',
      title: "제5교지: 백성 구획 및 공동 우물 조성",
      desc: "방·리(주거), 저잣거리(상업), 둔전(농업) 구획을 지정하고 우물을 파십시오.",
      tool: 'well',
      btnText: "우물 파기",
      check: (grid) => {
        let hasZone = false, hasWell = false;
        grid.forEach(row => row.forEach(t => {
          if (t.zone || (t.building && (t.building.startsWith('res') || t.building.startsWith('com') || t.building.startsWith('agr')))) hasZone = true;
          if (t.building === 'well') hasWell = true;
        }));
        return hasZone && hasWell;
      },
      reward: { gold: 300, rice: 200, msg: "백성들이 정착하고 신도시가 활기를 띱니다! (+🪙300, +🌾200)" }
    },
    {
      id: 'wall_build',
      title: "제6교지: 화성 성곽 축조 및 완공",
      desc: "화성 성곽을 둘러치고 24년 내에 100% 완공을 달성하십시오.",
      tool: 'wall',
      btnText: "성곽 축조",
      check: (_, state) => state.fortressProgress >= 100,
      reward: { gold: 1000, authority: 30, msg: "축하하옵니다! 수원화성 성곽이 완벽히 완공되었습니다!" }
    }
  ];

  constructor() {
    this.state = {
      turn: 1,
      year: 1776,
      seasonIndex: 0,
      seasons: ['봄', '여름', '가을', '겨울'],
      seasonIcons: ['🌸', '☀️', '🍁', '❄️'],
      gold: 2500,
      rice: 1600,
      pop: 120,
      loyalty: 88,
      authority: 70,
      military: 100,
      fortressProgress: 0,
      floodDefense: 0,
      reservoirCount: 0,
      megaProjects: [],
      retainers: {
        jeong: false, chae: true, park: false, baek: false,
        kim: false, seo: false, guk: false, gu: false, hong: false
      },
      research: {
        goguma: false, gwanong: false, seed: false, fertilizer: false, reservoir: false
      },
      soundEnabled: true,
      currentTool: 'inspect',
      isPanMode: false,
      rotation: 0,
      demandRes: 65,
      demandCom: 45,
      demandAgr: 50,
      taxRates: { landTax: 7, marketTax: 7, militaryTax: 7 },
      trade: {
        autoBuyRice: true,
        totalImportedRice: 0,
        isConnected: false,
        hasBorderGate: false,
        activeMerchants: 0
      },
      crownPrince: {
        invested: false,
        educationLevel: 0,
        tutor: '',
        friction: 0
      },
      tigerCrisis: {
        active: false,
        threatLevel: 1,
        solved: false
      },
      hyoryungwon: {
        visited: false,
        blessingActive: false
      },
      eulmyoEvent: {
        active: false,
        step: 'bridge',
        gyeokjaengSolved: 0
      },
      milestones: { wonhaeng1789: false, eulmyo1795: false }
    };

    this.grid = [];
    this.initSmoothTerrain();
    this.initCitizens();
    this.initMegaProjects();
    this.updateDemands();
  }

  private initMegaProjects(): void {
    this.state.megaProjects = [
      {
        id: 'levee_project',
        name: "수원천 3대 석축 제방 및 준천 대역사",
        category: 'water',
        desc: "영조의 청계천 준천을 본받아 수원천 강바닥을 파내고 견고한 화강암 석축 제방 8칸을 축조하여 여름철 홍수를 영구 차단합니다.",
        baseTurns: 6,
        costPerTurn: { gold: 80, rice: 40 },
        progressTurns: 0,
        totalTurns: 6,
        isStarted: false,
        isCompleted: false,
        targetTiles: [
          { x: 7, y: 3, building: 'levee' }, { x: 7, y: 5, building: 'levee' },
          { x: 7, y: 7, building: 'levee' }, { x: 7, y: 9, building: 'levee' },
          { x: 10, y: 4, building: 'levee' }, { x: 10, y: 6, building: 'levee' },
          { x: 10, y: 8, building: 'levee' }, { x: 10, y: 10, building: 'levee' }
        ],
        rewardMsg: "수원천 석축 제방 대역사가 완공되어 치수 방재율 100%를 달성했습니다!"
      },
      {
        id: 'fortress_west',
        name: "팔달산 능선 서성곽 및 서장대 대역사",
        category: 'fortress',
        desc: "팔달산 정상 군사 총지휘소 서장대와 능선을 둘러치는 철통같은 방어 성벽 8칸을 대규모 부역으로 축성합니다.",
        baseTurns: 8,
        costPerTurn: { gold: 110, rice: 50 },
        progressTurns: 0,
        totalTurns: 8,
        isStarted: false,
        isCompleted: false,
        targetTiles: [
          { x: 2, y: 2, building: 'seojangdae' },
          { x: 1, y: 2, building: 'wall' }, { x: 1, y: 3, building: 'wall' },
          { x: 2, y: 4, building: 'wall' }, { x: 3, y: 4, building: 'wall' },
          { x: 4, y: 4, building: 'wall' }, { x: 4, y: 3, building: 'wall' },
          { x: 3, y: 1, building: 'wall' }, { x: 2, y: 1, building: 'wall' }
        ],
        rewardMsg: "팔달산 서성곽과 서장대가 우뚝 솟아 군사 방어력이 대폭 증강되었습니다!"
      },
      {
        id: 'fortress_north',
        name: "화홍문(북수문) 및 장안문 북성곽 대역사",
        category: 'fortress',
        desc: "수원천 위로 7개의 무지개 홍예를 틀어올리는 화홍문과 웅장한 장안문 북성곽 8칸을 축조합니다.",
        baseTurns: 8,
        costPerTurn: { gold: 130, rice: 60 },
        progressTurns: 0,
        totalTurns: 8,
        isStarted: false,
        isCompleted: false,
        targetTiles: [
          { x: 5, y: 1, building: 'wall' }, { x: 6, y: 1, building: 'wall' },
          { x: 7, y: 1, building: 'wall' }, { x: 8, y: 1, building: 'wall' },
          { x: 9, y: 1, building: 'wall' }, { x: 10, y: 1, building: 'wall' },
          { x: 11, y: 1, building: 'wall' }, { x: 12, y: 1, building: 'wall' }
        ],
        rewardMsg: "화홍문 북수문과 장안문 성벽이 틈새 없이 완공되었습니다!"
      },
      {
        id: 'manseok_project',
        name: "만석거·축만제 및 대유둔전 수리 관개 대역사",
        category: 'agriculture',
        desc: "고지대에 인공 저수지 만석거를 파고, 관개 수로와 함께 둔전 4필지를 개간하여 가뭄을 영구 퇴치합니다.",
        baseTurns: 6,
        costPerTurn: { gold: 90, rice: 45 },
        progressTurns: 0,
        totalTurns: 6,
        isStarted: false,
        isCompleted: false,
        targetTiles: [
          { x: 3, y: 5, building: 'reservoir' },
          { x: 4, y: 6, building: 'agr_2' }, { x: 5, y: 6, building: 'agr_2' },
          { x: 4, y: 7, building: 'agr_2' }, { x: 5, y: 7, building: 'agr_2' }
        ],
        rewardMsg: "만석거 수문이 열려 대유둔전으로 물이 넘쳐흐르며 대풍년이 시작되었습니다!"
      }
    ];
  }

  public startMegaProject(id: string): { success: boolean; msg: string } {
    const p = this.state.megaProjects.find(item => item.id === id);
    if (!p) return { success: false, msg: "해당 국책사업이 존재하지 않습니다." };
    if (p.isStarted) return { success: false, msg: "이미 공사가 진행 중입니다." };
    if (p.isCompleted) return { success: false, msg: "이미 완공된 사업입니다." };

    // 인재 효과 적용: 정약용 (기간 35% 단축), 채제공 (공사비 25% 절감)
    const turnDiscount = this.state.retainers.jeong ? 0.65 : 1.0;
    const costDiscount = this.state.retainers.chae ? 0.75 : 1.0;

    p.totalTurns = Math.max(3, Math.round(p.baseTurns * turnDiscount));
    p.costPerTurn.gold = Math.round(p.costPerTurn.gold * costDiscount);
    p.costPerTurn.rice = Math.round(p.costPerTurn.rice * costDiscount);

    if (this.state.gold < p.costPerTurn.gold || this.state.rice < p.costPerTurn.rice) {
      return { success: false, msg: "착공에 필요한 첫 턴 국고나 군량이 부족하옵니다!" };
    }

    this.state.gold -= p.costPerTurn.gold;
    this.state.rice -= p.costPerTurn.rice;
    p.isStarted = true;
    p.progressTurns = 1;

    // 대상 타일에 공사 현장 플래그 설정 (비계/거중기 렌더링 시작)
    p.targetTiles.forEach(pt => {
      const tile = this.grid[pt.y]?.[pt.x];
      if (tile) {
        tile.underConstruction = true;
      }
    });

    return {
      success: true,
      msg: `어명을 받들어 [${p.name}] 대역사에 착공하였습니다! (예상 공기: ${p.totalTurns}턴)`
    };
  }

  /**
   * 심시티 2000/4 스타일 연속 슬로프 정점 높이맵 (17x17) 및 타일 지형 초기화
   */
  private initSmoothTerrain(): void {
    const size = GameStateManager.MAP_SIZE;
    const vertexSize = size + 1;

    // 1. 초기 기본 정점 높이 생성 (수원 분지 지형: 북서 팔달산 4~5단, 남동 화산 3~4단, 수원천 0단, 평지 1단)
    const rawVertex: number[][] = [];
    for (let vy = 0; vy < vertexSize; vy++) {
      rawVertex[vy] = [];
      for (let vx = 0; vx < vertexSize; vx++) {
        let h = 1.0;
        // 북서측 팔달산 주봉 (서장대 능선)
        const distToPaldal = Math.hypot(vx - 2, vy - 2);
        if (distToPaldal < 6) {
          h = Math.max(h, 4.2 - distToPaldal * 0.65);
        }

        // 남동측 화산(花山) 봉우리 - 사도세자 묘소 현륭원 명당
        const distToHwasan = Math.hypot(vx - 12, vy - 14);
        if (distToHwasan < 4.5) {
          h = Math.max(h, 3.6 - distToHwasan * 0.6);
        }

        // 수원천 완만한 계곡 수로 (x: 8~9 부근 남북 관통)
        const streamX = 8.5 + Math.sin(vy * 0.45) * 1.2;
        const distToStream = Math.abs(vx - streamX);
        if (distToStream < 1.8) {
          h = Math.min(h, 0.15 + distToStream * 0.35);
        }

        rawVertex[vy][vx] = h;
      }
    }

    // 2. 가우시안 3x3 스무딩 필터 적용 (자연스러운 능선 및 완만한 구릉 표현)
    this.cornerHeights = [];
    for (let vy = 0; vy < vertexSize; vy++) {
      this.cornerHeights[vy] = [];
      for (let vx = 0; vx < vertexSize; vx++) {
        let sum = 0, count = 0;
        for (let dy = -1; dy <= 1; dy++) {
          for (let dx = -1; dx <= 1; dx++) {
            const ny = vy + dy, nx = vx + dx;
            if (ny >= 0 && ny < vertexSize && nx >= 0 && nx < vertexSize) {
              const weight = (dx === 0 && dy === 0) ? 4 : (dx === 0 || dy === 0 ? 2 : 1);
              sum += rawVertex[ny][nx] * weight;
              count += weight;
            }
          }
        }
        this.cornerHeights[vy][vx] = Number((sum / count).toFixed(2));
      }
    }

    // 3. 타일 그리드 구성 (4개 꼭짓점 버텍스 고도 연결)
    for (let y = 0; y < size; y++) {
      this.grid[y] = [];
      for (let x = 0; x < size; x++) {
        const hN = this.cornerHeights[y][x];
        const hE = this.cornerHeights[y][x + 1];
        const hS = this.cornerHeights[y + 1][x + 1];
        const hW = this.cornerHeights[y + 1][x];
        const avgElev = (hN + hE + hS + hW) / 4;

        let terrain: 'plain' | 'mountain' | 'water' = 'plain';
        if (avgElev >= 2.4) terrain = 'mountain';
        else if (avgElev <= 0.45) terrain = 'water';

        let building: string | null = null;
        // 남동쪽 화산(花山) 명당에 사도세자의 묘소 현륭원(顯隆園) 기본 배치
        if (x === 11 && y === 14) {
          building = 'hyoryungwon';
          terrain = 'mountain';
        }

        this.grid[y][x] = {
          x, y,
          elevation: Number(avgElev.toFixed(2)),
          terrain,
          building,
          zone: null,
          level: 1,
          smokeOffset: Math.random() * 10,
          cornerElev: [hN, hE, hS, hW]
        };
      }
    }
  }

  /**
   * 실시간 보행 백성 에이전트 초기화 (지게꾼, 보부상, 장용영 병사, 농민)
   */
  private initCitizens(): void {
    this.citizens = [];
    const types: Array<'carrier' | 'merchant' | 'guard' | 'farmer'> = ['carrier', 'merchant', 'guard', 'farmer'];
    for (let i = 0; i < 14; i++) {
      const type = types[i % types.length];
      const startX = 6 + Math.floor(Math.random() * 6);
      const startY = 6 + Math.floor(Math.random() * 6);
      this.citizens.push({
        id: i,
        x: startX,
        y: startY,
        targetX: startX + (Math.random() - 0.5) * 3,
        targetY: startY + (Math.random() - 0.5) * 3,
        type,
        action: 'walk',
        speed: 0.02 + Math.random() * 0.02,
        animFrame: 0
      });
    }
  }

  /**
   * 매 프레임 백성 에이전트 이동 및 일터 행동 업데이트
   */
  public updateCitizens(): void {
    const size = GameStateManager.MAP_SIZE;

    // 길(road) 타일 목록 수집
    const roadTiles: Array<{ x: number; y: number }> = [];
    this.grid.forEach(row => row.forEach(t => {
      if (t.building === 'road') roadTiles.push({ x: t.x, y: t.y });
    }));

    this.citizens.forEach(c => {
      c.animFrame += 0.12;

      const dx = c.targetX - c.x;
      const dy = c.targetY - c.y;
      const dist = Math.hypot(dx, dy);

      if (dist < 0.1) {
        // 새로운 목적지 탐색 (도로망 우선 배회)
        if (roadTiles.length > 0 && Math.random() < 0.75) {
          const randRoad = roadTiles[Math.floor(Math.random() * roadTiles.length)];
          c.targetX = randRoad.x + 0.3 + Math.random() * 0.4;
          c.targetY = randRoad.y + 0.3 + Math.random() * 0.4;
        } else {
          c.targetX = Math.max(1, Math.min(size - 2, c.x + (Math.random() - 0.5) * 4));
          c.targetY = Math.max(1, Math.min(size - 2, c.y + (Math.random() - 0.5) * 4));
        }
      } else {
        c.x += (dx / dist) * c.speed;
        c.y += (dy / dist) * c.speed;
      }
    });
  }

  /**
   * 16방향 도로 연결 비트마스크 계산
   * 북(1, y-1), 동(2, x+1), 남(4, y+1), 서(8, x-1)
   */
  public getRoadMask(x: number, y: number): number {
    let mask = 0;
    const size = GameStateManager.MAP_SIZE;
    if (y > 0 && this.isRoadOrGate(x, y - 1)) mask |= 1;
    if (x + 1 < size && this.isRoadOrGate(x + 1, y)) mask |= 2;
    if (y + 1 < size && this.isRoadOrGate(x, y + 1)) mask |= 4;
    if (x > 0 && this.isRoadOrGate(x - 1, y)) mask |= 8;
    return mask;
  }

  private isRoadOrGate(x: number, y: number): boolean {
    const b = this.grid[y][x].building;
    return b === 'road' || b === 'wall' || b === 'levee' || b === 'gate';
  }

  /**
   * 16방향 성곽 연결 비트마스크 계산
   */
  public getWallMask(x: number, y: number): number {
    let mask = 0;
    const size = GameStateManager.MAP_SIZE;
    if (y > 0 && this.grid[y - 1][x].building === 'wall') mask |= 1;
    if (x + 1 < size && this.grid[y][x + 1].building === 'wall') mask |= 2;
    if (y + 1 < size && this.grid[y + 1][x].building === 'wall') mask |= 4;
    if (x > 0 && this.grid[y][x - 1].building === 'wall') mask |= 8;
    return mask;
  }

  public updateFortressScore(): void {
    this.wallManager.updateFortressProgress(this.grid, this.state);
  }

  public updateWaterManagement(): void {
    let leveeCount = 0;
    let resvCount = 0;
    this.grid.forEach(row => row.forEach(t => {
      if (t.building === 'levee') leveeCount++;
      if (t.building === 'reservoir') resvCount++;
    }));
    this.state.floodDefense = Math.min(100, leveeCount * 25);
    this.state.reservoirCount = resvCount;
  }

  public updateDemands(): void {
    let resCount = 0, comCount = 0, agrCount = 0;
    this.grid.forEach(row => row.forEach(t => {
      if (t.building?.startsWith('res')) resCount += (t.building === 'res_2' ? 2 : 1);
      if (t.building?.startsWith('com')) comCount += (t.building === 'com_2' ? 2 : 1);
      if (t.building?.startsWith('agr')) agrCount += (t.building === 'agr_2' ? 2 : 1);
    }));

    const jobs = comCount * 18 + agrCount * 12;
    const popNeed = jobs - this.state.pop;

    let dRes = 20 + Math.floor(popNeed * 0.4) + (this.state.loyalty - 70) * 0.6 + (this.state.fortressProgress * 0.3);
    dRes += (7 - this.state.taxRates.militaryTax) * 4;

    let dCom = 15 + Math.floor(this.state.pop * 0.25) - comCount * 10;
    if (this.state.retainers.park) dCom += 25;
    dCom += (7 - this.state.taxRates.marketTax) * 5;

    const riceDeficit = Math.max(0, (this.state.pop * 5) - this.state.rice);
    let dAgr = 20 + Math.floor(riceDeficit * 0.1) - agrCount * 8;
    if (this.state.retainers.seo) dAgr += 20;
    dAgr += (7 - this.state.taxRates.landTax) * 4;

    this.state.demandRes = Math.max(-100, Math.min(100, Math.round(dRes)));
    this.state.demandCom = Math.max(-100, Math.min(100, Math.round(dCom)));
    this.state.demandAgr = Math.max(-100, Math.min(100, Math.round(dAgr)));
  }

  public advanceTurn(): { historicEvent: string | null; dilemma: boolean; article: NewspaperArticle; completedProject: string | null } {
    this.state.turn++;
    this.state.seasonIndex = (this.state.seasonIndex + 1) % 4;
    if (this.state.seasonIndex === 0) this.state.year++;

    this.updateDemands();

    let addGold = 0, addRice = 0, addPop = 0;

    // 대외 교역로 및 관문 통제력 점검
    this.checkTradeSystem();
    if (this.state.trade.isConnected) {
      if (this.state.trade.hasBorderGate) {
        addGold += 300; // 합법 관세 세수
        this.state.authority = Math.min(100, this.state.authority + 2);
      } else {
        // 관문 미비 시 밀수 및 치안 누수 (왕권/통제력 하락)
        this.state.authority = Math.max(0, this.state.authority - 2);
        this.state.demandCom = Math.min(100, this.state.demandCom + 25);
      }
    }

    // 도로 거리 기반 차등 발전 (큰길가 최고급 발전 vs 샛길 골목 자율 개발)
    for (let y = 0; y < GameStateManager.MAP_SIZE; y++) {
      for (let x = 0; x < GameStateManager.MAP_SIZE; x++) {
        const tile = this.grid[y][x];
        const distToRoad = this.getDistanceToRoad(x, y);

        // 1. 미개발 구역의 신규 착공 판정
        if (tile.zone && !tile.building) {
          const zoneDemand = tile.zone === 'res' ? this.state.demandRes :
                             tile.zone === 'com' ? this.state.demandCom : this.state.demandAgr;
          
          if (zoneDemand > 0) {
            if (tile.zone === 'agr') {
              // 대유둔전: 도로 6칸 거리 이내 즉각 개간
              if (distToRoad <= 6) {
                tile.building = 'agr_1';
              }
            } else {
              // 저잣거리/방리: 도로 3칸 거리 이내 즉각 착공
              if (distToRoad <= 3) {
                tile.building = `${tile.zone}_1`;
              }
            }
          }
        } 
        // 2. 기존 건물의 고도화 승급 (큰길가가 가장 번성하고 기와집/대형시전 탄생)
        else if (tile.building && tile.building.endsWith('_1')) {
          const zoneDemand = tile.building.startsWith('res') ? this.state.demandRes :
                             tile.building.startsWith('com') ? this.state.demandCom : this.state.demandAgr;

          if (distToRoad === 1) {
            // 큰길가: 수요 15 이상이면 대감댁 기와집(res_2), 육의전 대형 상점(com_2)으로 최고급 승급!
            if (zoneDemand > 15 && Math.random() < 0.65) {
              tile.building = `${tile.zone}_2`;
            }
          } else if (distToRoad <= 3) {
            // 샛길 골목: 우물이 있거나 수요가 매우 높을 때 점진적 승급
            if (zoneDemand > 35 && this.hasNeighbor(x, y, 'well') && Math.random() < 0.35) {
              tile.building = `${tile.zone}_2`;
            }
          }
        }

        // 건물별 차등 세수/인구 수확 (큰길가 보너스)
        const roadBonus = (distToRoad === 1) ? 1.4 : 1.0;

        if (tile.building === 'res_1') addPop += Math.round(3 * roadBonus);
        if (tile.building === 'res_2') addPop += Math.round(9 * roadBonus);
        if (tile.building === 'com_1') addGold += Math.round(35 * roadBonus);
        if (tile.building === 'com_2') addGold += Math.round(110 * roadBonus);
        if (tile.building === 'agr_1') addRice += 40;
        if (tile.building === 'agr_2') addRice += 100;
        if (tile.building === 'guesthouse') addGold += 140;
        if (tile.building === 'factory') addGold += 160;
        if (tile.building === 'hyoryungwon' && this.state.hyoryungwon.blessingActive) {
          addGold += 80;
          this.state.loyalty = Math.min(100, this.state.loyalty + 1);
        }
      }
    }

    if (this.state.retainers.park) addGold = Math.floor(addGold * 1.4);
    if (this.state.retainers.seo) addRice = Math.floor(addRice * 1.25);
    if (this.state.retainers.hong) { addGold += 350; this.state.loyalty = Math.max(0, this.state.loyalty - 3); }
    if (this.state.retainers.kim) this.state.loyalty = Math.min(100, this.state.loyalty + 2);
    if (this.state.retainers.baek) this.state.military += 10;
    if (this.state.retainers.gu) { this.state.military += 25; addRice -= 20; }

    if (this.state.research.gwanong) addRice = Math.floor(addRice * 1.4);
    if (this.state.research.seed) addRice = Math.floor(addRice * 1.2);
    if (this.state.research.fertilizer) addRice += 60;
    if (this.state.research.reservoir) addRice += 80;

    const taxMarketRevenue = Math.floor(addGold * (this.state.taxRates.marketTax / 7));
    const taxLandRevenue = Math.floor((addRice * 0.2) * (this.state.taxRates.landTax / 7));
    const taxMilitaryRevenue = Math.floor((this.state.pop * 0.5) * (this.state.taxRates.militaryTax / 7));

    addGold += taxMarketRevenue + taxLandRevenue + taxMilitaryRevenue;

    const avgTax = (this.state.taxRates.landTax + this.state.taxRates.marketTax + this.state.taxRates.militaryTax) / 3;
    if (avgTax > 10) {
      this.state.loyalty = Math.max(0, this.state.loyalty - Math.round(avgTax - 10));
    } else if (avgTax < 7) {
      this.state.loyalty = Math.min(100, this.state.loyalty + Math.round(7 - avgTax));
    }

    this.state.gold += addGold;
    this.state.rice += addRice;
    this.state.pop += addPop;

    let riceConsumption = Math.floor(this.state.pop * 0.4 + this.state.military * 0.2);
    if (this.state.research.goguma) riceConsumption = Math.floor(riceConsumption * 0.63);
    this.state.rice -= riceConsumption;

    if (this.state.rice < 100 && this.state.trade.autoBuyRice && this.state.gold >= 200) {
      this.state.gold -= 200;
      this.state.rice += 250;
      this.state.trade.totalImportedRice += 250;
    } else if (this.state.rice < 0) {
      this.state.rice = 0;
      this.state.loyalty = Math.max(0, this.state.loyalty - 18);
    }

    this.updateFortressScore();
    this.updateWaterManagement();

    // 1. 여름철(여름) 홍수 및 수원천 범람 시뮬레이션 (청계천 준천 모델)
    if (this.state.seasonIndex === 1) {
      if (this.state.floodDefense >= 50) {
        this.state.loyalty = Math.min(100, this.state.loyalty + 4);
      } else {
        // 제방 미흡 시 수해 발생
        this.state.gold = Math.max(0, this.state.gold - 120);
        this.state.rice = Math.max(0, this.state.rice - 80);
        this.state.loyalty = Math.max(0, this.state.loyalty - 6);
      }
    }

    // 2. 가뭄 극복 및 만석거 관개 용수 시뮬레이션
    if (this.state.seasonIndex === 0 || this.state.seasonIndex === 2) {
      if (this.state.reservoirCount >= 1) {
        this.state.rice += 150 * this.state.reservoirCount;
      }
    }

    // 3. 국책 대역사 공사 진척 시뮬레이션
    let completedProject: string | null = null;
    this.state.megaProjects.forEach(p => {
      if (p.isStarted && !p.isCompleted) {
        this.state.gold = Math.max(0, this.state.gold - p.costPerTurn.gold);
        this.state.rice = Math.max(0, this.state.rice - p.costPerTurn.rice);
        p.progressTurns++;

        if (p.progressTurns >= p.totalTurns) {
          p.isCompleted = true;
          p.isStarted = false;
          p.targetTiles.forEach(pt => {
            const tile = this.grid[pt.y]?.[pt.x];
            if (tile) {
              tile.building = pt.building;
              tile.underConstruction = false;
            }
          });
          completedProject = p.rewardMsg;
        }
      }
    });

    if (completedProject) {
      this.updateFortressScore();
      this.updateWaterManagement();
    }

    this.updateDemands();

    let historicEvent: string | null = null;
    if (this.state.year === 1789 && !this.state.milestones.wonhaeng1789) {
      this.state.milestones.wonhaeng1789 = true;
      historicEvent = 'wonhaeng1789';
    } else if (this.state.year === 1795 && !this.state.milestones.eulmyo1795) {
      this.state.milestones.eulmyo1795 = true;
      historicEvent = 'eulmyo1795';
    }

    const article = this.generateNewspaperArticle(historicEvent);

    return {
      historicEvent,
      dilemma: (this.state.turn % 3 === 0),
      article,
      completedProject
    };
  }

  public generateNewspaperArticle(historicEvent: string | null): NewspaperArticle {
    const y = this.state.year;
    const season = this.state.seasons[this.state.seasonIndex];
    const dateStr = `정조 ${y - 1776 + 1}년(${y}년) ${season}호`;

    if (historicEvent === 'wonhaeng1789') {
      return {
        dateStr,
        headline: "정조 대왕, 현륭원 원행 단행! 한강에 웅장한 주교(舟橋) 개통",
        subhead: "정약용 설계 배다리로 백성 피해 없이 한강 도하… 수원 신도시 일대 환호",
        body: "과인의 부친 사도세자의 묘소를 수원 화산으로 영구히 모시는 원행 행렬이 무사히 한강을 건넜다. 조정 대신들의 우려와 달리 단 한 척의 상선 피해도 없이 완벽한 부교를 완성한 정약용의 주교지모가 천하를 놀라게 하고 있다.",
        editorial: "[비변사 논평] 화성 신도시가 이제 단순한 행정 구역을 넘어 왕실과 국가의 정신적 상징으로 우뚝 솟아오르고 있다."
      };
    }

    if (historicEvent === 'eulmyo1795') {
      return {
        dateStr,
        headline: "을묘년 혜경궁 홍씨 회갑연! 화성행궁 봉수당에서 천하 대잔치",
        subhead: "어머니를 위한 8일간의 화성 행차… 장용영 3천 정예병 사열로 노론 벽파 간담 서늘",
        body: "화성행궁 봉수당에서 모친 혜경궁 홍씨를 위한 회갑연이 성대히 거행되었다. 8일간 이어진 야간 군사 훈련에서 팔달산 서장대에 오른 정조 대왕의 지휘 아래 장용영 군사들이 철통같은 위용을 떨쳐 외침과 역모의 싹을 잘라냈다.",
        editorial: "[한양 정계 반응] 팔달산 정상에서 뿜어져 나오는 장용영의 포화 소리에 붕당 세력들이 숨을 죽이고 있다."
      };
    }

    if (this.state.fortressProgress >= 100) {
      return {
        dateStr,
        headline: "천하제일 철옹성 수원화성 완공! 거중기와 녹로로 2년 9개월의 기적",
        subhead: "품삯을 지급하는 관급 공사 제도로 백성들 부역 고통 해소… 유네스코급 세계적 성곽 탄생",
        body: "화성성역의 대역사가 대단원의 막을 내렸다. 정약용의 거중기와 채제공 총리대신의 헌신으로 공사비와 기간을 절반으로 단축시켰으며, 부역에 동원된 모든 장인과 백성들에게 공정한 엽전 품삯이 지급되어 태평성대를 구가하고 있다.",
        editorial: "[사관의 평] 임금의 애민정신과 실학 과학기술이 빚어낸 조선 역사상 가장 찬란한 금자탑이다."
      };
    }

    if (this.state.reservoirCount >= 1 && this.state.seasonIndex === 0) {
      return {
        dateStr,
        headline: "만석거(萬石渠) 축조 성공! 팔달산 고지대 저수지로 둔전 관개 완비",
        subhead: "정조 대왕의 혜안, 황무지가 1만 석 곡창지대로 변모… 가뭄 걱정 완전 해소",
        body: "수원 북방 고지대에 축조된 인공 저수지 만석거가 완공되어 수문을 열었다. 풍부한 관개 용수가 거미줄 같은 수로를 타고 대유둔전으로 흘러들며 전국 농민들의 이주 행렬이 이어지고 있다.",
        editorial: "[비변사 평가] 치수와 수리를 겸비한 혁신적인 농업 인프라로 국가 재정의 든든한 보루가 마련되었다."
      };
    }

    if (this.state.floodDefense >= 50 && this.state.seasonIndex === 1) {
      return {
        dateStr,
        headline: "수원천 석축 제방 준공! 청계천 준천에 버금가는 대역사 완성",
        subhead: "여름철 집중호우에도 단 한 가구의 침수 피해 없어… 유수부 치수 행정 극찬",
        body: "수원천을 따라 견고한 화강암 석축 제방이 들어서면서 매년 반복되던 여름철 범람 악순환의 고리가 끊어졌다. 영조 대왕의 청계천 준천 사업을 계승한 완벽한 방재 시스템이 신도시를 지켜냈다.",
        editorial: "[백성들의 노래] 물난리 걱정 없이 안심하고 잠을 이루니 정조 대왕의 성덕이 하해와 같습니다."
      };
    }

    if (this.state.demandCom > 50) {
      return {
        dateStr,
        headline: "삼남대로 저잣거리 번영! 팔도 보부상들 수원으로 대거 집결",
        subhead: "신해통공의 온기 확산… 난전 금지령 폐지로 시전 상인과 소상공인 모두 활짝",
        body: "수원 팔달문 밖 삼남대로에 전국 팔도에서 올라온 쌀, 소금, 인삼, 유기가 넘쳐나고 있다. 유수부의 상업 장려책과 세제 감면 조치에 힘입어 한양 종로 시전을 능가하는 대규모 교역 중심지로 급부상 중이다.",
        editorial: "[시전 상인회] 조세를 낮추고 도로를 닦아주니 장사할 맛이 납니다. 유수 영감의 혜안에 감사할 따름입니다."
      };
    }

    if (this.state.rice < 300) {
      return {
        dateStr,
        headline: "수원천 일대 가뭄 우려… 비변사 군량미 비축 경보 발령",
        subhead: "식량 재고 급감에 백성들 동요… 만석거 관개 정비와 대유둔전 확충 시급",
        body: "계절적 가뭄으로 수원천 수량이 줄어들며 둔전의 벼 수확량에 비상이 걸렸다. 유수부는 대외 곡물 교역을 확대하고 조엄의 고구마 보급을 서두르는 등 식량 안보 확보에 총력을 기울여야 할 것으로 보인다.",
        editorial: "[민심 동향] 배고픈 백성에겐 성벽보다 한 사발의 밥이 급선무요. 곡간을 채우는 데 힘써야 하옵니다."
      };
    }

    return {
      dateStr,
      headline: `화성성역 순항! 신도시 인구 ${this.state.pop}명 돌파하며 활기`,
      subhead: `충성도 ${this.state.loyalty}% 유지… 성벽 완공도 ${this.state.fortressProgress}% 달성 순조`,
      body: `정조 대왕의 개혁 의지가 서린 수원화성 신도시가 하루가 다르게 웅장한 면모를 갖춰가고 있다. 삼남대로를 따라 방·리와 저잣거리가 조화롭게 들어서며 백성들의 살림살이가 점차 윤택해지고 있다는 평이다.`,
      editorial: `[비변사 감찰] 백성들의 정착률이 높고 치안이 안정되어 있으니, 이 기세를 몰아 방어벽 축성에 만전을 기해야 할 것이다.`
    };
  }

  public static rotateCoords(x: number, y: number, rot: number, size = GameStateManager.MAP_SIZE): { rx: number; ry: number } {
    switch (rot % 4) {
      case 1: return { rx: y, ry: size - 1 - x };
      case 2: return { rx: size - 1 - x, ry: size - 1 - y };
      case 3: return { rx: size - 1 - y, ry: x };
      default: return { rx: x, ry: y };
    }
  }

  public static unrotateCoords(rx: number, ry: number, rot: number, size = GameStateManager.MAP_SIZE): { x: number; y: number } {
    switch (rot % 4) {
      case 1: return { x: size - 1 - ry, y: rx };
      case 2: return { x: size - 1 - rx, y: size - 1 - ry };
      case 3: return { x: ry, y: size - 1 - rx };
      default: return { x: rx, y: ry };
    }
  }

  public hasNeighbor(x: number, y: number, target: string): boolean {
    const dirs = [[0, 1], [0, -1], [1, 0], [-1, 0]];
    for (const [dx, dy] of dirs) {
      const nx = x + dx, ny = y + dy;
      if (nx >= 0 && nx < GameStateManager.MAP_SIZE && ny >= 0 && ny < GameStateManager.MAP_SIZE) {
        if (this.grid[ny][nx].building === target) return true;
      }
    }
    return false;
  }

  /**
   * BFS 기반 도로망과의 최단 거리 계산 (일반 도로, 제방로, 성문 포함)
   */
  public getDistanceToRoad(x: number, y: number): number {
    const size = GameStateManager.MAP_SIZE;
    const b = this.grid[y][x].building;
    if (b === 'road' || b === 'levee' || b === 'gate') return 0;

    let minD = 99;
    for (let ry = 0; ry < size; ry++) {
      for (let rx = 0; rx < size; rx++) {
        const tb = this.grid[ry][rx].building;
        if (tb === 'road' || tb === 'levee' || tb === 'gate') {
          const d = Math.abs(rx - x) + Math.abs(ry - y);
          if (d < minD) minD = d;
        }
      }
    }
    return minD;
  }

  /**
   * 구획별 도로 연결 허용 거리 (Road-connection Tolerance Buffer) 판정:
   * 대유둔전(농지 구역): 도로로부터 최대 6칸 이내
   * 저잣거리/방리(주거/상업): 도로로부터 최대 3칸 이내
   */
  public isRoadConnected(x: number, y: number, maxDist: number = -1, zoneType: string = ''): boolean {
    const tile = this.grid[y][x];
    if (tile.building && ['road', 'stone_road', 'wall', 'gate', 'levee', 'gongsimdon', 'poru', 'bongdon', 'hwahong', 'namsu'].includes(tile.building)) {
      return true;
    }
    const isAgr = zoneType === 'agr' || tile.zone === 'agr' || tile.building?.startsWith('agr');
    const threshold = maxDist >= 0 ? maxDist : (isAgr ? 6 : 3);
    const d = this.getDistanceToRoad(x, y);
    return d <= threshold;
  }

  /**
   * 샛길/골목 연결 판정: 8방향에 다른 건물이나 구역이 있어 징검다리 연결이 가능한지
   */
  public hasConnectedNeighbor(x: number, y: number): boolean {
    const size = GameStateManager.MAP_SIZE;
    for (let dy = -1; dy <= 1; dy++) {
      for (let dx = -1; dx <= 1; dx++) {
        if (dx === 0 && dy === 0) continue;
        const nx = x + dx, ny = y + dy;
        if (nx >= 0 && nx < size && ny >= 0 && ny < size) {
          const t = this.grid[ny][nx];
          if (t.building || t.zone) return true;
        }
      }
    }
    return false;
  }

  /**
   * 대외 교역로(지도 가장자리 도로) 및 관문(성문) 통제력 판정
   */
  public checkTradeSystem(): void {
    const size = GameStateManager.MAP_SIZE;
    let connected = false;
    let gated = false;

    // 4변 경계선 타일 검사
    const borderPoints: Array<{ x: number; y: number }> = [];
    for (let i = 0; i < size; i++) {
      borderPoints.push({ x: i, y: 0 });
      borderPoints.push({ x: i, y: size - 1 });
      borderPoints.push({ x: 0, y: i });
      borderPoints.push({ x: size - 1, y: i });
    }

    borderPoints.forEach(pt => {
      if (this.grid[pt.y][pt.x].building === 'road') {
        connected = true;
        // 주변 2칸 내에 성곽(wall)이나 관문이 있는지 확인
        for (let dy = -2; dy <= 2; dy++) {
          for (let dx = -2; dx <= 2; dx++) {
            const nx = pt.x + dx, ny = pt.y + dy;
            if (nx >= 0 && nx < size && ny >= 0 && ny < size) {
              if (this.grid[ny][nx].building === 'wall' || this.grid[ny][nx].building === 'gate') {
                gated = true;
              }
            }
          }
        }
      }
    });

    this.state.trade.isConnected = connected;
    this.state.trade.hasBorderGate = gated;

    // 교역로 연결 시 보부상 에이전트 활동 증가
    if (connected && this.citizens.length < 24) {
      this.citizens.push({
        id: this.citizens.length,
        x: borderPoints[0].x,
        y: borderPoints[0].y,
        targetX: 8,
        targetY: 8,
        type: 'merchant',
        action: 'walk',
        speed: 0.035,
        animFrame: 0
      });
      this.state.trade.activeMerchants++;
    }
  }

  /**
   * 정조 포호(捕虎) 정책 해결
   */
  public resolveTigerCrisis(choice: 'army' | 'clear' | 'bounty'): { success: boolean; msg: string } {
    if (choice === 'army') {
      if (this.state.military < 60 || this.state.rice < 100) {
        return { success: false, msg: "장용영 군사력(최소 60) 또는 군량이 부족합니다!" };
      }
      this.state.rice -= 100;
      this.state.gold += 500; // 호피 및 부산물 진상
      this.state.authority = Math.min(100, this.state.authority + 15);
      this.state.loyalty = Math.min(100, this.state.loyalty + 20);
      this.state.tigerCrisis.active = false;
      this.state.tigerCrisis.solved = true;
      return { success: true, msg: "장용영 착호군이 맹호를 사냥하여 호피를 진상하고 백성들을 구원했습니다! (금 +500, 왕권 +15, 민심 +20)" };
    } else if (choice === 'clear') {
      if (this.state.gold < 180) {
        return { success: false, msg: "산지 개간 예산이 부족합니다!" };
      }
      this.state.gold -= 180;
      this.state.rice += 200;
      this.state.loyalty = Math.min(100, this.state.loyalty + 8);
      this.state.tigerCrisis.active = false;
      this.state.tigerCrisis.solved = true;
      return { success: true, msg: "화전민과 함께 산지를 개간하여 호랑이 서식지를 농지로 바꾸었습니다! (식량 +200, 민심 +8)" };
    } else {
      // bounty 현상금
      if (this.state.gold < 80) return { success: false, msg: "현상금 재정이 부족합니다!" };
      this.state.gold -= 80;
      const success = Math.random() < 0.6;
      this.state.tigerCrisis.active = false;
      if (success) {
        this.state.loyalty = Math.min(100, this.state.loyalty + 10);
        return { success: true, msg: "민간 명포수가 호랑이를 처치하여 현상금을 지급했습니다! (민심 +10)" };
      } else {
        this.state.pop = Math.max(10, this.state.pop - 5);
        this.state.loyalty = Math.max(0, this.state.loyalty - 12);
        return { success: true, msg: "포수에 실패하여 호환으로 백성들이 희생되었습니다. (인구 -5, 민심 -12)" };
      }
    }
  }

  /**
   * 원자(순조) 세자 책봉 및 시강원 설치
   */
  public investCrownPrince(tutor: 'jeong' | 'chae' | 'classic'): { success: boolean; msg: string } {
    if (this.state.gold < 300) return { success: false, msg: "책봉 의식과 시강원 설치를 위한 국고(300냥)가 부족합니다!" };
    this.state.gold -= 300;
    this.state.crownPrince.invested = true;
    this.state.crownPrince.tutor = tutor;
    this.state.crownPrince.educationLevel = 15;
    this.state.authority = Math.max(0, this.state.authority - 5); // 노론 벽파의 반발 긴장
    this.state.loyalty = Math.min(100, this.state.loyalty + 10);
    const tutorName = tutor === 'jeong' ? "다산 정약용" : tutor === 'chae' ? "번암 채제공" : "성균관 대제학";
    return { success: true, msg: `원자를 세자로 책봉하고 ${tutorName}을 시강원 사부로 임명하여 제왕학 서연을 시작했습니다!` };
  }

  /**
   * 세자 제왕학 서연(書筵) 교육 진행
   */
  public studyCrownPrince(): { success: boolean; msg: string } {
    if (!this.state.crownPrince.invested) return { success: false, msg: "먼저 세자를 책봉해야 합니다!" };
    if (this.state.crownPrince.educationLevel >= 100) return { success: false, msg: "세자께서 이미 성군의 자질을 완벽히 갖추셨습니다!" };
    if (this.state.gold < 100 || this.state.rice < 40) return { success: false, msg: "서연 운영에 필요한 국고(100냥) 또는 군량(40석)이 부족합니다!" };

    this.state.gold -= 100;
    this.state.rice -= 40;
    this.state.crownPrince.educationLevel = Math.min(100, this.state.crownPrince.educationLevel + 20);
    this.state.authority = Math.min(100, this.state.authority + 5);

    if (this.state.crownPrince.educationLevel >= 100) {
      return { success: true, msg: "경축! 세자(순조)께서 제왕학을 완수하여, 정조 사후 세도정치를 원천 차단할 성군의 위용을 완성하셨습니다!" };
    }
    return { success: true, msg: `시강원 서연을 통해 세자의 학문과 치국 역량이 증진되었습니다. (진척도: ${this.state.crownPrince.educationLevel}%)` };
  }

  /**
   * 화산 현륭원(顯隆園) 친림 참배
   */
  public visitHyoryungwon(): { success: boolean; msg: string } {
    if (this.state.hyoryungwon.visited) return { success: false, msg: "이미 금년도 현륭원 참배를 성대히 마쳤습니다." };
    this.state.hyoryungwon.visited = true;
    this.state.hyoryungwon.blessingActive = true;
    this.state.loyalty = Math.min(100, this.state.loyalty + 20);
    this.state.authority = Math.min(100, this.state.authority + 15);
    return { success: true, msg: "정조 대왕께서 화산 현륭원에 친림하여 부친 사도세자의 묘소를 참배하니, 천하 백성들이 효심에 감읍합니다! (민심 +20, 왕권 +15, 가호 활성화)" };
  }
}
